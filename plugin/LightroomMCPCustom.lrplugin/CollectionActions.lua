local ActionUtils = require "ActionUtils"

local CollectionActions = {}

local function collectionToSummary(collection)
    return {
        local_id = collection.localIdentifier,
        name = collection:getName(),
        is_smart = collection:isSmartCollection(),
        photo_count = #collection:getPhotos(),
    }
end

local function collectChildCollections(parent, depth)
    depth = depth or 0
    if depth > 10 then
        return {}
    end

    local out = {}

    local collections = parent:getChildCollections()
    for _, collection in ipairs(collections) do
        local summary = collectionToSummary(collection)
        summary.type = "collection"
        summary.depth = depth
        out[#out + 1] = summary
    end

    local sets = parent:getChildCollectionSets()
    if sets then
        for _, collectionSet in ipairs(sets) do
            local setEntry = {
                local_id = collectionSet.localIdentifier,
                name = collectionSet:getName(),
                type = "collection_set",
                depth = depth,
            }
            out[#out + 1] = setEntry

            local children = collectChildCollections(collectionSet, depth + 1)
            for _, child in ipairs(children) do
                out[#out + 1] = child
            end
        end
    end

    return out
end

function CollectionActions.listCollections(params)
    local catalog = ActionUtils.getCatalog()
    local items = {}

    catalog:withReadAccessDo(function()
        items = collectChildCollections(catalog, 0)
    end)

    return {
        count = #items,
        collections = items,
    }
end

function CollectionActions.createCollection(params)
    if not params or type(params.name) ~= "string" or params.name == "" then
        error("name is required")
    end

    local catalog = ActionUtils.getCatalog()
    local collection = nil
    local parent = nil

    catalog:withWriteAccessDo("MCP Create Collection", function()
        if params.parent_id then
            local parentId = tonumber(params.parent_id)
            if parentId then
                parent = catalog:getCollectionByLocalIdentifier(parentId)
            end
        end

        collection = catalog:createCollection(params.name, parent, true)
    end)

    if not collection then
        error("Failed to create collection")
    end

    return {
        created = true,
        collection = collectionToSummary(collection),
    }
end

function CollectionActions.addToCollection(params)
    if not params or not params.collection_id then
        error("collection_id is required")
    end

    local catalog = ActionUtils.getCatalog()
    local photos = ActionUtils.resolvePhotos(params)
    if not photos or #photos == 0 then
        error("No target photos found")
    end

    local added = 0

    catalog:withWriteAccessDo("MCP Add to Collection", function()
        local collectionId = tonumber(params.collection_id)
        local collection = catalog:getCollectionByLocalIdentifier(collectionId)
        if not collection then
            error("Collection not found: " .. tostring(collectionId))
        end

        collection:addPhotos(photos)
        added = #photos
    end)

    return {
        collection_id = tonumber(params.collection_id),
        added = added,
    }
end

function CollectionActions.removeFromCollection(params)
    if not params or not params.collection_id then
        error("collection_id is required")
    end

    local catalog = ActionUtils.getCatalog()
    local photos = ActionUtils.resolvePhotos(params)
    if not photos or #photos == 0 then
        error("No target photos found")
    end

    local removed = 0

    catalog:withWriteAccessDo("MCP Remove from Collection", function()
        local collectionId = tonumber(params.collection_id)
        local collection = catalog:getCollectionByLocalIdentifier(collectionId)
        if not collection then
            error("Collection not found: " .. tostring(collectionId))
        end

        collection:removePhotos(photos)
        removed = #photos
    end)

    return {
        collection_id = tonumber(params.collection_id),
        removed = removed,
    }
end

function CollectionActions.deleteCollection(params)
    if not params or not params.collection_id then
        error("collection_id is required")
    end

    local catalog = ActionUtils.getCatalog()

    catalog:withWriteAccessDo("MCP Delete Collection", function()
        local collectionId = tonumber(params.collection_id)
        local collection = catalog:getCollectionByLocalIdentifier(collectionId)
        if not collection then
            error("Collection not found: " .. tostring(collectionId))
        end

        collection:delete()
    end)

    return {
        collection_id = tonumber(params.collection_id),
        deleted = true,
    }
end

return CollectionActions
