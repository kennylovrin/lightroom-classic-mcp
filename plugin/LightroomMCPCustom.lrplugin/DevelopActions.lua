local LrApplication = import "LrApplication"
local LrDevelopController = import "LrDevelopController"
local LrTasks = import "LrTasks"
local hasAgDevelopParams, AgDevelopParams = pcall(import, "AgDevelopParams")
if not hasAgDevelopParams then
    AgDevelopParams = nil
end
local hasLrUndo, LrUndo = pcall(import, "LrUndo")
if not hasLrUndo then
    LrUndo = nil
end

local ActionUtils = require "ActionUtils"

local DevelopActions = {}

local function getKnownParameterNames()
    local out = {}
    if AgDevelopParams and type(AgDevelopParams.kParamInfo) == "table" then
        for key, _ in pairs(AgDevelopParams.kParamInfo) do
            if type(key) == "string" and key ~= "" then
                out[#out + 1] = key
            end
        end
    end
    table.sort(out)
    return out
end

function DevelopActions.getSettings(params)
    local catalog = ActionUtils.getCatalog()
    local primary = nil
    local settings = nil

    catalog:withReadAccessDo(function()
        primary = ActionUtils.getPrimaryPhoto(params)
        if primary then
            settings = primary:getDevelopSettings()
        end
    end)

    if not primary then
        error("No photo selected")
    end

    return {
        local_id = primary.localIdentifier,
        settings = settings,
    }
end

function DevelopActions.applySettings(params)
    if not params or type(params.settings) ~= "table" then
        error("settings must be provided as a table")
    end

    local catalog = ActionUtils.getCatalog()
    local photos = ActionUtils.resolvePhotos(params)
    if not photos or #photos == 0 then
        error("No target photos found")
    end

    local historyName = nil
    if params.history_name and type(params.history_name) == "string" and params.history_name ~= "" then
        historyName = params.history_name
    end

    local flattenAutoNow = false
    if params.flatten_auto_now == true then
        flattenAutoNow = true
    end

    local updated = 0
    local failures = {}

    catalog:withWriteAccessDo("MCP Apply Develop Settings", function()
        for _, photo in ipairs(photos) do
            local ok, err = LrTasks.pcall(function()
                photo:applyDevelopSettings(params.settings, historyName, flattenAutoNow)
            end)
            if ok then
                updated = updated + 1
            else
                failures[#failures + 1] = {
                    local_id = photo.localIdentifier,
                    error = tostring(err),
                }
            end
        end
    end)

    return {
        requested = #photos,
        updated = updated,
        failures = failures,
    }
end

function DevelopActions.setParam(params)
    if not params or type(params.parameter) ~= "string" or params.parameter == "" then
        error("parameter is required")
    end

    if params.value == nil then
        error("value is required")
    end

    return DevelopActions.applySettings({
        settings = {
            [params.parameter] = params.value,
        },
        local_ids = params.local_ids,
        history_name = params.history_name,
        flatten_auto_now = params.flatten_auto_now,
    })
end

function DevelopActions.getParamRange(params)
    if not params or type(params.parameter) ~= "string" or params.parameter == "" then
        error("parameter is required")
    end

    local ok, minValue, maxValue = pcall(function()
        return LrDevelopController.getRange(params.parameter)
    end)

    if not ok then
        error("Unable to read range for parameter " .. params.parameter .. ": " .. tostring(minValue))
    end

    return {
        parameter = params.parameter,
        min = minValue,
        max = maxValue,
    }
end

function DevelopActions.listParams(_)
    local names = getKnownParameterNames()
    return {
        count = #names,
        source = AgDevelopParams and "AgDevelopParams.kParamInfo" or "unavailable",
        parameters = names,
    }
end

function DevelopActions.listParamRanges(params)
    local names = {}
    if params and type(params.parameters) == "table" and #params.parameters > 0 then
        for _, raw in ipairs(params.parameters) do
            if type(raw) == "string" and raw ~= "" then
                names[#names + 1] = raw
            end
        end
    else
        names = getKnownParameterNames()
    end

    local ranges = {}
    local unavailable = {}
    for _, parameter in ipairs(names) do
        local ok, minValue, maxValue = pcall(function()
            return LrDevelopController.getRange(parameter)
        end)
        if ok and type(minValue) == "number" and type(maxValue) == "number" then
            ranges[parameter] = {
                min = minValue,
                max = maxValue,
            }
        else
            unavailable[#unavailable + 1] = {
                parameter = parameter,
                error = tostring(minValue),
            }
        end
    end

    return {
        requested = #names,
        ranged = ranges,
        ranged_count = (function()
            local c = 0
            for _, _ in pairs(ranges) do
                c = c + 1
            end
            return c
        end)(),
        unavailable = unavailable,
    }
end

function DevelopActions.autoWhiteBalance(params)
    return DevelopActions.applySettings({
        settings = {
            WhiteBalance = "Auto",
        },
        local_ids = params and params.local_ids or nil,
        history_name = "MCP Auto White Balance",
    })
end

function DevelopActions.autoTone(params)
    -- Best effort across selected photos using documented auto flags.
    return DevelopActions.applySettings({
        settings = {
            AutoExposure = true,
            AutoContrast = true,
            AutoShadows = true,
            AutoBrightness = true,
        },
        local_ids = params and params.local_ids or nil,
        flatten_auto_now = true,
        history_name = "MCP Auto Tone",
    })
end

function DevelopActions.resetCurrentPhoto(_)
    local ok, err = pcall(function()
        LrDevelopController.resetAllDevelopAdjustments()
    end)

    if not ok then
        error("reset_current_photo failed: " .. tostring(err))
    end

    return {
        reset = true,
    }
end

-- ── Undo / Redo ───────────────────────────────────────────────────

function DevelopActions.undo(_)
    if not LrUndo then
        error("LrUndo is not available in this Lightroom version")
    end

    local ok, err = pcall(function()
        LrUndo.undo()
    end)

    if not ok then
        error("undo failed: " .. tostring(err))
    end

    return { undone = true }
end

function DevelopActions.redo(_)
    if not LrUndo then
        error("LrUndo is not available in this Lightroom version")
    end

    local ok, err = pcall(function()
        LrUndo.redo()
    end)

    if not ok then
        error("redo failed: " .. tostring(err))
    end

    return { redone = true }
end

function DevelopActions.canUndo(_)
    if not LrUndo then
        return { can_undo = false, can_redo = false, note = "LrUndo not available" }
    end

    local canUndoResult = false
    local canRedoResult = false

    pcall(function()
        canUndoResult = LrUndo.canUndo()
    end)
    pcall(function()
        canRedoResult = LrUndo.canRedo()
    end)

    return {
        can_undo = canUndoResult == true,
        can_redo = canRedoResult == true,
    }
end

-- ── Snapshots ─────────────────────────────────────────────────────

function DevelopActions.createSnapshot(params)
    if not params or type(params.name) ~= "string" or params.name == "" then
        error("name is required")
    end

    local catalog = ActionUtils.getCatalog()
    local primary = ActionUtils.getPrimaryPhoto(params)
    if not primary then
        error("No photo selected")
    end

    local snapshotId = nil

    catalog:withWriteAccessDo("MCP Create Snapshot", function()
        snapshotId = primary:createDevelopSnapshot(params.name)
    end)

    return {
        created = true,
        snapshot_name = params.name,
        snapshot_id = snapshotId,
        local_id = primary.localIdentifier,
    }
end

function DevelopActions.listSnapshots(params)
    local catalog = ActionUtils.getCatalog()
    local primary = nil
    local snapshots = {}

    catalog:withReadAccessDo(function()
        primary = ActionUtils.getPrimaryPhoto(params)
        if primary then
            local rawSnapshots = primary:getDevelopSnapshots() or {}
            for _, snap in ipairs(rawSnapshots) do
                snapshots[#snapshots + 1] = {
                    id = snap.snapshotID,
                    name = snap.snapshotName,
                }
            end
        end
    end)

    if not primary then
        error("No photo selected")
    end

    return {
        local_id = primary.localIdentifier,
        count = #snapshots,
        snapshots = snapshots,
    }
end

function DevelopActions.applySnapshot(params)
    if not params or not params.snapshot_id then
        error("snapshot_id is required")
    end

    local catalog = ActionUtils.getCatalog()
    local primary = ActionUtils.getPrimaryPhoto(params)
    if not primary then
        error("No photo selected")
    end

    catalog:withWriteAccessDo("MCP Apply Snapshot", function()
        primary:applyDevelopSnapshot(params.snapshot_id)
    end)

    return {
        applied = true,
        snapshot_id = params.snapshot_id,
        local_id = primary.localIdentifier,
    }
end

function DevelopActions.deleteSnapshot(params)
    if not params or not params.snapshot_id then
        error("snapshot_id is required")
    end

    local catalog = ActionUtils.getCatalog()
    local primary = ActionUtils.getPrimaryPhoto(params)
    if not primary then
        error("No photo selected")
    end

    catalog:withWriteAccessDo("MCP Delete Snapshot", function()
        primary:deleteDevelopSnapshot(params.snapshot_id)
    end)

    return {
        deleted = true,
        snapshot_id = params.snapshot_id,
        local_id = primary.localIdentifier,
    }
end

-- ── Lightroom Presets ─────────────────────────────────────────────

function DevelopActions.listLrPresets(_)
    local presets = {}

    local ok, err = pcall(function()
        local folders = LrApplication.developPresetFolders()
        if folders then
            for _, folder in ipairs(folders) do
                local folderName = folder:getName()
                local folderPresets = folder:getDevelopPresets() or {}
                for _, preset in ipairs(folderPresets) do
                    presets[#presets + 1] = {
                        uuid = preset:getUuid(),
                        name = preset:getName(),
                        folder = folderName,
                    }
                end
            end
        end
    end)

    if not ok then
        error("listLrPresets failed: " .. tostring(err))
    end

    return {
        count = #presets,
        presets = presets,
    }
end

function DevelopActions.applyLrPreset(params)
    if not params or not params.uuid then
        error("uuid is required")
    end

    local catalog = ActionUtils.getCatalog()
    local photos = ActionUtils.resolvePhotos(params)
    if not photos or #photos == 0 then
        error("No target photos found")
    end

    local preset = nil
    local ok, err = pcall(function()
        preset = LrApplication.developPresetByUuid(params.uuid)
    end)

    if not ok or not preset then
        error("Preset not found for UUID: " .. tostring(params.uuid))
    end

    local applied = 0

    catalog:withWriteAccessDo("MCP Apply LR Preset", function()
        for _, photo in ipairs(photos) do
            local applyOk, applyErr = LrTasks.pcall(function()
                photo:applyDevelopPreset(preset)
            end)
            if applyOk then
                applied = applied + 1
            end
        end
    end)

    return {
        uuid = params.uuid,
        preset_name = preset:getName(),
        requested = #photos,
        applied = applied,
    }
end

-- ── Lens Blur Extras ──────────────────────────────────────────────

function DevelopActions.toggleLensBlurDepthViz(_)
    local ok, err = pcall(function()
        LrDevelopController.toggleLensBlurDepthVisualization()
    end)

    if not ok then
        error("toggleLensBlurDepthVisualization failed: " .. tostring(err))
    end

    return { toggled = true }
end

function DevelopActions.setLensBlurBokeh(params)
    if not params or not params.bokeh then
        error("bokeh shape is required")
    end

    local ok, err = pcall(function()
        LrDevelopController.setLensBlurBokeh(params.bokeh)
    end)

    if not ok then
        error("setLensBlurBokeh failed: " .. tostring(err))
    end

    return {
        bokeh = params.bokeh,
        applied = true,
    }
end

return DevelopActions
