-- luacheck: globals BattleBuddyTeams BattleBuddyTeamStrings BattleBuddyCompatibility BattleBuddyScript BattleBuddySaveTeamDialog InCombatLockdown CreateFrame UIParent MenuUtil
BattleBuddyTeamMenus = {}

local M, T, X = BattleBuddyTeamMenus, BattleBuddyTeams, BattleBuddyTeamStrings
local dialogFrame

local function Combat()
    local ok, value = pcall(InCombatLockdown)
    return not ok or BattleBuddyCompatibility.PublicValue(value) ~= false
end

local function Present(model, callbacks)
    if callbacks.dialog then callbacks.dialog(model); return model end
    if not dialogFrame then
        local frame = CreateFrame("Frame", nil, UIParent, "BasicFrameTemplateWithInset")
        frame:SetSize(460, 350)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("DIALOG")
        frame.TitleText:SetText("BattleBuddy")
        frame.message = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        frame.message:SetPoint("TOPLEFT", 16, -34)
        frame.message:SetSize(424, 64)
        frame.message:SetJustifyH("LEFT")
        frame.deleteTeams = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
        frame.deleteTeams:SetPoint("TOPLEFT", 16, -98)
        frame.deleteTeams.label = frame.deleteTeams:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        frame.deleteTeams.label:SetPoint("LEFT", frame.deleteTeams, "RIGHT", 4, 0)
        frame.deleteTeams.label:SetText("Also delete the teams in this group")
        frame.deleteTeams:SetScript("OnClick", function(self)
            frame.model.deleteTeams = self:GetChecked() == true
        end)
        local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
        frame.scroll = scroll
        scroll:SetPoint("TOPLEFT", 16, -104)
        scroll:SetPoint("BOTTOMRIGHT", -34, 88)
        frame.edit = CreateFrame("EditBox", nil, scroll)
        frame.edit:SetSize(404, 180)
        frame.edit:SetMultiLine(true)
        frame.edit:SetAutoFocus(false)
        frame.edit:SetFontObject("ChatFontNormal")
        scroll:SetScrollChild(frame.edit)
        frame.edit:SetScript("OnCursorChanged", function(_, _, y, _, height)
            if not frame.model.import then return end
            local public = BattleBuddyCompatibility.PublicValueOfType
            y, height = public(y, "number"), public(height, "number")
            local offset = public(scroll:GetVerticalScroll(), "number")
            local visible = public(scroll:GetHeight(), "number")
            local range = public(scroll:GetVerticalScrollRange(), "number")
            if not y or not height or not offset or not visible or not range then return end
            local top = -y
            if top < offset then scroll:SetVerticalScroll(math.max(0, top))
            elseif top + height > offset + visible then
                scroll:SetVerticalScroll(math.min(range, top + height - visible))
            end
        end)
        frame.error = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        frame.error:SetPoint("TOPLEFT", scroll, "BOTTOMLEFT", 0, -6)
        frame.error:SetSize(424, 36)
        frame.error:SetJustifyH("LEFT")
        frame.edit:SetScript("OnEscapePressed", function() frame:Hide() end)
        frame.accept = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        frame.accept:SetSize(120, 24)
        frame.accept:SetPoint("BOTTOMRIGHT", -16, 12)
        frame.accept:SetScript("OnClick", function()
            local current = frame.model
            local ok, reason = current:Submit(frame.edit:GetText())
            frame.error:SetText("")
            if not ok then
                local feedback = current.import and frame.error or frame.message
                feedback:SetText(reason or "Unable to complete this action")
            elseif current.done then frame:Hide()
            else
                frame.message:SetText(current.message or "")
                frame.accept:SetText(current.acceptLabel or "Save")
                frame.edit:SetText(current.text or "")
            end
        end)
        local cancel = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        cancel:SetSize(100, 24)
        cancel:SetText("Cancel")
        cancel:SetPoint("RIGHT", frame.accept, "LEFT", -8, 0)
        cancel:SetScript("OnClick", function() frame:Hide() end)
        dialogFrame = frame
    end
    local frame = dialogFrame
    frame.model = model
    frame.scroll:SetPoint("BOTTOMRIGHT", -34, model.import and 88 or 48)
    frame.scroll:SetVerticalScroll(0)
    frame.deleteTeams:SetShown(model.deleteTeams ~= nil)
    frame.deleteTeams:SetChecked(model.deleteTeams == true)
    frame.edit:SetShown(model.deleteTeams == nil)
    frame.TitleText:SetText(model.title)
    frame.message:SetText(model.message or "")
    frame.error:SetText("")
    frame.edit:SetText(model.text or "")
    frame.accept:SetText(model.acceptLabel or "Save")
    frame:Show()
    if model.text ~= nil then frame.edit:SetFocus(); frame.edit:HighlightText() end
    return model
end

local function Action(callbacks, operation)
    return function(...)
        if Combat() then return nil, "Team changes are unavailable in combat." end
        local result, reason = operation(...)
        if result and callbacks.refresh then callbacks.refresh() end
        return result, reason
    end
end

local function Dialog(callbacks, title, text, operation, message, acceptLabel, deleteTeams)
    local model = { title = title, text = text, message = message, acceptLabel = acceptLabel, deleteTeams = deleteTeams }
    function model:Submit(value)
        if Combat() then return nil, "Team changes are unavailable in combat." end
        if self.done then return nil, "This dialog is already complete" end
        local result, reason = operation(value, self.deleteTeams)
        self.done = not not result
        return result, reason
    end
    return Present(model, callbacks)
end

local function Export(callbacks, title, value, reason)
    return Dialog(callbacks, title, value or "", function() return true end,
        reason or "Select the text and copy it.", "Okay")
end

local function ImportScript(text)
    if text:match("# Version: 2") and not text:match("^%s*#.-\n# Code Start\n.-\n# Code End%s*$") then
        return nil, "Incomplete script share string."
    end
    if text:match("^%s*#") and (text:match("# Version: [12]") or text:find("(Script)", 1, true)) then
        local document, reason = X.Decode(text)
        reason = reason and reason:gsub("^.-:%d+: ", "")
        if not document and reason ~= "Missing Rematch team metadata" and reason ~= "Missing team metadata" then
            return nil, reason
        end
    end
    return BattleBuddyScript.Import(text)
end

local function Classify(store, value)
    if type(value) ~= "string" or #value > 1024 * 1024 or value:find("%z") then
        return nil, nil, "Paste a team or PBS script (up to 1 MB)."
    end
    value = value:gsub("\r\n", "\n")
    local preview = X.Import(store, value)
    if preview then return preview end
    local lines, candidate, index = {}, nil, nil
    for line in (value .. "\n"):gmatch("(.-)\n") do
        lines[#lines + 1] = line
        local decoded = X.Import(store, line)
        if decoded and decoded.kind == "team" then
            if candidate then return nil, nil, "Paste multiple teams without a separate script." end
            candidate, index = decoded, #lines
        end
    end
    if candidate then table.remove(lines, index) end
    local scriptText = table.concat(lines, "\n"):match("^%s*(.-)%s*$")
    local script, reason = ImportScript(scriptText)
    if not script then
        return nil, nil, "Unable to read a team or PBS script: " .. tostring(reason):gsub("^.-:%d+: ", "")
    end
    if candidate then
        local draft = candidate.teams[1]
        if draft.script and draft.script ~= script then return nil, nil, "The pasted scripts differ. Keep only one script." end
        draft.script = script
        return candidate
    end
    return nil, { script = script }
end

function M.Import(store, callbacks, groupID)
    callbacks = callbacks or {}
    if Combat() then return nil, "Team changes are unavailable in combat." end
    local model = { title = "Import Teams", text = "", acceptLabel = "Continue", import = true,
        message = "Paste a team, PBS script, or both. Multiple teams are imported as copies." }
    function model:Submit(value)
        if Combat() then return nil, "Team changes are unavailable in combat." end
        if self.done then return nil, "This dialog is already complete" end
        if not self.preview then
            local preview, draft, reason = Classify(store, value)
            if not preview and not draft then return nil, reason end
            local scriptOnly = draft ~= nil
            if preview and preview.kind == "team" then draft = preview.teams[1] end
            if draft then
                draft.groupID = groupID or draft.groupID
                local result, problem = BattleBuddySaveTeamDialog.Open("saveAs", {
                    draft = draft, store = store, tab = scriptOnly and "script" or nil,
                })
                self.done = not not result
                return result, problem
            end
            self.preview, self.acceptLabel = preview, "Import " .. #preview.teams .. " teams"
            local names, unresolved = {}, 0
            for index, team in ipairs(preview.teams) do
                names[#names + 1] = team.name .. (preview.scriptPresent[index] and " (script included)" or "")
                for _, pet in ipairs(preview.pets[index]) do
                    if pet.unresolved then unresolved = unresolved + 1 end
                end
            end
            self.text = table.concat(names, "\n")
            self.message = #preview.teams .. " teams; " .. #preview.conflicts .. " name conflicts (copies); "
                .. unresolved .. " unresolved pets; " .. #preview.warnings .. " warnings. Confirm to import."
            return true
        end
        local result, reason = X.ApplyImport(store, self.preview, { groupID = groupID, conflicts = "copy" })
        if result then
            self.done = true
            if callbacks.refresh then callbacks.refresh() end
        end
        return result, reason
    end
    return Present(model, callbacks)
end

local function Entry(label, action, disabled, children)
    local guarded
    if action then guarded = function(...)
        if Combat() then return nil, "Team changes are unavailable in combat." end
        return action(...)
    end end
    return { label = label, action = guarded, disabled = disabled, children = children }
end

local function Unavailable(label)
    return Entry(label, nil, "Not available yet")
end

local function NewGroup(store, callbacks)
    return Dialog(callbacks, "Create New Group", "", Action(callbacks, function(name)
        return T.CreateGroup(store, { name = name })
    end))
end

function M.TeamEntries(store, id, callbacks)
    callbacks = callbacks or {}
    local team = T.GetTeam(store, id)
    if not team then return {} end
    local entries = {}
    if callbacks.loadedTeamID == id then
        entries[#entries + 1] = Entry("Unload Team", callbacks.unload, not callbacks.unload and "Not available yet" or nil)
    end
    entries[#entries + 1] = Entry("Edit Team", function()
        return BattleBuddySaveTeamDialog.Open("save", { teamID = id, store = store })
    end)
    entries[#entries + 1] = Entry("Rename Team", function()
        Dialog(callbacks, "Rename Team", team.name, Action(callbacks, function(name) return T.EditTeam(store, id, { name = name }) end))
    end)
    entries[#entries + 1] = Entry("Set Notes", function()
        Dialog(callbacks, "Set Notes", team.notes or "", Action(callbacks, function(notes) return T.EditTeam(store, id, { notes = notes }) end))
    end)
    local destinations = {}
    for _, group in ipairs(T.ListGroups(store)) do
        local destination = group.groupID
        destinations[#destinations + 1] = Entry(group.name, Action(callbacks, function() return T.MoveTeam(store, id, destination) end))
    end
    entries[#entries + 1] = Entry("Move Team", nil, nil, destinations)
    entries[#entries + 1] = Entry(team.favorite and "Remove Favorite" or "Set Favorite",
        Action(callbacks, function() return T.SetFavorite(store, id, not team.favorite) end))
    if team.targets and #team.targets > 0 then
        entries[#entries + 1] = Unavailable("Load Target")
        entries[#entries + 1] = Unavailable("Edit Target")
    end
    entries[#entries + 1] = Entry("Share", nil, nil, {
        Entry("Plain Text", function() Export(callbacks, "Plain Text", X.PlainText(team)) end),
        Entry("Export Team", function() Export(callbacks, "Export Team", X.ExportTeam(store, id)) end),
        Unavailable("Send Team"), Entry("Cancel"),
    })
    entries[#entries + 1] = Entry("Duplicate Team", Action(callbacks, function() return T.DuplicateTeam(store, id) end))
    if callbacks.alternatives then
        local slots = {}
        for index = 1, 3 do
            local slot = index
            slots[#slots + 1] = Entry("Slot " .. slot, function() callbacks.alternatives(slot, id) end)
        end
        entries[#entries + 1] = Entry("Find Alternatives", nil, nil, slots)
    else entries[#entries + 1] = Unavailable("Find Alternatives") end
    entries[#entries + 1] = Entry("Edit Script", function()
        return BattleBuddySaveTeamDialog.Open("save", { teamID = id, store = store, tab = "script" })
    end)
    entries[#entries + 1] = Entry("Delete Team", function()
        Dialog(callbacks, "Delete Team", nil, Action(callbacks, function() return T.DeleteTeam(store, id, true) end),
            "Delete " .. team.name .. "? This cannot be undone.", "Delete")
    end)
    entries[#entries + 1] = Entry("Cancel")
    return entries
end

function M.GroupEntries(store, id, callbacks)
    callbacks = callbacks or {}
    local group = T.GetGroup(store, id)
    if not group then return {} end
    local protected = group.meta and "System groups cannot be changed" or nil
    local edits = {}
    for _, field in ipairs({ { "Name", "name" }, { "Color (RGB hex)", "color" }, { "Icon (file ID)", "icon" } }) do
        local label, key = field[1], field[2]
        edits[#edits + 1] = Entry(label, function()
            Dialog(callbacks, label, tostring(group[key] or ""), Action(callbacks, function(value)
                if key == "icon" and value ~= "" then
                    value = tonumber(value)
                    if not value then return nil, "Enter a numeric file ID or leave empty" end
                end
                return T.EditGroup(store, id, { [key] = value })
            end))
        end)
    end
    for _, sort in ipairs({ { "By Name", "alpha" }, { "By Wins", "wins" }, { "Custom Sort", "custom" } }) do
        local mode = sort[2]
        edits[#edits + 1] = Entry(sort[1], Action(callbacks, function() return T.EditGroup(store, id, { sortMode = mode }) end))
    end
    edits[#edits + 1] = Unavailable("Leveling Preferences")
    local moves = {}
    for index, destination in ipairs(T.ListGroups(store)) do
        if not destination.meta then
            local position = index
            moves[#moves + 1] = Entry(destination.name, Action(callbacks, function() return T.MoveGroup(store, id, position) end))
        end
    end
    return {
        Entry("Create New Group", function() NewGroup(store, callbacks) end),
        Entry("Edit Group", nil, protected, edits),
        Entry("Move Group", nil, protected, moves),
        Entry("Delete Group", function()
            Dialog(callbacks, "Delete Group", nil, Action(callbacks, function(_, deleteTeams)
                return T.DeleteGroup(store, id, true, deleteTeams)
            end), "Delete this group? Teams move to Ungrouped unless you also choose to delete them.", "Delete", false)
        end, group.meta and "System groups cannot be deleted" or nil),
        Entry("Export Group", function() Export(callbacks, "Export Group", X.ExportGroup(store, id)) end),
        Entry("Import Teams", function() M.Import(store, callbacks, id) end),
        Entry("Delete Teams", function()
            Dialog(callbacks, "Delete Teams", nil, Action(callbacks, function()
                for _, member in ipairs(T.ListTeams(store, id)) do T.DeleteTeam(store, member.teamID, true) end
                return true
            end), "Delete all teams in " .. group.name .. "? This cannot be undone.", "Delete")
        end, #group.teams == 0 and "This group has no teams" or nil),
        Unavailable(group.showTab and "Hide Tab" or "Show Tab"),
        Entry("Cancel"),
    }
end

function M.TeamsEntries(store, callbacks)
    callbacks = callbacks or {}
    return {
        Entry("Create New Group", function() NewGroup(store, callbacks) end),
        Unavailable("Team Herder"),
        Entry("Import Teams", function() M.Import(store, callbacks) end),
        Entry("Backup All Teams", function() Export(callbacks, "Backup All Teams", X.ExportBackup(store)) end),
        Entry("Help", function()
            Dialog(callbacks, "Teams", nil, function() return true end,
                "Click a team to load it. Drag teams between groups or onto another team to reorder. Right-click teams and groups for more actions.", "Okay")
        end),
        Entry("Okay"),
    }
end

local function Populate(root, entries)
    for _, entry in ipairs(entries) do
        local button = root:CreateButton(entry.label, entry.action)
        if entry.disabled then
            button:SetEnabled(false)
            button:SetTooltip(function(tooltip) tooltip:AddLine(entry.disabled) end)
        elseif entry.children then Populate(button, entry.children) end
    end
end

function M.Team(owner, store, id, callbacks)
    if Combat() then return end
    if dialogFrame then dialogFrame:Hide() end
    local team = T.GetTeam(store, id)
    if not team then return end
    return MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(team.name)
        Populate(root, M.TeamEntries(store, id, callbacks))
    end)
end

function M.Group(owner, store, id, callbacks)
    if Combat() then return end
    if dialogFrame then dialogFrame:Hide() end
    local group = T.GetGroup(store, id)
    if not group then return end
    return MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(group.name)
        Populate(root, M.GroupEntries(store, id, callbacks))
    end)
end

function M.Teams(owner, store, callbacks)
    if Combat() then return end
    if dialogFrame then dialogFrame:Hide() end
    return MenuUtil.CreateContextMenu(owner, function(_, root) Populate(root, M.TeamsEntries(store, callbacks)) end)
end
