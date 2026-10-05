local root = (... or ".")
dofile(root .. "/BattleBuddy/Store.lua")
dofile(root .. "/BattleBuddy/Persistence.lua")
dofile(root .. "/BattleBuddy/Teams.lua")
local T = BattleBuddyTeams
local S = BattleBuddyStore

local function Encode(value)
    if type(value) == "table" then
        local keys, parts = {}, {}
        for key in pairs(value) do keys[#keys + 1] = key end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        for _, key in ipairs(keys) do
            parts[#parts + 1] = "[" .. Encode(key) .. "]=" .. Encode(value[key])
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    if type(value) == "string" then return string.format("%q", value) end
    return tostring(value)
end

local function Equal(a, b)
    assert(Encode(a) == Encode(b), Encode(a) .. " ~= " .. Encode(b))
end

local db = assert(T.Initialize(S.New()))
local working = T.NewWorkingRecords()
Equal(working.sideline, { teamID = "sideline", name = "", pets = {}, tags = {} })
working.sideline.pets[1] = 42
Equal(working.original.pets, {})
Equal(next(db.teamsByID), nil)
Equal(db.groupOrder, { "group:favorites", "group:none" })
local g = assert(T.CreateGroup(db, { name = " Dailies ", sortMode = "custom", icon = 123, isExpanded = false }))
Equal(g.groupID, "group:1")
Equal(g.name, "Dailies")
local h = assert(T.CreateGroup(db, { name = "Dailies" }))
assert(T.EditGroup(db, h.groupID, { color = "abcdef", preferences = { minHP = 100 }, isExpanded = true }))
assert(T.EditGroup(db, h.groupID, { color = "", icon = "" }))
Equal(T.GetGroup(db, h.groupID).color, nil)
Equal(T.GetGroup(db, h.groupID).icon, nil)
assert(T.MoveGroup(db, h.groupID, 3))
Equal(db.groupOrder[3], h.groupID)
local before = Encode(db)
assert(not T.MoveGroup(db, "group:none", 3))
assert(not T.EditGroup(db, "group:favorites", { name = "Replacement" }))
assert(not T.DeleteGroup(db, g.groupID))
Equal(Encode(db), before)

local input = {
    name = " Alpha ", groupID = g.groupID,
    pets = { "BattlePet-missing", 123, 0 },
    tags = { { speciesID = 42, breedID = 4, abilities = { 1, 2, 0 } }, {}, {} },
    script = "ability(1)", notes = "note", preferences = { maxHP = 500 },
    winrecord = { wins = 2, losses = 1, draws = 1 },
    targets = { "target:99", 101 },
}
local a = assert(T.CreateTeam(db, input))
Equal(a.teamID, "team:1")
Equal(a.name, "Alpha")
Equal(a.winrecord.battles, 4)
input.tags[1].abilities[1] = 2
Equal(T.GetTeam(db, a.teamID).tags[1].abilities[1], 1)
local b = assert(T.DuplicateTeam(db, a.teamID))
Equal(b.name, "Alpha (2)")
Equal(b.script, a.script)
assert(b.teamID ~= a.teamID)
local c = assert(T.DuplicateTeam(db, b.teamID))
Equal(c.name, "Alpha (3)")
Equal(T.FindByName(db, " ALPHA ").teamID, a.teamID)
before = Encode(db)
local result, reason = T.EditTeam(db, b.teamID, { name = "alpha" })
assert(not result and reason == "name_conflict")
Equal(Encode(db), before)
assert(T.EditTeam(db, b.teamID, { name = "Beta", notes = "", script = "", preferences = {}, targets = {} }))
Equal(T.GetTeam(db, b.teamID).script, nil)
Equal(T.GetTeam(db, b.teamID).notes, nil)
Equal(T.GetTeam(db, b.teamID).preferences, nil)
assert(T.MoveTeam(db, b.teamID, h.groupID))
assert(T.MoveTeam(db, c.teamID, h.groupID, 1))
Equal(T.GetGroup(db, h.groupID).teams, { c.teamID, b.teamID })
Equal(T.GetGroup(db, h.groupID).sortMode, "custom")
assert(T.MoveTeam(db, b.teamID, h.groupID, 1))
Equal(T.ListTeams(db, h.groupID)[1].teamID, b.teamID)
Equal(T.ListGroups(db)[3].groupID, h.groupID)
assert(T.SetFavorite(db, a.teamID, true))
Equal(T.GetTeam(db, a.teamID).homeID, g.groupID)
assert(T.SetFavorite(db, a.teamID, false))
Equal(T.GetTeam(db, a.teamID).groupID, g.groupID)
Equal(T.GetTeam(db, a.teamID).script, "ability(1)")
assert(T.EditTeam(db, a.teamID, { groupID = "group:favorites" }))
Equal(T.GetTeam(db, a.teamID).homeID, g.groupID)
assert(T.EditTeam(db, a.teamID, { favorite = false }))
Equal(T.GetTeam(db, a.teamID).groupID, g.groupID)
assert(T.SetGroupExpanded(db, "group:favorites", false))
Equal(T.GetGroup(db, "group:favorites").isExpanded, false)

assert(T.AttachTarget(db, b.teamID, "target:99"))
assert(T.AttachTarget(db, b.teamID, 99))
Equal(T.GetTeam(db, b.teamID).targets, { 99 })
assert(T.SetTargetTeams(db, 99, { b.teamID, a.teamID }))
Equal(T.ListByTarget(db, "target:99")[1].teamID, b.teamID)
Equal(T.GetTeam(db, c.teamID).targets, { 101 })
assert(T.DetachTarget(db, b.teamID, 99))
Equal(T.ListByTarget(db, 99)[1].teamID, a.teamID)
assert(T.AttachTarget(db, a.teamID, 202, 1))
Equal(T.GetTeam(db, a.teamID).targets, { 202, 99, 101 })
before = Encode(db)
assert(not T.SetTargetTeams(db, 99, { a.teamID, "team:999" }))
assert(not T.AttachTarget(db, a.teamID, "target:no"))
assert(not T.DeleteTeam(db, a.teamID, "yes"))
Equal(Encode(db), before)

local loaded = assert(T.LoadTeam(db, a.teamID, function(petID, tag)
    if petID == 123 then return "BattlePet-owned" end
end))
assert(loaded.slots[1].unresolved)
Equal(loaded.slots[1].petID, "BattlePet-missing")
Equal(loaded.slots[2].resolvedPetID, "BattlePet-owned")
Equal(loaded.slots[1].tag.speciesID, 42)
Equal(Encode(db), before)
local staged = T.GetTeam(db, a.teamID)
staged.notes = "staged"
Equal(T.GetTeam(db, a.teamID).notes, "note")
assert(T.EditTeam(db, a.teamID, staged))
Equal(T.GetTeam(db, a.teamID).notes, "staged")
local indices = T.BuildIndexes(db)
Equal(indices.count, 3)
Equal(indices.byName.alpha, a.teamID)
Equal(indices.petCounts[123], 3)
assert(T.CreateTeam(db, { name = "Repeated", pets = { 123, 123 }, tags = { {}, {} } }))
Equal(T.BuildIndexes(db).petCounts[123], 4)
Equal(T.EffectivePreferences(db, a.teamID, { minHP = 1, allowMM = false }), { minHP = 1, maxHP = 500, allowMM = false })

local copiedGroup = assert(T.DuplicateGroup(db, g.groupID))
assert(copiedGroup.groupID ~= g.groupID)
Equal(#T.ListTeams(db, copiedGroup.groupID), 1)
Equal(T.ListTeams(db, copiedGroup.groupID)[1].script, "ability(1)")
assert(T.SetFavorite(db, a.teamID, true))
assert(T.DeleteGroup(db, g.groupID, true))
assert(T.SetFavorite(db, a.teamID, false))
Equal(T.GetTeam(db, a.teamID).groupID, "group:none")
assert(T.DeleteGroup(db, copiedGroup.groupID, true, true))
assert(not T.GetGroup(db, copiedGroup.groupID))
assert(T.DeleteGroup(db, h.groupID, true))
Equal(T.GetTeam(db, b.teamID).groupID, "group:none")
assert(T.DeleteTeam(db, a.teamID, true))
assert(not T.GetTeam(db, a.teamID))
Equal(T.ListByTarget(db, 202), {})
local replacement = assert(T.CreateTeam(db, { name = "Replacement" }))
Equal(replacement.teamID, "team:1")

local sorted = assert(T.CreateGroup(db, { name = "Sorted" }))
local z = assert(T.CreateTeam(db, { name = "Zulu", groupID = sorted.groupID, winrecord = { wins = 8, losses = 2 } }))
local y = assert(T.CreateTeam(db, { name = "Yankee", groupID = sorted.groupID, winrecord = { wins = 2 } }))
Equal(T.ListTeams(db, sorted.groupID)[1].teamID, y.teamID)
assert(T.EditGroup(db, sorted.groupID, { sortMode = "wins" }))
Equal(T.ListTeams(db, sorted.groupID)[1].teamID, y.teamID)
Equal(T.ListTeams(db, sorted.groupID, true)[1].teamID, z.teamID)
assert(T.MoveTeam(db, z.teamID, sorted.groupID, 1))
Equal(T.ListTeams(db, sorted.groupID)[1].teamID, z.teamID)
Equal(#T.ListTeams(db, sorted.groupID), 2)

before = Encode(db)
for _, bad in ipairs({
    { name = " " }, { name = "Bad", pets = { 1, 2, 3, 4 } },
    { name = "Bad", tags = { {} } }, { name = "Bad", pets = { {} }, tags = { {} } },
    { name = "Bad", script = {} }, { name = "Bad", winrecord = { wins = -1 } },
    { name = "Bad", preferences = { minHP = "x" } },
    { name = "Bad", tags = setmetatable({}, {}) },
    { name = "Bad", targets = { 0 } }, { name = "Bad", pets = { [2] = 4 } },
    { name = "Bad", pets = false }, { name = "Bad", winrecord = { wins = false } },
    { name = "Bad", winrecord = { battles = "bad" } },
}) do assert(not T.CreateTeam(db, bad)) end
assert(not T.MoveTeam(db, z.teamID, sorted.groupID, 0))
assert(not T.EditTeam(db, z.teamID, { teamID = "team:900" }))
assert(not T.CreateGroup(db, { name = "Bad", groupID = "group:800" }))
Equal(Encode(db), before)

for i = 1, 18 do assert(T.CreateGroup(db, { name = "Tab", showTab = true })) end
local tabs = 0
for _, group in ipairs(T.ListGroups(db)) do if group.showTab then tabs = tabs + 1 end end
Equal(tabs, 16)
local snapshot = Encode(db)
local versionTwo = assert(loadstring("return " .. snapshot))()
versionTwo.schemaVersion = 2
versionTwo.groupsByID, versionTwo.groupOrder, versionTwo.targetsByID = nil, nil, nil
local versionTwoSnapshot = Encode(versionTwo)
local migrated, migrationStatus = T.Initialize(versionTwo)
Equal(migrationStatus, "upgraded")
Equal(migrated.schemaVersion, 3)
Equal(T.GetTeam(migrated, c.teamID).script, T.GetTeam(db, c.teamID).script)
Equal(T.GetTeam(migrated, c.teamID).groupID, "group:none")
Equal(Encode(versionTwo), versionTwoSnapshot)
for _, field in ipairs({ "pets", "tags" }) do
    local invalid = assert(loadstring("return " .. snapshot))()
    invalid.teamsByID[z.teamID][field] = nil
    local value, classification = T.Initialize(invalid)
    assert(not value and classification == "malformed")
end
for _, field in ipairs({ "teams", "sortMode" }) do
    local invalid = assert(loadstring("return " .. snapshot))()
    invalid.groupsByID[sorted.groupID][field] = false
    local value, classification = T.Initialize(invalid)
    assert(not value and classification == "malformed")
end
local reloaded = assert(loadstring("return " .. snapshot))()
local persisted, status = S.Initialize(reloaded)
Equal(status, "current")
local restored = assert(T.Initialize(persisted))
Equal(restored, db)
assert(T.LoadTeam(restored, c.teamID).slots[1].unresolved)

local damaged = assert(loadstring("return " .. snapshot))()
damaged.groupsByID["group:none"].teams = { "team:999" }
damaged.targetsByID[111] = { "team:999" }
local repaired = assert(T.Initialize(damaged))
Equal(T.ListByTarget(repaired, 111), {})
assert(#T.ListTeams(repaired, "group:none") > 0)
Equal(damaged.groupsByID["group:none"].teams, { "team:999" })
damaged.teamsByID[z.teamID].pets = "bad"
local rejected, problem = T.Initialize(damaged)
assert(not rejected and problem == "malformed")
BattleBuddyDB = damaged
local malformedSnapshot = Encode(damaged)
Equal(BattleBuddyPersistence.Load(), "malformed")
assert(BattleBuddyDB == damaged)
Equal(Encode(damaged), malformedSnapshot)

BattleBuddyDB = { schemaVersion = S.SchemaVersion + 1 }
local untouched = BattleBuddyDB
Equal(BattleBuddyPersistence.Load(), "newer")
assert(BattleBuddyDB == untouched)
BattleBuddyDB = { schemaVersion = S.SchemaVersion }
untouched = BattleBuddyDB
Equal(BattleBuddyPersistence.Load(), "malformed")
assert(BattleBuddyDB == untouched)
local specialDB = assert(T.Initialize(nil))
local special = assert(T.CreateTeam(specialDB, {
    name = "Special", pets = { "ignored", "empty", "random:10" },
}))
local calls = 0
local specialLoad = T.LoadTeam(specialDB, special.teamID, function()
    calls = calls + 1
    error("journal unavailable")
end)
Equal(calls, 1)
assert(not specialLoad.slots[1].unresolved)
assert(not specialLoad.slots[2].unresolved)
assert(specialLoad.slots[3].unresolved)
print("teams_test: ok")

local targetStore = assert(T.Initialize(nil))
local legacy = assert(T.CreateTeam(targetStore, { name = "Legacy", targets = { 42 }, script = "ability(1)" }))
local migratedTargets = assert(T.Initialize(targetStore))
Equal(migratedTargets, targetStore)
Equal(T.ListByTarget(migratedTargets, 42)[1].teamID, legacy.teamID)
assert(T.AttachTarget(migratedTargets, legacy.teamID, { key = 42, npcID = 42, name = "Opponent" }))
Equal(T.GetTeam(migratedTargets, legacy.teamID).targetNames[42], "Opponent")
assert(T.AttachTarget(migratedTargets, legacy.teamID, { name = " Hidden Opponent! " }))
Equal(T.GetTeam(migratedTargets, legacy.teamID).targets, { 42, "name:hidden opponent" })
Equal(T.ListByTarget(migratedTargets, "name:hidden opponent")[1].script, "ability(1)")
local targetSnapshot = Encode(migratedTargets)
local targetReload = assert(T.Initialize(assert(loadstring("return " .. targetSnapshot))()))
Equal(targetReload, migratedTargets)
assert(T.DetachTarget(targetReload, legacy.teamID, "name:hidden opponent"))
Equal(T.GetTeam(targetReload, legacy.teamID).targetNames["name:hidden opponent"], nil)
Equal(#T.ListByTarget(targetReload, "name:hidden opponent"), 0)
assert(T.SetTargetTeams(targetReload, { name = "New opponent" }, { legacy.teamID }))
Equal(T.GetTeam(targetReload, legacy.teamID).targetNames["name:new opponent"], "New opponent")
assert(T.SetTargetTeams(targetReload, "name:new opponent", {}))
Equal(T.GetTeam(targetReload, legacy.teamID).targetNames["name:new opponent"], nil)
Equal(Encode(migratedTargets), targetSnapshot)
