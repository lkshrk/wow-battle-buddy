local root = (... or ".")

dofile(root .. "/BattleBuddy/EncounterCatalog.lua")
dofile(root .. "/BattleBuddy/EncounterContent.lua")

local function Equal(actual, expected)
    if actual ~= expected then error(("expected %s, got %s"):format(tostring(expected), tostring(actual))) end
end

local Catalog = BattleBuddyEncounterCatalog
local Content = BattleBuddyEncounterContent

local input = Content.BuildCatalogInput()
Equal(input.schemaVersion, 1)
Equal(input.shippedContentVersion, 1)

local catalog = Catalog.BuildView(input)
Equal(catalog.state, "ready")
Equal(#catalog.records, 3)

local match = Catalog.MatchEncounter(catalog, { npcID = 79179 }, 1)
Equal(match.state, "unique")
Equal(match.encounterID, "shipped.wod.squirt")

local browser = Catalog.BuildBrowserInput(catalog, match.encounterID)
Equal(#browser.encounters, 3)
Equal(browser.selectedEncounterID, match.encounterID)
Equal(browser.encounters[1].label, "Squirt")
Equal(browser.encounters[1].expansion, "Warlords of Draenor")
Equal(browser.encounters[1].availability, "unknown")

Equal(Catalog.BuildBrowserInput({ state = "invalid" }).encounters, nil)
