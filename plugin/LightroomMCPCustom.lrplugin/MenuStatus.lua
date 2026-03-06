local LrDialogs = import "LrDialogs"

local SocketBridge = require "SocketBridge"
local Logger = require "Logger"

local status = SocketBridge.status()

LrDialogs.message(
    "Lightroom MCP Custom",
    "Running: " .. tostring(status.running) ..
    "\nSender connected: " .. tostring(status.sender_connected) ..
    "\nReceiver connected: " .. tostring(status.receiver_connected) ..
    "\nSend port: " .. tostring(status.sender_port) ..
    "\nReceive port: " .. tostring(status.receiver_port) ..
    "\nPort file: " .. tostring(status.port_file) ..
    "\nLog file: " .. tostring(Logger.getPath()),
    "info"
)
