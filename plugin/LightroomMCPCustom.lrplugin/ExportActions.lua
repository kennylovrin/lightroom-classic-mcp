local LrExportSession = import "LrExportSession"
local LrPathUtils = import "LrPathUtils"
local LrFileUtils = import "LrFileUtils"

local ActionUtils = require "ActionUtils"
local Logger = require "Logger"

local ExportActions = {}

function ExportActions.exportPhotos(params)
    local photos = ActionUtils.resolvePhotos(params)
    if #photos == 0 then
        error("No photos to export")
    end

    local destination = params.destination
    if not destination or type(destination) ~= "string" or destination == "" then
        error("destination folder path is required")
    end

    local quality = tonumber(params.quality) or 85
    if quality < 1 or quality > 100 then
        quality = 85
    end

    -- Create destination directory if needed
    LrFileUtils.createAllDirectories(destination)

    local exportSettings = {
        LR_export_destinationType = "specificFolder",
        LR_export_destinationPathPrefix = destination,
        LR_export_useSubfolder = false,
        LR_format = "JPEG",
        LR_jpeg_quality = quality / 100,
        LR_jpeg_useLimitSize = false,
        LR_size_doConstrain = false,
        LR_export_colorSpace = "sRGB",
        LR_export_bitDepth = 8,
        LR_collisionHandling = "overwrite",
        LR_reimportExportedPhoto = false,
        LR_renamingTokensOn = false,
        LR_metadata_keywordOptions = "lightroomHierarchical",
        LR_embeddedMetadataOption = "all",
        LR_removeFaceMetadata = true,
        LR_removeLocationMetadata = false,
        LR_outputSharpeningOn = true,
        LR_outputSharpeningMedia = "screen",
        LR_outputSharpeningLevel = 2,
        LR_minimizeEmbeddedMetadata = false,
        LR_includeVideoFiles = false,
    }

    Logger.info("Exporting " .. #photos .. " photos to " .. destination)

    local exportSession = LrExportSession({
        photosToExport = photos,
        exportSettings = exportSettings,
    })

    local exported = {}
    local failed = {}

    for _, rendition in exportSession:renditions() do
        local success, pathOrMessage = rendition:waitForRender()
        if success then
            local fileName = LrPathUtils.leafName(pathOrMessage)
            exported[#exported + 1] = fileName
            Logger.debug("Exported: " .. fileName)
        else
            local photo = rendition.photo
            local name = "unknown"
            if photo then
                name = photo:getFormattedMetadata("fileName") or "unknown"
            end
            failed[#failed + 1] = {
                file_name = name,
                error = tostring(pathOrMessage),
            }
            Logger.error("Export failed: " .. name .. " -> " .. tostring(pathOrMessage))
        end
    end

    Logger.info("Export complete: " .. #exported .. " exported, " .. #failed .. " failed")

    return {
        exported_count = #exported,
        failed_count = #failed,
        exported_files = exported,
        failed_files = failed,
        destination = destination,
        total_requested = #photos,
    }
end

return ExportActions
