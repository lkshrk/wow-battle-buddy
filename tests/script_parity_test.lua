local root = (... or ".")
dofile(root .. "/BattleBuddy/Compatibility.lua")
dofile(root .. "/BattleBuddy/Script/Parser.lua")
dofile(root .. "/BattleBuddy/Script/Evaluate.lua")
local snapshot, selected
local owners = { [1] = "ally", [2] = "enemy" }
local function side(owner) return snapshot[owners[owner]] end
local function pet(owner, index) return side(owner).pets[index] end
local function ability(owner, index, slot) return pet(owner, index).abilities[slot] or {} end
local function auras(owner, index)
    if owner == 0 then return snapshot.weather and { snapshot.weather } or {} end
    return index == 0 and side(owner).auras or pet(owner, index).auras
end
Enum = { BattlePetOwner = { Ally = 1, Enemy = 2, Weather = 0 } }
NUM_BATTLE_PET_ABILITIES, PET_BATTLE_PAD_INDEX = 3, 0
format, tinsert, max, floor = string.format, table.insert, math.max, math.floor
function string.trim(value) return value:match("^%s*(.-)%s*$") end
function strsplit(separator, value)
    local parts = {}
    for item in (value .. separator):gmatch("(.-)" .. separator) do parts[#parts + 1] = item end
    return unpack(parts)
end
for i, name in ipairs({ "Humanoid", "Dragonkin", "Flying", "Undead", "Critter", "Magic", "Elemental", "Beast", "Aquatic", "Mechanical" }) do
    _G["BATTLE_PET_NAME_" .. i] = name
end
for i, name in ipairs({ "Poor", "Common", "Uncommon", "Rare", "Epic", "Legendary" }) do
    _G["BATTLE_PET_BREED_QUALITY" .. i] = name
end
C_PetBattles = {
    GetActivePet = function(owner) return side(owner).active end,
    GetNumPets = function(owner) return #side(owner).pets end,
    GetName = function(owner, index) return pet(owner, index).name, pet(owner, index).name end,
    GetBreedQuality = function(owner, index) return pet(owner, index).quality - 1 end,
    GetAbilityInfo = function(owner, index, slot)
        local a = ability(owner, index, slot)
        return a.id, a.name, nil, nil, nil, nil, a.type, false
    end,
    GetAbilityState = function(owner, index, slot)
        local a = ability(owner, index, slot)
        return a.usable, a.cooldown or 0, a.lockdown or 0
    end,
    GetAttackModifier = function(kind) return kind == 8 and 1.5 or kind == 9 and 0.67 or 1 end,
    GetNumAuras = function(owner, index) return #auras(owner, index) end,
    GetAuraInfo = function(owner, index, auraIndex)
        local a = auras(owner, index)[auraIndex]
        if a then return a.id, 1, a.duration end
    end,
    GetAbilityInfoByID = function(id) return id, ({ [900] = "Rain", [901] = "Shield" })[id] end,
    CanPetSwapIn = function(index) return pet(1, index).canSwapIn end,
    CanActivePetSwapOut = function() return snapshot.canSwapOut end,
    ShouldShowPetSelect = function() return snapshot.petSelect end,
    IsSkipAvailable = function() return snapshot.skipAvailable end,
    IsTrapAvailable = function() return snapshot.trapAvailable, snapshot.trapError end,
}
for api, field in pairs({ GetHealth = "health", GetMaxHealth = "maxHealth", GetSpeed = "speed",
    GetPower = "power", GetLevel = "level", GetPetType = "type", GetPetSpeciesID = "speciesID" }) do
    local key = field
    C_PetBattles[api] = function(owner, index) return pet(owner, index)[key] end
end
for api, kind in pairs({ UseAbility = "ability", ChangePet = "change", ForfeitGame = "quit", SkipTurn = "standby", UseTrap = "catch" }) do
    local actionKind = kind
    C_PetBattles[api] = function(index)
        assert(not selected, "PBS dispatched multiple actions")
        selected = { kind = actionKind, index = index }
    end
end
local function findPet(field, value)
    for _, owner in ipairs({ "ally", "enemy" }) do
        for _, p in ipairs(snapshot[owner].pets) do if p[field] == value then return p end end
    end
end
C_PetJournal = {
    GetNumPetTypes = function() return 10 end,
    FindPetIDByName = function(name)
        local p = findPet("name", name)
        return p.speciesID, p.collected and "guid" or nil
    end,
    GetPetInfoBySpeciesID = function() return nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, true end,
    GetNumCollectedInfo = function(id)
        local p = findPet("speciesID", id)
        return p.collectedCount, p.collectedMax
    end,
}
local ns = { Addon = {}, L = {} }
function ns.Addon:NewModule(name)
    local module = {}; ns[name] = module; return module
end
function ns.Addon:NewClass()
    local class = {}
    function class:New()
        local object = setmetatable({}, { __index = self }); object:Constructor(); return object
    end
    return class
end
function ns.Addon:GetSetting() return true end
local caches = {
    Round = { GetRound = function() return snapshot.round end,
        GetRoundByOwner = function(_, owner) return side(owner).round end },
    Played = { IsPetPlayed = function(_, owner, index) return pet(owner, index).played end },
}
ns.BattleCacheManager = { GetModule = function(_, name) return caches[name] end }
LibStub = function() return {} end
for _, file in ipairs({ "Core/Util", "Core/Stack", "Core/Condition", "Core/Action", "Core/Director", "Extension/Conditions", "Extension/Actions" }) do
    assert(loadfile(root .. "/third_party/pbs/" .. file .. ".lua"))("PBS", ns)
end
local function makePet(id, health, speed)
    return { speciesID = id, name = "Pet" .. id, health = health, maxHealth = 1000, speed = speed,
        power = 300, level = 25, type = 8, quality = 4, played = false, collected = true,
        collectedCount = 1, collectedMax = 3, canSwapIn = true, auras = {}, abilities = {
            { id = 100, name = "Strike", usable = true, cooldown = 0, lockdown = 0, type = 8, modifier = 1.5 },
            { id = 200, name = "Heal", usable = false, cooldown = 2, lockdown = 1, type = 9, modifier = 0.67 },
            { id = 300, name = "Guard", usable = true, cooldown = 0, lockdown = 0, type = 1, modifier = 1 },
        } }
end
local function reset()
    snapshot = { ally = { active = 1, round = 2, pets = { makePet(10, 800, 300), makePet(20, 1000, 200), makePet(40, 0, 250) }, auras = {} },
        enemy = { active = 1, round = 3, pets = { makePet(30, 400, 200) }, auras = {} },
        round = 4, weather = false, skipAvailable = true, trapAvailable = false, trapError = 4,
        canSwapOut = true, petSelect = false }
end
local cases = 0
local function parity(text)
    selected = nil
    local original, originalError = ns.Director:BuildScript(text)
    assert(original, originalError)
    local originalPrint = print
    print = function(value) selected = { kind = "test", text = value } end
    local ok, err = pcall(ns.Director.Action, ns.Director, original)
    print = originalPrint
    assert(ok, err)
    local expected = selected
    selected = nil
    local script, errors = BattleBuddyScript.Parse(text)
    assert(script, errors and errors[1] and errors[1].message)
    local actual = BattleBuddyScript.Evaluate(script, snapshot, { isSecret = function() return false end,
        canAccess = function() return true end })
    assert(not selected, "Evaluate dispatched a battle action")
    assert((actual and actual.kind) == (expected and expected.kind)
        and (actual and actual.index) == (expected and expected.index)
        and (actual and actual.text) == (expected and expected.text),
        text .. ": PBS=" .. tostring(expected and expected.kind) .. "/" .. tostring(expected and expected.index)
            .. " BattleBuddy=" .. tostring(actual and actual.kind) .. "/" .. tostring(actual and actual.index))
    cases = cases + 1
end
local conditions = {
    "self.dead", "self.hp > 500", "self.hp.full", "self.hp.can_be_exploded", "self.hp.can_explode",
    "self.hp.low", "self.hp.high", "self.hpp >= 80", "self.hp.diff = 400", "self.hpp.diff = 40",
    "self.aura(901).exists", "self.aura(901).duration = 3", "weather(900)", "weather(900).exists", "weather(900).duration = 4",
    "self.active", "self.ability(#1).usable", "self.ability(#2).duration = 2", "self.ability(#1).strong",
    "self.ability(#2).weak", "self.ability(#1).type = beast", "round = 4", "self.round = 2", "enemy.round = 3",
    "self.played", "self.speed = 300", "self.power = 300", "self.level = 25", "self.level.max",
    "self.speed.fast", "self.speed.slow", "self.type = beast", "self.quality = rare", "self.exists",
    "self.is(10)", "self.id ~ 10,20", "self.collected", "self.collected.count = 1", "self.collected.max = 3", "trap",
}
local covered = {}
for variant = 1, 3 do
    reset()
    if variant == 2 then
        snapshot.ally.pets[1].health, snapshot.ally.pets[1].speed = 0, 100
        snapshot.ally.pets[1].played = true
        snapshot.ally.pets[1].auras = { { id = 901, name = "Shield", duration = 3 } }
        snapshot.weather = { id = 900, name = "Rain", duration = 4 }
    elseif variant == 3 then
        snapshot.ally.pets[1].health = 1000
        snapshot.ally.auras = { { id = 901, name = "Shield", duration = 3 } }
        snapshot.ally.pets[1].level, snapshot.ally.pets[1].quality = 23, 3
        snapshot.trapAvailable, snapshot.trapError = false, 1
    end
    for _, condition in ipairs(conditions) do
        local _, _, keyword = ns.Condition:ParseCondition(condition)
        covered[keyword] = true
        parity("quit [" .. condition .. "]\nstandby")
        if ns.Condition.opts[keyword].type == "boolean" then parity("quit [!" .. condition .. "]\nstandby") end
    end
end
for keyword in pairs(ns.Condition.apis) do assert(covered[keyword], "Missing parity condition: " .. keyword) end
reset()
for _, action in ipairs({ "use(#1)", "ability(Strike)", "use(Strike:100)", "use(100)", "use(#2)", "use(999)",
    "change(next)", "change(#2)", "change(20)", "change(Pet20)", "change(Pet20:20)", "change(#1)", "change(#3)",
    "standby", "catch", "quit", "test(debug)", "-- ignored" }) do parity(action .. "\nquit") end
for _, condition in ipairs({ "ally(Pet10).active", "self(#2).hp.full", "self(20).id = 20", "self(Pet20:20).exists",
    "self.ability(Strike).usable", "self.ability(Strike:100).usable", "self.ability(200).duration = 2",
    "self.id !~ 20,30", "self.hp != 400", "self.hp <= 800", "self.hp == 800", "!self(#3).active" }) do
    parity("quit [" .. condition .. "]\nstandby")
end
snapshot.ally.pets[1].abilities[2] = { id = 100, name = "Strike", usable = true, cooldown = 0, lockdown = 0, type = 8, modifier = 1.5 }
snapshot.ally.pets[1].abilities[1].usable = false
snapshot.ally.pets[1].abilities[1].cooldown = 4
parity("use(Strike)\nstandby")
snapshot.ally.pets[1].abilities[2].usable = false
snapshot.ally.pets[1].abilities[2].cooldown = 1
parity("quit [self.ability(100).duration = 1]\nstandby")
snapshot.ally.active = 2
parity("change(next)\nquit")
snapshot.canSwapOut, snapshot.petSelect = false, true
parity("change(#1)\nquit")
snapshot.petSelect = false
parity("change(#1)\nquit")
reset()
parity("catch [trap & enemy.hpp < 35]\nchange(next) [self.dead]\nuse(Heal:200) [self.hpp < 50]\nuse(Strike:100)\nstandby")
parity("if [round >= 1]\nif [self.speed.fast]\nuse(#2) [enemy.hp > 0]\nuse(#1) [!self.aura(901).exists]\nendif\nendif\nstandby")
parity("change(next) [self.round = 1 & !self.played]\nuse(#3) [enemy.hp.can_be_exploded]\nuse(#1)\nstandby")
snapshot.trapAvailable = true
parity("catch [trap]\nquit")
snapshot.skipAvailable = false
parity("standby\nquit")
reset()
snapshot.ally.pets[1].auras = { { id = 901, name = "Shield", duration = 2 } }
snapshot.ally.auras = { { id = 901, name = "Shield", duration = 5 } }
snapshot.weather = { id = 900, name = "Rain", duration = 4 }
parity("quit [self.aura(Shield).duration = 2 & weather(Rain).duration = 4]\nstandby")
snapshot.ally.pets[2].speciesID, snapshot.ally.pets[2].name = 10, "Pet10"
snapshot.ally.active = 2
parity("change(10)\nuse(#1)")
parity("quit [self(Pet10).active]\nstandby")
snapshot.ally.pets[1].canSwapIn = false
parity("change(next)\nstandby")
print("script PBS differential parity tests passed (" .. cases .. " cases)")
