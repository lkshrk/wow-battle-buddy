local root = arg[1] or "."
local secret = setmetatable({}, { __eq = function() error("secret comparison") end,
    __add = function() error("secret arithmetic") end, __lt = function() error("secret order") end })
issecretvalue = function(value) return rawequal(value, secret) end
canaccessvalue = function(value) return not rawequal(value, secret) end
dofile(root .. "/BattleBuddy/Compatibility.lua")
BattleBuddyScript = {}
local calls, registered = {}, {}
C_PetBattles = {}
for _, name in ipairs({ "UseAbility", "ChangePet", "ForfeitGame", "SkipTurn", "UseTrap" }) do
    C_PetBattles[name] = function(index) calls[#calls + 1] = { name, index } end
end
CreateFrame = function()
    return { RegisterEvent = function(_, event) registered[event] = true end,
        SetScript = function(_, name, callback) assert(name == "OnEvent"); registered.callback = callback end }
end
BattleBuddyTeams = { GetTeam = function(store, id) return store[id] end }
dofile(root .. "/BattleBuddy/Script/Runtime.lua")
local S = BattleBuddyScript
assert(not S.Execute({ kind = "ability", index = 1 }))
S.WithHardwareEvent(function()
    assert(S.Execute({ kind = "ability", index = 2 }))
    assert(not S.Execute({ kind = "quit" }))
    assert(not S.WithHardwareEvent(function() S.Execute({ kind = "quit" }) end))
end)
assert(#calls == 1 and calls[1][1] == "UseAbility" and calls[1][2] == 2)
assert(not S.WithHardwareEvent(function() error("handler failed") end))
assert(not S.Execute({ kind = "quit" }))
for _, action in ipairs({ {kind="change",index=3}, {kind="quit"}, {kind="standby"}, {kind="catch"} }) do
    S.WithHardwareEvent(function() assert(S.Execute(action)) end)
end
assert(#calls == 5)
local oldPrint, message = print
print = function(text) message = text end
S.WithHardwareEvent(function()
    assert(not S.Execute({kind="test",text=secret}))
    assert(S.Execute({kind="test",text="diagnostic"}))
    assert(not S.Execute({kind="quit"}))
end)
print = oldPrint
assert(message == "diagnostic" and #calls == 5)
S.WithHardwareEvent(function() assert(not S.Execute({kind="ability",index=secret})); assert(not S.Execute({kind="change",index=4})) end)
local store = { ["team:1"] = { script = "use(1)" } }
assert(S.SetLoadedTeam(store, "team:1"))
assert(S.ActiveScript() == "use(1)")
store["team:1"].script = "quit"
assert(S.ActiveScript() == "quit")
store["team:1"] = nil
assert(S.ActiveScript() == nil)
local api = {
    GetNumPets = function() return 1 end, GetActivePet = function() return 1 end,
    GetHealth = function() return secret end, GetMaxHealth = function() return 100 end,
    GetSpeed = function() return secret end, GetBreedQuality = function() return secret end,
    GetNumAuras = function(owner) return owner == 0 and secret or 1 end,
    GetAuraInfo = function() return secret, 1, secret end,
    GetAbilityInfo = function() return secret, secret, nil, nil, nil, nil, secret, secret end,
    GetAbilityState = function() return secret, secret, secret end,
    IsTrapAvailable = function() return secret, secret end,
    GetAttackModifier = function() error("secret input escaped") end,
    GetAbilityInfoByID = function() error("secret id escaped") end,
}
local snap = S.CaptureSnapshot(api)
assert(snap.round == nil and snap.ally.round == nil and snap.ally.pets[1].played == nil)
assert(snap.ally.pets[1].health == nil and snap.ally.pets[1].speed == nil)
assert(snap.ally.pets[1].quality == nil and snap.ally.pets[1].maxHealth == 100)
assert(snap.weather == nil and snap.trapAvailable == nil)
assert(snap.ally.pets[1].abilities[1].id == nil)
assert(registered.PET_BATTLE_PET_CHANGED and registered.PET_BATTLE_PET_ROUND_RESULTS)
S.HandleBattleEvent("PET_BATTLE_OPENING_START", nil, api)
S.HandleBattleEvent("PET_BATTLE_PET_CHANGED", 1, api)
S.HandleBattleEvent("PET_BATTLE_PET_ROUND_RESULTS", 0, api)
S.HandleBattleEvent("PET_BATTLE_PET_ROUND_RESULTS", 0, api)
snap = S.CaptureSnapshot(api)
assert(snap.round == 1 and snap.ally.round == 2 and snap.enemy.round == 1)
assert(snap.ally.pets[1].played == true and snap.enemy.pets[1].played == false)
assert(S.CaptureSnapshot(api).round == 1)
S.HandleBattleEvent("PET_BATTLE_PET_ROUND_RESULTS", secret, api)
assert(S.CaptureSnapshot(api).round == nil)
S.HandleBattleEvent("PET_BATTLE_OPENING_START", nil, api)
assert(S.CaptureSnapshot(api).round == 0)
S.HandleBattleEvent("PET_BATTLE_PET_CHANGED", secret, api)
assert(S.CaptureSnapshot(api).ally.pets[1].played == nil)
S.HandleBattleEvent("PET_BATTLE_PET_CHANGED", 1, api)
assert(S.CaptureSnapshot(api).ally.pets[1].played == true)
api.GetHealth = function() return 50 end
api.GetSpeed = function() return 123 end
api.GetBreedQuality = function() return 3 end
api.GetNumAuras = function(owner) return owner == 0 and 0 or 1 end
api.GetAuraInfo = function() return 99, 1, 2 end
api.GetAbilityInfoByID = function(id) assert(id == 99); return id, "Aura" end
api.GetAbilityInfo = function() return 11, "Strike", nil, nil, nil, nil, 5, false end
api.GetPetType = function() return 2 end
api.GetAttackModifier = function(a, b) assert(a == 5 and b == 2); return 1.5 end
api.GetAbilityState = function() return true, 0, 0 end
api.IsTrapAvailable = function() return false, 4 end
api.GetName = function() return "Nickname", "Species" end
local journal = {
    FindPetIDByName = function(name) assert(name == "Species"); return 44, "Pet-1" end,
    GetPetInfoBySpeciesID = function(id) assert(id == 44); return nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,true end,
    GetNumCollectedInfo = function(id) assert(id == 44); return 2, 3 end,
}
snap = S.CaptureSnapshot(api, nil, journal)
assert(snap.weather == false and snap.ally.pets[1].quality == 4)
assert(snap.ally.pets[1].auras[1].id == 99 and snap.ally.pets[1].auras[1].duration == 2)
assert(snap.ally.pets[1].abilities[1].modifier == 1.5)
assert(snap.ally.pets[1].collected and snap.ally.pets[1].collectedCount == 2 and snap.ally.pets[1].collectedMax == 3)
assert(snap.trapAvailable == false and snap.trapError == 4)
api.GetHealth = function() error("API unavailable") end
journal.FindPetIDByName = function() error("journal unavailable") end
snap = S.CaptureSnapshot(api, nil, journal)
assert(snap.ally.pets[1].health == nil and snap.ally.pets[1].collected == nil)
api.GetActivePet = function() return secret end
S.HandleBattleEvent("PET_BATTLE_OPENING_START", nil, api)
S.HandleBattleEvent("PET_BATTLE_PET_CHANGED", 1, api)
assert(S.CaptureSnapshot(api).ally.pets[1].played == nil)
api.GetActivePet = function() return 1 end
S.HandleBattleEvent("PET_BATTLE_PET_CHANGED", 1, api)
assert(S.CaptureSnapshot(api).ally.pets[1].played == true)
assert(#snap.weathers == 12 and snap.weathers[1].id == 171)
issecretvalue, canaccessvalue = nil, nil
snap = S.CaptureSnapshot(api)
assert(snap.ally.pets == nil and snap.weather == nil)
print("script_runtime_test: ok")
