BattleBuddyBattlePanel = {}

local Panel, Compatibility = BattleBuddyBattlePanel, BattleBuddyCompatibility
local paused, ended, held, registered, hooked = true, false, false, false, false
local heldKeys = {}
local AUTO = "BATTLEBUDDY_AUTOBATTLE"
local PASS = "CLICK BattleBuddyPass:LeftButton"
local function SwapBinding(index) return "CLICK BattleBuddySwap" .. index .. ":LeftButton" end

BINDING_HEADER_BATTLEBUDDY = "BattleBuddy"
BINDING_NAME_BATTLEBUDDY_AUTOBATTLE = "BattleBuddy: Autobattle"
_G["BINDING_NAME_" .. PASS] = PET_BATTLE_PASS or "Pass"
for index = 1, 3 do
    _G["BINDING_NAME_" .. SwapBinding(index)] = (SWITCH_PET or "Swap pet") .. " " .. index
end

local function Public(value) return Compatibility.PublicValue(value) end
local function Read(name, ...)
    local fn = C_PetBattles and C_PetBattles[name]
    if type(fn) ~= "function" then return end
    local ok, a, b, c, d, e, f, g, h = pcall(fn, ...)
    if ok then return Public(a), Public(b), Public(c), Public(d), Public(e), Public(f), Public(g), Public(h) end
end

local function Number(value, low, high)
    value = Public(value)
    if type(value) == "number" and value >= low and value <= high then return value end
end

local function Setting(key, low, high)
    return Number(BattleBuddyConfig.GetSetting(key), low, high) or BattleBuddyConfig.Defaults[key]
end

local function InCombat() return not InCombatLockdown or InCombatLockdown() end
local function InBattle() return not ended and Read("IsInBattle") == true end
local function Key(command)
    local value = GetBindingKey and Public(GetBindingKey(command))
    return type(value) == "string" and value or ""
end

local function AutoKey()
    local key = Key(AUTO)
    if key ~= "" then return key end
    key = Public(BattleBuddyConfig.GetSetting("battleAutobattleKey"))
    return type(key) == "string" and key or ""
end

local function Reason()
    if not InBattle() then return "Outside pet battle" end
    if paused then return "Paused after reload; resumes next battle" end
    if not BattleBuddyScript then return "Script runtime unavailable" end
    local script = Public(BattleBuddyScript.ActiveScript())
    if script == nil or script == "" then return "No active team script" end
end

local function Advance()
    if Reason() then return end
    BattleBuddyScript.WithHardwareEvent(function()
        local script = BattleBuddyScript.ActiveScript()
        if type(script) == "string" then script = BattleBuddyScript.Parse(script) end
        local snapshot = BattleBuddyScript.CaptureSnapshot()
        local action = BattleBuddyScript.Evaluate(script, snapshot)
        if action then BattleBuddyScript.Execute(action) end
    end)
end

function Panel.Binding(state)
    if state == "up" then
        if IsKeyDown then
            for _, key in ipairs(heldKeys) do
                key = Public(key)
                local base = type(key) == "string" and key:match("[^-]+$")
                if base and Public(IsKeyDown(base)) ~= false then return end
            end
        end
        held, heldKeys = false, {}
        return
    end
    if state ~= "down" or held then return end
    held = true
    heldKeys = { GetBindingKey(AUTO) }
    heldKeys[#heldKeys + 1] = AutoKey()
    Advance()
end

local function Text(parent, text)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetText(text or "")
    return label
end

local function Texture(parent, r, g, b, a)
    local texture = parent:CreateTexture(nil, "BACKGROUND")
    texture:SetColorTexture(r, g, b, a)
    return texture
end

local function Button(parent, text, width)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 30)
    button:SetText(text)
    return button
end

local function Place(object, parent, x, y, width, height)
    object:ClearAllPoints()
    object:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", x, y)
    object:SetSize(width, height)
end

local function Position(frame)
    frame:SetScale(Setting("battlePanelScale", 50, 200) / 100)
    frame:ClearAllPoints()
    if Public(BattleBuddyConfig.GetSetting("battlePanelMoved")) == true then
        local ratio = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
        frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
            Setting("battlePanelX", -100000, 100000) / ratio,
            Setting("battlePanelY", -100000, 100000) / ratio)
    else
        frame:SetPoint("BOTTOM", PetBattleFrame.BottomFrame, "BOTTOM", 0, 14)
    end
end

local function Remember(frame)
    local x, y = frame:GetCenter()
    x, y = Number(x, -100000, 100000), Number(y, -100000, 100000)
    if not x or not y then return end
    local ratio = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    BattleBuddyConfig.SetSetting("battlePanelX", x * ratio)
    BattleBuddyConfig.SetSetting("battlePanelY", y * ratio)
    BattleBuddyConfig.SetSetting("battlePanelMoved", true)
end

local function UpdateBindings()
    if InCombat() then return end
    if held and IsKeyDown then
        local released = #heldKeys > 0
        for _, key in ipairs(heldKeys) do
            key = Public(key)
            local base = type(key) == "string" and key:match("[^-]+$")
            if not base or Public(IsKeyDown(base)) ~= false then released = false end
        end
        if released then held, heldKeys = false, {} end
    end
    ClearOverrideBindings(Panel.events)
    if InBattle() and AutoKey() ~= "" then
        SetOverrideBinding(Panel.events, false, AutoKey(), AUTO)
    end
end

local function EndCapture(frame)
    frame.capture:EnableKeyboard(false)
    frame.capture:Hide()
end

local function SaveKey(frame, key)
    if InCombat() then return end
    if key ~= "" then held, heldKeys = true, { key } end
    local assigned = { GetBindingKey(AUTO) }
    for _, old in ipairs(assigned) do
        old = Public(old)
        if type(old) == "string" then SetBinding(old) end
    end
    if #assigned > 0 then SaveBindings(GetCurrentBindingSet()) end
    BattleBuddyConfig.SetSetting("battleAutobattleKey", key)
    EndCapture(frame)
    UpdateBindings()
    Panel.Refresh()
end

local function CreatePanel(parent, preview)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(395, 106)
    frame.background = Texture(frame, 0.025, 0.035, 0.05, 0.97)
    frame.background:SetAllPoints()
    frame.divider = Texture(frame, 0.1, 0.75, 1, 0.9)
    Place(frame.divider, frame, 8, 72, 379, 1)
    for _, x in ipairs({ 112, 225, 330 }) do
        local separator = Texture(frame, 0.1, 0.75, 1, 0.9)
        Place(separator, frame, x, 76, 1, 22)
    end
    frame.data = Button(frame, "Battle Data", 104)
    frame.auto = Button(frame, "Autobattle", 104)
    frame.bind = Button(frame, "+", 22)
    frame.bind:SetHeight(22)
    frame.bind:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    Place(frame.data, frame, 8, 72, 104, 30)
    Place(frame.auto, frame, 226, 72, 104, 30)
    Place(frame.bind, frame, 365, 80, 22, 22)
    frame.key = Text(frame)
    frame.key:SetPoint("CENTER", frame, "BOTTOMLEFT", 347, 87)
    frame.reason = Text(frame)
    frame.reason:SetPoint("TOP", frame, "BOTTOM", 0, -2)
    frame.timer = Text(frame)
    frame.timer:SetPoint("TOP", frame, "TOP", 0, -8)
    frame.xp = CreateFrame("Frame", nil, frame)
    Place(frame.xp, frame, 1, 1, 393, 8)
    frame.xp.track = Texture(frame.xp, 0.01, 0.02, 0.035, 1)
    frame.xp.track:SetAllPoints()
    frame.xp.fill = Texture(frame.xp, 0.08, 0.7, 0.95, 1)
    frame.xp.fill:SetPoint("LEFT", frame.xp, "LEFT", 0, 0)
    frame.xp.fill:SetHeight(8)
    frame.xpText = Text(frame.xp)
    frame.xpText:SetPoint("CENTER", frame.xp, "CENTER", 0, 0)
    frame.capture = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.capture:SetSize(220, 26)
    frame.capture:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 0, 24)
    frame.capture.background = Texture(frame.capture, 0.02, 0.03, 0.05, 1)
    frame.capture.background:SetAllPoints()
    frame.capture.label = Text(frame.capture, "Press a key; Escape cancels")
    frame.capture.label:SetPoint("CENTER", frame.capture, "CENTER", 0, 0)
    EndCapture(frame)
    frame:SetScript("OnHide", function() EndCapture(frame) end)
    frame.dataView = CreateFrame("Frame", nil, frame)
    frame.dataView:SetSize(395, 48)
    frame.dataView:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", -8, 0)
    frame.dataView.background = Texture(frame.dataView, 0.02, 0.03, 0.05, 1)
    frame.dataView.background:SetAllPoints()
    frame.dataView.text = Text(frame.dataView)
    frame.dataView.text:SetPoint("CENTER", frame.dataView, "CENTER", 0, 0)
    frame.dataView:Hide()
    frame.data:SetScript("OnClick", function()
        frame.dataView:SetShown(not frame.dataView:IsShown())
        if not preview then Panel.Refresh() end
    end)
    if preview then
        frame.pass = Button(frame, PET_BATTLE_PASS or "Pass", 112)
        Place(frame.pass, frame, 113, 72, 112, 30)
        for index = 1, 6 do
            local icon = CreateFrame("Frame", nil, frame)
            Place(icon, frame, 13 + (index - 1) * 63, 14, 54, 54)
            local texture = icon:CreateTexture(nil, "ARTWORK")
            texture:SetAllPoints()
            texture:SetTexture(134400)
        end
        frame.auto:Disable()
        frame.bind:Disable()
        frame.key:SetText("A")
        frame.reason:SetText("Preview")
        frame.dataView.text:SetText("Preview: public battle facts appear here")
        return frame
    end
    frame.auto:RegisterForClicks("LeftButtonUp")
    frame.auto:SetScript("OnClick", Advance)
    frame.bind:SetScript("OnClick", function(_, mouse)
        if InCombat() then return end
        if mouse == "RightButton" then SaveKey(frame, ""); return end
        frame.capture:Show()
        frame.capture:EnableKeyboard(true)
        frame.capture:SetPropagateKeyboardInput(false)
    end)
    frame.capture:SetScript("OnKeyDown", function(_, key)
        if InCombat() then return end
        key = Public(key)
        if type(key) ~= "string" then return end
        if key == "ESCAPE" then EndCapture(frame); return end
        if key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL"
            or key == "LALT" or key == "RALT" then return end
        if IsShiftKeyDown() then key = "SHIFT-" .. key end
        if IsControlKeyDown() then key = "CTRL-" .. key end
        if IsAltKeyDown() then key = "ALT-" .. key end
        SaveKey(frame, key)
    end)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:EnableMouseWheel(true)
    frame:SetScript("OnDragStart", function()
        if not InCombat() and IsShiftKeyDown() then frame.dragging = true; frame:StartMoving() end
    end)
    frame:SetScript("OnDragStop", function()
        if InCombat() or not frame.dragging then return end
        frame:StopMovingOrSizing()
        frame.dragging = false
        Remember(frame)
        Position(frame)
    end)
    frame:SetScript("OnMouseWheel", function(_, delta)
        delta = Number(delta, -100, 100)
        if InCombat() or not IsControlKeyDown() or not delta or delta == 0 then return end
        Remember(frame)
        BattleBuddyConfig.SetSetting("battlePanelScale", math.max(50, math.min(200,
            Setting("battlePanelScale", 50, 200) + (delta > 0 and 1 or -1))))
        Position(frame)
        Panel.Refresh()
    end)
    return frame
end

local function Proxy(frame, name, target)
    local proxy = CreateFrame("Button", name, frame, "SecureActionButtonTemplate")
    proxy:RegisterForClicks("AnyUp")
    proxy:SetAttribute("type", "click")
    proxy:SetAttribute("clickbutton", target)
    proxy:SetAttribute("useOnKeyDown", false)
    return proxy
end

local function Attach(frame, bottom)
    frame.pass = bottom.TurnTimer.SkipButton
    frame.actions = { bottom.abilityButtons[1], bottom.abilityButtons[2], bottom.abilityButtons[3],
        bottom.SwitchPetButton, bottom.CatchButton, bottom.ForfeitButton }
    frame.pass:SetParent(frame)
    for _, button in ipairs(frame.actions) do button:SetParent(frame) end
    frame.hints = {}
    for index = 1, 3 do
        local hint = frame.actions[index]:CreateTexture(nil, "OVERLAY")
        hint:SetAllPoints()
        hint:SetColorTexture(1, 1, 1, 1)
        hint:Hide()
        frame.hints[index] = hint
    end
    frame.passBinding = Proxy(frame, "BattleBuddyPass", frame.pass)
    frame.swapBindings, frame.swapKeys = {}, {}
    for index = 1, 3 do
        local pet = bottom.PetSelectionFrame["Pet" .. index]
        frame.swapBindings[index] = Proxy(frame, "BattleBuddySwap" .. index, pet)
        frame.swapKeys[index] = Text(pet)
        frame.swapKeys[index]:SetPoint("TOPRIGHT", pet, "TOPRIGHT", -4, -4)
    end
    frame.passKey = Text(frame.pass)
    frame.passKey:SetPoint("TOPRIGHT", frame.pass, "TOPRIGHT", -3, -2)
    hooksecurefunc(bottom.TurnTimer.TimerText, "SetText", function() Panel.UpdateTimer() end)
end

local function Effectiveness(frame)
    local ally, enemy = Enum.BattlePetOwner.Ally, Enum.BattlePetOwner.Enemy
    local pet = Number(Read("GetActivePet", ally), 1, 3)
    local opponent = Number(Read("GetActivePet", enemy), 1, 3)
    local enemyType
    if opponent and opponent % 1 == 0 then enemyType = Number(Read("GetPetType", enemy, opponent), 1, 10) end
    for index, hint in ipairs(frame.hints) do
        hint:Hide()
        if pet and pet % 1 == 0 and enemyType and enemyType % 1 == 0 then
            local _, _, _, _, _, _, family, suppressed = Read("GetAbilityInfo", ally, pet, index)
            family = Number(family, 1, 10)
            if family and family % 1 == 0 and suppressed == false then
                local modifier = Number(Read("GetAttackModifier", family, enemyType), 0, 100)
                if modifier and modifier ~= 1 then
                    local r, g = modifier > 1 and 0 or 1, modifier > 1 and 1 or 0
                    hint:SetGradient("VERTICAL", CreateColor(r, g, 0, 0.45), CreateColor(r, g, 0, 0))
                    hint:Show()
                end
            end
        end
    end
end

function Panel.UpdateTimer()
    local frame = Panel.frame
    if not frame or not InBattle() then return end
    local remaining, total = Read("GetTurnTimeInfo")
    remaining, total = Number(remaining, 0, 86400), Number(total, 0.001, 86400)
    local state = Read("GetBattleState")
    local states = Enum.PetbattleState
    local waiting = state == states.WaitingPreBattle or state == states.RoundInProgress
        or state == states.WaitingForFrontPets
    local text = ""
    if Read("IsPlayerNPC", Enum.BattlePetOwner.Enemy) == false and waiting and remaining and total then
        if Read("IsWaitingOnOpponent") == true then text = PET_BATTLE_WAITING_FOR_OPPONENT or "Waiting for opponent"
        else text = tostring(math.ceil(remaining)) end
    end
    frame.timer:SetText(text)
end

local function Facts(frame)
    local owner = Enum.BattlePetOwner.Ally
    local pet = Number(Read("GetActivePet", owner), 1, 3)
    local xp, maximum
    if pet and pet % 1 == 0 then xp, maximum = Read("GetXP", owner, pet) end
    xp, maximum = Number(xp, 0, 2147483647), Number(maximum, 1, 2147483647)
    local known = xp and maximum and xp <= maximum
    frame.xpText:SetText(known and ("%.0f / %.0f"):format(xp, maximum) or "")
    frame.xp.fill:SetWidth(known and 393 * xp / maximum or 0)
    frame.xp.fill:SetShown(known and xp > 0 or false)
    frame.dataView.text:SetText("Active pet: " .. (pet and tostring(pet) or "?")
        .. "    XP: " .. (known and frame.xpText:GetText() or "?")
        .. "\n" .. (paused and "Script history unavailable after reload" or "Public current snapshot"))
    Panel.UpdateTimer()
end

local function HideArt(object)
    if object then object:Hide() end
end

function Panel.Refresh()
    if InCombat() then return end
    if not InBattle() then
        if Panel.frame then EndCapture(Panel.frame); Panel.frame:Hide() end
        return
    end
    local bottom = PetBattleFrame and PetBattleFrame.BottomFrame
    if not bottom or not bottom.abilityButtons or not bottom.abilityButtons[3]
        or not bottom.TurnTimer or not bottom.PetSelectionFrame then return end
    if not Panel.frame then
        Panel.frame = CreatePanel(PetBattleFrame)
        Attach(Panel.frame, bottom)
    end
    local frame = Panel.frame
    local pvp = Read("IsPlayerNPC", Enum.BattlePetOwner.Enemy) == false
    frame:SetSize(395, pvp and 135 or 106)
    Position(frame)
    bottom:SetHeight(math.max(100, 14 + frame:GetHeight() * frame:GetEffectiveScale() / bottom:GetEffectiveScale()))
    for index, button in ipairs(frame.actions) do
        button:SetScale(1)
        button:SetFrameLevel(frame:GetFrameLevel() + 2)
        Place(button, frame, 13 + (index - 1) * 63, 14, 54, 54)
    end
    frame.pass:SetScale(1)
    Place(frame.pass, frame, 113, 72, 112, 30)
    frame.pass:SetText(PET_BATTLE_PASS or "Pass")
    frame.passKey:SetText(Key(PASS))
    for index, label in ipairs(frame.swapKeys) do label:SetText(Key(SwapBinding(index))) end
    for _, key in ipairs({ "Background", "LeftEndCap", "RightEndCap", "MicroButtonFrame", "Delimiter", "xpBar" }) do
        HideArt(bottom[key])
    end
    bottom.FlowFrame:DisableDrawLayer("BACKGROUND")
    bottom.FlowFrame:DisableDrawLayer("BORDER")
    for _, key in ipairs({ "TimerBG", "Bar", "ArtFrame", "ArtFrame2", "TimerText" }) do HideArt(bottom.TurnTimer[key]) end
    local reason = Reason()
    frame.reason:SetText(reason or "")
    if reason then frame.auto:Disable() else frame.auto:Enable() end
    frame.key:SetText(AutoKey())
    Facts(frame)
    Effectiveness(frame)
    frame:Show()
end

function Panel.ShowPreview()
    if InCombat() or Read("IsInBattle") ~= false then return false end
    if not Panel.preview then
        Panel.preview = CreatePanel(UIParent, true)
        Panel.preview:SetPoint("CENTER", UIParent, "CENTER", 0, -160)
    end
    Panel.preview:Show()
    return true
end

function Panel.HidePreview()
    if Panel.preview then Panel.preview:Hide() end
end

local function OnEvent(_, event)
    if not registered and BattleBuddyDev then
        registered = BattleBuddyDev.RegisterView("battle-panel", Panel.ShowPreview, Panel.HidePreview,
            function() return Panel.preview and Panel.preview:IsShown() end)
    end
    if event == "PET_BATTLE_OPENING_START" then
        paused, ended = false, false
        Panel.HidePreview()
    elseif event == "PLAYER_LOGIN" then
        paused = Read("IsInBattle") == true
    elseif event == "PET_BATTLE_CLOSE" or event == "PET_BATTLE_OVER" then
        ended = true
        Panel.HidePreview()
    elseif event == "PLAYER_REGEN_DISABLED" and Panel.frame then
        EndCapture(Panel.frame)
    end
    if not hooked and PetBattleFrame and hooksecurefunc and not InCombat() then
        for _, name in ipairs({ "PetBattleFrame_UpdateActionBarLayout", "PetBattleFrame_UpdatePassButtonAndTimer",
            "PetBattleFrame_UpdateXpBar" }) do
            if type(_G[name]) == "function" then hooksecurefunc(name, Panel.Refresh) end
        end
        hooked = true
    end
    if event == "PLAYER_REGEN_ENABLED" and Panel.frame and Panel.frame.dragging then
        Panel.frame:StopMovingOrSizing(); Panel.frame.dragging = false
        Remember(Panel.frame)
    end
    UpdateBindings()
    Panel.Refresh()
end

Panel.events = CreateFrame("Frame")
for _, event in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "UPDATE_BINDINGS",
    "PET_BATTLE_OPENING_START", "PET_BATTLE_OPENING_DONE", "PET_BATTLE_CLOSE", "PET_BATTLE_OVER",
    "PET_BATTLE_PET_CHANGED", "PET_BATTLE_PET_ROUND_PLAYBACK_COMPLETE", "PET_BATTLE_ACTION_SELECTED",
    "PET_BATTLE_XP_CHANGED", "PET_BATTLE_PET_TYPE_CHANGED", "PET_BATTLE_OVERRIDE_ABILITY" }) do
    Panel.events:RegisterEvent(event)
end
Panel.events:SetScript("OnEvent", OnEvent)
