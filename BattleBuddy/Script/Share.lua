--[[
Copyright (c) 2018 Dengzhun Lu <tdaddon@163.com>

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
Source: third_party/pbs/Core/Share.lua and Share/Version0.lua, Version1.lua, Version2.lua.
]]

BattleBuddyScript = BattleBuddyScript or {}
local Script = BattleBuddyScript
local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function Encode64(text)
    local result = {}
    for i = 1, #text, 3 do
        local a, b, c = text:byte(i, i + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        for shift = 18, 0, -6 do
            local index = math.floor(n / 2 ^ shift) % 64 + 1
            result[#result + 1] = ((shift == 6 and not b) or (shift == 0 and not c))
                and "=" or alphabet:sub(index, index)
        end
    end
    return table.concat(result)
end

local function Decode64(text)
    text = text:gsub("%s", "")
    assert(not text:find("[^%w+/=]") and #text % 4 == 0, "Invalid base64")
    assert(not text:find("=[^=]") and not text:find("===", 1, true), "Invalid base64 padding")
    local result = {}
    for i = 1, #text, 4 do
        local n, padding = 0, 0
        for j = i, i + 3 do
            local char = text:sub(j, j)
            local index = alphabet:find(char, 1, true)
            if char == "=" then padding = padding + 1 else assert(index, "Invalid base64") end
            n = n * 64 + (index and index - 1 or 0)
        end
        assert(padding <= 2 and (padding == 0 or i + 3 == #text), "Invalid base64 padding")
        for shift = 16, padding * 8, -8 do
            result[#result + 1] = string.char(math.floor(n / 2 ^ shift) % 256)
        end
    end
    return table.concat(result)
end

local function Xor(a, b)
    local result, place = 0, 1
    while a > 0 or b > 0 do
        if a % 2 ~= b % 2 then result = result + place end
        a, b, place = math.floor(a / 2), math.floor(b / 2), place * 2
    end
    return result
end

local function CRC32(text)
    local crc = 4294967295
    for i = 1, #text do
        crc = Xor(crc, text:byte(i))
        for _ = 1, 8 do
            local odd = crc % 2 == 1
            crc = math.floor(crc / 2)
            if odd then crc = Xor(crc, 3988292384) end
        end
    end
    return 4294967295 - crc
end

local function Serialize(value, seen)
    local kind = type(value)
    if kind == "string" then
        return "^S" .. value:gsub("[%c ~^]", function(char)
            local byte = char:byte()
            local special = { [30] = "z", [94] = "}", [126] = "|", [127] = "{" }
            return "~" .. (special[byte] or string.char(byte + 64))
        end)
    elseif kind == "boolean" then
        return value and "^B" or "^b"
    elseif kind == "number" then
        local text = tostring(value)
        if tonumber(text) == value then return "^N" .. text end
        if value == math.huge then return "^Ninf" end
        if value == -math.huge then return "^N-inf" end
        assert(value == value, "Cannot serialize NaN")
        local mantissa, exponent = math.frexp(value)
        return "^F" .. string.format("%.0f", mantissa * 2 ^ 53) .. "^f" .. (exponent - 53)
    elseif kind == "nil" then
        return "^Z"
    end
    assert(kind == "table", "Unsupported metadata value")
    seen = seen or {}
    assert(not seen[value], "Cyclic metadata")
    seen[value] = true
    local result = { "^T" }
    for key, item in pairs(value) do
        result[#result + 1] = Serialize(key, seen)
        result[#result + 1] = Serialize(item, seen)
    end
    seen[value] = nil
    result[#result + 1] = "^t"
    return table.concat(result)
end

local function Deserialize(text)
    text = text:gsub("[%c ]", "")
    local position = 1
    local function Token()
        assert(text:sub(position, position) == "^", "Invalid serialization")
        local marker = text:sub(position + 1, position + 1)
        local finish = text:find("^", position + 2, true) or (#text + 1)
        local value = text:sub(position + 2, finish - 1)
        position = finish
        return marker, value
    end
    local function Value(marker, value, depth)
        assert(depth < 100, "Metadata nesting limit")
        if marker == "S" then
            return value:gsub("~(.)", function(char)
                local special = { z = 30, ["{"] = 127, ["|"] = 126, ["}"] = 94 }
                local byte = special[char] or (char:byte() - 64)
                assert(byte >= 0 and byte <= 127, "Invalid string escape")
                return string.char(byte)
            end)
        elseif marker == "N" then
            if value == "inf" or value == "1.#INF" then return math.huge end
            if value == "-inf" or value == "-1.#INF" then return -math.huge end
            return assert(tonumber(value), "Invalid number")
        elseif marker == "F" then
            local nextMarker, exponent = Token()
            assert(nextMarker == "f", "Invalid float")
            return assert(tonumber(value), "Invalid float") * 2 ^ assert(tonumber(exponent), "Invalid float")
        elseif marker == "B" then return true
        elseif marker == "b" then return false
        elseif marker == "Z" then return nil
        elseif marker == "T" then
            local result = {}
            while true do
                local keyMarker, keyValue = Token()
                if keyMarker == "t" then return result end
                local key = Value(keyMarker, keyValue, depth + 1)
                local itemMarker, itemValue = Token()
                local item = Value(itemMarker, itemValue, depth + 1)
                assert(key ~= nil and item ~= nil, "Invalid table")
                result[key] = item
            end
        end
        error("Invalid serialization token")
    end
    assert(Token() == "1", "Unknown serialization version")
    local marker, value = Token()
    local result = Value(marker, value, 0)
    assert(text:sub(position) == "^^", "Invalid serialization terminator")
    return result
end

function Script.Export(text, meta)
    assert(type(text) == "string", "Script text must be a string")
    meta = meta or {}
    local version = meta.version or 2
    if version == 0 then return text end
    assert(version == 1 or version == 2, "Unsupported share version")
    local name = tostring(meta.name or "BattleBuddy"):gsub("[\r\n]", " ")
    local data = { plugin = meta.plugin, key = meta.key, extra = meta.extra }
    if version == 1 then data.db = { code = text, name = name } end
    local serialized = "^1" .. Serialize(data) .. "^^"
    local header = "# Pet Battle Scripts\n# Version: " .. version .. "\n# Name: " .. name .. "\n"
    if version == 1 then
        local payload = Encode64(tostring(CRC32(serialized)) .. serialized)
        local lines = {}
        for i = 1, #payload, 32 do lines[#lines + 1] = "# " .. payload:sub(i, i + 31) end
        return header .. "# (Script) : #\n" .. table.concat(lines, "\n") .. "\n"
    end
    return header .. "# Data: " .. Encode64(serialized) .. "\n# Code Start\n" .. text .. "\n# Code End\n"
end

local function Import(text)
    local version = tonumber(text:match("# Version: (%d+)"))
    local code = text
    if version == 2 then
        code = text:match("# Code Start(.+)# Code End")
        assert(code, "Missing script code")
        code = code:match("^%s*(.-)%s*$")
        local metadata = text:match("# Data: (%S+)")
        if metadata then assert(type(Deserialize(Decode64(metadata))) == "table", "Invalid metadata") end
    elseif version == 1 or (not version and text:find("(Script)", 1, true)) then
        local payload = assert(text:match("%(Script%) : (.+)"), "Missing script data")
        payload = Decode64((payload:gsub("[# ]", "")))
        local crc, serialized = payload:match("^(%d+)(^.+)$")
        assert(crc and serialized, "Invalid script data")
        assert(CRC32(serialized) == tonumber(crc), "CRC32 error")
        local data = Deserialize(serialized)
        assert(type(data) == "table" and type(data.db) == "table", "Invalid script data")
        code = data.db.code
    else
        assert(not version or version == 0, "Unsupported share version")
    end
    assert(type(code) == "string" and code:find("%S"), "Missing script code")
    if Script.Parse then assert(Script.Parse(code), "Invalid script syntax") end
    return code
end

function Script.Import(text)
    if type(text) ~= "string" then return nil, "Share string must be a string" end
    local ok, code = pcall(Import, text)
    if ok then return code end
    return nil, tostring(code)
end
