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

local source = {
    schemaVersion = BattleBuddyStore.SchemaVersion,
    storeRevision = 7,
    nextEntitySequence = 12,
    teamsByID = { ["team-1"] = { name = "Alpha", slots = { 1, 2, 3 } } },
    foldersByID = {},
    scriptsByID = {},
    encounterAssignments = {},
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
AssertEqual(classification, "old")

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
