BattleBuddyEncounterContent = {}

local Content = BattleBuddyEncounterContent

Content.SchemaVersion = 1
Content.ShippedContentVersion = 1

Content.Records = {
    {
        encounterID = "shipped.wod.squirt",
        origin = "shipped",
        recordRevision = 1,
        display = { fallbackLabel = "Squirt" },
        selectors = { { npcID = 79179 } },
        content = {
            expansion = "Warlords of Draenor",
            locations = {},
            repeatability = "daily",
        },
        support = { state = "unverified", reasons = { "Client availability has not yet been verified." } },
        provenance = { "Mapped from the audited native NPC identity list." },
    },
    {
        encounterID = "shipped.legion.amalia",
        origin = "shipped",
        recordRevision = 1,
        display = { fallbackLabel = "Amalia" },
        selectors = { { npcID = 107489 } },
        content = {
            expansion = "Legion",
            locations = {},
            repeatability = "daily",
        },
        support = { state = "unverified", reasons = { "Client availability has not yet been verified." } },
        provenance = { "Mapped from the audited native NPC identity list." },
    },
    {
        encounterID = "shipped.legion.sir-galveston",
        origin = "shipped",
        recordRevision = 1,
        display = { fallbackLabel = "Sir Galveston" },
        selectors = { { npcID = 99182 } },
        content = {
            expansion = "Legion",
            locations = {},
            repeatability = "daily",
        },
        support = { state = "unverified", reasons = { "Client availability has not yet been verified." } },
        provenance = { "Mapped from the audited native NPC identity list." },
    },
}

function Content.BuildCatalogInput()
    return {
        schemaVersion = Content.SchemaVersion,
        shippedContentVersion = Content.ShippedContentVersion,
        catalogRevision = Content.ShippedContentVersion,
        records = Content.Records,
    }
end
