local root = (... or ".")
local secret = {}
issecretvalue = function(value) return value == secret end
canaccessvalue = function() return true end
dofile(root .. "/BattleBuddy/Compatibility.lua")

local calls = 0
C_PetJournal = {
    GetOwnedPetIDs = function() return { "owned", "hidden", secret } end,
    GetPetInfoTableByPetID = function(id)
        return { speciesID = 10, name = "Moth", customName = id == "owned" and "Fluffy" or nil,
            petLevel = id == "owned" and 25 or secret, isFavorite = true, icon = 123, petType = 3 }
    end,
    GetNumPets = function() return 2 end,
    GetPetInfoByIndex = function(index)
        if index == 1 then return "owned", 10, true end
        return nil, 20, false, nil, nil, false, false, "Whelp", 456, 2
    end,
    GetPetStats = function(id)
        calls = calls + 1
        if id == "hidden" then return secret, secret, secret, secret, secret end
        return 50, 1400, 300, 280, 4
    end,
    GetSummonedPetGUID = function() return "owned" end,
    GetPetAbilityListTable = function() return { { abilityID = 1 }, { abilityID = secret } } end,
    SetSearchFilter = function() error("must not mutate journal") end,
    SetPetLoadOutInfo = function() error("must not change loadout") end,
    SummonPetByGUID = function() error("must not summon") end,
}
C_PetBattles = { GetAbilityInfoByID = function(id)
    assert(id == 1)
    return id, "Bite", 123, 0, "Deals beast damage", 1, 8
end }
local rows = BattleBuddyCompatibility.ReadPetCollection()
assert(#rows == 3 and calls == 2)
assert(rows[1].name == "Fluffy" and rows[1].speciesName == "Moth")
assert(rows[1].petID == "owned" and rows[1].owned and rows[1].favorite and rows[1].summoned)
assert(rows[1].health == 1400 and rows[1].power == 300 and rows[1].speed == 280 and rows[1].quality == 4)
assert(rows[1].abilities[1].name == "Bite" and rows[1].abilities[1].description == "Deals beast damage")
assert(rows[1].abilities[1].petType == 8 and #rows[1].abilities == 1)
assert(rows[2].level == nil and rows[2].health == nil and rows[2].quality == nil)
assert(rows[3].speciesID == 20 and not rows[3].owned and rows[3].petID == nil)
local picked
C_PetJournal.PickupPet = function(id) picked = id end
InCombatLockdown = function() return false end
assert(BattleBuddyCompatibility.PickupPet("owned"))
assert(picked == "owned")
picked = nil
assert(not BattleBuddyCompatibility.PickupPet(secret) and picked == nil)
InCombatLockdown = function() return true end
assert(not BattleBuddyCompatibility.PickupPet("owned") and picked == nil)
InCombatLockdown = function() return false end
local getInfo = C_PetJournal.GetPetInfoTableByPetID
C_PetJournal.GetPetInfoTableByPetID = function() return nil end
assert(not BattleBuddyCompatibility.PickupPet("unknown") and picked == nil)
C_PetJournal.GetPetInfoTableByPetID = getInfo
C_PetJournal.PickupPet = function() error("unavailable") end
assert(not BattleBuddyCompatibility.PickupPet("owned"))
C_PetJournal.GetPetInfoTableByPetID = function() return { speciesID = 0 / 0 } end
rows = BattleBuddyCompatibility.ReadPetCollection()
assert(#rows == 2)
C_PetJournal.GetPetInfoTableByPetID = function()
    return { speciesID = 10, petLevel = math.huge, petType = 11, icon = -1 }
end
C_PetJournal.GetPetStats = function() return 10, math.huge, 0 / 0, -math.huge, math.huge end
C_PetJournal.GetPetAbilityListTable = function() return { { abilityID = 0 / 0 }, { abilityID = -1 } } end
rows = BattleBuddyCompatibility.ReadPetCollection()
assert(rows[1].level == nil and rows[1].petType == nil and rows[1].icon == nil)
assert(rows[1].health == nil and rows[1].power == nil and rows[1].speed == nil and rows[1].quality == nil)
assert(#rows[1].abilities == 0)
C_PetJournal.GetNumPets = function() return secret end
C_PetJournal.GetOwnedPetIDs = function() return secret end
assert(#BattleBuddyCompatibility.ReadPetCollection() == 0)
C_PetJournal.GetOwnedPetIDs = function() error("unavailable") end
assert(#BattleBuddyCompatibility.ReadPetCollection() == 0)
C_PetJournal = nil
assert(#BattleBuddyCompatibility.ReadPetCollection() == 0)
print("pet_collection_test: ok")
