local LrDialogs = import "LrDialogs"
local LrTasks = import "LrTasks"

local Logger = require "Logger"
local SocketBridge = require "SocketBridge"

Logger.info("Manual restart requested")

SocketBridge.stop()

LrTasks.startAsyncTask(function()
    LrTasks.sleep(0.25)
    SocketBridge.start()
    if _G.LightroomMCPCustom then
        _G.LightroomMCPCustom.running = true
    end
    LrDialogs.showBezel("Lightroom MCP bridge restarted", 2)
end)
