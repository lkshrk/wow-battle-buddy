BattleBuddyWindow = {}

local Window = BattleBuddyWindow
local COLUMN_WIDTH, COLUMN_HEIGHT, JOURNAL_EXTRA_HEIGHT = 280, 520, 15
local GAP, TITLE_HEIGHT, TOOLBAR_HEIGHT, BOTTOM_HEIGHT = 2, 24, 32, 22
local CANVAS_WIDTH = COLUMN_WIDTH * 3 + GAP * 2
local CANVAS_HEIGHT = COLUMN_HEIGHT + JOURNAL_EXTRA_HEIGHT
local FRAME_WIDTH = CANVAS_WIDTH + 10
local FRAME_HEIGHT = CANVAS_HEIGHT + TITLE_HEIGHT + 4 + TOOLBAR_HEIGHT + BOTTOM_HEIGHT + GAP * 2
local views = { "teams", "targets", "queue", "options" }
local labels = { teams = "Teams", targets = "Targets", queue = "Queue", options = "Options" }
local stones = {
    levelingStone = { 116416, 116419, 116421, 116423, 116418, 116422, 116420, 116374, 116424, 116417, 116429, 127755, 122457 },
    rarityStone = { 92682, 92683, 92677, 92681, 92676, 92678, 92665, 92675, 92679, 92680, 98715, 92741 },
}
local actions = {
    { "heal", "Heal", "spell", 125439 },
    { "hat", "Safari Hat", "toy", 92738 },
    { "lesserTreat", "Lesser Pet Treat", "item", 98112 },
    { "treat", "Pet Treat", "item", 98114 },
    { "levelingStone", "Leveling Stone", "item", 116429 },
    { "rarityStone", "Rarity Stone", "item", 98715 },
    { "import", "Import Team", nil, "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up" },
    { "export", "Export Team", nil, "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up" },
    { "random", "Random Team", nil, "Interface\\Buttons\\UI-GroupLoot-Dice-Up" },
    { "summon", "Summon Pet", nil, "Interface\\Icons\\INV_Misc_Pet_Pandaren_Yeti" },
}
local changing, attached, registeredDev, loadedTeam
local hiddenArt = {}
local heals = {
    revive = { "Revive Battle Pets", "spell", 125439 },
    bandage = { "Battle Pet Bandage", "item", 86143 },
}
local selectedHeal, pendingHeal, preferredHeal
local Public = BattleBuddyCompatibility.PublicValue
local Field = BattleBuddyCompatibility.ReadField

local function InCombat()
    return not InCombatLockdown or Public(InCombatLockdown()) ~= false
end

local function SafeCall(callback, ...)
    if type(callback) ~= "function" then return end
    local function Pack(...) return { n = select("#", ...), ... } end
    local result = Pack(pcall(callback, ...))
    if not result[1] then return end
    for index = 2, result.n do result[index] = Public(result[index]) end
    return unpack(result, 2, result.n)
end

local function Text(parent, text, font)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    label:SetPoint("CENTER", parent, "CENTER", 0, 0)
    label:SetText(text)
    return label
end

local function Tooltip(button, text)
    button:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(text)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
end

local function Button(parent, text, width)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, BOTTOM_HEIGHT)
    button:SetText(text)
    return button
end

local function Checkbox(parent)
    local button = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    button:SetSize(24, 24)
    button.label = Text(button, "BattleBuddy")
    button.label:ClearAllPoints()
    button.label:SetPoint("LEFT", button, "RIGHT", 0, 0)
    button:SetChecked(false)
    return button
end

local function RestoreArt()
    for region, alpha in pairs(hiddenArt) do region:SetAlpha(alpha) end
    hiddenArt = {}
end

local function HideArt()
    local regions = { CollectionsJournal:GetRegions() }
    for _, key in ipairs({ "NineSlice", "BorderFrame" }) do
        if CollectionsJournal[key] then regions[#regions + 1] = CollectionsJournal[key] end
    end
    for _, region in ipairs(regions) do
        if region:GetObjectType() ~= "FontString" and hiddenArt[region] == nil then
            hiddenArt[region] = region:GetAlpha()
            region:SetAlpha(0)
        end
    end
end

local function ItemCount(itemID)
    local count = SafeCall(C_Item and C_Item.GetItemCount, itemID)
    return type(count) == "number" and count or 0
end

local function Stone(key, default)
    local list = stones[key]
    if not list then return default end
    local guid = SafeCall(C_PetJournal and C_PetJournal.GetSummonedPetGUID)
    if guid then
        local _, _, _, _, _, _, _, _, _, petType = SafeCall(C_PetJournal and C_PetJournal.GetPetInfoByPetID, guid)
        if type(petType) == "number" and list[petType] and petType >= 1 and petType <= 10
            and ItemCount(list[petType]) > 0 then return list[petType] end
    end
    for index = 11, #list do
        if ItemCount(list[index]) > 0 then return list[index] end
    end
    return default
end

local function Queued()
    local state = SafeCall(C_PetBattles and C_PetBattles.GetPVPMatchmakingInfo)
    return state == "queued" or state == "proposal" or state == "suspended"
end

local function HealOrder()
    return BattleBuddyConfig.GetSetting("healOrder")
end

local function HealStatus(key)
    local action = heals[key]
    local count = action[2] == "item" and ItemCount(action[3]) or nil
    local start, duration, enabled
    if action[2] == "spell" then
        local cooldown = SafeCall(C_Spell and C_Spell.GetSpellCooldown, action[3])
        start, duration, enabled = Field(cooldown, "startTime"), Field(cooldown, "duration"), Field(cooldown, "isEnabled")
    else
        start, duration, enabled = SafeCall(C_Item and C_Item.GetItemCooldown, action[3])
    end
    local now = SafeCall(GetTime)
    local remaining
    if type(start) == "number" and type(duration) == "number" and type(now) == "number" then
        remaining = math.max(0, start + duration - now)
    end
    local available = (not count or count > 0) and remaining == 0 and (enabled == true or enabled == 1)
    local status = remaining and remaining > 0 and (math.ceil(remaining) .. "s")
        or (available and "Ready" or "Unavailable")
    return available, action[1] .. (count and (" (" .. count .. ")") or "") .. " — " .. status
end

local function ChooseHeal()
    local first, ready
    for _, key in ipairs(HealOrder()) do
        if heals[key] then
            first = first or key
            if HealStatus(key) then ready = ready or key end
        end
    end
    if pendingHeal then
        preferredHeal, pendingHeal = pendingHeal, nil
    end
    if preferredHeal then
        selectedHeal = preferredHeal
    else
        selectedHeal = ready or first
    end
    return selectedHeal and heals[selectedHeal]
end

local function Refresh()
    local frame = Window.frame
    if not frame then return end
    local _, total = SafeCall(C_PetJournal and C_PetJournal.GetNumPets)
    frame.toolbar.total:SetText("Total Pets |cffffffff" .. tostring(total or 0))
    frame.toolbar.achievement.text:SetText(tostring(SafeCall(GetCategoryAchievementPoints, 15117, true) or 0))
    frame.bottom.findBattle:SetText(Queued() and "Leave Queue" or "Find Battle")
    frame.bottom.findBattle:SetEnabled(not InCombat())
    for index, action in ipairs(actions) do
        local button = frame.toolbar.buttons[index]
        local kind = action[3]
        if kind then
            local id = button.actionID or action[4]
            if action[1] == "heal" then
                if not InCombat() then
                    local heal = ChooseHeal()
                    if heal then
                        kind, id = heal[2], heal[3]
                        button:SetAttribute("spell", nil)
                        button:SetAttribute("item", nil)
                        button:SetAttribute("type", kind)
                        button:SetAttribute(kind, kind == "item" and ("item:" .. id) or id)
                        button.actionID, button.actionKind = id, kind
                        Tooltip(button, heal[1])
                    end
                end
                kind = button.actionKind or kind
            end
            if not InCombat() and action[1] ~= "heal" then
                id = Stone(action[1], action[4])
                button.actionID = id
                button:SetAttribute("type", kind)
                button:SetAttribute(kind, kind == "item" and ("item:" .. id) or id)
            end
            local icon, start, duration, enabled
            if kind == "spell" then
                icon = SafeCall(C_Spell and C_Spell.GetSpellTexture, id)
                local cooldown = SafeCall(C_Spell and C_Spell.GetSpellCooldown, id)
                if type(cooldown) == "table" then
                    start, duration, enabled = Field(cooldown, "startTime"), Field(cooldown, "duration"), Field(cooldown, "isEnabled")
                end
            else
                icon = SafeCall(C_Item and C_Item.GetItemIconByID, id)
                if kind == "toy" then
                    local _, _, toyIcon = SafeCall(C_ToyBox and C_ToyBox.GetToyInfo, id)
                    icon = toyIcon or icon
                end
                start, duration, enabled = SafeCall(C_Item and C_Item.GetItemCooldown, id)
            end
            button.icon:SetTexture(icon)
            local count = kind == "item" and ItemCount(id) or nil
            button.count:SetText(count and tostring(count) or "")
            button.icon:SetDesaturated(count == 0)
            button.cooldown:Clear()
            if type(start) == "number" and type(duration) == "number" and duration > 0
                and (enabled == true or enabled == 1) then
                button.cooldown:SetCooldown(start, duration)
            end
        end
    end
end

local function OpenSaveDialog(mode)
    if InCombat() or type(BattleBuddySaveTeamDialog) ~= "table" then return end
    BattleBuddySaveTeamDialog.Open(mode)
end

function Window.SetLoadedTeam(teamID)
    loadedTeam = type(teamID) == "string" and teamID or nil
    local save = Window.frame and Window.frame.bottom and Window.frame.bottom.save
    if save then save:SetEnabled(loadedTeam ~= nil) end
end

function Window.SelectView(name)
    if not labels[name] then return false end
    Window.view = name
    if type(BattleBuddyDB) == "table" then BattleBuddyDB.windowView = name end
    if Window.frame then
        Window.frame.panel.label:SetText(labels[name])
        for index, button in ipairs(Window.frame.tabButtons) do
            button.selected = views[index] == name
            if button.selected then PanelTemplates_SelectTab(button)
            else PanelTemplates_DeselectTab(button) end
        end
    end
    return true
end

function Window.IsActive()
    return Window.frame ~= nil and CollectionsJournal ~= nil
        and Window.frame:GetParent() == CollectionsJournal and Window.frame:IsShown()
end

function Window.Hide()
    if InCombat() then return false end
    if Window.frame then
        Window.frame:SetAttribute("window-active", false)
        Window.frame:Hide()
        Window.frame:SetParent(UIParent)
    end
    RestoreArt()
    return true
end

local function SetEnabled(enabled)
    if Window.toggle then Window.toggle:SetEnabled(enabled) end
    if Window.frame then Window.frame.bottom.toggle:SetEnabled(enabled) end
end

local function SetJournalWindow(enabled)
    if InCombat() or not BattleBuddyConfig or not BattleBuddyConfig.SetSetting
        or not BattleBuddyConfig.SetSetting("journalWindow", enabled) then return end
    if enabled then
        Window.Show()
    else
        Window.Hide()
        if PetJournal then
            changing = true
            PetJournal:Show()
            changing = false
        end
        if Window.toggle then Window.toggle:SetChecked(false) end
    end
end

local function CreateWindow()
    if Window.frame then return end
    local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate,SecureHandlerStateTemplate")
    Window.frame = frame
    frame:Hide()
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:EnableMouse(false)
    frame:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    frame:SetBackdropColor(0.04, 0.04, 0.04, 1)
    frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    frame:SetFrameRef("journal", PetJournal)
    -- Secure descendants protect their ancestors; combat visibility must change securely.
    frame:SetAttribute("_onstate-combat", [[
        if newstate == "combat" and self:GetAttribute("window-active") then
            self:Hide()
            local journal = self:GetFrameRef("journal")
            if journal then journal:Show() end
        end
    ]])
    if RegisterStateDriver then RegisterStateDriver(frame, "combat", "[combat] combat; peace") end

    frame.title = CreateFrame("Frame", nil, frame)
    frame.title:SetSize(FRAME_WIDTH, TITLE_HEIGHT)
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    frame.title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    frame.title.label = Text(frame.title, "BattleBuddy")
    local portrait = frame.title:CreateTexture(nil, "ARTWORK")
    portrait:SetSize(40, 40)
    portrait:SetPoint("TOPLEFT", frame.title, "TOPLEFT", -12, 8)
    portrait:SetTexture("Interface\\Icons\\PetJournalPortrait")
    local mask = frame.title:CreateMaskTexture()
    mask:SetAllPoints(portrait)
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    portrait:AddMaskTexture(mask)
    frame.title.portrait = portrait
    frame.title.close = CreateFrame("Button", nil, frame.title, "UIPanelCloseButton")
    frame.title.close:SetPoint("TOPRIGHT", frame.title, "TOPRIGHT", 2, 2)
    frame.title.close:SetScript("OnClick", function()
        if not InCombat() and HideUIPanel and CollectionsJournal then HideUIPanel(CollectionsJournal) end
    end)

    local canvas = CreateFrame("Frame", nil, frame)
    frame.canvas = canvas
    canvas:SetSize(CANVAS_WIDTH, CANVAS_HEIGHT)
    canvas:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -(TITLE_HEIGHT + TOOLBAR_HEIGHT + GAP))
    for _, key in ipairs({ "pets", "target", "team", "loadout", "panel" }) do
        frame[key] = CreateFrame("Frame", nil, canvas, "InsetFrameTemplate")
    end
    frame.pets:SetPoint("TOPLEFT", canvas, "TOPLEFT", 0, 0)
    frame.pets:SetPoint("BOTTOMRIGHT", canvas, "BOTTOMLEFT", COLUMN_WIDTH, 0)
    if BattleBuddyPetList then BattleBuddyPetList.Mount(frame.pets) end
    frame.panel:SetPoint("TOPLEFT", canvas, "TOPRIGHT", -COLUMN_WIDTH, 0)
    frame.panel:SetPoint("BOTTOMRIGHT", canvas, "BOTTOMRIGHT", 0, 0)
    frame.target:SetPoint("TOPLEFT", frame.pets, "TOPRIGHT", GAP, 0)
    frame.target:SetPoint("BOTTOMRIGHT", frame.panel, "TOPLEFT", -GAP, -75)
    frame.team:SetPoint("TOPLEFT", frame.target, "BOTTOMLEFT", 0, -GAP)
    frame.team:SetPoint("BOTTOMRIGHT", frame.target, "BOTTOMRIGHT", 0, -(26 + GAP))
    frame.loadout:SetPoint("TOPLEFT", frame.team, "BOTTOMLEFT", 0, -GAP)
    frame.loadout:SetPoint("BOTTOMRIGHT", canvas, "BOTTOMRIGHT", -(COLUMN_WIDTH + GAP), 0)
    frame.target.label = Text(frame.target, "Target")
    frame.team.label = Text(frame.team, "Team")
    frame.loadout.label = Text(frame.loadout, "Loadout")
    frame.panel.label = Text(frame.panel, "Teams")

    local toolbar = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
    frame.toolbar = toolbar
    toolbar:SetHeight(TOOLBAR_HEIGHT)
    toolbar:SetPoint("TOPLEFT", canvas, "TOPLEFT", 0, TOOLBAR_HEIGHT + GAP)
    toolbar:SetPoint("BOTTOMRIGHT", canvas, "TOPRIGHT", 0, GAP)
    toolbar.buttons = {}
    for index = #actions, 1, -1 do
        local action = actions[index]
        local button = CreateFrame("Button", nil, toolbar, action[3] and "SecureActionButtonTemplate" or nil)
        toolbar.buttons[index] = button
        button.key = action[1]
        button:SetSize(32, 32)
        if index == #actions then button:SetPoint("RIGHT", toolbar, "RIGHT", 0, 0)
        else button:SetPoint("RIGHT", toolbar.buttons[index + 1], "LEFT", 0, 0) end
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetAllPoints()
        button.count = Text(button, "", "NumberFontNormalSmall")
        button.count:ClearAllPoints()
        button.count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
        button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
        button.cooldown:SetAllPoints()
        button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
        if action[3] then
            button:RegisterForClicks("AnyDown", "AnyUp")
            Tooltip(button, action[2])
        else
            button.icon:SetTexture(action[4])
            if action[1] == "import" then
                button:SetScript("OnClick", function()
                    if InCombat() then return end
                    BattleBuddyTeamMenus.Import(BattleBuddyDB, { refresh = function()
                        if BattleBuddyTeamsPanel then BattleBuddyTeamsPanel.Refresh() end
                    end })
                end)
                Tooltip(button, action[2])
            else
                button:SetEnabled(false)
                button:SetMotionScriptsWhileDisabled(true)
                Tooltip(button, "Available in a later BattleBuddy slice")
            end
        end
    end
    toolbar.healArrow = CreateFrame("DropdownButton", nil, toolbar, "WowStyle1ArrowDropdownTemplate")
    toolbar.healArrow:SetSize(25, 25)
    toolbar.healArrow:SetPoint("RIGHT", toolbar.buttons[1], "LEFT", 0, 0)
    toolbar.healArrow:SetupMenu(function(_, root)
        for _, key in ipairs(HealOrder()) do
            if heals[key] then
                local _, label = HealStatus(key)
                root:CreateRadio(label, function() return selectedHeal == key end, function()
                    pendingHeal = key
                    if not InCombat() then Refresh() end
                end)
            end
        end
    end)
    toolbar.total = Button(toolbar, "Total Pets", 120)
    toolbar.total:SetPoint("LEFT", toolbar, "LEFT", 56, 0)
    toolbar.achievement = CreateFrame("Button", nil, toolbar)
    toolbar.achievement:SetHeight(32)
    toolbar.achievement:SetPoint("LEFT", toolbar.total, "RIGHT", 8, 0)
    toolbar.achievement:SetPoint("RIGHT", toolbar.healArrow, "LEFT", -4, 0)
    toolbar.achievement.text = Text(toolbar.achievement, "", "GameFontNormalLarge")
    for _, side in ipairs({ -1, 1 }) do
        local flair = toolbar.achievement:CreateTexture(nil, "BACKGROUND")
        flair:SetSize(48, 24)
        flair:SetPoint("CENTER", toolbar.achievement, "CENTER", side * 65, 0)
        SafeCall(flair.SetAtlas, flair, "PetJournal-PetBattleAchievementBG")
        if side == 1 then flair:SetTexCoord(1, 0, 0, 1) end
    end
    local shield = toolbar.achievement:CreateTexture(nil, "ARTWORK")
    shield:SetSize(24, 24)
    shield:SetPoint("LEFT", toolbar.achievement.text, "RIGHT", 4, 0)
    shield:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Shields-NoPoints")
    toolbar.achievement:SetScript("OnClick", function()
        if not InCombat() then SafeCall(ToggleAchievementFrame) end
    end)

    local bottom = CreateFrame("Frame", nil, frame)
    frame.bottom = bottom
    bottom:SetHeight(BOTTOM_HEIGHT)
    bottom:SetPoint("TOPLEFT", canvas, "BOTTOMLEFT", 0, -GAP)
    bottom:SetPoint("BOTTOMRIGHT", canvas, "BOTTOMRIGHT", 0, -(BOTTOM_HEIGHT + GAP))
    bottom.summon = Button(bottom, "Summon", 156)
    bottom.summon:SetPoint("LEFT", bottom, "LEFT", 0, 0)
    bottom.summon:SetEnabled(false)
    bottom.toggle = Checkbox(bottom)
    bottom.toggle:SetPoint("LEFT", bottom.summon, "RIGHT", 0, 0)
    bottom.toggle:SetScript("OnClick", function(self) SetJournalWindow(self:GetChecked()) end)
    bottom.findBattle = Button(bottom, "Find Battle", 136)
    bottom.findBattle:SetPoint("RIGHT", bottom, "RIGHT", 0, 0)
    bottom.saveAs = Button(bottom, "Save As", 136)
    bottom.saveAs:SetPoint("RIGHT", bottom.findBattle, "LEFT", -GAP, 0)
    bottom.save = Button(bottom, "Save", 136)
    bottom.save:SetPoint("RIGHT", bottom.saveAs, "LEFT", -GAP, 0)
    bottom.save:SetEnabled(loadedTeam ~= nil)
    bottom.save:SetScript("OnClick", function() OpenSaveDialog("save") end)
    bottom.saveAs:SetScript("OnClick", function() OpenSaveDialog("saveAs") end)
    bottom.findBattle:SetScript("OnClick", function()
        if InCombat() or not C_PetBattles then return end
        if Queued() then SafeCall(C_PetBattles.StopPVPMatchmaking)
        else SafeCall(C_PetBattles.StartPVPMatchmaking) end
        Refresh()
    end)
    frame.tabs = CreateFrame("Frame", nil, frame)
    frame.tabs:SetWidth(256)
    frame.tabs.minTabWidth, frame.tabs.maxTabWidth = 64, 64
    frame.tabs:SetPoint("TOPLEFT", CollectionsJournal.MountsTab, "TOPLEFT", 565, 0)
    frame.tabs:SetPoint("BOTTOMLEFT", CollectionsJournal.MountsTab, "BOTTOMLEFT", 565, 0)
    frame.tabButtons = {}
    for index, name in ipairs(views) do
        local tab = CreateFrame("Button", nil, frame.tabs, "PanelTabButtonTemplate")
        tab:SetText(labels[name])
        tab:SetHeight(32)
        PanelTemplates_TabResize(tab, nil, nil, 64, 64)
        tab:SetPoint("TOPLEFT", frame.tabs, "TOPLEFT", (index - 1) * 64, 0)
        tab:SetScript("OnClick", function() Window.SelectView(name) end)
        frame.tabButtons[index] = tab
    end
    local saved = type(BattleBuddyDB) == "table" and BattleBuddyDB.windowView
    Window.SelectView(labels[saved] and saved or "teams")
    frame:SetScript("OnShow", Refresh)
    if BattleBuddyLoadout then BattleBuddyLoadout.Mount(frame) end
    if BattleBuddyTeamsPanel then BattleBuddyTeamsPanel.Mount(frame.panel) end
end

function Window.Show()
    if InCombat() or changing or not PetJournal or not CollectionsJournal or not UIParent
        or not CollectionsJournal:IsShown() or not CreateFrame then return false end
    CreateWindow()
    changing = true
    PetJournal:Hide()
    changing = false
    local frame = Window.frame
    frame:SetParent(CollectionsJournal)
    frame:SetFrameLevel(CollectionsJournal:GetFrameLevel() + 600)
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMLEFT", CollectionsJournal, "BOTTOMLEFT", -10, -5)
    frame:SetAttribute("window-active", true)
    HideArt()
    frame.bottom.toggle:SetChecked(true)
    if Window.toggle then Window.toggle:SetChecked(false) end
    SetEnabled(true)
    frame:Show()
    Refresh()
    return true
end

local function JournalShown()
    if not changing and BattleBuddyConfig and BattleBuddyConfig.GetSetting
        and BattleBuddyConfig.GetSetting("journalWindow") then Window.Show() end
end

local function RegisterDevViews()
    if registeredDev or not BattleBuddyDev or not BattleBuddyDev.RegisterView then return end
    for _, name in ipairs({ "teams", "queue" }) do
        BattleBuddyDev.RegisterView("window-" .. name, function()
            if InCombat() or not SetCollectionsJournalShown or not COLLECTIONS_JOURNAL_TAB_INDEX_PETS then return false end
            SetCollectionsJournalShown(true, COLLECTIONS_JOURNAL_TAB_INDEX_PETS)
            if not Window.Show() then return false end
            Window.SelectView(name)
            if name == "teams" and BattleBuddyTeamsPanel then BattleBuddyTeamsPanel.SetPreview(true) end
            return true
        end, function()
            if not InCombat() and HideUIPanel and CollectionsJournal then HideUIPanel(CollectionsJournal) end
        end, function() return Window.IsActive() and Window.view == name end)
    end
    registeredDev = true
end

local function Attach()
    RegisterDevViews()
    if attached or InCombat() or not CreateFrame or not PetJournal or not PetJournalSummonButton
        or not CollectionsJournal or not hooksecurefunc then return end
    attached = true
    Window.toggle = Checkbox(PetJournal)
    Window.toggle:SetPoint("LEFT", PetJournalSummonButton, "RIGHT", 0, -1)
    Window.toggle:SetScript("OnClick", function(self) SetJournalWindow(self:GetChecked()) end)
    hooksecurefunc(PetJournal, "Show", JournalShown)
    hooksecurefunc(PetJournal, "Hide", function() if not changing then Window.Hide() end end)
    if type(BattleBuddyScript) == "table" and type(BattleBuddyScript.SetLoadedTeam) == "function" then
        hooksecurefunc(BattleBuddyScript, "SetLoadedTeam", function(_, id) Window.SetLoadedTeam(id) end)
    end
    hooksecurefunc(PetJournal, "SetShown", function(_, shown)
        if changing then return end
        if shown then JournalShown() else Window.Hide() end
    end)
    CollectionsJournal:HookScript("OnShow", function()
        if PetJournal:IsShown() then JournalShown() end
    end)
    CollectionsJournal:HookScript("OnHide", function()
        if InCombat() then RestoreArt(); return end
        local active = Window.IsActive()
        Window.Hide()
        if active then
            changing = true
            PetJournal:Show()
            changing = false
        end
    end)
    if PetJournal:IsShown() then JournalShown() end
end

if CreateFrame then
    Window.events = CreateFrame("Frame")
    for _, event in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
        "BAG_UPDATE_DELAYED", "PET_JOURNAL_LIST_UPDATE", "ACHIEVEMENT_EARNED", "PET_BATTLE_QUEUE_STATUS",
        "SPELL_UPDATE_COOLDOWN", "BAG_UPDATE_COOLDOWN", "COMPANION_UPDATE" }) do
        Window.events:RegisterEvent(event)
    end
    Window.events:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            RestoreArt()
            SetEnabled(false)
        elseif event == "PLAYER_REGEN_ENABLED" then
            SetEnabled(true)
            Attach()
            if PetJournal and CollectionsJournal and PetJournal:IsShown() and CollectionsJournal:IsShown() then
                JournalShown()
            else
                Window.Hide()
            end
        elseif event == "ADDON_LOADED" or event == "PLAYER_LOGIN" then
            Attach()
        end
        Refresh()
    end)
end
RegisterDevViews()
if EventUtil and EventUtil.ContinueOnAddOnLoaded then
    EventUtil.ContinueOnAddOnLoaded("Blizzard_Collections", Attach)
end
