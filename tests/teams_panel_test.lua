local root = (... or ".")
local Frames = dofile(root .. "/tests/support/frames.lua")
local function Equal(a, b) assert(a == b, tostring(a) .. " ~= " .. tostring(b)) end
local create = Frames.Create
Frames.Create = function(...)
    local f = create(...)
    f.Instructions = false
    function f:SetAtlas(v) self.atlas = v end
    function f:SetTexCoord(...) self.crop = { ... } end
    function f:SetTextColor(...) self.color = { ... } end
    function f:SetDesaturated(v) self.desaturated = v end
    function f:SetEnabled(v) self.enabled = v end
    function f:SetNormalTexture(v) self.normal = v end
    function f:SetHighlightTexture(v) self.highlight = v end
    function f:RegisterForDrag(...) self.drags = { ... } end
    function f:RegisterForClicks(...) self.clicks = { ... } end
    function f:ClearFocus() end
    function f:GetTop() return 200 end
    function f:GetEffectiveScale() return 1 end
    function f:SetFontObject(v) self.fontObject = v end
    function f:SetMaxLetters(v) self.maxLetters = v end
    function f:SetDataProvider(v) self.provider = v end
    function f:RegisterCallback(event, callback) self.callbacks = self.callbacks or {}; self.callbacks[event] = callback end
    return f
end
CreateFrame = Frames.Create
CreateScrollBoxListLinearView = function()
    return {
        SetElementInitializer = function(self, template, callback) self.template, self.initialize = template, callback end,
        SetElementExtentCalculator = function(self, callback) self.extent = callback end,
    }
end
CreateDataProvider = function(data) return { data = data } end
ScrollUtil = { InitScrollBoxListWithScrollBar = function(box, bar, view) box.view, box.bar = view, bar end }
ScrollBoxListMixin = { Event = { OnScroll = "OnScroll" } }
local combat, battle = false, false
local secret = setmetatable({}, { __tostring = function() error("secret formatted") end })
issecretvalue = function(v) return rawequal(v, secret) end
canaccessvalue = function(v) return not rawequal(v, secret) end
InCombatLockdown = function() return combat end
C_PetBattles = { IsInBattle = function() return battle end }
GetCursorPosition = function() return 0, 190 end
C_PetJournal = {
    GetPetInfoByPetID = function(id)
        if id == "BattlePet-missing" then return end
        return 1, "Custom pet", 25, nil, nil, nil, nil, "Species", 123
    end,
    GetPetInfoBySpeciesID = function() return "Species", 123 end,
    GetPetAbilityList = function() return { 11, 12, 13, 21, 22, 23 } end,
}
local sets, abilities, loads = {}, {}, 0
BattleBuddyLoadout = {
    DropPet = function(slot, id) sets[#sets + 1] = { slot, id }; return true end,
    ChooseAbility = function(slot, tier, id) abilities[#abilities + 1] = { slot, tier, id }; return true end,
}
dofile(root .. "/BattleBuddy/Compatibility.lua")
dofile(root .. "/BattleBuddy/Store.lua")
dofile(root .. "/BattleBuddy/Teams.lua")
BattleBuddyScript = { SetLoadedTeam = function(_, id) loads = loads + 1; return true end }
local T = BattleBuddyTeams
local store = T.Initialize()
BattleBuddyDB = store
local group = assert(T.CreateGroup(store, { name = "My group", isExpanded = true }))
local team = assert(T.CreateTeam(store, { name = "First team", groupID = group.groupID,
    pets = { "BattlePet-a", "BattlePet-missing", "BattlePet-c" },
    tags = { { speciesID = 1, abilities = { 1, 2, 0 } }, { speciesID = 2 }, { speciesID = 1 } },
    script = "standby", targets = { { npcID = 123, name = "Target name" } } }))
local second = assert(T.CreateTeam(store, { name = "Second team", groupID = group.groupID }))
BattleBuddyWindow = { view = "teams", SelectView = function(name) BattleBuddyWindow.view = name end }
hooksecurefunc = function(object, key, after)
    local before = object[key]
    object[key] = function(...) local result = before(...); after(...); return result end
end
local menuCalls = 0
BattleBuddyTeamMenus = { Team = function() menuCalls = menuCalls + 1 end,
    Group = function() menuCalls = menuCalls + 1 end, Teams = function() menuCalls = menuCalls + 1 end }
dofile(root .. "/BattleBuddy/TeamsPanel.lua")
local P = BattleBuddyTeamsPanel
local host = CreateFrame("Frame")
host.label = host:CreateFontString()
P.Mount(host)
local frame = P.frame
Frames.AssertSize(frame.all, 64, 24)
Frames.AssertSize(frame.menu, 80, 24)
Equal(frame.top:GetHeight(), 29)
Frames.AssertText(frame.search.placeholder, "Search Teams")
Equal(frame.scrollBox.template, "WowScrollBoxList")
local function Find(kind, id)
    for _, row in ipairs(P.Rows(store, "")) do
        if row.kind == kind and (row.teamID == id or row.groupID == id) then return row end
    end
end
local header = CreateFrame("Button", nil, frame.scrollBox)
P.BindRow(header, Find("group", group.groupID))
Equal(header:GetHeight(), 26)
Frames.Fire(header, "OnClick", "LeftButton")
Equal(T.GetGroup(store, group.groupID).isExpanded, false)
Equal(Find("team", team.teamID), nil)
Frames.Fire(header, "OnClick", "LeftButton")
Equal(T.GetGroup(store, group.groupID).isExpanded, true)
local row = CreateFrame("Button", nil, frame.scrollBox)
P.BindRow(row, Find("team", team.teamID))
Equal(row:GetHeight(), 44)
for index, icon in ipairs(row.pets) do
    Frames.AssertSize(icon, 28, 40)
    Frames.AssertAnchor(icon, 1, { "TOPLEFT", row, "TOPLEFT", 2 + (index - 1) * 29, -2 })
end
Frames.AssertText(row.name, "First team")
Frames.AssertText(row.subtitle, "Target name")
Frames.AssertShown(row.script, true)
local scriptEdits = 0
BattleBuddySaveTeamDialog = { Open = function(mode, opts)
    Equal(mode, "save"); Equal(opts.teamID, team.teamID); Equal(opts.tab, "script")
    Equal(opts.store, store)
    scriptEdits = scriptEdits + 1
end }
Frames.Fire(row.script, "OnClick")
Equal(scriptEdits, 1)
combat = true
Frames.Fire(row.script, "OnClick")
Equal(scriptEdits, 1)
combat = false
P.Refresh(); Frames.Fire(row, "OnEnter")
Equal(#sets, 0); Equal(loads, 0)
Frames.Fire(row, "OnClick", "LeftButton")
Equal(#sets, 2); Equal(loads, 1); Equal(#abilities, 2)
Equal(abilities[1][3], 11); Equal(abilities[2][3], 22)
assert(P.message:match("slot 2")); assert(P.message:match("Species"))
Frames.Fire(row, "OnClick", "RightButton")
Equal(menuCalls, 1); Equal(#sets, 2)
for _, state in ipairs({ "combat", "battle", "secret" }) do
    combat, battle = state == "combat", state == "battle"
    if state == "secret" then battle = secret end
    Frames.Fire(row, "OnClick", "LeftButton")
    Equal(#sets, 2); Equal(loads, 1); assert(P.message ~= "")
end
combat, battle = false, false
local moved = 0
local move = T.MoveTeam
T.MoveTeam = function(...) moved = moved + 1; return move(...) end
Frames.Fire(row, "OnDragStart")
local destination = CreateFrame("Button", nil, frame.scrollBox)
P.BindRow(destination, Find("group", "group:none"))
Frames.Fire(destination, "OnReceiveDrag")
Equal(moved, 1); Equal(T.GetTeam(store, team.teamID).groupID, "group:none")
Equal(#sets, 2); Equal(loads, 1)
assert(P.Move(team.teamID, group.groupID, second.teamID, false))
Equal(T.ListTeams(store, group.groupID)[1].teamID, team.teamID)
Equal(T.GetGroup(store, group.groupID).sortMode, "custom")
assert(P.Move(team.teamID, group.groupID, second.teamID, true))
Equal(T.ListTeams(store, group.groupID)[2].teamID, team.teamID)
P.BindRow(row, Find("team", team.teamID))
P.BindRow(destination, Find("team", second.teamID))
Frames.Fire(row, "OnDragStart")
Frames.Fire(destination, "OnEnter")
Frames.Fire(row, "OnDragStop")
Equal(T.ListTeams(store, group.groupID)[1].teamID, team.teamID)
Equal(#sets, 2); Equal(loads, 1)
Frames.Fire(row, "OnDragStart")
Frames.Fire(destination, "OnMouseUp", "LeftButton")
Frames.Fire(destination, "OnClick", "LeftButton")
Equal(#sets, 2); Equal(loads, 1)
Frames.Fire(row.petButtons[1], "OnClick", "LeftButton")
Equal(#sets, 2); Equal(loads, 1)
P.ToggleAll(); Equal(T.GetGroup(store, group.groupID).isExpanded, false)
local found = P.Rows(store, "target NAME")
Equal(#found, 2); Equal(found[2].teamID, team.teamID)
Equal(T.GetGroup(store, group.groupID).isExpanded, false)
Equal(#P.Rows(store, "BattlePet-a"), 2)
Equal(#P.Rows(store, "my GROUP"), 3)
frame.search:SetText("First")
Frames.Fire(frame.search, "OnTextChanged")
Equal(frame.all.enabled, false)
P.Toggle(group.groupID); Equal(T.GetGroup(store, group.groupID).isExpanded, false)
frame.search:SetText(""); Frames.Fire(frame.search, "OnTextChanged")
BattleBuddyWindow.SelectView("queue"); Frames.AssertShown(frame, false)
BattleBuddyWindow.SelectView("teams"); Frames.AssertShown(frame, true)
P.BindRow(row, Find("group", "group:none"))
for _, icon in ipairs(row.pets) do Frames.AssertShown(icon, false) end
Frames.AssertShown(row.script, false)
Equal(row:GetHeight(), 26)
BattleBuddyDB = T.Initialize()
P.Refresh(); Equal(#T.ListTeams(BattleBuddyDB), 0)
P.SetPreview(true); assert(#frame.scrollBox.provider.data > #T.ListGroups(BattleBuddyDB))
Equal(#T.ListTeams(BattleBuddyDB), 0)
Frames.Fire(frame, "OnHide"); Equal(P.preview, nil)
Equal(#T.ListTeams(BattleBuddyDB), 0)
for _, f in ipairs({ frame, row, header, P.events }) do Equal(f:GetScript("OnUpdate"), nil) end

local current = { { nil, 11, 12, 13, false }, { nil, 11, 12, 13, false }, { nil, 11, 12, 13, false } }
local nativeSets, nativeAbilities = 0, 0
C_PetJournal.GetPetLoadOutInfo = function(slot) return unpack(current[slot], 1, 5) end
C_PetJournal.IsJournalUnlocked = function() return true end
C_PetJournal.PetIsRevoked = function() return false end
C_PetJournal.PetIsLockedForConvert = function() return false end
C_PetJournal.GetPetStats = function() return 100, 100, 20, 20, 3 end
C_PetJournal.GetPetInfoByPetID = function(id)
    if id == "BattlePet-missing" then return end
    return 1, "Custom", 25, 0, 0, 0, false, "Species", 123, 1, nil, nil, nil, nil, true
end
C_PetJournal.GetPetAbilityList = function() return { 11, 12, 13, 21, 22, 23 }, { 1, 2, 4, 10, 15, 20 } end
C_PetJournal.SetPetLoadOutInfo = function(slot, id) nativeSets = nativeSets + 1; current[slot][1] = id end
C_PetJournal.SetAbility = function(slot, tier, id) nativeAbilities = nativeAbilities + 1; current[slot][tier + 1] = id end
C_PetBattles.GetPVPMatchmakingInfo = function() return nil end
BattleBuddyWindow = nil
dofile(root .. "/BattleBuddy/Loadout.lua")
Frames.Fire(BattleBuddyLoadout.events, "OnEvent", "PLAYER_ENTERING_WORLD")
BattleBuddyDB = store
assert(P.Load(team.teamID))
Equal(nativeSets, 2); Equal(nativeAbilities, 2)
Equal(current[1][1], "BattlePet-a"); Equal(current[1][3], 22)
P.Refresh(); Equal(nativeSets, 2); Equal(nativeAbilities, 2)
battle = true
Equal(P.Load(team.teamID), false)
Equal(nativeSets, 2); Equal(nativeAbilities, 2)
battle, combat = false, true
Equal(P.Load(team.teamID), false)
Equal(nativeSets, 2); Equal(nativeAbilities, 2)
combat = false
local beforeLoads = loads
current[1][1] = "BattlePet-other"
C_PetJournal.SetPetLoadOutInfo = function() end
Equal(P.Load(team.teamID), false)
Equal(loads, beforeLoads + 1)
print("teams_panel_test.lua: passed")
