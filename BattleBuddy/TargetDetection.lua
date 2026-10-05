BattleBuddyTargetDetection = {}

local Detection = BattleBuddyTargetDetection
local Public = BattleBuddyCompatibility.PublicValueOfType
local catalog, frame
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
    local npcID, excluded = Identity(unit)
    local observation = {
        npcID = npcID,
        speciesID = Public(Read(UnitBattlePetSpeciesID, unit), "number"),
        name = Public(Read(UnitName, unit), "string"),
        locale = Public(Read(GetLocale), "string"),
        gossipTexts = {}, publicTexts = {}, scenarioTexts = {},
    }
    if excluded then return nil end
    if observation.name and (observation.name:sub(-3) == "..." or observation.name:sub(-3) == "…") then
        observation.prefix = observation.name:gsub("%.%.%.$", ""):gsub("…$", "")
    end
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
        AddText(observation.publicTexts, Read(UnitName, nameplate))
        if C_NamePlate then
            VisibleText(observation.publicTexts, Read(C_NamePlate.GetNamePlateForUnit, nameplate), 5)
        end
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

function Detection.Refresh(unit, nameplate)
    unit = Public(unit, "string") or "target"
    nameplate = Public(nameplate, "string")
    if nameplate and Public(Read(UnitIsUnit, nameplate, unit), "boolean") ~= true then nameplate = nil end
    current = BattleBuddyEncounterCatalog.Lookup(catalog, Observe(unit, nameplate))
    if current.state == "unique" then
        for index = #recent, 1, -1 do
            if recent[index] == current.npcID then table.remove(recent, index) end
        end
        table.insert(recent, 1, current.npcID)
        recent[4] = nil
    end
    return Detection.GetCurrent()
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

function Detection.Start(view)
    catalog = view
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
