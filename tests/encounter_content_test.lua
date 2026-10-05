local root = (... or ".")

issecretvalue = function() return false end
canaccessvalue = function() return true end
dofile(root .. "/BattleBuddy/Compatibility.lua")
dofile(root .. "/BattleBuddy/EncounterCatalog.lua")
dofile(root .. "/BattleBuddy/EncounterContent.lua")

local Content = BattleBuddyEncounterContent
local Catalog = BattleBuddyEncounterCatalog
assert(Content.SchemaVersion == 1)
assert(Content.ShippedContentVersion == 2)
assert(Content.Records[1].encounterID == "shipped.wod.squirt")

local view = Catalog.BuildView(Content.BuildCatalogInput())
assert(view.state == "ready")
assert(#view.records == 8)
local counts, npcs = {}, {}
for _, record in ipairs(view.records) do
    local content = record.content
    assert(record.display.locale == "enUS")
    assert(content.headerID and content.mapID and content.zone)
    assert(#content.enemyPets >= 1 and #content.enemyPets <= 3)
    counts[content.category] = (counts[content.category] or 0) + 1
    assert(not npcs[record.selectors[1].npcID])
    npcs[record.selectors[1].npcID] = record
    for _, pet in ipairs(content.enemyPets) do
        assert(type(pet.speciesID) == "number" and pet.speciesID > 0)
    end
end
assert(counts.tamer == 2)
assert(counts["world-quest"] == 3)
assert(counts.legendary == 1)
assert(counts.dungeon == 2)
assert(npcs[79179].content.enemyPets[1].speciesID == 1400)
assert(npcs[107489].encounterID == "shipped.legion.amalia")
assert(npcs[99182].encounterID == "shipped.legion.sir-galveston")
assert(npcs[196264].content.questID == 66551)
assert(npcs[116789].content.enemyPets[1].speciesID == 1990)
assert(npcs[68559].content.enemyPets[1].speciesID == 1188)

local input = Content.BuildCatalogInput()
input.overrides = { {
    targetEncounterID = "shipped.wod.squirt", baseRecordRevision = 2,
    content = { interactionProfile = "custom-profile" },
} }
local overridden = Catalog.BuildView(input)
assert(overridden.state == "ready")
assert(Catalog.GetEncounter(overridden, "shipped.wod.squirt").encounter.content.interactionProfile == "custom-profile")
assert(Content.Records[1].content.interactionProfile == nil)
