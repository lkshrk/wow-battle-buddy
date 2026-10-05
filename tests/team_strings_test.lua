local root = (... or ".")
dofile(root .. "/BattleBuddy/Store.lua")
dofile(root .. "/BattleBuddy/Teams.lua")
dofile(root .. "/BattleBuddy/Script/Parser.lua")
dofile(root .. "/BattleBuddy/Script/Share.lua")
dofile(root .. "/BattleBuddy/TeamStrings.lua")
local X, T = BattleBuddyTeamStrings, BattleBuddyTeams
local fixtures = dofile(root .. "/tests/fixtures/team_strings/corpus.lua")
for version = 1, 2 do
    fixtures["pbs" .. version] = BattleBuddyScript.Export("standby", {
        version = version, name = "Shared", plugin = "Rematch", key = "team:77", extra = fixtures.empty,
    })
end
fixtures.pbsLegacy = fixtures.pbs1:gsub("# Version: 1\n", "")
for index, text in ipairs(dofile(root .. "/tests/fixtures/team_strings/reference.lua")) do
    fixtures["reference" .. index] = text
end
local function Dump(value)
    if type(value) ~= "table" then return tostring(value) end
    local parts = {}
    for key, item in pairs(value) do parts[#parts + 1] = tostring(key) .. "=" .. Dump(item) end
    table.sort(parts)
    return "{" .. table.concat(parts, ",") .. "}"
end
local function Equal(a, b) assert(Dump(a) == Dump(b), Dump(a) .. " ~= " .. Dump(b)) end
local function Store() return assert(T.Initialize(BattleBuddyStore.New())) end
for name, wire in pairs(fixtures) do
    local document = assert(X.Decode(wire), name)
    Equal(assert(X.Encode(document)), wire)
    Equal(assert(X.Encode(assert(X.Decode(wire:gsub("\n", "\r\n"))))), wire:gsub("\n", "\r\n"))
end
local decoded = assert(X.Decode(fixtures.team))
local team = decoded.teams[1]
Equal(team.name, "Clockwork")
Equal(team.targets, { 97, 1024 })
Equal(team.pets, { 13, 0, "ignored" })
Equal(team.tags[1], { speciesID = 13, breedID = 4, abilities = { 1, 2, 0 } })
Equal(team.preferences, { minHP = 100, allowMM = true, expectedDD = 2, maxHP = 1500, minXP = 1.5, maxXP = 25 })
Equal(team.notes, "first\nsecond: note")
Equal(assert(X.Decode(fixtures.empty)).teams[1].pets, { "empty", "empty", "empty" })
local group = assert(X.Decode(fixtures.group)).groups[1]
Equal(group.name, "Workshop")
Equal(group.icon, 123)
Equal(group.color, "abcdef")
Equal(group.sortMode, "custom")
Equal(group.showTab, true)
Equal(assert(X.Decode(fixtures.backup)).kind, "backup")
local late = assert(X.Decode(fixtures.empty .. "\n" .. fixtures.group))
assert(not late.grouped and #late.groups == 0)
local db = Store()
for _, name in ipairs({ "Boss:A", "Boss: Hero", "Colon:12" }) do
    local named = assert(T.CreateTeam(db, { name = name, pets = { 13, 0, "ignored" }, tags = {
        { speciesID = 13, breedID = 0, abilities = { 1, 1, 1 } }, {}, {},
    } }))
    Equal(assert(X.Decode(assert(X.ExportTeam(db, named.teamID)))).teams[1].name, name)
end
local literal = assert(T.CreateTeam(db, { name = "Literal", notes = "literal \\n sequence" }))
assert(not X.ExportTeam(db, literal.teamID))
assert(X.ExportTeam(db, literal.teamID, { includeNotes = false }))
assert(T.DeleteTeam(db, literal.teamID, true))
local existing = assert(T.CreateTeam(db, { name = "CLOCKWORK", script = "standby()", notes = "old" }))
local before = Dump(db)
local preview = assert(X.Import(db, fixtures.team, function(pet) if pet == 13 then return "BattlePet-owned" end end))
Equal(Dump(db), before)
Equal(preview.conflicts[1].teamID, existing.teamID)
Equal(preview.pets[1][1].resolvedPetID, "BattlePet-owned")
assert(preview.pets[1][2].unresolved)
assert(not preview.pets[1][3].unresolved)
local unresolved = assert(X.Import(db, fixtures.team))
assert(unresolved.pets[1][1].unresolved)
local queue = assert(X.Import(db, "Queue::QA34D:::"))
Equal(queue.pets[1][1].selection, { minLevel = 10, minRarity = 3, maxLevel = 24 })
assert(queue.pets[1][1].unresolved and #queue.warnings == 1)
local imported = assert(X.ApplyImport(db, unresolved, { conflicts = "copy" }))
Equal(imported.teams[1].name, "Clockwork (2)")
Equal(imported.teams[1].pets[1], 13)
Equal(T.GetTeam(db, existing.teamID).notes, "old")
local replaced = assert(X.ApplyImport(db, preview, { conflicts = "replace" }))
Equal(replaced.teams[1].teamID, existing.teamID)
Equal(replaced.teams[1].pets[1], "BattlePet-owned")
Equal(replaced.teams[1].script, nil)
Equal(T.ListByTarget(db, 97)[1].teamID, imported.teams[1].teamID)
local scripted = assert(X.Import(db, fixtures.script))
assert(scripted.scriptPresent[1])
Equal(scripted.teams[1].script, "standby")
for version = 1, 2 do
    local wrapped = assert(X.Import(db, fixtures["pbs" .. version]))
    Equal(wrapped.teams[1].name, "Vacant")
    Equal(wrapped.teams[1].script, "standby")
    Equal(assert(X.ApplyImport(db, wrapped)).teams[1].script, "standby")
    assert(not X.Import(db, BattleBuddyScript.Export("standby", {
        version = version, plugin = "Rematch", extra = "Bad\0Name:::::",
    })))
end
local saved = assert(X.ApplyImport(db, scripted)).teams[1]
Equal(saved.script, "standby")
local exported = assert(X.ExportTeam(db, saved.teamID))
Equal(assert(X.Decode(exported)).teams[1].script, "standby")
local grouped = assert(X.ApplyImport(db, assert(X.Import(db, fixtures.backup))))
Equal(#grouped.groups, 2)
Equal(grouped.teams[1].groupID, grouped.groups[1].groupID)
Equal(grouped.teams[2].groupID, grouped.groups[2].groupID)
Equal(assert(X.Decode(assert(X.ExportGroup(db, grouped.groups[1].groupID)))).kind, "group")
local all = assert(X.Decode(assert(X.ExportBackup(db))))
Equal(#all.teams, #T.ListTeams(db))
Equal(#all.groups, #T.ListGroups(db))
local omitted = assert(X.Decode(assert(X.Encode(decoded, { includeNotes = false, includePreferences = false }))))
Equal(omitted.teams[1].notes, nil)
Equal(omitted.teams[1].preferences, nil)
decoded.teams[1].name = "Changed"
assert(assert(X.Encode(decoded)):find("Changed:", 1, true))
local plain = assert(X.PlainText(team))
assert(plain:find("Changed", 1, true) and plain:find("13", 1, true) and plain:find("first\nsecond", 1, true))
assert(not X.Decode(plain))
for _, bad in ipairs({ "", "garbage", "Name::ZL:ZI:", "Name::1110!:::", "Name::9990D:::",
    "Name::ZRZ:::", "Name:!:ZL:ZI::", "Name:::::P:1:0:", "Name:::::V:9:",
    "Name:::::P:1:2:0:0:0:0:", "Name:::::P:-1:0:0:0:0:0:",
    "__ Name:9:1::1: __", "Name:::::\nmalformed", "Name:::::N:-----BEGIN PET BATTLE SCRIPT-----\\nstandby()",
    "# Version: 9\n# Code Start\nstandby\n# Code End", "# Version: 1\n# (Script) : #\n# !!!",
    "Name:::::N:-----BEGIN PET BATTLE SCRIPT-----\\nthis is invalid\\n-----END PET BATTLE SCRIPT-----" }) do
    local ok, result, reason = pcall(X.Import, db, bad)
    assert(ok and result == nil and type(reason) == "string", "must reject " .. bad)
end
for _, bad in ipairs({ false, 42, {} }) do assert(not X.Decode(bad)) end
assert(not X.Decode(fixtures.pbs2 .. "unexpected trailing text"))
assert(not X.Decode(fixtures.pbs2:gsub("# Code End", "")))
assert(not X.Decode(BattleBuddyScript.Export("standby", { version = 2, plugin = "Other", extra = fixtures.empty })))
assert(not X.Decode(BattleBuddyScript.Export("standby", { version = 2, plugin = "Rematch", extra = fixtures.backup })))
before = Dump(db)
local broken = assert(X.Import(db, fixtures.backup))
broken.teams[2].name = ""
assert(not X.ApplyImport(db, broken))
Equal(Dump(db), before)
assert(not X.ApplyImport(db, scripted, { groupID = "group:999" }))
Equal(Dump(db), before)
assert(not X.ApplyImport(db, scripted, { conflicts = "oops" }))
Equal(Dump(db), before)
print("team_strings_test: ok")
