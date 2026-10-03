local sourceRoot = (... or ".")

local function AssertEqual(actual, expected)
    if actual ~= expected then
        error(("expected %s, got %s"):format(tostring(expected), tostring(actual)))
    end
end

local loadCallback
EventUtil = {
    ContinueOnAddOnLoaded = function(_, callback)
        loadCallback = callback
    end,
}
local openCalls = 0
BattleBuddyPetJournalSurface = {
    Open = function()
        openCalls = openCalls + 1
        return false
    end,
}
local loadCalls = 0
BattleBuddyPersistence = { Load = function() loadCalls = loadCalls + 1 end }
BattleBuddyDB = { encounterOverrides = { { targetEncounterID = "shipped.example" } } }
local capturedCatalogInput
BattleBuddyEncounterContent = { BuildCatalogInput = function() return { schemaVersion = 1, catalogRevision = 1, records = {} } end }
BattleBuddyEncounterCatalog = {
    BuildView = function(input)
        capturedCatalogInput = input
        return { state = "ready", records = {}, recordsByID = {} }
    end,
    BuildBrowserInput = function() return {} end,
}
BattleBuddyPetJournalSurface.SetEncounterBrowserInput = function() end

local settingsOpenID
Settings = {
    RegisterVerticalLayoutCategory = function()
        return { GetID = function() return "101" end }
    end,
    RegisterAddOnCategory = function() end,
    OpenToCategory = function(id) settingsOpenID = id end,
}
SlashCmdList = {}

dofile(sourceRoot .. "/BattleBuddy/BattleBuddy.lua")
loadCallback("BattleBuddy")
AssertEqual(loadCalls, 1)
AssertEqual(capturedCatalogInput.overrides, BattleBuddyDB.encounterOverrides)

SlashCmdList.BATTLEBUDDY("")
AssertEqual(openCalls, 1)
AssertEqual(settingsOpenID, "101")

settingsOpenID = nil
SlashCmdList.BATTLEBUDDY("config")
AssertEqual(settingsOpenID, "101")

settingsOpenID = nil
SlashCmdList.BATTLEBUDDY(nil)
AssertEqual(openCalls, 2)
AssertEqual(settingsOpenID, "101")
