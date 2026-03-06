-- Lightweight JSON encoder/decoder for plugin IPC.

local JSON = {}

local escapeMap = {
    ["\\"] = "\\\\",
    ["\""] = "\\\"",
    ["\b"] = "\\b",
    ["\f"] = "\\f",
    ["\n"] = "\\n",
    ["\r"] = "\\r",
    ["\t"] = "\\t",
}

local unescapeMap = {
    ["\\"] = "\\",
    ["\""] = "\"",
    ["/"] = "/",
    ["b"] = "\b",
    ["f"] = "\f",
    ["n"] = "\n",
    ["r"] = "\r",
    ["t"] = "\t",
}

local function encodeString(value)
    return '"' .. value:gsub('[%z\1-\31\\"]', function(ch)
        local mapped = escapeMap[ch]
        if mapped then
            return mapped
        end
        return string.format("\\u%04x", string.byte(ch))
    end) .. '"'
end

local function isArray(tableValue)
    local maxIndex = 0
    local count = 0
    for key, _ in pairs(tableValue) do
        if type(key) ~= "number" or key <= 0 or key % 1 ~= 0 then
            return false, 0
        end
        if key > maxIndex then
            maxIndex = key
        end
        count = count + 1
    end
    if maxIndex ~= count then
        return false, 0
    end
    return true, maxIndex
end

local function encodeValue(value)
    local kind = type(value)
    if kind == "nil" then
        return "null"
    end
    if kind == "boolean" then
        return tostring(value)
    end
    if kind == "number" then
        if value ~= value or value <= -math.huge or value >= math.huge then
            error("cannot encode non-finite number")
        end
        return tostring(value)
    end
    if kind == "string" then
        return encodeString(value)
    end
    if kind == "table" then
        local asArray, length = isArray(value)
        local out = {}
        if asArray then
            for i = 1, length do
                out[#out + 1] = encodeValue(value[i])
            end
            return "[" .. table.concat(out, ",") .. "]"
        end
        for key, child in pairs(value) do
            if type(key) ~= "string" then
                error("object key must be a string")
            end
            out[#out + 1] = encodeString(key) .. ":" .. encodeValue(child)
        end
        return "{" .. table.concat(out, ",") .. "}"
    end
    error("unsupported JSON type: " .. kind)
end

function JSON.encode(value)
    return encodeValue(value)
end

local function decodeError(message, index)
    error("JSON decode error at " .. tostring(index) .. ": " .. tostring(message))
end

function JSON.decode(input)
    if type(input) ~= "string" then
        error("JSON input must be a string")
    end

    local index = 1
    local length = #input

    local function peek()
        return input:sub(index, index)
    end

    local function nextChar()
        local ch = input:sub(index, index)
        index = index + 1
        return ch
    end

    local function skipWhitespace()
        while index <= length do
            local ch = input:sub(index, index)
            if ch ~= " " and ch ~= "\t" and ch ~= "\r" and ch ~= "\n" then
                break
            end
            index = index + 1
        end
    end

    local parseValue

    local function parseString()
        local quote = nextChar()
        if quote ~= '"' then
            decodeError("expected string", index)
        end
        local out = {}
        while index <= length do
            local ch = nextChar()
            if ch == '"' then
                return table.concat(out)
            end
            if ch == "\\" then
                local esc = nextChar()
                if esc == "u" then
                    local hex = input:sub(index, index + 3)
                    if #hex ~= 4 or not hex:match("^[0-9a-fA-F]+$") then
                        decodeError("invalid unicode escape", index)
                    end
                    local code = tonumber(hex, 16)
                    index = index + 4
                    if code < 128 then
                        out[#out + 1] = string.char(code)
                    elseif code < 2048 then
                        local b1 = math.floor(code / 64) + 192
                        local b2 = (code % 64) + 128
                        out[#out + 1] = string.char(b1, b2)
                    elseif code < 65536 then
                        local b1 = math.floor(code / 4096) + 224
                        local b2 = (math.floor(code / 64) % 64) + 128
                        local b3 = (code % 64) + 128
                        out[#out + 1] = string.char(b1, b2, b3)
                    else
                        out[#out + 1] = "?"
                    end
                else
                    local mapped = unescapeMap[esc]
                    if not mapped then
                        decodeError("invalid escape sequence", index)
                    end
                    out[#out + 1] = mapped
                end
            else
                out[#out + 1] = ch
            end
        end
        decodeError("unterminated string", index)
    end

    local function parseNumber()
        local startIndex = index
        local pattern = "^-?%d+%.?%d*[eE]?[+-]?%d*"
        local slice = input:sub(index)
        local token = slice:match(pattern)
        if not token or token == "" or token == "-" then
            decodeError("invalid number", index)
        end
        index = index + #token
        local value = tonumber(token)
        if value == nil then
            decodeError("invalid number", startIndex)
        end
        return value
    end

    local function parseArray()
        local out = {}
        nextChar() -- [
        skipWhitespace()
        if peek() == "]" then
            nextChar()
            return out
        end
        while true do
            out[#out + 1] = parseValue()
            skipWhitespace()
            local ch = nextChar()
            if ch == "]" then
                break
            end
            if ch ~= "," then
                decodeError("expected ',' or ']' in array", index)
            end
            skipWhitespace()
        end
        return out
    end

    local function parseObject()
        local out = {}
        nextChar() -- {
        skipWhitespace()
        if peek() == "}" then
            nextChar()
            return out
        end
        while true do
            if peek() ~= '"' then
                decodeError("expected string key", index)
            end
            local key = parseString()
            skipWhitespace()
            if nextChar() ~= ":" then
                decodeError("expected ':' after object key", index)
            end
            skipWhitespace()
            out[key] = parseValue()
            skipWhitespace()
            local ch = nextChar()
            if ch == "}" then
                break
            end
            if ch ~= "," then
                decodeError("expected ',' or '}' in object", index)
            end
            skipWhitespace()
        end
        return out
    end

    parseValue = function()
        skipWhitespace()
        local ch = peek()
        if ch == "" then
            decodeError("unexpected end of input", index)
        end
        if ch == '"' then
            return parseString()
        end
        if ch == "{" then
            return parseObject()
        end
        if ch == "[" then
            return parseArray()
        end
        if ch == "t" and input:sub(index, index + 3) == "true" then
            index = index + 4
            return true
        end
        if ch == "f" and input:sub(index, index + 4) == "false" then
            index = index + 5
            return false
        end
        if ch == "n" and input:sub(index, index + 3) == "null" then
            index = index + 4
            return nil
        end
        if ch == "-" or ch:match("%d") then
            return parseNumber()
        end
        decodeError("unexpected token '" .. ch .. "'", index)
    end

    local value = parseValue()
    skipWhitespace()
    if index <= length then
        decodeError("trailing characters", index)
    end
    return value
end

return JSON
