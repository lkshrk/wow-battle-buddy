local addonName = ...

local function OpenPetJournal()
    local opened = BattleBuddyPetJournalSurface.Open()
    if opened then
        return true
    end

    return false
end

local function OpenSettings(category)
    if Settings and category then
        Settings.OpenToCategory(category:GetID())
        return true
    end

    return false
end

local function PrintHelp()
    print("|cff00ff98BattleBuddy|r — Available slash commands:")
    print("  |cffffd100/bb|r — Focus BattleBuddy in the Pet Journal when available; otherwise open settings.")
    print("  |cffffd100/bb config|r — Open BattleBuddy settings.")
    print("  |cffffd100/bb help|r — Show this command list.")
end

local function RegisterSettings()
    local category = Settings.RegisterVerticalLayoutCategory(addonName)
    Settings.RegisterAddOnCategory(category)

    _G.SLASH_BATTLEBUDDY1 = "/bb"
    SlashCmdList.BATTLEBUDDY = function(command)
        command = type(command) == "string" and command:lower():match("^%s*(.-)%s*$") or ""
        if command == "config" then
            if not OpenSettings(category) then
                print("|cffff0000BattleBuddy|r — Settings are unavailable.")
            end
        elseif command == "help" then
            PrintHelp()
        elseif not OpenPetJournal() and not OpenSettings(category) then
            print("|cffff0000BattleBuddy|r — The Pet Journal and settings are unavailable.")
        end
    end
end

local function Initialize()
    BattleBuddyPersistence.Load()
    RegisterSettings()

    if type(BattleBuddyEncounterContent) ~= "table" or type(BattleBuddyEncounterCatalog) ~= "table" then
        return
    end

    local catalog = BattleBuddyEncounterCatalog.BuildView(BattleBuddyEncounterContent.BuildCatalogInput())
    if catalog.state == "invalid" then
        return
    end

    BattleBuddyEncounterCatalog.Current = catalog
    BattleBuddyPetJournalSurface.SetEncounterBrowserInput(BattleBuddyEncounterCatalog.BuildBrowserInput(catalog))
end

EventUtil.ContinueOnAddOnLoaded(addonName, Initialize)
