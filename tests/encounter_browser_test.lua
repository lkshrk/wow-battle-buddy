local sourceRoot = (... or ".")

dofile(sourceRoot .. "/BattleBuddy/EncounterBrowser.lua")

local function AssertEqual(actual, expected)
    if actual ~= expected then
        error(("expected %s, got %s"):format(tostring(expected), tostring(actual)))
    end
end

local Browser = BattleBuddyEncounterBrowser
local encounters = {
    { encounterID = "tww.1", display = { fallbackLabel = "Cinder Pup" }, recordRevision = 4, effectiveRecordRevision = 5, expansion = "The War Within", zone = "Dornogal", availability = "available", support = "supported" },
    { encounterID = "tww.2", label = "Hidden Fox", expansion = "The War Within", zone = "Dornogal", availability = "unknown", support = "unverified" },
    { encounterID = "old.1", label = "Old Turtle", expansion = "Dragonflight", zone = "Valdrakken", availability = "unavailable", support = "unsupported" },
    { encounterID = 12, label = "Invalid identity" },
}

local view = Browser.BuildView({ encounters = encounters, selectedEncounterID = "tww.2" })
AssertEqual(#view.rows, 3)
AssertEqual(view.selectedState, "selected")
AssertEqual(view.selectedEncounter.label, "Hidden Fox")
AssertEqual(view.rows[1].recordRevision, 4)
AssertEqual(view.rows[1].effectiveRecordRevision, 5)

view = Browser.BuildView({ encounters = encounters, selectedEncounterID ="tww.2", filters = { availability = "available" } })
AssertEqual(#view.rows, 1)
AssertEqual(view.selectedState, "hidden")
AssertEqual(view.hiddenSelection, true)

view = Browser.BuildView({ encounters = encounters, selectedEncounterID = "gone", filters = { query = "cinder", expansion = "The War Within", zone = "Dornogal", support = "supported" } })
AssertEqual(#view.rows, 1)
AssertEqual(view.rows[1].encounterID, "tww.1")
AssertEqual(view.selectedState, "missing")

view = Browser.BuildView({ encounters = encounters, filters = { query = "no match" } })
AssertEqual(#view.rows, 0)
AssertEqual(view.selectedState, "none")
AssertEqual(view.emptyState, "No encounters match these filters.")

view = Browser.BuildView({ encounters = {} })
AssertEqual(view.inputState, "available")
AssertEqual(view.knownEncounterCount, 0)
AssertEqual(view.emptyState, "No encounter content has been loaded yet.")

view = Browser.BuildView({ filters = { query = "cinder" } })
AssertEqual(view.inputState, "unavailable")
AssertEqual(view.emptyState, "Encounter content is unavailable.")

view = Browser.BuildView(false)
AssertEqual(view.inputState, "unavailable")
AssertEqual(view.emptyState, "Encounter content is unavailable.")

view = Browser.BuildView({
    encounters = { { encounterID = "invalid" } },
})
AssertEqual(view.inputState, "available")
AssertEqual(view.knownEncounterCount, 0)
AssertEqual(view.emptyState, "No encounter content has been loaded yet.")
