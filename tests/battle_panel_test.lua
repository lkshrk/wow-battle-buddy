local root = (... or ".")
local Frames = dofile(root .. "/tests/support/frames.lua")
local create = CreateFrame
CreateFrame = function(...)
    local frame = create(...)
    frame.SetScale = function(self, value) self.scale = value end
    frame.GetEffectiveScale = function(self) return self.scale or 1 end
    frame.GetCenter = function() return 600, 100 end
    frame.SetAlpha = function(self, value) self.alpha = value end
    frame.SetGradient = function(self, ...) self.gradient = { ... } end
    local createTexture = frame.CreateTexture
    frame.CreateTexture = function(self, ...)
        local texture = createTexture(self, ...)
        texture.SetGradient = frame.SetGradient
        return texture
    end
    frame.SetMovable = function() end
    frame.RegisterForDrag = function() end
    frame.EnableMouseWheel = function() end
    frame.DisableDrawLayer = function() end
    frame.StartMoving = function(self) self.moving = true end
    frame.StopMovingOrSizing = function(self) self.moving = false end
    frame.RegisterForClicks = function(self, ...) self.clicks = { ... } end
    frame.EnableKeyboard = function(self, value) self.keyboard = value end
    frame.SetPropagateKeyboardInput = function() end
    frame.Enable = function(self) self.enabled = true end
    frame.Disable = function(self) self.enabled = false end
    frame.IsEnabled = function(self) return self.enabled ~= false end
    frame.SetAttribute = function(self, key, value)
        self.attributes = self.attributes or {}; self.attributes[key] = value
    end
    return frame
end
local secret = setmetatable({}, { __tostring = function() error("secret formatted") end })
issecretvalue = function(value) return rawequal(value, secret) end
canaccessvalue = function() return true end
local combat, battle, pvp = false, false, false
InCombatLockdown = function() return combat end
IsShiftKeyDown = function() return true end
IsControlKeyDown = function() return true end
IsAltKeyDown = function() return false end
CreateColor = function(...) return { ... } end
local keys, secondKeys, overrides = {}, {}, {}
GetBindingKey = function(command) return keys[command], secondKeys[command] end
GetBindingAction = function() return "" end
SetBinding = function(key, command)
    assert(not combat)
    for actionName, assigned in pairs(keys) do if assigned == key then keys[actionName] = nil end end
    if command then keys[command] = key end
end
SaveBindings = function() assert(not combat) end
GetCurrentBindingSet = function() return 1 end
ClearOverrideBindings = function(owner) assert(not combat); overrides[owner] = {} end
SetOverrideBinding = function(owner, _, key, command)
    assert(not combat); overrides[owner][key] = command
end
hooksecurefunc = function(target, name, callback)
    if type(target) == "string" then return end
    local original = target[name]
    target[name] = function(...) local result = original(...); callback(...); return result end
end
C_Timer = { After = function() error("scheduled timer") end }
UIParent = CreateFrame("Frame", "UIParent")
Enum = { BattlePetOwner = { Ally = 1, Enemy = 2 },
    PetbattleState = { WaitingPreBattle = 1, RoundInProgress = 2, WaitingForFrontPets = 3 } }
local xp, maximum, remaining = 50, 100, 20
C_PetBattles = {
    IsInBattle = function() return battle end,
    IsWildBattle = function() return not pvp end,
    IsPlayerNPC = function() return not pvp end,
    GetActivePet = function() return 1 end,
    GetXP = function() return xp, maximum end,
    GetTurnTimeInfo = function() return remaining, 30 end,
    GetBattleState = function() return 1 end,
    IsWaitingOnOpponent = function() return false end,
}
BattleBuddyDB = { settingOverrides = {} }
dofile(root .. "/BattleBuddy/Config.lua")
dofile(root .. "/BattleBuddy/Compatibility.lua")
dofile(root .. "/BattleBuddy/Dev.lua")
local captures, evaluations, executions, hardware = 0, 0, 0, 0
local script, action = {}, { kind = "standby" }
BattleBuddyScript = {
    ActiveScript = function() return script end,
    CaptureSnapshot = function() captures = captures + 1; return {} end,
    Evaluate = function(value) assert(value == script); evaluations = evaluations + 1; return action end,
    Execute = function(value) assert(value == action); executions = executions + 1 end,
    WithHardwareEvent = function(callback) hardware = hardware + 1; callback() end,
}
PetBattleFrame = CreateFrame("Frame", "PetBattleFrame", UIParent)
local bottom = CreateFrame("Frame", nil, PetBattleFrame)
PetBattleFrame.BottomFrame = bottom
bottom:SetSize(800, 100)
bottom.abilityButtons = {}
local manual, confirmations, forfeits = 0, 0, 0
local pendingForfeit
local function Button(parent)
    local button = CreateFrame("Button", nil, parent)
    button:SetScript("OnClick", function() manual = manual + 1 end)
    return button
end
for i = 1, 3 do bottom.abilityButtons[i] = Button(bottom) end
bottom.SwitchPetButton, bottom.CatchButton, bottom.ForfeitButton = Button(bottom), Button(bottom), Button(bottom)
bottom.ForfeitButton:SetScript("OnClick", function()
    confirmations = confirmations + 1
    pendingForfeit = function() forfeits = forfeits + 1 end
end)
bottom.TurnTimer = CreateFrame("Frame", nil, bottom)
bottom.TurnTimer.SkipButton = Button(bottom.TurnTimer)
bottom.TurnTimer.TimerText = bottom.TurnTimer:CreateFontString()
bottom.PetSelectionFrame = CreateFrame("Frame", nil, bottom)
for i = 1, 3 do bottom.PetSelectionFrame["Pet" .. i] = Button(bottom.PetSelectionFrame) end
bottom.MicroButtonFrame = CreateFrame("Frame", nil, bottom)
bottom.FlowFrame = CreateFrame("Frame", nil, bottom)
bottom.xpBar = CreateFrame("Frame", nil, bottom)
for _, key in ipairs({ "Background", "LeftEndCap", "RightEndCap", "Delimiter" }) do
    bottom[key] = CreateFrame("Frame", nil, bottom)
end
for _, key in ipairs({ "LeftEndCap", "RightEndCap", "Background" }) do
    bottom.FlowFrame[key] = CreateFrame("Frame", nil, bottom.FlowFrame)
end
for _, key in ipairs({ "TimerBG", "Bar", "ArtFrame", "ArtFrame2" }) do
    bottom.TurnTimer[key] = CreateFrame("Frame", nil, bottom.TurnTimer)
end
local nativePass = bottom.TurnTimer.SkipButton:GetScript("OnClick")
local nativeForfeit = bottom.ForfeitButton:GetScript("OnClick")
dofile(root .. "/BattleBuddy/BattlePanel.lua")
local Panel = BattleBuddyBattlePanel
local function Event(event) Frames.Fire(Panel.events, "OnEvent", event) end
Event("PLAYER_LOGIN")
assert(Panel.ShowPreview())
Frames.AssertSize(Panel.preview, 395, 106)
assert(executions == 0 and hardware == 0)
Panel.HidePreview()
battle = true
Event("PET_BATTLE_OPENING_START")
local frame = assert(Panel.frame)
Frames.AssertSize(frame, 395, 106)
Frames.AssertAnchor(frame, 1, { "BOTTOM", bottom, "BOTTOM", 0, 14 })
Frames.AssertSize(frame.xp, 393, 8)
Frames.AssertAnchor(frame.xp, 1, { "BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1 })
Frames.AssertAnchor(bottom.abilityButtons[1], 1, { "BOTTOMLEFT", frame, "BOTTOMLEFT", 13, 14 })
Frames.AssertSize(bottom.abilityButtons[1], 54, 54)
Frames.AssertSize(frame.auto, 104, 30)
Frames.AssertSize(frame.bind, 22, 22)
Frames.AssertShown(bottom.MicroButtonFrame, false)
assert(frame.data:IsShown() and frame.auto:IsEnabled())
assert(frame:GetHeight() + 14 <= bottom:GetHeight() + 28)
assert(frame:GetScript("OnUpdate") == nil and Panel.events:GetScript("OnUpdate") == nil)
assert(bottom.TurnTimer.SkipButton:GetScript("OnClick") == nativePass)
assert(bottom.ForfeitButton:GetScript("OnClick") == nativeForfeit)
assert(frame.passBinding.template == "SecureActionButtonTemplate")
assert(frame.passBinding.attributes.clickbutton == bottom.TurnTimer.SkipButton)
for i = 1, 3 do assert(frame.swapBindings[i].attributes.clickbutton == bottom.PetSelectionFrame["Pet" .. i]) end
for i = 1, 5 do Event("PET_BATTLE_PET_ROUND_PLAYBACK_COMPLETE") end
assert(executions == 0 and evaluations == 0 and captures == 0)
Frames.Fire(frame.auto, "OnClick", "LeftButton")
assert(executions == 1 and evaluations == 1 and captures == 1 and hardware == 1)
Panel.Binding("down")
for i = 1, 10 do Panel.Binding("down"); Event("PET_BATTLE_ACTION_SELECTED") end
assert(executions == 2 and hardware == 2)
Panel.Binding("up")
Panel.Binding("down")
assert(executions == 3 and hardware == 3)
Panel.Binding("up")
action = nil
Frames.Fire(frame.auto, "OnClick", "LeftButton")
assert(executions == 3 and evaluations == 4 and hardware == 4)
script = nil
Panel.Refresh()
assert(not frame.auto:IsEnabled() and frame.reason:GetText() ~= "")
Frames.Fire(frame.auto, "OnClick", "LeftButton")
assert(executions == 3)
script, action = {}, { kind = "standby" }
Event("PLAYER_LOGIN")
assert(not frame.auto:IsEnabled() and frame.reason:GetText():find("reload"))
Frames.Fire(bottom.TurnTimer.SkipButton, "OnClick")
Frames.Fire(bottom.abilityButtons[1], "OnClick")
Frames.Fire(bottom.PetSelectionFrame.Pet1, "OnClick")
assert(manual == 3)
Frames.Fire(frame.auto, "OnClick", "LeftButton")
assert(executions == 3)
Event("PET_BATTLE_OPENING_START")
assert(frame.auto:IsEnabled())
Frames.Fire(bottom.ForfeitButton, "OnClick")
assert(confirmations == 1 and forfeits == 0)
pendingForfeit = nil
assert(forfeits == 0)
Frames.Fire(bottom.ForfeitButton, "OnClick")
pendingForfeit()
assert(confirmations == 2 and forfeits == 1)
Frames.AssertText(frame.xpText, "50 / 100")
for _, value in ipairs({ secret, -1, math.huge, 0/0, "5" }) do
    xp, remaining = value, value
    pvp = true
    Panel.Refresh()
    Frames.AssertText(frame.xpText, "")
    Frames.AssertText(frame.timer, "")
end
xp, remaining = 50, 20
Panel.Refresh()
Frames.AssertSize(frame, 395, 135)
Frames.AssertText(frame.timer, "20")
assert(frame:GetHeight() + 14 <= bottom:GetHeight() + 28)
C_PetBattles.ShouldShowPetSelect = function() return false end
C_PetBattles.GetAbilityInfo = function() return 1, "test", 134400, 0 end
dofile(root .. "/BattleBuddy/EnemyAbilities.lua")
BattleBuddyEnemyAbilities.Refresh()
Frames.AssertAnchor(BattleBuddyEnemyAbilities.frame, 1, { "BOTTOM", bottom, "TOP", 0, 28 })
Frames.AssertShown(BattleBuddyEnemyAbilities.frame, true)
remaining = 19
bottom.TurnTimer.TimerText:SetText("native timer")
Frames.AssertText(frame.timer, "19")
assert(executions == 3)
local modifier, suppressed = 1.5, false
C_PetBattles.GetPetType = function() return 5 end
C_PetBattles.GetAbilityInfo = function() return 1, nil, nil, nil, nil, nil, 8, suppressed end
C_PetBattles.GetAttackModifier = function() return modifier end
Panel.Refresh()
assert(frame.hints[1]:IsShown() and frame.hints[1].gradient[2][2] == 1)
modifier = 0.5
Panel.Refresh()
assert(frame.hints[1]:IsShown() and frame.hints[1].gradient[2][1] == 1)
for _, value in ipairs({ 1, secret, -1, math.huge }) do
    modifier = value
    Panel.Refresh()
    assert(not frame.hints[1]:IsShown())
end
modifier, suppressed = 1.5, true
Panel.Refresh()
assert(not frame.hints[1]:IsShown())
suppressed = secret
Panel.Refresh()
assert(not frame.hints[1]:IsShown())
keys.BATTLEBUDDY_AUTOBATTLE = "F9"
Event("UPDATE_BINDINGS")
assert(frame.key:GetText() == "F9")
Frames.Fire(frame.bind, "OnClick", "LeftButton")
assert(frame.capture:IsShown())
Frames.Fire(frame.capture, "OnKeyDown", "ESCAPE")
assert(not frame.capture:IsShown())
Frames.Fire(frame.bind, "OnClick", "LeftButton")
Frames.Fire(frame.capture, "OnKeyDown", "F8")
assert(keys.BATTLEBUDDY_AUTOBATTLE == nil)
assert(overrides[Panel.events]["CTRL-SHIFT-F8"] == "BATTLEBUDDY_AUTOBATTLE")
assert(frame.key:GetText() == "CTRL-SHIFT-F8")
Panel.Binding("down")
assert(executions == 3)
Panel.Binding("up")
Frames.Fire(frame.bind, "OnClick", "RightButton")
assert(frame.key:GetText() == "" and keys.BATTLEBUDDY_AUTOBATTLE == nil)
assert(next(overrides[Panel.events]) == nil)
keys.BATTLEBUDDY_AUTOBATTLE = "F9"
local physicallyDown = true
IsKeyDown = function() return physicallyDown end
Event("UPDATE_BINDINGS")
Panel.Binding("down")
assert(executions == 4)
Event("PET_BATTLE_CLOSE")
Event("PET_BATTLE_OPENING_START")
Panel.Binding("down")
assert(executions == 4)
Event("PET_BATTLE_CLOSE")
physicallyDown = false
Event("PET_BATTLE_OPENING_START")
physicallyDown = true
Panel.Binding("down")
assert(executions == 5)
physicallyDown = false
Panel.Binding("up")
secondKeys.BATTLEBUDDY_AUTOBATTLE = "F10"
IsKeyDown = function(key) return key == "F10" end
Panel.Binding("down")
assert(executions == 6)
for index = 1, 3 do Event("PET_BATTLE_ACTION_SELECTED"); Panel.Binding("down") end
assert(executions == 6)
Panel.Binding("up")
Panel.Binding("down")
assert(executions == 6)
IsKeyDown = function() return false end
Panel.Binding("up")
secondKeys.BATTLEBUDDY_AUTOBATTLE = nil
Frames.Fire(frame, "OnMouseWheel", 1)
assert(BattleBuddyConfig.GetSetting("battlePanelScale") == 101)
Frames.AssertAnchor(frame, 1, { "CENTER", UIParent, "BOTTOMLEFT", 600 / 1.01, 100 / 1.01 })
BattleBuddyConfig.SetSetting("battlePanelScale", 200)
Frames.Fire(frame, "OnMouseWheel", 1)
assert(frame.scale == 2)
BattleBuddyConfig.SetSetting("battlePanelScale", 50)
Frames.Fire(frame, "OnMouseWheel", -1)
assert(frame.scale == 0.5)
assert(frame:GetHeight() * frame.scale + 14 <= bottom:GetHeight() + 28)
combat = true
local scale = frame.scale
Frames.Fire(frame, "OnMouseWheel", 1)
assert(frame.scale == scale)
battle = false
Event("PET_BATTLE_CLOSE")
combat = false
Event("PLAYER_REGEN_ENABLED")
assert(next(overrides[Panel.events]) == nil)
Frames.AssertShown(frame, false)
assert(executions == 6)
BattleBuddyScript = nil
dofile(root .. "/BattleBuddy/Script/Parser.lua")
dofile(root .. "/BattleBuddy/Script/Evaluate.lua")
dofile(root .. "/BattleBuddy/Script/Runtime.lua")
local realActions = 0
C_PetBattles.SkipTurn = function() realActions = realActions + 1 end
C_PetBattles.IsSkipAvailable = function() return true end
BattleBuddyTeams = { GetTeam = function() return { script = "standby" } end }
assert(BattleBuddyScript.SetLoadedTeam({}, "test"))
battle = true
Event("PET_BATTLE_OPENING_START")
Frames.Fire(frame.auto, "OnClick", "LeftButton")
assert(realActions == 1)
Panel.Refresh()
Event("PET_BATTLE_PET_ROUND_PLAYBACK_COMPLETE")
assert(realActions == 1)
print("battle_panel_test: ok")
