local LrLogger = import "LrLogger"
local LrPathUtils = import "LrPathUtils"

local Logger = {}

local logger = LrLogger("LightroomMCPCustom")
logger:enable("logfile")

local logPath = LrPathUtils.child(LrPathUtils.getStandardFilePath("temp"), "lightroom_mcp_custom.log")

local function writeLine(level, message)
    logger:trace("[" .. level .. "] " .. tostring(message))
    local file = io.open(logPath, "a")
    if file then
        file:write(os.date("%Y-%m-%d %H:%M:%S") .. " [" .. level .. "] " .. tostring(message) .. "\n")
        file:close()
    end
end

function Logger.debug(message)
    writeLine("DEBUG", message)
end

function Logger.info(message)
    writeLine("INFO", message)
end

function Logger.warn(message)
    writeLine("WARN", message)
end

function Logger.error(message)
    writeLine("ERROR", message)
end

function Logger.getPath()
    return logPath
end

return Logger
