BattleBuddySaveTeamDialog = {}

local Dialog = BattleBuddySaveTeamDialog
local Teams, Compatibility = BattleBuddyTeams, BattleBuddyCompatibility
local loadedStore, loadedID, registered
local Refresh, Build
local tabs = { "Team", "Targets", "Preferences", "Wins" }
local families = { "Humanoid", "Dragonkin", "Flying", "Undead", "Critter", "Magic", "Elemental", "Beast", "Aquatic", "Mechanical" }

local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = Copy(item) end
    return result
end

local function Equal(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for key, value in pairs(a) do if not Equal(value, b[key]) then return false end end
    for key in pairs(b) do if a[key] == nil then return false end end
    return true
end

local function ReadAPI(api, name, ...)
    local fn = Compatibility.ReadField(api, name)
    if type(fn) ~= "function" then return end
    local function Pack(...) return {n = select("#", ...), ...} end
    local values = Pack(pcall(fn, ...))
    if not values[1] then return end
    for i = 2, values.n do values[i] = Compatibility.PublicValue(values[i]) end
    return unpack(values, 2, values.n)
end

local function Read(name, ...) return ReadAPI(C_PetJournal, name, ...) end

local function Sound(name)
    if PlaySound and SOUNDKIT and SOUNDKIT[name] then PlaySound(SOUNDKIT[name]) end
end

local function Number(value)
    value = Compatibility.PublicValueOfType(value, "number")
    if value and value >= 0 and value < math.huge then return value end
end

local function Target(value)
    local state = Compatibility.ReadField(value, "state")
    if state == "ambiguous" or state == "secret" then return end
    local id = Number(Compatibility.ReadField(value, "npcID"))
    local name = Compatibility.PublicValueOfType(Compatibility.ReadField(value, "name"), "string")
    if name then name = name:match("^%s*(.-)%s*$"); if name == "" then name = nil end end
    if id and id > 0 and id % 1 == 0 then return id, name or ("NPC " .. id) end
    if name then
        local key = name:lower():gsub("[%p%s]+$", "")
        if key ~= "" then return "name:" .. key, name end
    end
end

local function UniqueName(name)
    if not Teams.FindByName(Dialog.store, name) then return name end
    local base, i = name:gsub(" %(%d+%)$", ""), 2
    while Teams.FindByName(Dialog.store, base .. " (" .. i .. ")") do i = i + 1 end
    return base .. " (" .. i .. ")"
end

local function Loadout()
    local pets, tags = {}, {}
    for slot = 1, 3 do
        local pet, a, b, c = Read("GetPetLoadOutInfo", slot)
        pet = Compatibility.PublicValueOfType(pet, "string")
        pets[slot], tags[slot] = pet or "empty", {}
        if pet then
            local species = Number(Read("GetPetInfoByPetID", pet))
            if species and species > 0 then
                local choices, selected = {}, {a, b, c}
                local abilities = Read("GetPetAbilityList", species)
                for tier = 1, 3 do
                    local first = Number(Compatibility.ReadField(abilities, tier))
                    local second = Number(Compatibility.ReadField(abilities, tier + 3))
                    local chosen = Number(selected[tier])
                    choices[tier] = chosen and first and chosen == first and 1
                        or chosen and second and chosen == second and 2 or 0
                end
                tags[slot] = {speciesID = species, abilities = choices}
            end
        end
    end
    return pets, tags
end

function Dialog.IsDirty()
    return Dialog.draft ~= nil and not Equal(Dialog.draft, Dialog.original)
end

function Dialog.CanSave()
    local draft = Dialog.draft
    if not draft or not draft.name:find("%S") then return false, "Enter a team name." end
    local p = draft.preferences or {}
    for _, key in ipairs({ "minXP", "maxXP", "minHP", "maxHP", "expectedDD" }) do
        local value = p[key]
        if value ~= nil and (not Number(value) or (key:find("XP") and value > 25)
            or (key == "expectedDD" and (value < 1 or value > 10 or value % 1 ~= 0))) then
            return false, "Enter valid preference values."
        end
    end
    if (p.minXP and p.maxXP and p.minXP > p.maxXP) or (p.minHP and p.maxHP and p.minHP > p.maxHP) then
        return false, "Minimum must not exceed maximum."
    end
    for _, value in pairs(draft.winrecord or {}) do
        if not Number(value) or value % 1 ~= 0 then return false, "Records require whole, non-negative counts." end
    end
    return true
end

function Dialog.SetName(value)
    Dialog.draft.name = value
    Refresh()
end

function Dialog.SetPreference(key, value)
    local allowed = {minXP = true, maxXP = true, minHP = true, maxHP = true, expectedDD = true, allowMM = true}
    if not allowed[key] then return false end
    local p = Dialog.draft.preferences
    if key == "allowMM" then p[key] = value == true and true or nil
    elseif value == "" or value == nil then p[key] = nil
    else p[key] = tonumber(value) or value end
    Refresh()
    return true
end

function Dialog.SetWins(key, value)
    if key ~= "wins" and key ~= "losses" and key ~= "draws" then return false end
    value = tonumber(value) or 0
    if not Number(value) or value % 1 ~= 0 then Refresh(); return false end
    Dialog.draft.winrecord[key] = value
    Refresh()
    return true
end

function Dialog.WinSummary()
    local w = Dialog.draft.winrecord
    local total = (w.wins or 0) + (w.losses or 0) + (w.draws or 0)
    return {battles = total, rate = total > 0 and (w.wins or 0) * 100 / total or nil}
end

function Dialog.SelectTab(tab)
    for _, name in ipairs(tabs) do
        if name == tab then Dialog.tab = tab; Dialog.picking = false; Refresh(); return true end
    end
    return false
end

function Dialog.ClearTab(tab)
    local fields = {Targets = "targets", Preferences = "preferences", Wins = "winrecord"}
    local field = fields[tab or Dialog.tab]
    if field then
        Dialog.draft[field] = {}
        if field == "targets" then Dialog.draft.targetNames = {}; Dialog.selected = nil end
    else
        Dialog.draft.targets, Dialog.draft.targetNames, Dialog.draft.preferences, Dialog.draft.winrecord = {}, {}, {}, {}
        Dialog.selected = nil
    end
    Refresh()
end

function Dialog.AddTarget(value)
    local id, name = Target(value)
    if not id then return false end
    local list = Dialog.draft.targets
    for i, existing in ipairs(list) do
        if existing == id then Dialog.selected = i; Dialog.picking = false; Refresh(); return true end
    end
    list[#list + 1], Dialog.draft.targetNames[id] = id, name
    Dialog.selected, Dialog.picking = #list, false
    Refresh()
    return true
end

function Dialog.RemoveTarget(index)
    local list = Dialog.draft.targets
    if not index or not list[index] then return false end
    Dialog.draft.targetNames[table.remove(list, index)] = nil
    Dialog.selected = #list > 0 and math.min(index, #list) or nil
    Refresh()
    return true
end

function Dialog.MoveTarget(index, offset)
    local list = Dialog.draft.targets
    if not index or not list[index] or not list[index + offset] then return false end
    list[index], list[index + offset] = list[index + offset], list[index]
    Dialog.selected = index + offset
    Refresh()
    return true
end

function Dialog.Reset()
    Dialog.draft = Copy(Dialog.original)
    Dialog.tab, Dialog.selected, Dialog.picking = "Team", nil, false
    Dialog.frame.confirm:Hide()
    Refresh()
end

function Dialog.Close()
    if Dialog.frame and Dialog.frame:IsShown() then Sound("IG_MAINMENU_CLOSE") end
    if Dialog.frame then Dialog.frame.confirm:Hide(); Dialog.frame:Hide() end
    Dialog.draft, Dialog.original, Dialog.onSaved = nil, nil, nil
end

local function Confirm(kind, old)
    Dialog.confirmKind = kind
    local f = Dialog.frame.confirm
    Dialog.frame.name:ClearFocus()
    for _, edit in pairs(Dialog.frame.preferences) do edit:ClearFocus() end
    for _, edit in pairs(Dialog.frame.wins) do edit:ClearFocus() end
    f.title:SetText(kind == "collision" and "Overwrite Team" or "Saving Loaded Team")
    f.oldLabel:SetText("Old " .. old.name)
    f.newLabel:SetText("New " .. Dialog.draft.name)
    Dialog.RenderPreview(f.oldPreview, old)
    Dialog.RenderPreview(f.newPreview, Dialog.draft)
    f.overwrite:SetText(kind == "collision" and "Overwrite" or "Yes")
    f.copy:SetShown(kind == "collision")
    f:Show()
end

function Dialog.Save(choice)
    local valid, reason = Dialog.CanSave()
    if not valid then return nil, reason end
    local draft = Copy(Dialog.draft)
    draft.name = draft.name:match("^%s*(.-)%s*$")
    local owner = Teams.FindByName(Dialog.store, draft.name)
    local destination = Dialog.mode == "save" and Dialog.teamID or nil
    if not destination and owner and Dialog.store == loadedStore and owner.teamID == loadedID and choice ~= "copy" then
        destination = loadedID
    end
    if owner and owner.teamID ~= destination then
        if choice ~= "overwrite" and choice ~= "copy" then Confirm("collision", owner); return nil, "name_conflict" end
        if choice == "copy" then destination = nil; draft.name = UniqueName(draft.name)
        else destination = destination or owner.teamID end
    elseif destination and Dialog.fromLoadout and not Equal(
        {Teams.GetTeam(Dialog.store, destination).pets, Teams.GetTeam(Dialog.store, destination).tags}, {draft.pets, draft.tags})
        and choice ~= "overwrite" then
        Confirm("loaded", Teams.GetTeam(Dialog.store, destination)); return nil, "loadout_changed"
    end
    draft.teamID = nil
    draft.notes, draft.script = draft.notes or "", draft.script or ""
    -- Validate the complete transaction before deleting a collided identity.
    local trial = Teams.Initialize(Dialog.store)
    if not trial then return nil, "unavailable_store" end
    if owner and choice == "overwrite" and owner.teamID ~= destination then Teams.DeleteTeam(trial, owner.teamID, true) end
    local result, err
    if destination then result, err = Teams.EditTeam(trial, destination, draft)
    else result, err = Teams.CreateTeam(trial, draft) end
    if not result then return nil, err end
    if owner and choice == "overwrite" and owner.teamID ~= destination then Teams.DeleteTeam(Dialog.store, owner.teamID, true) end
    if destination then result, err = Teams.EditTeam(Dialog.store, destination, draft)
    else result, err = Teams.CreateTeam(Dialog.store, draft) end
    if not result then return nil, err end
    local callback = Dialog.onSaved
    Dialog.Close()
    if callback then callback(result.teamID) end
    return result.teamID
end

function Dialog.Open(mode, opts)
    opts = opts or {}
    if mode ~= "save" and mode ~= "saveAs" then return nil, "invalid_mode" end
    if Compatibility.PublicValueOfType(InCombatLockdown(), "boolean") ~= false then return nil, "combat" end
    local store = opts.store or loadedStore or BattleBuddyDB
    if not store then return nil, "unavailable_store" end
    local id = opts.teamID or (mode == "save" and loadedID)
    local team = id and Teams.GetTeam(store, id)
    if id and not team then return nil, "unknown_team" end
    if mode == "save" and not team then return nil, "no_loaded_team" end
    Dialog.store, Dialog.mode, Dialog.teamID = store, mode, id
    local draft = team or {name = "New Team", groupID = "group:none"}
    Dialog.fromLoadout = not opts.teamID
    if Dialog.fromLoadout then draft.pets, draft.tags = Loadout() end
    if mode == "saveAs" then draft.name = UniqueName(opts.teamID and draft.name or "New Team") end
    draft.teamID = nil
    if not Teams.GetGroup(store, draft.groupID) then draft.groupID = "group:none" end
    draft.targets, draft.targetNames = draft.targets or {}, draft.targetNames or {}
    draft.preferences, draft.winrecord = draft.preferences or {}, draft.winrecord or {}
    draft.winrecord.battles = nil
    Dialog.draft, Dialog.onSaved = draft, opts.onSaved
    Dialog.tab, Dialog.selected, Dialog.picking, Dialog.query, Dialog.collapsed = "Team", nil, false, "", {}
    if not Dialog.frame then Build() end
    if Menu and Menu.GetManager then Menu.GetManager():CloseMenus() end
    if Dialog.fromLoadout and BattleBuddyTargetDetection then Dialog.AddTarget(BattleBuddyTargetDetection.Current()) end
    Dialog.original = Copy(draft)
    Dialog.frame.confirm:Hide()
    Refresh()
    Dialog.frame:Show()
    Sound("IG_MAINMENU_OPEN")
    return Dialog.frame
end

local function Label(parent, text, x, y, template)
    local label = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetText(text)
    return label
end

local function Button(parent, text, x, y, width, callback)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 23)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    button:SetText(text)
    button:SetScript("OnClick", callback)
    return button
end

local function Edit(parent, x, y, width, callback, numeric)
    local edit = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    edit:SetSize(width, 24); edit:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y); edit:SetAutoFocus(false)
    edit:SetScript("OnTextChanged", function(self, user)
        if not user or Dialog.refreshing then return end
        local text = self:GetText()
        if numeric then
            text = text:gsub(numeric == "integer" and "[^%d]" or "[^%d.]", "")
            if text ~= self:GetText() then self:SetText(text) end
        end
        callback(text)
    end)
    edit:SetScript("OnEnterPressed", function() Dialog.Save() end)
    edit:SetScript("OnEscapePressed", function() Dialog.Close() end)
    edit.clear = Button(edit, "x", width - 18, 0, 18, function() edit:SetText(""); callback("") end)
    return edit
end

local function Preview(parent, x, y)
    local preview = CreateFrame("Frame", nil, parent)
    preview:SetSize(290, 76); preview:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    preview.slots = {}
    for i = 1, 3 do
        local slot = CreateFrame("Frame", nil, preview)
        slot:SetSize(76, 76); slot:SetPoint("TOPLEFT", preview, "TOPLEFT", (i - 1) * 105, 0)
        slot.border = slot:CreateTexture(nil, "BACKGROUND"); slot.border:SetSize(48, 48)
        slot.border:SetPoint("TOPLEFT", slot, "TOPLEFT", -2, -14)
        slot.icon = slot:CreateTexture(nil, "ARTWORK"); slot.icon:SetSize(44, 44)
        slot.icon:SetPoint("TOPLEFT", slot, "TOPLEFT", 0, -16)
        slot.level = Label(slot, "", 32, -50, "GameFontHighlightSmall")
        slot.favorite = Label(slot, "", 0, -16)
        slot.abilities = {}
        for tier = 1, 3 do
            local icon = slot:CreateTexture(nil, "ARTWORK"); icon:SetSize(22, 22)
            icon:SetPoint("TOPLEFT", slot, "TOPLEFT", 54, -(tier - 1) * 26)
            slot.abilities[tier] = icon
        end
        preview.slots[i] = slot
    end
    return preview
end

function Dialog.RenderPreview(preview, team)
    for i = 1, 3 do
        local slot, pet, tag = preview.slots[i], team.pets[i], team.tags[i] or {}
        local species, level, favorite, icon, quality
        if type(pet) == "string" and pet:match("^BattlePet%-") then
            local _, _, petLevel, _, _, _, isFavorite, _, petIcon = Read("GetPetInfoByPetID", pet)
            level, favorite, icon = Number(petLevel), isFavorite == true, Number(petIcon)
            local _, _, _, _, rarity = Read("GetPetStats", pet)
            quality = Number(rarity)
        end
        species = tag.speciesID or (type(pet) == "number" and pet > 0 and pet)
        if not icon and species then local _, texture = Read("GetPetInfoBySpeciesID", species); icon = Number(texture) end
        slot.icon:SetTexture(icon or 134400)
        slot.level:SetText(level and tostring(level) or "")
        slot.favorite:SetText(favorite and "*" or "")
        local colors = {{0.6, 0.6, 0.6}, {1, 1, 1}, {0.1, 1, 0.1}, {0, 0.5, 1}}
        local color = colors[quality or 1] or colors[1]
        slot.border:SetColorTexture(unpack(color))
        local abilities = species and Read("GetPetAbilityList", species)
        for tier = 1, 3 do
            local choice = tag.abilities and tag.abilities[tier]
            local ability = choice and choice > 0 and Number(Compatibility.ReadField(abilities, tier + (choice - 1) * 3))
            local _, texture
            if ability then _, texture = Read("GetPetAbilityInfo", ability) end
            slot.abilities[tier]:SetTexture(Number(texture) or 134400)
        end
    end
end

local function TargetChoices()
    local result, seen = {}, {}
    local function Add(value, group, search, quest)
        local id, name = Target(value)
        if id and not seen[id] then
            seen[id] = true; result[#result + 1] = {id = id, name = name, group = group, search = search, quest = quest}
        end
    end
    local known = {}
    for _, record in ipairs(BattleBuddyEncounterContent and BattleBuddyEncounterContent.Records or {}) do
        for _, selector in ipairs(record.selectors) do known[selector.npcID] = record end
    end
    if BattleBuddyTargetDetection then
        Add(BattleBuddyTargetDetection.Current(), "Recent Targets")
        for _, id in ipairs(BattleBuddyTargetDetection.GetRecent()) do
            local record = known[id]
            Add({npcID = id, name = record and record.display.fallbackLabel}, "Recent Targets")
        end
    end
    seen = {}
    for _, record in ipairs(BattleBuddyEncounterContent and BattleBuddyEncounterContent.Records or {}) do
        local content = record.content
        local quest = content.questID and Compatibility.PublicValueOfType(
            ReadAPI(C_QuestLog, "GetTitleForQuestID", content.questID), "string")
        local search = (quest or "") .. " " .. (content.expansion or "")
        for _, pet in ipairs(content.enemyPets or {}) do
            local name = pet.speciesID and Compatibility.PublicValueOfType(Read("GetPetInfoBySpeciesID", pet.speciesID), "string")
            search = search .. " " .. (name or "")
        end
        for _, selector in ipairs(record.selectors) do
            for _, team in ipairs(Teams.ListByTarget(Dialog.store, selector.npcID)) do search = search .. " " .. team.name end
            Add({npcID = selector.npcID, name = record.display.fallbackLabel}, content.zone or "Known Targets", search, quest)
        end
    end
    for _, team in ipairs(Teams.ListTeams(Dialog.store)) do
        for _, id in ipairs(team.targets or {}) do
            Add({npcID = type(id) == "number" and id or nil, name = (team.targetNames or {})[id]
                or (type(id) == "string" and id:sub(6))}, "Saved Targets", team.name)
        end
    end
    return result
end

Build = function()
    local f = CreateFrame("Frame", "BattleBuddySaveTeamDialogFrame", UIParent, "ButtonFrameTemplate")
    Dialog.frame = f
    f:SetSize(366, 385); f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetFrameStrata("DIALOG"); f:SetMovable(true); f:SetClampedToScreen(true); f:EnableMouse(true)
    f:RegisterForDrag("LeftButton"); f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
    if ButtonFrameTemplate_HidePortrait then ButtonFrameTemplate_HidePortrait(f) end
    Label(f, "Save Team", 142, -7)
    if f.CloseButton then f.CloseButton:SetScript("OnClick", function() Dialog.Close() end)
    else Button(f, "X", 341, -2, 22, function() Dialog.Close() end) end
    f:EnableKeyboard(true)
    f:SetScript("OnKeyDown", function(self, key)
        self:SetPropagateKeyboardInput(key ~= "ESCAPE")
        if key == "ESCAPE" then
            if f.confirm:IsShown() then f.confirm:Hide() else Dialog.Close() end
        end
    end)
    f.pages, f.tabs = {}, {}
    local canvas = CreateFrame("Frame", nil, f)
    canvas:SetPoint("TOPLEFT", f, "TOPLEFT", 9, -37); canvas:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -11, 32)
    local background = canvas:CreateTexture(nil, "BACKGROUND"); background:SetAllPoints(canvas)
    background:SetTexture("Interface\\FrameGeneral\\UI-Background-Marble")
    for index, name in ipairs(tabs) do
        local widths = {52, 62, 91, 47}
        local x = 6; for i = 1, index - 1 do x = x + widths[i] end
        f.tabs[name] = Button(canvas, name, x, -6, widths[index], function() Dialog.SelectTab(name) end)
        local page = CreateFrame("Frame", nil, canvas)
        page:SetPoint("TOPLEFT", canvas, "TOPLEFT", 6, -36); page:SetSize(330, 250)
        f.pages[name] = page
    end
    f.clear = Button(canvas, "x", 318, -6, 18, function() Dialog.ClearTab() end)
    local team = f.pages.Team
    Label(team, "Name:", 16, -34)
    f.name = Edit(team, 70, -28, 216, Dialog.SetName)
    f.names = CreateFrame("DropdownButton", nil, team, "WowStyle1DropdownTemplate")
    f.names:SetSize(24, 24); f.names:SetPoint("TOPLEFT", team, "TOPLEFT", 286, -28)
    f.names:SetupMenu(function(_, menu)
        local seen = {}
        local function Add(name)
            if name and name ~= "" and not seen[name:lower()] then
                seen[name:lower()] = true; menu:CreateButton(name, function() Dialog.SetName(name) end)
            end
        end
        Add(Dialog.draft.name)
        for _, id in ipairs(Dialog.draft.targets) do Add(Dialog.draft.targetNames[id]) end
        local choices = TargetChoices()
        for _, choice in ipairs(choices) do
            for _, id in ipairs(Dialog.draft.targets) do if choice.id == id then Add(choice.quest) end end
        end
        for _, choice in ipairs(choices) do if choice.group == "Recent Targets" then Add(choice.name) end end
        Add("New Team")
    end)
    Label(team, "Group:", 16, -74)
    f.group = CreateFrame("DropdownButton", nil, team, "WowStyle1DropdownTemplate")
    f.group:SetSize(240, 26); f.group:SetPoint("TOPLEFT", team, "TOPLEFT", 70, -67)
    f.group:SetupMenu(function(_, menu)
        for _, group in ipairs(Teams.ListGroups(Dialog.store)) do
            menu:CreateRadio(group.name, function() return Dialog.draft.groupID == group.groupID end,
                function() Dialog.draft.groupID = group.groupID; Refresh() end)
        end
    end)
    f.preview = Preview(team, 20, -122)
    f.feedback = Label(team, "", 12, -218, "GameFontHighlightSmall"); f.feedback:SetWidth(310)
    local targetPage = f.pages.Targets
    f.add = Button(targetPage, "Add", 8, -4, 68, function() Dialog.picking = true; Refresh() end)
    f.delete = Button(targetPage, "Delete", 78, -4, 68, function() Dialog.RemoveTarget(Dialog.selected) end)
    f.up = Button(targetPage, "Up", 148, -4, 68, function() Dialog.MoveTarget(Dialog.selected, -1) end)
    f.down = Button(targetPage, "Down", 218, -4, 68, function() Dialog.MoveTarget(Dialog.selected, 1) end)
    f.all = Button(targetPage, "All", 8, -4, 48, function()
        local collapse = false
        for _, entry in ipairs(TargetChoices()) do if not Dialog.collapsed[entry.group] then collapse = true end end
        for _, entry in ipairs(TargetChoices()) do Dialog.collapsed[entry.group] = collapse end
        Refresh()
    end)
    f.search = Edit(targetPage, 64, -4, 150, function(value) Dialog.query = value; Refresh() end)
    f.search:SetText("")
    f.search.hint = Label(f.search, "Search Targets", 0, -5, "GameFontHighlightSmall")
    f.pickerCancel = Button(targetPage, "Cancel", 224, -4, 62, function() Dialog.picking = false; Refresh() end)
    f.targetScroll = CreateFrame("ScrollFrame", nil, targetPage, "UIPanelScrollFrameTemplate")
    f.targetScroll:SetSize(280, 192); f.targetScroll:SetPoint("TOPLEFT", targetPage, "TOPLEFT", 8, -34)
    f.targetContent = CreateFrame("Frame", nil, f.targetScroll); f.targetContent:SetSize(280, 192)
    f.targetScroll:SetScrollChild(f.targetContent); f.targetRows = {}
    local p = f.pages.Preferences
    Label(p, "Leveling Preferences", 20, -4)
    f.preferences = {}
    local fields = {{"minXP", "Level Min", 16, -35}, {"maxXP", "Max", 176, -35},
        {"minHP", "Health Min", 16, -69}, {"maxHP", "Max", 176, -69}}
    for i, field in ipairs(fields) do
        local key, label, x, y = unpack(field)
        Label(p, label, x, y - 6)
        local edit = Edit(p, x + 72, y, 56, function(value) Dialog.SetPreference(key, value) end, true)
        edit:SetScript("OnTabPressed", function() f.preferences[fields[i % #fields + 1][1]]:SetFocus() end)
        f.preferences[key] = edit
    end
    f.allow = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate")
    f.allow:SetSize(24, 24); f.allow:SetPoint("TOPLEFT", p, "TOPLEFT", 42, -102)
    Label(p, "Allow any Magic or Mechanical", 68, -107)
    f.allow:SetScript("OnClick", function() Dialog.SetPreference("allowMM", not Dialog.draft.preferences.allowMM) end)
    Label(p, "Expected Damage Taken", 20, -144)
    f.types = {}
    for i, family in ipairs(families) do
        local button = Button(p, "", 20 + (i - 1) * 26, -166, 23, function()
            Dialog.SetPreference("expectedDD", Dialog.draft.preferences.expectedDD ~= i and i or nil)
        end)
        button.familyIcon = button:CreateTexture(nil, "ARTWORK"); button.familyIcon:SetAllPoints(button)
        button.familyIcon:SetTexture("Interface\\Icons\\Pet_Type_" .. family)
        button.selected = button:CreateTexture(nil, "BACKGROUND"); button.selected:SetSize(25, 25)
        button.selected:SetPoint("CENTER", button, "CENTER", 0, 0); button.selected:SetColorTexture(1, 0.82, 0)
        f.types[i] = button
    end
    Label(p, "Team values override group and default preferences.", 12, -206, "GameFontHighlightSmall")
    local w = f.pages.Wins
    Label(w, "Win Record", 20, -4); f.wins, f.minus = {}, {}
    for i, key in ipairs({ "wins", "losses", "draws" }) do
        local y = -32 - (i - 1) * 32
        local label = Label(w, key:sub(1, 1):upper() .. key:sub(2), 20, y - 6)
        label:SetTextColor(unpack(({ {0.125, 1, 0.125}, {1, 0.28, 0.28}, {1, 0.82, 0} })[i]))
        f.minus[key] = Button(w, "-", 110, y, 24, function() Dialog.SetWins(key, math.max(0, (Dialog.draft.winrecord[key] or 0) - 1)) end)
        f.wins[key] = Edit(w, 146, y, 70, function(value) Dialog.SetWins(key, value) end, "integer")
        Button(w, "+", 228, y, 24, function() Dialog.SetWins(key, (Dialog.draft.winrecord[key] or 0) + 1) end)
    end
    f.total = Label(w, "", 20, -148); f.rate = Label(w, "", 20, -174)
    f.reset = Button(f, "Reset", 4, -359, 114, Dialog.Reset)
    f.save = Button(f, "Save", 124, -359, 114, function() Dialog.Save() end)
    f.cancel = Button(f, "Cancel", 244, -359, 116, Dialog.Close)
    local confirm = CreateFrame("Frame", nil, f, "ButtonFrameTemplate")
    f.confirm = confirm
    confirm:SetSize(366, 385); confirm:SetPoint("CENTER", f, "CENTER", 0, 0)
    confirm:SetFrameStrata("FULLSCREEN_DIALOG"); confirm:EnableMouse(true)
    if ButtonFrameTemplate_HidePortrait then ButtonFrameTemplate_HidePortrait(confirm) end
    confirm.title = Label(confirm, "", 76, -7)
    confirm.oldLabel = Label(confirm, "", 20, -38); confirm.oldPreview = Preview(confirm, 24, -62)
    confirm.newLabel = Label(confirm, "", 20, -148); confirm.newPreview = Preview(confirm, 24, -172)
    confirm.overwrite = Button(confirm, "Overwrite", 6, -266, 106, function() Dialog.Save("overwrite") end)
    confirm.copy = Button(confirm, "New Copy", 118, -266, 106, function() Dialog.Save("copy") end)
    Button(confirm, "Cancel", 230, -266, 110, function() confirm:Hide() end)
    if confirm.CloseButton then confirm.CloseButton:SetScript("OnClick", function() confirm:Hide() end) end
    confirm:Hide(); f:Hide()
end

Refresh = function()
    local f, draft = Dialog.frame, Dialog.draft
    if not f or not draft then return end
    Dialog.refreshing = true
    local content = {Targets = #draft.targets > 0, Preferences = next(draft.preferences) ~= nil,
        Wins = Dialog.WinSummary().battles > 0}
    for _, name in ipairs(tabs) do
        f.pages[name]:SetShown(Dialog.tab == name)
        f.tabs[name]:SetText((content[name] and "|cff66bbff" or "") .. name .. (content[name] and "|r" or ""))
        f.tabs[name]:SetEnabled(Dialog.tab ~= name)
    end
    f.clear:SetShown(content.Targets or content.Preferences or content.Wins)
    f.name:SetText(draft.name); f.name.clear:SetShown(draft.name ~= "")
    f.group:OverrideText((Teams.GetGroup(Dialog.store, draft.groupID) or {}).name or "Ungrouped Teams")
    Dialog.RenderPreview(f.preview, draft)
    local valid, reason = Dialog.CanSave()
    f.save:SetEnabled(valid); f.reset:SetEnabled(Dialog.IsDirty())
    local owner = Teams.FindByName(Dialog.store, draft.name)
    f.feedback:SetText(reason or (owner and owner.teamID ~= (Dialog.mode == "save" and Dialog.teamID)
        and "A team with this name exists. Save to choose Overwrite or New Copy." or ""))
    for _, control in ipairs({f.add, f.delete, f.up, f.down}) do control:SetShown(not Dialog.picking) end
    for _, control in ipairs({f.all, f.search, f.pickerCancel}) do control:SetShown(Dialog.picking) end
    f.delete:SetEnabled(Dialog.selected ~= nil); f.up:SetEnabled(Dialog.selected ~= nil and Dialog.selected > 1)
    f.down:SetEnabled(Dialog.selected ~= nil and Dialog.selected < #draft.targets)
    local rows = {}
    if Dialog.picking then
        local group
        for _, entry in ipairs(TargetChoices()) do
            if Dialog.query == "" or (entry.group ~= "Recent Targets"
                and (entry.name .. " " .. entry.group .. " " .. (entry.search or "")):lower():find(Dialog.query:lower(), 1, true)) then
                if entry.group ~= group then
                    group = entry.group; rows[#rows + 1] = {name = group, group = group, header = true}
                end
                if not Dialog.collapsed[entry.group] or Dialog.query ~= "" then rows[#rows + 1] = entry end
            end
        end
        if #rows == 0 then rows[1] = {name = "No known targets", header = true} end
    else
        for i, id in ipairs(draft.targets) do rows[#rows + 1] = {name = draft.targetNames[id] or tostring(id), index = i} end
    end
    for _, row in ipairs(f.targetRows) do row:Hide() end
    for i, data in ipairs(rows) do
        local row = f.targetRows[i]
        if not row then row = Button(f.targetContent, "", 0, -(i - 1) * 26, 280, function() end); f.targetRows[i] = row end
        row:SetText((data.index and data.index == Dialog.selected and "|cffffd200" or "") .. data.name .. "|r")
        row:SetEnabled(not data.header or (data.group ~= nil and Dialog.query == "")); row:Show()
        row:SetScript("OnClick", function()
            if data.header then Dialog.collapsed[data.group] = not Dialog.collapsed[data.group]; Refresh()
            elseif Dialog.picking then Dialog.AddTarget({npcID = type(data.id) == "number" and data.id, name = data.name})
            else Dialog.selected = data.index; Refresh() end
        end)
    end
    f.targetContent:SetHeight(math.max(192, #rows * 26))
    f.search.hint:SetShown(Dialog.query == "")
    f.search:SetText(Dialog.query)
    f.all:SetEnabled(Dialog.query == "")
    for key, edit in pairs(f.preferences) do
        edit:SetText(draft.preferences[key] and tostring(draft.preferences[key]) or "")
        edit.clear:SetShown(draft.preferences[key] ~= nil)
    end
    f.allow:SetChecked(draft.preferences.allowMM == true)
    for i, button in ipairs(f.types) do
        button.familyIcon:SetDesaturated(draft.preferences.expectedDD ~= i)
        button.selected:SetShown(draft.preferences.expectedDD == i)
    end
    for key, edit in pairs(f.wins) do
        local count = draft.winrecord[key] or 0
        edit:SetText(count > 0 and tostring(count) or ""); edit.clear:SetShown(count > 0); f.minus[key]:SetEnabled(count > 0)
    end
    local summary = Dialog.WinSummary()
    f.total:SetText("Total Battles: " .. summary.battles)
    f.rate:SetText(summary.rate and ("Win Rate: %.1f%%"):format(summary.rate) or "")
    f.rate:SetTextColor(unpack(summary.rate and summary.rate >= 60 and {0.25, 0.75, 0.25}
        or summary.rate and summary.rate <= 40 and {1, 0.25, 0.25} or {1, 0.82, 0}))
    Dialog.refreshing = false
end

function Dialog.RegisterDev()
    if registered or not BattleBuddyDev then return end
    registered = BattleBuddyDev.RegisterView("save-team-dialog", function()
        local store = Teams.Initialize(nil)
        local team = Teams.CreateTeam(store, {name = "Practice Team", pets = {39, 40, 41},
            tags = {{speciesID = 39, abilities = {1, 1, 1}}, {speciesID = 40, abilities = {1, 1, 1}},
                {speciesID = 41, abilities = {1, 1, 1}}},
            targets = {{npcID = 123, name = "Practice Opponent"}}, preferences = {minXP = 1, maxXP = 25},
            winrecord = {wins = 7, losses = 2, draws = 1}})
        Dialog.Open("save", {store = store, teamID = team.teamID})
    end, Dialog.Close, function() return Dialog.frame and Dialog.frame:IsShown() end)
end

if CreateFrame then
    local events = CreateFrame("Frame")
    events:RegisterEvent("ADDON_LOADED")
    events:SetScript("OnEvent", Dialog.RegisterDev)
    if hooksecurefunc and BattleBuddyScript then
        hooksecurefunc(BattleBuddyScript, "SetLoadedTeam", function(store, id)
            if not store or Teams.GetTeam(store, id) then loadedStore, loadedID = store, id end
        end)
    end
    Dialog.RegisterDev()
end
