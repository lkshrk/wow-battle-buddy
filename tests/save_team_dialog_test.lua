local root = (... or ".")
local Frames = dofile(root .. "/tests/support/frames.lua")
local create = Frames.Create
CreateFrame = function(...)
    local f = create(...)
    for _, method in ipairs({ "SetMovable", "SetClampedToScreen", "RegisterForDrag", "StartMoving", "StopMovingOrSizing",
        "SetTextColor", "SetDesaturated", "SetVertexColor", "SetFocus", "ClearFocus", "EnableKeyboard",
        "SetPropagateKeyboardInput", "SetScrollChild", "SetVerticalScroll", "EnableMouseWheel", "SetMultiLine",
        "SetFontObject", "HighlightText" }) do
        f[method] = function() end
    end
    function f:SetEnabled(value) self.enabled = value end
    function f:SetChecked(value) self.checked = value end
    function f:SetupMenu(callback) self.menu = callback end
    function f:SetDefaultText(value) self.text = value end
    function f:OverrideText(value) self.text = value end
    if select(4, ...) == "ButtonFrameTemplate" then f.CloseButton = CreateFrame("Button", nil, f) end
    return f
end
Frames.Create = CreateFrame
UIParent = CreateFrame("Frame")
local secret = {}
issecretvalue = function(v) return rawequal(v, secret) end
canaccessvalue = function(v) return not rawequal(v, secret) end
InCombatLockdown = function() return false end
local target = { npcID = 123, name = "Opponent" }
BattleBuddyTargetDetection = { Current = function() return target end, GetRecent = function() return {123} end }
local mutations = 0
C_PetJournal = {
    GetPetLoadOutInfo = function(slot) return "BattlePet-" .. slot, 104, 102, 106 end,
    GetPetInfoByPetID = function() return 1, "Pet", 25, 0, 100, 0, true, "Species", 134400 end,
    GetPetAbilityList = function() return {101, 102, 103, 104, 105, 106} end,
    GetPetAbilityInfo = function() return "Ability", 134400 end,
    GetPetInfoBySpeciesID = function() return "Species", 134400 end,
    GetPetStats = function() return 100, 100, 20, 20, 4 end,
    SetPetLoadOutInfo = function() mutations = mutations + 1 end,
    SetAbility = function() mutations = mutations + 1 end,
}
local views = {}
BattleBuddyDev = { RegisterView = function(name, show) views[name] = show end }
BattleBuddyScript = {SetLoadedTeam = function() end}
hooksecurefunc = function(object, key, callback)
    local original = object[key]
    object[key] = function(...) original(...); callback(...) end
end
for _, file in ipairs({ "Store", "Teams", "Compatibility", "EncounterContent", "Script/Parser", "Script/Share", "SaveTeamDialog" }) do
    dofile(root .. "/BattleBuddy/" .. file .. ".lua")
end
local D, T = BattleBuddySaveTeamDialog, BattleBuddyTeams
local store = T.Initialize(nil)
local function eq(a, b) assert(a == b, tostring(a) .. " ~= " .. tostring(b)) end
local function open(mode, options)
    options = options or {}; options.store = store
    assert(D.Open(mode or "saveAs", options))
end
open()
eq(D.draft.name, "New Team")
eq(D.draft.pets[1], "BattlePet-1")
eq(D.draft.tags[1].abilities[1], 2)
eq(D.draft.tags[1].abilities[2], 1)
eq(D.draft.tags[1].abilities[3], 2)
eq(D.draft.targets[1], 123)
eq(D.frame.preview.slots[1].border.color[3], 1)
Frames.AssertSize(D.frame, 366, 385)
for _, tab in ipairs({ "Team", "Targets", "Preferences", "Wins", "Script" }) do
    D.SelectTab(tab); assert(D.frame.pages[tab]:IsShown())
end
D.SetName("   "); assert(not D.CanSave())
D.SetName("First"); assert(D.IsDirty()); D.Reset(); eq(D.draft.name, "New Team"); eq(D.tab, "Team")
D.SetName("First")
local first = assert(D.Save()); eq(T.GetTeam(store, first).name, "First")
open("save", {teamID = first}); D.SetName("Renamed"); eq(D.Save(), first)
T.EditTeam(store, first, {script = "standby", preferences = {minHP = 10}, winrecord = {wins = 3}})
open("saveAs", {teamID = first}); assert(D.draft.name ~= "Renamed")
local second = assert(D.Save()); assert(second ~= first); eq(T.GetTeam(store, second).script, "standby")
open("saveAs"); D.SetName("RENAMED"); local id, status = D.Save(); eq(id, nil); eq(status, "name_conflict")
assert(D.frame.confirm:IsShown()); assert(D.Save("copy") ~= first)
open("saveAs"); D.SetName("renamed"); eq(D.Save("overwrite"), first)
open("save", {teamID = second}); D.SetName("renamed"); eq(select(2, D.Save()), "name_conflict")
eq(D.Save("overwrite"), second); eq(T.GetTeam(store, first), nil)
open("save", {teamID = second})
D.SetPreference("minXP", "2.5"); D.SetPreference("maxXP", "2"); assert(not D.CanSave())
D.SetPreference("maxXP", "25"); assert(D.CanSave())
D.SetPreference("minHP", "100"); D.SetPreference("maxHP", "50"); assert(not D.CanSave())
D.SetPreference("maxHP", "150"); assert(D.CanSave())
D.SetWins("wins", 2); D.SetWins("losses", 1); eq(D.WinSummary().battles, 3)
eq(D.WinSummary().rate, 200 / 3)
D.ClearTab("Wins"); eq(D.WinSummary().battles, 0)
D.ClearTab("Preferences"); D.ClearTab("Targets"); assert(D.Save())
local saved = T.GetTeam(store, second)
eq(saved.preferences, nil); eq(saved.targets, nil); eq(saved.winrecord, nil)
open("save", {teamID = second}); D.SetName("Discard this"); D.Close(); eq(T.GetTeam(store, second).name, "renamed")
open("save", {teamID = second}); D.SetName("Escape this"); Frames.Fire(D.frame, "OnKeyDown", "ESCAPE")
assert(not D.frame:IsShown()); eq(T.GetTeam(store, second).name, "renamed")
open(); D.AddTarget({npcID = 456, name = "Other"}); D.AddTarget({npcID = 456}); eq(#D.draft.targets, 2)
D.MoveTarget(2, -1); eq(D.draft.targets[1], 456); D.RemoveTarget(1); eq(D.draft.targets[1], 123)
Frames.Fire(D.frame.add, "OnClick"); assert(D.picking)
D.frame.search:SetText("Squirt")
Frames.Fire(D.frame.search, "OnTextChanged", true)
assert(D.frame.targetRows[2]:GetText():find("Squirt", 1, true))
Frames.Fire(D.frame.targetRows[2], "OnClick"); assert(not D.picking)
eq(D.draft.targets[#D.draft.targets], 79179)
Frames.Fire(D.frame.add, "OnClick"); assert(D.picking)
Frames.Fire(D.frame.pickerCancel, "OnClick"); assert(not D.picking)
Frames.Fire(D.frame.tabs.Preferences, "OnClick"); eq(D.tab, "Preferences")
D.frame.preferences.minXP:SetText("3a.5")
Frames.Fire(D.frame.preferences.minXP, "OnTextChanged", true); eq(D.draft.preferences.minXP, 3.5)
D.frame.wins.wins:SetText("1a2")
Frames.Fire(D.frame.wins.wins, "OnTextChanged", true); eq(D.draft.winrecord.wins, 12)
D.Close(); target = {name = "Unknown"}; open(); eq(D.draft.targets[1], "name:unknown")
D.Close(); target = {npcID = secret, name = secret}; open(); eq(#D.draft.targets, 0)
D.Close(); D.RegisterDev(); assert(views["save-team-dialog"]); views["save-team-dialog"](); assert(D.frame:IsShown())
D.Close()
local loaded = T.CreateTeam(store, {name = "Loaded", pets = {"BattlePet-old"}, script = "standby"})
BattleBuddyScript.SetLoadedTeam(store, loaded.teamID)
open("save"); eq(D.draft.name, "Loaded"); eq(D.draft.pets[1], "BattlePet-1")
eq(select(2, D.Save()), "loadout_changed"); eq(T.GetTeam(store, loaded.teamID).pets[1], "BattlePet-old")
eq(D.Save("overwrite"), loaded.teamID); eq(T.GetTeam(store, loaded.teamID).script, "standby")
local group = T.CreateGroup(store, {name = "A Group"})
open("save", {teamID = loaded.teamID})
local menu = {CreateRadio = function(_, name, selected, callback)
    if name == "A Group" then assert(not selected()); callback() end
end}
D.frame.group.menu(D.frame.group, menu); eq(D.draft.groupID, group.groupID)
eq(D.frame.group:GetText(), "A Group"); D.Reset(); eq(D.frame.group:GetText(), "Ungrouped Teams")
D.Close()
local imported = {name = "Imported", pets = {39, "empty", "empty"},
    tags = {{speciesID = 39, abilities = {2, 1, 2}}, {}, {}}, targets = {456}, targetNames = {[456] = "Other"},
    preferences = {minHP = 123}, notes = "Imported notes", script = "standby"}
local count = #T.ListTeams(store)
open("saveAs", {draft = imported, tab = "script"})
eq(D.tab, "Script"); eq(D.draft.name, "Imported"); eq(D.draft.pets[1], 39)
eq(D.draft.tags[1].abilities[1], 2); eq(D.draft.targets[1], 456); eq(#D.draft.targets, 1)
eq(D.draft.preferences.minHP, 123); eq(D.draft.notes, "Imported notes")
eq(D.frame.preview.slots[1].unresolved:GetText(), "Unresolved")
eq(D.frame.scriptEditor:GetText(), "standby"); eq(#T.ListTeams(store), count)
D.frame.scriptEditor:SetText("use(1)"); Frames.Fire(D.frame.scriptEditor, "OnTextChanged", true)
eq(D.draft.script, "use(1)"); eq(imported.script, "standby")
D.SelectTab("Team"); D.SelectTab("Script"); eq(D.frame.scriptEditor:GetText(), "use(1)")
D.Reset(); eq(D.draft.script, "standby"); eq(D.frame.scriptEditor:GetText(), "standby")
D.SetScript("use(1)"); D.Close(); eq(#T.ListTeams(store), count)
open("saveAs", {draft = imported}); local importedID = assert(D.Save())
eq(T.GetTeam(store, importedID).script, "standby"); eq(T.GetTeam(store, importedID).pets[1], 39)
open("save", {teamID = importedID, tab = "script"})
D.SetScript("standby\nbad syntax"); D.SetName("Must not commit")
local valid, reason = D.ValidateScript(); eq(valid, false); assert(reason:find("Line 2", 1, true))
eq(D.Save(), nil); eq(T.GetTeam(store, importedID).script, "standby")
eq(T.GetTeam(store, importedID).name, "Imported"); eq(D.tab, "Script")
assert(D.frame.scriptFeedback:GetText():find("Line 2", 1, true))
D.SetScript("standby"); local share = assert(D.ExportScript())
eq(BattleBuddyScript.Import(share), "standby")
for version = 0, 2 do
    assert(D.ImportScript(BattleBuddyScript.Export("use(1)", {version = version})))
    eq(D.draft.script, "use(1)")
end
eq(D.ImportScript("garbage"), nil); eq(D.draft.script, "use(1)")
eq(T.GetTeam(store, importedID).script, "standby")
Frames.Fire(D.frame.scriptExport, "OnClick"); eq(D.scriptTransfer, "export")
eq(BattleBuddyScript.Import(D.frame.scriptShare:GetText()), "use(1)")
Frames.Fire(D.frame.scriptBack, "OnClick"); eq(D.scriptTransfer, nil)
Frames.Fire(D.frame.scriptImport, "OnClick"); eq(D.scriptTransfer, "import")
D.frame.scriptShare:SetText(BattleBuddyScript.Export("standby"))
Frames.Fire(D.frame.scriptImport, "OnClick"); eq(D.scriptTransfer, nil); eq(D.draft.script, "standby")
eq(T.GetTeam(store, importedID).script, "standby")
D.ClearTab("Team"); eq(D.draft.script, "")
D.Reset(); eq(D.draft.script, "standby")
D.SetScript(" "); eq(D.Save(), importedID); eq(T.GetTeam(store, importedID).script, nil)
open("save", {teamID = importedID, tab = "script"}); D.SetScript("standby")
Frames.Fire(D.frame.scriptEditor, "OnEscapePressed"); eq(T.GetTeam(store, importedID).script, nil)
assert(not D.frame:IsShown())
open("saveAs", {draft = {script = "standby"}, tab = "script"})
eq(D.draft.pets[1], "BattlePet-1"); eq(D.draft.script, "standby"); eq(D.tab, "Script"); D.Close()
open("saveAs", {draft = {name = "Loaded", script = "use(1)"}})
eq(select(2, D.Save()), "name_conflict"); eq(T.GetTeam(store, loaded.teamID).script, "standby")
local copyID = assert(D.Save("copy")); assert(copyID ~= loaded.teamID)
eq(T.GetTeam(store, copyID).script, "use(1)")
dofile(root .. "/BattleBuddy/TeamStrings.lua")
dofile(root .. "/BattleBuddy/TeamMenus.lua")
local fixtures = dofile(root .. "/tests/fixtures/team_strings/corpus.lua")
count = #T.ListTeams(store)
local popup = BattleBuddyTeamMenus.Import(store, {dialog = function() end})
assert(popup:Submit(fixtures.team .. "\nstandby"))
eq(#T.ListTeams(store), count); eq(D.draft.name, "Clockwork"); eq(D.draft.script, "standby")
eq(D.draft.notes, "first\nsecond: note"); eq(D.draft.preferences.minHP, 100)
D.Close(); eq(#T.ListTeams(store), count)
popup = BattleBuddyTeamMenus.Import(store, {dialog = function() end})
assert(popup:Submit(fixtures.team .. "\nstandby"))
eq(#T.ListTeams(store), count)
local refreshed = false
BattleBuddyTeamsPanel = {Refresh = function()
    refreshed = true; eq(T.FindByName(store, "Clockwork").script, "standby")
end}
local committed = assert(D.Save()); eq(#T.ListTeams(store), count + 1)
eq(T.GetTeam(store, committed).script, "standby"); assert(refreshed)
eq(mutations, 0)
print("save team dialog tests passed")
