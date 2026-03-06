from __future__ import annotations

from typing import Any, Final

from .develop_params import BOOL_PARAMS, ENUM_PARAMS, PARAM_RANGES

DEVELOP_GROUPS: Final[dict[str, tuple[str, ...]]] = {
    "basic_tone": (
        "Exposure",
        "Contrast",
        "Highlights",
        "Shadows",
        "Whites",
        "Blacks",
        "Exposure2012",
        "Contrast2012",
        "Highlights2012",
        "Shadows2012",
        "Whites2012",
        "Blacks2012",
    ),
    "white_balance_color": (
        "WhiteBalance",
        "Temperature",
        "Tint",
        "Vibrance",
        "Saturation",
    ),
    "presence": (
        "Texture",
        "Clarity",
        "Clarity2012",
        "Dehaze",
    ),
    "tone_curve": (
        "ParametricShadows",
        "ParametricDarks",
        "ParametricLights",
        "ParametricHighlights",
        "ParametricShadowSplit",
        "ParametricMidtoneSplit",
        "ParametricHighlightSplit",
    ),
    "hsl_hue": (
        "HueAdjustmentRed",
        "HueAdjustmentOrange",
        "HueAdjustmentYellow",
        "HueAdjustmentGreen",
        "HueAdjustmentAqua",
        "HueAdjustmentBlue",
        "HueAdjustmentPurple",
        "HueAdjustmentMagenta",
    ),
    "hsl_saturation": (
        "SaturationAdjustmentRed",
        "SaturationAdjustmentOrange",
        "SaturationAdjustmentYellow",
        "SaturationAdjustmentGreen",
        "SaturationAdjustmentAqua",
        "SaturationAdjustmentBlue",
        "SaturationAdjustmentPurple",
        "SaturationAdjustmentMagenta",
    ),
    "hsl_luminance": (
        "LuminanceAdjustmentRed",
        "LuminanceAdjustmentOrange",
        "LuminanceAdjustmentYellow",
        "LuminanceAdjustmentGreen",
        "LuminanceAdjustmentAqua",
        "LuminanceAdjustmentBlue",
        "LuminanceAdjustmentPurple",
        "LuminanceAdjustmentMagenta",
    ),
    "bw_mix": (
        "GrayMixerRed",
        "GrayMixerOrange",
        "GrayMixerYellow",
        "GrayMixerGreen",
        "GrayMixerAqua",
        "GrayMixerBlue",
        "GrayMixerPurple",
        "GrayMixerMagenta",
    ),
    "color_grading": (
        "SplitToningShadowHue",
        "SplitToningShadowSaturation",
        "SplitToningHighlightHue",
        "SplitToningHighlightSaturation",
        "SplitToningBalance",
        "ColorGradeGlobalHue",
        "ColorGradeGlobalSat",
        "ColorGradeGlobalLum",
        "ColorGradeShadowHue",
        "ColorGradeShadowSat",
        "ColorGradeMidtoneHue",
        "ColorGradeMidtoneSat",
        "ColorGradeMidtoneLum",
        "ColorGradeHighlightHue",
        "ColorGradeHighlightSat",
        "ColorGradeShadowLum",
        "ColorGradeHighlightLum",
        "ColorGradeBlending",
    ),
    "detail_noise": (
        "Sharpness",
        "SharpenRadius",
        "SharpenDetail",
        "SharpenEdgeMasking",
        "LuminanceSmoothing",
        "LuminanceNoiseReductionDetail",
        "LuminanceNoiseReductionContrast",
        "ColorNoiseReduction",
        "ColorNoiseReductionDetail",
        "ColorNoiseReductionSmoothness",
    ),
    "effects_grain_vignette": (
        "PostCropVignetteAmount",
        "PostCropVignetteMidpoint",
        "PostCropVignetteFeather",
        "PostCropVignetteRoundness",
        "PostCropVignetteHighlightContrast",
        "GrainAmount",
        "GrainSize",
        "GrainFrequency",
    ),
    "optics": (
        "EnableProfileCorrections",
        "RemoveChromaticAberration",
        "LensManualDistortionAmount",
        "LensProfileDistortionScale",
        "LensProfileVignettingScale",
        "DefringePurpleAmount",
        "DefringePurpleHueLo",
        "DefringePurpleHueHi",
        "DefringeGreenAmount",
        "DefringeGreenHueLo",
        "DefringeGreenHueHi",
        "VignetteAmount",
        "VignetteMidpoint",
    ),
    "transform": (
        "PerspectiveVertical",
        "PerspectiveHorizontal",
        "PerspectiveRotate",
        "PerspectiveScale",
        "PerspectiveAspect",
        "PerspectiveUpright",
        "PerspectiveX",
        "PerspectiveY",
    ),
    "crop": (
        "CropTop",
        "CropLeft",
        "CropBottom",
        "CropRight",
        "CropAngle",
    ),
    "calibration": (
        "ShadowTint",
        "RedHue",
        "RedSaturation",
        "GreenHue",
        "GreenSaturation",
        "BlueHue",
        "BlueSaturation",
    ),
    "ai_lens_blur": (
        "LensBlurActive",
        "LensBlurAmount",
        "LensBlurHighlightsBoost",
        "LensBlurFocalRange",
        "LensBlurCatEye",
    ),
    "auto_flags": (
        "AutoExposure",
        "AutoContrast",
        "AutoShadows",
        "AutoBrightness",
    ),
}

GROUP_ALIASES: Final[dict[str, str]] = {
    "basic": "basic_tone",
    "tone": "basic_tone",
    "wb": "white_balance_color",
    "color": "white_balance_color",
    "presence_detail": "presence",
    "hsl": "hsl_saturation",
    "detail": "detail_noise",
    "effects": "effects_grain_vignette",
    "lens": "optics",
    "geometry": "transform",
    "blur": "ai_lens_blur",
    "auto": "auto_flags",
}

DEVELOP_PRESETS: Final[dict[str, dict[str, Any]]] = {
    "portrait_clean": {
        "Exposure": 0.25,
        "Highlights": -25,
        "Shadows": 20,
        "Texture": -10,
        "Clarity": -5,
        "Vibrance": 8,
        "Sharpness": 40,
        "LuminanceSmoothing": 15,
        "EnableProfileCorrections": True,
        "RemoveChromaticAberration": True,
    },
    "landscape_pop": {
        "Exposure": 0.15,
        "Contrast": 12,
        "Highlights": -35,
        "Shadows": 25,
        "Whites": 18,
        "Blacks": -20,
        "Texture": 25,
        "Clarity": 20,
        "Dehaze": 15,
        "Vibrance": 22,
        "Saturation": 5,
        "EnableProfileCorrections": True,
        "RemoveChromaticAberration": True,
    },
    "night_recovery": {
        "Exposure": 0.5,
        "Highlights": -45,
        "Shadows": 35,
        "Whites": 8,
        "Blacks": -12,
        "Clarity": 10,
        "Dehaze": 8,
        "LuminanceSmoothing": 30,
        "ColorNoiseReduction": 30,
        "ColorNoiseReductionDetail": 45,
    },
    "bw_crisp": {
        "ConvertToGrayscale": True,
        "Contrast": 20,
        "Highlights": -20,
        "Shadows": 20,
        "Whites": 15,
        "Blacks": -25,
        "Clarity": 18,
        "Texture": 10,
        "GrainAmount": 8,
        "GrainSize": 24,
        "GrainFrequency": 40,
    },
    "film_matte": {
        "Contrast": -8,
        "Highlights": -30,
        "Shadows": 22,
        "Whites": -20,
        "Blacks": 22,
        "Clarity": -8,
        "Vibrance": 10,
        "Saturation": -4,
        "GrainAmount": 20,
        "GrainSize": 28,
        "GrainFrequency": 52,
        "PostCropVignetteAmount": -8,
        "PostCropVignetteFeather": 70,
    },
    "product_clean": {
        "Exposure": 0.2,
        "Contrast": 6,
        "Highlights": -18,
        "Shadows": 12,
        "Whites": 16,
        "Blacks": -12,
        "Texture": 18,
        "Clarity": 8,
        "Dehaze": 4,
        "Sharpness": 55,
        "EnableProfileCorrections": True,
        "RemoveChromaticAberration": True,
    },
}

PRESET_ALIASES: Final[dict[str, str]] = {
    "portrait": "portrait_clean",
    "landscape": "landscape_pop",
    "night": "night_recovery",
    "bw": "bw_crisp",
    "black_white": "bw_crisp",
    "matte": "film_matte",
    "film": "film_matte",
    "product": "product_clean",
}

PRESET_DESCRIPTIONS: Final[dict[str, str]] = {
    "portrait_clean": "Softens skin texture slightly and lifts tones for portrait work.",
    "landscape_pop": "Adds depth, contrast, and color separation for scenery.",
    "night_recovery": "Recovers dark scenes with highlight control and denoise.",
    "bw_crisp": "Converts to black and white with crisp contrast and light grain.",
    "film_matte": "Creates a low-contrast matte film look with grain.",
    "product_clean": "Neutral crisp look for product and catalog photography.",
}


def _normalize_key(raw: str) -> str:
    return raw.strip().lower().replace("-", "_").replace(" ", "_")


def _resolve_name(raw_name: str, names: set[str], aliases: dict[str, str], *, kind: str) -> str:
    if not raw_name or not isinstance(raw_name, str):
        raise ValueError(f"{kind} name is required")

    normalized = _normalize_key(raw_name)
    if normalized in names:
        return normalized
    if normalized in aliases:
        return aliases[normalized]

    allowed = ", ".join(sorted(names))
    raise ValueError(f"unknown {kind} '{raw_name}'. Available {kind}s: {allowed}")


def resolve_group_name(raw_group: str) -> str:
    return _resolve_name(raw_group, set(DEVELOP_GROUPS), GROUP_ALIASES, kind="group")


def resolve_preset_name(raw_preset: str) -> str:
    return _resolve_name(raw_preset, set(DEVELOP_PRESETS), PRESET_ALIASES, kind="preset")


def get_group_parameters(raw_group: str) -> tuple[str, tuple[str, ...]]:
    canonical = resolve_group_name(raw_group)
    return canonical, DEVELOP_GROUPS[canonical]


def get_preset_settings(raw_preset: str) -> tuple[str, dict[str, Any]]:
    canonical = resolve_preset_name(raw_preset)
    return canonical, dict(DEVELOP_PRESETS[canonical])


def merge_preset_overrides(raw_preset: str, overrides: dict[str, Any] | None) -> tuple[str, dict[str, Any]]:
    canonical, settings = get_preset_settings(raw_preset)
    if overrides:
        settings.update(overrides)
    return canonical, settings


def validate_group_values(raw_group: str, values: dict[str, Any]) -> tuple[str, dict[str, Any]]:
    if not isinstance(values, dict) or not values:
        raise ValueError("values must be a non-empty dictionary")

    canonical, parameters = get_group_parameters(raw_group)
    allowed = set(parameters)
    invalid = [k for k in values if k not in allowed]
    if invalid:
        invalid_s = ", ".join(sorted(invalid))
        raise ValueError(f"unsupported parameters for group '{canonical}': {invalid_s}")

    return canonical, dict(values)


def describe_parameter(parameter: str) -> dict[str, Any]:
    if parameter in PARAM_RANGES:
        low, high = PARAM_RANGES[parameter]
        return {
            "parameter": parameter,
            "type": "number",
            "min": low,
            "max": high,
        }
    if parameter in BOOL_PARAMS:
        return {
            "parameter": parameter,
            "type": "boolean",
        }
    if parameter in ENUM_PARAMS:
        return {
            "parameter": parameter,
            "type": "enum",
            "allowed": sorted(ENUM_PARAMS[parameter]),
        }
    return {
        "parameter": parameter,
        "type": "passthrough",
    }


def list_group_descriptions() -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    for name in sorted(DEVELOP_GROUPS):
        params = DEVELOP_GROUPS[name]
        out.append(
            {
                "group": name,
                "parameter_count": len(params),
                "parameters": [describe_parameter(param) for param in params],
            }
        )
    return out


def list_preset_descriptions() -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    for name in sorted(DEVELOP_PRESETS):
        out.append(
            {
                "preset": name,
                "description": PRESET_DESCRIPTIONS.get(name),
                "parameter_count": len(DEVELOP_PRESETS[name]),
                "parameters": sorted(DEVELOP_PRESETS[name]),
            }
        )
    return out
