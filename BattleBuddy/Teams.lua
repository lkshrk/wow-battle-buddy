BattleBuddyTeams = {}

local Teams = BattleBuddyTeams
local Favorites, Ungrouped = "group:favorites", "group:none"

local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = Copy(item) end
    return result
end

local function Plain(value)
    local probe = BattleBuddyStore.New()
    probe.input = value
    return BattleBuddyStore.Classify(probe) == "current"
end

local function Integer(value, minimum)
    return type(value) == "number" and value < math.huge and value >= minimum and value % 1 == 0
end

local function Array(value, maximum)
    if type(value) ~= "table" then return false end
    local count = 0
    for key in pairs(value) do
        if not Integer(key, 1) then return false end
        count = count + 1
    end
    return count == #value and (not maximum or count <= maximum)
end

local function Trim(value)
    return type(value) == "string" and value:match("^%s*(.-)%s*$") or nil
end

local function Contains(list, value)
    for index, item in ipairs(list or {}) do
        if item == value then return index end
    end
end

local function Remove(list, value)
    local index = Contains(list, value)
    if index then table.remove(list, index) end
end

local function Keys(map)
    local keys = {}
    for key in pairs(map) do keys[#keys + 1] = key end
    table.sort(keys)
    return keys
end

local function Allocate(map, prefix)
    local number = 1
    while map[prefix .. number] do number = number + 1 end
    return prefix .. number
end

local function ValidID(id, prefix)
    return type(id) == "string" and id:match("^" .. prefix .. ":[1-9]%d*$") ~= nil
end

local function Target(value)
    if type(value) == "string" then value = tonumber(value:match("^target:(%d+)$")) end
    if Integer(value, 1) then return value end
end

local function Preferences(value)
    if type(value) ~= "table" then return false end
    for key, item in pairs(value) do
        if key == "allowMM" then
            if type(item) ~= "boolean" then return false end
        elseif key == "minHP" or key == "maxHP" or key == "minXP" or key == "maxXP" or key == "expectedDD" then
            if type(item) ~= "number" or item < 0 then return false end
        else
            return false
        end
    end
    return true
end

local function Pet(value)
    if Integer(value, 0) then return true end
    if type(value) ~= "string" then return false end
    return value:match("^BattlePet%-.+") ~= nil or value == "ignored" or value == "empty"
        or value:match("^random:[0-9]$") ~= nil or value == "random:10"
end

local function Tag(value)
    if type(value) ~= "table" then return false end
    for key, item in pairs(value) do
        if key == "speciesID" then
            if not Integer(item, 1) then return false end
        elseif key == "breedID" then
            if not Integer(item, 0) then return false end
        elseif key == "abilities" then
            if not Array(item, 3) or #item ~= 3 then return false end
            for _, choice in ipairs(item) do
                if not Integer(choice, 0) or choice > 2 then return false end
            end
        else
            return false
        end
    end
    return true
end

local TeamFields = {
    teamID = true, name = true, pets = true, tags = true, groupID = true, homeID = true,
    favorite = true, notes = true, targets = true, preferences = true, winrecord = true, script = true,
}

local GroupFields = {
    groupID = true, name = true, icon = true, color = true, sortMode = true, teams = true,
    preferences = true, isExpanded = true, showTab = true, meta = true,
}

local function Fields(value, allowed)
    if type(value) ~= "table" or not Plain(value) then return false end
    for key in pairs(value) do if not allowed[key] then return false end end
    return true
end

local function NormalizeTeam(value)
    if not Fields(value, TeamFields) then return nil end
    local team = Copy(value)
    team.name = Trim(team.name)
    if not team.name or team.name == "" then return nil end
    if team.pets == nil then team.pets = {} end
    if not Array(team.pets, 3) then return nil end
    if team.tags == nil then
        team.tags = {}
        for i = 1, #team.pets do team.tags[i] = {} end
    end
    if not Array(team.tags, 3) or #team.tags ~= #team.pets then return nil end
    for i, pet in ipairs(team.pets) do
        if not Pet(pet) or not Tag(team.tags[i]) then return nil end
    end
    for _, field in ipairs({ "notes", "script" }) do
        if team[field] ~= nil and type(team[field]) ~= "string" then return nil end
        if team[field] == "" then team[field] = nil end
    end
    for _, field in ipairs({ "groupID", "homeID" }) do
        if team[field] ~= nil and type(team[field]) ~= "string" then return nil end
    end
    if team.favorite ~= nil and type(team.favorite) ~= "boolean" then return nil end
    if team.preferences ~= nil then
        if not Preferences(team.preferences) then return nil end
        if not next(team.preferences) then team.preferences = nil end
    end
    if team.targets ~= nil then
        if not Array(team.targets) then return nil end
        local targets = {}
        for _, entry in ipairs(team.targets) do
            local id = Target(entry)
            if not id then return nil end
            if not Contains(targets, id) then targets[#targets + 1] = id end
        end
        team.targets = #targets > 0 and targets or nil
    end
    if team.winrecord ~= nil then
        if type(team.winrecord) ~= "table" then return nil end
        for key in pairs(team.winrecord) do
            if key ~= "wins" and key ~= "losses" and key ~= "draws" and key ~= "battles" then return nil end
        end
        local record = team.winrecord
        if record.battles ~= nil and not Integer(record.battles, 0) then return nil end
        for _, key in ipairs({ "wins", "losses", "draws" }) do
            if record[key] == nil then record[key] = 0 end
            if not Integer(record[key], 0) then return nil end
        end
        record.battles = record.wins + record.losses + record.draws
        if not Integer(record.battles, 0) then return nil end
        if record.battles == 0 then team.winrecord = nil end
    end
    return team
end

local function NormalizeGroup(value)
    if not Fields(value, GroupFields) then return nil end
    local group = Copy(value)
    group.name = Trim(group.name)
    if not group.name or group.name == "" then return nil end
    if group.sortMode == nil then group.sortMode = "alpha" end
    if group.sortMode ~= "alpha" and group.sortMode ~= "wins" and group.sortMode ~= "custom" then return nil end
    if group.teams == nil then group.teams = {} end
    if not Array(group.teams) then return nil end
    for _, id in ipairs(group.teams) do if type(id) ~= "string" then return nil end end
    if group.icon == "" then group.icon = nil end
    if group.color == "" then group.color = nil end
    if group.icon ~= nil and type(group.icon) ~= "string" and not Integer(group.icon, 1) then return nil end
    if group.color ~= nil and (type(group.color) ~= "string" or not group.color:match("^%x%x%x%x%x%x$")) then return nil end
    for _, field in ipairs({ "isExpanded", "showTab", "meta" }) do
        if group[field] ~= nil and type(group[field]) ~= "boolean" then return nil end
    end
    if group.preferences ~= nil then
        if not Preferences(group.preferences) then return nil end
        if not next(group.preferences) then group.preferences = nil end
    end
    return group
end

local function NameOwner(store, name, except)
    for id, team in pairs(store.teamsByID) do
        if id ~= except and team.name:lower() == name:lower() then return id end
    end
end

local function UniqueName(store, name)
    if not NameOwner(store, name) then return name end
    local base, number = name:gsub(" %(%d+%)$", ""), 2
    while NameOwner(store, base .. " (" .. number .. ")") do number = number + 1 end
    return base .. " (" .. number .. ")"
end

local function Place(store, team, destination)
    if not store.groupsByID[destination] then destination = Ungrouped end
    if destination == Favorites then
        if team.groupID ~= Favorites then team.homeID = team.groupID or Ungrouped end
        team.favorite = true
    else
        team.favorite, team.homeID = nil, nil
    end
    team.groupID = destination
end

local function Reconcile(store)
    local order, seen = { Favorites, Ungrouped }, { [Favorites] = true, [Ungrouped] = true }
    for _, id in ipairs(store.groupOrder) do
        if store.groupsByID[id] and not seen[id] then order[#order + 1], seen[id] = id, true end
    end
    for _, id in ipairs(Keys(store.groupsByID)) do
        if not seen[id] then order[#order + 1] = id end
    end
    store.groupOrder = order
    local ids, tabs = Keys(store.teamsByID), 0
    for _, id in ipairs(ids) do
        local team = store.teamsByID[id]
        local destination = team.favorite and Favorites or team.groupID or Ungrouped
        Place(store, team, destination)
        if team.homeID and (team.homeID == Favorites or not store.groupsByID[team.homeID]) then
            team.homeID = Ungrouped
        end
    end
    for _, groupID in ipairs(order) do
        local group, members, used = store.groupsByID[groupID], {}, {}
        for _, id in ipairs(group.teams) do
            if store.teamsByID[id] and store.teamsByID[id].groupID == groupID and not used[id] then
                members[#members + 1], used[id] = id, true
            end
        end
        for _, id in ipairs(ids) do
            if store.teamsByID[id].groupID == groupID and not used[id] then members[#members + 1] = id end
        end
        group.teams = members
        if group.showTab then
            tabs = tabs + 1
            if tabs > 16 then group.showTab = nil end
        end
    end
    local targets = {}
    for npcID, members in pairs(store.targetsByID) do
        local list, used = {}, {}
        for _, id in ipairs(members) do
            if store.teamsByID[id] and Contains(store.teamsByID[id].targets, npcID) and not used[id] then
                list[#list + 1], used[id] = id, true
            end
        end
        if #list > 0 then targets[npcID] = list end
    end
    for _, id in ipairs(ids) do
        for _, npcID in ipairs(store.teamsByID[id].targets or {}) do
            targets[npcID] = targets[npcID] or {}
            if not Contains(targets[npcID], id) then table.insert(targets[npcID], id) end
        end
    end
    store.targetsByID = targets
end

function Teams.Initialize(rawStore)
    local store, status = BattleBuddyStore.Initialize(rawStore)
    if not store then return nil, status end
    if not Array(store.groupOrder) then return nil, "malformed" end
    for _, id in ipairs(store.groupOrder) do if type(id) ~= "string" then return nil, "malformed" end end
    for id, value in pairs(store.groupsByID) do
        if type(value) ~= "table" or type(value.teams) ~= "table" or type(value.sortMode) ~= "string" then
            return nil, "malformed"
        end
        local group = NormalizeGroup(value)
        if not group or group.groupID ~= id
            or (id ~= Favorites and id ~= Ungrouped and (not ValidID(id, "group") or group.meta)) then
            return nil, "malformed"
        end
        store.groupsByID[id] = group
    end
    local defaults = BattleBuddyStore.New().groupsByID
    for _, id in ipairs({ Favorites, Ungrouped }) do
        local group = store.groupsByID[id] or defaults[id]
        group.name, group.icon, group.meta = defaults[id].name, defaults[id].icon, true
        store.groupsByID[id] = group
    end
    local names = {}
    for id, value in pairs(store.teamsByID) do
        if type(value) ~= "table" or type(value.pets) ~= "table" or type(value.tags) ~= "table" then
            return nil, "malformed"
        end
        local team = NormalizeTeam(value)
        if not team or team.teamID ~= id or not ValidID(id, "team") or names[string.lower(team.name)] then
            return nil, "malformed"
        end
        names[string.lower(team.name)], store.teamsByID[id] = true, team
    end
    for id, list in pairs(store.targetsByID) do
        if not Integer(id, 1) or not Array(list) then return nil, "malformed" end
        for _, teamID in ipairs(list) do if type(teamID) ~= "string" then return nil, "malformed" end end
    end
    Reconcile(store)
    return store, status
end

function Teams.GetTeam(store, id)
    return Copy(store.teamsByID[id])
end

function Teams.NewWorkingRecords()
    local records = {}
    for _, id in ipairs({ "empty", "sideline", "loadonly", "temporary", "original", "counter" }) do
        records[id] = { teamID = id, name = "", pets = {}, tags = {} }
    end
    return records
end

function Teams.GetGroup(store, id)
    return Copy(store.groupsByID[id])
end

function Teams.FindByName(store, name)
    name = Trim(name)
    if name then return Teams.GetTeam(store, NameOwner(store, name)) end
end

function Teams.ListGroups(store)
    local groups = {}
    for _, id in ipairs(store.groupOrder) do groups[#groups + 1] = Teams.GetGroup(store, id) end
    return groups
end

function Teams.ListTeams(store, groupID, rawWins)
    local result = {}
    if not groupID then
        for _, id in ipairs(store.groupOrder) do
            for _, team in ipairs(Teams.ListTeams(store, id, rawWins)) do result[#result + 1] = team end
        end
        return result
    end
    local group = store.groupsByID[groupID]
    if not group then return result end
    for _, id in ipairs(group.teams) do result[#result + 1] = Teams.GetTeam(store, id) end
    if group.sortMode ~= "custom" then
        table.sort(result, function(a, b)
            if (a.favorite == true) ~= (b.favorite == true) then return a.favorite == true end
            if group.sortMode == "wins" then
                local ar, br = a.winrecord or {}, b.winrecord or {}
                local av, bv = ar.wins or 0, br.wins or 0
                if not rawWins then av, bv = av / math.max(ar.battles or 0, 1), bv / math.max(br.battles or 0, 1) end
                if av ~= bv then return av > bv end
            end
            if a.name:lower() ~= b.name:lower() then return a.name:lower() < b.name:lower() end
            return a.teamID < b.teamID
        end)
    end
    return result
end

function Teams.ListByTarget(store, targetID)
    local id, result = Target(targetID), {}
    for _, teamID in ipairs(id and store.targetsByID[id] or {}) do result[#result + 1] = Teams.GetTeam(store, teamID) end
    return result
end

function Teams.CreateTeam(store, value)
    local team = NormalizeTeam(value)
    if not team or team.teamID ~= nil then return nil, "invalid_team" end
    team.teamID, team.name = Allocate(store.teamsByID, "team:"), UniqueName(store, team.name)
    store.teamsByID[team.teamID] = team
    Reconcile(store)
    return Copy(team)
end

function Teams.EditTeam(store, id, patch)
    local current = store.teamsByID[id]
    if not current then return nil, "unknown_team" end
    if not Fields(patch, TeamFields) or (patch.teamID ~= nil and patch.teamID ~= id) then return nil, "invalid_team" end
    local value = Copy(current)
    for key, item in pairs(patch) do value[key] = item end
    local team = NormalizeTeam(value)
    if not team then return nil, "invalid_team" end
    if NameOwner(store, team.name, id) then return nil, "name_conflict" end
    if patch.groupID ~= nil then
        team.groupID = current.groupID
        Place(store, team, patch.groupID)
    elseif patch.favorite == false and current.favorite then Place(store, team, current.homeID or Ungrouped) end
    store.teamsByID[id] = team
    Reconcile(store)
    return Copy(team)
end

function Teams.MoveTeam(store, id, groupID, position)
    local team, group = store.teamsByID[id], store.groupsByID[groupID]
    if not team or not group then return nil, "unknown_destination_or_team" end
    local maximum = #group.teams + (Contains(group.teams, id) and 0 or 1)
    if position ~= nil and (not Integer(position, 1) or position > maximum) then return nil, "invalid_position" end
    if position ~= nil and group.sortMode ~= "custom" then
        local members = Teams.ListTeams(store, groupID)
        group.teams = {}
        for _, member in ipairs(members) do group.teams[#group.teams + 1] = member.teamID end
    end
    Remove(group.teams, id)
    Place(store, team, groupID)
    table.insert(group.teams, position or #group.teams + 1, id)
    if position ~= nil then group.sortMode = "custom" end
    Reconcile(store)
    return Copy(team)
end

function Teams.SetFavorite(store, id, favorite)
    local team = store.teamsByID[id]
    if not team or type(favorite) ~= "boolean" then return nil, "invalid_favorite" end
    if favorite == (team.favorite == true) then return Copy(team) end
    return Teams.MoveTeam(store, id, favorite and Favorites or team.homeID or Ungrouped)
end

function Teams.DuplicateTeam(store, id, groupID)
    local team = Teams.GetTeam(store, id)
    if not team then return nil, "unknown_team" end
    team.teamID = nil
    if groupID ~= nil then
        if not store.groupsByID[groupID] then return nil, "unknown_group" end
        Place(store, team, groupID)
    end
    return Teams.CreateTeam(store, team)
end

function Teams.DeleteTeam(store, id, confirm)
    if confirm ~= true then return nil, "confirmation_required" end
    if not store.teamsByID[id] then return nil, "unknown_team" end
    store.teamsByID[id] = nil
    Reconcile(store)
    return true
end

function Teams.CreateGroup(store, value)
    local group = NormalizeGroup(value)
    if not group or group.groupID ~= nil or group.meta ~= nil or #group.teams > 0 then return nil, "invalid_group" end
    group.groupID = Allocate(store.groupsByID, "group:")
    store.groupsByID[group.groupID] = group
    table.insert(store.groupOrder, group.groupID)
    Reconcile(store)
    return Copy(group)
end

function Teams.EditGroup(store, id, patch)
    local current = store.groupsByID[id]
    if not current or current.meta then return nil, "protected_or_unknown_group" end
    if not Fields(patch, GroupFields) or patch.groupID ~= nil or patch.meta ~= nil or patch.teams ~= nil then return nil, "invalid_group" end
    local value = Copy(current)
    for key, item in pairs(patch) do value[key] = item end
    local group = NormalizeGroup(value)
    if not group then return nil, "invalid_group" end
    store.groupsByID[id] = group
    Reconcile(store)
    return Copy(group)
end

function Teams.SetGroupExpanded(store, id, expanded)
    local group = store.groupsByID[id]
    if not group or type(expanded) ~= "boolean" then return nil, "invalid_group" end
    group.isExpanded = expanded
    return Copy(group)
end

function Teams.MoveGroup(store, id, position)
    local group = store.groupsByID[id]
    if not group or group.meta then return nil, "protected_or_unknown_group" end
    if not Integer(position, 3) or position > #store.groupOrder then return nil, "invalid_position" end
    Remove(store.groupOrder, id)
    table.insert(store.groupOrder, position, id)
    return Copy(group)
end

function Teams.DuplicateGroup(store, id)
    local source = Teams.GetGroup(store, id)
    if not source then return nil, "unknown_group" end
    local members = Teams.ListTeams(store, id)
    source.groupID, source.meta, source.teams = nil, nil, {}
    local group, reason = Teams.CreateGroup(store, source)
    if not group then return nil, reason end
    for _, team in ipairs(members) do Teams.DuplicateTeam(store, team.teamID, group.groupID) end
    return Teams.GetGroup(store, group.groupID)
end

function Teams.DeleteGroup(store, id, confirm, deleteTeams)
    if confirm ~= true then return nil, "confirmation_required" end
    local group = store.groupsByID[id]
    if not group or group.meta then return nil, "protected_or_unknown_group" end
    if deleteTeams ~= nil and type(deleteTeams) ~= "boolean" then return nil, "invalid_delete_mode" end
    for _, teamID in ipairs(group.teams) do
        if deleteTeams then store.teamsByID[teamID] = nil
        else Place(store, store.teamsByID[teamID], Ungrouped) end
    end
    store.groupsByID[id] = nil
    Reconcile(store)
    return true
end

function Teams.AttachTarget(store, teamID, targetID, position)
    local team, id = Teams.GetTeam(store, teamID), Target(targetID)
    if not team or not id then return nil, "invalid_target_or_team" end
    local targets = team.targets or {}
    if not position and Contains(targets, id) then return team end
    Remove(targets, id)
    if position ~= nil and (not Integer(position, 1) or position > #targets + 1) then return nil, "invalid_position" end
    table.insert(targets, position or #targets + 1, id)
    return Teams.EditTeam(store, teamID, { targets = targets })
end

function Teams.DetachTarget(store, teamID, targetID)
    local team, id = Teams.GetTeam(store, teamID), Target(targetID)
    if not team or not id then return nil, "invalid_target_or_team" end
    local targets = team.targets or {}
    Remove(targets, id)
    return Teams.EditTeam(store, teamID, { targets = targets })
end

function Teams.SetTargetTeams(store, targetID, teamIDs)
    local id = Target(targetID)
    if not id or not Plain(teamIDs) or not Array(teamIDs) then return nil, "invalid_target" end
    local seen = {}
    for _, teamID in ipairs(teamIDs) do
        if type(teamID) ~= "string" or not store.teamsByID[teamID] or seen[teamID] then return nil, "invalid_team" end
        seen[teamID] = true
    end
    for teamID, team in pairs(store.teamsByID) do
        local targets = team.targets or {}
        if seen[teamID] then
            if not Contains(targets, id) then table.insert(targets, id) end
        else Remove(targets, id) end
        team.targets = #targets > 0 and targets or nil
    end
    store.targetsByID[id] = Copy(teamIDs)
    Reconcile(store)
    return true
end

function Teams.LoadTeam(store, id, resolver)
    local team = Teams.GetTeam(store, id)
    if not team then return nil, "unknown_team" end
    if resolver ~= nil and type(resolver) ~= "function" then return nil, "invalid_resolver" end
    team.slots = {}
    for index = 1, 3 do
        local petID, tag = team.pets[index], team.tags[index]
        local needsResolution = petID ~= nil and petID ~= "empty" and petID ~= "ignored"
        local resolved
        if resolver and needsResolution then
            local ok, value = pcall(resolver, petID, Copy(tag), index)
            if ok and type(value) == "string" and value:match("^BattlePet%-.+") then resolved = value end
        end
        team.slots[index] = { petID = petID, tag = Copy(tag), resolvedPetID = resolved, unresolved = needsResolution and resolved == nil }
    end
    return team
end

function Teams.BuildIndexes(store)
    local result = { byName = {}, petCounts = {}, count = 0 }
    for _, team in ipairs(Teams.ListTeams(store)) do
        result.count = result.count + 1
        result.byName[team.name:lower()] = team.teamID
        local seen = {}
        for index, petID in ipairs(team.pets) do
            seen[petID] = true
            local speciesID = team.tags[index].speciesID
            if speciesID then seen[speciesID] = true end
        end
        for petID in pairs(seen) do result.petCounts[petID] = (result.petCounts[petID] or 0) + 1 end
    end
    return result
end

function Teams.EffectivePreferences(store, id, defaults)
    if not Plain(defaults) or (defaults ~= nil and not Preferences(defaults)) then return nil, "invalid_preferences" end
    local team = store.teamsByID[id]
    if not team then return nil, "unknown_team" end
    local result = Copy(defaults or {})
    local group = store.groupsByID[team.groupID]
    for _, layer in ipairs({ group.preferences or {}, team.preferences or {} }) do
        for key, value in pairs(layer) do result[key] = value end
    end
    return result
end
