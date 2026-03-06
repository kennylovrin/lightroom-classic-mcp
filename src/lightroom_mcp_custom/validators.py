from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any

from .develop_params import BOOL_PARAMS, ENUM_PARAMS, KNOWN_PARAMS, PARAM_RANGES, PASSTHROUGH_PARAMS


@dataclass
class ValidationResult:
    sanitized: dict[str, Any]
    warnings: list[str] = field(default_factory=list)


def _to_float(value: Any) -> float:
    if isinstance(value, bool):
        raise TypeError("boolean is not a numeric develop value")
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, str):
        return float(value)
    raise TypeError(f"unsupported value type: {type(value).__name__}")


def _to_bool(value: Any) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, int):
        if value in (0, 1):
            return bool(value)
        raise ValueError("boolean numeric values must be 0 or 1")
    if isinstance(value, str):
        lowered = value.strip().lower()
        if lowered in {"1", "true", "yes", "on"}:
            return True
        if lowered in {"0", "false", "no", "off"}:
            return False
    raise TypeError(f"unsupported boolean value type/content: {value!r}")


def _to_enum(parameter: str, value: Any) -> str:
    if not isinstance(value, str):
        raise TypeError(f"{parameter} must be a string enum value")

    normalized = value.strip().lower()
    allowed = ENUM_PARAMS[parameter]
    canonical_by_lower = {item.lower(): item for item in allowed}
    if normalized not in canonical_by_lower:
        raise ValueError(
            f"{parameter} must be one of: {', '.join(sorted(allowed))}"
        )

    return canonical_by_lower[normalized]


def validate_develop_settings(
    settings: dict[str, Any],
    *,
    strict: bool = False,
    clamp: bool = True,
) -> ValidationResult:
    if not isinstance(settings, dict):
        raise TypeError("settings must be a dictionary")
    if not settings:
        raise ValueError("settings cannot be empty")

    sanitized: dict[str, Any] = {}
    warnings: list[str] = []

    for key, raw_value in settings.items():
        if not isinstance(key, str) or not key:
            raise ValueError("all setting keys must be non-empty strings")

        if key not in KNOWN_PARAMS and key not in PARAM_RANGES:
            if strict:
                raise ValueError(f"unsupported develop parameter: {key}")
            sanitized[key] = raw_value
            warnings.append(f"passing through unknown parameter '{key}' without range validation")
            continue

        if key in BOOL_PARAMS:
            sanitized[key] = _to_bool(raw_value)
            continue

        if key in ENUM_PARAMS:
            sanitized[key] = _to_enum(key, raw_value)
            continue

        if key in PASSTHROUGH_PARAMS:
            sanitized[key] = raw_value
            warnings.append(
                f"passing through known non-scalar parameter '{key}' without scalar validation"
            )
            continue

        low, high = PARAM_RANGES[key]
        value = _to_float(raw_value)

        if value < low or value > high:
            if clamp:
                clamped = min(max(value, low), high)
                warnings.append(
                    f"clamped {key} from {value} to {clamped} (allowed range {low}..{high})"
                )
                value = clamped
            else:
                raise ValueError(
                    f"{key} value {value} is outside allowed range {low}..{high}"
                )

        sanitized[key] = value

    return ValidationResult(sanitized=sanitized, warnings=warnings)


def validate_local_ids(local_ids: list[int] | None) -> list[int] | None:
    if local_ids is None:
        return None
    if not isinstance(local_ids, list):
        raise TypeError("local_ids must be a list of integers")
    out: list[int] = []
    for raw in local_ids:
        if isinstance(raw, bool):
            raise TypeError("local_ids cannot contain booleans")
        value = int(raw)
        if value <= 0:
            raise ValueError("local_ids must be positive integers")
        out.append(value)
    return out


def validate_rating(rating: int) -> int:
    value = int(rating)
    if value < 0 or value > 5:
        raise ValueError("rating must be in the range 0..5")
    return value


def validate_pick_status(status: int) -> int:
    value = int(status)
    if value not in (-1, 0, 1):
        raise ValueError("pick_status must be -1 (reject), 0 (unflag), or 1 (pick)")
    return value
