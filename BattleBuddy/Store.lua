BattleBuddyStore = {}

local Store = BattleBuddyStore

Store.SchemaVersion = 1

local RequiredContainers = {
    "teamsByID",
    "foldersByID",
    "scriptsByID",
    "encounterAssignments",
    "preferredTeamByEncounter",
    "levelingQueue",
    "settingOverrides",
    "transportRecords",
    "recoveryRecords",
}

local function IsNonNegativeInteger(value)
    return type(value) == "number" and value >= 0 and value % 1 == 0
end

local function IsPlainData(value, seen)
    local valueType = type(value)
    if valueType == "nil" or valueType == "boolean" or valueType == "string" then
        return true
    end

    if valueType == "number" then
        return value == value and value ~= math.huge and value ~= -math.huge
    end

    if valueType ~= "table" or getmetatable(value) ~= nil or seen[value] then
        return false
    end

    seen[value] = true
    for key, item in pairs(value) do
        if (type(key) ~= "string" and type(key) ~= "number") or not IsPlainData(item, seen) then
            seen[value] = nil
            return false
        end
    end
    seen[value] = nil
    return true
end

local function Clone(value, copies)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    copies[value] = copy
    for key, item in pairs(value) do
        copy[Clone(key, copies)] = type(item) == "table" and copies[item] or Clone(item, copies)
    end
    return copy
end

local function IsCurrentStore(store)
    if type(store) ~= "table" or getmetatable(store) ~= nil then
        return false
    end

    if store.schemaVersion ~= Store.SchemaVersion
        or not IsNonNegativeInteger(store.storeRevision)
        or not IsNonNegativeInteger(store.nextEntitySequence)
        or store.nextEntitySequence < 1 then
        return false
    end

    for _, field in ipairs(RequiredContainers) do
        if type(store[field]) ~= "table" then
            return false
        end
    end

    return IsPlainData(store, {})
end

function Store.New()
    return {
        schemaVersion = Store.SchemaVersion,
        storeRevision = 0,
        nextEntitySequence = 1,
        teamsByID = {},
        foldersByID = {},
        scriptsByID = {},
        encounterAssignments = {},
        preferredTeamByEncounter = {},
        levelingQueue = {},
        settingOverrides = {},
        transportRecords = {},
        recoveryRecords = {},
    }
end

function Store.Classify(rawStore)
    if rawStore == nil then
        return "fresh"
    end

    if type(rawStore) ~= "table" or type(rawStore.schemaVersion) ~= "number"
        or rawStore.schemaVersion % 1 ~= 0 or rawStore.schemaVersion < 0 then
        return "malformed"
    end

    if rawStore.schemaVersion < Store.SchemaVersion then
        return "old"
    end

    if rawStore.schemaVersion > Store.SchemaVersion then
        return "newer"
    end

    if not IsCurrentStore(rawStore) then
        return "malformed"
    end

    return "current"
end

function Store.Initialize(rawStore)
    local classification = Store.Classify(rawStore)
    if classification == "fresh" then
        return Store.New(), classification
    end

    if classification == "current" then
        return Clone(rawStore, {}), classification
    end

    return nil, classification
end
