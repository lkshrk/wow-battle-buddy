local root = (... or ".")

dofile(root .. "/BattleBuddy/EncounterCatalog.lua")

local function Equal(actual, expected)
    if actual ~= expected then error(("expected %s, got %s"):format(tostring(expected), tostring(actual))) end
end

local Catalog = BattleBuddyEncounterCatalog
local function Record(id, npcID, activityID)
    return {
        encounterID = id,
        origin = "shipped",
        recordRevision = 1,
        display = { fallbackLabel = id },
        content = {},
        support = { state = "unverified" },
        selectors = { { npcID = npcID, activityID = activityID } },
    }
end

local catalog = Catalog.BuildView({
    schemaVersion = 1,
    catalogRevision = 4,
    records = { Record("shipped.alpha", 123, "alpha"), Record("shipped.beta", 123, "beta"), Record("shipped.solo", 456) },
})
Equal(catalog.state, "ready")
Equal(#catalog.records, 3)

local result = Catalog.MatchEncounter(catalog, { npcID = 123 })
Equal(result.state, "ambiguous")
Equal(result.reason, "AMBIGUOUS_MATCH")
Equal(#result.candidateIDs, 2)

result = Catalog.MatchEncounter(catalog, { npcID = 123, activityID = "alpha" }, 4)
Equal(result.state, "unique")
Equal(result.encounterID, "shipped.alpha")

result = Catalog.MatchEncounter(catalog, { npcID = 456 }, 4)
Equal(result.state, "unique")
Equal(result.encounterID, "shipped.solo")

result = Catalog.MatchEncounter(catalog, { npcID = 456 }, 3)
Equal(result.state, "stale")
Equal(result.reason, "STALE_CATALOG")

result = Catalog.MatchEncounter(catalog, { npcID = 999 })
Equal(result.state, "unresolved")
Equal(result.reason, "MISSING_ENCOUNTER")

local found = Catalog.GetEncounter(catalog, "shipped.solo")
Equal(found.state, "found")
found.encounter.display.fallbackLabel = "changed"
Equal(Catalog.GetEncounter(catalog, "shipped.solo").encounter.display.fallbackLabel, "shipped.solo")
Equal(Catalog.GetEncounter(catalog, "missing").reason, "MISSING_ENCOUNTER")

local diagnostic = Catalog.BuildView({
    schemaVersion = 1,
    catalogRevision = 1,
    records = { Record("shipped.same", 1), Record("shipped.same", 2), { encounterID = "bad" } },
})
Equal(diagnostic.state, "diagnostic")
Equal(#diagnostic.records, 1)
Equal(diagnostic.diagnostics[1].reason, "ID_COLLISION")
Equal(diagnostic.diagnostics[2].reason, "INVALID_RECORD")

local overlap = Catalog.BuildView({
    schemaVersion = 1,
    catalogRevision = 1,
    records = { Record("shipped.left", 77), Record("shipped.right", 77) },
})
Equal(overlap.state, "diagnostic")
Equal(overlap.diagnostics[1].reason, "SELECTOR_OVERLAP")
Equal(overlap.diagnostics[1].competingEncounterID, "shipped.left")

local broad = Record("shipped.broad", 88)
local scoped = Record("shipped.scoped", 88, "activity")
local broadOverlap = Catalog.BuildView({ schemaVersion = 1, catalogRevision = 1, records = { broad, scoped } })
Equal(broadOverlap.diagnostics[1].reason, "SELECTOR_OVERLAP")

local validOverride, copiedOverride = Catalog.ValidateOverride({
    targetEncounterID = "shipped.solo", baseRecordRevision = 1, content = { interactionProfile = "safe-profile" },
}, catalog)
Equal(validOverride, true)
copiedOverride.content.interactionProfile = "changed"
Equal(Catalog.ValidateOverride({ targetEncounterID = "shipped.solo", baseRecordRevision = 1, content = { interactionProfile = "safe-profile" } }, catalog), true)
Equal(Catalog.ValidateOverride({ targetEncounterID = "shipped.solo", baseRecordRevision = 2, content = {} }, catalog), false)
Equal(select(2, Catalog.ValidateOverride({ targetEncounterID = "shipped.solo", baseRecordRevision = 2, content = {} }, catalog)), "OVERRIDE_BASE_CHANGED")
local overridden = Catalog.BuildView({
    schemaVersion = 1,
    catalogRevision = 4,
    records = { Record("shipped.solo", 456) },
    overrides = {
        { targetEncounterID = "shipped.solo", baseRecordRevision = 1, content = { healingProfile = "safe-profile" } },
        { targetEncounterID = "shipped.solo", baseRecordRevision = 2, content = { healingProfile = "stale-profile" } },
    },
})
Equal(overridden.state, "diagnostic")
local overriddenRecord = Catalog.GetEncounter(overridden, "shipped.solo").encounter
Equal(overriddenRecord.content.healingProfile, "safe-profile")
Equal(overriddenRecord.recordRevision, 1)
Equal(overriddenRecord.effectiveRecordRevision, 2)
local browserInput = Catalog.BuildBrowserInput(overridden)
Equal(browserInput.encounters[1].recordRevision, 1)
Equal(browserInput.encounters[1].effectiveRecordRevision, 2)
Equal(overridden.diagnostics[1].reason, "OVERRIDE_BASE_CHANGED")

local duplicatedOverride = Catalog.BuildView({
    schemaVersion = 1,
    catalogRevision = 4,
    records = { Record("shipped.solo", 456) },
    overrides = {
        { targetEncounterID = "shipped.solo", baseRecordRevision = 1, content = { healingProfile = "first-profile" } },
        { targetEncounterID = "shipped.solo", baseRecordRevision = 1, content = { healingProfile = "second-profile" } },
    },
})
Equal(duplicatedOverride.state, "diagnostic")
Equal(Catalog.GetEncounter(duplicatedOverride, "shipped.solo").encounter.content.healingProfile, "first-profile")
Equal(duplicatedOverride.diagnostics[1].reason, "ID_COLLISION")

Equal(Catalog.BuildView({ schemaVersion = 2, catalogRevision = 1, records = {} }).state, "invalid")
