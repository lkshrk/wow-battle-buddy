BattleBuddyBattleStats = {}

local Stats = BattleBuddyBattleStats
local inBattle, registeredDev = false, false
local columns = { "health", "power", "speed" }
local crops = { health = "32:64:32:64", power = "0:32:0:32", speed = "0:32:32:64" }

local function Public(value)
    local ok, result = pcall(BattleBuddyCompatibility.ClassifyValue, value)
    if ok then return result end
end

local function Number(value)
    value = Public(value)
    if type(value) == "number" and value >= 0 and value < math.huge and value % 1 == 0 then
        return value
    end
end

local function Read(name, ...)
    local api = C_PetBattles and C_PetBattles[name]
    if type(api) ~= "function" then return end
    local ok, value = pcall(api, ...)
    if ok then return Public(value) end
end

local function InCombat()
    return not InCombatLockdown or InCombatLockdown()
end

function Stats.FormatStats(pet)
    local health, maximum = Number(pet.health), Number(pet.maximum)
    local power, speed = Number(pet.power), Number(pet.speed)
    return {
        health = health and maximum and maximum > 0 and health <= maximum
            and ("%.0f%%"):format(health / maximum * 100) or nil,
        power = power and ("%.0f"):format(power) or "?",
        speed = speed and ("%.0f"):format(speed) or "?",
    }
end

function Stats.ReadPet(owner)
    local slot = Number(Read("GetActivePet", owner))
    if not slot or slot < 1 or slot > 3 then return {} end
    return {
        health = Read("GetHealth", owner, slot),
        maximum = Read("GetMaxHealth", owner, slot),
        power = Read("GetPower", owner, slot),
        speed = Read("GetSpeed", owner, slot),
    }
end

local function CreateDisplay(parent)
    local display = { parent = parent, sides = {}, versusShown = parent.TopVersusText:IsShown() }
    display.round = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    display.round:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 24, "OUTLINE")
    display.round:SetPoint("TOP", parent, "TOP", -1, -17)
    display.round:Hide()
    for index, unit in ipairs({ parent.ActiveAlly, parent.ActiveEnemy }) do
        local side = { unit = unit, healthShown = unit.HealthText:IsShown() }
        display.sides[index] = side
        side.row = CreateFrame("Frame", nil, unit)
        side.row:SetSize(165, 16)
        side.row:SetPoint("TOPLEFT", unit, index == 1 and "BOTTOMRIGHT" or "BOTTOMLEFT",
            index == 1 and -188 or 42, 10)
        for column, key in ipairs(columns) do
            local stat = {}
            side[key] = stat
            stat.icon = side.row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            stat.icon:SetSize(16, 16)
            stat.icon:SetPoint("LEFT", side.row, "LEFT", (column - 1) * 55, 0)
            stat.icon:SetText("|TInterface\\PetBattles\\PetBattle-StatIcons:16:16:0:0:64:64:"
                .. crops[key] .. "|t")
            stat.text = side.row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            stat.text:SetPoint("LEFT", stat.icon, "RIGHT", 2, 0)
            stat.background = side.row:CreateTexture(nil, "BACKGROUND")
            stat.background:SetPoint("TOPLEFT", stat.icon, "TOPLEFT", -2, 2)
            stat.background:SetPoint("BOTTOMRIGHT", stat.text, "BOTTOMRIGHT", 2, -2)
            stat.background:SetColorTexture(0, 0, 0, 0.35)
        end
        side.row:Hide()
    end
    return display
end

local function Render(display, pets, round)
    local showRound = BattleBuddyConfig.GetSetting("battleRound")
    round = Number(round)
    display.round:SetText(round and ("%.0f"):format(round) or "?")
    display.round:SetShown(showRound)
    display.parent.TopVersusText:SetShown(not showRound and display.versusShown)
    for index, side in ipairs(display.sides) do
        local values = Stats.FormatStats(pets[index])
        side.row:SetShown(BattleBuddyConfig.GetSetting("battleStats"))
        side.unit.HealthText:SetShown(BattleBuddyConfig.GetSetting("battleHealth"))
        for _, key in ipairs(columns) do
            local stat = side[key]
            stat.text:SetText(values[key] or "")
            stat.text:SetShown(values[key] ~= nil)
            stat.icon:SetShown(values[key] ~= nil)
            stat.background:SetShown(values[key] ~= nil)
        end
    end
end

local function Restore(display)
    display.round:Hide()
    display.parent.TopVersusText:SetShown(display.versusShown)
    for _, side in ipairs(display.sides) do
        side.row:Hide()
        side.unit.HealthText:SetShown(side.healthShown)
    end
end

local function ShowPreview()
    if InCombat() or inBattle or Read("IsInBattle") == true then return false end
    if not Stats.preview then
        local preview = CreateFrame("Frame", nil, UIParent)
        preview:SetSize(900, 140)
        preview:SetPoint("CENTER", UIParent, "CENTER", 0, 150)
        preview.TopVersusText = preview:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        preview.TopVersusText:SetPoint("TOP", preview, "TOP", -1, -17)
        preview.TopVersusText:SetText("?")
        for index, key in ipairs({ "ActiveAlly", "ActiveEnemy" }) do
            local unit = CreateFrame("Frame", nil, preview)
            preview[key] = unit
            unit:SetSize(260, 80)
            unit:SetPoint(index == 1 and "TOPLEFT" or "TOPRIGHT", preview,
                index == 1 and "TOPLEFT" or "TOPRIGHT", 0, 0)
            unit.HealthBarBG = unit:CreateTexture(nil, "BACKGROUND")
            unit.HealthBarBG:SetSize(180, 36)
            unit.HealthBarBG:SetPoint("BOTTOMLEFT", unit, "BOTTOMLEFT", index == 1 and 66 or 36, 16)
            unit.HealthBarBG:SetColorTexture(0, 0.5, 0, 1)
            unit.HealthText = unit:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
            unit.HealthText:SetPoint("CENTER", unit.HealthBarBG, "CENTER", 0, 0)
            unit.HealthText:SetText(index == 1 and "1363/1400" or "923/923")
        end
        preview.display = CreateDisplay(preview)
        Stats.preview = preview
    end
    Render(Stats.preview.display, {
        { health = 1363, maximum = 1400, power = 341, speed = 244 },
        { health = 923, maximum = 923, power = 152, speed = 226 },
    }, 1)
    Stats.preview:Show()
    return true
end

local function HidePreview()
    if not InCombat() and Stats.preview then Stats.preview:Hide() end
end

local function RegisterDev()
    if registeredDev or not BattleBuddyDev then return end
    registeredDev = BattleBuddyDev.RegisterView("battle-stats", ShowPreview, HidePreview,
        function() return Stats.preview ~= nil and Stats.preview:IsShown() end)
end

local function OnEvent(_, event)
    if event == "ADDON_LOADED" then RegisterDev(); return end
    if event == "PET_BATTLE_CLOSE" then
        inBattle = false
        if not InCombat() and Stats.display then Restore(Stats.display) end
        return
    end
    if event == "PET_BATTLE_OPENING_START" or event == "PET_BATTLE_OPENING_DONE" then
        inBattle = true
    elseif not inBattle then
        inBattle = Read("IsInBattle") == true
    end
    if not inBattle or InCombat() then return end
    HidePreview()
    local parent = PetBattleFrame
    if not parent or not parent.TopVersusText or not parent.ActiveAlly or not parent.ActiveEnemy
        or not parent.ActiveAlly.HealthText or not parent.ActiveEnemy.HealthText then return end
    if not Stats.display then Stats.display = CreateDisplay(parent) end
    local owners = Enum and Enum.BattlePetOwner
    local pets = owners and { Stats.ReadPet(owners.Ally), Stats.ReadPet(owners.Enemy) } or { {}, {} }
    -- Playback counters do not establish the absolute current round.
    Render(Stats.display, pets, nil)
end

Stats.events = CreateFrame("Frame")
for _, event in ipairs({ "ADDON_LOADED", "PET_BATTLE_OPENING_START", "PET_BATTLE_OPENING_DONE",
    "PET_BATTLE_CLOSE", "PET_BATTLE_HEALTH_CHANGED", "PET_BATTLE_MAX_HEALTH_CHANGED",
    "PET_BATTLE_PET_CHANGED", "PET_BATTLE_AURA_APPLIED", "PET_BATTLE_AURA_CHANGED",
    "PET_BATTLE_AURA_CANCELED", "PET_BATTLE_PET_ROUND_PLAYBACK_COMPLETE" }) do
    Stats.events:RegisterEvent(event)
end
Stats.events:SetScript("OnEvent", OnEvent)
