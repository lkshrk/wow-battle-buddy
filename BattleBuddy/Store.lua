BattleBuddyStore = {}

local Store = BattleBuddyStore

Store.SchemaVersion = 3

local RequiredContainers = {
    "teamsByID",
    "foldersByID",
    "scriptsByID",
    "encounterAssignments",
    "encounterOverrides",
    "preferredTeamByEncounter",
    "levelingQueue",
    "settingOverrides",
    "transportRecords",
    "recoveryRecords",
    "groupsByID",
    "groupOrder",
    "targetsByID",
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
        if (type(key) ~= "string" and type(key) ~= "number")
            or not IsPlainData(key, seen) or not IsPlainData(item, seen) then
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

local function IsValidStore(store, version)
    if type(store) ~= "table" or getmetatable(store) ~= nil then
        return false
    end

    if store.schemaVersion ~= version
        or not IsNonNegativeInteger(store.storeRevision)
        or not IsNonNegativeInteger(store.nextEntitySequence)
        or store.nextEntitySequence < 1 then
        return false
    end

    for _, field in ipairs(RequiredContainers) do
        local introduced = field == "encounterOverrides" and 2
            or (field == "groupsByID" or field == "groupOrder" or field == "targetsByID") and 3 or 1
        if version >= introduced and type(store[field]) ~= "table" then
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
        groupsByID = {
            ["group:favorites"] = {
                groupID = "group:favorites",
                name = "Favorite Teams",
                icon = "Interface\\Icons\\ACHIEVEMENT_GUILDPERK_MRPOPULARITY_RANK2",
                meta = true,
                sortMode = "alpha",
                teams = {},
            },
            ["group:none"] = {
                groupID = "group:none",
                name = "Ungrouped Teams",
                icon = "Interface\\Icons\\INV_Pet_BattlePetTraining",
                meta = true,
                sortMode = "alpha",
                teams = {},
            },
        },
        groupOrder = { "group:favorites", "group:none" },
        targetsByID = {},
        foldersByID = {},
        scriptsByID = {},
        encounterAssignments = {},
        encounterOverrides = {},
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

    if type(rawStore) ~= "table" or getmetatable(rawStore) ~= nil or type(rawStore.schemaVersion) ~= "number"
        or rawStore.schemaVersion % 1 ~= 0 or rawStore.schemaVersion < 0 then
        return "malformed"
    end

    if rawStore.schemaVersion < Store.SchemaVersion then
        return "old"
    end

    if rawStore.schemaVersion > Store.SchemaVersion then
        return "newer"
    end

    if not IsValidStore(rawStore, Store.SchemaVersion) then
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

    if classification == "old" and (rawStore.schemaVersion == 1 or rawStore.schemaVersion == 2) then
        if not IsValidStore(rawStore, rawStore.schemaVersion) then
            return nil, "malformed"
        end
        local upgraded = Clone(rawStore, {})
        upgraded.schemaVersion = Store.SchemaVersion
        local defaults = Store.New()
        for _, field in ipairs({ "encounterOverrides", "groupsByID", "groupOrder", "targetsByID" }) do
            if upgraded[field] == nil then
                upgraded[field] = defaults[field]
            end
        end
        if IsValidStore(upgraded, Store.SchemaVersion) then
            return upgraded, "upgraded"
        end
        return nil, "malformed"
    end

    return nil, classification
end
