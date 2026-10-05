local sourceRoot = (... or ".")

local function AssertEqual(actual, expected)
    if actual ~= expected then
        error(("expected %s, got %s"):format(tostring(expected), tostring(actual)), 2)
    end
end

local Frames = dofile(sourceRoot .. "/tests/support/frames.lua")
Frames.Reset()
Frames.Install()
local combat, queued, starts, stops, attributes = false, false, 0, 0, 0
local secureExecution = false
local counts = { [86143] = 7, [98112] = 0, [98114] = 4, [116421] = 2, [116429] = 5, [92677] = 1, [98715] = 6 }
local petType = 3
local originalCreate = Frames.Create
local function HasSecureChild(frame)
    if frame.template and frame.template:find("Secure") then return true end
    for _, child in ipairs(frame.children) do
        if HasSecureChild(child) then return true end
    end
    return false
end
local function AssertMutable(frame)
    if combat and not secureExecution and HasSecureChild(frame) then error("protected frame mutation in combat") end
end
local function Enhance(frame)
    frame.alpha, frame.enabled, frame.checked = 1, true, false
    function frame:SetAlpha(value) self.alpha = value end
    function frame:GetAlpha() return self.alpha end
    function frame:GetObjectType() return self.frameType end
    function frame:IsObjectType(kind) return self.frameType == kind end
    function frame:GetRegions()
        local regions = {}
        for _, child in ipairs(self.children) do
            if child.frameType == "Texture" or child.frameType == "FontString" then regions[#regions + 1] = child end
        end
        return unpack(regions)
    end
    function frame:SetEnabled(value) self.enabled = not not value end
    function frame:Enable() self.enabled = true end
    function frame:Disable() self.enabled = false end
    function frame:IsEnabled() return self.enabled end
    function frame:SetChecked(value) self.checked = not not value end
    function frame:GetChecked() return self.checked end
    function frame:SetText(value) self.text = tostring(value) end
    function frame:SetAttribute(key, value)
        AssertEqual(combat, false)
        attributes = attributes + 1
        self.attributes = self.attributes or {}
        self.attributes[key] = value
    end
    function frame:GetAttribute(key) return self.attributes and self.attributes[key] end
    function frame:SetFrameRef(key, value)
        self.frameRefs = self.frameRefs or {}
        self.frameRefs[key] = value
    end
    function frame:GetFrameRef(key) return self.frameRefs and self.frameRefs[key] end
    function frame:CreateMaskTexture(name, layer) return self:CreateTexture(name, layer) end
    function frame:AddMaskTexture(mask) self.mask = mask end
    function frame:SetAtlas(value) self.atlas = value end
    function frame:SetDesaturated(value) self.desaturated = value end
    function frame:SetVertexColor(...) self.vertexColor = { ... } end
    function frame:SetTexCoord(...) self.texCoord = { ... } end
    function frame:SetCooldown(...) self.cooldown = { ... } end
    function frame:Clear() self.cooldown = nil end
    function frame:SetDrawEdge(value) self.drawEdge = value end
    function frame:SetHideCountdownNumbers(value) self.hideCountdown = value end
    function frame:SetNormalTexture(value) self.normalTexture = value end
    function frame:SetPushedTexture(value) self.pushedTexture = value end
    function frame:SetHighlightTexture(value) self.highlightTexture = value end
    function frame:SetDisabledTexture(value) self.disabledTexture = value end
    function frame:SetNormalFontObject(value) self.normalFont = value end
    function frame:SetHighlightFontObject(value) self.highlightFont = value end
    function frame:SetDisabledFontObject(value) self.disabledFont = value end
    function frame:RegisterForClicks(...) self.clicks = { ... } end
    function frame:SetMotionScriptsWhileDisabled(value) self.motionWhenDisabled = value end
    function frame:SetID(value) self.id = value end
    function frame:GetID() return self.id end
    function frame:LockHighlight() self.lockedHighlight = true end
    function frame:UnlockHighlight() self.lockedHighlight = false end
    local show, hide = frame.Show, frame.Hide
    function frame:Show()
        AssertMutable(self)
        local changed = not self.shown
        show(self)
        if changed then Frames.Fire(self, "OnShow") end
    end
    function frame:Hide()
        AssertMutable(self)
        local changed = self.shown
        hide(self)
        if changed then Frames.Fire(self, "OnHide") end
    end
    function frame:SetShown(value) if value then self:Show() else self:Hide() end end
    local setParent = frame.SetParent
    function frame:SetParent(parent) AssertMutable(self); setParent(self, parent) end
    return frame
end
Frames.Create = function(...) return Enhance(originalCreate(...)) end
CreateFrame = function(kind, name, parent, template)
    local frame = Frames.Create(kind, name, parent, template)
    if template and template:find("CheckButton") then frame.Text = frame:CreateFontString(nil, "OVERLAY") end
    if kind == "DropdownButton" then
        function frame:SetupMenu(generator)
            self:SetScript("OnClick", function() MenuUtil.CreateContextMenu(self, generator) end)
        end
    end
    return frame
end
UIParent = CreateFrame("Frame", "UIParent")
CollectionsJournal = CreateFrame("Frame", "CollectionsJournal", UIParent)
CollectionsJournal:SetFrameLevel(12)
CollectionsJournal.MountsTab = CreateFrame("Button", "CollectionsJournalTab1", CollectionsJournal)
CollectionsJournal.MountsTab:SetSize(80, 32)
PanelTemplates_TabResize = function(tab, _, _, minimum, maximum)
    AssertEqual(minimum, maximum)
    tab:SetWidth(minimum)
end
PanelTemplates_SelectTab = function(tab) tab.nativeSelected = true end
PanelTemplates_DeselectTab = function(tab) tab.nativeSelected = false end
issecretvalue = function() return false end
canaccessvalue = function() return true end
dofile(sourceRoot .. "/BattleBuddy/Compatibility.lua")
GetTime = function() return 25 end
local menuEntries
MenuUtil = { CreateContextMenu = function(_, generator)
    menuEntries = {}
    generator(nil, { CreateRadio = function(_, label, selected, pick)
        menuEntries[#menuEntries + 1] = { label = label, selected = selected, pick = pick }
    end })
end }
CollectionsJournal.NineSlice = CreateFrame("Frame", nil, CollectionsJournal)
CollectionsJournal.BorderFrame = CreateFrame("Frame", nil, CollectionsJournal)
CollectionsJournal.NineSlice:SetAlpha(0.7)
CollectionsJournal.BorderFrame:SetAlpha(0.6)
local backdrop = CollectionsJournal:CreateTexture(nil, "BACKGROUND")
backdrop:SetAlpha(0.8)
PetJournal = CreateFrame("Frame", "PetJournal", CollectionsJournal)
PetJournalSummonButton = CreateFrame("Button", "PetJournalSummonButton", PetJournal)
PetJournal:Hide()
InCombatLockdown = function() return combat end
local stateDrivers = {}
RegisterStateDriver = function(frame, state, condition)
    AssertEqual(state, "combat")
    AssertEqual(condition, "[combat] combat; peace")
    stateDrivers[#stateDrivers + 1] = frame
end
hooksecurefunc = function(object, method, callback)
    local original = object[method]
    object[method] = function(...)
        local result = original(...)
        callback(...)
        return result
    end
end
HideUIPanel = function(frame) frame:Hide() end
C_PetJournal = {
    GetNumPets = function() return 150, 123 end,
    GetSummonedPetGUID = function() return "pet-guid" end,
    GetPetInfoByPetID = function() return 1, "Name", 25, 0, 0, 100, false, "Pet", 1, petType end,
}
C_Item = {
    GetItemCount = function(id) return counts[id] or 0 end,
    GetItemIconByID = function(id) return id + 100000 end,
    GetItemCooldown = function() return 0, 0, 1 end,
}
C_Spell = {
    GetSpellTexture = function() return 12345 end,
    GetSpellCooldown = function() return { startTime = 0, duration = 0, isEnabled = true } end,
    GetSpellInfo = function() return { name = "Revive Battle Pets", iconID = 12345 } end,
}
C_ToyBox = { GetToyInfo = function(id) return id, "Safari Hat", 54321, false end }
PlayerHasToy = function() return true end
GetCategoryAchievementPoints = function(id, all)
    AssertEqual(id, 15117)
    AssertEqual(all, true)
    return 9876
end
local achievementClicks = 0
ToggleAchievementFrame = function() achievementClicks = achievementClicks + 1 end
C_PetBattles = {
    GetPVPMatchmakingInfo = function() return queued and "queued" or nil end,
    StartPVPMatchmaking = function() starts = starts + 1 end,
    StopPVPMatchmaking = function() stops = stops + 1 end,
}
local loadCollections
EventUtil = { ContinueOnAddOnLoaded = function(name, callback)
    AssertEqual(name, "Blizzard_Collections")
    loadCollections = callback
end }
local views = {}
BattleBuddyDev = nil
COLLECTIONS_JOURNAL_TAB_INDEX_PETS = 2
SetCollectionsJournalShown = function(shown, tab)
    AssertEqual(shown, true)
    AssertEqual(tab, 2)
    CollectionsJournal:Show()
    PetJournal:Show()
end
BattleBuddyDB = { settingOverrides = {} }
dofile(sourceRoot .. "/BattleBuddy/Config.lua")
AssertEqual(BattleBuddyConfig.GetSetting("journalWindow"), true)
AssertEqual(BattleBuddyConfig.SetSetting("journalWindow", false), true)
AssertEqual(BattleBuddyDB.settingOverrides.journalWindow, false)
AssertEqual(BattleBuddyConfig.SetSetting("journalWindow", true), true)
AssertEqual(BattleBuddyDB.settingOverrides.journalWindow, nil)
dofile(sourceRoot .. "/BattleBuddy/Window.lua")
loadCollections()
local Window = BattleBuddyWindow
AssertEqual(next(views), nil)
BattleBuddyDev = { RegisterView = function(name, show, hide, isShown)
    AssertEqual(type(show), "function")
    AssertEqual(type(hide), "function")
    AssertEqual(type(isShown), "function")
    views[name] = { show = show, hide = hide, isShown = isShown }
end }
Frames.Fire(Window.events, "OnEvent", "ADDON_LOADED", "BattleBuddy")
PetJournal:Show()
AssertEqual(Window.IsActive(), true)
Frames.AssertShown(PetJournal, false)
local frame = Window.frame
Frames.AssertSize(frame, 854, 621)
AssertEqual(frame:GetParent(), CollectionsJournal)
AssertEqual(frame:GetFrameLevel(), 612)
AssertEqual(frame:GetNumPoints(), 1)
Frames.AssertAnchor(frame, 1, { "BOTTOMLEFT", CollectionsJournal, "BOTTOMLEFT", -10, -5 })
AssertEqual(frame.mouseEnabled, false)
Frames.AssertSize(frame.canvas, 844, 535)
Frames.AssertAnchor(frame.canvas, 1, { "TOPLEFT", frame, "TOPLEFT", 5, -58 })
AssertEqual(frame.title:GetHeight(), 24)
Frames.AssertAnchor(frame.title, 1, { "TOPLEFT", frame, "TOPLEFT", 0, 0 })
Frames.AssertAnchor(frame.title, 2, { "TOPRIGHT", frame, "TOPRIGHT", 0, 0 })
Frames.AssertAnchor(frame.toolbar, 1, { "TOPLEFT", frame.canvas, "TOPLEFT", 0, 34 })
Frames.AssertAnchor(frame.toolbar, 2, { "BOTTOMRIGHT", frame.canvas, "TOPRIGHT", 0, 2 })
Frames.AssertAnchor(frame.bottom, 1, { "TOPLEFT", frame.canvas, "BOTTOMLEFT", 0, -2 })
Frames.AssertAnchor(frame.bottom, 2, { "BOTTOMRIGHT", frame.canvas, "BOTTOMRIGHT", 0, -24 })
Frames.AssertAnchor(frame.tabs, 1, { "TOPLEFT", CollectionsJournal.MountsTab, "TOPLEFT", 565, 0 })
Frames.AssertAnchor(frame.tabs, 2, { "BOTTOMLEFT", CollectionsJournal.MountsTab, "BOTTOMLEFT", 565, 0 })
Frames.AssertAnchor(frame.pets, 1, { "TOPLEFT", frame.canvas, "TOPLEFT", 0, 0 })
Frames.AssertAnchor(frame.pets, 2, { "BOTTOMRIGHT", frame.canvas, "BOTTOMLEFT", 280, 0 })
Frames.AssertAnchor(frame.panel, 1, { "TOPLEFT", frame.canvas, "TOPRIGHT", -280, 0 })
Frames.AssertAnchor(frame.panel, 2, { "BOTTOMRIGHT", frame.canvas, "BOTTOMRIGHT", 0, 0 })
Frames.AssertAnchor(frame.target, 1, { "TOPLEFT", frame.pets, "TOPRIGHT", 2, 0 })
Frames.AssertAnchor(frame.target, 2, { "BOTTOMRIGHT", frame.panel, "TOPLEFT", -2, -75 })
Frames.AssertAnchor(frame.team, 1, { "TOPLEFT", frame.target, "BOTTOMLEFT", 0, -2 })
Frames.AssertAnchor(frame.team, 2, { "BOTTOMRIGHT", frame.target, "BOTTOMRIGHT", 0, -28 })
Frames.AssertAnchor(frame.loadout, 1, { "TOPLEFT", frame.team, "BOTTOMLEFT", 0, -2 })
Frames.AssertAnchor(frame.loadout, 2, { "BOTTOMRIGHT", frame.canvas, "BOTTOMRIGHT", -282, 0 })
Frames.AssertText(frame.target.label, "Target")
Frames.AssertText(frame.team.label, "Team")
Frames.AssertText(frame.loadout.label, "Loadout")
Frames.AssertText(frame.toolbar.total, "Total Pets |cffffffff123")
Frames.AssertText(frame.toolbar.achievement.text, "9876")
Frames.Fire(frame.toolbar.achievement, "OnClick")
AssertEqual(achievementClicks, 1)
local buttons = frame.toolbar.buttons
AssertEqual(#buttons, 10)
for index, button in ipairs(buttons) do
    Frames.AssertSize(button, 32, 32)
    if index == 10 then
        Frames.AssertAnchor(button, 1, { "RIGHT", frame.toolbar, "RIGHT", 0, 0 })
    else
        Frames.AssertAnchor(button, 1, { "RIGHT", buttons[index + 1], "LEFT", 0, 0 })
    end
    if index <= 6 then AssertEqual(button.template, "SecureActionButtonTemplate") end
    if index >= 7 then AssertEqual(button:IsEnabled(), false) end
end
AssertEqual(buttons[1]:GetAttribute("type"), "spell")
AssertEqual(buttons[1]:GetAttribute("spell"), 125439)
AssertEqual(buttons[2]:GetAttribute("type"), "toy")
AssertEqual(buttons[2]:GetAttribute("toy"), 92738)
AssertEqual(buttons[3]:GetAttribute("item"), "item:98112")
AssertEqual(buttons[4]:GetAttribute("item"), "item:98114")
AssertEqual(buttons[5]:GetAttribute("item"), "item:116421")
AssertEqual(buttons[6]:GetAttribute("item"), "item:92677")
Frames.AssertText(buttons[3].count, "0")
AssertEqual(buttons[3].icon.desaturated, true)
AssertEqual(BattleBuddyConfig.GetSetting("healOrder")[1], "revive")
AssertEqual(frame.toolbar.healArrow.frameType, "DropdownButton")
AssertEqual(frame.toolbar.healArrow.template, "WowStyle1ArrowDropdownTemplate")
local readyCooldown = C_Spell.GetSpellCooldown
C_Spell.GetSpellCooldown = function() return { startTime = 20, duration = 40, isEnabled = true } end
Frames.Fire(Window.events, "OnEvent", "SPELL_UPDATE_COOLDOWN")
AssertEqual(buttons[1]:GetAttribute("item"), "item:86143")
Frames.Fire(frame.toolbar.healArrow, "OnClick")
AssertEqual(menuEntries[1].label, "Revive Battle Pets — 35s")
C_Spell.GetSpellCooldown = readyCooldown
Frames.Fire(Window.events, "OnEvent", "SPELL_UPDATE_COOLDOWN")
AssertEqual(buttons[1]:GetAttribute("spell"), 125439)
BattleBuddyConfig.SetSetting("healOrder", { "bandage", "revive" })
Frames.Fire(Window.events, "OnEvent", "BAG_UPDATE_DELAYED")
AssertEqual(buttons[1]:GetAttribute("item"), "item:86143")
counts[86143] = 0
Frames.Fire(Window.events, "OnEvent", "BAG_UPDATE_DELAYED")
AssertEqual(buttons[1]:GetAttribute("spell"), 125439)
counts[86143] = 7
BattleBuddyConfig.SetSetting("healOrder", { "revive", "bandage" })
Frames.Fire(frame.toolbar.healArrow, "OnClick")
AssertEqual(#menuEntries, 2)
AssertEqual(menuEntries[1].label, "Revive Battle Pets — Ready")
AssertEqual(menuEntries[2].label, "Battle Pet Bandage (7) — Ready")
menuEntries[2].pick()
AssertEqual(buttons[1]:GetAttribute("type"), "item")
AssertEqual(buttons[1]:GetAttribute("item"), "item:86143")
AssertEqual(buttons[1]:GetAttribute("spell"), nil)
Frames.AssertText(buttons[1].count, "7")
combat = true
local beforePick = attributes
menuEntries[1].pick()
AssertEqual(attributes, beforePick)
AssertEqual(buttons[1]:GetAttribute("type"), "item")
combat = false
Frames.Fire(Window.events, "OnEvent", "PLAYER_REGEN_ENABLED")
AssertEqual(buttons[1]:GetAttribute("spell"), 125439)
AssertEqual(buttons[1]:GetAttribute("item"), nil)
Window.Show()
BattleBuddyConfig.SetSetting("healOrder", { "bandage", "revive" })
Frames.Fire(frame.toolbar.healArrow, "OnClick")
AssertEqual(menuEntries[1].label, "Battle Pet Bandage (7) — Ready")
AssertEqual(menuEntries[2].selected(), true)
BattleBuddyConfig.SetSetting("healOrder", { "revive", "bandage" })
local originalItemCooldown, originalSpellCooldown = C_Item.GetItemCooldown, C_Spell.GetSpellCooldown
C_Item.GetItemCooldown = function() return 10, 30, 1 end
C_Spell.GetSpellCooldown = function() return { startTime = 20, duration = 40, isEnabled = true } end
Frames.Fire(Window.events, "OnEvent", "SPELL_UPDATE_COOLDOWN")
AssertEqual(buttons[1].cooldown.cooldown[1], 20)
AssertEqual(buttons[1].cooldown.cooldown[2], 40)
AssertEqual(buttons[2].cooldown.cooldown[1], 10)
AssertEqual(buttons[2].cooldown.cooldown[2], 30)
C_Item.GetItemCooldown = function() error("unavailable item cooldown") end
C_Spell.GetSpellCooldown = function() error("unavailable spell cooldown") end
Frames.Fire(Window.events, "OnEvent", "SPELL_UPDATE_COOLDOWN")
AssertEqual(buttons[1].cooldown.cooldown, nil)
AssertEqual(buttons[2].cooldown.cooldown, nil)
local secret = setmetatable({}, {
    __lt = function() error("secret compared") end,
    __le = function() error("secret compared") end,
    __tostring = function() error("secret formatted") end,
    __concat = function() error("secret concatenated") end,
})
issecretvalue = function(value) return rawequal(value, secret) end
for _, field in ipairs({ "startTime", "duration", "isEnabled" }) do
    C_Spell.GetSpellCooldown = function()
        local data = { startTime = 20, duration = 40, isEnabled = true }
        data[field] = secret
        return data
    end
    Frames.Fire(Window.events, "OnEvent", "SPELL_UPDATE_COOLDOWN")
    AssertEqual(buttons[1].cooldown.cooldown, nil)
end
C_Item.GetItemCooldown = function() return secret, 30, 1 end
Frames.Fire(Window.events, "OnEvent", "SPELL_UPDATE_COOLDOWN")
AssertEqual(buttons[2].cooldown.cooldown, nil)
C_Item.GetItemCooldown, C_Spell.GetSpellCooldown = originalItemCooldown, originalSpellCooldown
counts[116421], counts[92677] = 0, 0
Frames.Fire(Window.events, "OnEvent", "BAG_UPDATE_DELAYED")
AssertEqual(buttons[5]:GetAttribute("item"), "item:116429")
AssertEqual(buttons[6]:GetAttribute("item"), "item:98715")
counts[116421], counts[92677], counts[116429], counts[98715] = 2, 2, 1, 1
C_PetJournal.GetSummonedPetGUID = function() return nil end
Frames.Fire(Window.events, "OnEvent", "PET_JOURNAL_LIST_UPDATE")
AssertEqual(buttons[5]:GetAttribute("item"), "item:116429")
AssertEqual(buttons[6]:GetAttribute("item"), "item:98715")
for _, event in ipairs({ "BAG_UPDATE_DELAYED", "PET_JOURNAL_LIST_UPDATE", "ACHIEVEMENT_EARNED", "PET_BATTLE_QUEUE_STATUS", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
    AssertEqual(Window.events.events[event], true)
end
counts[116429], counts[98715], counts[127755], counts[92741] = 0, 0, 2, 2
Frames.Fire(Window.events, "OnEvent", "PET_JOURNAL_LIST_UPDATE")
AssertEqual(buttons[5]:GetAttribute("item"), "item:127755")
AssertEqual(buttons[6]:GetAttribute("item"), "item:92741")
counts[127755], counts[92741] = 0, 0
Frames.Fire(Window.events, "OnEvent", "BAG_UPDATE_DELAYED")
AssertEqual(buttons[5]:GetAttribute("item"), "item:116429")
AssertEqual(buttons[6]:GetAttribute("item"), "item:98715")
local stable = { frame.pets, frame.target, frame.team, frame.loadout }
local names = { "Teams", "Targets", "Queue", "Options" }
for index, name in ipairs(names) do
    local tab = frame.tabButtons[index]
    AssertEqual(tab.template, "PanelTabButtonTemplate")
    Frames.AssertSize(tab, 64, 32)
    Frames.AssertText(tab, name)
    Frames.AssertAnchor(tab, 1, { "TOPLEFT", frame.tabs, "TOPLEFT", (index - 1) * 64, 0 })
    Frames.Fire(tab, "OnClick")
    AssertEqual(Window.view, name:lower())
    AssertEqual(BattleBuddyDB.windowView, name:lower())
    Frames.AssertText(frame.panel.label, name)
    AssertEqual(tab.selected, true)
    AssertEqual(tab.nativeSelected, true)
    for other, otherTab in ipairs(frame.tabButtons) do AssertEqual(otherTab.selected, other == index) end
end
AssertEqual(frame.pets, stable[1])
AssertEqual(frame.target, stable[2])
AssertEqual(frame.team, stable[3])
AssertEqual(frame.loadout, stable[4])
Window.SelectView("invalid")
AssertEqual(Window.view, "options")
AssertEqual(frame.bottom.summon:GetWidth(), 156)
AssertEqual(frame.bottom.save:GetWidth(), 136)
AssertEqual(frame.bottom.saveAs:GetWidth(), 136)
AssertEqual(frame.bottom.findBattle:GetWidth(), 136)
Frames.AssertAnchor(frame.bottom.findBattle, 1, { "RIGHT", frame.bottom, "RIGHT", 0, 0 })
Frames.AssertAnchor(frame.bottom.saveAs, 1, { "RIGHT", frame.bottom.findBattle, "LEFT", -2, 0 })
Frames.AssertAnchor(frame.bottom.save, 1, { "RIGHT", frame.bottom.saveAs, "LEFT", -2, 0 })
AssertEqual(frame.bottom.summon:IsEnabled(), false)
AssertEqual(frame.bottom.save:IsEnabled(), false)
AssertEqual(frame.bottom.saveAs:IsEnabled(), false)
Frames.AssertAnchor(frame.bottom.toggle, 1, { "LEFT", frame.bottom.summon, "RIGHT", 0, 0 })
AssertEqual(starts, 0)
AssertEqual(stops, 0)
Frames.AssertText(frame.bottom.findBattle, "Find Battle")
Frames.Fire(frame.bottom.findBattle, "OnClick")
AssertEqual(starts, 1)
queued = true
Frames.Fire(Window.events, "OnEvent", "PET_BATTLE_QUEUE_STATUS")
Frames.AssertText(frame.bottom.findBattle, "Leave Queue")
Frames.Fire(frame.bottom.findBattle, "OnClick")
AssertEqual(starts, 1)
AssertEqual(stops, 1)
AssertEqual(backdrop:GetAlpha(), 0)
AssertEqual(CollectionsJournal.NineSlice:GetAlpha(), 0)
frame.bottom.toggle:SetChecked(false)
Frames.Fire(frame.bottom.toggle, "OnClick")
AssertEqual(Window.IsActive(), false)
AssertEqual(frame:GetParent(), UIParent)
Frames.AssertShown(PetJournal, true)
AssertEqual(BattleBuddyDB.settingOverrides.journalWindow, false)
AssertEqual(backdrop:GetAlpha(), 0.8)
AssertEqual(CollectionsJournal.NineSlice:GetAlpha(), 0.7)
AssertEqual(CollectionsJournal.BorderFrame:GetAlpha(), 0.6)
PetJournal:Hide()
PetJournal:Show()
AssertEqual(Window.IsActive(), false)
Frames.AssertAnchor(Window.toggle, 1, { "LEFT", PetJournalSummonButton, "RIGHT", 0, -1 })
Window.toggle:SetChecked(true)
Frames.Fire(Window.toggle, "OnClick")
AssertEqual(Window.IsActive(), true)
AssertEqual(BattleBuddyDB.settingOverrides.journalWindow, nil)
PetJournal:Hide()
AssertEqual(Window.IsActive(), false)
PetJournal:SetShown(true)
AssertEqual(Window.IsActive(), true)
PetJournal:SetShown(false)
AssertEqual(Window.IsActive(), false)
PetJournal:Show()
AssertEqual(Window.IsActive(), true)
CollectionsJournal:Hide()
AssertEqual(Window.IsActive(), false)
AssertEqual(backdrop:GetAlpha(), 0.8)
CollectionsJournal:Show()
AssertEqual(Window.IsActive(), true)
combat = true
local beforeCombatAttributes = attributes
for _, driver in ipairs(stateDrivers) do
    local snippet = driver:GetAttribute("_onstate-combat")
    local handler = assert(loadstring("return function(self, newstate) " .. snippet .. " end"))()
    secureExecution = true
    handler(driver, "combat")
    secureExecution = false
end
Frames.Fire(Window.events, "OnEvent", "PLAYER_REGEN_DISABLED")
AssertEqual(Window.IsActive(), false)
Frames.AssertShown(PetJournal, true)
AssertEqual(Window.toggle:IsEnabled(), false)
AssertEqual(frame.bottom.toggle:IsEnabled(), false)
Frames.Fire(Window.events, "OnEvent", "BAG_UPDATE_DELAYED")
Window.Show()
AssertEqual(attributes, beforeCombatAttributes)
combat = false
Frames.Fire(Window.events, "OnEvent", "PLAYER_REGEN_ENABLED")
AssertEqual(Window.IsActive(), true)
AssertEqual(Window.toggle:IsEnabled(), true)
AssertEqual(frame.bottom.toggle:IsEnabled(), true)
AssertEqual(Window.Hide(), true)
AssertEqual(Window.IsActive(), false)
AssertEqual(frame:GetParent(), UIParent)
AssertEqual(backdrop:GetAlpha(), 0.8)
AssertEqual(Window.Show(), true)
AssertEqual(Window.IsActive(), true)
Frames.Fire(frame.title.close, "OnClick")
Frames.AssertShown(CollectionsJournal, false)
AssertEqual(Window.IsActive(), false)
AssertEqual(Window.Show(), false)
CollectionsJournal:Show()
PetJournal:Show()
combat = true
for _, driver in ipairs(stateDrivers) do
    local handler = assert(loadstring("return function(self, newstate) " .. driver:GetAttribute("_onstate-combat") .. " end"))()
    secureExecution = true
    handler(driver, "combat")
    secureExecution = false
end
Frames.Fire(Window.events, "OnEvent", "PLAYER_REGEN_DISABLED")
PetJournal:Hide()
combat = false
Frames.Fire(Window.events, "OnEvent", "PLAYER_REGEN_ENABLED")
AssertEqual(Window.IsActive(), false)
AssertEqual(frame:GetParent(), UIParent)
Frames.AssertShown(PetJournal, false)
AssertEqual(Window.toggle:IsEnabled(), true)
PetJournal:Show()
AssertEqual(Window.IsActive(), true)
AssertEqual(type(views["window-teams"]), "table")
AssertEqual(type(views["window-queue"]), "table")
views["window-queue"].show()
AssertEqual(Window.view, "queue")
AssertEqual(views["window-queue"].isShown(), true)
AssertEqual(views["window-teams"].isShown(), false)
views["window-queue"].hide()
AssertEqual(Window.IsActive(), false)
BattleBuddyDev = nil
dofile(sourceRoot .. "/BattleBuddy/Window.lua")
print("window_test.lua: passed")
