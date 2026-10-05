local root = (... or ".")
local secret = setmetatable({}, { __tostring = function() error("secret formatted") end,
    __eq = function() error("secret compared") end, __lt = function() error("secret ordered") end,
    __add = function() error("secret arithmetic") end })
local inspectors = { isSecret = function(v) return rawequal(v, secret) end, canAccess = function() return true end }
dofile(root .. "/BattleBuddy/Compatibility.lua")
dofile(root .. "/BattleBuddy/Script/Parser.lua")
dofile(root .. "/BattleBuddy/Script/Evaluate.lua")
local function pet(id, health, speed)
    return { speciesID = id, name = "Pet" .. id, health = health, maxHealth = 1000,
        speed = speed, power = 300, level = 25, type = 8, quality = 4, played = false,
        collected = true, collectedCount = 1, collectedMax = 3, canSwapIn = true, auras = {},
        abilities = { { id = 100, name = "Strike", usable = true, cooldown = 0, lockdown = 0, type = 8, modifier = 1 },
            { id = 200, name = "Heal", usable = false, cooldown = 2, lockdown = 0, type = 8, modifier = 1 } } }
end
local s = { ally = { active = 1, round = 1, pets = { pet(10, 800, 300), pet(20, 1000, 200) }, auras = {} },
    enemy = { active = 1, round = 1, pets = { pet(30, 400, 200) }, auras = {} },
    round = 1, weather = false, skipAvailable = true, trapAvailable = false, trapError = 4,
    canSwapOut = true, petSelect = false }
local calls = 0
C_PetBattles = setmetatable({}, { __index = function() return function() calls = calls + 1; error("impure evaluation") end end })
local function evaluate(text)
    local script, errors = BattleBuddyScript.Parse(text)
    assert(script, errors and errors[1] and errors[1].message)
    return BattleBuddyScript.Evaluate(script, s, inspectors)
end
local function expect(text, kind, index)
    local action = evaluate(text)
    assert(action and action.kind == kind and action.index == index, text)
end
expect("use(#2) [self.hpp < 90]\nuse(Strike:100)\nstandby", "ability", 1)
expect("if [enemy.hp < 500]\nuse(#1) [self.speed.fast]\nendif\nquit", "ability", 1)
expect("change(next) [self.round = 1 & !self.played]\nuse(#1)", "change", 2)
expect("catch [trap & enemy.hpp < 35]\nuse(#1)", "ability", 1)
expect("test(debug)\n-- ignored\nstandby", "test")
expect("use(#1) [self.hp > 0 & self.quality = rare & self.type = beast]", "ability", 1)
expect("quit [enemy.id ~ 30,40]", "quit")
for _, condition in ipairs({ "self.dead", "!self.hp.full", "self.hp > 0", "self.hpp > 0", "self.hp.diff > 0",
    "self.hpp.diff > 0", "self.hp.low", "self.hp.high", "self.hp.can_be_exploded", "!self.hp.can_explode" }) do
    local before = s.ally.pets[1].health
    s.ally.pets[1].health = secret
    assert(evaluate("quit [" .. condition .. "]") == nil, condition)
    s.ally.pets[1].health = before
end
for _, condition in ipairs({ "self.speed.fast", "!self.speed.slow", "self.speed > 0" }) do
    s.ally.pets[1].speed = secret
    assert(evaluate("quit [" .. condition .. "]") == nil)
end
s.ally.pets[1].speed = 300
s.ally.pets[1].auras = { { id = secret, name = secret, duration = secret } }
assert(evaluate("quit [!self.aura(100).exists]") == nil)
assert(evaluate("quit [self.aura(100).duration = 0]") == nil)
s.weather = { id = secret, name = secret, duration = secret }
assert(evaluate("quit [!weather(100)]") == nil)
assert(evaluate("quit [weather(100).duration = 0]") == nil)
s.ally.pets[1].health = nil
assert(evaluate("quit [!self.dead]") == nil)
assert(evaluate("use(#1) [self.hp > 0]") == nil)
assert(calls == 0)
assert(BattleBuddyCompatibility.ReadField(secret, "x", inspectors) == nil)
assert(BattleBuddyCompatibility.ReadField({ x = secret }, "x", inspectors) == nil)
assert(BattleBuddyCompatibility.PublicValue(secret, inspectors) == nil)
local p = s.ally.pets[1]
for field, conditions in pairs({
    power = { "self.power > 0" }, level = { "self.level = 25", "!self.level.max" },
    type = { "self.type != beast" }, quality = { "self.quality >= rare" },
    speciesID = { "self.id != 10", "!self.is(10)" },
    played = { "!self.played" }, collected = { "!self.collected" },
    collectedCount = { "self.collected.count = 0" }, collectedMax = { "self.collected.max = 3" },
}) do
    local saved = p[field]
    p[field] = secret
    for _, condition in ipairs(conditions) do assert(evaluate("quit [" .. condition .. "]") == nil, condition) end
    p[field] = saved
end
for field, condition in pairs({ usable = "!self.ability(#1).usable", cooldown = "self.ability(#1).duration = 0",
    lockdown = "self.ability(#1).duration = 0", modifier = "!self.ability(#1).strong", type = "self.ability(#1).type = beast" }) do
    local saved = p.abilities[1][field]
    p.abilities[1][field] = secret
    assert(evaluate("quit [" .. condition .. "]") == nil, condition)
    p.abilities[1][field] = saved
end
local result, trace = evaluate("quit [!self.dead]\nstandby")
assert(result.kind == "standby" and trace[1].state == "unknown")
local before = s.round
s.round = secret
assert(evaluate("quit [round > 0]") == nil)
s.round = before
assert(BattleBuddyScript.Evaluate(BattleBuddyScript.Parse("quit [round > 0]"), s) == nil)
print("script evaluation tests passed")
