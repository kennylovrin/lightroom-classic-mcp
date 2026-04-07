local ActionUtils = require "ActionUtils"

local MetadataActions = {}

local function ensurePhotos(params)
    local photos = ActionUtils.resolvePhotos(params)
    if not photos or #photos == 0 then
        error("No target photos found")
    end
    return photos
end

local function applyRawMetadata(params, key, value)
    local catalog = ActionUtils.getCatalog()
    local photos = ensurePhotos(params)
    local updated = 0

    catalog:withWriteAccessDo("MCP Set Metadata", function()
        for _, photo in ipairs(photos) do
            photo:setRawMetadata(key, value)
            updated = updated + 1
        end
    end)

    return {
        key = key,
        value = value,
        updated = updated,
    }
end

local function ensureKeywordPath(catalog, keywordPath)
    local parts = ActionUtils.splitKeywordPath(keywordPath)
    if #parts == 0 then
        return nil
    end

    local parent = nil
    for _, name in ipairs(parts) do
        parent = catalog:createKeyword(name, {}, true, parent, true)
    end

    return parent
end

function MetadataActions.setRating(params)
    if not params or params.rating == nil then
        error("rating is required")
    end
    local rating = math.floor(tonumber(params.rating))
    if rating < 0 or rating > 5 then
        error("rating must be in range 0..5")
    end
    return applyRawMetadata(params, "rating", rating)
end

function MetadataActions.setLabel(params)
    if not params or params.label == nil then
        error("label is required")
    end
    return applyRawMetadata(params, "label", tostring(params.label))
end

function MetadataActions.setPickStatus(params)
    if not params or params.status == nil then
        error("status is required")
    end
    local status = math.floor(tonumber(params.status))
    if status ~= -1 and status ~= 0 and status ~= 1 then
        error("status must be -1, 0, or 1")
    end
    return applyRawMetadata(params, "pickStatus", status)
end

function MetadataActions.setTitle(params)
    if not params or params.title == nil then
        error("title is required")
    end
    return applyRawMetadata(params, "title", tostring(params.title))
end

function MetadataActions.setCaption(params)
    if not params or params.caption == nil then
        error("caption is required")
    end
    return applyRawMetadata(params, "caption", tostring(params.caption))
end

-- Uses getFormattedMetadata("keywordTags") instead of getRawMetadata("keywords")
-- because the latter silently returns nil inside both withReadAccessDo and outside it.
function MetadataActions.getKeywords(params)
    local catalog = ActionUtils.getCatalog()
    local photos = ensurePhotos(params)
    local results = {}

    catalog:withReadAccessDo(function()
        for _, photo in ipairs(photos) do
            local kwList = {}
            local tagStr = photo:getFormattedMetadata("keywordTags")
            if tagStr and tagStr ~= "" then
                for tag in tagStr:gmatch("[^,]+") do
                    local name = tag:match("^%s*(.-)%s*$")
                    if name and name ~= "" then
                        kwList[#kwList + 1] = name
                    end
                end
            end
            local exportStr = photo:getFormattedMetadata("keywordTagsForExport") or ""
            local exportList = {}
            if exportStr ~= "" then
                for tag in exportStr:gmatch("[^,]+") do
                    local name = tag:match("^%s*(.-)%s*$")
                    if name and name ~= "" then
                        exportList[#exportList + 1] = name
                    end
                end
            end
            results[#results + 1] = {
                local_id = photo.localIdentifier,
                keywords = kwList,
                keywords_for_export = exportList,
            }
        end
    end)

    return {
        photo_count = #photos,
        photos = results,
    }
end

function MetadataActions.addKeywords(params)
    if not params or type(params.keywords) ~= "table" or #params.keywords == 0 then
        error("keywords list is required")
    end

    local catalog = ActionUtils.getCatalog()
    local photos = ensurePhotos(params)
    local applied = 0

    catalog:withWriteAccessDo("MCP Add Keywords", function()
        for _, keywordPath in ipairs(params.keywords) do
            local keyword = ensureKeywordPath(catalog, tostring(keywordPath))
            if keyword then
                for _, photo in ipairs(photos) do
                    photo:addKeyword(keyword)
                    applied = applied + 1
                end
            end
        end
    end)

    return {
        photo_count = #photos,
        keyword_count = #params.keywords,
        applied = applied,
    }
end

function MetadataActions.removeKeywords(params)
    if not params or type(params.keywords) ~= "table" or #params.keywords == 0 then
        error("keywords list is required")
    end

    local catalog = ActionUtils.getCatalog()
    local photos = ensurePhotos(params)
    local removed = 0

    catalog:withWriteAccessDo("MCP Remove Keywords", function()
        for _, requested in ipairs(params.keywords) do
            local req = tostring(requested)
            local matches = {}

            local key = req:lower()
            local function collectByName(keywords)
                for _, kw in ipairs(keywords) do
                    if kw:getName():lower() == key then
                        matches[#matches + 1] = kw
                    end
                    local children = kw:getChildren()
                    if children then
                        collectByName(children)
                    end
                end
            end

            if req:find(">") then
                -- Walk the path to find the specific keyword
                local parts = ActionUtils.splitKeywordPath(req)
                local current = catalog:getKeywords() or {}
                local found = nil
                for _, part in ipairs(parts) do
                    found = nil
                    local partLower = part:lower()
                    for _, kw in ipairs(current) do
                        if kw:getName():lower() == partLower then
                            found = kw
                            current = kw:getChildren() or {}
                            break
                        end
                    end
                    if not found then break end
                end
                if found then
                    matches[#matches + 1] = found
                end
            else
                collectByName(catalog:getKeywords() or {})
            end

            for _, kw in ipairs(matches) do
                for _, photo in ipairs(photos) do
                    photo:removeKeyword(kw)
                    removed = removed + 1
                end
            end
        end
    end)

    return {
        photo_count = #photos,
        keyword_count = #params.keywords,
        removed = removed,
    }
end

function MetadataActions.rotateLeft(params)
    local catalog = ActionUtils.getCatalog()
    local photos = ensurePhotos(params)
    local rotated = 0

    catalog:withWriteAccessDo("MCP Rotate Left", function()
        for _, photo in ipairs(photos) do
            local ok, _ = pcall(function()
                photo:rotateLeft()
            end)
            if ok then
                rotated = rotated + 1
            end
        end
    end)

    return {
        rotated = rotated,
        direction = "left",
    }
end

function MetadataActions.rotateRight(params)
    local catalog = ActionUtils.getCatalog()
    local photos = ensurePhotos(params)
    local rotated = 0

    catalog:withWriteAccessDo("MCP Rotate Right", function()
        for _, photo in ipairs(photos) do
            local ok, _ = pcall(function()
                photo:rotateRight()
            end)
            if ok then
                rotated = rotated + 1
            end
        end
    end)

    return {
        rotated = rotated,
        direction = "right",
    }
end

return MetadataActions
