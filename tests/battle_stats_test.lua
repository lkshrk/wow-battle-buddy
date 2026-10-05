local root = (... or ".")
local Frames = dofile(root .. "/tests/support/frames.lua")
local secret = setmetatable({}, {
    __tostring = function() error("secret formatted") end,
    __lt = function() error("secret compared") end,
    __le = function() error("secret compared") end,
    __add = function() error("secret arithmetic") end,
    __div = function() error("secret arithmetic") end,
})
local restricted = {}
issecretvalue = function(value) return rawequal(value, secret) end
canaccessvalue = function(value) return not rawequal(value, restricted) end
local combat = false
InCombatLockdown = function() return combat end
UIParent = CreateFrame("Frame", "UIParent")
Enum = { BattlePetOwner = { Ally = 1, Enemy = 2 } }
BattleBuddyDB = { settingOverrides = {} }
dofile(root .. "/BattleBuddy/Config.lua")
dofile(root .. "/BattleBuddy/Compatibility.lua")
dofile(root .. "/BattleBuddy/BattleStats.lua")
local Stats = BattleBuddyBattleStats
local function Equal(actual, expected)
    assert(actual == expected, tostring(actual) .. " ~= " .. tostring(expected))
end
for _, key in ipairs({ "battleRound", "battleStats", "battleHealth" }) do
    Equal(BattleBuddyConfig.GetSetting(key), true)
end

local function Formatted(health, maximum, power, speed)
    return Stats.FormatStats({ health = health, maximum = maximum, power = power, speed = speed })
end
local values = Formatted(1363, 1400, 341, 244)
Equal(values.health, "97%")
Equal(values.power, "341")
Equal(values.speed, "244")
Equal(Formatted(0, 1400, 0, 0).health, "0%")
Equal(Formatted(0, 1400, 0, 0).power, "0")
for _, bad in ipairs({ secret, restricted, false, "123", -1, math.huge, 0/0 }) do
    values = Formatted(bad, 1400, bad, bad)
    Equal(values.health, nil)
    Equal(values.power, "?")
    Equal(values.speed, "?")
    Equal(Formatted(100, bad, 1, 1).health, nil)
end
Equal(Formatted(nil, nil, nil, nil).power, "?")
Equal(Formatted(100, 0, 1, 1).health, nil)
Equal(Formatted(101, 100, 1, 1).health, nil)
local inspector = issecretvalue
issecretvalue = nil
Equal(Formatted(1, 2, 3, 4).power, "?")
issecretvalue = inspector

local reads, actions = 0, 0
local active = { 1, 2 }
local health = { 1363, 923 }
C_PetBattles = {
    GetActivePet = function(owner) return active[owner] end,
    GetHealth = function(owner, slot)
        assert(slot == active[owner]); reads = reads + 1; return health[owner]
    end,
    GetMaxHealth = function(owner) return owner == 1 and 1400 or 923 end,
    GetPower = function(owner) return owner == 1 and 341 or 152 end,
    GetSpeed = function(owner) return owner == 1 and 244 or 226 end,
}
for _, action in ipairs({ "UseAbility", "SkipTurn", "ChangePet", "ForfeitGame", "UseTrap" }) do
    C_PetBattles[action] = function() actions = actions + 1; error("action dispatched") end
end
C_Timer = { After = function() error("timer scheduled") end }
BattleBuddyTeams = { Load = function() error("team loaded") end }
values = Stats.ReadPet(1)
Equal(values.health, 1363)
for _, bad in ipairs({ secret, restricted, 0, 4, 1.5, "1" }) do
    active[1] = bad
    local before = reads
    Equal(Stats.ReadPet(1).health, nil)
    Equal(reads, before)
end
active[1] = 1
local getPower = C_PetBattles.GetPower
C_PetBattles.GetPower = function() error("unavailable") end
Equal(Stats.FormatStats(Stats.ReadPet(1)).power, "?")
C_PetBattles.GetPower = nil
Equal(Stats.FormatStats(Stats.ReadPet(1)).power, "?")
C_PetBattles.GetPower = getPower

local function NativeFrame()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame.TopVersusText = frame:CreateFontString(nil, "ARTWORK", "GameFont_Gigantic")
    frame.TopVersusText:SetText("native versus")
    for _, key in ipairs({ "ActiveAlly", "ActiveEnemy" }) do
        local unit = CreateFrame("Frame", nil, frame)
        unit.HealthBarBG = unit:CreateTexture()
        unit.HealthText = unit:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        unit.HealthText:SetPoint("CENTER", unit.HealthBarBG, "CENTER", 0, 0)
        unit.HealthText:SetText("native health")
        frame[key] = unit
    end
    return frame
end
PetBattleFrame = NativeFrame()
local function Event(name, ...)
    assert(Stats.events.events[name], "unregistered event: " .. name)
    Frames.Fire(Stats.events, "OnEvent", name, ...)
end
Event("PET_BATTLE_OPENING_START")
local display = Stats.display
assert(display)
Frames.AssertAnchor(display.round, 1, { "TOP", PetBattleFrame, "TOP", -1, -17 })
Equal(display.round.font[2], 24)
Frames.AssertText(display.round, "?")
Frames.AssertShown(PetBattleFrame.TopVersusText, false)
for index, unit in ipairs({ PetBattleFrame.ActiveAlly, PetBattleFrame.ActiveEnemy }) do
    local side = display.sides[index]
    Frames.AssertAnchor(side.row, 1, { "TOPLEFT", unit,
        index == 1 and "BOTTOMRIGHT" or "BOTTOMLEFT", index == 1 and -188 or 42, 10 })
    Frames.AssertSize(side.row, 165, 16)
    for column, key in ipairs({ "health", "power", "speed" }) do
        local stat = side[key]
        Frames.AssertSize(stat.icon, 16, 16)
        Frames.AssertAnchor(stat.icon, 1, { "LEFT", side.row, "LEFT", (column-1)*55, 0 })
        Frames.AssertAnchor(stat.text, 1, { "LEFT", stat.icon, "RIGHT", 2, 0 })
        Frames.AssertShown(stat.icon, true)
        Frames.AssertShown(stat.text, true)
    end
    Frames.AssertText(unit.HealthText, "native health")
    Frames.AssertAnchor(unit.HealthText, 1, { "CENTER", unit.HealthBarBG, "CENTER", 0, 0 })
end
Frames.AssertText(display.sides[1].health.text, "97%")
Frames.AssertText(display.sides[2].health.text, "100%")
health[1] = 700
Frames.AssertText(display.sides[1].health.text, "97%")
Event("PET_BATTLE_HEALTH_CHANGED", secret, secret, secret)
Frames.AssertText(display.sides[1].health.text, "50%")
health[1] = secret
Event("PET_BATTLE_MAX_HEALTH_CHANGED")
Frames.AssertShown(display.sides[1].health.text, false)
Frames.AssertShown(display.sides[1].health.icon, false)
Frames.AssertText(PetBattleFrame.ActiveAlly.HealthText, "native health")
health[1] = 0
Event("PET_BATTLE_PET_CHANGED")
Frames.AssertText(display.sides[1].health.text, "0%")
for _, round in ipairs({ 0, 3, secret }) do
    Event("PET_BATTLE_PET_ROUND_PLAYBACK_COMPLETE", round)
    Frames.AssertText(display.round, "?")
end
for _, event in ipairs({ "PET_BATTLE_AURA_APPLIED", "PET_BATTLE_AURA_CHANGED",
    "PET_BATTLE_AURA_CANCELED", "PET_BATTLE_OPENING_DONE" }) do Event(event) end
for _, key in ipairs({ "battleRound", "battleStats", "battleHealth" }) do
    assert(BattleBuddyConfig.SetSetting(key, false))
    Event("PET_BATTLE_PET_CHANGED")
    Frames.AssertShown(display.round, BattleBuddyConfig.GetSetting("battleRound"))
    Frames.AssertShown(display.sides[1].row, BattleBuddyConfig.GetSetting("battleStats"))
    Frames.AssertShown(PetBattleFrame.ActiveAlly.HealthText, BattleBuddyConfig.GetSetting("battleHealth"))
end
Frames.AssertShown(PetBattleFrame.TopVersusText, true)
for _, key in ipairs({ "battleRound", "battleStats", "battleHealth" }) do
    BattleBuddyConfig.SetSetting(key, true)
end
Event("PET_BATTLE_PET_CHANGED")
combat = true
local before = reads
Event("PET_BATTLE_HEALTH_CHANGED")
Equal(reads, before)
combat = false
Event("PET_BATTLE_CLOSE")
Frames.AssertShown(display.round, false)
Frames.AssertShown(display.sides[1].row, false)
Frames.AssertShown(PetBattleFrame.TopVersusText, true)
Frames.AssertShown(PetBattleFrame.ActiveAlly.HealthText, true)
Event("PET_BATTLE_HEALTH_CHANGED")
Equal(reads, before)
assert(not Stats.events.scripts.OnUpdate)
Equal(actions, 0)

local registered
BattleBuddyDev = { RegisterView = function(name, show, hide, shown)
    registered = { name, show, hide, shown }; return true
end }
Event("ADDON_LOADED", "BattleBuddy")
Equal(registered[1], "battle-stats")
assert(registered[2]())
assert(registered[4]())
Frames.AssertText(Stats.preview.display.round, "1")
registered[3]()
assert(not registered[4]())
combat = true
assert(not registered[2]())
combat = false
Event("PET_BATTLE_OPENING_START")
assert(not registered[2]())
Event("PET_BATTLE_CLOSE")
Equal(actions, 0)
Frames.Reset()
print("battle_stats_test: passed")
