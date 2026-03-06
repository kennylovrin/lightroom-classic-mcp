local LrDialogs = import "LrDialogs"

local SocketBridge = require "SocketBridge"

SocketBridge.stop()
if _G.LightroomMCPCustom then
    _G.LightroomMCPCustom.running = false
end

LrDialogs.showBezel("Lightroom MCP bridge stopped", 2)
