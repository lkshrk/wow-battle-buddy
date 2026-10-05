local root = (... or ".")
local secret = {}
issecretvalue = function(value) return rawequal(value, secret) end
canaccessvalue = function(value) return not rawequal(value, secret) end
dofile(root .. "/BattleBuddy/Compatibility.lua")
dofile(root .. "/BattleBuddy/Alternatives.lua")
local enabled, combat, battle, failDrop, failAbility = true, false, false
local slots, changes, originalSuccess = {}, {}, true
local function Pet(id, health, species)
    return { petID = "BattlePet-" .. id, speciesID = species or 1, health = health, maxHealth = 100,
        level = 25, quality = 4, family = 2, abilities = { 10, 20, 30 },
        abilityTypes = { [10] = 2, [20] = 2, [30] = 2 } }
end
local hurt, healthy, occupied, other = Pet("hurt", 20), Pet("healthy", 100), Pet("occupied", 100), Pet("other", 100, 2)
local collection = { hurt, occupied, healthy, other }
BattleBuddyAlternatives.Collect = function() return collection end
BattleBuddyConfig = { GetSetting = function() return enabled end }
InCombatLockdown = function() return combat end
C_PetBattles = { IsInBattle = function() return battle end }
C_PetJournal = { GetPetLoadOutInfo = function(index) return unpack(slots[index] or {}) end }
BattleBuddyLoadout = {
    DropPet = function(index, id)
        if failDrop then return false, "drop failed" end
        changes[#changes + 1] = id
        slots[index] = { id, 1, 2, 3 }
        return true
    end,
    ChooseAbility = function(index, tier, id)
        if failAbility then return false, "ability failed" end
        slots[index][tier + 1] = id
        return true
    end,
}
local unloaded
BattleBuddyScript = { SetLoadedTeam = function(store, id) unloaded = store == nil and id == nil end }
BattleBuddyTeamsPanel = {}
BattleBuddyTeamsPanel.Load = function()
    if not originalSuccess then return false, "original reason" end
    local ok, reason = BattleBuddyTeamsPanel.afterLoad()
    if not ok then BattleBuddyScript.SetLoadedTeam(nil, nil) end
    return ok, reason
end
local eventHandler
CreateFrame = function()
    return { RegisterEvent = function() end, SetScript = function(_, _, callback) eventHandler = callback end }
end
dofile(root .. "/BattleBuddy/HealthiestPets.lua")
local H = BattleBuddyHealthiestPets
local function Reset()
    slots = { { hurt.petID, 10, 20, 30 }, { occupied.petID, 10, 20, 30 }, { other.petID, 10, 20, 30 } }
    changes = {}
end
Reset()
local saved = { pets = { hurt.petID, occupied.petID, other.petID } }
assert(not H.IsUninjured(saved))
assert(H.IsUninjured({ pets = { healthy.petID, occupied.petID, other.petID } }))
assert(not H.IsUninjured({ pets = { healthy.petID, "empty", other.petID } }))
assert(BattleBuddyTeamsPanel.Load("team"))
assert(#changes == 1 and slots[1][1] == healthy.petID)
assert(slots[1][2] == 10 and slots[1][3] == 20 and slots[1][4] == 30)
assert(saved.pets[1] == hurt.petID)
assert(H.Apply() and #changes == 1)
Reset(); enabled = false
assert(H.Apply() and #changes == 0)
enabled = true; combat = true
assert(not H.Apply() and #changes == 0)
combat = false; battle = true
assert(not H.Apply() and #changes == 0)
battle = false; originalSuccess = false
local ok, reason = BattleBuddyTeamsPanel.Load("team")
assert(not ok and reason == "original reason" and #changes == 0)
originalSuccess = true; failDrop = true
ok, reason = BattleBuddyTeamsPanel.Load("team")
assert(not ok and reason == "drop failed")
failDrop = false; failAbility = true
assert(not BattleBuddyTeamsPanel.Load("team") and unloaded)
failAbility = false; Reset()
healthy.health = secret
assert(H.Apply() and #changes == 0)
assert(not H.IsUninjured({ pets = { healthy.petID, occupied.petID, other.petID } }))
healthy.health = 100; healthy.abilities = { 10, 20 }
assert(H.Apply() and #changes == 0)
healthy.abilities = { 10, 20, 30 }; Reset()
slots[1][2] = secret
assert(H.Apply() and #changes == 0)
Reset()
local lessHealthy = Pet("lessHealthy", 60)
lessHealthy.level = 26
collection = { hurt, occupied, lessHealthy, healthy, other }
assert(H.Apply() and slots[1][1] == healthy.petID)
Reset()
occupied.health = 30
collection = { hurt, occupied, healthy, other }
assert(H.Apply() and #changes == 1 and slots[2][1] == occupied.petID)
occupied.health = 100; Reset()
hurt.health = secret
assert(H.Apply() and #changes == 0)
hurt.health = 20; combat = secret
assert(not H.Apply() and #changes == 0)
combat = false; battle = secret
assert(not H.Apply() and #changes == 0)
combat, battle = false, false; Reset()
assert(H.AnyInjured())
slots[1][1] = healthy.petID
assert(not H.AnyInjured())
healthy.health = secret
assert(not H.AnyInjured())
healthy.health = 100; Reset()
local function HealthFrame()
    return { CreateAnimationGroup = function()
        return {
            CreateAnimation = function() return {
                SetFromAlpha = function() end, SetToAlpha = function() end, SetDuration = function() end,
            } end,
            SetLooping = function() end,
            Play = function(self) self.playing = true end,
            Stop = function(self) self.playing = false end,
        }
    end }
end
BattleBuddyLoadout.slots = { { health = HealthFrame() }, { health = HealthFrame() }, { health = HealthFrame() } }
H.FlashInjured()
assert(BattleBuddyLoadout.slots[1].injuryFlash.playing)
assert(not BattleBuddyLoadout.slots[2].injuryFlash)
hurt.health = 100
eventHandler(nil, "PET_JOURNAL_LIST_UPDATE")
assert(not BattleBuddyLoadout.slots[1].injuryFlash.playing and #changes == 0)
hurt.health, occupied.health = 60, 20; Reset()
assert(H.Apply() and slots[1][1] == healthy.petID and slots[2][1] == hurt.petID)
print("healthiest_pets_test: ok")
