local root = (... or ".")

local secret = setmetatable({}, { __tostring = function() error("secret formatted") end })
issecretvalue = function(value) return rawequal(value, secret) end
canaccessvalue = function() return true end
dofile(root .. "/BattleBuddy/Compatibility.lua")
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

local alpha, beta = Record("shipped.a", 10), Record("shipped.b", 20)
alpha.display = { fallbackLabel = "Test Trainer", aliases = { "Shared", "Member One" }, locale = "enUS" }
alpha.selectors[2] = { npcID = 11 }
alpha.content = { questID = 101, enemyPets = { { speciesID = 51 }, { speciesID = 52 } }, gossipHints = { "the first challenge" } }
beta.display = { fallbackLabel = "Test Rival", aliases = { "Shared" }, locale = "enUS" }
beta.content = { questID = 102, enemyPets = { { speciesID = 52 } }, gossipHints = { "the second challenge" } }
local lookup = Catalog.BuildView({ schemaVersion = 1, catalogRevision = 1, records = { alpha, beta } })
Equal(Catalog.Lookup(lookup, { npcID = 11, name = "Test Rival" }).npcID, 10)
Equal(Catalog.Lookup(lookup, { npcID = 999, name = "Test Trainer" }).state, "unresolved")
Equal(Catalog.Lookup(lookup, { name = "  MEMBER ONE! " }).encounterID, "shipped.a")
Equal(Catalog.Lookup(lookup, { name = "Shared" }).state, "ambiguous")
Equal(#Catalog.Lookup(lookup, { name = "Shared" }).candidateIDs, 2)
Equal(Catalog.Lookup(lookup, { name = "Test Trainer", locale = "deDE" }).state, "unresolved")
Equal(Catalog.Lookup(lookup, { prefix = "Test T" }).encounterID, "shipped.a")
Equal(Catalog.Lookup(lookup, { prefix = "Test" }).state, "ambiguous")
Equal(Catalog.Lookup(lookup, { speciesID = 51 }).encounterID, "shipped.a")
Equal(Catalog.Lookup(lookup, { speciesID = 52, name = "Test Trainer" }).state, "ambiguous")
Equal(Catalog.Lookup(lookup, { questID = 102 }).encounterID, "shipped.b")
Equal(Catalog.Lookup(lookup, { name = "Shared", questID = 101 }).encounterID, "shipped.a")
Equal(Catalog.Lookup(lookup, { gossipTexts = { "Ready for the first challenge?" } }).encounterID, "shipped.a")
Equal(Catalog.Lookup(lookup, { gossipTexts = { "the first challenge", "the second challenge" } }).state, "ambiguous")
Equal(Catalog.Lookup(lookup, { gossipTexts = { "Contest Trainerish" } }).state, "unresolved")
Equal(Catalog.Lookup(lookup, { scenarioTexts = { "Defeat Test Rival." } }).encounterID, "shipped.b")
Equal(Catalog.Lookup(lookup, { npcID = secret, name = "Test Trainer" }).encounterID, "shipped.a")
Equal(Catalog.Lookup(lookup, { npcID = secret, name = secret, speciesID = secret, questID = secret,
    prefix = secret, locale = secret, gossipTexts = { secret }, scenarioTexts = secret }).state, "unresolved")
Equal(Catalog.Lookup(lookup, secret).state, "unresolved")
Equal(Catalog.MatchEncounter(lookup, { npcID = secret }).state, "unresolved")
local detached = Catalog.Lookup(lookup, { npcID = 10 })
detached.encounter.display.fallbackLabel = "mutated"
Equal(Catalog.Lookup(lookup, { npcID = 10 }).encounter.display.fallbackLabel, "Test Trainer")

for _, field in ipairs({ "aliases", "gossipHints", "enemyPets" }) do
    local invalid = Record("shipped.invalid", 30)
    local owner = field == "aliases" and invalid.display or invalid.content
    owner[field] = "invalid"
    Equal(Catalog.BuildView({ schemaVersion = 1, catalogRevision = 1, records = { invalid } }).state, "diagnostic")
end
Equal(Catalog.Lookup(lookup, { publicTexts = { "Test T..." } }).encounterID, "shipped.a")
Equal(Catalog.Lookup(lookup, { publicTexts = { "Test…" } }).state, "ambiguous")
