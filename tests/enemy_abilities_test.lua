local root = (... or ".")
local Frames = dofile(root .. "/tests/support/frames.lua")
local create = CreateFrame
CreateFrame = function(...)
    local frame = create(...)
    frame.SetMovable = function(self, value) self.movable = value end
    frame.RegisterForDrag = function() end
    frame.EnableMouseWheel = function() end
    frame.StartMoving = function(self) self.moving = true end
    frame.StopMovingOrSizing = function(self) self.moving = false end
    frame.SetScale = function(self, value) self.scale = value end
    frame.GetEffectiveScale = function(self) return self.scale or 1 end
    frame.GetCenter = function() return 500, 300 end
    return frame
end
local shift, control = false, false
IsShiftKeyDown = function() return shift end
IsControlKeyDown = function() return control end
local secret, restricted = {}, {}
issecretvalue = function(value) return rawequal(value, secret) end
canaccessvalue = function(value) return not rawequal(value, restricted) end
UIParent = CreateFrame("Frame", "UIParent")
PetBattleFrame = CreateFrame("Frame", "PetBattleFrame", UIParent)
PetBattleFrame.BottomFrame = CreateFrame("Frame", nil, PetBattleFrame)
PetBattlePrimaryAbilityTooltip = CreateFrame("Frame", nil, UIParent)
local battle, selection, active, combat = true, false, 1, false
InCombatLockdown = function() return combat end
Enum = { BattlePetOwner = { Enemy = 2 } }
local cooldowns = { { 3, 0, 1 }, { 0, 4, 0 }, { 0, 0, 0 } }
local ids, icons = {}, {}
local reads, tooltipCalls = 0, 0
local lockdown = 0
C_PetBattles = {
    IsInBattle = function() return battle end,
    ShouldShowPetSelect = function() return selection end,
    GetActivePet = function() return active end,
    GetAbilityInfo = function(owner, pet, slot)
        assert(owner == 2)
        return ids[slot] or pet * 10 + slot, "Ability", icons[slot] or 134400, slot == 2 and 3 or secret
    end,
    GetAbilityState = function(owner, pet, slot)
        reads = reads + 1
        return true, cooldowns[pet][slot], lockdown
    end,
    UseAbility = function() error("action dispatched") end,
    ChangePet = function() error("action dispatched") end,
}
C_Timer = { After = function() error("timer scheduled") end }
PetBattleAbilityTooltip_SetAbility = function(owner, pet, slot)
    assert(owner == 2 and pet == active and slot >= 1 and slot <= 3)
    tooltipCalls = tooltipCalls + 1
end
PetBattleAbilityTooltip_Show = function() PetBattlePrimaryAbilityTooltip:Show() end
BattleBuddyDB = { settingOverrides = {} }
dofile(root .. "/BattleBuddy/Config.lua")
dofile(root .. "/BattleBuddy/Compatibility.lua")
dofile(root .. "/BattleBuddy/EnemyAbilities.lua")
dofile(root .. "/BattleBuddy/Dev.lua")
local Bar = BattleBuddyEnemyAbilities
local function Event(event) Frames.Fire(Bar.events, "OnEvent", event) end
Event("PLAYER_LOGIN")
assert(BattleBuddyDev.Views()[1] == "battle-enemy-abilities")
Event("PET_BATTLE_OPENING_DONE")
local frame = Bar.frame
Frames.AssertSize(frame, 138, 42)
Frames.AssertAnchor(frame, 1, { "BOTTOM", PetBattleFrame.BottomFrame, "TOP", 0, 28 })
assert(#frame.icons == 3)
for slot, icon in ipairs(frame.icons) do
    Frames.AssertSize(icon, 42, 42)
    Frames.AssertAnchor(icon, 1, { "LEFT", frame, "LEFT", (slot - 1) * 48, 0 })
    Frames.AssertVisible(icon, true)
    assert(not icon:GetScript("OnClick"))
end
Frames.AssertText(frame.icons[1].cooldown, "3")
Frames.AssertText(frame.icons[2].cooldown, "")
Frames.AssertText(frame.icons[2].maxCooldown, "3")
Frames.AssertText(frame.icons[1].maxCooldown, "")
lockdown = 5
Event("PET_BATTLE_ACTION_SELECTED")
Frames.AssertText(frame.icons[1].cooldown, "5")
lockdown = secret
Event("PET_BATTLE_ACTION_SELECTED")
Frames.AssertText(frame.icons[1].cooldown, "")
lockdown = 0
Event("PET_BATTLE_ACTION_SELECTED")
Frames.Fire(frame.icons[1], "OnEnter")
assert(tooltipCalls == 1)
Frames.Fire(frame.icons[1], "OnLeave")
Frames.AssertShown(PetBattlePrimaryAbilityTooltip, false)
local tooltip = PetBattleAbilityTooltip_SetAbility
PetBattleAbilityTooltip_SetAbility = function() error("restricted tooltip") end
Frames.Fire(frame.icons[1], "OnEnter")
Frames.AssertShown(PetBattlePrimaryAbilityTooltip, false)
PetBattleAbilityTooltip_SetAbility = nil
Frames.Fire(frame.icons[1], "OnEnter")
Frames.AssertShown(PetBattlePrimaryAbilityTooltip, false)
PetBattleAbilityTooltip_SetAbility = tooltip
active = 2
Event("PET_BATTLE_PET_CHANGED")
Frames.AssertText(frame.icons[2].cooldown, "4")
cooldowns[1][1], cooldowns[2][2] = 2, 3
Event("PET_BATTLE_PET_ROUND_PLAYBACK_COMPLETE")
active = 1
Event("PET_BATTLE_PET_CHANGED")
Frames.AssertText(frame.icons[1].cooldown, "2")
for _, value in ipairs({ secret, restricted, -1, 1.5, math.huge, "3", false }) do
    cooldowns[1][1] = value
    Event("PET_BATTLE_PET_ROUND_PLAYBACK_COMPLETE")
    Frames.AssertText(frame.icons[1].cooldown, "")
end
cooldowns[1][1] = nil
Event("PET_BATTLE_PET_CHANGED")
Frames.AssertText(frame.icons[1].cooldown, "")
for _, value in ipairs({ secret, restricted, 0, 4, "1" }) do
    active = value
    Event("PET_BATTLE_PET_CHANGED")
    Frames.AssertShown(frame, false)
end
active = 1
ids[1], icons[2] = secret, secret
Event("PET_BATTLE_OVERRIDE_ABILITY")
Frames.AssertShown(frame.icons[1], false)
assert(frame.icons[2].texture.texture == 134400)
ids, icons = {}, {}
selection = true
Event("PET_BATTLE_HEALTH_CHANGED")
Frames.AssertShown(frame, false)
selection = secret
Event("PET_BATTLE_PET_CHANGED")
Frames.AssertShown(frame, false)
selection = false
battle = secret
Event("PET_BATTLE_PET_CHANGED")
Frames.AssertShown(frame, false)
battle = true
BattleBuddyConfig.SetSetting("enemyAbilitySize", 50)
BattleBuddyConfig.SetSetting("enemyAbilitySpacing", 10)
BattleBuddyConfig.SetSetting("enemyAbilityFont", "Fonts\\ARIALN.TTF")
BattleBuddyConfig.SetSetting("enemyAbilityFontSize", 20)
Event("PET_BATTLE_PET_CHANGED")
Frames.AssertSize(frame, 170, 50)
assert(frame.icons[1].cooldown.font[1] == "Fonts\\ARIALN.TTF")
assert(frame.icons[1].cooldown.font[2] == 20)
BattleBuddyDB.settingOverrides.enemyAbilitySize = secret
BattleBuddyDB.settingOverrides.enemyAbilitySpacing = -10
Event("PET_BATTLE_PET_CHANGED")
Frames.AssertSize(frame, 138, 42)
local count = reads
assert(not Bar.events:GetScript("OnUpdate"))
Event("UNRELATED_EVENT")
assert(reads == count)
local stateAPI = C_PetBattles.GetAbilityState
C_PetBattles.GetAbilityState = function() error("unavailable") end
Event("PET_BATTLE_PET_CHANGED")
Frames.AssertText(frame.icons[1].cooldown, "")
C_PetBattles.GetAbilityState = nil
Event("PET_BATTLE_PET_CHANGED")
Frames.AssertText(frame.icons[1].cooldown, "")
C_PetBattles.GetAbilityState = stateAPI
Event("PET_BATTLE_CLOSE")
Frames.AssertShown(frame, false)
Event("PET_BATTLE_AURA_CHANGED")
Frames.AssertShown(frame, false)
Event("PET_BATTLE_OPENING_DONE")
Frames.AssertShown(frame, true)
Frames.Fire(frame.icons[1], "OnDragStart")
assert(not frame.moving)
shift = true
Frames.Fire(frame.icons[1], "OnDragStart")
assert(frame.moving)
Frames.Fire(frame.icons[1], "OnDragStop")
assert(not frame.moving and BattleBuddyConfig.GetSetting("enemyAbilityMoved"))
Frames.AssertAnchor(frame, 1, { "CENTER", UIParent, "BOTTOMLEFT", 500, 300 })
control = true
Frames.Fire(frame.icons[1], "OnMouseWheel", 1)
assert(BattleBuddyConfig.GetSetting("enemyAbilityScale") == 101)
combat = true
Frames.Fire(frame.icons[1], "OnMouseWheel", 1)
assert(BattleBuddyConfig.GetSetting("enemyAbilityScale") == 101)
combat = false
BattleBuddyConfig.SetSetting("enemyAbilityScale", 200)
Frames.Fire(frame.icons[1], "OnMouseWheel", 1)
assert(BattleBuddyConfig.GetSetting("enemyAbilityScale") == 200)
BattleBuddyConfig.SetSetting("enemyAbilityScale", 50)
Frames.Fire(frame.icons[1], "OnMouseWheel", -1)
assert(BattleBuddyConfig.GetSetting("enemyAbilityScale") == 50)
Event("PET_BATTLE_PET_CHANGED")
assert(frame.scale == 0.5)
battle = false
assert(Bar.ShowPreview())
Frames.AssertShown(Bar.preview, true)
Frames.AssertText(Bar.preview.icons[1].cooldown, "2")
Event("PET_BATTLE_CLOSE")
Frames.AssertShown(Bar.preview, false)
assert(Bar.ShowPreview())
Bar.HidePreview()
Frames.AssertShown(Bar.preview, false)
combat = true
assert(not Bar.ShowPreview())
Frames.Reset()
print("enemy_abilities_test: passed")
