-- luacheck: globals BattleBuddyCompatibility BattleBuddyTeams BattleBuddyDB BattleBuddyLoadout BattleBuddyScript BattleBuddyTeamMenus BattleBuddySaveTeamDialog BattleBuddyWindow C_PetJournal C_PetBattles InCombatLockdown CreateFrame CreateDataProvider CreateScrollBoxListLinearView ScrollUtil Menu GameTooltip UIErrorsFrame GetCursorPosition hooksecurefunc
BattleBuddyTeamsPanel = {}

local P, T, C = BattleBuddyTeamsPanel, BattleBuddyTeams, BattleBuddyCompatibility
local query, loadedID, loadedStore = "", nil, nil
local drag, previewStore

local function Read(callback, ...)
    if type(callback) ~= "function" then return end
    local function Results(ok, ...)
        if not ok then return end
        local values = {}
        for i = 1, select("#", ...) do values[i] = C.PublicValue((select(i, ...))) end
        return unpack(values, 1, select("#", ...))
    end
    return Results(pcall(callback, ...))
end

local function Combat() return Read(InCombatLockdown) ~= false end
local function Store() return P.preview and previewStore or BattleBuddyDB end

local function Report(message)
    P.message = message or ""
    if P.frame then P.frame.message:SetText(P.message) end
    if message and UIErrorsFrame then UIErrorsFrame:AddMessage(message, 1, 0.7, 0.2) end
    return false, message
end

local function Pet(team, index)
    local id, tag = team.pets[index], team.tags[index] or {}
    local species, custom, name, icon
    if type(id) == "string" and id:match("^BattlePet%-.+") then
        local _
        species, custom, _, _, _, _, _, name, icon = Read(C_PetJournal.GetPetInfoByPetID, id)
    end
    species = C.PublicValueOfType(species, "number")
    local owned = species ~= nil
    if not species then species = tag.speciesID or (type(id) == "number" and id > 0 and id) end
    if species and not owned then name, icon = Read(C_PetJournal.GetPetInfoBySpeciesID, species) end
    return { id = owned and id or nil, species = species, name = C.PublicValueOfType(custom, "string")
        or C.PublicValueOfType(name, "string"), speciesName = C.PublicValueOfType(name, "string"),
        icon = C.PublicValueOfType(icon, "number") or C.PublicValueOfType(icon, "string") }
end

local function Matches(team, search)
    if search:match("^battlepet%-.+") then
        for _, id in ipairs(team.pets) do if type(id) == "string" and id:lower() == search then return true end end
        return false
    end
    local function Has(text) return text and text:lower():find(search, 1, true) ~= nil end
    if Has(team.name) then return true end
    for _, name in pairs(team.targetNames or {}) do if Has(name) then return true end end
    for index = 1, 3 do
        local pet = Pet(team, index)
        if Has(pet.name) or Has(pet.speciesName) then return true end
    end
    return false
end

function P.Rows(store, search)
    if not store or not store.groupsByID then return {} end
    local rows = {}
    search = (search or ""):lower()
    for _, group in ipairs(T.ListGroups(store)) do
        local members, matching = T.ListTeams(store, group.groupID), {}
        local groupMatch = not search:match("^battlepet%-.+") and group.name:lower():find(search, 1, true)
        for _, team in ipairs(members) do
            if search == "" or groupMatch or Matches(team, search) then matching[#matching + 1] = team end
        end
        if search == "" or groupMatch or #matching > 0 then
            local expanded = search ~= "" or group.isExpanded == true
            if drag and drag.groupID ~= group.groupID then expanded = false end
            rows[#rows + 1] = { kind = "group", groupID = group.groupID, group = group, expanded = expanded }
            if expanded then
                for _, team in ipairs(matching) do
                    rows[#rows + 1] = { kind = "team", teamID = team.teamID, groupID = group.groupID, team = team }
                end
                if #matching == 0 then rows[#rows + 1] = { kind = "empty", groupID = group.groupID } end
            end
        end
    end
    return rows
end

function P.Load(teamID)
    if Combat() then return Report("Teams cannot be loaded in combat.") end
    if Read(C_PetBattles and C_PetBattles.IsInBattle) ~= false then return Report("Teams cannot be loaded during a pet battle.") end
    if P.preview then return Report("Preview teams cannot be loaded.") end
    local store = Store()
    local team = store and T.GetTeam(store, teamID)
    if not team then return Report("This team no longer exists.") end
    local missing, failures, changedSlots = {}, {}, 0
    for index = 1, 3 do
        local id, tag = team.pets[index], team.tags[index] or {}
        if id and id ~= "empty" and id ~= "ignored" then
            local pet = Pet(team, index)
            if pet.id then
                local ok, reason = BattleBuddyLoadout.DropPet(index, pet.id)
                if ok then
                    changedSlots = changedSlots + 1
                    local list = pet.species and Read(C_PetJournal.GetPetAbilityList, pet.species)
                    for tier, choice in ipairs(tag.abilities or {}) do
                        if choice > 0 then
                            local ability = C.PublicValueOfType(C.ReadField(list, tier + (choice - 1) * 3), "number")
                            local changed, why
                            if ability then changed, why = BattleBuddyLoadout.ChooseAbility(index, tier, ability) end
                            if not changed then failures[#failures + 1] = why or ("Ability unavailable in slot " .. index) end
                        end
                    end
                else failures[#failures + 1] = reason or ("Unable to load slot " .. index) end
            else
                missing[#missing + 1] = (pet.name or tostring(id)) .. " (slot " .. index .. ")"
            end
        end
    end
    if #failures > 0 then
        if changedSlots > 0 then
            BattleBuddyScript.SetLoadedTeam(nil, nil)
            loadedStore, loadedID = nil, nil
            P.Refresh()
        end
        return Report(table.concat(failures, "; "))
    end
    BattleBuddyScript.SetLoadedTeam(store, teamID)
    loadedStore, loadedID = store, teamID
    if type(P.afterLoad) == "function" then
        local ok, reason = P.afterLoad()
        if not ok then
            BattleBuddyScript.SetLoadedTeam(nil, nil)
            loadedStore, loadedID = nil, nil
            P.Refresh()
            return Report(reason)
        end
    end
    P.Refresh()
    if #missing > 0 then Report("Missing pets: " .. table.concat(missing, ", ")) else Report(nil) end
    return true
end

function P.Toggle(groupID)
    if Combat() or query ~= "" or drag then return end
    local store = Store()
    local group = store and T.GetGroup(store, groupID)
    if group then T.SetGroupExpanded(store, groupID, not group.isExpanded); P.Refresh() end
end

function P.ToggleAll()
    if Combat() or query ~= "" or drag then return end
    local store, any = Store(), false
    if not store then return end
    for _, group in ipairs(T.ListGroups(store)) do if group.isExpanded then any = true end end
    for _, group in ipairs(T.ListGroups(store)) do T.SetGroupExpanded(store, group.groupID, not any) end
    P.Refresh()
end

function P.Move(teamID, groupID, targetID, after)
    if Combat() then return Report("Teams cannot be moved in combat.") end
    if teamID == targetID then return false end
    local store, position = Store(), nil
    if targetID then
        position = 1
        local found = false
        for _, team in ipairs(T.ListTeams(store, groupID)) do
            if team.teamID == targetID then found = true; break end
            if team.teamID ~= teamID then position = position + 1 end
        end
        if not found then return false end
        if after then position = position + 1 end
    end
    local result, reason = T.MoveTeam(store, teamID, groupID, position)
    drag = nil
    P.Refresh()
    if not result then return Report(reason) end
    return true
end

local function Callbacks()
    return { refresh = P.Refresh, load = P.Load, loadedTeamID = loadedStore == Store() and loadedID or nil,
        unload = function()
            if Combat() then return Report("Teams cannot be unloaded in combat.") end
            BattleBuddyScript.SetLoadedTeam(nil, nil)
            loadedID, loadedStore = nil, nil
            P.Refresh()
            return true
        end }
end

local function CloseMenus()
    if Menu and Menu.GetManager then Menu.GetManager():CloseMenus() end
end

local function Drop(row)
    if not drag or Combat() then return end
    local data, after = row.data, false
    if data.kind == "team" or data.kind == "group" then
        local _, y = Read(GetCursorPosition)
        local top, scale = Read(row.GetTop, row), Read(row.GetEffectiveScale, row)
        if type(y) == "number" and type(top) == "number" and type(scale) == "number" and scale > 0 then
            after = y / scale < top - row:GetHeight() / 2
        end
    end
    if drag.teamID then P.Move(drag.teamID, data.groupID, data.teamID, after)
    elseif drag.groupID ~= data.groupID then
        local position = 1
        for _, group in ipairs(T.ListGroups(Store())) do
            if group.groupID == data.groupID then break end
            if group.groupID ~= drag.groupID then position = position + 1 end
        end
        if after then position = position + 1 end
        local result, reason = T.MoveGroup(Store(), drag.groupID, position)
        drag = nil
        P.Refresh()
        if not result then Report(reason) end
    else drag = nil; P.Refresh() end
end

local function Label(parent, font)
    local text = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    return text
end

local function Icon(parent, width, height, point, x, y)
    local texture = parent:CreateTexture(nil, "ARTWORK")
    texture:SetSize(width, height)
    texture:SetPoint(point, parent, point, x, y)
    return texture
end

local function Tip(owner, text)
    if not GameTooltip then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(text)
    GameTooltip:Show()
end

local function Button(parent, width, height, point, x, y)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, height)
    button:SetPoint(point, parent, point, x, y)
    return button
end

function P.BindRow(row, data)
    if Combat() then return end
    if not row.pets then
        row.background = row:CreateTexture(nil, "BACKGROUND")
        row.background:SetColorTexture(0.03, 0.03, 0.03, 0.9)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        row.name, row.subtitle = Label(row), Label(row, "GameFontNormalSmall")
        row.pets, row.petButtons = {}, {}
        for index = 1, 3 do
            local pet = Icon(row, 28, 40, "TOPLEFT", 2 + (index - 1) * 29, -2)
            pet:SetTexCoord(0.203125, 0.796875, 0.078125, 0.921875)
            row.pets[index] = pet
            local hit = Button(row, 28, 40, "TOPLEFT", 2 + (index - 1) * 29, -2)
            hit:SetScript("OnEnter", function(self)
                local info = Pet(row.data.team, index)
                Tip(self, (info.name or "Unknown pet") .. "\nPet card: Not available yet")
            end)
            hit:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
            hit:SetScript("OnClick", function() Report("Pet card: Not available yet") end)
            row.petButtons[index] = hit
        end
        row.glyph = Icon(row, 20, 20, "LEFT", 3, 0)
        row.favorite = Icon(row, 21, 21, "TOPLEFT", -5, 3)
        row.favorite:SetAtlas("PetJournal-FavoritesIcon")
        row.options = Button(row, 20, 20, "RIGHT", -4, 0)
        row.options:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
        row.options:SetScript("OnClick", function()
            if Combat() then return end
            local d = row.data
            if d.kind == "group" then BattleBuddyTeamMenus.Group(row.options, Store(), d.groupID, Callbacks())
            elseif d.kind == "team" then BattleBuddyTeamMenus.Team(row.options, Store(), d.teamID, Callbacks()) end
        end)
        row.script = Button(row, 18, 18, "TOPRIGHT", -26, -3)
        row.script:SetNormalTexture("Interface\\Icons\\INV_Scroll_03")
        row.script:SetScript("OnEnter", function(self) Tip(self, "Edit Script") end)
        row.script:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        row.script:SetScript("OnClick", function()
            if Combat() or row.data.kind ~= "team" then return end
            BattleBuddySaveTeamDialog.Open("save", { store = Store(), teamID = row.data.teamID, tab = "script" })
        end)
        row.notes = Icon(row, 14, 14, "TOPRIGHT", -46, -5)
        row.notes:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
        row.target = Icon(row, 14, 14, "BOTTOMRIGHT", -26, 4)
        row.target:SetTexture("Interface\\Icons\\Ability_Hunter_SniperShot")
        row.wins = Label(row, "GameFontHighlightSmall")
        row.wins:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -44, 4)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:RegisterForDrag("LeftButton")
        row:SetScript("OnClick", function(self, button)
            if self.dropClick then self.dropClick = nil; return end
            if Combat() then
                if button == "LeftButton" and self.data.kind == "team" then P.Load(self.data.teamID) end
                return
            end
            if drag then
                if button == "RightButton" then drag = nil; P.Refresh() else Drop(self) end
                return
            end
            if button == "RightButton" then
                if self.data.kind == "group" then BattleBuddyTeamMenus.Group(self, Store(), self.data.groupID, Callbacks())
                elseif self.data.kind == "team" then BattleBuddyTeamMenus.Team(self, Store(), self.data.teamID, Callbacks()) end
            elseif self.data.kind == "group" then P.Toggle(self.data.groupID)
            elseif self.data.kind == "team" then P.Load(self.data.teamID) end
        end)
        row:SetScript("OnDragStart", function(self)
            if Combat() or self.noPickup or self.data.kind == "empty"
                or (self.data.kind == "group" and self.data.group.meta) then return end
            drag = { teamID = self.data.teamID, groupID = self.data.groupID }
            query = ""
            if P.frame then P.frame.search:SetText("") end
            CloseMenus()
            P.Refresh()
        end)
        row:SetScript("OnDragStop", function()
            if not drag then return end
            local destination = drag.over
            if destination then Drop(destination) else drag = nil; P.Refresh() end
        end)
        row:SetScript("OnMouseUp", function(self, button)
            if drag and button == "LeftButton" then
                self.dropClick = true
                Drop(self)
            end
        end)
        row:SetScript("OnReceiveDrag", Drop)
        row:SetScript("OnEnter", function(self)
            if drag then drag.over = self end
            local d = self.data
            Tip(self, d.team and d.team.name or d.group and d.group.name or "Drop a team here")
        end)
        row:SetScript("OnLeave", function(self)
            if drag and drag.over == self then drag.over = nil end
            self.dropClick = nil
            if GameTooltip then GameTooltip:Hide() end
        end)
    end
    row.data = data
    local isTeam, isGroup = data.kind == "team", data.kind == "group"
    row:SetHeight(isTeam and 44 or 26)
    row.background:ClearAllPoints()
    row.background:SetPoint("TOPLEFT", row, "TOPLEFT", isTeam and 91 or 0, -1)
    row.background:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    local selected = isTeam and loadedStore == Store() and loadedID == data.teamID
    row.background:SetColorTexture(selected and 0.3 or 0.03, selected and 0.24 or 0.025, 0.015, 0.9)
    row.name:ClearAllPoints()
    row.name:SetPoint("TOPLEFT", row, "TOPLEFT", isTeam and 97 or 27, isTeam and -4 or -5)
    row.name:SetPoint("RIGHT", row, "RIGHT", isTeam and -62 or -26, 0)
    row.name:SetTextColor(1, 0.82, 0)
    row.subtitle:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -1)
    row.subtitle:SetPoint("RIGHT", row, "RIGHT", -62, 0)
    row.subtitle:SetText("")
    row.subtitle:SetShown(isTeam)
    row.options:SetShown(isTeam or isGroup)
    row.glyph:SetShown(isGroup)
    row.glyph:SetTexture(data.expanded and "Interface\\Buttons\\UI-MinusButton-Up" or "Interface\\Buttons\\UI-PlusButton-Up")
    row.glyph:SetDesaturated(query ~= "" or drag ~= nil)
    row.favorite:SetShown(isTeam and data.team.favorite == true)
    row.script:SetShown(isTeam and type(data.team.script) == "string" and data.team.script:match("%S") ~= nil)
    row.notes:SetShown(isTeam and data.team.notes ~= nil)
    row.target:SetShown(isTeam and data.team.targets ~= nil)
    row.wins:SetText("")
    for index, icon in ipairs(row.pets) do
        icon:SetShown(isTeam)
        row.petButtons[index]:SetShown(isTeam)
        if isTeam then
            local pet = Pet(data.team, index)
            icon:SetTexture(pet.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            icon:SetDesaturated(pet.id == nil)
        end
    end
    if isTeam then
        row.name:SetText(data.team.name)
        local target = data.team.targets and data.team.targets[1]
        local name = target and data.team.targetNames and data.team.targetNames[target]
        row.subtitle:SetText(name ~= data.team.name and name or "")
        local record = data.team.winrecord
        if record and record.battles > 0 then
            local percent = math.floor(record.wins / record.battles * 100 + 0.5)
            row.wins:SetText(percent .. "%")
            row.wins:SetTextColor(percent >= 60 and 0.25 or 1, percent <= 40 and 0.25 or 0.75, 0.25)
        end
    elseif isGroup then
        row.name:SetText(data.group.name)
        local color = data.group.color
        if color then row.name:SetTextColor(tonumber(color:sub(1, 2), 16) / 255,
            tonumber(color:sub(3, 4), 16) / 255, tonumber(color:sub(5, 6), 16) / 255) end
        row.options:SetNormalTexture(data.group.icon or "Interface\\Buttons\\UI-OptionsButton")
    else
        row.name:SetText(data.groupID == "group:favorites" and "No favorite teams"
            or data.groupID == "group:none" and "No ungrouped teams" or "No teams in this group")
        row.name:SetTextColor(0.5, 0.5, 0.5)
    end
    if isTeam then row.options:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton") end
end

function P.Refresh()
    local frame, store = P.frame, Store()
    if not frame or Combat() then return end
    if loadedStore and loadedID and not T.GetTeam(loadedStore, loadedID) then
        loadedStore, loadedID = nil, nil
        BattleBuddyScript.SetLoadedTeam(nil, nil)
    end
    if BattleBuddyLoadout and BattleBuddyLoadout.Refresh then BattleBuddyLoadout.Refresh() end
    frame.scrollBox:SetDataProvider(CreateDataProvider(P.Rows(store, query)), true)
    local groups = store and store.groupsByID and T.ListGroups(store) or {}
    frame.scrollBox.data = #groups > 0 and { kind = "empty", groupID = groups[#groups].groupID } or nil
    frame.search.placeholder:SetShown(query == "")
    frame.all:SetEnabled(query == "" and not drag)
    local any = false
    if store and store.groupsByID then
        for _, group in ipairs(T.ListGroups(store)) do if group.isExpanded then any = true end end
    end
    frame.all.glyph:SetTexture(any and "Interface\\Buttons\\UI-MinusButton-Up" or "Interface\\Buttons\\UI-PlusButton-Up")
    frame.all.glyph:SetDesaturated(query ~= "" or drag ~= nil)
end

function P.SelectView(name)
    if not P.frame or Combat() then return end
    P.frame:SetShown(name == "teams")
    local placeholder = P.frame:GetParent()["label"]
    if placeholder then placeholder:SetShown(name ~= "teams") end
    if name == "teams" then P.Refresh() else P.preview, drag = nil, nil end
end

function P.SetPreview(enabled)
    if Combat() then return end
    P.preview = nil
    if enabled and BattleBuddyDB and #T.ListTeams(BattleBuddyDB) == 0 then
        previewStore = T.Initialize()
        local group = T.CreateGroup(previewStore, { name = "Preview group", isExpanded = true })
        T.CreateTeam(previewStore, { name = "Preview team", groupID = group.groupID, pets = { 39, 40, 41 },
            script = "standby", targets = { { npcID = 1, name = "Preview target" } } })
        P.preview = true
    end
    P.Refresh()
end

function P.Mount(parent)
    if P.frame or Combat() then return end
    local frame = CreateFrame("Frame", nil, parent)
    P.frame = frame
    frame:SetAllPoints()
    frame.top = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
    frame.top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    frame.top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    frame.top:SetHeight(29)
    frame.all = CreateFrame("Button", nil, frame.top, "UIPanelButtonTemplate")
    frame.all:SetSize(64, 24)
    frame.all:SetPoint("TOPLEFT", frame.top, "TOPLEFT", 3, -3)
    frame.all:SetText("All")
    frame.all.glyph = Icon(frame.all, 16, 16, "LEFT", 2, 0)
    frame.all:SetScript("OnClick", P.ToggleAll)
    frame.menu = CreateFrame("Button", nil, frame.top, "UIPanelButtonTemplate")
    frame.menu:SetSize(80, 24)
    frame.menu:SetPoint("TOPRIGHT", frame.top, "TOPRIGHT", -3, -3)
    frame.menu:SetText("Teams  |TInterface\\Buttons\\UI-SpellbookIcon-NextPage-Up:12|t")
    frame.menu:SetScript("OnClick", function(self)
        if not Combat() and Store() then BattleBuddyTeamMenus.Teams(self, Store(), Callbacks()) end
    end)
    frame.search = CreateFrame("EditBox", nil, frame.top, "SearchBoxTemplate")
    frame.search:SetPoint("LEFT", frame.all, "RIGHT", -1, 0)
    frame.search:SetPoint("RIGHT", frame.menu, "LEFT", 1, 0)
    frame.search:SetHeight(24)
    frame.search:SetAutoFocus(false)
    frame.search:SetMaxLetters(128)
    frame.search:SetTextInsets(24, 19, 0, 0)
    frame.search:SetFontObject("GameFontHighlightSmall")
    if frame.search.searchIcon then
        frame.search.searchIcon:ClearAllPoints()
        frame.search.searchIcon:SetPoint("LEFT", frame.search, "LEFT", 6, 0)
    end
    frame.search.placeholder = frame.search.Instructions or Label(frame.search, "GameFontDisableSmall")
    frame.search.placeholder:ClearAllPoints()
    frame.search.placeholder:SetPoint("LEFT", frame.search, "LEFT", 24, 0)
    frame.search.placeholder:SetText("Search Teams")
    frame.search:HookScript("OnTextChanged", function(self)
        query = C.PublicValueOfType(self:GetText(), "string") or ""
        local gray = query:lower():match("^battlepet%-.+") and 0.5 or 1
        self:SetTextColor(gray, gray, gray)
        P.Refresh()
    end)
    frame.search:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus(); query = ""; P.Refresh() end)
    frame.scrollBox = CreateFrame("Frame", nil, frame, "WowScrollBoxList")
    frame.scrollBox:SetPoint("TOPLEFT", frame.top, "BOTTOMLEFT", 0, -2)
    frame.scrollBox:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 0)
    frame.scrollBar = CreateFrame("EventFrame", nil, frame, "MinimalScrollBar")
    frame.scrollBar:SetPoint("TOPLEFT", frame.scrollBox, "TOPRIGHT", 3, 0)
    frame.scrollBar:SetPoint("BOTTOMLEFT", frame.scrollBox, "BOTTOMRIGHT", 3, 0)
    local view = CreateScrollBoxListLinearView()
    view:SetElementInitializer("Button", P.BindRow)
    view:SetElementExtentCalculator(function(_, data) return data.kind == "team" and 44 or 26 end)
    ScrollUtil.InitScrollBoxListWithScrollBar(frame.scrollBox, frame.scrollBar, view)
    frame.scrollBox:RegisterCallback("OnScroll", CloseMenus, P)
    frame.scrollBox:SetScript("OnReceiveDrag", function()
        if not drag or not drag.teamID then return end
        local groups = T.ListGroups(Store())
        if #groups > 0 then P.Move(drag.teamID, groups[#groups].groupID) end
    end)
    frame.scrollBox:SetScript("OnEnter", function(self) if drag and self.data then drag.over = self end end)
    frame.scrollBox:SetScript("OnLeave", function(self) if drag and drag.over == self then drag.over = nil end end)
    frame.scrollBox:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then drag = nil; P.Refresh()
        elseif drag and self.data then Drop(self) end
    end)
    frame.message = Label(frame, "GameFontHighlightSmall")
    frame.message:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 4, 2)
    frame.message:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 2)
    frame.message:SetWordWrap(true)
    frame.message:SetText("")
    frame:SetScript("OnShow", P.Refresh)
    frame:SetScript("OnHide", function() P.preview, drag = nil, nil; CloseMenus() end)
    P.SelectView(BattleBuddyWindow.view or "teams")
end

if CreateFrame then
    P.events = CreateFrame("Frame")
    for _, event in ipairs({ "PET_JOURNAL_LIST_UPDATE", "PET_JOURNAL_PET_DELETED", "PLAYER_REGEN_ENABLED" }) do
        P.events:RegisterEvent(event)
    end
    P.events:SetScript("OnEvent", P.Refresh)
end

if hooksecurefunc and BattleBuddyWindow then hooksecurefunc(BattleBuddyWindow, "SelectView", P.SelectView) end
if hooksecurefunc and BattleBuddyScript then
    hooksecurefunc(BattleBuddyScript, "SetLoadedTeam", function(store, id)
        if not (store == nil and id == nil) and (type(store) ~= "table" or type(store.teamsByID) ~= "table"
            or type(id) ~= "string" or not T.GetTeam(store, id)) then return end
        loadedStore, loadedID = store, id
        P.Refresh()
    end)
end
