local root = (... or ".")
local Frames = dofile(root .. "/tests/support/frames.lua")
local function Equal(a, b) assert(a == b, tostring(a) .. " ~= " .. tostring(b)) end
local originalCreate = Frames.Create
Frames.Create = function(...)
    local f = originalCreate(...)
    function f:SetAlpha(v) self.alpha = v end
    function f:SetAtlas(v) self.atlas = v end
    function f:SetTexCoord(...) self.texCoord = { ... } end
    function f:SetVertexColor(...) self.tint = { ... } end
    function f:SetTextColor(...) self.textColor = { ... } end
    function f:SetDesaturated(v) self.desaturated = v end
    function f:SetEnabled(v) self.enabled = v end
    function f:SetNormalTexture(v) self.normalTexture = v end
    function f:SetHighlightTexture(v) self.highlightTexture = v end
    function f:RegisterForDrag(...) self.drags = { ... } end
    function f:RegisterForClicks(...) self.clicks = { ... } end
    function f:SetDisplayInfo(v) self.display = v end
    function f:ClearModel() self.display = nil end
    return f
end
CreateFrame = Frames.Create
UIParent = CreateFrame("Frame")
local secret = setmetatable({}, { __tostring = function() error("secret formatted") end })
issecretvalue = function(v) return rawequal(v, secret) end
canaccessvalue = function(v) return not rawequal(v, secret) end
local combat, battle, journalLocked, queued = false, false, false, false
local sets, choices, clears = 0, 0, 0
local current = { { "BattlePet-1", 101, 102, 103, false },
    { "BattlePet-2", 101, 102, 103, false }, { nil, nil, nil, nil, false } }
local health, petName, species, petIcon = 50, "My Pet", 1, 132199
local cursor, cursorPet, targetName
InCombatLockdown = function() return combat end
C_PetBattles = { IsInBattle = function() return battle end,
    GetPVPMatchmakingInfo = function() return queued and "queued" or nil end }
C_PetJournal = {
    GetPetLoadOutInfo = function(slot) return unpack(current[slot], 1, 5) end,
    GetPetInfoByPetID = function(id)
        if not id:match("^BattlePet%-%d+$") then return end
        return species, petName, 12, 20, 100, 200, false, "Species", petIcon, 8, 400, "Source", "Description", false, true, true, false
    end,
    GetPetStats = function() return health, 100, 20, 30, 3 end,
    GetPetAbilityList = function() return { 101, 102, 103, 104, 105, 106 }, { 1, 2, 4, 10, 15, 20 } end,
    GetPetAbilityInfo = function(id) return "Ability", id + 1000 end,
    PetIsSlotted = function() return false end,
    PetIsRevoked = function() return false end,
    PetIsLockedForConvert = function() return false end,
    IsJournalUnlocked = function() return not journalLocked end,
    SetPetLoadOutInfo = function(slot, id) sets = sets + 1; current[slot][1] = id end,
    SetAbility = function(slot, tier, id) choices = choices + 1; current[slot][tier + 1] = id end,
}
GetCursorInfo = function() return cursor, cursorPet end
ClearCursor = function() clears = clears + 1; cursor = nil end
UnitExists = function() return targetName ~= nil end
UnitIsPlayer = function() return false end
UnitName = function() return targetName end
UnitGUID = function() return "Creature-0-0-0-0-123-0" end
local views = {}
BattleBuddyDev = { RegisterView = function(name, show, hide, shown)
    views[name] = { show = show, hide = hide, shown = shown }
end }
local host = CreateFrame("Frame", nil, UIParent)
for _, key in ipairs({ "target", "team", "loadout" }) do
    host[key] = CreateFrame("Frame", nil, host)
    host[key].label = host[key]:CreateFontString()
end
BattleBuddyWindow = { frame = host, Show = function() host:Show(); return true end,
    Hide = function() host:Hide() end, IsActive = function() return host:IsShown() end }
SetCollectionsJournalShown = function() end
COLLECTIONS_JOURNAL_TAB_INDEX_PETS = 2
hooksecurefunc = function(object, key, after)
    local before = object[key]
    object[key] = function(...) local result = before(...); after(...); return result end
end
dofile(root .. "/BattleBuddy/Compatibility.lua")
dofile(root .. "/BattleBuddy/Store.lua")
dofile(root .. "/BattleBuddy/Teams.lua")
BattleBuddyScript = {}
dofile(root .. "/BattleBuddy/Script/Runtime.lua")
dofile(root .. "/BattleBuddy/Loadout.lua")
local L = BattleBuddyLoadout
L.Mount(host)
Frames.Fire(L.events, "OnEvent", "PLAYER_ENTERING_WORLD")
local slots = L.slots
for i, slot in ipairs(slots) do
    Frames.AssertSize(slot, 280, 137)
    Frames.AssertAnchor(slot, 1, { "TOPLEFT", host.loadout, "TOPLEFT", 0, -(i - 1) * 139 })
    Frames.AssertSize(slot.pet, 46, 46)
    Frames.AssertAnchor(slot.pet, 1, { "TOPLEFT", slot, "TOPLEFT", 15, -18 })
    Equal(slot.icon:GetParent(), slot.pet)
    Equal(slot.icon.layer, "ARTWORK")
    Frames.AssertSize(slot.icon, 42, 42)
    Frames.AssertAnchor(slot.icon, 1, { "CENTER", slot.pet, "CENTER", 0, 0 })
    Equal(slot.border.layer, "OVERLAY")
    Equal(slot.border.texture, "Interface\\Common\\WhiteIconFrame")
    Frames.AssertSize(slot.border, 46, 46)
    Frames.AssertSize(slot.model, 88, 100)
    Frames.AssertAnchor(slot.model, 1, { "BOTTOMRIGHT", slot, "BOTTOMRIGHT", -1, 1 })
    Frames.AssertSize(slot.family, 77, 77)
    Frames.AssertSize(slot.health, 60, 8)
    Frames.AssertSize(slot.xp, 252, 8)
    Frames.AssertSize(slot.abilityBar, 112, 36)
    Frames.AssertText(slot.breed, "")
    Equal(#slot.abilities, 3)
    for _, button in ipairs(slot.abilities) do Frames.AssertSize(button, 32, 32) end
end
Frames.AssertText(slots[1].name, "My Pet")
Frames.AssertText(slots[1].healthText, "50%")
Frames.AssertText(slots[1].level, "12")
Equal(slots[1].model.display, 200)
Equal(slots[1].icon.texture, 132199)
Equal(slots[2].icon.texture, 132199)
Equal(slots[3].icon.texture, nil)
petName = nil
L.Refresh()
Frames.AssertText(slots[1].name, "Species")
Equal(slots[1].icon.texture, 132199)
petIcon = secret
L.Refresh()
Equal(slots[1].icon.texture, nil)
petName, petIcon = "My Pet", 132199
L.Refresh()
Equal(slots[1].abilities[1].icon.texture, 1101)
Frames.AssertText(slots[3].name, "Empty slot")
Frames.AssertShown(slots[3].model, false)
Frames.AssertText(host.target.name, "No Target")
Frames.AssertShown(host.target.portrait, false)
Frames.AssertShown(host.target.save, false)
Frames.AssertSize(host.target.save, 68, 34)
Frames.AssertAnchor(host.target.save, 1, { "BOTTOMRIGHT", host.target, "BOTTOMRIGHT", -8, 6 })
Frames.AssertText(host.team.name, "Battle Pet Slots")
Equal(sets, 0); Equal(choices, 0)
health = 0
Frames.Fire(L.events, "OnEvent", "PET_JOURNAL_PETS_HEALED")
Frames.AssertText(slots[1].healthText, "Dead")
Frames.AssertShown(slots[1].dead, true)
health = 100
Frames.Fire(L.events, "OnEvent", "PET_JOURNAL_LIST_UPDATE")
Frames.AssertText(slots[1].healthText, "100")
targetName = "Unrecorded NPC"
Frames.Fire(L.events, "OnEvent", "PLAYER_TARGET_CHANGED")
Frames.AssertText(host.target.name, targetName)
Frames.AssertShown(host.target.portrait, true)
Equal(host.target.portrait.texture, "Interface\\Icons\\INV_Misc_QuestionMark")
for _, enemy in ipairs(host.target.enemies) do Frames.AssertShown(enemy, false) end
Frames.AssertShown(host.target.clear, true)
Frames.AssertShown(host.target.save, true)
Frames.Fire(host.target.clear, "OnClick")
Frames.AssertText(host.target.name, "No Target")
L.SetTarget({ name = "Known NPC", enemies = { { icon = 987, level = 25 } } })
Frames.AssertShown(host.target.enemies[1], true)
Equal(host.target.enemies[1].icon.texture, 987)
Frames.Fire(slots[1].abilities[1], "OnClick")
Frames.AssertSize(L.flyout, 44, 81)
Frames.AssertShown(L.flyout, true)
Frames.Fire(L.flyout.alternatives[2], "OnClick")
Equal(choices, 1); Equal(current[1][2], 104)
Frames.AssertShown(L.flyout, false)
local originalAbilitySetter = C_PetJournal.SetAbility
C_PetJournal.SetAbility = function() end
Equal(L.ChooseAbility(1, 1, 101), false)
Equal(current[1][2], 104)
C_PetJournal.SetAbility = originalAbilitySetter
Frames.Fire(slots[1].abilities[2], "OnClick")
Frames.Fire(L.flyout.alternatives[2], "OnClick")
Equal(choices, 1)
Equal(L.DropPet(2, "BattlePet-3"), true)
Equal(sets, 1); Equal(current[2][1], "BattlePet-3")
cursor, cursorPet = "battlepet", "BattlePet-4"
Frames.Fire(slots[3].pet, "OnReceiveDrag")
Equal(sets, 2); Equal(clears, 1)
for _, state in ipairs({ "battle", "combat", "journal", "queue", "slot" }) do
    battle, combat, journalLocked, queued = state == "battle", state == "combat", state == "journal", state == "queue"
    current[1][5] = state == "slot"
    L.Refresh()
    if not combat then Frames.AssertShown(slots[1].lock, true) end
    if state == "slot" then Frames.AssertShown(slots[1].abilityBar, false) end
    local beforeSets, beforeChoices = sets, choices
    L.DropPet(1, "BattlePet-5")
    L.ChooseAbility(1, 1, 101)
    cursor, cursorPet = "battlepet", "BattlePet-5"
    Frames.Fire(slots[1].pet, "OnReceiveDrag")
    Equal(sets, beforeSets); Equal(choices, beforeChoices)
    assert(L.message:GetText() ~= "")
    Equal(clears, 1)
end
battle, combat, journalLocked, queued, current[1][5] = false, false, false, false, false
local beforeSets, beforeChoices = sets, choices
L.DropPet(0, "BattlePet-1"); L.DropPet(1, "species:1"); L.ChooseAbility(1, 1, 999)
Equal(sets, beforeSets); Equal(choices, beforeChoices)
local store = BattleBuddyTeams.Initialize()
local team = assert(BattleBuddyTeams.CreateTeam(store, { name = "Own team", pets = { 0 }, script = "standby" }))
assert(BattleBuddyScript.SetLoadedTeam(store, team.teamID))
Frames.AssertText(host.team.name, "Own team")
Equal(host.team.script.hasScript, true)
Frames.AssertShown(slots[1].leveling, true)
local originalSetter = C_PetJournal.SetPetLoadOutInfo
C_PetJournal.SetPetLoadOutInfo = function() end
Equal(L.DropPet(1, "BattlePet-9"), false)
Frames.AssertShown(slots[1].leveling, true)
Equal(current[1][1], "BattlePet-1")
C_PetJournal.SetPetLoadOutInfo = originalSetter
local beforeConversion = sets
C_PetJournal.PetIsLockedForConvert = function() return true end
Equal(L.DropPet(1, "BattlePet-9"), false)
Equal(sets, beforeConversion)
C_PetJournal.PetIsLockedForConvert = function() return false end
L.DropPet(1, "BattlePet-2")
Frames.AssertShown(slots[1].leveling, false)
Equal(BattleBuddyTeams.GetTeam(store, team.teamID).pets[1], 0)
petName, health, species = secret, secret, secret
Frames.Fire(L.events, "OnEvent", "PET_JOURNAL_LIST_UPDATE")
Frames.AssertText(slots[1].name, "Species")
Frames.AssertText(slots[1].healthText, "")
Frames.AssertText(slots[1].breed, "")
Equal(slots[1].abilities[1].icon.texture, nil)
local beforeUnknownSets, beforeUnknownChoices = sets, choices
local originalBattle, originalCombat = C_PetBattles.IsInBattle, InCombatLockdown
C_PetBattles.IsInBattle = function() return secret end
Equal(L.DropPet(1, "BattlePet-1"), false)
L.ChooseAbility(1, 1, 101)
C_PetBattles.IsInBattle = originalBattle
InCombatLockdown = function() return secret end
Equal(L.DropPet(1, "BattlePet-1"), false)
L.ChooseAbility(1, 1, 101)
InCombatLockdown = originalCombat
local originalQueue = C_PetBattles.GetPVPMatchmakingInfo
C_PetBattles.GetPVPMatchmakingInfo = function() return secret end
Equal(L.DropPet(1, "BattlePet-1"), false)
C_PetBattles.GetPVPMatchmakingInfo = originalQueue
Equal(sets, beforeUnknownSets); Equal(choices, beforeUnknownChoices)
L.SetTarget({ name = secret, enemies = secret })
Frames.AssertText(host.target.name, "Unknown target")
for _, event in ipairs({ "PET_JOURNAL_LIST_UPDATE", "PET_JOURNAL_PETS_HEALED", "PET_JOURNAL_PET_DELETED",
    "PLAYER_TARGET_CHANGED", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "PET_BATTLE_OPENING_START", "PET_BATTLE_CLOSE" }) do
    Equal(L.events.events[event], true)
end
Equal(type(views["window-loadout"].show), "function")
Equal(views["window-loadout"].show(), true)
Equal(views["window-loadout"].shown(), true)
views["window-loadout"].hide()
Equal(views["window-loadout"].shown(), false)
for _, f in ipairs({ L.events, L.flyout, slots[1], host }) do Equal(f:GetScript("OnUpdate"), nil) end
print("loadout_test.lua: passed")
