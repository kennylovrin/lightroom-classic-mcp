local LrDialogs = import "LrDialogs"

local Logger = require "Logger"
local SocketBridge = require "SocketBridge"

local status = SocketBridge.status()
if status.running then
    LrDialogs.showBezel("Lightroom MCP bridge already running", 2)
    return
end

local ok, err = pcall(function()
    SocketBridge.start()
    if _G.LightroomMCPCustom then
        _G.LightroomMCPCustom.running = true
    end
end)

if not ok then
    Logger.error("Start bridge failed: " .. tostring(err))
    LrDialogs.message(
        "Lightroom MCP Custom",
        "Could not start bridge. Log: " .. Logger.getPath(),
        "critical"
    )
    return
end

LrDialogs.showBezel("Lightroom MCP bridge started", 2)
