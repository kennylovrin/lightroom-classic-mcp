local Logger = require "Logger"
local SocketBridge = require "SocketBridge"

_G.LightroomMCPCustom = {
    running = false,
    startedAt = os.time(),
    portFile = "/tmp/lightroom_mcp_custom_ports.json",
    logFile = Logger.getPath(),
}

local ok, err = pcall(function()
    SocketBridge.start()
end)

if ok then
    _G.LightroomMCPCustom.running = true
    Logger.info("PluginInit complete (auto bridge start mode)")
else
    Logger.error("PluginInit failed to start bridge: " .. tostring(err))
end
