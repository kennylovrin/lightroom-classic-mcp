local LrDevelopController = import "LrDevelopController"
local LrTasks = import "LrTasks"

local Logger = require "Logger"

local MaskActions = {}

-- Local adjustment parameters available on masks
local LOCAL_PARAMS = {
    "local_Exposure",
    "local_Contrast",
    "local_Highlights",
    "local_Shadows",
    "local_Whites",
    "local_Blacks",
    "local_Clarity",
    "local_Dehaze",
    "local_Saturation",
    "local_Vibrance",
    "local_Temperature",
    "local_Tint",
    "local_Sharpness",
    "local_LuminanceNoise",
    "local_Moire",
    "local_Defringe",
    "local_ToningHue",
    "local_ToningSaturation",
    "local_Texture",
}

local VALID_TOOLS = {
    brush = true,
    ["graduated-filter"] = true,
    ["radial-filter"] = true,
    ["range-mask"] = true,
}

-- AI selection subtypes use maskType="aiSelection" with a subtype
local AI_SUBTYPES = {
    subject = true,
    sky = true,
    background = true,
    person = true,
    object = true,
}

-- Range mask types use their own maskType directly
local RANGE_MASK_TYPES = {
    depth = true,
    luminance = true,
    color = true,
}

-- Combined for validation
local VALID_MASK_TYPES = {
    subject = true,
    sky = true,
    background = true,
    person = true,
    object = true,
    depth = true,
    luminance = true,
    color = true,
}

local VALID_OPERATIONS = {
    add = true,
    subtract = true,
    intersect = true,
    new = true,
}

function MaskActions.selectTool(params)
    if not params or type(params.tool) ~= "string" or params.tool == "" then
        error("tool is required (brush, graduated-filter, radial-filter, range-mask)")
    end

    local tool = params.tool
    if not VALID_TOOLS[tool] then
        error("Unknown tool: " .. tool .. ". Valid: brush, graduated-filter, radial-filter, range-mask")
    end

    local ok, err = pcall(function()
        LrDevelopController.selectTool(tool)
    end)

    if not ok then
        error("selectTool failed: " .. tostring(err))
    end

    return {
        tool = tool,
        selected = true,
    }
end

function MaskActions.createAIMask(params)
    if not params or type(params.mask_type) ~= "string" or params.mask_type == "" then
        error("mask_type is required (subject, sky, background, person, object, depth, luminance, color)")
    end

    local maskType = params.mask_type
    if not VALID_MASK_TYPES[maskType] then
        error("Unknown mask_type: " .. maskType)
    end

    local operation = params.operation or "new"
    if not VALID_OPERATIONS[operation] then
        error("Unknown operation: " .. operation .. ". Valid: new, add, subtract, intersect")
    end

    -- Determine SDK maskType and subtype
    local sdkMaskType, sdkSubtype
    if AI_SUBTYPES[maskType] then
        sdkMaskType = "aiSelection"
        sdkSubtype = maskType
    elseif RANGE_MASK_TYPES[maskType] then
        sdkMaskType = "rangeMask"
        sdkSubtype = maskType
    else
        sdkMaskType = maskType
        sdkSubtype = nil
    end

    local ok, err = pcall(function()
        if operation == "new" or operation == "add" then
            LrDevelopController.addToCurrentMask(sdkMaskType, sdkSubtype)
        elseif operation == "subtract" then
            LrDevelopController.subtractFromCurrentMask(sdkMaskType, sdkSubtype)
        elseif operation == "intersect" then
            LrDevelopController.intersectWithCurrentMask(sdkMaskType, sdkSubtype)
        end
    end)

    if not ok then
        error("createAIMask failed: " .. tostring(err))
    end

    return {
        mask_type = maskType,
        operation = operation,
        created = true,
    }
end

function MaskActions.selectMask(params)
    if not params or params.mask_id == nil then
        error("mask_id is required")
    end

    local maskId = tonumber(params.mask_id)
    if not maskId then
        error("mask_id must be a number")
    end

    local ok, err = pcall(function()
        LrDevelopController.selectMask(maskId)
    end)

    if not ok then
        error("selectMask failed: " .. tostring(err))
    end

    return {
        mask_id = maskId,
        selected = true,
    }
end

function MaskActions.toggleOverlay(params)
    local ok, err = pcall(function()
        LrDevelopController.toggleOverlay()
    end)

    if not ok then
        error("toggleOverlay failed: " .. tostring(err))
    end

    return {
        toggled = true,
    }
end

function MaskActions.toggleInvert(params)
    local maskId = nil
    if params and params.mask_id ~= nil then
        maskId = tonumber(params.mask_id)
    end

    local ok, err = pcall(function()
        if maskId then
            LrDevelopController.toggleInvertMaskTool(maskId)
        else
            LrDevelopController.toggleInvertMaskTool()
        end
    end)

    if not ok then
        error("toggleInvert failed: " .. tostring(err))
    end

    return {
        mask_id = maskId,
        inverted = true,
    }
end

function MaskActions.getLocalSettings(params)
    local settings = {}
    local errors = {}

    for _, param in ipairs(LOCAL_PARAMS) do
        local ok, value = pcall(function()
            return LrDevelopController.getValue(param)
        end)
        if ok and value ~= nil then
            settings[param] = value
        else
            errors[#errors + 1] = {
                param = param,
                error = tostring(value),
            }
        end
    end

    return {
        settings = settings,
        param_count = #LOCAL_PARAMS,
        errors = errors,
    }
end

function MaskActions.setLocalSettings(params)
    if not params or type(params.settings) ~= "table" then
        error("settings must be provided as a table of local_* parameter values")
    end

    local applied = {}
    local errors = {}

    for param, value in pairs(params.settings) do
        if type(param) == "string" and param:sub(1, 6) == "local_" then
            local ok, err = pcall(function()
                LrDevelopController.setValue(param, value)
            end)
            if ok then
                applied[#applied + 1] = param
            else
                errors[#errors + 1] = {
                    param = param,
                    error = tostring(err),
                }
            end
        else
            errors[#errors + 1] = {
                param = tostring(param),
                error = "parameter must start with local_",
            }
        end
    end

    return {
        applied = applied,
        applied_count = #applied,
        errors = errors,
    }
end

function MaskActions.listLocalParams(params)
    return {
        parameters = LOCAL_PARAMS,
        count = #LOCAL_PARAMS,
    }
end

return MaskActions
