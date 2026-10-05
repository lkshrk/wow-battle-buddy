BattleBuddyTargetDetection = {}

local Detection = BattleBuddyTargetDetection
local Public = BattleBuddyCompatibility.PublicValueOfType
local catalog, frame, targetStore, latestObservation, latestSource
local gossipOpen = false
local current = { state = "unresolved", candidateIDs = {} }
local recent = {}

local function Read(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok then return value end
end

local function AddText(texts, value)
    value = Public(value, "string")
    if value and value ~= "" then texts[#texts + 1] = value end
end

local function VisibleText(texts, object, depth)
    object = Public(object, "table") or Public(object, "userdata")
    if not object or depth == 0 or Public(Read(object.IsShown, object), "boolean") ~= true then return end
    AddText(texts, Read(object.GetText, object))
    for _, method in ipairs({ "GetRegions", "GetChildren" }) do
        if type(object[method]) == "function" then
            local results = { pcall(object[method], object) }
            if results[1] then
                for index = 2, #results do VisibleText(texts, results[index], depth - 1) end
            end
        end
    end
end

local function Identity(unit)
    local guid = Public(Read(UnitGUID, unit), "string")
    if not guid then return nil end
    local kind = guid:match("^(%a+)%-")
    if kind == "Player" or kind == "Pet" then return nil, true end
    local _, id = guid:match("^(%a+)%-[^-]+%-[^-]+%-[^-]+%-[^-]+%-(%d+)%-")
    if kind == "Creature" or kind == "Vehicle" then return tonumber(id) end
end

local function Observe(unit, nameplate)
    if Public(Read(UnitIsPlayer, unit), "boolean") == true then return nil end
    local npcID, excluded = Identity(unit)
    local observation = {
        npcID = npcID,
        speciesID = Public(Read(UnitBattlePetSpeciesID, unit), "number"),
        name = Public(Read(UnitName, unit), "string"),
        locale = Public(Read(GetLocale), "string"),
        gossipTexts = {}, publicTexts = {}, scenarioTexts = {},
    }
    if excluded then return nil end
    local ownGossip = gossipOpen and (unit == "npc" or Public(Read(UnitIsUnit, unit, "npc"), "boolean") == true)
    if ownGossip and C_GossipInfo then
        AddText(observation.gossipTexts, Read(C_GossipInfo.GetText))
        local options = Public(Read(C_GossipInfo.GetOptions), "table")
        if options then
            for _, option in ipairs(options) do
                option = Public(option, "table")
                if option then AddText(observation.gossipTexts, option.name) end
            end
        end
    end
    if ownGossip then VisibleText(observation.gossipTexts, GossipFrame, 5) end
    if unit == "target" then
        VisibleText(observation.publicTexts, TargetFrame, 5)
    end
    if unit == "mouseover" then VisibleText(observation.publicTexts, GameTooltip, 5) end
    if nameplate then
        local name = Public(Read(UnitName, nameplate), "string")
        AddText(observation.publicTexts, name)
        if not observation.name then
            observation.name = name
        end
        if C_NamePlate then
            VisibleText(observation.publicTexts, Read(C_NamePlate.GetNamePlateForUnit, nameplate), 5)
        end
    end
    if observation.name and (observation.name:sub(-3) == "..." or observation.name:sub(-3) == "…") then
        observation.prefix = observation.name:gsub("%.%.%.$", ""):gsub("…$", "")
    end
    if C_Scenario then
        AddText(observation.scenarioTexts, Read(C_Scenario.GetInfo))
        if type(C_Scenario.GetStepInfo) == "function" then
            local ok, title, description = pcall(C_Scenario.GetStepInfo)
            if ok then
                AddText(observation.scenarioTexts, title)
                AddText(observation.scenarioTexts, description)
            end
        end
    end
    VisibleText(observation.scenarioTexts, ScenarioObjectiveTracker, 5)
    return observation
end

local function Normalize(text)
    return text and text:lower():match("^%s*(.-)%s*$"):gsub("[%p%s]+$", "") or ""
end

local function SavedTarget(store, observed)
    if not store or not BattleBuddyTeams then return nil end
    local function Find(texts, partial, phrases)
        local matches, count, matched = {}, 0, nil
        for _, team in pairs(store.teamsByID) do
            for _, key in ipairs(team.targets or {}) do
                local name = team.targetNames and team.targetNames[key]
                if not name and type(key) == "string" then name = key:match("^name:(.+)$") end
                local wanted = Normalize(name)
                for _, raw in ipairs(texts) do
                    local text = Normalize(raw)
                    local found = text ~= "" and wanted ~= "" and
                        (text == wanted or (partial and wanted:sub(1, #text) == text))
                    if phrases and wanted ~= "" then
                        local from = 1
                        while not found do
                            local first, last = text:find(wanted, from, true)
                            if not first then break end
                            found = (first == 1 or not text:sub(first - 1, first - 1):match("[%w_]"))
                                and (last == #text or not text:sub(last + 1, last + 1):match("[%w_]"))
                            from = last + 1
                        end
                        if raw:match("%.%.%.%s*$") or raw:match("…%s*$") then
                            local prefix = Normalize(raw:gsub("…%s*$", ""))
                            found = found or (prefix ~= "" and wanted:sub(1, #prefix) == prefix)
                        end
                    end
                    if found and not matches[key] then
                        matches[key], count = true, count + 1
                        matched = { key = key, npcID = type(key) == "number" and key or nil, name = name,
                            state = "unique", candidateIDs = {} }
                    end
                end
            end
        end
        if count > 1 then return { state = "ambiguous", ambiguous = true, candidateIDs = {} } end
        return matched
    end
    local result = Find({ observed.name }) or Find({ observed.prefix }, true)
    if result then return result end
    for _, field in ipairs({ "gossipTexts", "publicTexts", "scenarioTexts" }) do
        result = Find(observed[field], false, true)
        if result then return result end
    end
end

local function Resolve(store)
    local observation = latestObservation
    local result
    if observation then
        if not observation.npcID then result = SavedTarget(store, observation) end
        result = result or BattleBuddyEncounterCatalog.Lookup(catalog, observation)
        if observation.npcID then
            result.key, result.npcID = observation.npcID, observation.npcID
            result.state, result.ambiguous = "unique", nil
        elseif result.state == "unique" then
            result.key = result.key or result.npcID
        elseif result.state == "ambiguous" then
            result.ambiguous = true
        elseif observation.name and not observation.prefix then
            local name = Normalize(observation.name)
            if name ~= "" then result.key, result.state = "name:" .. name, "unique" end
        end
        result.name = result.name or observation.name
        if not result.name and result.encounter then result.name = result.encounter.display.fallbackLabel end
    end
    result = result or { state = "unresolved", candidateIDs = {} }
    result.source = latestSource or "target"
    return result
end

function Detection.Refresh(unit, nameplate)
    unit = Public(unit, "string") or "target"
    nameplate = Public(nameplate, "string")
    if nameplate and Public(Read(UnitIsUnit, nameplate, unit), "boolean") ~= true then nameplate = nil end
    latestObservation, latestSource = Observe(unit, nameplate), unit
    current = Resolve(targetStore or BattleBuddyDB)
    if current.state == "unique" and current.npcID then
        for index = #recent, 1, -1 do
            if recent[index] == current.npcID then table.remove(recent, index) end
        end
        table.insert(recent, 1, current.npcID)
        recent[4] = nil
    end
    return Detection.GetCurrent()
end

function Detection.Current()
    current = Resolve(targetStore or BattleBuddyDB)
    return Detection.GetCurrent()
end

function Detection.TeamsForCurrent(store)
    store = store or targetStore or BattleBuddyDB
    if not store then return {} end
    local target = Resolve(store)
    local teams = BattleBuddyTeams.ListByTarget(store, target.key)
    if #teams == 0 and target.npcID then
        local saved = SavedTarget(store, latestObservation)
        if saved and type(saved.key) == "string" then
            return BattleBuddyTeams.ListByTarget(store, saved.key)
        end
    end
    return teams
end

function Detection.GetRecent()
    return { unpack(recent) }
end

function Detection.GetCurrent()
    local function Copy(item)
        if type(item) ~= "table" then return item end
        local copy = {}
        for k, v in pairs(item) do copy[k] = Copy(v) end
        return copy
    end
    return Copy(current)
end

function Detection.Start(view, store)
    catalog, targetStore = view, store
    if not frame then
        frame = CreateFrame("Frame")
        for _, event in ipairs({ "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "PLAYER_SOFT_INTERACT_CHANGED",
            "GOSSIP_SHOW", "GOSSIP_CLOSED", "NAME_PLATE_UNIT_ADDED", "SCENARIO_UPDATE", "SCENARIO_CRITERIA_UPDATE", "CRITERIA_UPDATE" }) do
            frame:RegisterEvent(event)
        end
        frame:SetScript("OnEvent", function(_, event, unit)
            if event == "GOSSIP_SHOW" then gossipOpen = true end
            if event == "GOSSIP_CLOSED" or event == "PLAYER_TARGET_CHANGED" then gossipOpen = false end
            if event == "NAME_PLATE_UNIT_ADDED" then
                unit = Public(unit, "string")
                if unit and Public(Read(UnitIsUnit, unit, "target"), "boolean") == true then
                    Detection.Refresh("target", unit)
                elseif unit and gossipOpen and Public(Read(UnitIsUnit, unit, "npc"), "boolean") == true then
                    Detection.Refresh("npc", unit)
                end
            else
                local source = event == "GOSSIP_SHOW" and "npc" or "target"
                if event ~= "GOSSIP_SHOW" and type(UnitExists) == "function" then
                    source = "mouseover"
                    if Public(Read(UnitExists, source), "boolean") == false then
                        source = "softinteract"
                        if Public(Read(UnitExists, source), "boolean") == false then source = "target" end
                    end
                end
                Detection.Refresh(source)
            end
        end)
    end
    return Detection.GetCurrent()
end
