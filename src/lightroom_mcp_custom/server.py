from __future__ import annotations

import logging
import mimetypes
import os
from pathlib import Path
from typing import Any

from mcp.server.fastmcp import FastMCP

from .bridge import AsyncLightroomBridge, BridgeCommandError, BridgeConnectionError
from .validators import (
    validate_develop_settings,
    validate_local_ids,
    validate_pick_status,
    validate_rating,
)
from .workflows import (
    get_group_parameters,
    list_group_descriptions,
    list_preset_descriptions,
    merge_preset_overrides,
    validate_group_values,
)

LOG_LEVEL = os.getenv("LIGHTROOM_MCP_LOG_LEVEL", "INFO").upper()
logging.basicConfig(level=getattr(logging, LOG_LEVEL, logging.INFO))

mcp = FastMCP(
    name="lightroom-classic-mcp",
    instructions="""\
Controls Adobe Lightroom Classic through a local custom bridge plugin.
Operates on selected photos by default, or pass local_ids for targeted edits.

## Key develop parameters (use with apply_develop_settings / set_develop_param)

### Basic Tone
- Temperature (2000-50000), Tint (-150 to 150)
- Exposure (-5.0 to 5.0), Contrast (-100 to 100)
- Highlights, Shadows, Whites, Blacks (-100 to 100)
- Clarity, Vibrance, Saturation (-100 to 100), Dehaze (-100 to 100)

### Color Grading / Split Toning
- SplitToningHighlightHue (0-360), SplitToningHighlightSaturation (0-100)
- SplitToningShadowHue (0-360), SplitToningShadowSaturation (0-100)
- SplitToningBalance (-100 to 100)
- ColorGradeMidtoneHue (0-360), ColorGradeMidtoneSat (0-100)
- ColorGradeGlobalHue (0-360), ColorGradeGlobalSat (0-100)
- ColorGradeBlending (0-100)

### HSL (per-channel: Red, Orange, Yellow, Green, Aqua, Blue, Purple, Magenta)
- HueAdjustment{Color} (-100 to 100)
- SaturationAdjustment{Color} (-100 to 100)
- LuminanceAdjustment{Color} (-100 to 100)

### Tone Curve (parametric)
- ParametricShadows, ParametricDarks, ParametricLights, ParametricHighlights (-100 to 100)

### Effects
- PostCropVignetteAmount (-100 to 100), PostCropVignetteFeather (0-100)
- GrainAmount (0-100), GrainSize (0-100)

### Detail
- Sharpness (0-150), SharpenRadius (0.5-3.0), SharpenDetail (0-100)
- LuminanceSmoothing (0-100), ColorNoiseReduction (0-100)

## Workflow tips
- Call get_active_photo_file or get_selected_photo_files when you want to inspect the original image from disk before editing.
- Call get_develop_settings first to see current state before editing.
- Use apply_develop_settings to change multiple params at once (most efficient).
- Use set_develop_param for a single slider change.
- Use list_develop_groups / set_develop_group for category-based edits.
- Use list_develop_presets / apply_develop_preset for one-click looks.
- batch_apply_develop_operations chains multiple operations sequentially.
- auto_tone and auto_white_balance let Lightroom decide optimal values.
- reset_current_photo reverts all develop adjustments.
- history_name param creates a named history step in Lightroom (for undo).
- Use export_photos for final output or Lightroom-rendered before/after verification, not as the default inspection path.

## Local Adjustments / Masks
- select_mask_tool to choose brush, graduated-filter, radial-filter, range-mask
- create_ai_mask to create AI masks: subject, sky, background, person, object, depth, luminance, color
- select_mask to switch between existing masks by ID
- get/apply_local_adjustment_settings to read/write local_* params on active mask
- toggle_mask_overlay to visualize the mask
- invert_mask to invert the active mask

### Local adjustment parameters (on active mask)
- local_Exposure (-5 to 5), local_Contrast (-100 to 100)
- local_Highlights, local_Shadows, local_Whites, local_Blacks (-100 to 100)
- local_Clarity, local_Dehaze, local_Texture (-100 to 100)
- local_Saturation, local_Vibrance (-100 to 100)
- local_Temperature, local_Tint (-100 to 100)
- local_Sharpness, local_LuminanceNoise, local_Moire, local_Defringe (0 to 100)

## Undo / Redo
- undo and redo to step through history
- create_snapshot / list_snapshots / apply_snapshot for named develop snapshots

## Collections
- list_collections, create_collection, add_to_collection, remove_from_collection

## Other tools
- create_virtual_copy, rotate_left, rotate_right
- list_lightroom_presets / apply_lightroom_preset for Lightroom's built-in presets
""",
)
bridge = AsyncLightroomBridge()


async def _call(
    command: str,
    params: dict[str, Any] | None = None,
    timeout_s: float | None = None,
) -> dict[str, Any]:
    try:
        return await bridge.send_command(command, params=params, timeout_s=timeout_s)
    except (BridgeConnectionError, BridgeCommandError) as exc:
        raise RuntimeError(str(exc)) from exc


async def _apply_validated_settings(
    settings: dict[str, Any],
    *,
    local_ids: list[int] | None = None,
    strict: bool = False,
    clamp: bool = True,
    history_name: str | None = None,
) -> dict[str, Any]:
    ids = validate_local_ids(local_ids)
    result = validate_develop_settings(settings, strict=strict, clamp=clamp)

    payload: dict[str, Any] = {"settings": result.sanitized}
    if ids:
        payload["local_ids"] = ids
    if history_name:
        payload["history_name"] = history_name

    response = await _call("develop.apply_settings", payload)
    response["validation_warnings"] = result.warnings
    response["applied_settings"] = result.sanitized
    return response


def _normalize_photo_for_inspection(photo: dict[str, Any]) -> dict[str, Any]:
    path_value = photo.get("path")
    file_path = Path(path_value).expanduser() if isinstance(path_value, str) and path_value else None
    exists = bool(file_path and file_path.exists())
    readable = bool(exists and os.access(file_path, os.R_OK))
    mime_type = mimetypes.guess_type(str(file_path))[0] if file_path else None
    file_size = None
    if readable and file_path is not None:
        try:
            file_size = file_path.stat().st_size
        except OSError:
            file_size = None

    normalized = dict(photo)
    normalized["inspection"] = {
        "source": "lightroom-path",
        "path": str(file_path) if file_path else None,
        "file_exists": exists,
        "is_readable": readable,
        "is_inspectable": bool(exists and readable),
        "suffix": file_path.suffix.lower() if file_path else None,
        "mime_type": mime_type,
        "file_size_bytes": file_size,
    }
    return normalized


def _resolve_batch_operation(operation: dict[str, Any]) -> tuple[str, dict[str, Any], str | None]:
    if "preset" in operation:
        preset = operation.get("preset")
        overrides = operation.get("overrides")
        if overrides is not None and not isinstance(overrides, dict):
            raise ValueError("overrides must be a dictionary when provided")
        preset_name, settings = merge_preset_overrides(str(preset), overrides)
        return "preset", settings, preset_name

    if "parameter" in operation:
        parameter = operation.get("parameter")
        if not isinstance(parameter, str) or not parameter:
            raise ValueError("parameter operation requires a non-empty parameter")
        if "value" not in operation:
            raise ValueError("parameter operation requires a value field")
        return "parameter", {parameter: operation["value"]}, parameter

    if "settings" in operation:
        settings = operation.get("settings")
        if not isinstance(settings, dict) or not settings:
            raise ValueError("settings operation requires a non-empty settings dictionary")
        return "settings", settings, None

    if "group" in operation:
        group = operation.get("group")
        values = operation.get("values")
        if not isinstance(values, dict) or not values:
            raise ValueError("group operation requires a non-empty values dictionary")
        group_name, group_values = validate_group_values(str(group), values)
        return "group", group_values, group_name

    raise ValueError("operation must include one of: preset, settings, parameter, or group")


@mcp.tool()
async def lightroom_ping() -> dict[str, Any]:
    """Verify Lightroom bridge connectivity and plugin health."""
    return await _call("system.ping")


@mcp.tool()
async def lightroom_status() -> dict[str, Any]:
    """Get plugin status, command count, and socket state."""
    return await _call("system.status")


@mcp.tool()
async def lightroom_list_commands() -> dict[str, Any]:
    """List command names currently exposed by the Lightroom plugin."""
    return await _call("system.list_commands")


@mcp.tool()
async def get_selected_photos(limit: int = 200) -> dict[str, Any]:
    """List selected Lightroom photos with IDs and key metadata."""
    limit = max(1, min(int(limit), 1000))
    return await _call("catalog.get_selected_photos", {"limit": limit})


@mcp.tool()
async def get_active_photo() -> dict[str, Any]:
    """Get the active Lightroom photo in the current selection."""
    return await _call("catalog.get_active_photo")


@mcp.tool()
async def get_active_photo_file() -> dict[str, Any]:
    """Get active photo metadata plus direct file-inspection details."""
    response = await get_active_photo()
    photo = response.get("photo")
    if not isinstance(photo, dict):
        return {
            **response,
            "photo": None,
        }
    return {
        **response,
        "photo": _normalize_photo_for_inspection(photo),
    }


@mcp.tool()
async def find_photo_by_path(path: str) -> dict[str, Any]:
    """Find one Lightroom catalog photo by absolute file path."""
    if not path:
        raise ValueError("path is required")
    return await _call("catalog.find_photo_by_path", {"path": path})


@mcp.tool()
async def search_photos(
    keyword: str | None = None,
    date_from: str | None = None,
    date_to: str | None = None,
    rating_min: int | None = None,
    rating_max: int | None = None,
    pick_status: int | None = None,
    label: str | None = None,
    camera_model: str | None = None,
    limit: int = 20,
    sort: str = "newest",
) -> dict[str, Any]:
    """Search photos in the catalog by filters. All filters are optional and combinable.

    Args:
        keyword: Filter by keyword name (exact match, case-insensitive).
        date_from: Start date inclusive (YYYY-MM-DD).
        date_to: End date inclusive (YYYY-MM-DD).
        rating_min: Minimum star rating (0-5).
        rating_max: Maximum star rating (0-5).
        pick_status: -1 (rejected), 0 (unflagged), or 1 (flagged/picked).
        label: Color label (red, yellow, green, blue, purple).
        camera_model: Camera model substring match (case-insensitive).
        limit: Max results to return (default 20, max 100).
        sort: "newest" (default) or "oldest".
    """
    import re

    payload: dict[str, Any] = {}
    if keyword:
        payload["keyword"] = keyword
    if date_from:
        if not re.match(r"^\d{4}-\d{2}-\d{2}$", date_from):
            raise ValueError("date_from must be YYYY-MM-DD format")
        payload["date_from"] = date_from
    if date_to:
        if not re.match(r"^\d{4}-\d{2}-\d{2}$", date_to):
            raise ValueError("date_to must be YYYY-MM-DD format")
        payload["date_to"] = date_to
    if rating_min is not None:
        payload["rating_min"] = validate_rating(rating_min)
    if rating_max is not None:
        payload["rating_max"] = validate_rating(rating_max)
    if pick_status is not None:
        payload["pick_status"] = validate_pick_status(pick_status)
    if label:
        payload["label"] = label
    if camera_model:
        payload["camera_model"] = camera_model
    payload["limit"] = min(max(int(limit), 1), 100)
    if sort not in ("newest", "oldest"):
        raise ValueError("sort must be 'newest' or 'oldest'")
    payload["sort"] = sort
    return await _call("catalog.search_photos", payload, timeout_s=60.0)


@mcp.tool()
async def get_selected_photo_files(limit: int = 200) -> dict[str, Any]:
    """List selected Lightroom photos with direct file-inspection details."""
    response = await get_selected_photos(limit=limit)
    photos = response.get("photos")
    if not isinstance(photos, list):
        return {
            **response,
            "photos": [],
        }
    return {
        **response,
        "photos": [
            _normalize_photo_for_inspection(photo)
            for photo in photos
            if isinstance(photo, dict)
        ],
    }


@mcp.tool()
async def get_develop_settings(local_ids: list[int] | None = None) -> dict[str, Any]:
    """Get all ~175 develop settings for the active photo (or first in local_ids).

    Returns a settings dict with every slider value: exposure, contrast, HSL,
    split toning, tone curve, sharpening, noise reduction, effects, etc.
    Call this before editing to understand the photo's current state.
    """
    ids = validate_local_ids(local_ids)
    params: dict[str, Any] = {}
    if ids:
        params["local_ids"] = ids
    return await _call("develop.get_settings", params)


@mcp.tool()
async def get_develop_param_range(parameter: str) -> dict[str, Any]:
    """Get slider range for a develop parameter (when Lightroom can report it)."""
    if not parameter:
        raise ValueError("parameter is required")
    return await _call("develop.get_param_range", {"parameter": parameter})


@mcp.tool()
async def list_develop_parameters() -> dict[str, Any]:
    """List develop parameters known by this Lightroom Classic install."""
    return await _call("develop.list_params")


@mcp.tool()
async def list_develop_param_ranges(parameters: list[str] | None = None) -> dict[str, Any]:
    """Get numeric ranges for known develop parameters (where available)."""
    payload: dict[str, Any] = {}
    if parameters:
        payload["parameters"] = [str(p) for p in parameters if str(p)]
    return await _call("develop.list_param_ranges", payload)


@mcp.tool()
async def apply_develop_settings(
    settings: dict[str, Any],
    local_ids: list[int] | None = None,
    strict: bool = False,
    clamp: bool = True,
    history_name: str | None = None,
) -> dict[str, Any]:
    """Apply one or many develop settings to selected photos or local_ids.

    Settings is a dict of parameter names to values, e.g.:
    {"Exposure": 0.5, "Contrast": 25, "SplitToningHighlightHue": 35}
    Use strict=True to reject unknown parameters. clamp=True (default) auto-clamps to valid ranges.
    history_name creates a named undo step in Lightroom.
    """
    response = await _apply_validated_settings(
        settings,
        local_ids=local_ids,
        strict=strict,
        clamp=clamp,
        history_name=history_name,
    )
    return response


@mcp.tool()
async def set_develop_param(
    parameter: str,
    value: Any,
    local_ids: list[int] | None = None,
    strict: bool = False,
    clamp: bool = True,
    history_name: str | None = None,
) -> dict[str, Any]:
    """Set a single develop parameter across selected photos or local_ids."""
    if not parameter:
        raise ValueError("parameter is required")

    response = await _apply_validated_settings(
        {parameter: value},
        local_ids=local_ids,
        strict=strict,
        clamp=clamp,
        history_name=history_name,
    )
    response["parameter"] = parameter
    response["value"] = response["applied_settings"][parameter]
    return response


@mcp.tool()
async def list_develop_groups() -> dict[str, Any]:
    """List grouped develop parameter sets for faster targeted edits."""
    groups = list_group_descriptions()
    return {
        "count": len(groups),
        "groups": groups,
    }


@mcp.tool()
async def get_develop_group_settings(
    group: str,
    local_ids: list[int] | None = None,
) -> dict[str, Any]:
    """Get only the settings for one named develop group."""
    canonical, parameters = get_group_parameters(group)
    response = await get_develop_settings(local_ids=local_ids)
    settings = response.get("settings") or {}
    if not isinstance(settings, dict):
        raise RuntimeError("Lightroom returned an invalid settings payload")

    grouped = {name: settings[name] for name in parameters if name in settings}
    missing = [name for name in parameters if name not in grouped]
    return {
        "group": canonical,
        "local_id": response.get("local_id"),
        "parameter_count": len(parameters),
        "settings": grouped,
        "missing_parameters": missing,
    }


@mcp.tool()
async def set_develop_group(
    group: str,
    values: dict[str, Any],
    local_ids: list[int] | None = None,
    strict: bool = False,
    clamp: bool = True,
    history_name: str | None = None,
) -> dict[str, Any]:
    """Apply a partial update to one develop parameter group."""
    canonical, scoped_values = validate_group_values(group, values)
    response = await _apply_validated_settings(
        scoped_values,
        local_ids=local_ids,
        strict=strict,
        clamp=clamp,
        history_name=history_name or f"MCP Group: {canonical}",
    )
    response["group"] = canonical
    return response


@mcp.tool()
async def list_develop_presets() -> dict[str, Any]:
    """List built-in editing presets that can be applied in one call."""
    presets = list_preset_descriptions()
    return {
        "count": len(presets),
        "presets": presets,
    }


@mcp.tool()
async def apply_develop_preset(
    preset: str,
    local_ids: list[int] | None = None,
    overrides: dict[str, Any] | None = None,
    strict: bool = False,
    clamp: bool = True,
    history_name: str | None = None,
) -> dict[str, Any]:
    """Apply a named preset with optional parameter overrides."""
    preset_name, settings = merge_preset_overrides(preset, overrides)
    response = await _apply_validated_settings(
        settings,
        local_ids=local_ids,
        strict=strict,
        clamp=clamp,
        history_name=history_name or f"MCP Preset: {preset_name}",
    )
    response["preset"] = preset_name
    return response


@mcp.tool()
async def batch_apply_develop_operations(
    operations: list[dict[str, Any]],
    default_local_ids: list[int] | None = None,
    strict: bool = False,
    clamp: bool = True,
    stop_on_error: bool = False,
) -> dict[str, Any]:
    """Run multiple preset/settings/parameter/group operations in sequence.

    Each operation is a dict with one of: preset, settings, parameter, or group.
    Examples:
      [{"preset": "portrait_clean"}, {"settings": {"Exposure": 0.3}}, {"parameter": "Contrast", "value": 20}]
    Operations run in order. Use stop_on_error=True to halt on first failure.
    default_local_ids applies to all operations unless overridden per-operation.
    """
    if not isinstance(operations, list) or not operations:
        raise ValueError("operations must be a non-empty list")

    results: list[dict[str, Any]] = []
    succeeded = 0
    failed = 0

    for index, operation in enumerate(operations):
        if not isinstance(operation, dict):
            err = "operation must be an object"
            failed += 1
            results.append({"index": index, "success": False, "error": err})
            if stop_on_error:
                break
            continue

        try:
            mode, settings, target = _resolve_batch_operation(operation)
            op_local_ids = operation.get("local_ids", default_local_ids)
            op_history = operation.get("history_name")
            if op_history is not None and not isinstance(op_history, str):
                raise ValueError("history_name must be a string when provided")

            response = await _apply_validated_settings(
                settings,
                local_ids=op_local_ids,
                strict=strict,
                clamp=clamp,
                history_name=op_history,
            )
            record: dict[str, Any] = {
                "index": index,
                "success": True,
                "mode": mode,
                "result": response,
            }
            if target:
                record["target"] = target
            results.append(record)
            succeeded += 1
        except Exception as exc:
            failed += 1
            results.append(
                {
                    "index": index,
                    "success": False,
                    "error": str(exc),
                }
            )
            if stop_on_error:
                break

    return {
        "requested": len(operations),
        "succeeded": succeeded,
        "failed": failed,
        "stop_on_error": bool(stop_on_error),
        "results": results,
    }


@mcp.tool()
async def auto_tone(local_ids: list[int] | None = None) -> dict[str, Any]:
    """Run Auto Tone style adjustments for selected photos or local_ids."""
    ids = validate_local_ids(local_ids)
    payload = {"local_ids": ids} if ids else {}
    return await _call("develop.auto_tone", payload)


@mcp.tool()
async def auto_white_balance(local_ids: list[int] | None = None) -> dict[str, Any]:
    """Set white balance to Auto for selected photos or local_ids."""
    ids = validate_local_ids(local_ids)
    payload = {"local_ids": ids} if ids else {}
    return await _call("develop.auto_white_balance", payload)


@mcp.tool()
async def reset_current_photo() -> dict[str, Any]:
    """Reset all develop adjustments on the currently active photo."""
    return await _call("develop.reset_current_photo")


@mcp.tool()
async def set_rating(rating: int, local_ids: list[int] | None = None) -> dict[str, Any]:
    """Set Lightroom star rating (0..5)."""
    payload = {
        "rating": validate_rating(rating),
    }
    ids = validate_local_ids(local_ids)
    if ids:
        payload["local_ids"] = ids
    return await _call("metadata.set_rating", payload)


@mcp.tool()
async def set_label(label: str, local_ids: list[int] | None = None) -> dict[str, Any]:
    """Set Lightroom color label name (or empty string to clear)."""
    if label is None:
        raise ValueError("label must be a string")
    payload: dict[str, Any] = {"label": str(label)}
    ids = validate_local_ids(local_ids)
    if ids:
        payload["local_ids"] = ids
    return await _call("metadata.set_label", payload)


@mcp.tool()
async def set_pick_status(status: int, local_ids: list[int] | None = None) -> dict[str, Any]:
    """Set pick flag: -1 reject, 0 unflag, 1 pick."""
    payload = {
        "status": validate_pick_status(status),
    }
    ids = validate_local_ids(local_ids)
    if ids:
        payload["local_ids"] = ids
    return await _call("metadata.set_pick_status", payload)


@mcp.tool()
async def set_title(title: str, local_ids: list[int] | None = None) -> dict[str, Any]:
    """Set Lightroom title metadata for selected photos or local_ids."""
    payload: dict[str, Any] = {"title": str(title)}
    ids = validate_local_ids(local_ids)
    if ids:
        payload["local_ids"] = ids
    return await _call("metadata.set_title", payload)


@mcp.tool()
async def set_caption(caption: str, local_ids: list[int] | None = None) -> dict[str, Any]:
    """Set Lightroom caption metadata for selected photos or local_ids."""
    payload: dict[str, Any] = {"caption": str(caption)}
    ids = validate_local_ids(local_ids)
    if ids:
        payload["local_ids"] = ids
    return await _call("metadata.set_caption", payload)


@mcp.tool()
async def get_keywords(local_ids: list[int] | None = None) -> dict[str, Any]:
    """Get keywords assigned to selected photos or specific photos by local_ids."""
    payload: dict[str, Any] = {}
    ids = validate_local_ids(local_ids)
    if ids:
        payload["local_ids"] = ids
    return await _call("metadata.get_keywords", payload)


@mcp.tool()
async def add_keywords(keywords: list[str], local_ids: list[int] | None = None) -> dict[str, Any]:
    """Add keywords (supports hierarchical format: A > B > C)."""
    if not keywords:
        raise ValueError("keywords cannot be empty")
    payload: dict[str, Any] = {"keywords": [str(k) for k in keywords]}
    ids = validate_local_ids(local_ids)
    if ids:
        payload["local_ids"] = ids
    return await _call("metadata.add_keywords", payload)


@mcp.tool()
async def remove_keywords(keywords: list[str], local_ids: list[int] | None = None) -> dict[str, Any]:
    """Remove keywords by name/path from selected photos or local_ids."""
    if not keywords:
        raise ValueError("keywords cannot be empty")
    payload: dict[str, Any] = {"keywords": [str(k) for k in keywords]}
    ids = validate_local_ids(local_ids)
    if ids:
        payload["local_ids"] = ids
    return await _call("metadata.remove_keywords", payload)


# ── Mask / Local Adjustment Tools ──────────────────────────────────


@mcp.tool()
async def select_mask_tool(tool: str) -> dict[str, Any]:
    """Select a mask tool: brush, graduated-filter, radial-filter, or range-mask."""
    if not tool:
        raise ValueError("tool is required")
    return await _call("masks.select_tool", {"tool": tool})


@mcp.tool()
async def create_ai_mask(
    mask_type: str,
    operation: str = "new",
) -> dict[str, Any]:
    """Create an AI-powered mask on the active photo.

    mask_type: subject, sky, background, person, object, depth, luminance, color
    operation: new (default), add, subtract, intersect
    """
    if not mask_type:
        raise ValueError("mask_type is required")
    return await _call("masks.create_ai_mask", {
        "mask_type": mask_type,
        "operation": operation,
    })


@mcp.tool()
async def select_mask(mask_id: int) -> dict[str, Any]:
    """Select an existing mask by its numeric ID."""
    return await _call("masks.select_mask", {"mask_id": mask_id})


@mcp.tool()
async def get_local_adjustment_settings() -> dict[str, Any]:
    """Read local_* adjustment parameters on the currently active mask.

    Returns values for local_Exposure, local_Contrast, local_Highlights, etc.
    A mask must be active (selected) first.
    """
    return await _call("masks.get_local_settings")


@mcp.tool()
async def apply_local_adjustment_settings(settings: dict[str, Any]) -> dict[str, Any]:
    """Set local_* adjustment parameters on the currently active mask.

    Settings dict uses local_* parameter names, e.g.:
    {"local_Exposure": 1.5, "local_Contrast": 25, "local_Clarity": 40}
    A mask must be active (selected) first.
    """
    if not settings:
        raise ValueError("settings dict is required")
    return await _call("masks.set_local_settings", {"settings": settings})


@mcp.tool()
async def toggle_mask_overlay() -> dict[str, Any]:
    """Toggle the mask overlay visualization on/off."""
    return await _call("masks.toggle_overlay")


@mcp.tool()
async def invert_mask(mask_id: int | None = None) -> dict[str, Any]:
    """Invert the active mask (or a specific mask by ID)."""
    payload: dict[str, Any] = {}
    if mask_id is not None:
        payload["mask_id"] = mask_id
    return await _call("masks.toggle_invert", payload)


@mcp.tool()
async def list_local_params() -> dict[str, Any]:
    """List available local_* adjustment parameters for masks."""
    return await _call("masks.list_local_params")


# ── Undo / Redo Tools ──────────────────────────────────────────────


@mcp.tool()
async def undo() -> dict[str, Any]:
    """Undo the last Lightroom operation."""
    return await _call("system.undo")


@mcp.tool()
async def redo() -> dict[str, Any]:
    """Redo the last undone Lightroom operation."""
    return await _call("system.redo")


@mcp.tool()
async def can_undo() -> dict[str, Any]:
    """Check if undo/redo operations are available."""
    return await _call("system.can_undo")


# ── Snapshot Tools ─────────────────────────────────────────────────


@mcp.tool()
async def create_snapshot(
    name: str,
    local_ids: list[int] | None = None,
) -> dict[str, Any]:
    """Create a named develop snapshot for the active photo."""
    if not name:
        raise ValueError("name is required")
    ids = validate_local_ids(local_ids)
    payload: dict[str, Any] = {"name": name}
    if ids:
        payload["local_ids"] = ids
    return await _call("develop.create_snapshot", payload)


@mcp.tool()
async def list_snapshots(local_ids: list[int] | None = None) -> dict[str, Any]:
    """List develop snapshots for the active photo."""
    ids = validate_local_ids(local_ids)
    payload: dict[str, Any] = {}
    if ids:
        payload["local_ids"] = ids
    return await _call("develop.list_snapshots", payload)


@mcp.tool()
async def apply_snapshot(
    snapshot_id: str,
    local_ids: list[int] | None = None,
) -> dict[str, Any]:
    """Apply a develop snapshot by its ID."""
    if not snapshot_id:
        raise ValueError("snapshot_id is required")
    ids = validate_local_ids(local_ids)
    payload: dict[str, Any] = {"snapshot_id": snapshot_id}
    if ids:
        payload["local_ids"] = ids
    return await _call("develop.apply_snapshot", payload)


@mcp.tool()
async def delete_snapshot(
    snapshot_id: str,
    local_ids: list[int] | None = None,
) -> dict[str, Any]:
    """Delete a develop snapshot by its ID."""
    if not snapshot_id:
        raise ValueError("snapshot_id is required")
    ids = validate_local_ids(local_ids)
    payload: dict[str, Any] = {"snapshot_id": snapshot_id}
    if ids:
        payload["local_ids"] = ids
    return await _call("develop.delete_snapshot", payload)


# ── Collection Tools ───────────────────────────────────────────────


@mcp.tool()
async def list_collections() -> dict[str, Any]:
    """List all collections and collection sets in the catalog."""
    return await _call("catalog.list_collections")


@mcp.tool()
async def create_collection(name: str, parent_id: int | None = None) -> dict[str, Any]:
    """Create a new collection (optionally inside a collection set)."""
    if not name:
        raise ValueError("name is required")
    payload: dict[str, Any] = {"name": name}
    if parent_id is not None:
        payload["parent_id"] = parent_id
    return await _call("catalog.create_collection", payload)


@mcp.tool()
async def add_to_collection(
    collection_id: int,
    local_ids: list[int] | None = None,
) -> dict[str, Any]:
    """Add selected photos (or specific local_ids) to a collection."""
    ids = validate_local_ids(local_ids)
    payload: dict[str, Any] = {"collection_id": collection_id}
    if ids:
        payload["local_ids"] = ids
    return await _call("catalog.add_to_collection", payload)


@mcp.tool()
async def remove_from_collection(
    collection_id: int,
    local_ids: list[int] | None = None,
) -> dict[str, Any]:
    """Remove selected photos (or specific local_ids) from a collection."""
    ids = validate_local_ids(local_ids)
    payload: dict[str, Any] = {"collection_id": collection_id}
    if ids:
        payload["local_ids"] = ids
    return await _call("catalog.remove_from_collection", payload)


@mcp.tool()
async def delete_collection(collection_id: int) -> dict[str, Any]:
    """Delete a collection by its ID."""
    return await _call("catalog.delete_collection", {"collection_id": collection_id})


# ── Smart Collection Tools ─────────────────────────────────────────


SMART_COLLECTION_RULES_DOC = """
Rules format: each rule is a dict with criteria, operation, and value.

Combine modes: "intersect" (AND), "union" (OR), "exclude" (NONE).

Common criteria and operations:
  rating: ==, !=, >, <, >=, <= (value: 0-5)
  pick: ==, != (value: 1=flagged, 0=unflagged, -1=rejected)
  captureTime: ==, >, <, in, inLast, notInLast, today, yesterday, thisWeek, thisMonth, thisYear
    Date values: "YYYY-MM-DD". For inLast/notInLast: value=number, value_units="days"|"weeks"|"months"|"years"
  keywords: any, all, words, noneOf, ==, !=, empty, notEmpty (value: string)
  filename, title, caption: any, all, beginsWith, endsWith, ==, != (value: string)
  camera: ==, != (value: string, exact model name)
  lens: ==, != (value: string, exact lens name)
  labelColor: ==, != (value: 1=red, 2=yellow, 3=green, 4=blue, 5=purple)
  fileFormat: ==, != (value: "DNG", "RAW", "JPG", "TIFF", "PSD", "VIDEO")
  treatment: ==, != (value: "grayscale", "color")
  hasGPSData, hasAdjustments: isTrue, isFalse
  isoSpeedRating: ==, !=, >, <, >=, <=, in (value: number)

Example rules:
  [{"criteria": "rating", "operation": ">=", "value": 3}]
  [{"criteria": "captureTime", "operation": "inLast", "value": 30, "value_units": "days"}]
  [{"criteria": "keywords", "operation": "any", "value": "landscape"}]
"""


@mcp.tool()
async def create_smart_collection(
    name: str,
    rules: list[dict[str, Any]],
    combine: str = "intersect",
    parent_id: int | None = None,
) -> dict[str, Any]:
    f"""Create a smart collection with search rules.
    {SMART_COLLECTION_RULES_DOC}
    Args:
        name: Collection name.
        rules: Array of search criteria dicts.
        combine: How to combine rules - "intersect" (AND), "union" (OR), or "exclude" (NONE).
        parent_id: Optional parent collection set ID.
    """
    if not name:
        raise ValueError("name is required")
    if not rules:
        raise ValueError("rules are required")
    payload: dict[str, Any] = {"name": name, "rules": rules, "combine": combine}
    if parent_id is not None:
        payload["parent_id"] = parent_id
    return await _call("catalog.create_smart_collection", payload)


@mcp.tool()
async def get_smart_collection_rules(collection_id: int) -> dict[str, Any]:
    """Get the search rules of a smart collection.

    Args:
        collection_id: The local ID of the smart collection.
    """
    return await _call(
        "catalog.get_smart_collection_rules", {"collection_id": collection_id}
    )


@mcp.tool()
async def update_smart_collection(
    collection_id: int,
    rules: list[dict[str, Any]],
    combine: str = "intersect",
) -> dict[str, Any]:
    f"""Update the search rules of a smart collection.
    {SMART_COLLECTION_RULES_DOC}
    Args:
        collection_id: The local ID of the smart collection.
        rules: New array of search criteria dicts (replaces all existing rules).
        combine: How to combine rules - "intersect" (AND), "union" (OR), or "exclude" (NONE).
    """
    if not rules:
        raise ValueError("rules are required")
    return await _call(
        "catalog.update_smart_collection",
        {"collection_id": collection_id, "rules": rules, "combine": combine},
    )


# ── Virtual Copy / Rotation / Preset Tools ─────────────────────────


@mcp.tool()
async def create_virtual_copy(local_ids: list[int] | None = None) -> dict[str, Any]:
    """Create virtual copies of selected photos or specific local_ids."""
    ids = validate_local_ids(local_ids)
    payload: dict[str, Any] = {}
    if ids:
        payload["local_ids"] = ids
    return await _call("catalog.create_virtual_copy", payload)


@mcp.tool()
async def rotate_left(local_ids: list[int] | None = None) -> dict[str, Any]:
    """Rotate selected photos 90 degrees left."""
    ids = validate_local_ids(local_ids)
    payload: dict[str, Any] = {}
    if ids:
        payload["local_ids"] = ids
    return await _call("metadata.rotate_left", payload)


@mcp.tool()
async def rotate_right(local_ids: list[int] | None = None) -> dict[str, Any]:
    """Rotate selected photos 90 degrees right."""
    ids = validate_local_ids(local_ids)
    payload: dict[str, Any] = {}
    if ids:
        payload["local_ids"] = ids
    return await _call("metadata.rotate_right", payload)


@mcp.tool()
async def list_lightroom_presets() -> dict[str, Any]:
    """List Lightroom's built-in and user-created develop presets."""
    return await _call("develop.list_lr_presets")


@mcp.tool()
async def apply_lightroom_preset(
    preset_uuid: str,
    local_ids: list[int] | None = None,
) -> dict[str, Any]:
    """Apply a Lightroom develop preset by its UUID."""
    if not preset_uuid:
        raise ValueError("preset_uuid is required")
    ids = validate_local_ids(local_ids)
    payload: dict[str, Any] = {"uuid": preset_uuid}
    if ids:
        payload["local_ids"] = ids
    return await _call("develop.apply_lr_preset", payload)


@mcp.tool()
async def toggle_lens_blur_depth_viz() -> dict[str, Any]:
    """Toggle the lens blur depth visualization overlay."""
    return await _call("develop.toggle_lens_blur_depth_viz")


@mcp.tool()
async def set_lens_blur_bokeh(bokeh: str) -> dict[str, Any]:
    """Set the lens blur bokeh shape."""
    if not bokeh:
        raise ValueError("bokeh shape is required")
    return await _call("develop.set_lens_blur_bokeh", {"bokeh": bokeh})


@mcp.tool()
async def export_photos(
    destination: str,
    local_ids: list[int] | None = None,
    quality: int = 85,
) -> dict[str, Any]:
    """Export photos as JPG to a destination folder.

    Exports selected photos (or specific local_ids) with all develop
    edits applied as sRGB JPEG files to the given folder path.
    Creates the folder if it doesn't exist.
    """
    if not destination:
        raise ValueError("destination folder path is required")
    ids = validate_local_ids(local_ids)
    payload: dict[str, Any] = {
        "destination": destination,
        "quality": max(1, min(100, quality)),
    }
    if ids:
        payload["local_ids"] = ids
    return await _call("catalog.export_photos", payload, timeout_s=300.0)


@mcp.tool()
async def send_raw_lightroom_command(command: str, params: dict[str, Any] | None = None) -> dict[str, Any]:
    """Send a raw command to the plugin (advanced/debug use)."""
    if not command:
        raise ValueError("command is required")
    return await _call(command, params or {})


def main() -> None:
    transport = os.getenv("LIGHTROOM_MCP_TRANSPORT", "stdio")
    if transport not in {"stdio", "sse", "streamable-http"}:
        raise ValueError("LIGHTROOM_MCP_TRANSPORT must be stdio, sse, or streamable-http")
    mcp.run(transport=transport)


if __name__ == "__main__":
    # FastMCP internally handles its own event loop.
    main()
