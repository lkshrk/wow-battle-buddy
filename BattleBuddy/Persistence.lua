BattleBuddyPersistence = {}

local Persistence = BattleBuddyPersistence

Persistence.Status = "uninitialized"

function Persistence.Initialize(rawStore)
    local model = BattleBuddyTeams or BattleBuddyStore
    local store, classification = model.Initialize(rawStore)
    if not store then
        Persistence.Status = classification
        return nil, classification
    end

    Persistence.Status = classification
    return store, classification
end

function Persistence.Load()
    local store, classification = Persistence.Initialize(BattleBuddyDB)
    if store then
        BattleBuddyDB = store
    end

    return classification
end
