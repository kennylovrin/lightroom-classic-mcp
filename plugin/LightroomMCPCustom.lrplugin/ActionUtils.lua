local LrApplication = import "LrApplication"

local ActionUtils = {}

local function trim(value)
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

function ActionUtils.getCatalog()
    return LrApplication.activeCatalog()
end

function ActionUtils.resolvePhotos(params)
    local catalog = ActionUtils.getCatalog()
    if not catalog then
        return {}
    end

    if params and type(params.local_ids) == "table" and #params.local_ids > 0 then
        local wantedOrdered = {}
        for _, raw in ipairs(params.local_ids) do
            local id = tonumber(raw)
            if id then
                wantedOrdered[#wantedOrdered + 1] = id
            end
        end

        local resolved = {}
        local unresolved = {}

        -- Fast path: direct lookup by local ID when available.
        for _, id in ipairs(wantedOrdered) do
            local photo = nil
            local okByLocalId = pcall(function()
                photo = catalog:getPhotoByLocalId(id)
            end)
            if (not okByLocalId) or (not photo) then
                pcall(function()
                    photo = catalog:getPhotoById(id)
                end)
            end

            if photo then
                resolved[#resolved + 1] = photo
            else
                unresolved[id] = true
            end
        end

        -- Fallback path for any IDs not resolved via direct lookup.
        if next(unresolved) ~= nil then
            local allPhotos = catalog:getAllPhotos()
            for _, photo in ipairs(allPhotos) do
                local localId = photo.localIdentifier
                if unresolved[localId] then
                    resolved[#resolved + 1] = photo
                    unresolved[localId] = nil
                end
            end
        end
        return resolved
    end

    return catalog:getTargetPhotos() or {}
end

function ActionUtils.getPrimaryPhoto(params)
    local photos = ActionUtils.resolvePhotos(params)
    if not photos or #photos == 0 then
        return nil
    end
    return photos[1]
end

function ActionUtils.photoToSummary(photo)
    return {
        local_id = photo.localIdentifier,
        path = photo:getRawMetadata("path"),
        file_name = photo:getFormattedMetadata("fileName"),
        rating = photo:getRawMetadata("rating"),
        label = photo:getRawMetadata("colorNameForLabel"),
        pick_status = photo:getRawMetadata("pickStatus"),
        capture_time = photo:getFormattedMetadata("dateTimeOriginal"),
        focal_length = photo:getFormattedMetadata("focalLength"),
        aperture = photo:getFormattedMetadata("aperture"),
        shutter_speed = photo:getFormattedMetadata("shutterSpeed"),
        iso = photo:getFormattedMetadata("isoSpeedRating"),
        camera_model = photo:getFormattedMetadata("cameraModel"),
        lens = photo:getFormattedMetadata("lens"),
        dimensions = photo:getFormattedMetadata("dimensions"),
        is_virtual_copy = photo:getRawMetadata("isVirtualCopy"),
        copy_name = photo:getFormattedMetadata("copyName"),
    }
end

function ActionUtils.splitKeywordPath(path)
    local parts = {}
    if not path or type(path) ~= "string" then
        return parts
    end

    for rawPart in path:gmatch("([^>]+)") do
        local part = trim(rawPart)
        if part ~= "" then
            parts[#parts + 1] = part
        end
    end

    return parts
end

return ActionUtils
