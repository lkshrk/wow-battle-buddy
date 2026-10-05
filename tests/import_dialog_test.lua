local root = (... or ".")
InCombatLockdown = function() return false end
issecretvalue = function() return false end
canaccessvalue = function() return true end
for _, file in ipairs({ "Compatibility", "Store", "Persistence", "Teams", "Script/Parser", "Script/Share", "TeamStrings", "TeamMenus" }) do
    dofile(root .. "/BattleBuddy/" .. file .. ".lua")
end
local T, M, S = BattleBuddyTeams, BattleBuddyTeamMenus, BattleBuddyScript
local fixtures = dofile(root .. "/tests/fixtures/team_strings/corpus.lua")
local references = dofile(root .. "/tests/fixtures/team_strings/reference.lua")
local db = assert(T.Initialize(BattleBuddyStore.New()))
local opened
BattleBuddySaveTeamDialog = { Open = function(mode, opts) opened = { mode = mode, opts = opts }; return true end }
local callbacks = { dialog = function() end }
local function Stage(text)
    opened = nil
    local popup = M.Import(db, callbacks)
    assert(popup.acceptLabel == "Continue")
    assert(#T.ListTeams(db) == 0)
    assert(popup:Submit(text))
    assert(#T.ListTeams(db) == 0, "Continue must never save a single team")
    assert(opened and opened.mode == "saveAs" and opened.opts.store == db and popup.done)
    return opened.opts.draft
end
local draft = Stage(fixtures.team)
assert(draft.name == "Clockwork" and draft.pets[1] == 13 and draft.tags[1].abilities[2] == 2)
assert(draft.notes == "first\nsecond: note" and draft.targets[2] == 1024 and draft.preferences.minHP == 100)
assert(Stage(references[8]).name == "Boss: Hero")
assert(Stage(fixtures.script).script == "standby")
assert(Stage(fixtures.team .. "\n\nstandby\nchange(next)").script == "standby\nchange(next)")
assert(Stage("standby\n" .. fixtures.empty).name == "Vacant")
assert(Stage("standby").script == "standby" and opened.opts.tab == "script")
for version = 0, 2 do
    local share = S.Export("standby", { version = version })
    assert(Stage(share).script == "standby")
    assert(Stage(fixtures.team .. "\n" .. share).name == "Clockwork")
    assert(Stage(share .. "\n" .. fixtures.empty).name == "Vacant")
end
for version = 1, 2 do
    assert(Stage(S.Export("standby", { version = version, plugin = "Rematch", extra = fixtures.empty })).name == "Vacant")
    for _, bad in ipairs({
        { extra = 42, reason = "Invalid Rematch team metadata" },
        { extra = fixtures.empty .. "garbage", reason = "Invalid or truncated team" },
        { extra = fixtures.backup, reason = "Script share requires exactly one team" },
        { extra = fixtures.script, code = "change(next)", reason = "Conflicting attached scripts" },
    }) do
        local share = S.Export(bad.code or "standby", { version = version, plugin = "Rematch", extra = bad.extra })
        for _, wire in ipairs({ share, fixtures.team .. "\n" .. share, (share:gsub("# Version: 1\n", "")) }) do
            opened = nil
            local importing = M.Import(db, callbacks)
            local ok, reason = importing:Submit(wire)
            assert(not ok and not opened and not importing.done, "Invalid encoded team must not become a script-only draft")
            assert(reason:find(bad.reason, 1, true), reason)
            assert(#T.ListTeams(db) == 0)
        end
    end
end
for _, text in ipairs({ fixtures.group, fixtures.backup, fixtures.team .. "\n" .. fixtures.empty }) do
    opened = nil
    local popup = M.Import(db, callbacks)
    assert(popup:Submit(text) and popup.preview and not opened)
    assert(popup.acceptLabel == "Import " .. #popup.preview.teams .. " teams")
    assert(#T.ListTeams(db) == 0)
end
for _, text in ipairs({ "garbage", "", " \n ", fixtures.team .. "\nnot a script", fixtures.script .. "\nchange(next)" }) do
    opened = nil
    local popup = M.Import(db, callbacks)
    local ok, reason = popup:Submit(text)
    assert(not ok and type(reason) == "string" and not opened and not popup.done)
end
local popup = M.Import(db, callbacks)
assert(not popup:Submit("garbage"))
assert(popup:Submit(fixtures.team), "A failed paste can be corrected")
assert(#T.ListTeams(db) == 0)
local frames = {}
local function Widget(kind, parent)
    local widget = { kind = kind, parent = parent, scripts = {}, points = {}, shown = true }
    frames[#frames + 1] = widget
    function widget:SetSize(w, h) self.width, self.height = w, h end
    function widget:SetPoint(...) self.points[select(1, ...)] = { ... } end
    function widget:SetText(text) self.text = text end
    function widget:GetText() return self.text end
    function widget:SetScript(event, callback) self.scripts[event] = callback end
    function widget:SetShown(value) self.shown = value end
    function widget:Hide() self.shown = false end
    function widget:Show() self.shown = true end
    function widget:GetHeight() return self.height or 100 end
    function widget:GetVerticalScroll() return self.scroll or 0 end
    function widget:SetVerticalScroll(value) self.scroll = value end
    function widget:GetVerticalScrollRange() return 1000 end
    function widget:SetScrollChild(child) self.child = child end
    function widget:CreateFontString() return Widget("FontString", self) end
    for _, method in ipairs({ "SetFrameStrata", "SetJustifyH", "SetMultiLine", "SetAutoFocus", "SetFontObject", "SetFocus", "HighlightText", "SetChecked" }) do
        widget[method] = function() end
    end
    return widget
end
CreateFrame = function(kind, _, parent)
    local frame = Widget(kind, parent)
    if kind == "Frame" then frame.TitleText = Widget("FontString", frame) end
    return frame
end
M.Import(db)
local frame = frames[1]
local scroll = frame.edit.parent
assert(frame.error.points.TOPLEFT[2] == scroll and frame.error.points.TOPLEFT[3] == "BOTTOMLEFT")
frame.edit:SetText("garbage")
frame.accept.scripts.OnClick()
assert(frame.shown and frame.error.text:find("Unable to read", 1, true))
assert(#T.ListTeams(db) == 0)
frame.edit:SetText(string.rep("standby\n", 80))
assert(frame.edit.scripts.OnCursorChanged and not frame.edit.scripts.OnUpdate)
frame.edit.scripts.OnCursorChanged(frame.edit, 0, -600, 1, 12)
assert(scroll.scroll and scroll.scroll > 0, "Cursor follows a long paste")
frame.edit.scripts.OnCursorChanged(frame.edit, 0, 0, 1, 12)
assert(scroll.scroll == 0)
for _, widget in ipairs(frames) do
    if widget.kind == "Button" and widget.text == "Cancel" then widget.scripts.OnClick() end
end
assert(not frame.shown and #T.ListTeams(db) == 0)
M.Import(db)
assert(frame.error.text == "")
frame.edit:SetText(fixtures.team)
frame.accept.scripts.OnClick()
assert(not frame.shown and opened.opts.draft.name == "Clockwork")
assert(#T.ListTeams(db) == 0)
print("import_dialog_test: ok")
