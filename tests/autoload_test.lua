local root = (... or ".")
local Frames = dofile(root .. "/tests/support/frames.lua")
local secret = {}
issecretvalue = function(value) return value == secret end
canaccessvalue = function(value) return value ~= secret end
hooksecurefunc = function(object, key, callback)
    local original = object[key]
    object[key] = function(...)
        local result, reason = original(...)
        callback(...)
        return result, reason
    end
end
dofile(root .. "/BattleBuddy/Compatibility.lua")
dofile(root .. "/BattleBuddy/Config.lua")
dofile(root .. "/BattleBuddy/Store.lua")
dofile(root .. "/BattleBuddy/Teams.lua")
dofile(root .. "/BattleBuddy/TeamStrings.lua")
dofile(root .. "/BattleBuddy/EncounterCatalog.lua")
dofile(root .. "/BattleBuddy/TargetDetection.lua")
UIParent = CreateFrame("Frame")
local combat, battle, pvp, dead = false, false, false, false
InCombatLockdown = function() return combat end
C_PetBattles = { IsInBattle = function() return battle end,
    IsPlayerNPC = function() return not pvp end,
    GetNumPets = function() return 3 end, GetHealth = function() return dead and 0 or 100 end }
local units = {}
UnitExists = function(unit) return units[unit] ~= nil end
UnitIsPlayer = function() return false end
UnitGUID = function(unit)
    local id = units[unit]
    if id == secret then return secret end
    return id and ("Creature-0-1-2-3-" .. id .. "-123")
end
UnitName = function(unit) return units[unit] == secret and secret or units[unit] and ("NPC " .. units[unit]) end
local loads, opens, loaded = {}, 0
BattleBuddyScript = { SetLoadedTeam = function(_, id) loaded = id; return true end }
BattleBuddyTeamsPanel = { Load = function(id)
    assert(not combat and not battle)
    loads[#loads + 1] = id
    BattleBuddyScript.SetLoadedTeam(BattleBuddyDB, id)
    return true
end, Refresh = function() end }
BattleBuddyPetJournalSurface = { Open = function() opens = opens + 1; return true end }
BattleBuddyWindow = { IsActive = function() return false end }
BattleBuddyHealthiestPets = { IsUninjured = function(team) return team.name == "Healthy" end,
    Apply = function() return true end }
local injured, flashes = false, 0
BattleBuddyHealthiestPets.AnyInjured = function() return injured end
BattleBuddyHealthiestPets.FlashInjured = function() flashes = flashes + 1 end
local dev = {}
BattleBuddyDev = { RegisterView = function(name, show, hide) dev[name] = { show, hide } end }
BattleBuddyDB = BattleBuddyTeams.Initialize()
local T = BattleBuddyTeams
local function team(name, npc)
    return assert(T.CreateTeam(BattleBuddyDB, { name = name, targets = { { npcID = npc, name = "NPC " .. npc } } }))
end
local first, second = team("First", 101), team("Healthy", 101)
local mouse, soft = team("Mouse", 102), team("Soft", 103)
local createFrame, detectionFrame = CreateFrame
CreateFrame = function(...)
    detectionFrame = createFrame(...)
    return detectionFrame
end
BattleBuddyTargetDetection.Start(BattleBuddyEncounterCatalog.BuildView({ schemaVersion = 1, catalogRevision = 1, records = {} }))
CreateFrame = createFrame
dofile(root .. "/BattleBuddy/AutoLoad.lua")
local A = BattleBuddyAutoLoad
local function set(key, value) assert(BattleBuddyConfig.SetSetting(key, value)) end
local function reset()
    A.Cancel()
    units = {}
    A.OnObservation()
    BattleBuddyScript.SetLoadedTeam(nil, nil)
    BattleBuddyDB.settingOverrides = {}
    loads, opens, combat, battle = {}, 0, false, false
end
assert(BattleBuddyConfig.GetSetting("onTarget") == "prompt")
set("onTarget", "none")
assert(BattleBuddyConfig.GetSetting("onMouseover") == "none")
assert(BattleBuddyConfig.GetSetting("onSoftInteract") == "none")
units.target = 101
A.OnObservation()
assert(#loads == 0 and not A.prompt)
set("onTarget", "prompt")
Frames.Fire(detectionFrame, "OnEvent", "PLAYER_TARGET_CHANGED")
assert(A.prompt and A.prompt.teams[1].teamID == first.teamID and #loads == 0)
A.Cycle(1)
assert(A.prompt.teams[A.prompt.index].teamID == second.teamID)
A.Cycle(1)
assert(A.prompt.index == 1)
A.Cycle(-1)
assert(A.LoadPrompt() and loaded == second.teamID and not A.prompt)
reset()
units.target = 101
set("onTarget", "window")
A.OnObservation()
assert(opens == 1 and #loads == 0)
A.OnObservation()
assert(opens == 1)
set("alwaysInteract", true)
A.OnObservation()
assert(opens == 2)
reset()
set("onTarget", "autoload")
set("onMouseover", "autoload")
set("onSoftInteract", "autoload")
units.mouseover, units.softinteract = 102, 103
A.OnObservation()
assert(loads[1] == mouse.teamID)
units.mouseover = nil
A.OnObservation()
assert(loads[2] == soft.teamID)
units.target, units.mouseover = 101, 102
A.OnObservation()
assert(loads[3] == first.teamID, "actual target teams defer mouseover to target path")
reset()
set("onTarget", "autoload")
units.target = 999
A.OnObservation()
assert(#loads == 0)
units.target, combat = 101, true
A.OnObservation()
assert(#loads == 0)
combat, battle = false, true
A.OnObservation()
assert(#loads == 0)
battle = false
BattleBuddyScript.SetLoadedTeam(BattleBuddyDB, second.teamID)
A.OnObservation()
assert(#loads == 0)
set("alwaysInteract", true)
A.OnObservation()
assert(#loads == 0)
set("evenIfTeamLoaded", true)
A.OnObservation()
assert(loads[1] == first.teamID)
A.OnObservation()
assert(#loads == 1, "do not reload the preferred team already loaded")
reset()
set("onTarget", "autoload")
units.target = secret
A.OnObservation()
assert(#loads == 0)
local original = BattleBuddyTargetDetection.ForUnit
BattleBuddyTargetDetection.ForUnit = function() return { state = "ambiguous", key = 101 }, { first } end
A.OnObservation()
assert(#loads == 0)
BattleBuddyTargetDetection.ForUnit = original
reset()
units.target = 101
set("onTarget", "autoload")
set("preferUninjuredTeams", true)
A.OnObservation()
assert(loads[1] == second.teamID)
reset()
set("onTarget", "autoload")
set("showWindowAfterLoading", true)
set("onlyWhenAnyPetsInjured", true)
units.target = 101
A.OnObservation()
assert(opens == 0 and flashes == 0, "healthy live loadout does not open window")
reset()
set("onTarget", "autoload")
set("showWindowAfterLoading", true)
set("onlyWhenAnyPetsInjured", true)
units.target, injured = 101, true
A.OnObservation()
assert(opens == 1 and flashes == 1)
injured = false
reset()
set("onTarget", "autoload")
units.target = 101
BattleBuddyTargetDetection.Refresh("target")
BattleBuddyTargetDetection.Current()
BattleBuddyTargetDetection.TeamsForCurrent(BattleBuddyDB)
assert(#loads == 0, "read-only target refresh cannot load")
set("preferUninjuredTeams", true)
local healthy = BattleBuddyHealthiestPets.IsUninjured
BattleBuddyHealthiestPets.IsUninjured = function() return false end
A.OnObservation()
assert(loads[1] == first.teamID, "injured fallback preserves preferred order")
BattleBuddyHealthiestPets.IsUninjured = healthy
reset()
set("onTarget", "autoload")
set("onMouseover", "autoload")
units.mouseover = secret
A.OnObservation()
assert(#loads == 0, "unknown high-priority source cannot load")
reset()
set("onTarget", "autoload")
C_Scenario = { GetInfo = function() return "NPC 101" end }
A.OnObservation()
assert(#loads == 0, "scenario text without an NPC cannot trigger an interaction")
C_Scenario = nil
reset()
set("onTarget", "prompt")
units.target = secret
local unitName = UnitName
UnitName = function(unit) return unit == "nameplate1" and "NPC 101" or secret end
UnitIsUnit = function(left, right) return left == "nameplate1" and right == "target" end
BattleBuddyTargetDetection.Refresh("target", "nameplate1")
A.OnObservation()
assert(A.prompt and A.prompt.teams[1].teamID == first.teamID, "nameplate evidence reaches interaction")
UnitIsUnit = function() return false end
A.OnObservation()
assert(not A.prompt, "uncorrelated nameplate cannot retain interaction")
UnitName = unitName
reset()
units.target = 900
set("onTarget", "prompt")
A.OnObservation()
assert(not A.prompt)
local added = team("New target", 900)
assert(A.prompt and A.prompt.teams[1].teamID == added.teamID, "save reevaluates current target")
A.Cancel()
A.OnObservation()
assert(not A.prompt, "cancel suppresses repeated prompt")
assert(T.EditTeam(BattleBuddyDB, added.teamID, { name = "Edited" }))
assert(A.prompt and A.prompt.teams[1].name == "Edited")
combat = true
assert(not A.LoadPrompt() and #loads == 0)
combat = false
reset()
units.target = 901
set("onTarget", "prompt")
local importStore = T.Initialize()
local source = assert(T.CreateTeam(importStore, { name = "Imported", targets = { 901 } }))
local X = BattleBuddyTeamStrings
local text = assert(X.ExportTeam(importStore, source.teamID))
local preview = assert(X.Import(BattleBuddyDB, text))
assert(not A.prompt, "import preview does not interact")
assert(X.ApplyImport(BattleBuddyDB, preview))
assert(A.prompt and A.prompt.teams[1].name == "Imported", "committed import reevaluates")
A.Cancel()
assert(not X.ApplyImport(BattleBuddyDB, {}))
assert(not A.prompt, "failed mutation does not interact")
reset()
BattleBuddyScript.SetLoadedTeam(BattleBuddyDB, first.teamID)
local function fire(event, ...)
    Frames.Fire(A.events, "OnEvent", event, ...)
end
fire("PET_BATTLE_OPENING_START")
fire("PET_BATTLE_FINAL_ROUND", 1)
fire("PET_BATTLE_OVER")
assert(not T.GetTeam(BattleBuddyDB, first.teamID).winrecord, "tracking defaults off")
set("autoTrackWinRecord", true)
local function outcome(winner)
    A.OnEvent("PET_BATTLE_OPENING_START")
    A.OnEvent("PET_BATTLE_FINAL_ROUND", winner)
    A.OnEvent("PET_BATTLE_OVER")
    A.OnEvent("PET_BATTLE_OVER")
end
outcome(1)
outcome(2)
dead = true
outcome(0)
outcome(2)
dead = false
outcome(secret)
outcome(77)
local record = T.GetTeam(BattleBuddyDB, first.teamID).winrecord
assert(record.wins == 1 and record.losses == 1 and record.draws == 2 and record.battles == 4)
set("forPVPBattlesOnly", true)
outcome(1)
assert(T.GetTeam(BattleBuddyDB, first.teamID).winrecord.battles == 4)
pvp = true
outcome(1)
assert(T.GetTeam(BattleBuddyDB, first.teamID).winrecord.battles == 5)
local swaps = 0
BattleBuddyHealthiestPets.Apply = function() swaps = swaps + 1; return true end
set("loadHealthiestPets", true)
set("afterPetBattlesToo", true)
A.OnEvent("PET_BATTLE_OPENING_START")
battle = true
A.OnEvent("PET_BATTLE_FINAL_ROUND", 1)
A.OnEvent("PET_BATTLE_OVER")
assert(swaps == 0)
battle = false
A.OnEvent("PET_BATTLE_CLOSE")
A.OnEvent("PET_BATTLE_CLOSE")
assert(swaps == 1, "post-battle swaps wait for close and run once")
assert(dev["autoload-prompt"])
dev["autoload-prompt"][1]()
assert(A.prompt and A.prompt.preview)
assert(not A.LoadPrompt())
dev["autoload-prompt"][2]()
Frames.Reset()
