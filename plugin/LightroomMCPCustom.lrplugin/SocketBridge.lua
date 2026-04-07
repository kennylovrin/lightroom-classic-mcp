local LrFileUtils = import "LrFileUtils"
local LrFunctionContext = import "LrFunctionContext"
local LrSocket = import "LrSocket"
local LrTasks = import "LrTasks"

local Logger = require "Logger"
local JSON = require "JSON"
local CommandRouter = require "CommandRouter"

local SocketBridge = {}

local state = {
    running = false,
    shuttingDown = false,
    senderSocket = nil,
    receiverSocket = nil,
    senderPort = nil,
    receiverPort = nil,
    senderConnected = false,
    receiverConnected = false,
    senderConnectedAt = nil,
    receiveBuffer = "",
    sessionId = nil,
    startedAt = nil,
    needsRestart = false,
}

local PORT_FILE = "/tmp/lightroom_mcp_custom_ports.json"

local function cleanupPortFile()
    if LrFileUtils.exists(PORT_FILE) then
        LrFileUtils.delete(PORT_FILE)
    end
end

local function writePortFileIfReady()
    if state.senderPort and state.receiverPort then
        local payload = JSON.encode({
            send_port = state.senderPort,
            receive_port = state.receiverPort,
            session_id = state.sessionId,
            started_at = state.startedAt,
            plugin = "Lightroom MCP Custom",
            version = "0.4.0",
        })
        local file = io.open(PORT_FILE, "w")
        if file then
            file:write(payload)
            file:write("\n")
            file:close()
            Logger.info("Wrote port file " .. PORT_FILE)
        else
            Logger.error("Failed to write port file " .. PORT_FILE)
        end
    end
end

local function socketKey(socketObj)
    if not socketObj then
        return nil
    end
    local ok, key = pcall(function()
        return tostring(socketObj)
    end)
    if ok then
        return key
    end
    return nil
end

local function sendLine(socketObj, line)
    local ok, sent, err, partial = pcall(function()
        return socketObj:send(line)
    end)
    if not ok then
        return false, "send threw: " .. tostring(sent)
    end

    if sent == nil then
        -- LrSocket:send may return no values on success; treat that as success.
        if err == nil and partial == nil then
            return true, "sent"
        end
        return false, tostring(err or "send failed")
    end

    if sent == false then
        return false, tostring(err or "send failed")
    end

    if type(sent) == "number" then
        local n = #line
        if sent < n then
            local progressed = partial
            if type(progressed) ~= "number" then
                progressed = err
            end
            return false, string.format(
                "partial send (%s/%s), err=%s",
                tostring(progressed or sent),
                tostring(n),
                tostring(err)
            )
        end
    end

    return true, tostring(sent)
end

local function sendResponse(response, preferredSocket)
    local ok, encoded = pcall(function()
        return JSON.encode(response)
    end)
    if not ok then
        Logger.error("JSON encode failure for response: " .. tostring(encoded))
        return false
    end

    local originalLength = #encoded
    encoded = string.gsub(encoded, "\r", "")
    encoded = string.gsub(encoded, "\n", "")
    if #encoded ~= originalLength then
        Logger.debug("Normalized JSON response length from " .. tostring(originalLength) .. " to " .. tostring(#encoded))
    end

    local responseLine = encoded .. "\n"
    local candidates = {}
    local seen = {}

    local function enqueueCandidate(name, socketObj, connected)
        if not socketObj or not connected then
            return
        end
        local key = socketKey(socketObj)
        if key and seen[key] then
            return
        end
        if key then
            seen[key] = true
        end
        candidates[#candidates + 1] = {
            name = name,
            socket = socketObj,
        }
    end

    -- Sender-first has been the most reliable delivery path in Lightroom.
    enqueueCandidate("sender", state.senderSocket, state.senderConnected)
    enqueueCandidate("receiver", state.receiverSocket, state.receiverConnected)

    for _, candidate in ipairs(candidates) do
        local sendOk, detail = sendLine(candidate.socket, responseLine)
        if sendOk then
            Logger.debug("Sent response via " .. candidate.name .. " socket (" .. tostring(detail) .. ")")
            return true
        end
        Logger.warn("Socket send via " .. candidate.name .. " failed: " .. tostring(detail))
        if candidate.name == "sender" then
            state.senderConnected = false
        elseif candidate.name == "receiver" then
            state.receiverConnected = false
        end
    end

    -- Last resort: try whichever sockets exist even if connection state looked stale.
    local emergency = {
        { name = "sender-emergency", socket = state.senderSocket },
        { name = "receiver-emergency", socket = state.receiverSocket },
    }
    for _, candidate in ipairs(emergency) do
        local key = socketKey(candidate.socket)
        if candidate.socket and (not key or not seen[key]) then
            local sendOk, detail = sendLine(candidate.socket, responseLine)
            if sendOk then
                Logger.warn("Sent response via " .. candidate.name .. " fallback")
                return true
            end
            Logger.warn("Fallback send via " .. candidate.name .. " failed: " .. tostring(detail))
        end
    end

    Logger.warn("Cannot send response: no connected socket accepted payload")
    return false
end

local function handleMessageLine(line, sourceSocket)
    if line == nil or line == "" then
        return
    end

    local ok, request = pcall(function()
        return JSON.decode(line)
    end)
    if not ok then
        Logger.error("Invalid JSON request: " .. tostring(request))
        return
    end

    Logger.debug("Handling request line bytes=" .. tostring(#line))
    LrTasks.startAsyncTask(function()
        local response = CommandRouter.dispatch(request)
        sendResponse(response, sourceSocket)
    end)
end

local function processChunk(chunk, sourceSocket)
    if type(chunk) ~= "string" or chunk == "" then
        return
    end

    state.receiveBuffer = state.receiveBuffer .. chunk
    local consumedByNewline = false

    while true do
        local nl = string.find(state.receiveBuffer, "\n", 1, true)
        if not nl then
            break
        end

        local line = string.sub(state.receiveBuffer, 1, nl - 1)
        state.receiveBuffer = string.sub(state.receiveBuffer, nl + 1)

        handleMessageLine(line, sourceSocket)
        consumedByNewline = true
    end

    -- LrSocket receive callbacks can be message-framed already and may not
    -- include newline delimiters. If no delimiter was found, treat the chunk
    -- as a complete request payload.
    if (not consumedByNewline) and state.receiveBuffer ~= "" then
        handleMessageLine(state.receiveBuffer, sourceSocket)
        state.receiveBuffer = ""
    end
end

local function scheduleRestart()
    if state.needsRestart or state.shuttingDown then
        return
    end

    state.needsRestart = true
    Logger.info("Restart requested, main loop will handle it")
end

function SocketBridge.start()
    if state.running then
        Logger.info("SocketBridge.start called while already running")
        return
    end

    state.running = true
    state.shuttingDown = false
    state.receiveBuffer = ""
    state.senderPort = nil
    state.receiverPort = nil
    state.senderConnected = false
    state.receiverConnected = false
    state.needsRestart = false
    state.startedAt = os.time()
    math.randomseed(state.startedAt)
    state.sessionId = tostring(state.startedAt) .. "-" .. tostring(math.random(100000, 999999))
    cleanupPortFile()

    Logger.info("Starting Lightroom MCP socket bridge")

    LrTasks.startAsyncTask(function()
        local restartAfter = false

        LrFunctionContext.callWithContext("LightroomMCPCustomBridge", function(context)
            context:addCleanupHandler(function()
                cleanupPortFile()
                state.running = false
                state.shuttingDown = true
                Logger.info("Bridge context cleanup handler fired")
            end)

            state.senderSocket = LrSocket.bind {
                functionContext = context,
                plugin = _PLUGIN,
                address = "localhost",
                port = 0,
                mode = "send",

                onConnecting = function(_, port)
                    state.senderPort = port
                    Logger.info("Sender socket listening on port " .. tostring(port))
                    writePortFileIfReady()
                end,

                onConnected = function(_, _)
                    state.senderConnected = true
                    state.senderConnectedAt = os.time()
                    Logger.info("Sender socket connected")
                end,

                onClosed = function(socket)
                    if state.shuttingDown then return end
                    state.senderConnected = false
                    state.senderConnectedAt = nil
                    Logger.warn("Sender socket closed")
                    if state.running then
                        scheduleRestart()
                    end
                end,

                onError = function(socket, err)
                    if state.shuttingDown then return end
                    if err ~= "timeout" then
                        Logger.error("Sender socket error: " .. tostring(err))
                        if state.running then
                            scheduleRestart()
                        end
                    else
                        Logger.debug("Sender socket timeout")
                        if state.running then
                            socket:reconnect()
                        end
                    end
                end,
            }

            state.receiverSocket = LrSocket.bind {
                functionContext = context,
                plugin = _PLUGIN,
                address = "localhost",
                port = 0,
                mode = "receive",

                onConnecting = function(_, port)
                    state.receiverPort = port
                    Logger.info("Receiver socket listening on port " .. tostring(port))
                    writePortFileIfReady()
                end,

                onConnected = function(_, _)
                    state.receiverConnected = true
                    Logger.info("Receiver socket connected")
                end,

                onMessage = function(socketObj, message)
                    if state.shuttingDown then return end
                    Logger.debug("Receiver socket message chunk length: " .. tostring(#(message or "")))
                    processChunk(message, socketObj)
                end,

                onClosed = function(socket)
                    if state.shuttingDown then return end
                    state.receiverConnected = false
                    Logger.warn("Receiver socket closed")
                    if state.running then
                        scheduleRestart()
                    end
                end,

                onError = function(socket, err)
                    if state.shuttingDown then return end
                    if err ~= "timeout" then
                        Logger.error("Receiver socket error: " .. tostring(err))
                        if state.running then
                            scheduleRestart()
                        end
                    else
                        Logger.debug("Receiver socket timeout")
                        if state.running then
                            socket:reconnect()
                        end
                    end
                end,
            }

            while state.running do
                LrTasks.sleep(0.2)

                if state.needsRestart and state.running and not state.shuttingDown then
                    Logger.info("Restarting bridge from main loop")
                    restartAfter = true
                    state.needsRestart = false
                    state.running = false
                end
            end

            if state.senderSocket then
                pcall(function() state.senderSocket:close() end)
            end
            if state.receiverSocket then
                pcall(function() state.receiverSocket:close() end)
            end

            cleanupPortFile()
            Logger.info("Socket bridge async loop ended")
        end)

        if restartAfter and not state.shuttingDown then
            LrTasks.sleep(0.5)
            SocketBridge.start()
        end
    end)
end

function SocketBridge.stop()
    if not state.running then
        return
    end

    Logger.info("Stopping Lightroom MCP socket bridge")
    state.shuttingDown = true
    state.running = false
    state.needsRestart = false

    if state.senderSocket then
        pcall(function() state.senderSocket:close() end)
    end

    if state.receiverSocket then
        pcall(function() state.receiverSocket:close() end)
    end

    cleanupPortFile()
end

function SocketBridge.status()
    return {
        running = state.running,
        sender_connected = state.senderConnected,
        receiver_connected = state.receiverConnected,
        sender_port = state.senderPort,
        receiver_port = state.receiverPort,
        port_file = PORT_FILE,
        needs_restart = state.needsRestart,
    }
end

return SocketBridge
