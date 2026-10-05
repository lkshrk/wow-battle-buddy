BattleBuddyEnemyAbilities = {}

local Abilities = BattleBuddyEnemyAbilities
local registeredDev
local finished = false
local battleEvents = {
    PET_BATTLE_OPENING_START = true, PET_BATTLE_OPENING_DONE = true,
    PET_BATTLE_PET_ROUND_PLAYBACK_COMPLETE = true, PET_BATTLE_PET_CHANGED = true,
    PET_BATTLE_ACTION_SELECTED = true, PET_BATTLE_PET_TYPE_CHANGED = true,
    PET_BATTLE_OVERRIDE_ABILITY = true, PET_BATTLE_HEALTH_CHANGED = true,
    PET_BATTLE_AURA_APPLIED = true, PET_BATTLE_AURA_CANCELED = true,
    PET_BATTLE_AURA_CHANGED = true,
}

local function Public(value)
    local ok, result = pcall(BattleBuddyCompatibility.ClassifyValue, value)
    if ok then return result end
end

local function Integer(value, minimum, maximum)
    value = Public(value)
    if type(value) == "number" and value >= minimum and value <= maximum and value % 1 == 0 then
        return value
    end
end

local function Read(name, ...)
    local api = C_PetBattles and C_PetBattles[name]
    if type(api) ~= "function" then return end
    local ok, a, b, c, d = pcall(api, ...)
    if ok then return Public(a), Public(b), Public(c), Public(d) end
end

local function Setting(name, minimum, maximum)
    return Integer(BattleBuddyConfig.GetSetting(name), minimum, maximum) or BattleBuddyConfig.Defaults[name]
end

local function HideTooltip()
    if PetBattlePrimaryAbilityTooltip then PetBattlePrimaryAbilityTooltip:Hide() end
end

local function Position(frame)
    frame:SetScale(Setting("enemyAbilityScale", 50, 200) / 100)
    frame:ClearAllPoints()
    if Public(BattleBuddyConfig.GetSetting("enemyAbilityMoved")) == true then
        local ratio = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
        frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
            Setting("enemyAbilityX", -100000, 100000) / ratio,
            Setting("enemyAbilityY", -100000, 100000) / ratio)
    else
        frame:SetPoint("BOTTOM", PetBattleFrame.BottomFrame, "TOP", 0, 28)
    end
end

local function RememberCenter(frame)
    local x, y = frame:GetCenter()
    if not x or not y then return end
    local ratio = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    BattleBuddyConfig.SetSetting("enemyAbilityX", math.floor(x * ratio + 0.5))
    BattleBuddyConfig.SetSetting("enemyAbilityY", math.floor(y * ratio + 0.5))
    BattleBuddyConfig.SetSetting("enemyAbilityMoved", true)
end

local function CreateBar(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame.icons = {}
    frame:SetScript("OnHide", HideTooltip)
    for slot = 1, 3 do
        local icon = CreateFrame("Frame", nil, frame)
        icon:EnableMouse(true)
        icon.texture = icon:CreateTexture(nil, "ARTWORK")
        icon.texture:SetAllPoints()
        icon.border = icon:CreateTexture(nil, "OVERLAY")
        icon.border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        icon.border:SetPoint("TOPLEFT", icon, "TOPLEFT", -3, 3)
        icon.border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 3, -3)
        icon.cooldown = icon:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        icon.cooldown:SetPoint("CENTER", icon, "CENTER", 0, 0)
        icon.maxCooldown = icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        icon.maxCooldown:SetPoint("TOPRIGHT", icon, "TOPRIGHT", 0, 0)
        icon:SetScript("OnEnter", function()
            if not frame.pet or not icon.ability or not PetBattleAbilityTooltip_SetAbility
                or not PetBattleAbilityTooltip_Show then return end
            local ok = pcall(PetBattleAbilityTooltip_SetAbility, Enum.BattlePetOwner.Enemy, frame.pet, slot)
            if ok then
                ok = pcall(PetBattleAbilityTooltip_Show, "BOTTOMLEFT", icon, "TOPRIGHT", 0, 0)
            end
            if not ok then HideTooltip() end
        end)
        icon:SetScript("OnLeave", HideTooltip)
        if parent ~= UIParent then
            frame:SetMovable(true)
            icon:RegisterForDrag("LeftButton")
            icon:EnableMouseWheel(true)
            icon:SetScript("OnDragStart", function()
                if not InCombatLockdown() and IsShiftKeyDown() then
                    frame.dragging = true
                    frame:StartMoving()
                end
            end)
            icon:SetScript("OnDragStop", function()
                if not frame.dragging then return end
                frame:StopMovingOrSizing()
                frame.dragging = false
                if InCombatLockdown() then return end
                RememberCenter(frame)
                Position(frame)
            end)
            icon:SetScript("OnMouseWheel", function(_, delta)
                if InCombatLockdown() or not IsControlKeyDown() or delta == 0 then return end
                RememberCenter(frame)
                local scale = Setting("enemyAbilityScale", 50, 200) + (delta > 0 and 1 or -1)
                BattleBuddyConfig.SetSetting("enemyAbilityScale", math.max(50, math.min(200, scale)))
                Position(frame)
            end)
        end
        frame.icons[slot] = icon
    end
    return frame
end

local function Layout(frame)
    local size = Setting("enemyAbilitySize", 16, 128)
    local gap = Setting("enemyAbilitySpacing", 0, 32)
    local fontSize = Setting("enemyAbilityFontSize", 6, 48)
    local font = Public(BattleBuddyConfig.GetSetting("enemyAbilityFont"))
    if type(font) ~= "string" or font == "" then font = BattleBuddyConfig.Defaults.enemyAbilityFont end
    frame:SetSize(size * 3 + gap * 2, size)
    for slot, icon in ipairs(frame.icons) do
        icon:SetSize(size, size)
        icon:ClearAllPoints()
        icon:SetPoint("LEFT", frame, "LEFT", (slot - 1) * (size + gap), 0)
        if not icon.cooldown:SetFont(font, fontSize, "OUTLINE") then
            icon.cooldown:SetFont(BattleBuddyConfig.Defaults.enemyAbilityFont, fontSize, "OUTLINE")
        end
        if not icon.maxCooldown:SetFont(font, 12, "OUTLINE") then
            icon.maxCooldown:SetFont(BattleBuddyConfig.Defaults.enemyAbilityFont, 12, "OUTLINE")
        end
    end
end

function Abilities.Refresh()
    HideTooltip()
    if finished or Read("IsInBattle") ~= true or Read("ShouldShowPetSelect") ~= false then
        if Abilities.frame then Abilities.frame:Hide() end
        return
    end
    local owner = Enum.BattlePetOwner.Enemy
    local pet = Integer(Read("GetActivePet", owner), 1, 3)
    if not pet or not PetBattleFrame or not PetBattleFrame.BottomFrame then
        if Abilities.frame then Abilities.frame:Hide() end
        return
    end
    if not Abilities.frame then
        Abilities.frame = CreateBar(PetBattleFrame)
    end
    local frame = Abilities.frame
    Layout(frame)
    Position(frame)
    frame.pet = pet
    local visible = false
    for slot, icon in ipairs(frame.icons) do
        local id, _, texture, maximum = Read("GetAbilityInfo", owner, pet, slot)
        icon.ability = Integer(id, 1, 2147483647)
        texture = Integer(texture, 1, 2147483647) or 134400
        icon.texture:SetTexture(texture)
        maximum = Integer(maximum, 0, 2147483647)
        icon.maxCooldown:SetText(maximum and maximum > 0 and tostring(maximum) or "")
        local _, cooldown, lockdown = Read("GetAbilityState", owner, pet, slot)
        cooldown = Integer(cooldown, 0, 2147483647)
        lockdown = Integer(lockdown, 0, 2147483647)
        local remaining = cooldown and lockdown and math.max(cooldown, lockdown)
        icon.cooldown:SetText(remaining and remaining > 0 and tostring(remaining) or "")
        icon:SetShown(icon.ability ~= nil)
        visible = visible or icon.ability ~= nil
    end
    frame:SetShown(visible)
end

function Abilities.ShowPreview()
    if InCombatLockdown() or Read("IsInBattle") ~= false then return false end
    if not Abilities.preview then
        Abilities.preview = CreateBar(UIParent)
        Abilities.preview:SetPoint("CENTER", UIParent, "CENTER", 0, -160)
    end
    Layout(Abilities.preview)
    for slot, icon in ipairs(Abilities.preview.icons) do
        icon.texture:SetTexture(134400)
        icon.cooldown:SetText(slot == 1 and "2" or "")
    end
    Abilities.preview:Show()
    return true
end

function Abilities.HidePreview()
    if Abilities.preview then Abilities.preview:Hide() end
end

local function RegisterDev()
    if registeredDev or not BattleBuddyDev then return end
    registeredDev = BattleBuddyDev.RegisterView("battle-enemy-abilities", Abilities.ShowPreview,
        Abilities.HidePreview, function() return Abilities.preview and Abilities.preview:IsShown() end)
end

if CreateFrame then
    Abilities.events = CreateFrame("Frame")
    for event in pairs(battleEvents) do Abilities.events:RegisterEvent(event) end
    for _, event in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PET_BATTLE_OVER", "PET_BATTLE_CLOSE" }) do
        Abilities.events:RegisterEvent(event)
    end
    Abilities.events:SetScript("OnEvent", function(_, event)
        if event == "ADDON_LOADED" or event == "PLAYER_LOGIN" then
            RegisterDev()
        elseif event == "PET_BATTLE_CLOSE" or event == "PET_BATTLE_OVER" then
            finished = true
            Abilities.HidePreview()
            HideTooltip()
            if Abilities.frame then Abilities.frame.pet = nil; Abilities.frame:Hide() end
        elseif battleEvents[event] then
            if event == "PET_BATTLE_OPENING_START" or event == "PET_BATTLE_OPENING_DONE" then finished = false end
            Abilities.HidePreview()
            Abilities.Refresh()
        end
    end)
end
