BattleBuddyPetList = {}

local List = BattleBuddyPetList
local ROW_HEIGHT, EXPANDED_HEIGHT, COLLAPSED_HEIGHT = 44, 115, 56
local families = { "Humanoid", "Dragon", "Flying", "Undead", "Critter", "Magical", "Elemental", "Beast", "Water", "Mechanical" }
local collection, duplicates, inTeams = {}, {}, {}
local registeredDev
List.filters = { families = {}, strong = {}, tough = {} }

local function InCombat()
    return InCombatLockdown and InCombatLockdown() or false
end

local function Restricted(value)
    local _, state = BattleBuddyCompatibility.PublicValue(value)
    return state ~= "usable"
end

local function Label(parent, text, font)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    label:SetText(text)
    return label
end

local function FamilyTexture(family)
    return families[family] and ("Interface\\PetBattles\\PetIcon-" .. families[family]) or nil
end

local function Selection(row)
    local id = row.pet.petID or row.pet.speciesID
    row.selected:SetShown(id ~= nil and List.selectedPetID == id)
end

function List.BindRow(row, pet)
    if InCombat() then return end
    if not row.icon then
        row:SetHeight(ROW_HEIGHT)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        row.background = row:CreateTexture(nil, "BACKGROUND")
        row.background:SetAllPoints()
        row.background:SetColorTexture(0.02, 0.02, 0.02, 0.9)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(40, 40)
        row.icon:SetPoint("LEFT", row, "LEFT", 2, 0)
        row.border = row:CreateTexture(nil, "OVERLAY")
        row.border:SetSize(46, 46)
        row.border:SetPoint("CENTER", row.icon, "CENTER", 0, 0)
        row.border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        row.levelBadge = row:CreateTexture(nil, "ARTWORK")
        row.levelBadge:SetSize(18, 16)
        row.levelBadge:SetPoint("BOTTOMRIGHT", row.icon, "BOTTOMRIGHT", 2, 0)
        row.levelBadge:SetAtlas("PetJournal-LevelBubble")
        row.level = Label(row, "", "NumberFontNormalSmall")
        row.level:SetPoint("CENTER", row.levelBadge, "CENTER", 0, 0)
        row.name = Label(row, "")
        row.name:SetPoint("LEFT", row, "LEFT", 48, 0)
        row.name:SetPoint("RIGHT", row, "RIGHT", -34, 0)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)
        row.family = row:CreateTexture(nil, "BORDER")
        row.family:SetSize(42, 42)
        row.family:SetPoint("RIGHT", row, "RIGHT", -1, 0)
        row.family:SetAlpha(0.3)
        row.family:SetTexCoord(0.4921875, 0.796875, 0.50390625, 0.65625)
        row.breed = Label(row, "")
        row.breed:SetPoint("BOTTOMRIGHT", row.family, "BOTTOMRIGHT", -2, 0)
        row.breed:SetJustifyH("RIGHT")
        row.favorite = row:CreateTexture(nil, "OVERLAY")
        row.favorite:SetSize(14, 14)
        row.favorite:SetPoint("TOPLEFT", row.icon, "TOPLEFT", -3, 3)
        row.favorite:SetAtlas("PetJournal-FavoritesIcon")
        row.duplicate = Label(row, "")
        row.duplicate:SetPoint("TOPRIGHT", row, "TOPRIGHT", -3, -2)
        row.inTeam = Label(row, "T")
        row.inTeam:SetTextColor(0.2, 1, 0.2)
        row.inTeam:SetPoint("TOPRIGHT", row, "TOPRIGHT", -23, -2)
        row.summoned = row:CreateTexture(nil, "BACKGROUND")
        row.summoned:SetAllPoints()
        row.summoned:SetColorTexture(0.12, 0.3, 0.15, 0.4)
        row.selected = row:CreateTexture(nil, "BORDER")
        row.selected:SetAllPoints()
        row.selected:SetColorTexture(0.5, 0.4, 0.1, 0.3)
        row:RegisterForDrag("LeftButton")
        row:RegisterForClicks("LeftButtonUp")
        row:SetScript("OnDragStart", function(self)
            if not InCombat() and self.pet.owned == true and self.pet.petID then
                BattleBuddyCompatibility.PickupPet(self.pet.petID)
            end
        end)
        row:SetScript("OnClick", function(self)
            if InCombat() then return end
            List.selectedPetID = self.pet.petID or self.pet.speciesID
            List.ApplyFilters(true)
        end)
    end
    row.pet = pet
    row.icon:SetTexture(pet.icon)
    row.level:SetText(pet.level and tostring(pet.level) or "")
    row.levelBadge:SetShown(pet.level ~= nil)
    row.name:SetText(pet.name or pet.speciesName or "Unknown pet")
    local quality = BattleBuddyCompatibility.PublicValueOfType(pet.quality, "number")
    local color = pet.owned == true and quality and ColorManager.GetColorDataForItemQuality(quality - 1)
    row.name:SetTextColor(color and color.r or 0.5, color and color.g or 0.5, color and color.b or 0.5)
    row.family:SetTexture(FamilyTexture(pet.petType))
    row.breed:SetText("")
    row.favorite:SetShown(pet.favorite == true)
    local count = duplicates[pet.speciesID] or 0
    row.duplicate:SetText(count > 1 and tostring(count) or "")
    row.duplicate:SetShown(count > 1)
    row.inTeam:SetShown(inTeams[pet.petID] == true or inTeams[pet.speciesID] == true)
    row.summoned:SetShown(pet.summoned == true)
    Selection(row)
end

local function Layout()
    local frame = List.frame
    local header = frame.expanded and EXPANDED_HEIGHT or COLLAPSED_HEIGHT
    frame.familyBar:SetShown(frame.expanded)
    frame.expand:SetText(frame.expanded and "^" or "v")
    frame.summary:ClearAllPoints()
    frame.summary:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -header)
    frame.summary:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -18, -header)
    frame.scrollBox:ClearAllPoints()
    frame.scrollBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 3, -(header + (frame.summary:IsShown() and 20 or 0)))
    frame.scrollBox:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 3)
end

function List.ApplyFilters(retainScrollPosition)
    local frame = List.frame
    if not frame or InCombat() then return end
    local ranges = {}
    for key, edit in pairs(frame.ranges) do ranges[key] = edit:GetText() end
    List.query = BattleBuddyPetQuery.Parse(frame.search:GetText(), ranges)
    List.results = BattleBuddyPetQuery.Filter(collection, List.query, List.filters, Restricted)
    for key, edit in pairs(frame.ranges) do
        local invalid = List.query.errors[key] ~= nil
        edit:SetTextColor(1, invalid and 0.2 or 1, invalid and 0.2 or 1)
        edit.hint:SetShown(edit:GetText() == "")
    end
    local invalid = List.query.errors.search ~= nil
    frame.search:SetTextColor(1, invalid and 0.2 or 1, invalid and 0.2 or 1)
    frame.search.hint:SetShown(frame.search:GetText() == "")
    local active = List.query.active or List.filters.level25 or List.filters.rare
    for index, key in ipairs({ "families", "strong", "tough" }) do
        if next(List.filters[key]) then active = true end
        frame.tabs[key]:SetText((next(List.filters[key]) and "* " or "") .. ({ "Pet Type", "Strong Vs", "Tough Vs" })[index])
        frame.tabs[key]:SetNormalTexture(frame.category == key and "Interface\\Buttons\\UI-Panel-Button-Down"
            or "Interface\\Buttons\\UI-Panel-Button-Up")
    end
    frame.level25:SetNormalTexture(List.filters.level25 and "Interface\\Buttons\\UI-Panel-Button-Down"
        or "Interface\\Buttons\\UI-Panel-Button-Up")
    local group = List.filters[frame.category]
    for index, button in ipairs(frame.families) do
        button.icon:SetAlpha((not next(group) or group[index]) and 1 or 0.3)
        button.selected:SetShown(group[index] == true)
    end
    frame.summary:SetText(tostring(#List.results) .. " pets")
    frame.summary:SetShown(active or not List.query.valid)
    Layout()
    frame.scrollBox:SetDataProvider(CreateDataProvider(List.results), retainScrollPosition == true)
end

function List.Refresh()
    if not List.frame or InCombat() then return end
    collection = BattleBuddyCompatibility.ReadPetCollection() or {}
    duplicates, inTeams = {}, {}
    for _, pet in ipairs(collection) do
        if pet.owned == true and pet.speciesID then
            duplicates[pet.speciesID] = (duplicates[pet.speciesID] or 0) + 1
        end
    end
    for _, team in pairs(BattleBuddyDB and BattleBuddyDB.teamsByID or {}) do
        for _, id in ipairs(team.pets or {}) do
            id = BattleBuddyCompatibility.PublicValue(id)
            if type(id) == "string" or type(id) == "number" then inTeams[id] = true end
        end
    end
    List.ApplyFilters(true)
end

local function Input(parent, text)
    local edit = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    edit:SetAutoFocus(false)
    edit:SetHeight(22)
    edit:SetMaxLetters(256)
    edit:SetText("")
    edit.hint = Label(edit, text)
    edit.hint:SetPoint("LEFT", edit, "LEFT", 2, 0)
    edit.hint:SetTextColor(0.5, 0.5, 0.5)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnTextChanged", function() List.ApplyFilters() end)
    return edit
end

function List.Mount(parent)
    if InCombat() then return end
    if List.frame then return List.frame end
    local frame = CreateFrame("Frame", nil, parent)
    List.frame = frame
    frame:SetAllPoints()
    frame.expanded, frame.category = true, "families"
    frame.expand = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.expand:SetSize(20, 22)
    frame.expand:SetPoint("TOPLEFT", frame, "TOPLEFT", 3, -3)
    frame.expand:SetScript("OnClick", function()
        if InCombat() then return end
        frame.expanded = not frame.expanded
        Layout()
    end)
    frame.search = Input(frame, "Search pets / abilities")
    frame.search:SetPoint("TOPLEFT", frame, "TOPLEFT", 30, -3)
    frame.search:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -3)
    frame.ranges = {}
    for index, key in ipairs({ "health", "power", "speed" }) do
        local edit = Input(frame, ({ "HP < = >", "Power < = >", "Speed < = >" })[index])
        edit:SetSize(82, 22)
        edit:SetPoint("TOPLEFT", frame, "TOPLEFT", 8 + (index - 1) * 90, -30)
        frame.ranges[key] = edit
    end
    frame.familyBar = CreateFrame("Frame", nil, frame)
    frame.familyBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 3, -56)
    frame.familyBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -3, -56)
    frame.familyBar:SetHeight(56)
    frame.level25 = CreateFrame("Button", nil, frame.familyBar, "UIPanelButtonTemplate")
    frame.level25:SetSize(26, 22)
    frame.level25:SetPoint("TOPLEFT", frame.familyBar, "TOPLEFT", 0, 0)
    frame.level25:SetText("25")
    frame.level25:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    frame.level25:SetScript("OnClick", function(_, button)
        if InCombat() then return end
        if button == "RightButton" then
            local enabled = not (List.filters.level25 and List.filters.rare)
            List.filters.level25, List.filters.rare = enabled, enabled
        else
            List.filters.level25, List.filters.rare = not List.filters.level25, false
        end
        List.ApplyFilters()
    end)
    frame.tabs, frame.families = {}, {}
    for index, key in ipairs({ "families", "strong", "tough" }) do
        local tab = CreateFrame("Button", nil, frame.familyBar, "UIPanelButtonTemplate")
        tab:SetSize(80, 22)
        tab:SetPoint("TOPLEFT", frame.familyBar, "TOPLEFT", 28 + (index - 1) * 80, 0)
        tab:SetText(({ "Pet Type", "Strong Vs", "Tough Vs" })[index])
        tab:SetScript("OnClick", function()
            if InCombat() then return end
            frame.category = key
            List.ApplyFilters()
        end)
        frame.tabs[key] = tab
    end
    for index = 1, 10 do
        local button = CreateFrame("Button", nil, frame.familyBar)
        button:SetSize(26, 26)
        button:SetPoint("TOPLEFT", frame.familyBar, "TOPLEFT", 2 + (index - 1) * 27, -27)
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetAllPoints()
        button.icon:SetTexture(FamilyTexture(index))
        button.icon:SetTexCoord(0.4921875, 0.796875, 0.50390625, 0.65625)
        button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
        button.selected = button:CreateTexture(nil, "OVERLAY")
        button.selected:SetSize(40, 40)
        button.selected:SetPoint("CENTER", button, "CENTER", 0, 0)
        button.selected:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        button.selected:SetBlendMode("ADD")
        button.selected:SetVertexColor(1, 0.82, 0)
        button:SetScript("OnClick", function()
            if InCombat() then return end
            local group = List.filters[frame.category]
            if IsAltKeyDown and IsAltKeyDown() then
                for family = 1, 10 do group[family] = family == index or nil end
            elseif IsShiftKeyDown and IsShiftKeyDown() then
                for family = 1, 10 do group[family] = family ~= index or nil end
            else group[index] = not group[index] or nil end
            local count = 0
            for _ in pairs(group) do count = count + 1 end
            if count == 10 then List.filters[frame.category] = {} end
            List.ApplyFilters()
        end)
        frame.families[index] = button
    end
    frame.summary = Label(frame, "")
    frame.summary:SetHeight(20)
    frame.summary:Hide()
    frame.scrollBox = CreateFrame("Frame", nil, frame, "WowScrollBoxList")
    frame.scrollBar = CreateFrame("EventFrame", nil, frame, "MinimalScrollBar")
    frame.scrollBar:SetPoint("TOPLEFT", frame.scrollBox, "TOPRIGHT", 3, 0)
    frame.scrollBar:SetPoint("BOTTOMLEFT", frame.scrollBox, "BOTTOMRIGHT", 3, 0)
    local view = CreateScrollBoxListLinearView()
    view:SetElementInitializer("Button", List.BindRow)
    view:SetElementExtent(ROW_HEIGHT)
    ScrollUtil.InitScrollBoxListWithScrollBar(frame.scrollBox, frame.scrollBar, view)
    frame:SetScript("OnShow", List.Refresh)
    List.Refresh()
    return frame
end

local function RegisterDev()
    if registeredDev or not BattleBuddyDev or not BattleBuddyDev.RegisterView then return end
    registeredDev = BattleBuddyDev.RegisterView("window-pets", function()
        if InCombat() or not SetCollectionsJournalShown then return false end
        SetCollectionsJournalShown(true, COLLECTIONS_JOURNAL_TAB_INDEX_PETS)
        return BattleBuddyWindow.Show()
    end, function()
        if not InCombat() and HideUIPanel and CollectionsJournal then HideUIPanel(CollectionsJournal) end
    end, function() return BattleBuddyWindow.IsActive() end)
end

if CreateFrame then
    List.events = CreateFrame("Frame")
    for _, event in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_REGEN_ENABLED", "PET_JOURNAL_LIST_UPDATE",
        "PET_JOURNAL_PET_DELETED", "PET_JOURNAL_PETS_HEALED", "PET_BATTLE_LEVEL_CHANGED", "COMPANION_UPDATE" }) do
        List.events:RegisterEvent(event)
    end
    List.events:SetScript("OnEvent", function()
        RegisterDev()
        List.Refresh()
    end)
end
RegisterDev()
