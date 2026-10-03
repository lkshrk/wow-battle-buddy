local addonName = ...

local function OpenPetJournal()
    ToggleCollectionsJournal(COLLECTIONS_JOURNAL_TAB_INDEX_PETS)
end

local function PrintHelp()
    print("|cff00ff98BattleBuddy|r — Available slash commands:")
    print("  |cffffd100/bb|r — Open the Pet Journal on the Pets tab.")
    print("  |cffffd100/bb config|r — Open BattleBuddy settings.")
    print("  |cffffd100/bb help|r — Show this command list.")
end

local function RegisterSettings()
    local category = Settings.RegisterVerticalLayoutCategory(addonName)
    Settings.RegisterAddOnCategory(category)

    _G.SLASH_BATTLEBUDDY1 = "/bb"
    SlashCmdList.BATTLEBUDDY = function(command)
        command = command:lower():match("^%s*(.-)%s*$")
        if command == "config" then
            Settings.OpenToCategory(category:GetID())
        elseif command == "help" then
            PrintHelp()
        else
            OpenPetJournal()
        end
    end
end

EventUtil.ContinueOnAddOnLoaded(addonName, RegisterSettings)
