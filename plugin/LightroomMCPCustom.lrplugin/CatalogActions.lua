local ActionUtils = require "ActionUtils"
local LrDate = import "LrDate"

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

function CatalogActions.searchPhotos(params)
    params = params or {}
    local catalog = ActionUtils.getCatalog()
    local limit = math.min(math.floor(tonumber(params.limit) or 20), 100)
    local sortOrder = params.sort or "newest"

    local keyword = params.keyword and tostring(params.keyword):lower() or nil
    local dateFrom = params.date_from or nil
    local dateTo = params.date_to or nil
    local ratingMin = params.rating_min and tonumber(params.rating_min) or nil
    local ratingMax = params.rating_max and tonumber(params.rating_max) or nil
    local pickStatus = params.pick_status and tonumber(params.pick_status) or nil
    local label = params.label and tostring(params.label) or nil
    local cameraModel = params.camera_model and tostring(params.camera_model):lower() or nil

    local results = {}
    local scanned = 0
    local matched = 0

    catalog:withReadAccessDo(function()
        local photos

        photos = catalog:getAllPhotos() or {}

        local filtered = {}
        for _, photo in ipairs(photos) do
            scanned = scanned + 1
            local dominated = false

            -- Cheapest checks first
            if not dominated and pickStatus then
                local ps = photo:getRawMetadata("pickStatus")
                if ps ~= pickStatus then dominated = true end
            end

            if not dominated and ratingMin then
                local r = photo:getRawMetadata("rating") or 0
                if r < ratingMin then dominated = true end
            end

            if not dominated and ratingMax then
                local r = photo:getRawMetadata("rating") or 0
                if r > ratingMax then dominated = true end
            end

            if not dominated and label then
                local l = photo:getRawMetadata("colorNameForLabel") or ""
                if l:lower() ~= label:lower() then dominated = true end
            end

            if not dominated and keyword then
                local tags = photo:getFormattedMetadata("keywordTags") or ""
                if not tags:lower():find(keyword, 1, true) then dominated = true end
            end

            if not dominated and (dateFrom or dateTo) then
                local dt = photo:getRawMetadata("dateTimeOriginal")
                if dt then
                    local dateStr = LrDate.timeToIsoDate(dt)
                    if dateFrom and dateStr < dateFrom then dominated = true end
                    if dateTo and dateStr > dateTo then dominated = true end
                else
                    dominated = true
                end
            end

            if not dominated and cameraModel then
                local cm = photo:getFormattedMetadata("cameraModel") or ""
                if not cm:lower():find(cameraModel, 1, true) then dominated = true end
            end

            if not dominated then
                matched = matched + 1
                local dt = photo:getRawMetadata("dateTimeOriginal") or 0
                filtered[#filtered + 1] = { photo = photo, date = dt }
            end
        end

        -- Sort by date
        table.sort(filtered, function(a, b)
            if sortOrder == "oldest" then
                return a.date < b.date
            else
                return a.date > b.date
            end
        end)

        -- Limit and build summaries
        local count = math.min(#filtered, limit)
        for i = 1, count do
            local photo = filtered[i].photo
            local summary = ActionUtils.photoToSummary(photo)
            local tagStr = photo:getFormattedMetadata("keywordTags") or ""
            local kws = {}
            for tag in tagStr:gmatch("[^,]+") do
                local name = tag:match("^%s*(.-)%s*$")
                if name and name ~= "" then
                    kws[#kws + 1] = name
                end
            end
            summary.keywords = kws

            local exportStr = photo:getFormattedMetadata("keywordTagsForExport") or ""
            local exportKws = {}
            for tag in exportStr:gmatch("[^,]+") do
                local name = tag:match("^%s*(.-)%s*$")
                if name and name ~= "" then
                    exportKws[#exportKws + 1] = name
                end
            end
            summary.keywords_for_export = exportKws

            results[#results + 1] = summary
        end
    end)

    return {
        scanned = scanned,
        matched = matched,
        returned = #results,
        photos = results,
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
