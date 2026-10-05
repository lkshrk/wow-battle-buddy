local sourceRoot = (... or ".")
dofile(sourceRoot .. "/BattleBuddy/Store.lua")

local function AssertEqual(actual, expected)
    if actual ~= expected then
        error(("expected %s, got %s"):format(tostring(expected), tostring(actual)))
    end
end

local fresh, classification = BattleBuddyStore.Initialize(nil)
AssertEqual(classification, "fresh")
AssertEqual(fresh.schemaVersion, BattleBuddyStore.SchemaVersion)
AssertEqual(fresh.storeRevision, 0)
AssertEqual(fresh.nextEntitySequence, 1)
AssertEqual(type(fresh.teamsByID), "table")
AssertEqual(type(fresh.recoveryRecords), "table")
AssertEqual(fresh.schemaVersion, 3)
AssertEqual(fresh.groupOrder[1], "group:favorites")
AssertEqual(fresh.groupOrder[2], "group:none")
AssertEqual(#fresh.groupOrder, 2)
AssertEqual(fresh.groupsByID["group:favorites"].meta, true)
AssertEqual(fresh.groupsByID["group:favorites"].sortMode, "alpha")
AssertEqual(fresh.groupsByID["group:favorites"].icon,
    "Interface\\Icons\\ACHIEVEMENT_GUILDPERK_MRPOPULARITY_RANK2")
AssertEqual(fresh.groupsByID["group:none"].icon, "Interface\\Icons\\INV_Pet_BattlePetTraining")
AssertEqual(fresh.groupsByID["group:none"].groupID, "group:none")
AssertEqual(next(fresh.groupsByID["group:none"].teams), nil)
AssertEqual(next(fresh.targetsByID), nil)

local source = {
    schemaVersion = BattleBuddyStore.SchemaVersion,
    storeRevision = 7,
    nextEntitySequence = 12,
    teamsByID = { ["team-1"] = { name = "Alpha", slots = { 1, 2, 3 } } },
    groupsByID = fresh.groupsByID,
    groupOrder = fresh.groupOrder,
    targetsByID = {},
    foldersByID = {},
    scriptsByID = {},
    encounterAssignments = {},
    encounterOverrides = {},
    preferredTeamByEncounter = {},
    levelingQueue = {},
    settingOverrides = { showHints = false },
    transportRecords = {},
    recoveryRecords = {},
    extension = { retained = true },
}

local current
current, classification = BattleBuddyStore.Initialize(source)
AssertEqual(classification, "current")
AssertEqual(current == source, false)
AssertEqual(current.teamsByID == source.teamsByID, false)
AssertEqual(current.teamsByID["team-1"] == source.teamsByID["team-1"], false)
AssertEqual(current.settingOverrides.showHints, false)
AssertEqual(current.extension.retained, true)
current.teamsByID["team-1"].name = "Changed"
AssertEqual(source.teamsByID["team-1"].name, "Alpha")

local invalid
invalid, classification = BattleBuddyStore.Initialize({ schemaVersion = -1 })
AssertEqual(invalid, nil)
AssertEqual(classification, "malformed")

invalid, classification = BattleBuddyStore.Initialize({ schemaVersion = BattleBuddyStore.SchemaVersion + 1 })
AssertEqual(invalid, nil)
AssertEqual(classification, "newer")

invalid, classification = BattleBuddyStore.Initialize({ schemaVersion = BattleBuddyStore.SchemaVersion - 1 })
AssertEqual(invalid, nil)
AssertEqual(classification, "malformed")

local malformed = BattleBuddyStore.New()
malformed.teamsByID = "not-a-container"
invalid, classification = BattleBuddyStore.Initialize(malformed)
AssertEqual(invalid, nil)
AssertEqual(classification, "malformed")

malformed = BattleBuddyStore.New()
malformed.teamsByID.self = malformed.teamsByID
invalid, classification = BattleBuddyStore.Initialize(malformed)
AssertEqual(invalid, nil)
AssertEqual(classification, "malformed")

local versionOne = {
    schemaVersion = 1,
    storeRevision = 7,
    nextEntitySequence = 12,
    teamsByID = {},
    foldersByID = {},
    scriptsByID = {},
    encounterAssignments = {},
    preferredTeamByEncounter = {},
    levelingQueue = {},
    settingOverrides = {},
    transportRecords = {},
    recoveryRecords = {},
}
local upgraded
upgraded, classification = BattleBuddyStore.Initialize(versionOne)
AssertEqual(classification, "upgraded")
AssertEqual(upgraded.schemaVersion, BattleBuddyStore.SchemaVersion)
AssertEqual(type(upgraded.encounterOverrides), "table")
AssertEqual(next(upgraded.encounterOverrides), nil)
AssertEqual(versionOne.encounterOverrides, nil)

local versionTwo = BattleBuddyStore.New()
versionTwo.schemaVersion = 2
versionTwo.groupsByID, versionTwo.groupOrder, versionTwo.targetsByID = nil, nil, nil
versionTwo.teamsByID["legacy"] = { name = "Kept", slots = { 1, 2, 3 }, script = "kept script" }
versionTwo.scriptsByID["legacy"] = { text = "legacy script" }
versionTwo.foldersByID["folder"] = { teams = { "legacy" } }
versionTwo.encounterOverrides["encounter"] = { retained = true }
upgraded, classification = BattleBuddyStore.Initialize(versionTwo)
AssertEqual(classification, "upgraded")
AssertEqual(upgraded.schemaVersion, 3)
AssertEqual(upgraded.teamsByID.legacy.name, "Kept")
AssertEqual(upgraded.teamsByID.legacy.script, "kept script")
AssertEqual(upgraded.teamsByID.legacy.slots[3], 3)
AssertEqual(upgraded.scriptsByID.legacy.text, "legacy script")
AssertEqual(upgraded.foldersByID.folder.teams[1], "legacy")
AssertEqual(upgraded.encounterOverrides.encounter.retained, true)
AssertEqual(upgraded.groupOrder[1], "group:favorites")
AssertEqual(versionTwo.groupsByID, nil)
AssertEqual(versionTwo.schemaVersion, 2)
upgraded.teamsByID.legacy.slots[1] = 9
AssertEqual(versionTwo.teamsByID.legacy.slots[1], 1)

for _, version in ipairs({ 1, 2 }) do
    local old = BattleBuddyStore.New()
    old.schemaVersion = version
    old.groupsByID, old.groupOrder, old.targetsByID = nil, nil, nil
    old.extension = setmetatable({}, {})
    invalid, classification = BattleBuddyStore.Initialize(old)
    AssertEqual(invalid, nil)
    AssertEqual(classification, "malformed")
    AssertEqual(getmetatable(old.extension) ~= nil, true)
    old.extension = old
    invalid, classification = BattleBuddyStore.Initialize(old)
    AssertEqual(invalid, nil)
    AssertEqual(classification, "malformed")
    AssertEqual(old.extension, old)
end

local unsupported = { schemaVersion = 0, retained = true }
invalid, classification = BattleBuddyStore.Initialize(unsupported)
AssertEqual(invalid, nil)
AssertEqual(classification, "old")
AssertEqual(unsupported.retained, true)

local accessed = false
local inherited = setmetatable({}, { __index = function()
    accessed = true
    return 2
end })
invalid, classification = BattleBuddyStore.Initialize(inherited)
AssertEqual(invalid, nil)
AssertEqual(classification, "malformed")
AssertEqual(accessed, false)

malformed = BattleBuddyStore.New()
malformed.extension = { [math.huge] = true }
invalid, classification = BattleBuddyStore.Initialize(malformed)
AssertEqual(invalid, nil)
AssertEqual(classification, "malformed")
