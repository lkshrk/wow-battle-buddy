-- luacheck: globals BattleBuddyCompatibility BattleBuddyAlternatives BattleBuddyConfig BattleBuddyLoadout BattleBuddyTeamsPanel BattleBuddyScript C_PetJournal C_PetBattles InCombatLockdown CreateFrame
BattleBuddyHealthiestPets = {}

local H, C = BattleBuddyHealthiestPets, BattleBuddyCompatibility

local function Read(callback, ...)
    if type(callback) ~= "function" then return end
    local function Results(ok, ...)
        if not ok then return end
        local values = {}
        for index = 1, select("#", ...) do values[index] = C.PublicValue((select(index, ...))) end
        return unpack(values, 1, select("#", ...))
    end
    return Results(pcall(callback, ...))
end

local function Number(value)
    value = C.PublicValueOfType(value, "number")
    if value and value == value and value >= 0 and value < math.huge then return value end
end

local function Collection()
    local pets, byID = BattleBuddyAlternatives.Collect(), {}
    for _, pet in ipairs(pets) do byID[pet.petID] = pet end
    return pets, byID
end

function H.IsUninjured(team)
    local _, byID = Collection()
    local pets = C.ReadField(team, "pets")
    for index = 1, 3 do
        local id = C.PublicValueOfType(C.ReadField(pets, index), "string")
        local pet = id and byID[id]
        local health, maximum = Number(pet and pet.health), Number(pet and pet.maxHealth)
        if not health or not maximum or maximum == 0 or health < maximum then return false end
    end
    return true
end

local function InjuredSlots()
    local _, byID = Collection()
    local injured = {}
    for index = 1, 3 do
        local id = C.PublicValueOfType(Read(C_PetJournal and C_PetJournal.GetPetLoadOutInfo, index), "string")
        local pet = id and byID[id]
        local health, maximum = Number(pet and pet.health), Number(pet and pet.maxHealth)
        injured[index] = health ~= nil and maximum ~= nil and health < maximum
    end
    return injured
end

function H.AnyInjured()
    local injured = InjuredSlots()
    return injured[1] or injured[2] or injured[3]
end

local flashing
function H.FlashInjured()
    if Read(InCombatLockdown) ~= false then return end
    flashing = true
    local injured = InjuredSlots()
    for index, slot in ipairs(BattleBuddyLoadout.slots or {}) do
        if injured[index] then
            if not slot.injuryFlash then
                slot.injuryFlash = slot.health:CreateAnimationGroup()
                local alpha = slot.injuryFlash:CreateAnimation("Alpha")
                alpha:SetFromAlpha(1)
                alpha:SetToAlpha(0.2)
                alpha:SetDuration(0.6)
                slot.injuryFlash:SetLooping("BOUNCE")
            end
            slot.injuryFlash:Play()
        elseif slot.injuryFlash then
            slot.injuryFlash:Stop()
        end
    end
end

if CreateFrame then
    local events = CreateFrame("Frame")
    events:RegisterEvent("PET_JOURNAL_LIST_UPDATE")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:SetScript("OnEvent", function() if flashing then H.FlashInjured() end end)
end

function H.Apply()
    if BattleBuddyConfig.GetSetting("loadHealthiestPets") ~= true then return true end
    if Read(InCombatLockdown) ~= false then return false, "Loadout changes are unavailable in combat." end
    if Read(C_PetBattles and C_PetBattles.IsInBattle) ~= false then
        return false, "Loadout changes are unavailable during a pet battle."
    end
    local collection, byID = Collection()
    local slots, reserved = {}, {}
    for index = 1, 3 do
        local id, a, b, c = Read(C_PetJournal and C_PetJournal.GetPetLoadOutInfo, index)
        id = C.PublicValueOfType(id, "string")
        slots[index] = { id = id, abilities = { Number(a), Number(b), Number(c) } }
        if id then reserved[id] = true end
    end
    for index, slot in ipairs(slots) do
        local pet = slot.id and byID[slot.id]
        local health, maximum = Number(pet and pet.health), Number(pet and pet.maxHealth)
        if health and maximum and health < maximum
            and slot.abilities[1] and slot.abilities[2] and slot.abilities[3] then
            local best, bestHealth = nil, health
            for _, candidate in ipairs(BattleBuddyAlternatives.Find(pet, collection)) do
                local copy, usable = candidate.pet, true
                local available = {}
                for _, ability in ipairs(copy.abilities) do available[ability] = true end
                for _, ability in ipairs(slot.abilities) do
                    if not available[ability] then usable = false end
                end
                if candidate.tier == 1 and not reserved[copy.petID] and usable
                    and copy.health and copy.maxHealth and copy.health > bestHealth then
                    best, bestHealth = copy, copy.health
                end
            end
            if best then
                local ok, reason = BattleBuddyLoadout.DropPet(index, best.petID)
                if not ok then return false, reason end
                reserved[slot.id] = nil
                reserved[best.petID] = true
                for tier, ability in ipairs(slot.abilities) do
                    ok, reason = BattleBuddyLoadout.ChooseAbility(index, tier, ability)
                    if not ok then return false, reason end
                end
            end
        end
    end
    return true
end

BattleBuddyTeamsPanel.afterLoad = function() return H.Apply() end
