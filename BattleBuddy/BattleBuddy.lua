local addonName = ...

local function OpenPetJournal()
    ToggleCollectionsJournal(COLLECTIONS_JOURNAL_TAB_INDEX_PETS)
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
            print("BattleBuddy: /bb opens the Pet Journal; /bb config opens Settings.")
        else
            OpenPetJournal()
        end
    end
end

EventUtil.ContinueOnAddOnLoaded(addonName, RegisterSettings)
