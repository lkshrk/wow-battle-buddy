local root = (... or ".")
local secret = setmetatable({}, { __tostring = function() error("secret string") end })
issecretvalue = function(value) return rawequal(value, secret) end
canaccessvalue = function() return true end
dofile(root .. "/BattleBuddy/Compatibility.lua")
dofile(root .. "/BattleBuddy/EncounterCatalog.lua")
dofile(root .. "/BattleBuddy/TargetDetection.lua")

local function record(id, npc, name, hints)
    return { encounterID = "shipped." .. id, origin = "shipped", recordRevision = 1,
        selectors = {{ npcID = npc }}, display = { fallbackLabel = name, aliases = { "Shared" } },
        content = { gossipHints = hints, enemyPets = {{ speciesID = npc + 1000 }} },
        support = { state = "unverified" } }
end
local catalog = BattleBuddyEncounterCatalog.BuildView({ schemaVersion = 1, catalogRevision = 1,
    records = {record("first", 101, "Alpha", {"Copper console"}), record("second", 102, "Beta"),
        record("third", 103, "Gamma"), record("fourth", 104, "Delta")} })
local guid, name, species, gossip = "Creature-0-1-2-3-101-123", "Beta", nil, nil
UnitGUID = function() return guid end
UnitName = function() return name end
UnitBattlePetSpeciesID = function() return species end
GetLocale = function() return "enUS" end
C_GossipInfo = { GetText = function() return gossip end, GetOptions = function() return {} end }
local calls = 0
C_PetJournal = { SetPetLoadOutInfo = function() calls = calls + 1 end }
C_PetBattles = { UseAbility = function() calls = calls + 1 end }
local events, handler = {}, nil
CreateFrame = function()
    return { RegisterEvent = function(_, event) events[event] = true end,
        SetScript = function(_, script, fn) assert(script == "OnEvent"); handler = fn end }
end
local detection = BattleBuddyTargetDetection
detection.Start(catalog)
assert(detection.Refresh().npcID == 101)
guid, name, gossip = secret, secret, "Copper console"
handler(nil, "GOSSIP_SHOW")
assert(detection.GetCurrent().npcID == 101)
gossip, name = nil, "Beta!"
assert(detection.Refresh().npcID == 102)
name = "Shared"
assert(detection.Refresh().state == "ambiguous")
name = "Unknown"
assert(detection.Refresh().state == "unresolved")
guid, name = "Creature-0-1-2-3-999-123", "Alpha"
assert(detection.Refresh().state == "unresolved")
guid, name, species = secret, secret, 1102
assert(detection.Refresh().npcID == 102)
species, C_GossipInfo, C_Scenario = secret, nil, nil
assert(detection.Refresh().state == "unresolved")
assert(events.PLAYER_TARGET_CHANGED and events.GOSSIP_SHOW and events.NAME_PLATE_UNIT_ADDED)
assert(calls == 0)

UnitIsUnit = function() return false end
guid, name, species = secret, "Unknown", nil
UnitName = function() return name end
C_GossipInfo = { GetText = function() return "Copper console" end }
handler(nil, "GOSSIP_SHOW")
assert(detection.GetCurrent().npcID == 101)
assert(detection.Refresh("mouseover").state == "unresolved", "gossip belongs only to its NPC")
handler(nil, "GOSSIP_CLOSED")

local exists = { mouseover = false, softinteract = false, target = true }
UnitExists = function(unit) return exists[unit] end
UnitGUID = function(unit)
    if unit == "target" then return "Creature-0-1-2-3-101-123" end
    if unit == "softinteract" and exists[unit] == true then return "Creature-0-1-2-3-102-123" end
    return secret
end
handler(nil, "PLAYER_TARGET_CHANGED")
assert(detection.GetCurrent().npcID == 101)
handler(nil, "UPDATE_MOUSEOVER_UNIT")
assert(detection.GetCurrent().npcID == 101, "leaving mouseover restores actual target")
exists.softinteract = true
handler(nil, "UPDATE_MOUSEOVER_UNIT")
assert(detection.GetCurrent().npcID == 102, "soft interact precedes actual target")
exists.softinteract = false
handler(nil, "PLAYER_SOFT_INTERACT_CHANGED")
assert(detection.GetCurrent().npcID == 101, "leaving soft interact restores actual target")
exists.mouseover = secret
handler(nil, "UPDATE_MOUSEOVER_UNIT")
assert(detection.GetCurrent().state == "unresolved", "secret presence is not absence")
exists.mouseover = true
name = "Shared"
handler(nil, "UPDATE_MOUSEOVER_UNIT")
assert(detection.GetCurrent().state == "ambiguous", "present ambiguous source cannot fall through")
handler(nil, "PLAYER_TARGET_CHANGED")
assert(detection.GetCurrent().state == "ambiguous", "target events retain source priority")
exists.mouseover, name = false, "Unknown"
UnitExists = nil
UnitGUID = function() return guid end

for _, id in ipairs({ 101, 102, 103, 104, 102 }) do
    guid = "Creature-0-1-2-3-" .. id .. "-123"
    detection.Refresh()
end
local recent = detection.GetRecent()
assert(#recent == 3 and recent[1] == 102 and recent[2] == 104 and recent[3] == 103)
recent[1] = 999
assert(detection.GetRecent()[1] == 102)
guid = secret
detection.Refresh()
assert(detection.GetRecent()[1] == 102)

guid, name = "Player-1-1234", "Alpha"
assert(detection.Refresh().state == "unresolved")
guid, name = "Pet-0-1-2-3-101-123", "Alpha"
assert(detection.Refresh().state == "unresolved")
guid, name = secret, secret
assert(not events.OnUpdate)

local function font(text)
    return { IsShown = function() return true end, GetText = function() return text end }
end
name = secret
TargetFrame = font("Alpha")
assert(detection.Refresh().npcID == 101)
TargetFrame = font(secret)
assert(detection.Refresh().state == "unresolved")
C_Scenario = { GetInfo = function() return "Beta" end }
handler(nil, "SCENARIO_UPDATE")
assert(detection.GetCurrent().npcID == 102)
C_Scenario = nil
TargetFrame = nil
local correlated = false
UnitIsUnit = function() return correlated end
UnitName = function(unit) return unit == "nameplate1" and "Alpha" or secret end
handler(nil, "PLAYER_TARGET_CHANGED")
handler(nil, "NAME_PLATE_UNIT_ADDED", "nameplate1")
assert(detection.GetCurrent().state == "unresolved")
correlated = true
handler(nil, "NAME_PLATE_UNIT_ADDED", "nameplate1")
assert(detection.GetCurrent().npcID == 101)
handler(nil, "NAME_PLATE_UNIT_ADDED", secret)
assert(detection.GetCurrent().npcID == 101)
local copy = detection.GetCurrent()
copy.encounter.display.fallbackLabel = "changed"
assert(detection.GetCurrent().encounter.display.fallbackLabel == "Alpha")
C_GossipInfo = { GetText = function() return "Copper console" end }
handler(nil, "GOSSIP_SHOW")
assert(detection.GetCurrent().npcID == 101)
handler(nil, "GOSSIP_CLOSED")
assert(detection.GetCurrent().state == "unresolved")
assert(calls == 0)
