BattleBuddyEncounterCatalog = {}

local Catalog = BattleBuddyEncounterCatalog
Catalog.SchemaVersion = 1

local function Text(value)
    return type(value) == "string" and value ~= ""
end

local function PositiveInteger(value)
    return type(value) == "number" and value > 0 and value % 1 == 0
end

local function Array(value)
    if type(value) ~= "table" then return false end
    for key in pairs(value) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then return false end
    end
    return true
end

local function Copy(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, item in pairs(value) do copy[Copy(key)] = Copy(item) end
    return copy
end

local function SelectorsOverlap(left, right)
    if left.npcID ~= right.npcID then return false end
    for _, field in ipairs({ "activityID", "contextKey" }) do
        if left[field] and right[field] and left[field] ~= right[field] then return false end
    end
    return true
end

local function Record(record)
    if type(record) ~= "table" or (record.origin ~= "shipped" and record.origin ~= "custom")
        or not Text(record.encounterID) or not PositiveInteger(record.recordRevision)
        or type(record.display) ~= "table" or not Text(record.display.fallbackLabel)
        or type(record.content) ~= "table" or type(record.support) ~= "table"
        or (record.support.state ~= "unverified" and record.support.state ~= "supported" and record.support.state ~= "unsupported")
        or not Array(record.selectors) or #record.selectors == 0 then return false end
    local prefix = record.origin == "shipped" and "shipped." or "custom."
    if record.encounterID:sub(1, #prefix) ~= prefix then return false end
    for _, selector in ipairs(record.selectors) do
        if type(selector) ~= "table" or not PositiveInteger(selector.npcID)
            or (selector.activityID ~= nil and not Text(selector.activityID))
            or (selector.contextKey ~= nil and not Text(selector.contextKey)) then return false end
    end
    return true
end

local function ValidateOverride(override, record)
    if type(override) ~= "table" or not Text(override.targetEncounterID)
        or not PositiveInteger(override.baseRecordRevision) or type(override.content) ~= "table" then
        return false, "INVALID_RECORD"
    end
    if not record then return false, "MISSING_ENCOUNTER" end
    if record.origin ~= "shipped" or record.recordRevision ~= override.baseRecordRevision then
        return false, record.origin == "shipped" and "OVERRIDE_BASE_CHANGED" or "INVALID_RECORD"
    end
    for field, value in pairs(override.content) do
        if (field ~= "interactionProfile" and field ~= "healingProfile") or not Text(value) then return false, "INVALID_RECORD" end
    end
    return true, Copy(override)
end

local function ApplyOverride(record, override)
    for field, value in pairs(override.content) do record.content[field] = value end
end

function Catalog.BuildView(input)
    input = type(input) == "table" and input or {}
    local view = { state = "ready", catalogRevision = input.catalogRevision, records = {}, recordsByID = {}, diagnostics = {} }
    if input.schemaVersion ~= Catalog.SchemaVersion or not PositiveInteger(input.catalogRevision) or not Array(input.records) then
        return { state = "invalid", diagnostics = { { reason = "INVALID_CATALOG" } }, records = {}, recordsByID = {} }
    end
    local selectorOwners = {}
    for _, record in ipairs(input.records) do
        if not Record(record) then
            view.diagnostics[#view.diagnostics + 1] = { reason = "INVALID_RECORD" }
        elseif view.recordsByID[record.encounterID] then
            view.diagnostics[#view.diagnostics + 1] = { encounterID = record.encounterID, reason = "ID_COLLISION" }
        else
            for _, selector in ipairs(record.selectors) do
                for _, owner in ipairs(selectorOwners) do
                    if SelectorsOverlap(selector, owner.selector) then
                        view.diagnostics[#view.diagnostics + 1] = { reason = "SELECTOR_OVERLAP", encounterID = record.encounterID, competingEncounterID = owner.encounterID }
                    end
                end
                selectorOwners[#selectorOwners + 1] = { encounterID = record.encounterID, selector = selector }
            end
            view.records[#view.records + 1] = Copy(record)
            view.recordsByID[record.encounterID] = Copy(record)
        end
    end
    if input.overrides ~= nil and not Array(input.overrides) then
        view.diagnostics[#view.diagnostics + 1] = { reason = "INVALID_RECORD" }
    else
        for _, override in ipairs(input.overrides or {}) do
            local targetID = type(override) == "table" and override.targetEncounterID or nil
            local target = view.recordsByID[targetID]
            local valid, result = ValidateOverride(override, target)
            if valid then
                ApplyOverride(target, result)
                for _, record in ipairs(view.records) do
                    if record.encounterID == target.encounterID then ApplyOverride(record, result) end
                end
            else
                view.diagnostics[#view.diagnostics + 1] = {
                    encounterID = type(override) == "table" and override.targetEncounterID or nil,
                    reason = result,
                }
            end
        end
    end
    if #view.diagnostics > 0 then view.state = "diagnostic" end
    return view
end

function Catalog.GetEncounter(catalog, encounterID)
    local record = type(catalog) == "table" and catalog.recordsByID and catalog.recordsByID[encounterID]
    return record and { state = "found", encounter = Copy(record) } or { state = "missing", reason = "MISSING_ENCOUNTER" }
end

function Catalog.BuildBrowserInput(catalog, selectedEncounterID, filters)
    if type(catalog) ~= "table" or catalog.state == "invalid" then
        return { filters = filters, selectedEncounterID = selectedEncounterID }
    end

    local encounters = {}
    for _, record in ipairs(catalog.records or {}) do
        local content = type(record.content) == "table" and record.content or {}
        local support = type(record.support) == "table" and record.support or {}
        encounters[#encounters + 1] = {
            encounterID = record.encounterID,
            label = record.display.fallbackLabel,
            expansion = content.expansion,
            zone = content.zone,
            availability = "unknown",
            support = support.state or "unverified",
        }
    end

    return {
        encounters = encounters,
        filters = filters,
        selectedEncounterID = selectedEncounterID,
    }
end

function Catalog.ValidateOverride(override, catalog)
    local target = Catalog.GetEncounter(catalog, type(override) == "table" and override.targetEncounterID or nil).encounter
    return ValidateOverride(override, target)
end

function Catalog.MatchEncounter(catalog, observation, expectedRevision)
    if type(catalog) ~= "table" or catalog.state == "invalid" then return { state = "unresolved", candidateIDs = {}, reason = "INVALID_CATALOG" } end
    if expectedRevision and expectedRevision ~= catalog.catalogRevision then return { state = "stale", candidateIDs = {}, reason = "STALE_CATALOG" } end
    if type(observation) ~= "table" or not PositiveInteger(observation.npcID) then return { state = "unresolved", candidateIDs = {}, reason = "INSUFFICIENT_CONTEXT" } end
    local candidates, complete = {}, {}
    for _, record in ipairs(catalog.records) do
        for _, selector in ipairs(record.selectors) do
            local matches = selector.npcID == observation.npcID and (not Text(observation.activityID) or not selector.activityID or selector.activityID == observation.activityID) and (not Text(observation.contextKey) or not selector.contextKey or selector.contextKey == observation.contextKey)
            if matches then
                candidates[record.encounterID] = true
                if (not selector.activityID or selector.activityID == observation.activityID) and (not selector.contextKey or selector.contextKey == observation.contextKey) then complete[record.encounterID] = true end
            end
        end
    end
    local ids = {}
    for id in pairs(candidates) do ids[#ids + 1] = id end
    table.sort(ids)
    if #ids == 0 then return { state = "unresolved", candidateIDs = ids, reason = "MISSING_ENCOUNTER" } end
    if #ids > 1 then return { state = "ambiguous", candidateIDs = ids, reason = "AMBIGUOUS_MATCH" } end
    if complete[ids[1]] then return { state = "unique", candidateIDs = ids, encounterID = ids[1], reason = "MATCHED" } end
    return { state = "unresolved", candidateIDs = ids, reason = "INSUFFICIENT_CONTEXT" }
end
