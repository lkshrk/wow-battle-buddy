local root = (... or ".")
local secret = setmetatable({}, { __tostring = function() error("secret string") end })
issecretvalue = function(value) return rawequal(value, secret) end
canaccessvalue = function() return true end
dofile(root .. "/BattleBuddy/Compatibility.lua")
dofile(root .. "/BattleBuddy/EncounterCatalog.lua")
dofile(root .. "/BattleBuddy/Store.lua")
dofile(root .. "/BattleBuddy/Teams.lua")
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
assert(detection.Refresh().key == "name:unknown")
guid, name = "Creature-0-1-2-3-999-123", "Alpha"
assert(detection.Refresh().key == 999)
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
assert(detection.Refresh("mouseover").key == "name:unknown", "gossip belongs only to its NPC")
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
assert(detection.GetCurrent().key == "name:unknown", "secret presence is not absence")
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

local teams = BattleBuddyTeams
local store = assert(teams.Initialize(nil))
BattleBuddyDB = store
BattleBuddyLoadout = { SetTarget = function() error("detection changed loadout") end }
teams.LoadTeam = function() error("detection loaded a team") end
UnitName = function() return name end
UnitGUID = function() return guid end
C_GossipInfo, TargetFrame, C_Scenario = nil, nil, nil
guid, name = "Creature-0-1-2-3-901-123", "My Opponent"
assert(detection.Refresh().key == 901)
local saved = assert(teams.CreateTeam(store, { name = "My team", script = "ability(1)" }))
assert(teams.AttachTarget(store, saved.teamID, detection.Current()))
assert(detection.TeamsForCurrent(store)[1].teamID == saved.teamID)
assert(detection.Current().name == "My Opponent" and detection.Current().source == "target")
guid, name = secret, "my opponent!"
assert(detection.Refresh().key == 901)
assert(detection.TeamsForCurrent(store)[1].script == "ability(1)")
name = "Beta"
assert(detection.Refresh().key == 102)
assert(detection.Current().encounterID == "shipped.second")
assert(#detection.TeamsForCurrent(store) == 0)
name = "Uncatalogued"
assert(detection.Refresh().key == "name:uncatalogued")
assert(detection.Current().npcID == nil)
assert(#detection.TeamsForCurrent(store) == 0)
local hidden = assert(teams.CreateTeam(store, { name = "Hidden ID team" }))
assert(teams.AttachTarget(store, hidden.teamID, detection.Current()))
store = assert(teams.Initialize(store))
BattleBuddyDB = store
name = "Uncatalogued!"
assert(detection.Refresh().key == "name:uncatalogued")
assert(detection.TeamsForCurrent(store)[1].teamID == hidden.teamID)
guid = "Creature-0-1-2-3-904-123"
assert(detection.Refresh().key == 904)
assert(detection.TeamsForCurrent(store)[1].teamID == hidden.teamID,
    "a name-only saved target still matches when its ID becomes readable")
guid = secret
local duplicate = assert(teams.DuplicateTeam(store, hidden.teamID))
assert(detection.Refresh().key == "name:uncatalogued", "multiple teams for one target are not ambiguous")
assert(#detection.TeamsForCurrent(store) == 2)
assert(teams.SetTargetTeams(store, "name:uncatalogued", { duplicate.teamID, hidden.teamID }))
assert(detection.TeamsForCurrent(store)[1].teamID == duplicate.teamID)
assert(teams.DeleteTeam(store, duplicate.teamID, true))
local other = assert(teams.CreateTeam(store, { name = "Second opponent" }))
assert(teams.AttachTarget(store, other.teamID, { npcID = 902, name = "My Opponent" }))
name = "My Opponent"
assert(detection.Refresh().ambiguous and detection.Current().key == nil)
assert(#detection.TeamsForCurrent(store) == 0)
assert(teams.AttachTarget(store, other.teamID, { npcID = 903, name = "Beta" }))
name = "Beta"
assert(detection.Refresh().key == 903, "saved names precede the catalogue")
name = secret
TargetFrame = font("My Opponent")
assert(detection.Refresh().ambiguous)
TargetFrame = font("Uncatalogued")
assert(detection.Refresh().key == "name:uncatalogued")
TargetFrame = nil
C_GossipInfo = { GetText = function() return "Speak with Uncatalogued." end }
handler(nil, "GOSSIP_SHOW")
assert(detection.Current().key == "name:uncatalogued" and detection.Current().source == "npc")
handler(nil, "GOSSIP_CLOSED")
assert(detection.Current().key == nil)
name = "My Opp..."
assert(detection.Refresh().ambiguous)
name = "Unknown..."
assert(detection.Refresh().key == nil, "a truncated name cannot become a new identity")
guid, name = "Creature-0-1-2-3-9999-123", "My Opponent"
assert(detection.Refresh().key == 9999, "readable identity precedes ambiguous names")
assert(#detection.TeamsForCurrent(store) == 0)
guid, name = secret, secret
assert(detection.Refresh().key == nil)
UnitName = function(unit) return unit == "nameplate1" and "New Nameplate NPC" or secret end
correlated = false
handler(nil, "NAME_PLATE_UNIT_ADDED", "nameplate1")
assert(detection.Current().key == nil)
correlated = true
handler(nil, "NAME_PLATE_UNIT_ADDED", "nameplate1")
assert(detection.Current().key == "name:new nameplate npc")
assert(detection.Current().name == "New Nameplate NPC")
UnitName = function() return "Public Player" end
UnitIsPlayer = function() return true end
assert(detection.Refresh().key == nil, "a public player flag excludes a secret-GUID player")
UnitIsPlayer = function() return secret end
UnitName = function() return secret end
assert(detection.Refresh().key == nil)
assert(calls == 0)
