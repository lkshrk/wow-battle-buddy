BattleBuddyConfig = {
    Policy = {
        LevelingCompletionLevel = 25,
    },
    Defaults = {
        journalWindow = true,
        healOrder = { "revive", "bandage" },
        devTools = false,
        showPetJournalPanel = true,
        showRevisionDetails = false,
        battleRound = true,
        battleStats = true,
        battleHealth = true,
        battleHealthTicks = true,
        enemyAbilitySize = 42,
        enemyAbilitySpacing = 6,
        enemyAbilityFont = "Fonts\\FRIZQT__.TTF",
        enemyAbilityFontSize = 16,
        enemyAbilityScale = 100,
        enemyAbilityMoved = false,
        enemyAbilityX = 0,
        enemyAbilityY = 0,
        battlePanelScale = 100,
        battlePanelMoved = false,
        battlePanelX = 0,
        battlePanelY = 0,
        battleAutobattleKey = "A",
    },
}

local Config = BattleBuddyConfig

function Config.GetSetting(key)
    local defaults = Config.Defaults or {}
    local overrides = type(BattleBuddyDB) == "table" and BattleBuddyDB.settingOverrides or nil
    if type(overrides) == "table" and overrides[key] ~= nil then
        return overrides[key]
    end
    return defaults[key]
end

function Config.SetSetting(key, value)
    if type(BattleBuddyDB) ~= "table" or type(BattleBuddyDB.settingOverrides) ~= "table"
        or Config.Defaults[key] == nil or type(value) ~= type(Config.Defaults[key]) then
        return false
    end

    if value == Config.Defaults[key] then
        BattleBuddyDB.settingOverrides[key] = nil
    else
        BattleBuddyDB.settingOverrides[key] = value
    end
    return true
end
