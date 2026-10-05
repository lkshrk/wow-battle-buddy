--[[
The MIT License (MIT)

Copyright (c) 2018 Dengzhun Lu <tdaddon@163.com>

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
Source: PBS Core/Addon.lua, Core/Script.lua, Core/Director.lua, Core/Manager/BattleCacheManager.lua, Core/Prototype/BattleCache.lua, Extension/Actions.lua, Extension/Played.lua, Extension/Round.lua, Extension/Conditions.lua.
]]

local Script, Compatibility = BattleBuddyScript, BattleBuddyCompatibility
local hardware, used, loadedStore, loadedID
local rounds, played = {}, { { unknown = true }, { unknown = true } }
local actions = { ability = "UseAbility", change = "ChangePet", quit = "ForfeitGame", standby = "SkipTurn", catch = "UseTrap" }

local function Public(value, inspectors)
    return Compatibility.PublicValue(value, inspectors)
end

local function Integer(value, maximum)
    return type(value) == "number" and value >= 0 and value < math.huge
        and value % 1 == 0 and (not maximum or value <= maximum)
end

function Script.SetLoadedTeam(store, id)
    if store == nil and id == nil then loadedStore, loadedID = nil, nil; return true end
    if type(store) ~= "table" or type(id) ~= "string" or not BattleBuddyTeams.GetTeam(store, id) then
        return nil, "unknown_team"
    end
    loadedStore, loadedID = store, id
    return true
end

function Script.ActiveScript()
    if not loadedStore then return end
    local team = BattleBuddyTeams.GetTeam(loadedStore, loadedID)
    return team and team.script
end

-- Only an actual hardware handler may enter this integration seam.
function Script.WithHardwareEvent(callback, ...)
    if hardware or type(callback) ~= "function" then return nil, "invalid_hardware_context" end
    hardware, used = true, false
    local ok, result = pcall(callback, ...)
    hardware, used = false, false
    if not ok then return nil, result end
    return true, result
end

function Script.Execute(action)
    if not hardware then return nil, "hardware_event_required" end
    if used then return nil, "action_already_issued" end
    local kind = Compatibility.ReadField(action, "kind")
    local index = Compatibility.ReadField(action, "index")
    if kind == "test" then
        local value = Compatibility.ReadField(action, "text")
        if type(value) ~= "string" then return nil, "invalid_test_text" end
        used = true
        print(value)
        return true
    end
    if type(kind) ~= "string" or not actions[kind] then return nil, "invalid_action" end
    if (kind == "ability" or kind == "change") and (not Integer(index, 3) or index == 0) then
        return nil, "invalid_index"
    end
    local fn = C_PetBattles and C_PetBattles[actions[kind]]
    if type(fn) ~= "function" then return nil, "unavailable_action" end
    used = true
    local ok = pcall(fn, index)
    if not ok then return nil, "action_failed" end
    return true
end

local function Read(api, name, position, inspectors, ...)
    local fn = api and api[name]
    if type(fn) ~= "function" then return end
    local function Result(ok, ...)
        if not ok then return nil, "unavailable_api" end
        local value = select(position, ...)
        return Public(value, inspectors)
    end
    return Result(pcall(fn, ...))
end

function Script.HandleBattleEvent(event, value, api, inspectors)
    api = api or C_PetBattles
    if event == "PET_BATTLE_OPENING_START" or event == "PET_BATTLE_CLOSE" then
        rounds, played = { [0] = 0, [1] = 0, [2] = 0 }, { {}, {} }
    elseif event == "PET_BATTLE_PET_ROUND_RESULTS" then
        local round = Public(value, inspectors)
        if not Integer(round) then rounds = {}; return end
        if rounds[0] ~= nil and round == rounds[0] - 1 then return end
        rounds[0] = round + 1
        for owner = 1, 2 do if rounds[owner] ~= nil then rounds[owner] = rounds[owner] + 1 end end
    elseif event == "PET_BATTLE_PET_CHANGED" then
        local owner = Public(value, inspectors)
        if owner ~= 1 and owner ~= 2 then
            rounds[1], rounds[2], played = nil, nil, { { unknown = true }, { unknown = true } }
            return
        end
        rounds[owner] = 1
        local pet = Read(api, "GetActivePet", 1, inspectors, owner)
        if Integer(pet, 3) and pet > 0 then played[owner][pet] = true
        else played[owner].unknown = true end
    end
end

function Script.CaptureSnapshot(api, inspectors, journal)
    api, journal = api or C_PetBattles, journal or C_PetJournal
    local function Get(name, position, ...) return Read(api, name, position, inspectors, ...) end
    local function Auras(owner, pet)
        local count = Get("GetNumAuras", 1, owner, pet)
        if not Integer(count, 1000) then return end
        local result = {}
        for index = 1, count do
            local id = Get("GetAuraInfo", 1, owner, pet, index)
            local aura = { id = id, duration = Get("GetAuraInfo", 3, owner, pet, index) }
            if type(id) == "number" then
                aura.name, aura.icon = Get("GetAbilityInfoByID", 2, id), Get("GetAbilityInfoByID", 3, id)
            end
            result[index] = aura
        end
        return result
    end
    local snapshot = { round = rounds[0], canSwapOut = Get("CanActivePetSwapOut", 1),
        petSelect = Get("ShouldShowPetSelect", 1), skipAvailable = Get("IsSkipAvailable", 1),
        trapAvailable = Get("IsTrapAvailable", 1), trapError = Get("IsTrapAvailable", 2) }
    local weather = Auras(0, 0)
    if weather then snapshot.weather = weather[1] or false end
    snapshot.weathers = {}
    for _, id in ipairs({ 171, 590, 596, 257, 454, 205, 718, 229, 403, 203, 2320, 2350 }) do
        snapshot.weathers[#snapshot.weathers + 1] = { id = id, name = Get("GetAbilityInfoByID", 2, id),
            icon = Get("GetAbilityInfoByID", 3, id) }
    end
    local fields = { health = "GetHealth", maxHealth = "GetMaxHealth", speed = "GetSpeed", power = "GetPower",
        level = "GetLevel", type = "GetPetType", speciesID = "GetPetSpeciesID", name = "GetName", icon = "GetIcon" }
    for owner, key in ipairs({ "ally", "enemy" }) do
        local side = { active = Get("GetActivePet", 1, owner), round = rounds[owner], auras = Auras(owner, 0) }
        snapshot[key] = side
        local count = Get("GetNumPets", 1, owner)
        if Integer(count, 3) then
            side.pets = {}
            for slot = 1, count do
                local pet = { abilities = {}, auras = Auras(owner, slot) }
                side.pets[slot] = pet
                for field, name in pairs(fields) do pet[field] = Get(name, 1, owner, slot) end
                local quality = Get("GetBreedQuality", 1, owner, slot)
                if type(quality) == "number" then pet.quality = quality + 1 end
                if played[owner][slot] then pet.played = true
                elseif not played[owner].unknown then pet.played = false end
                if owner == 1 then pet.canSwapIn = Get("CanPetSwapIn", 1, slot) end
                local speciesName = Get("GetName", 2, owner, slot)
                if type(speciesName) == "string" then
                    local species = Read(journal, "FindPetIDByName", 1, inspectors, speciesName)
                    local petID, petState = Read(journal, "FindPetIDByName", 2, inspectors, speciesName)
                    if petState == "usable" then pet.collected = true
                    elseif petState == "unavailable" then pet.collected = false end
                    if type(species) == "number" then
                        local obtainable = Read(journal, "GetPetInfoBySpeciesID", 11, inspectors, species)
                        if obtainable == false then pet.collectedCount, pet.collectedMax = 0, 0
                        elseif obtainable == true then
                            pet.collectedCount = Read(journal, "GetNumCollectedInfo", 1, inspectors, species)
                            pet.collectedMax = Read(journal, "GetNumCollectedInfo", 2, inspectors, species)
                        end
                    end
                end
                for ability = 1, 3 do
                    local record = { id = Get("GetAbilityInfo", 1, owner, slot, ability),
                        name = Get("GetAbilityInfo", 2, owner, slot, ability),
                        icon = Get("GetAbilityInfo", 3, owner, slot, ability),
                        type = Get("GetAbilityInfo", 7, owner, slot, ability),
                        usable = Get("GetAbilityState", 1, owner, slot, ability),
                        cooldown = Get("GetAbilityState", 2, owner, slot, ability),
                        lockdown = Get("GetAbilityState", 3, owner, slot, ability) }
                    pet.abilities[ability] = record
                    local hidden = Get("GetAbilityInfo", 8, owner, slot, ability)
                    local otherOwner = owner == 1 and 2 or 1
                    local active = Get("GetActivePet", 1, otherOwner)
                    if hidden == false and type(record.type) == "number" and Integer(active, 3) and active > 0 then
                        local otherType = Get("GetPetType", 1, otherOwner, active)
                        if type(otherType) == "number" then record.modifier = Get("GetAttackModifier", 1, record.type, otherType) end
                    end
                end
            end
        end
    end
    return snapshot
end

if CreateFrame then
    local frame = CreateFrame("Frame")
    for _, event in ipairs({ "PET_BATTLE_OPENING_START", "PET_BATTLE_CLOSE", "PET_BATTLE_PET_CHANGED", "PET_BATTLE_PET_ROUND_RESULTS" }) do
        pcall(frame.RegisterEvent, frame, event)
    end
    frame:SetScript("OnEvent", function(_, event, value) Script.HandleBattleEvent(event, value) end)
end
