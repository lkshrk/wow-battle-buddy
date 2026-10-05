BattleBuddyAlternatives = {}

local Alternatives = BattleBuddyAlternatives
local Compatibility = BattleBuddyCompatibility

local function Number(value)
    value = Compatibility.PublicValueOfType(value, "number")
    if value and value == value and value >= 0 and value < math.huge then return value end
end

local function Field(value, key)
    return Compatibility.ReadField(value, key)
end

local function Snapshot(value)
    local pet = { abilities = {}, abilityTypes = {} }
    pet.petID = Compatibility.PublicValueOfType(Field(value, "petID"), "string")
    for _, key in ipairs({ "speciesID", "family", "level", "quality", "health", "maxHealth", "breedID" }) do
        local raw, state = Field(value, key)
        pet[key] = Number(raw)
        if (key ~= "breedID" and pet[key] == nil) or state == "secret" or state == "restricted" then
            pet.unknown = true
        end
    end
    pet.unknown = pet.unknown or Field(value, "unknown") == true
    local abilities = Compatibility.PublicValueOfType(Field(value, "abilities"), "table")
    pet.abilitiesUnknown = not abilities or Field(value, "abilitiesUnknown") == true
    local types = Field(value, "abilityTypes")
    for index = 1, 6 do
        local raw, state = Field(abilities, index)
        local id = Number(raw)
        if id and id > 0 then
            pet.abilities[#pet.abilities + 1] = id
            pet.abilityTypes[id] = Number(Field(types, id))
            if not pet.abilityTypes[id] then pet.unknown = true end
        elseif raw ~= nil or (state ~= "unavailable" and state ~= "usable") then
            pet.abilitiesUnknown = true
        end
    end
    pet.unknown = pet.unknown or pet.abilitiesUnknown
    return pet
end

local function AbilitySet(pet)
    local ids, types = {}, {}
    for _, id in ipairs(pet.abilities) do
        ids[id] = true
        local kind = pet.abilityTypes[id]
        if kind then types[kind] = true end
    end
    return ids, types
end

local function Differences(slot, pet, missing)
    local differences = {}
    for _, key in ipairs({ "level", "quality", "family" }) do
        if slot[key] ~= nil and pet[key] ~= nil and slot[key] ~= pet[key] then
            differences[#differences + 1] = { kind = key, expected = slot[key], actual = pet[key] }
        end
    end
    if #missing > 0 and not pet.abilitiesUnknown and not slot.abilitiesUnknown then
        differences[#differences + 1] = { kind = "missingAbilities", abilityIDs = missing }
    end
    if pet.health == 0 then
        differences[#differences + 1] = { kind = "dead" }
    elseif pet.health and pet.maxHealth and pet.health < pet.maxHealth then
        differences[#differences + 1] = { kind = "injured" }
    end
    return differences
end

function Alternatives.Find(slot, collection)
    slot = Snapshot(slot)
    collection = Compatibility.PublicValueOfType(collection, "table") or {}
    local chosen = AbilitySet(slot)
    local results = {}
    for index = 1, #collection do
        local pet = Snapshot(Field(collection, index))
        if pet.petID and pet.petID ~= slot.petID then
            local available, types = AbilitySet(pet)
            local matches, missing, sameTypes, count = 0, {}, not slot.abilitiesUnknown, 0
            for id in pairs(chosen) do
                count = count + 1
                if available[id] then matches = matches + 1 else missing[#missing + 1] = id end
                local kind = slot.abilityTypes[id]
                if not kind or not types[kind] then sameTypes = false end
            end
            local tier
            if slot.speciesID and pet.speciesID == slot.speciesID then tier = 1
            elseif slot.speciesID and pet.speciesID and matches > 0 then tier = 2
            elseif slot.family and pet.family == slot.family and count > 0 and sameTypes then tier = 3 end
            if tier then
                table.sort(missing)
                results[#results + 1] = { pet = pet, tier = tier, differences = Differences(slot, pet, missing),
                    matches = matches, order = index,
                    unknown = pet.unknown or (slot.breedID ~= nil and pet.breedID == nil) }
            end
        end
    end
    table.sort(results, function(a, b)
        if a.tier ~= b.tier then return a.tier < b.tier end
        if a.unknown ~= b.unknown then return not a.unknown end
        if a.tier == 2 and a.matches ~= b.matches then return a.matches > b.matches end
        for _, key in ipairs({ "level", "quality", "health" }) do
            local left, right = a.pet[key], b.pet[key]
            if left ~= right then
                if left == nil then return false end
                if right == nil then return true end
                return left > right
            end
        end
        return a.order < b.order
    end)
    for _, result in ipairs(results) do result.matches, result.order, result.unknown = nil, nil, nil end
    return results
end

local function Journal(name, ...)
    local api = Compatibility.PublicValueOfType(Field(C_PetJournal, name), "function")
    if not api then return end
    local ok, a, b, c, d, e = pcall(api, ...)
    if not ok then return end
    return Compatibility.PublicValue(a), Compatibility.PublicValue(b), Compatibility.PublicValue(c),
        Compatibility.PublicValue(d), Compatibility.PublicValue(e)
end

function Alternatives.Collect()
    local pets = {}
    local ids = Compatibility.PublicValueOfType(Journal("GetOwnedPetIDs"), "table") or {}
    for index = 1, #ids do
        local id = Compatibility.PublicValueOfType(Field(ids, index), "string")
        if id then
            local info = Journal("GetPetInfoTableByPetID", id)
            local canBattle = Compatibility.PublicValueOfType(Field(info, "canBattle"), "boolean")
            if canBattle ~= false then
                local health, maxHealth, _, _, quality = Journal("GetPetStats", id)
                local pet = { petID = id, speciesID = Number(Field(info, "speciesID")),
                    family = Number(Field(info, "petType")), level = Number(Field(info, "petLevel")),
                    health = Number(health), maxHealth = Number(maxHealth), quality = Number(quality),
                    abilities = {}, abilityTypes = {}, unknown = canBattle == nil }
                local abilities
                if pet.speciesID then abilities = Journal("GetPetAbilityListTable", pet.speciesID) end
                abilities = Compatibility.PublicValueOfType(abilities, "table")
                pet.abilitiesUnknown = not abilities
                for abilityIndex = 1, 6 do
                    local entry, state = Field(abilities, abilityIndex)
                    if entry ~= nil or state == "secret" or state == "restricted" then
                        local abilityID, level = Number(Field(entry, "abilityID")), Number(Field(entry, "level"))
                        if not abilityID or not level or not pet.level then
                            pet.abilitiesUnknown = true
                        elseif pet.level >= level then
                            pet.abilities[#pet.abilities + 1] = abilityID
                            local _, _, kind = Journal("GetPetAbilityInfo", abilityID)
                            pet.abilityTypes[abilityID] = Number(kind)
                        end
                    end
                end
                pets[#pets + 1] = Snapshot(pet)
            end
        end
    end
    return pets
end

function Alternatives.Apply(team, slotIndex, petID, confirmed)
    if Compatibility.PublicValue(confirmed) ~= true then return nil, "confirmation_required" end
    slotIndex = Number(slotIndex)
    petID = Compatibility.PublicValueOfType(petID, "string")
    local teamID = Compatibility.PublicValueOfType(Field(team, "teamID"), "string")
    if not slotIndex or slotIndex < 1 or slotIndex > 3 or slotIndex % 1 ~= 0
        or not petID or not petID:match("^BattlePet%-.+") then return nil, "invalid_slot_or_pet" end
    if not teamID or type(BattleBuddyDB) ~= "table" or type(BattleBuddyDB.teamsByID) ~= "table" then
        return nil, "unknown_team"
    end
    local current = BattleBuddyTeams.GetTeam(BattleBuddyDB, teamID)
    if not current then return nil, "unknown_team" end
    if not current.pets[slotIndex] then return nil, "invalid_slot_or_pet" end
    current.pets[slotIndex] = petID
    current.tags[slotIndex] = {}
    return BattleBuddyTeams.EditTeam(BattleBuddyDB, teamID, { pets = current.pets, tags = current.tags })
end
