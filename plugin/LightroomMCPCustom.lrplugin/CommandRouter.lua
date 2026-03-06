local LrTasks = import "LrTasks"

local Logger = require "Logger"
local CatalogActions = require "CatalogActions"
local CollectionActions = require "CollectionActions"
local DevelopActions = require "DevelopActions"
local MetadataActions = require "MetadataActions"
local MaskActions = require "MaskActions"
local ExportActions = require "ExportActions"

local CommandRouter = {
    handlers = {},
}

local function register(name, handler)
    CommandRouter.handlers[name] = handler
end

register("system.ping", function(_)
    return {
        pong = true,
        plugin = "Lightroom MCP Custom",
        version = "0.4.0",
        now = os.time(),
    }
end)

register("system.status", function(_)
    local state = _G.LightroomMCPCustom or {}
    local count = 0
    for _, _ in pairs(CommandRouter.handlers) do
        count = count + 1
    end

    return {
        running = state.running == true,
        started_at = state.startedAt,
        commands_registered = count,
        port_file = state.portFile,
        log_file = state.logFile,
    }
end)

register("system.list_commands", function(_)
    local out = {}
    for name, _ in pairs(CommandRouter.handlers) do
        out[#out + 1] = name
    end
    table.sort(out)
    return {
        commands = out,
        count = #out,
    }
end)

register("catalog.get_selected_photos", CatalogActions.getSelectedPhotos)
register("catalog.get_active_photo", CatalogActions.getActivePhoto)
register("catalog.find_photo_by_path", CatalogActions.findPhotoByPath)

register("develop.get_settings", DevelopActions.getSettings)
register("develop.apply_settings", DevelopActions.applySettings)
register("develop.set_param", DevelopActions.setParam)
register("develop.get_param_range", DevelopActions.getParamRange)
register("develop.list_params", DevelopActions.listParams)
register("develop.list_param_ranges", DevelopActions.listParamRanges)
register("develop.auto_white_balance", DevelopActions.autoWhiteBalance)
register("develop.auto_tone", DevelopActions.autoTone)
register("develop.reset_current_photo", DevelopActions.resetCurrentPhoto)

register("metadata.set_rating", MetadataActions.setRating)
register("metadata.set_label", MetadataActions.setLabel)
register("metadata.set_pick_status", MetadataActions.setPickStatus)
register("metadata.set_title", MetadataActions.setTitle)
register("metadata.set_caption", MetadataActions.setCaption)
register("metadata.add_keywords", MetadataActions.addKeywords)
register("metadata.remove_keywords", MetadataActions.removeKeywords)

register("masks.select_tool", MaskActions.selectTool)
register("masks.create_ai_mask", MaskActions.createAIMask)
register("masks.select_mask", MaskActions.selectMask)
register("masks.toggle_overlay", MaskActions.toggleOverlay)
register("masks.toggle_invert", MaskActions.toggleInvert)
register("masks.get_local_settings", MaskActions.getLocalSettings)
register("masks.set_local_settings", MaskActions.setLocalSettings)
register("masks.list_local_params", MaskActions.listLocalParams)

register("system.undo", DevelopActions.undo)
register("system.redo", DevelopActions.redo)
register("system.can_undo", DevelopActions.canUndo)

register("develop.create_snapshot", DevelopActions.createSnapshot)
register("develop.list_snapshots", DevelopActions.listSnapshots)
register("develop.apply_snapshot", DevelopActions.applySnapshot)
register("develop.delete_snapshot", DevelopActions.deleteSnapshot)

register("develop.list_lr_presets", DevelopActions.listLrPresets)
register("develop.apply_lr_preset", DevelopActions.applyLrPreset)
register("develop.toggle_lens_blur_depth_viz", DevelopActions.toggleLensBlurDepthViz)
register("develop.set_lens_blur_bokeh", DevelopActions.setLensBlurBokeh)

register("catalog.list_collections", CollectionActions.listCollections)
register("catalog.create_collection", CollectionActions.createCollection)
register("catalog.add_to_collection", CollectionActions.addToCollection)
register("catalog.remove_from_collection", CollectionActions.removeFromCollection)
register("catalog.delete_collection", CollectionActions.deleteCollection)
register("catalog.create_virtual_copy", CatalogActions.createVirtualCopy)

register("metadata.rotate_left", MetadataActions.rotateLeft)
register("metadata.rotate_right", MetadataActions.rotateRight)

register("catalog.export_photos", ExportActions.exportPhotos)

function CommandRouter.dispatch(request)
    if type(request) ~= "table" then
        error("request payload must be an object")
    end

    local requestId = request.id
    local command = request.command
    local params = request.params or {}

    if type(command) ~= "string" or command == "" then
        return {
            id = requestId,
            success = false,
            error = {
                code = "INVALID_REQUEST",
                message = "command is required",
            },
        }
    end

    local handler = CommandRouter.handlers[command]
    if not handler then
        return {
            id = requestId,
            success = false,
            error = {
                code = "UNKNOWN_COMMAND",
                message = "No handler for command: " .. command,
            },
        }
    end

    Logger.debug("Dispatching command: " .. command)
    local ok, result = LrTasks.pcall(function()
        return handler(params)
    end)

    if not ok then
        Logger.error("Command failed: " .. command .. " -> " .. tostring(result))
        return {
            id = requestId,
            success = false,
            error = {
                code = "COMMAND_FAILED",
                message = tostring(result),
            },
        }
    end

    return {
        id = requestId,
        success = true,
        result = result,
    }
end

return CommandRouter
