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
Source: PBS Core/Condition.lua, Core/Action.lua, Core/Director.lua, Core/Stack.lua, Core/Util.lua, Extension/Conditions.lua, Extension/Snippets.lua (fe78bd6).
]]

BattleBuddyScript = BattleBuddyScript or {}
local S = BattleBuddyScript
local function trim(value) return (value:gsub("^%s+", ""):gsub("%s+$", "")) end
local function quote(value)
    local name, arg = value:match("^([^()]-)%s*%((.+)%)$")
    if name then return name, tonumber(arg:match(":(%d+)$")) or arg end
    return value
end
local types = { "humanoid", "dragonkin", "flying", "undead", "critter", "magic", "elemental", "beast", "aquatic", "mechanical" }
local qualities = { "poor", "common", "uncommon", "rare", "epic", "legendary" }
local function enum(value, names, prefix)
    if type(value) == "string" then
        local id = tonumber(value:match(":(%d+)$"))
        if id and names[id] then return id end
        value = value:lower()
    end
    for i, name in ipairs(names) do
        local localized = _G[prefix .. i]
        if value == i or value == name or (type(localized) == "string" and value == localized:lower()) then return i end
    end
end
local options = {}
local function register(names, overrides)
    for name in names:gmatch("%S+") do
        local opts = { owner = "required", pet = true, arg = false, type = "compare", valueParse = tonumber }
        for key, value in pairs(overrides or {}) do opts[key] = value end
        options[name] = opts
    end
end
register("hp hpp hp.diff hpp.diff speed power level collected.count collected.max")
register("dead hp.full hp.can_be_exploded hp.can_explode active played level.max exists collected", { type = "boolean" })
register("hp.low hp.high speed.fast speed.slow", { type = "boolean", pet = false })
register("aura.exists ability.usable ability.strong ability.weak is", { type = "boolean", arg = true })
register("aura.duration ability.duration", { arg = true })
register("weather weather.exists", { type = "boolean", owner = "not-allowed", pet = false, arg = true })
register("weather.duration", { owner = "not-allowed", pet = false, arg = true })
register("round", { owner = "optional", pet = false })
register("trap", { type = "boolean", owner = "not-allowed", pet = false })
register("id", { type = "equality" })
register("type ability.type", { type = "equality", valueParse = function(value) return enum(value, types, "BATTLE_PET_NAME_") end })
options["ability.type"].arg = true
register("quality", { valueParse = function(value) return enum(value, qualities, "BATTLE_PET_BREED_QUALITY") end })
S.ConditionOptions = options
local actions = { test = true, change = true, ability = true, use = true, quit = true, standby = true, catch = true, ["--"] = true }
S.ActionKeywords = actions

local function parseApi(text)
    local parts, part, depth = {}, "", 0
    for char in text:gmatch(".") do
        if char == "." and depth == 0 then parts[#parts + 1], part = part, ""
        else part = part .. char end
        if char == "(" then depth = depth + 1 elseif char == ")" then depth = depth - 1 end
    end
    parts[#parts + 1] = part
    local owner, pet = quote(parts[1])
    if owner == "self" then owner = "ally" end
    local offset = 1
    if owner == "ally" or owner == "enemy" then offset = 2 else owner, pet = nil, nil end
    local keyword, arg = quote(parts[offset] or "")
    if parts[offset + 1] then keyword = keyword .. "." .. parts[offset + 1] end
    if parts[offset + 2] then keyword = "" end
    return owner, pet, keyword, arg
end

local function condition(text)
    local non, api, op, value = text:match("^(!?)([^!=<>~]+)%s*([!=<>~]*)%s*(.*)$")
    assert(non, "Cannot parse condition")
    local owner, pet, keyword, arg = parseApi(trim(api))
    local opts = options[keyword]
    assert(opts, "Unknown condition: " .. keyword)
    if opts.type == "boolean" then
        assert(op == "" and value == "", "Boolean condition cannot have operator or value")
        op, value = non == "!" and "!" or "=", nil
    else
        assert(non == "" and op ~= "" and value ~= "", "Condition requires operator and value")
        local operators = { ["="] = true, ["=="] = true, ["!="] = true, ["~"] = true, ["!~"] = true }
        if opts.type == "compare" then operators[">"], operators["<"], operators[">="], operators["<="] = true, true, true, true end
        assert(operators[op], "Invalid operator")
        local function convert(item)
            item = trim(item)
            return assert(opts.valueParse(tonumber(item) or item), "Invalid condition value")
        end
        if op == "~" or op == "!~" then
            local values = {}
            for item in (value .. ","):gmatch("(.-),") do values[convert(item)] = true end
            value = values
        else value = convert(value) end
    end
    assert(opts.owner ~= "required" or owner, "Condition requires owner")
    assert(opts.owner ~= "not-allowed" or not owner, "Condition forbids owner")
    assert(opts.pet or pet == nil, "Condition forbids pet selector")
    assert(opts.arg or arg == nil, "Condition forbids argument")
    return { owner = owner, pet = pet, keyword = keyword, arg = tonumber(arg) or arg, op = op, value = value }
end

function S.Parse(text)
    if type(text) ~= "string" then return nil, { { line = 1, message = "Script must be text" } } end
    local script, stack, lineNumber = { lines = {} }, {}, 0
    stack[1] = { children = script.lines }
    for line in (text:gsub("\r\n", "\n"):gsub("\r", "\n") .. "\n"):gmatch("(.-)\n") do
        lineNumber = lineNumber + 1
        line = trim(line)
        if line ~= "" then
            local ok, problem = pcall(function()
                local action, conditions = line, {}
                if line:sub(1, 2) ~= "--" then
                    action = line:match("^/?(.+)$")
                    if line:find("[", 1, true) then
                        local expression
                        action, expression = line:match("^/?([^%[]-)%s*%[([^%]]+)%]$")
                        assert(action, "Invalid condition brackets")
                        for item in (expression .. "&"):gmatch("(.-)&") do
                            item = trim(item)
                            if item ~= "" then conditions[#conditions + 1] = condition(item) end
                        end
                    end
                end
                local node = { line = lineNumber, conditions = conditions }
                if action == "endif" or action == "ei" then
                    assert(#stack > 1, "Unpaired endif")
                    stack[#stack] = nil
                else
                    if action == "if" then node.children = {}
                    elseif action:sub(1, 2) == "--" then node.action = { keyword = "--", arg = action }
                    else
                        local keyword, arg = quote(action)
                        assert(actions[keyword], "Unknown action: " .. keyword)
                        node.action = { keyword = keyword, arg = arg }
                    end
                    local children = stack[#stack].children
                    children[#children + 1] = node
                    if node.children then stack[#stack + 1] = node end
                end
            end)
            if not ok then return nil, { { line = lineNumber, message = tostring(problem):gsub("^.-:%d+: ", "") } } end
        end
    end
    if #stack > 1 then return nil, { { line = stack[#stack].line, message = "Unpaired if" } } end
    return script, {}
end

function S.Snippets(prefix, snapshot, inspectors)
    if type(prefix) ~= "string" then return end
    local C, list = BattleBuddyCompatibility, {}
    local function public(value) return (C.PublicValue or C.ClassifyValue)(value, inspectors) end
    local function field(record, key)
        record = public(record)
        if type(record) == "table" then return public(record[key]) end
    end
    local function rows(records, columns, isPet)
        records = public(records)
        if type(records) ~= "table" then return end
        local i = 1
        while true do
            local record = field(records, i)
            if record == nil then break end
            local name = field(record, "name")
            local id = field(record, isPet and "speciesID" or "id")
            if type(name) == "string" and type(id) == "number" then
                list[#list + 1] = { icon = field(record, "icon") }
                list[#list + 1] = { text = name, value = string.format("(%s:%d)", name, id) }
                if columns == 3 then list[#list + 1] = { text = "#" .. i, value = "(#" .. i .. ")" } end
            end
            i = i + 1
        end
    end
    local expression = prefix:match("[[&]%s*([^&[]+)$")
    local owner, selector, word, arg, non
    if expression then
        local rest
        non, rest = expression:match("^(!?)%s*(.+)$")
        if not rest then return end
        owner, selector, word, arg = parseApi(rest)
        if word == "" then word = prefix:match("(%w+)$") end
    else word = prefix:match("^%s*(%w+)$") end
    if not word then return end
    local side = field(snapshot, owner or "ally")
    local pets = field(side, "pets")
    local index = field(side, "active")
    if selector then
        index = type(selector) == "string" and tonumber(selector:match("^#(%d+)$")) or nil
        if not index and type(public(pets)) == "table" then
            for i = 1, 3 do
                local pet = field(pets, i)
                local speciesID = field(pet, "speciesID")
                if selector == field(pet, "name") or (speciesID ~= nil and tonumber(selector) == speciesID) then index = i break end
            end
        end
    end
    local pet = type(index) == "number" and field(pets, index) or nil
    local columns
    if not arg and ((not expression and (word == "use" or word == "ability")) or (expression and word == "ability")) then
        rows(field(pet, "abilities"), 3)
        columns = 3
    elseif not arg and ((not expression and word == "change") or (expression and (word == "self" or word == "ally" or word == "enemy" or word == "is"))) then
        if word == "enemy" then pets = field(field(snapshot, "enemy"), "pets") end
        rows(pets, 3, true)
        columns = 3
        if word == "change" then
            list[#list + 1], list[#list + 2], list[#list + 3] = {}, { text = "next", value = "(next)" }, {}
        end
    elseif expression and not arg and word == "aura" then
        rows(field(pet, "auras"), 2)
        rows(field(side, "auras"), 2)
        columns = 2
    elseif expression and not arg and word == "weather" then
        rows(field(snapshot, "weathers"), 2)
        columns = 2
    else
        local words = {}
        local function add(value) words[value] = true end
        if expression then
            if not owner then add("self") add("ally") add("enemy") end
            for keyword in pairs(options) do add(keyword:match("^[^.]+")) add(keyword) end
        else
            add("if") add("endif")
            for keyword in pairs(actions) do add(keyword) end
        end
        local sorted = {}
        for keyword in pairs(words) do sorted[#sorted + 1] = keyword end
        table.sort(sorted)
        for _, keyword in ipairs(sorted) do
            local opts, include = expression and options[keyword], true
            if opts then
                local dot = keyword:find(".", 1, true)
                include = not ((opts.owner == "required" and not owner) or (opts.owner == "not-allowed" and owner)
                    or (not opts.pet and selector) or (non == "!" and opts.type ~= "boolean")
                    or (not opts.arg and arg) or (opts.arg and not arg and dot and #word >= dot)
                    or (dot and dot > #word))
            end
            if include and keyword ~= word and keyword:sub(1, #word) == word then
                list[#list + 1] = { text = "|cff00ff00" .. word .. "|r" .. keyword:sub(#word + 1), value = keyword:sub(#word + 1) }
            end
        end
        columns = 1
    end
    if #list > 0 then return list, columns end
end
