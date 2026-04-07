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

local function keywordPathFor(keyword)
    local names = {}
    local node = keyword
    while node do
        names[#names + 1] = node:getName()
        node = node:getParent()
    end

    local out = {}
    for i = #names, 1, -1 do
        out[#out + 1] = names[i]
    end

    return table.concat(out, " > ")
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

local function buildKeywordMap(catalog)
    local map = {}
    local allKeywords = catalog:getKeywords() or {}
    for _, keyword in ipairs(allKeywords) do
        local okPath, path = pcall(function()
            return keywordPathFor(keyword)
        end)
        if okPath and path then
            map[path:lower()] = keyword
        end

        local okName, name = pcall(function()
            return keyword:getName()
        end)
        if okName and name and not map[name:lower()] then
            map[name:lower()] = keyword
        end
    end
    return map
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
        local keywordMap = buildKeywordMap(catalog)
        for _, requested in ipairs(params.keywords) do
            local key = tostring(requested):lower()
            local keyword = keywordMap[key]
            if keyword then
                for _, photo in ipairs(photos) do
                    photo:removeKeyword(keyword)
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

function MetadataActions.batchSetMetadata(params)
    if not params or type(params.entries) ~= "table" or #params.entries == 0 then
        error("entries list is required")
    end

    local catalog = ActionUtils.getCatalog()
    local results = {}
    local succeeded = 0
    local failed = 0
    local stopOnError = params.stop_on_error or false
    local stopped = false

    -- Phase 1: resolve all photos upfront
    local resolved = {}
    for i, entry in ipairs(params.entries) do
        if stopped then
            results[i] = { index = i - 1, success = false, error = "Skipped (stop_on_error)" }
            failed = failed + 1
        else
            local photos = ActionUtils.resolvePhotos(entry)
            if photos and #photos > 0 then
                resolved[i] = photos
            else
                failed = failed + 1
                results[i] = { index = i - 1, success = false, error = "No photos found for local_ids" }
                if stopOnError then
                    stopped = true
                end
            end
        end
    end

    -- Phase 2: single write transaction for all resolved entries.
    -- Entries not in resolved{} (failed or skipped in Phase 1) already have
    -- their result recorded and are silently skipped here.
    -- Skip the transaction entirely if nothing to write (empty withWriteAccessDo
    -- triggers an assertion error in Lightroom).
    if next(resolved) == nil then
        return {
            requested = #params.entries,
            succeeded = 0,
            failed = failed,
            stop_on_error = stopOnError,
            results = results,
        }
    end

    catalog:withWriteAccessDo("MCP Batch Set Metadata", function()
        -- Pre-resolve all unique keyword paths once. Calling ensureKeywordPath
        -- (catalog:createKeyword) repeatedly for the same path within a single
        -- transaction can silently fail to return the keyword on subsequent calls.
        local keywordCache = {}
        for i, entry in ipairs(params.entries) do
            if resolved[i] and entry.keywords and type(entry.keywords) == "table" then
                for _, keywordPath in ipairs(entry.keywords) do
                    local path = tostring(keywordPath)
                    if keywordCache[path] == nil then
                        keywordCache[path] = ensureKeywordPath(catalog, path) or false
                    end
                end
            end
        end

        for i, entry in ipairs(params.entries) do
            if resolved[i] then
                local photos = resolved[i]

                if entry.caption then
                    for _, photo in ipairs(photos) do
                        photo:setRawMetadata("caption", tostring(entry.caption))
                    end
                end

                if entry.keywords and type(entry.keywords) == "table" then
                    for _, keywordPath in ipairs(entry.keywords) do
                        local kw = keywordCache[tostring(keywordPath)]
                        if kw then
                            for _, photo in ipairs(photos) do
                                photo:addKeyword(kw)
                            end
                        end
                    end
                end

                succeeded = succeeded + 1
                results[i] = { index = i - 1, success = true, photos_updated = #photos }
            end
        end
    end)

    return {
        requested = #params.entries,
        succeeded = succeeded,
        failed = failed,
        stop_on_error = stopOnError,
        results = results,
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
