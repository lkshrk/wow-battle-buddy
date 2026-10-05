local root = (... or ".")
local Frames = dofile(root .. "/tests/support/frames.lua")
local create = Frames.Create
CreateFrame = function(...)
    local f = create(...)
    for _, method in ipairs({ "SetMovable", "SetClampedToScreen", "RegisterForDrag", "StartMoving", "StopMovingOrSizing",
        "SetTextColor", "SetDesaturated", "SetVertexColor", "SetFocus", "ClearFocus", "EnableKeyboard",
        "SetPropagateKeyboardInput", "SetScrollChild", "SetVerticalScroll", "EnableMouseWheel" }) do
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
for _, file in ipairs({ "Store", "Teams", "Compatibility", "EncounterContent", "SaveTeamDialog" }) do
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
for _, tab in ipairs({ "Team", "Targets", "Preferences", "Wins" }) do
    D.SelectTab(tab); assert(D.frame.pages[tab]:IsShown())
end
D.SetName("   "); assert(not D.CanSave())
D.SetName("First"); assert(D.IsDirty()); D.Reset(); eq(D.draft.name, "New Team"); eq(D.tab, "Team")
D.SetName("First")
local first = assert(D.Save()); eq(T.GetTeam(store, first).name, "First")
open("save", {teamID = first}); D.SetName("Renamed"); eq(D.Save(), first)
T.EditTeam(store, first, {script = "opaque script", preferences = {minHP = 10}, winrecord = {wins = 3}})
open("saveAs", {teamID = first}); assert(D.draft.name ~= "Renamed")
local second = assert(D.Save()); assert(second ~= first); eq(T.GetTeam(store, second).script, "opaque script")
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
local loaded = T.CreateTeam(store, {name = "Loaded", pets = {"BattlePet-old"}, script = "untouched"})
BattleBuddyScript.SetLoadedTeam(store, loaded.teamID)
open("save"); eq(D.draft.name, "Loaded"); eq(D.draft.pets[1], "BattlePet-1")
eq(select(2, D.Save()), "loadout_changed"); eq(T.GetTeam(store, loaded.teamID).pets[1], "BattlePet-old")
eq(D.Save("overwrite"), loaded.teamID); eq(T.GetTeam(store, loaded.teamID).script, "untouched")
local group = T.CreateGroup(store, {name = "A Group"})
open("save", {teamID = loaded.teamID})
local menu = {CreateRadio = function(_, name, selected, callback)
    if name == "A Group" then assert(not selected()); callback() end
end}
D.frame.group.menu(D.frame.group, menu); eq(D.draft.groupID, group.groupID)
eq(D.frame.group:GetText(), "A Group"); D.Reset(); eq(D.frame.group:GetText(), "Ungrouped Teams")
D.Close()
eq(mutations, 0)
print("save team dialog tests passed")
