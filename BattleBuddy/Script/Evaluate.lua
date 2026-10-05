--[[
The MIT License (MIT)

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
Source: Core/Condition.lua, Core/Action.lua, Core/Director.lua, Core/Util.lua, Extension/Conditions.lua, Extension/Actions.lua.
]]

BattleBuddyScript = BattleBuddyScript or {}
local Script = BattleBuddyScript
local Compatibility = BattleBuddyCompatibility
local unknown = {}

local function Selector(value)
    if type(value) == "string" then
        return tonumber(value:match(":(%d+)$")) or tonumber(value) or value
    end
    return value
end

function Script.Evaluate(script, snapshot, inspectors)
    local trace = {}
    local function read(container, key, optional)
        local value, state = Compatibility.ReadField(container, key, inspectors)
        if state ~= "usable" and not (optional and state == "unavailable") then error(unknown, 0) end
        return value
    end
    local function number(value)
        if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then error(unknown, 0) end
        return value
    end
    local function numeric(container, key)
        return number(read(container, key))
    end
    local function side(owner) return read(snapshot, owner) end
    local function petAt(owner, index)
        return read(read(side(owner), "pets"), index, true)
    end
    local function active(owner)
        local index = numeric(side(owner), "active")
        if index % 1 ~= 0 or index < 1 or index > 3 then error(unknown, 0) end
        return index
    end
    local function matches(record, selector, idKey)
        selector = Selector(selector)
        if type(selector) == "number" then return numeric(record, idKey) == selector end
        return read(record, "name") == selector
    end
    local function petIndex(owner, selector)
        if selector == nil then return active(owner) end
        local index = type(selector) == "string" and tonumber(selector:match("^#(%d+)$"))
        if index then return index >= 1 and index <= 3 and petAt(owner, index) and index or nil end
        local current = active(owner)
        if petAt(owner, current) and matches(petAt(owner, current), selector, "speciesID") then return current end
        for i = 1, 3 do
            local pet = petAt(owner, i)
            if pet and matches(pet, selector, "speciesID") then return i end
        end
    end
    local function ability(pet, selector)
        local abilities = read(pet, "abilities")
        local index = type(selector) == "string" and tonumber(selector:match("^#(%d+)$"))
        if index then
            if index >= 1 and index <= 3 then return read(abilities, index, true), index end
            return
        end
        local best, bestIndex, bestDuration
        for i = 1, 3 do
            local item = read(abilities, i, true)
            if item and matches(item, selector, "id") then
                local usable = read(item, "usable")
                local duration = math.max(numeric(item, "cooldown"), numeric(item, "lockdown"))
                if usable == true then return item, i end
                if not bestDuration or duration < bestDuration then best, bestIndex, bestDuration = item, i, duration end
            end
        end
        return best, bestIndex
    end
    local function auraIn(list, selector)
        if type(list) ~= "table" then error(unknown, 0) end
        for i = 1, #list do
            local aura = read(list, i)
            if matches(aura, selector, "id") then return aura end
        end
    end
    local function conditionValue(c)
        local owner, key = c.owner, c.keyword
        if key == "round" then return numeric(owner and side(owner) or snapshot, "round") end
        if key == "trap" then
            if read(snapshot, "trapAvailable") == true then return true end
            return numeric(snapshot, "trapError") == 4
        end
        if key == "weather" or key == "weather.exists" or key == "weather.duration" then
            local weather = read(snapshot, "weather")
            if weather == false then return key == "weather.duration" and 0 or false end
            local found = matches(weather, c.arg, "id")
            if key == "weather.duration" then return found and numeric(weather, "duration") or 0 end
            return found
        end
        local index = petIndex(owner, c.pet)
        if key == "exists" then return index ~= nil end
        if not index then error(unknown, 0) end
        local pet = petAt(owner, index)
        if key == "active" then return active(owner) == index end
        if key == "is" then return matches(pet, c.arg, "speciesID") end
        local fields = { hp = "health", speed = "speed", power = "power", level = "level",
            type = "type", quality = "quality", id = "speciesID", ["collected.count"] = "collectedCount",
            ["collected.max"] = "collectedMax" }
        if fields[key] then return numeric(pet, fields[key]) end
        if key == "played" or key == "collected" then return read(pet, key) end
        if key == "level.max" then return numeric(pet, "level") == 25 end
        if key == "dead" then return numeric(pet, "health") == 0 end
        if key == "hp.full" then return numeric(pet, "health") == numeric(pet, "maxHealth") end
        local function percent(p)
            local maximum = numeric(p, "maxHealth")
            if maximum <= 0 then error(unknown, 0) end
            return numeric(p, "health") / maximum * 100
        end
        if key == "hpp" then return percent(pet) end
        if key:match("^aura%.") then
            local aura = auraIn(read(pet, "auras"), c.arg) or auraIn(read(side(owner), "auras"), c.arg)
            if key == "aura.exists" then return aura ~= nil end
            return aura and numeric(aura, "duration") or 0
        end
        if key:match("^ability%.") then
            local a = ability(pet, c.arg)
            if not a then error(unknown, 0) end
            if key == "ability.usable" then return read(a, "usable") end
            if key == "ability.duration" then return math.max(numeric(a, "cooldown"), numeric(a, "lockdown")) end
            if key == "ability.type" then return numeric(a, "type") end
            if key == "ability.strong" then return numeric(a, "modifier") > 1 end
            if key == "ability.weak" then return numeric(a, "modifier") < 1 end
        end
        local opponent = owner == "ally" and "enemy" or "ally"
        local other = petAt(opponent, active(opponent))
        if key == "hp.can_be_exploded" or key == "hp.can_explode" then
            return numeric(pet, "health") <= math.floor(numeric(other, "maxHealth") * 0.4)
        end
        if key == "hp.low" then return numeric(pet, "health") < numeric(other, "health") end
        if key == "hp.high" then return numeric(pet, "health") > numeric(other, "health") end
        if key == "hp.diff" then return numeric(pet, "health") - numeric(other, "health") end
        if key == "hpp.diff" then return percent(pet) - percent(other) end
        if key == "speed.fast" then return numeric(pet, "speed") > numeric(other, "speed") end
        if key == "speed.slow" then return numeric(pet, "speed") < numeric(other, "speed") end
        error(unknown, 0)
    end
    local function condition(c)
        local value = conditionValue(c)
        if value == nil then error(unknown, 0) end
        local op = c.op
        if c.value == nil then
            if type(value) ~= "boolean" then error(unknown, 0) end
            if op == "!" then return not value end
            return value
        end
        if op == "~" then return c.value[value] == true end
        if op == "!~" then return c.value[value] ~= true end
        if op == "=" or op == "==" then return value == c.value end
        if op == "!=" then return value ~= c.value end
        if op == ">" then return value > c.value end
        if op == "<" then return value < c.value end
        if op == ">=" then return value >= c.value end
        if op == "<=" then return value <= c.value end
        error(unknown, 0)
    end
    local function action(a)
        local key = a.keyword
        if key == "quit" then return { kind = "quit" } end
        if key == "--" then return end
        if key == "test" then return { kind = "test", text = a.arg } end
        if key == "standby" or key == "catch" then
            if read(snapshot, key == "standby" and "skipAvailable" or "trapAvailable") == true then
                return { kind = key }
            end
            return
        end
        local current = active("ally")
        if key == "ability" or key == "use" then
            local found, index = ability(petAt("ally", current), a.arg)
            if found and read(found, "usable") == true then return { kind = "ability", index = index } end
        elseif key == "change" then
            local index
            if a.arg == "next" then
                local pets = read(side("ally"), "pets")
                local count = #pets
                if count < 1 or count > 3 then error(unknown, 0) end
                index = current % count + 1
                while index ~= current do
                    local p = petAt("ally", index)
                    if numeric(p, "health") ~= 0 and read(p, "canSwapIn") == true then break end
                    index = index % count + 1
                end
            else index = petIndex("ally", a.arg) end
            if index and index ~= current
                and (read(snapshot, "canSwapOut") == true or read(snapshot, "petSelect") == true)
                and read(petAt("ally", index), "canSwapIn") == true then
                return { kind = "change", index = index }
            end
        end
    end
    local function walk(lines)
        for _, node in ipairs(lines) do
            local accepted, state = true, "false"
            for _, c in ipairs(node.conditions or {}) do
                local ok, result = pcall(condition, c)
                if not ok or not result then
                    accepted, state = false, ok and "false" or "unknown"
                    break
                end
            end
            if accepted then
                if node.children then
                    local result = walk(node.children)
                    if result then return result end
                    trace[#trace + 1] = { line = node.line, state = "no_action" }
                else
                    local ok, result = pcall(action, node.action)
                    state = ok and (result and "selected" or "unavailable_action") or "unknown"
                    trace[#trace + 1] = { line = node.line, state = state }
                    if ok and result then return result end
                end
            else trace[#trace + 1] = { line = node.line, state = state } end
        end
    end
    if type(script) ~= "table" or type(script.lines) ~= "table" then
        return nil, { { state = "invalid_script" } }
    end
    return walk(script.lines), trace
end
