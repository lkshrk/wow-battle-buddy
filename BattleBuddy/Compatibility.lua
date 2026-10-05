BattleBuddyCompatibility = {}

local Compatibility = BattleBuddyCompatibility

function Compatibility.PublicValueOfType(value, expectedType)
    local ok, public = pcall(Compatibility.ClassifyValue, value)
    if ok and type(public) == expectedType then return public end
end

function Compatibility.ClassifyValue(value, inspectors)
    inspectors = inspectors or {}
    local isSecret = inspectors.isSecret or issecretvalue
    local canAccess = inspectors.canAccess or canaccessvalue

    if isSecret(value) then
        return nil, "secret"
    end

    if not canAccess(value) then
        return nil, "restricted"
    end

    if value == nil then
        return nil, "unavailable"
    end

    return value, "usable"
end

function Compatibility.PublicValue(value, inspectors)
    local ok, result, state = pcall(Compatibility.ClassifyValue, value, inspectors)
    if ok then return result, state end
    return nil, "unavailable"
end

function Compatibility.ReadField(container, key, inspectors)
    container = Compatibility.PublicValue(container, inspectors)
    key = Compatibility.PublicValue(key, inspectors)
    if type(container) ~= "table" or key == nil then return nil, "unavailable" end
    local ok, value = pcall(function() return container[key] end)
    if not ok then return nil, "unavailable" end
    return Compatibility.PublicValue(value, inspectors)
end

local function ReadCall(api, name, ...)
    local method = Compatibility.ReadField(api, name)
    if type(method) ~= "function" then return end
    local function Pack(...) return { n = select("#", ...), ... } end
    local values = Pack(pcall(method, ...))
    if not values[1] then return end
    for index = 2, values.n do values[index] = Compatibility.PublicValue(values[index]) end
    return unpack(values, 2, values.n)
end

local function Number(value)
    value = Compatibility.PublicValueOfType(value, "number")
    if value and value == value and value > -math.huge and value < math.huge then return value end
end

local function Identifier(value, maximum)
    value = Number(value)
    if value and value >= 1 and value % 1 == 0 and (not maximum or value <= maximum) then return value end
end

function Compatibility.ReadPetCollection()
    local public = Compatibility.PublicValueOfType
    local rows, seenPets, seenSpecies, abilities = {}, {}, {}, {}
    local summoned = public(ReadCall(C_PetJournal, "GetSummonedPetGUID"), "string")
    local function Add(petID, speciesID, owned, customName, level, favorite, speciesName, icon, petType)
        petID, speciesID = public(petID, "string"), Identifier(speciesID)
        if not speciesID or (petID and seenPets[petID]) or (not petID and seenSpecies[speciesID]) then return end
        if petID then seenPets[petID] = true end
        seenSpecies[speciesID] = true
        local name = public(customName, "string")
        speciesName = public(speciesName, "string")
        if not name or name == "" then name = speciesName end
        local _, health, power, speed, quality
        if petID then _, health, power, speed, quality = ReadCall(C_PetJournal, "GetPetStats", petID) end
        if not abilities[speciesID] then
            local list = {}
            local source = ReadCall(C_PetJournal, "GetPetAbilityListTable", speciesID)
            if type(source) == "table" then
                for index = 1, #source do
                    local entry = Compatibility.ReadField(source, index)
                    local id = Identifier((Compatibility.ReadField(entry, "abilityID")))
                    if id then
                        local _, abilityName, _, _, description, _, family = ReadCall(C_PetBattles, "GetAbilityInfoByID", id)
                        list[#list + 1] = { name = public(abilityName, "string"),
                            description = public(description, "string"), petType = Identifier(family, 10) }
                    end
                end
            end
            abilities[speciesID] = list
        end
        rows[#rows + 1] = { petID = petID, speciesID = speciesID, name = name,
            speciesName = speciesName, icon = Identifier(icon), petType = Identifier(petType, 10),
            level = Number(level), health = Number(health), power = Number(power),
            speed = Number(speed), quality = Number(quality),
            owned = public(owned, "boolean"), favorite = public(favorite, "boolean"),
            summoned = petID ~= nil and petID == summoned, abilities = abilities[speciesID] }
    end
    local owned = ReadCall(C_PetJournal, "GetOwnedPetIDs")
    if type(owned) == "table" then
        for index = 1, #owned do
            local id = public(Compatibility.ReadField(owned, index), "string")
            if id then
                local info = ReadCall(C_PetJournal, "GetPetInfoTableByPetID", id)
                local function Field(key) return Compatibility.ReadField(info, key) end
                Add(id, Field("speciesID"), true, Field("customName"), Field("petLevel"),
                    Field("isFavorite"), Field("name"), Field("icon"), Field("petType"))
            end
        end
    end
    local count = public(ReadCall(C_PetJournal, "GetNumPets"), "number")
    if count and count >= 0 and count < math.huge then
        for index = 1, count do
            local id, species, isOwned, custom, level, favorite, _, name, icon, family = ReadCall(C_PetJournal, "GetPetInfoByIndex", index)
            Add(id, species, isOwned, custom, level, favorite, name, icon, family)
        end
    end
    return rows
end

function Compatibility.PickupPet(petID)
    petID = Compatibility.PublicValueOfType(petID, "string")
    local pickup = Compatibility.ReadField(C_PetJournal, "PickupPet")
    if not petID or petID == "" or type(pickup) ~= "function" then return false end
    local ok, combat = pcall(InCombatLockdown)
    if not ok or Compatibility.PublicValueOfType(combat, "boolean") ~= false then return false end
    local info = ReadCall(C_PetJournal, "GetPetInfoTableByPetID", petID)
    if not Identifier((Compatibility.ReadField(info, "speciesID"))) then return false end
    return pcall(pickup, petID)
end
