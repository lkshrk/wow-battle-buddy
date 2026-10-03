local sourceRoot = (... or ".")
dofile(sourceRoot .. "/BattleBuddy/Store.lua")
dofile(sourceRoot .. "/BattleBuddy/Persistence.lua")

local function AssertEqual(actual, expected)
    if actual ~= expected then
        error(("expected %s, got %s"):format(tostring(expected), tostring(actual)))
    end
end

BattleBuddyDB = nil
local classification = BattleBuddyPersistence.Load()
AssertEqual(classification, "fresh")
AssertEqual(BattleBuddyPersistence.Status, "fresh")
AssertEqual(BattleBuddyDB.schemaVersion, BattleBuddyStore.SchemaVersion)

local current = BattleBuddyStore.New()
current.storeRevision = 4
BattleBuddyDB = current
classification = BattleBuddyPersistence.Load()
AssertEqual(classification, "current")
AssertEqual(BattleBuddyDB == current, false)
AssertEqual(BattleBuddyDB.storeRevision, 4)

local malformed = { schemaVersion = -1 }
BattleBuddyDB = malformed
classification = BattleBuddyPersistence.Load()
AssertEqual(classification, "malformed")
AssertEqual(BattleBuddyDB == malformed, true)
AssertEqual(BattleBuddyPersistence.Status, "malformed")
