local ActionUtils = require "ActionUtils"

local CatalogActions = {}

function CatalogActions.getSelectedPhotos(params)
    local catalog = ActionUtils.getCatalog()
    local limit = 200
    if params and params.limit then
        local parsed = tonumber(params.limit)
        if parsed and parsed > 0 then
            limit = math.floor(parsed)
        end
    end

    local result = {}
    local total = 0

    catalog:withReadAccessDo(function()
        local photos = catalog:getTargetPhotos() or {}
        total = #photos
        local count = math.min(total, limit)
        for i = 1, count do
            result[#result + 1] = ActionUtils.photoToSummary(photos[i])
        end
    end)

    return {
        total_selected = total,
        returned = #result,
        photos = result,
    }
end

function CatalogActions.getActivePhoto(_)
    local catalog = ActionUtils.getCatalog()
    local summary = nil

    catalog:withReadAccessDo(function()
        local active = catalog:getTargetPhoto()
        if not active then
            error("No active photo selected")
        end
        summary = ActionUtils.photoToSummary(active)
    end)

    if not summary then
        error("No active photo selected")
    end

    return {
        photo = summary,
    }
end

function CatalogActions.findPhotoByPath(params)
    if not params or type(params.path) ~= "string" or params.path == "" then
        error("path is required")
    end

    local catalog = ActionUtils.getCatalog()
    local photo = nil

    catalog:withReadAccessDo(function()
        photo = catalog:findPhotoByPath(params.path)
    end)

    if not photo then
        return {
            found = false,
            path = params.path,
        }
    end

    return {
        found = true,
        photo = ActionUtils.photoToSummary(photo),
    }
end

function CatalogActions.createVirtualCopy(params)
    local catalog = ActionUtils.getCatalog()
    local photos = ActionUtils.resolvePhotos(params)
    if not photos or #photos == 0 then
        error("No target photos found")
    end

    local created = 0
    local failures = {}

    catalog:withWriteAccessDo("MCP Create Virtual Copies", function()
        for _, photo in ipairs(photos) do
            local ok, err = pcall(function()
                catalog:createVirtualCopies(nil)
            end)
            if ok then
                created = created + 1
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
        created = created,
        failures = failures,
    }
end

return CatalogActions
