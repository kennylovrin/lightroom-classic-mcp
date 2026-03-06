local Logger = require "Logger"
local SocketBridge = require "SocketBridge"

Logger.info("PluginShutdown invoked")

pcall(function()
    SocketBridge.stop()
end)

if _G.LightroomMCPCustom then
    _G.LightroomMCPCustom.running = false
end
