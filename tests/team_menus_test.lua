local root = (... or ".")
local combat = false
InCombatLockdown = function() return combat end
issecretvalue = function() return false end
canaccessvalue = function() return true end
dofile(root .. "/BattleBuddy/Compatibility.lua")
dofile(root .. "/BattleBuddy/Store.lua")
dofile(root .. "/BattleBuddy/Persistence.lua")
dofile(root .. "/BattleBuddy/Teams.lua")
dofile(root .. "/BattleBuddy/Script/Parser.lua")
dofile(root .. "/BattleBuddy/Script/Share.lua")
dofile(root .. "/BattleBuddy/TeamStrings.lua")
dofile(root .. "/BattleBuddy/TeamMenus.lua")
local T, M = BattleBuddyTeams, BattleBuddyTeamMenus
local opened
BattleBuddySaveTeamDialog = { Open = function(mode, opts) opened = { mode = mode, opts = opts }; return true end }
local db = assert(T.Initialize(BattleBuddyStore.New()))
local team = assert(T.CreateTeam(db, { name = "Test", pets = { "empty", "empty", "empty" }, tags = {{}, {}, {}} }))
local dialog, refreshes = nil, 0
local callbacks = { dialog = function(value) dialog = value end, refresh = function() refreshes = refreshes + 1 end }
local function Find(entries, label)
    for _, entry in ipairs(entries) do if entry.label == label then return entry end end
    error("Missing menu entry: " .. label)
end
local entries = M.TeamEntries(db, team.teamID, callbacks)
assert(not Find(entries, "Edit Team").disabled)
Find(entries, "Edit Team").action()
assert(opened.mode == "save" and opened.opts.teamID == team.teamID and opened.opts.store == db)
Find(entries, "Edit Script").action()
assert(opened.opts.tab == "script" and opened.opts.teamID == team.teamID)
assert(Find(entries, "Set Notes").action)
assert(Find(entries, "Move Team").children)
assert(Find(entries, "Share").children)
Find(entries, "Delete Team").action()
assert(T.GetTeam(db, team.teamID), "Opening confirmation deleted team")
assert(dialog:Submit())
assert(not T.GetTeam(db, team.teamID))
assert(refreshes == 1)
local group = assert(T.CreateGroup(db, { name = "Group" }))
entries = M.GroupEntries(db, "group:none", callbacks)
assert(Find(entries, "Delete Group").disabled)
assert(Find(entries, "Delete Teams").disabled)
entries = M.TeamsEntries(db, callbacks)
for _, label in ipairs({ "Create New Group", "Team Herder", "Import Teams", "Backup All Teams", "Help", "Okay" }) do Find(entries, label) end
assert(Find(entries, "Team Herder").disabled == "Not available yet")
Find(entries, "Import Teams").action()
local importing = dialog
assert(importing:Submit("Imported:::::\nSecond:::::"))
assert(not T.FindByName(db, "Imported"), "Preview must not save teams")
assert(importing.preview and importing.acceptLabel == "Import 2 teams")
assert(importing:Submit())
assert(T.FindByName(db, "Imported"))
local imported = T.FindByName(db, "Imported")
Find(M.TeamEntries(db, imported.teamID, callbacks), "Set Favorite").action()
assert(T.GetTeam(db, imported.teamID).favorite)
Find(M.TeamEntries(db, imported.teamID, callbacks), "Move Team").children[3].action()
assert(T.GetTeam(db, imported.teamID).groupID == group.groupID)
Find(M.GroupEntries(db, group.groupID, callbacks), "Delete Group").action()
assert(T.GetGroup(db, group.groupID))
assert(dialog.deleteTeams == false)
combat = true
assert(not dialog:Submit())
assert(T.GetGroup(db, group.groupID))
combat = false
assert(dialog:Submit())
assert(not T.GetGroup(db, group.groupID))
assert(T.GetTeam(db, imported.teamID).groupID == "group:none")
local rendered = {}
local function Description()
    local description = {}
    function description:CreateTitle(value) self.title = value end
    function description:CreateButton(label, action)
        local button = Description()
        button.label, button.action = label, action
        rendered[label] = button
        return button
    end
    function description:SetEnabled(value) self.enabled = value end
    function description:SetTooltip(value) self.tooltip = value end
    return description
end
MenuUtil = { CreateContextMenu = function(owner, generate) generate(owner, Description()) end }
M.Team({}, db, imported.teamID, callbacks)
assert(rendered["Edit Team"].action and rendered["Edit Team"].enabled ~= false)
assert(rendered["Export Team"].action)
Find(M.TeamsEntries(db, callbacks), "Import Teams").action()
assert(not dialog:Submit("not a team string"))
assert(not dialog.preview)
local deleteGroup = assert(T.CreateGroup(db, { name = "Delete with teams" }))
assert(T.MoveTeam(db, imported.teamID, deleteGroup.groupID))
Find(M.GroupEntries(db, deleteGroup.groupID, callbacks), "Delete Group").action()
dialog.deleteTeams = true
assert(dialog:Submit())
assert(not T.GetTeam(db, imported.teamID))
combat = true
local oldDialog = dialog
assert(not Find(M.TeamsEntries(db, callbacks), "Create New Group").action())
assert(dialog == oldDialog)
combat = false
print("team_menus_test: ok")
