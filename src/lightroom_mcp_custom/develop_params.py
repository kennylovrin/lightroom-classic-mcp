"""Known develop parameter ranges for Lightroom Classic.

These tables intentionally focus on settings that are practical for MCP usage:
- scalar numeric values with clamping ranges
- boolean toggles
- small enum fields

Unknown keys can still be passed through when validation is non-strict.
"""

from __future__ import annotations

from typing import Final

PARAM_RANGES: Final[dict[str, tuple[float, float]]] = {
    # Basic
    "Temperature": (2000.0, 50000.0),
    "Tint": (-150.0, 150.0),
    "Exposure": (-5.0, 5.0),
    "Contrast": (-100.0, 100.0),
    "Highlights": (-100.0, 100.0),
    "Shadows": (-100.0, 100.0),
    "Whites": (-100.0, 100.0),
    "Blacks": (-100.0, 100.0),
    "Texture": (-100.0, 100.0),
    "Clarity": (-100.0, 100.0),
    "Dehaze": (-100.0, 100.0),
    "Vibrance": (-100.0, 100.0),
    "Saturation": (-100.0, 100.0),
    # Crop
    "CropTop": (0.0, 1.0),
    "CropLeft": (0.0, 1.0),
    "CropBottom": (0.0, 1.0),
    "CropRight": (0.0, 1.0),
    "CropAngle": (-45.0, 45.0),
    # PV2012
    "Exposure2012": (-5.0, 5.0),
    "Contrast2012": (-100.0, 100.0),
    "Highlights2012": (-100.0, 100.0),
    "Shadows2012": (-100.0, 100.0),
    "Whites2012": (-100.0, 100.0),
    "Blacks2012": (-100.0, 100.0),
    "Clarity2012": (-100.0, 100.0),
    # Tone curve parametric
    "ParametricDarks": (-100.0, 100.0),
    "ParametricLights": (-100.0, 100.0),
    "ParametricShadows": (-100.0, 100.0),
    "ParametricHighlights": (-100.0, 100.0),
    "ParametricShadowSplit": (5.0, 95.0),
    "ParametricMidtoneSplit": (5.0, 95.0),
    "ParametricHighlightSplit": (5.0, 95.0),
    # HSL hue
    "HueAdjustmentRed": (-100.0, 100.0),
    "HueAdjustmentOrange": (-100.0, 100.0),
    "HueAdjustmentYellow": (-100.0, 100.0),
    "HueAdjustmentGreen": (-100.0, 100.0),
    "HueAdjustmentAqua": (-100.0, 100.0),
    "HueAdjustmentBlue": (-100.0, 100.0),
    "HueAdjustmentPurple": (-100.0, 100.0),
    "HueAdjustmentMagenta": (-100.0, 100.0),
    # HSL saturation
    "SaturationAdjustmentRed": (-100.0, 100.0),
    "SaturationAdjustmentOrange": (-100.0, 100.0),
    "SaturationAdjustmentYellow": (-100.0, 100.0),
    "SaturationAdjustmentGreen": (-100.0, 100.0),
    "SaturationAdjustmentAqua": (-100.0, 100.0),
    "SaturationAdjustmentBlue": (-100.0, 100.0),
    "SaturationAdjustmentPurple": (-100.0, 100.0),
    "SaturationAdjustmentMagenta": (-100.0, 100.0),
    # HSL luminance
    "LuminanceAdjustmentRed": (-100.0, 100.0),
    "LuminanceAdjustmentOrange": (-100.0, 100.0),
    "LuminanceAdjustmentYellow": (-100.0, 100.0),
    "LuminanceAdjustmentGreen": (-100.0, 100.0),
    "LuminanceAdjustmentAqua": (-100.0, 100.0),
    "LuminanceAdjustmentBlue": (-100.0, 100.0),
    "LuminanceAdjustmentPurple": (-100.0, 100.0),
    "LuminanceAdjustmentMagenta": (-100.0, 100.0),
    # B&W mix
    "GrayMixerRed": (-100.0, 100.0),
    "GrayMixerOrange": (-100.0, 100.0),
    "GrayMixerYellow": (-100.0, 100.0),
    "GrayMixerGreen": (-100.0, 100.0),
    "GrayMixerAqua": (-100.0, 100.0),
    "GrayMixerBlue": (-100.0, 100.0),
    "GrayMixerPurple": (-100.0, 100.0),
    "GrayMixerMagenta": (-100.0, 100.0),
    # Color grading
    "SplitToningShadowHue": (0.0, 360.0),
    "SplitToningShadowSaturation": (0.0, 100.0),
    "SplitToningHighlightHue": (0.0, 360.0),
    "SplitToningHighlightSaturation": (0.0, 100.0),
    "SplitToningBalance": (-100.0, 100.0),
    "ColorGradeGlobalHue": (0.0, 360.0),
    "ColorGradeGlobalSat": (0.0, 100.0),
    "ColorGradeGlobalLum": (-100.0, 100.0),
    "ColorGradeShadowHue": (0.0, 360.0),
    "ColorGradeShadowSat": (0.0, 100.0),
    "ColorGradeMidtoneHue": (0.0, 360.0),
    "ColorGradeMidtoneSat": (0.0, 100.0),
    "ColorGradeMidtoneLum": (-100.0, 100.0),
    "ColorGradeHighlightHue": (0.0, 360.0),
    "ColorGradeHighlightSat": (0.0, 100.0),
    "ColorGradeShadowLum": (-100.0, 100.0),
    "ColorGradeHighlightLum": (-100.0, 100.0),
    "ColorGradeBlending": (0.0, 100.0),
    # Lens blur (newer Lightroom Classic versions)
    "LensBlurAmount": (0.0, 100.0),
    "LensBlurHighlightsBoost": (0.0, 100.0),
    "LensBlurFocalRange": (0.0, 100.0),
    "LensBlurCatEye": (0.0, 100.0),
    # Detail
    "Sharpness": (0.0, 150.0),
    "SharpenRadius": (0.5, 3.0),
    "SharpenDetail": (0.0, 100.0),
    "SharpenEdgeMasking": (0.0, 100.0),
    "LuminanceSmoothing": (0.0, 100.0),
    "LuminanceNoiseReductionDetail": (0.0, 100.0),
    "LuminanceNoiseReductionContrast": (0.0, 100.0),
    "ColorNoiseReduction": (0.0, 100.0),
    "ColorNoiseReductionDetail": (0.0, 100.0),
    "ColorNoiseReductionSmoothness": (0.0, 100.0),
    # Effects
    "PostCropVignetteAmount": (-100.0, 100.0),
    "PostCropVignetteMidpoint": (0.0, 100.0),
    "PostCropVignetteFeather": (0.0, 100.0),
    "PostCropVignetteRoundness": (-100.0, 100.0),
    "PostCropVignetteHighlightContrast": (0.0, 100.0),
    "GrainAmount": (0.0, 100.0),
    "GrainSize": (0.0, 100.0),
    "GrainFrequency": (0.0, 100.0),
    # Lens / transform / calibration
    "LensManualDistortionAmount": (-100.0, 100.0),
    "LensProfileDistortionScale": (0.0, 200.0),
    "LensProfileVignettingScale": (0.0, 200.0),
    "DefringePurpleAmount": (0.0, 20.0),
    "DefringePurpleHueLo": (30.0, 70.0),
    "DefringePurpleHueHi": (40.0, 100.0),
    "DefringeGreenAmount": (0.0, 20.0),
    "DefringeGreenHueLo": (0.0, 60.0),
    "DefringeGreenHueHi": (30.0, 100.0),
    "VignetteAmount": (-100.0, 100.0),
    "VignetteMidpoint": (0.0, 100.0),
    "PerspectiveVertical": (-100.0, 100.0),
    "PerspectiveHorizontal": (-100.0, 100.0),
    "PerspectiveRotate": (-10.0, 10.0),
    "PerspectiveScale": (50.0, 150.0),
    "PerspectiveAspect": (-100.0, 100.0),
    "PerspectiveUpright": (0.0, 5.0),
    "PerspectiveX": (-100.0, 100.0),
    "PerspectiveY": (-100.0, 100.0),
    "ShadowTint": (-100.0, 100.0),
    "RedHue": (-100.0, 100.0),
    "RedSaturation": (-100.0, 100.0),
    "GreenHue": (-100.0, 100.0),
    "GreenSaturation": (-100.0, 100.0),
    "BlueHue": (-100.0, 100.0),
    "BlueSaturation": (-100.0, 100.0),
}

BOOL_PARAMS: Final[set[str]] = {
    "AutoExposure",
    "AutoContrast",
    "AutoShadows",
    "AutoBrightness",
    "AutoLateralCA",
    "LensProfileEnable",
    "EnableProfileCorrections",
    "RemoveChromaticAberration",
    "ConvertToGrayscale",
    "LensBlurActive",
}

ENUM_PARAMS: Final[dict[str, set[str]]] = {
    "WhiteBalance": {
        "As Shot",
        "Auto",
        "Daylight",
        "Cloudy",
        "Shade",
        "Tungsten",
        "Fluorescent",
        "Flash",
        "Custom",
    },
}

# These are recognized settings but not validated numerically because they are
# complex/non-scalar (for example tone-curve arrays or profile identifiers).
PASSTHROUGH_PARAMS: Final[set[str]] = {
    "CameraProfile",
    "ProcessVersion",
    "ToneCurveName",
    "ToneCurveName2012",
    "ToneCurvePV",
    "ToneCurvePV2012",
    "ToneCurvePVRed",
    "ToneCurvePVGreen",
    "ToneCurvePVBlue",
    "ToneCurvePV2012Red",
    "ToneCurvePV2012Green",
    "ToneCurvePV2012Blue",
}

LOCAL_PARAMS: Final[dict[str, tuple[float, float]]] = {
    "local_Exposure": (-5.0, 5.0),
    "local_Contrast": (-100.0, 100.0),
    "local_Highlights": (-100.0, 100.0),
    "local_Shadows": (-100.0, 100.0),
    "local_Whites": (-100.0, 100.0),
    "local_Blacks": (-100.0, 100.0),
    "local_Clarity": (-100.0, 100.0),
    "local_Dehaze": (-100.0, 100.0),
    "local_Saturation": (-100.0, 100.0),
    "local_Vibrance": (-100.0, 100.0),
    "local_Temperature": (-100.0, 100.0),
    "local_Tint": (-100.0, 100.0),
    "local_Sharpness": (0.0, 100.0),
    "local_LuminanceNoise": (0.0, 100.0),
    "local_Moire": (0.0, 100.0),
    "local_Defringe": (0.0, 100.0),
    "local_ToningHue": (0.0, 360.0),
    "local_ToningSaturation": (0.0, 100.0),
    "local_Texture": (-100.0, 100.0),
}

KNOWN_PARAMS: Final[frozenset[str]] = frozenset(
    set(PARAM_RANGES)
    | set(BOOL_PARAMS)
    | set(ENUM_PARAMS)
    | set(PASSTHROUGH_PARAMS)
)
