local root = (... or ".")
local secret = setmetatable({}, {
    __eq = function() error("secret comparison") end,
    __lt = function() error("secret ordering") end,
    __index = function() error("secret indexing") end,
    __sub = function() error("secret arithmetic") end,
})
issecretvalue = function(value) return rawequal(value, secret) end
canaccessvalue = function(value) return not rawequal(value, secret) end
dofile(root .. "/BattleBuddy/Compatibility.lua")
dofile(root .. "/BattleBuddy/Store.lua")
dofile(root .. "/BattleBuddy/Teams.lua")
dofile(root .. "/BattleBuddy/Alternatives.lua")
local A, T = BattleBuddyAlternatives, BattleBuddyTeams

local function Pet(id, species, abilities, family)
    return { petID = "BattlePet-" .. id, speciesID = species or 1, family = family or 2,
        level = 25, quality = 4, health = 100, maxHealth = 100,
        abilities = abilities or { 10, 20, 30 }, abilityTypes = { [10] = 2, [20] = 3, [30] = 4 } }
end

local function IDs(results)
    local ids = {}
    for _, result in ipairs(results) do ids[#ids + 1] = result.pet.petID end
    return table.concat(ids, ",")
end

local function Difference(result, kind)
    for _, difference in ipairs(result.differences) do
        if difference.kind == kind then return difference end
    end
end

local slot = Pet("slot")
local copy, low, poor, hurt, dead = Pet("copy"), Pet("low"), Pet("poor"), Pet("hurt"), Pet("dead")
low.level, poor.quality, hurt.health, dead.health = 24, 3, 50, 0
local all, two, one = Pet("all", 2), Pet("two", 3, { 10, 20 }), Pet("one", 4, { 10 }, 7)
local typed = Pet("typed", 5, { 40, 50, 60 })
typed.abilityTypes = { [40] = 2, [50] = 3, [60] = 4 }
local unrelated = Pet("unrelated", 6, { 99 }, 8)
local results = A.Find(slot, { unrelated, one, low, dead, two, typed, poor, slot, hurt, all, copy })
assert(IDs(results) == "BattlePet-copy,BattlePet-hurt,BattlePet-dead,BattlePet-poor,BattlePet-low,BattlePet-all,BattlePet-two,BattlePet-one,BattlePet-typed")
for i = 1, 5 do assert(results[i].tier == 1) end
for i = 6, 8 do assert(results[i].tier == 2) end
assert(results[9].tier == 3)
assert(Difference(results[2], "injured"))
assert(Difference(results[3], "dead") and not Difference(results[3], "injured"))
assert(Difference(results[4], "quality").actual == 3)
assert(Difference(results[5], "level").expected == 25)
assert(Difference(results[8], "family").actual == 7)
assert(table.concat(Difference(results[8], "missingAbilities").abilityIDs, ",") == "20,30")
assert(#results[1].differences == 0)
assert(slot.petID == "BattlePet-slot" and low.level == 24)
assert(#A.Find(slot, { slot }) == 0)
assert(#A.Find({}, { unrelated }) == 0)

local unknown = Pet("unknown")
unknown.level, unknown.health, unknown.quality = secret, secret, secret
results = A.Find(slot, { unknown, low })
assert(IDs(results) == "BattlePet-low,BattlePet-unknown")
assert(results[2].pet.level == nil and results[2].pet.health == nil)
assert(not Difference(results[2], "injured") and not Difference(results[2], "dead"))
local missing = Pet("missing")
missing.maxHealth = nil
assert(IDs(A.Find(slot, { missing, low })) == "BattlePet-low,BattlePet-missing")
local uncertainAll = Pet("uncertainAll", 2)
uncertainAll.quality = secret
assert(IDs(A.Find(slot, { uncertainAll, two })) == "BattlePet-two,BattlePet-uncertainAll")
local unknownAbilities = Pet("unknownAbilities", 2, { secret, 10 })
unknownAbilities.abilityTypes = secret
assert(A.Find(slot, { unknownAbilities })[1].tier == 2)
assert(not Difference(A.Find(slot, { unknownAbilities })[1], "missingAbilities"))
local unknownIdentity = Pet("identity")
unknownIdentity.petID = secret
assert(#A.Find(slot, { unknownIdentity, secret }) == 0)
assert(#A.Find(secret, { copy }) == 0)
assert(#A.Find(slot, secret) == 0)
local partialTypes = Pet("partialTypes", 7, { 40 })
partialTypes.abilityTypes = { [40] = 2 }
assert(#A.Find(slot, { partialTypes }) == 0)
local noChosen = Pet("noChosen")
noChosen.abilities = {}
assert(#A.Find(noChosen, { all, typed }) == 0)
local tie = Pet("tie")
assert(IDs(A.Find(slot, { tie, copy })) == "BattlePet-tie,BattlePet-copy")
local typedLow, typedUnknown = Pet("typedLow", 8, { 40, 50, 60 }), Pet("typedUnknown", 9, { 40, 50, 60 })
typedLow.abilityTypes, typedUnknown.abilityTypes = typed.abilityTypes, typed.abilityTypes
typedLow.level, typedUnknown.health = 24, secret
assert(IDs(A.Find(slot, { typedUnknown, typedLow, typed })) == "BattlePet-typed,BattlePet-typedLow,BattlePet-typedUnknown")
for _, key in ipairs({ "level", "quality", "health", "maxHealth", "family", "breedID" }) do
    local hidden = Pet("hidden")
    hidden[key] = secret
    assert(IDs(A.Find(slot, { hidden, low })) == "BattlePet-low,BattlePet-hidden")
end

local calls = {}
C_PetJournal = {
    GetOwnedPetIDs = function()
        return { "BattlePet-collected1", "BattlePet-collected2", "BattlePet-collected3", secret, "BattlePet-nonbattle" }
    end,
    GetPetInfoTableByPetID = function(id)
        calls[#calls + 1] = id
        return { speciesID = 1, petLevel = id == "BattlePet-collected2" and secret or 25,
            petType = 2, canBattle = id ~= "BattlePet-nonbattle" }
    end,
    GetPetStats = function(id)
        if id == "BattlePet-collected2" then return secret, 100, secret, secret, secret end
        return 100, 100, 10, 10, 4
    end,
    GetPetAbilityListTable = function(species)
        assert(species == 1)
        return { { abilityID = 10, level = 1 }, { abilityID = 20, level = 2 },
            { abilityID = 30, level = 4 }, { abilityID = 40, level = 10 },
            { abilityID = 50, level = 15 }, { abilityID = secret, level = secret } }
    end,
    GetPetAbilityInfo = function(id) return "Ability", 123, id == 50 and secret or 2 end,
}
local collection = A.Collect()
assert(#calls == 4 and #collection == 3)
assert(collection[1].speciesID == 1 and collection[1].family == 2)
assert(collection[1].quality == 4 and collection[2].quality == nil)
assert(collection[1].breedID == nil)
assert(collection[1].abilityTypes[50] == nil)
assert(IDs(A.Find(slot, collection)) == "BattlePet-collected1,BattlePet-collected3,BattlePet-collected2")
assert(#collection[2].abilities == 0)
C_PetJournal.GetPetInfoTableByPetID = function()
    return { speciesID = 1, petLevel = 1, petType = 2, canBattle = true }
end
C_PetJournal.GetPetAbilityListTable = function()
    return { { abilityID = 10, level = 1 }, { abilityID = 20, level = 2 } }
end
local young = A.Collect()
assert(#young[1].abilities == 1 and young[1].abilities[1] == 10)
assert(table.concat(Difference(A.Find(slot, { young[1] })[1], "missingAbilities").abilityIDs, ",") == "20,30")
C_PetJournal.GetPetInfoTableByPetID = function() return secret end
local unavailable = A.Collect()
assert(#unavailable == 4 and unavailable[1].speciesID == nil)
assert(#A.Find(slot, unavailable) == 0)
C_PetJournal.GetOwnedPetIDs = function() return secret end
assert(#A.Collect() == 0)
C_PetJournal.GetOwnedPetIDs = function() error("unavailable") end
assert(#A.Collect() == 0)
C_PetJournal = nil
assert(#A.Collect() == 0)

BattleBuddyDB = assert(T.Initialize(nil))
local team = assert(T.CreateTeam(BattleBuddyDB, {
    name = "Team", pets = { "BattlePet-a", "BattlePet-b", "BattlePet-c" },
    tags = { { speciesID = 1 }, { speciesID = 2, abilities = { 1, 2, 1 } }, { breedID = 4 } },
    notes = "keep", script = "ability(1)", targets = { 99 },
}))
local edit, edits = T.EditTeam, 0
T.EditTeam = function(...) edits = edits + 1; return edit(...) end
for _, confirmed in ipairs({ false, "yes", 1 }) do
    local result, reason = A.Apply(team, 2, "BattlePet-new", confirmed)
    assert(result == nil and reason == "confirmation_required")
end
assert(not A.Apply(team, 2, "BattlePet-new"))
assert(edits == 0)
assert(edit(BattleBuddyDB, team.teamID, { notes = "new note", pets = { "BattlePet-latest", "BattlePet-b", "BattlePet-c" } }))
local changed = assert(A.Apply(team, 2, "BattlePet-new", true))
assert(edits == 1)
assert(changed.pets[1] == "BattlePet-latest" and changed.pets[2] == "BattlePet-new" and changed.pets[3] == "BattlePet-c")
assert(changed.tags[1].speciesID == 1 and next(changed.tags[2]) == nil and changed.tags[3].breedID == 4)
assert(changed.notes == "new note" and changed.script == "ability(1)" and changed.targets[1] == 99)
assert(team.pets[2] == "BattlePet-b")
assert(BattleBuddyDB.teamsByID[team.teamID].pets[2] == "BattlePet-new")
assert(not A.Apply(team, 0, "BattlePet-new", true))
assert(not A.Apply(team, 4, "BattlePet-new", true))
assert(not A.Apply(team, 1.5, "BattlePet-new", true))
assert(not A.Apply(team, 1, 42, true))
assert(not A.Apply(team, 1, secret, true))
assert(not A.Apply({}, 1, "BattlePet-new", true))
assert(edits == 1)
BattleBuddyDB = nil
assert(not A.Apply(team, 1, "BattlePet-new", true))
print("alternatives_test: ok")
