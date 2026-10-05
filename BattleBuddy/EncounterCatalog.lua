BattleBuddyEncounterCatalog = {}

local Catalog = BattleBuddyEncounterCatalog
Catalog.SchemaVersion = 1

local function Public(value, kind)
    return BattleBuddyCompatibility and BattleBuddyCompatibility.PublicValue(value, kind)
end

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

local function OptionalArray(value, valid)
    if value == nil then return true end
    if not Array(value) then return false end
    for _, item in ipairs(value) do if not valid(item) then return false end end
    return true
end

local function SelectorsOverlap(left, right)
    if left.npcID ~= right.npcID then return false end
    for _, field in ipairs({ "activityID", "contextKey", "questID" }) do
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
    if not OptionalArray(record.display.aliases, Text) or not OptionalArray(record.content.gossipHints, Text)
        or (record.display.locale ~= nil and not Text(record.display.locale))
        or (record.content.questID ~= nil and not PositiveInteger(record.content.questID))
        or not OptionalArray(record.content.enemyPets, function(pet)
            return type(pet) == "table" and (pet.speciesID == nil or PositiveInteger(pet.speciesID))
        end) then return false end
    for _, selector in ipairs(record.selectors) do
        if type(selector) ~= "table" or not PositiveInteger(selector.npcID)
            or (selector.activityID ~= nil and not Text(selector.activityID))
            or (selector.contextKey ~= nil and not Text(selector.contextKey))
            or (selector.questID ~= nil and not PositiveInteger(selector.questID)) then return false end
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
    record.effectiveRecordRevision = record.recordRevision + 1
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
            local copied = Copy(record)
            copied.effectiveRecordRevision = copied.recordRevision
            view.records[#view.records + 1] = copied
            view.recordsByID[record.encounterID] = Copy(copied)
        end
    end
    if input.overrides ~= nil and not Array(input.overrides) then
        view.diagnostics[#view.diagnostics + 1] = { reason = "INVALID_RECORD" }
    else
        local overriddenIDs = {}
        for _, override in ipairs(input.overrides or {}) do
            local targetID = type(override) == "table" and override.targetEncounterID or nil
            local target = view.recordsByID[targetID]
            local valid, result = ValidateOverride(override, target)
            if valid and overriddenIDs[targetID] then
                valid, result = false, "ID_COLLISION"
            end
            if valid then
                overriddenIDs[targetID] = true
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
            recordRevision = record.recordRevision,
            effectiveRecordRevision = record.effectiveRecordRevision or record.recordRevision,
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
    expectedRevision = Public(expectedRevision, "number")
    if expectedRevision and expectedRevision ~= catalog.catalogRevision then return { state = "stale", candidateIDs = {}, reason = "STALE_CATALOG" } end
    observation = Public(observation, "table") or {}
    observation = { npcID = Public(observation.npcID, "number"), activityID = Public(observation.activityID, "string"),
        contextKey = Public(observation.contextKey, "string"), questID = Public(observation.questID, "number") }
    if not PositiveInteger(observation.npcID) then return { state = "unresolved", candidateIDs = {}, reason = "INSUFFICIENT_CONTEXT" } end
    local candidates, complete = {}, {}
    for _, record in ipairs(catalog.records) do
        for _, selector in ipairs(record.selectors) do
            local matches, completed = selector.npcID == observation.npcID, true
            for _, field in ipairs({ "activityID", "contextKey", "questID" }) do
                if selector[field] then
                    if observation[field] and selector[field] ~= observation[field] then matches = false end
                    if selector[field] ~= observation[field] then completed = false end
                end
            end
            if matches then
                candidates[record.encounterID] = true
                if completed then complete[record.encounterID] = true end
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

local function Normalize(value)
    value = Public(value, "string")
    return value and value:lower():match("^%s*(.-)%s*$"):gsub("[%p%s]+$", "") or ""
end

local function Names(record)
    local names = { record.display.fallbackLabel }
    for _, alias in ipairs(record.display.aliases or {}) do names[#names + 1] = alias end
    return names
end

local function HasPhrase(text, phrase)
    if phrase == "" then return false end
    local from = 1
    while true do
        local first, last = text:find(phrase, from, true)
        if not first then return false end
        if (first == 1 or not text:sub(first - 1, first - 1):match("[%w_]"))
            and (last == #text or not text:sub(last + 1, last + 1):match("[%w_]")) then return true end
        from = last + 1
    end
end

function Catalog.Lookup(catalog, observation, expectedRevision)
    if type(catalog) ~= "table" or catalog.state == "invalid" then
        return { state = "unresolved", candidateIDs = {}, reason = "INVALID_CATALOG" }
    end
    observation = Public(observation, "table") or {}
    expectedRevision = Public(expectedRevision, "number")
    if expectedRevision and expectedRevision ~= catalog.catalogRevision then
        return { state = "stale", candidateIDs = {}, reason = "STALE_CATALOG" }
    end
    local function Finish(result)
        if result.state == "unique" then
            result.encounter = Copy(catalog.recordsByID[result.encounterID])
            result.npcID = result.encounter.selectors[1].npcID
        end
        return result
    end
    local npcID = Public(observation.npcID, "number")
    if PositiveInteger(npcID) then return Finish(Catalog.MatchEncounter(catalog, observation, expectedRevision)) end
    local questID = Public(observation.questID, "number")
    if not PositiveInteger(questID) then questID = nil end
    local function QuestMatches(record)
        if not questID or record.content.questID == questID then return true end
        for _, selector in ipairs(record.selectors) do
            if selector.questID == questID then return true end
        end
        return false
    end
    local function Find(predicate)
        local ids = {}
        for _, record in ipairs(catalog.records or {}) do
            if QuestMatches(record) and predicate(record) then ids[#ids + 1] = record.encounterID end
        end
        table.sort(ids)
        if #ids > 1 then return { state = "ambiguous", candidateIDs = ids, reason = "AMBIGUOUS_MATCH" } end
        if #ids == 1 then return Finish({ state = "unique", candidateIDs = ids, encounterID = ids[1], reason = "MATCHED" }) end
    end
    local speciesID = Public(observation.speciesID, "number")
    local result
    if PositiveInteger(speciesID) then
        result = Find(function(record)
            for _, pet in ipairs(record.content.enemyPets or {}) do
                if pet.speciesID == speciesID then return true end
            end
        end)
        if result then return result end
    end
    local locale = Public(observation.locale, "string") or "enUS"
    local function Localized(record) return (record.display.locale or "enUS") == locale end
    local name, prefix = Normalize(observation.name), Normalize(observation.prefix)
    for _, partial in ipairs({ false, true }) do
        local wanted = partial and prefix or name
        if wanted ~= "" then
            result = Find(function(record)
                if not Localized(record) then return false end
                for _, candidate in ipairs(Names(record)) do
                    candidate = Normalize(candidate)
                    if candidate == wanted or (partial and candidate:sub(1, #wanted) == wanted) then return true end
                end
            end)
            if result then return result end
        end
    end
    for _, field in ipairs({ "gossipTexts", "publicTexts", "scenarioTexts" }) do
        local texts = Public(observation[field], "table") or {}
        result = Find(function(record)
            if not Localized(record) then return false end
            local phrases = Names(record)
            for _, hint in ipairs(record.content.gossipHints or {}) do phrases[#phrases + 1] = hint end
            for _, raw in ipairs(texts) do
                local text = Normalize(raw)
                for _, phrase in ipairs(phrases) do
                    if HasPhrase(text, Normalize(phrase)) then return true end
                end
                raw = Public(raw, "string")
                if field == "publicTexts" and raw and (raw:match("%.%.%.%s*$") or raw:match("…%s*$")) then
                    local truncated = Normalize(raw:gsub("…%s*$", ""))
                    for _, candidate in ipairs(Names(record)) do
                        if truncated ~= "" and Normalize(candidate):sub(1, #truncated) == truncated then return true end
                    end
                end
            end
        end)
        if result then return result end
    end
    if questID then
        result = Find(function() return true end)
        if result then return result end
    end
    return { state = "unresolved", candidateIDs = {}, reason = "MISSING_ENCOUNTER" }
end
