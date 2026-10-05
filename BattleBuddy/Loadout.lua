BattleBuddyLoadout = {}

local Loadout = BattleBuddyLoadout
local Compatibility = BattleBuddyCompatibility
local Public, Field = Compatibility.PublicValueOfType, Compatibility.ReadField
local host, loadedStore, loadedID, target, registeredDev
local leveling = {}
local inWorld = false
local families = { "Humanoid", "Dragon", "Flying", "Undead", "Critter", "Magical", "Elemental", "Beast", "Water", "Mechanical" }
local rarityColors = { { 0.62, 0.62, 0.62 }, { 1, 1, 1 }, { 0.12, 1, 0 }, { 0, 0.44, 0.87 } }

local function Read(callback, ...)
    if type(callback) ~= "function" then return end
    local function Results(ok, ...)
        if not ok then return end
        local values = {}
        for i = 1, select("#", ...) do values[i] = Compatibility.PublicValue((select(i, ...))) end
        return unpack(values, 1, select("#", ...))
    end
    return Results(pcall(callback, ...))
end

local function Number(value)
    value = Public(value, "number")
    if value and value == value and value > -math.huge and value < math.huge then return value end
end

local function Index(value)
    value = Number(value)
    return value and value >= 1 and value <= 3 and value == math.floor(value) and value
end

local function Report(reason)
    if Loadout.message then Loadout.message:SetText(reason or "") end
    if reason and UIErrorsFrame then UIErrorsFrame:AddMessage(reason, 1, 0.3, 0.3) end
    return false, reason
end

local function LockReason(slot)
    if Read(InCombatLockdown) ~= false then return "Loadout changes are unavailable in combat." end
    if Read(C_PetBattles and C_PetBattles.IsInBattle) ~= false then return "Loadout changes are unavailable during a pet battle." end
    if not inWorld then return "Wait until the world has loaded." end
    if Read(C_PetJournal and C_PetJournal.IsJournalUnlocked) ~= true then return "The pet journal is locked." end
    if not C_PetBattles or type(C_PetBattles.GetPVPMatchmakingInfo) ~= "function" then return "Matchmaking status is unavailable." end
    local ok, rawQueue = pcall(C_PetBattles.GetPVPMatchmakingInfo)
    local queue, state = Compatibility.PublicValue(rawQueue)
    if not ok or state == "secret" or state == "restricted" then return "Matchmaking status is unavailable." end
    if queue then return "Leave pet battle matchmaking to edit the loadout." end
    local _, _, _, _, locked = Read(C_PetJournal and C_PetJournal.GetPetLoadOutInfo, slot)
    if locked ~= false then return "This battle pet slot is locked or unavailable." end
end

local function Pet(slot)
    local id, a, b, c, locked = Read(C_PetJournal and C_PetJournal.GetPetLoadOutInfo, slot)
    local pet = { id = Public(id, "string"), selected = { Number(a), Number(b), Number(c) }, locked = locked ~= false }
    if not pet.id then return pet end
    local species, custom, level, xp, maxXP, display, favorite, name, icon, family =
        Read(C_PetJournal and C_PetJournal.GetPetInfoByPetID, pet.id)
    pet.species, pet.custom, pet.name = Number(species), Public(custom, "string"), Public(name, "string")
    pet.level, pet.xp, pet.maxXP, pet.display = Number(level), Number(xp), Number(maxXP), Number(display)
    pet.icon, pet.family, pet.favorite = Number(icon) or Public(icon, "string"), Number(family), favorite == true
    local health, maximum, _, _, rarity = Read(C_PetJournal and C_PetJournal.GetPetStats, pet.id)
    pet.health, pet.maximum, pet.rarity = Number(health), Number(maximum), Number(rarity)
    if pet.species then
        pet.abilities, pet.levels = Read(C_PetJournal and C_PetJournal.GetPetAbilityList, pet.species)
    end
    return pet
end

function Loadout.DropPet(slot, petID)
    slot, petID = Index(slot), Public(petID, "string")
    if not slot or not petID or not petID:match("^BattlePet%-.+") then return Report("Choose an owned battle pet and a valid slot.") end
    local reason = LockReason(slot)
    if reason then return Report(reason) end
    local species, _, _, _, _, _, _, _, _, _, _, _, _, _, canBattle = Read(C_PetJournal.GetPetInfoByPetID, petID)
    if not Number(species) or canBattle ~= true or Read(C_PetJournal.PetIsRevoked, petID) ~= false
        or Read(C_PetJournal.PetIsLockedForConvert, petID) ~= false then
        return Report("This pet is unavailable for battles.")
    end
    if type(C_PetJournal.SetPetLoadOutInfo) ~= "function" or not pcall(C_PetJournal.SetPetLoadOutInfo, slot, petID) then
        return Report("The journal could not change this slot.")
    end
    if Read(C_PetJournal.GetPetLoadOutInfo, slot) ~= petID then return Report("The journal has not confirmed this pet change.") end
    leveling[slot] = nil
    Report(nil)
    Loadout.Refresh()
    return true
end

function Loadout.ChooseAbility(slot, tier, abilityID)
    slot, tier, abilityID = Index(slot), Index(tier), Number(abilityID)
    if not slot or not tier or not abilityID then return Report("Choose an available ability.") end
    local reason = LockReason(slot)
    if reason then return Report(reason) end
    local pet = Pet(slot)
    local usable = false
    for _, index in ipairs({ tier, tier + 3 }) do
        local id, level = Number(Field(pet.abilities, index)), Number(Field(pet.levels, index))
        if id == abilityID and level and pet.level and pet.level >= level then usable = true end
    end
    if not usable then return Report("This ability is not available at the pet's level.") end
    if type(C_PetJournal.SetAbility) ~= "function" or not pcall(C_PetJournal.SetAbility, slot, tier, abilityID) then
        return Report("The journal could not change this ability.")
    end
    if Pet(slot).selected[tier] ~= abilityID then return Report("The journal has not confirmed this ability change.") end
    if Loadout.flyout then Loadout.flyout:Hide() end
    Report(nil)
    Loadout.Refresh()
    return true
end

local function Label(parent, font, point, x, y)
    local text = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    text:SetPoint(point, parent, point, x, y)
    text:SetWordWrap(false)
    text:SetText("")
    return text
end

local function Texture(parent, width, height, point, x, y, layer)
    local texture = parent:CreateTexture(nil, layer or "ARTWORK")
    texture:SetSize(width, height)
    texture:SetPoint(point, parent, point, x, y)
    return texture
end

local function Button(parent, width, height, point, x, y, template)
    local button = CreateFrame("Button", nil, parent, template)
    button:SetSize(width, height)
    button:SetPoint(point, parent, point, x, y)
    return button
end

local function Tooltip(button, text)
    button:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(type(text) == "function" and text() or text)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end

local function Bar(parent, width, point, x, y, r, g, b)
    local bar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    bar:SetSize(width, 8)
    bar:SetPoint(point, parent, point, x, y)
    bar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 4 })
    bar:SetBackdropColor(0, 0, 0, 1)
    bar.fill = Texture(bar, width - 2, 6, "LEFT", 1, 0)
    bar.fill:SetColorTexture(r, g, b, 1)
    return bar
end

local function Fill(bar, value, maximum)
    local known = value and maximum and maximum > 0 and value >= 0
    bar.fill:SetShown(known and value > 0)
    if known then bar.fill:SetWidth((bar:GetWidth() - 2) * math.min(value / maximum, 1)) end
end

local function Ability(button, id, level, petLevel, selected)
    local name, icon
    if id then name, icon = Read(C_PetJournal and C_PetJournal.GetPetAbilityInfo, id) end
    button.icon:SetTexture(Number(icon) or Public(icon, "string"))
    local usable = id and level and petLevel and level <= petLevel
    button.icon:SetDesaturated(not usable)
    button.requirement:SetText(id and level and petLevel and level > petLevel and tostring(level) or "")
    button.selected:SetShown(selected == true)
    button.abilityID = id
    button.abilityName = Public(name, "string")
end

local function AbilityButton(parent, point, x, y)
    local button = Button(parent, 32, 32, point, x, y)
    button.icon = Texture(button, 30, 30, "CENTER", 0, 0)
    button.icon:SetTexCoord(0.075, 0.925, 0.075, 0.925)
    button:SetNormalTexture("Interface\\Buttons\\UI-Quickslot2")
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    button.selected = Texture(button, 32, 32, "CENTER", 0, 0, "OVERLAY")
    button.selected:SetTexture("Interface\\Buttons\\CheckButtonHilight")
    button.requirement = Label(button, "GameFontNormal", "CENTER", 0, 0)
    button.requirement:SetTextColor(1, 0.25, 0.25)
    Tooltip(button, function() return button.abilityName or "Ability unavailable" end)
    return button
end

local function OpenFlyout(slot, tier, button)
    local reason = LockReason(slot)
    if reason then return Report(reason) end
    local flyout = Loadout.flyout
    if flyout:IsShown() and flyout.slot == slot and flyout.tier == tier then flyout:Hide(); return end
    local pet = Pet(slot)
    if not pet.id or not pet.abilities then return end
    flyout.slot, flyout.tier = slot, tier
    flyout:ClearAllPoints()
    flyout:SetPoint("BOTTOM", button, "TOP", 0, 12)
    for index, alternative in ipairs(flyout.alternatives) do
        local position = tier + (index - 1) * 3
        local id, level = Number(Field(pet.abilities, position)), Number(Field(pet.levels, position))
        Ability(alternative, id, level, pet.level, id ~= nil and id == pet.selected[tier])
    end
    flyout:Show()
end

local function CursorDrop(slot)
    local kind, id = Read(GetCursorInfo)
    if kind == "battlepet" and Loadout.DropPet(slot, id) then
        if ClearCursor then ClearCursor() end
    end
end

function Loadout.SetTarget(value)
    target = Public(value, "table")
    Loadout.Refresh()
end

local function ObserveTarget()
    if Read(UnitExists, "target") ~= true or Read(UnitIsPlayer, "target") ~= false then return end
    local guid = Public(Read(UnitGUID, "target"), "string")
    if guid and not guid:match("^Creature%-") and not guid:match("^Vehicle%-") then return end
    local id = guid and tonumber(guid:match("^%a+%-[^-]+%-[^-]+%-[^-]+%-[^-]+%-(%d+)%-"))
    target = { name = Public(Read(UnitName, "target"), "string"), npcID = id }
end

function Loadout.Refresh()
    if not host or Read(InCombatLockdown) ~= false then return end
    Loadout.flyout:Hide()
    local header = host.target
    header.name:SetText(target and (Public(Field(target, "name"), "string") or "Unknown target") or "No Target")
    header.portrait:SetShown(target ~= nil)
    header.portrait:SetTexture(target and (Number(Field(target, "icon")) or "Interface\\Icons\\INV_Misc_QuestionMark") or nil)
    header.clear:SetShown(target ~= nil)
    header.save:SetShown(target ~= nil)
    local enemies = target and Field(target, "enemies")
    for index, enemy in ipairs(header.enemies) do
        local data = Field(enemies, index)
        local icon = Number(Field(data, "icon")) or Public(Field(data, "icon"), "string")
        local level = Number(Field(data, "level"))
        enemy:SetShown(icon ~= nil)
        enemy.icon:SetTexture(icon)
        enemy.level:SetText(level and tostring(level) or "")
    end
    local team = loadedStore and BattleBuddyTeams.GetTeam(loadedStore, loadedID)
    host.team.name:SetText(team and team.name or "Battle Pet Slots")
    local script = BattleBuddyScript and BattleBuddyScript.ActiveScript()
    host.team.script.hasScript = type(script) == "string" and script:match("%S") ~= nil
    host.team.script.icon:SetDesaturated(not host.team.script.hasScript)
    for index, slot in ipairs(Loadout.slots) do
        local pet = Pet(index)
        slot.petID = pet.id
        slot.name:SetText(pet.custom or pet.name or (pet.id and "Unknown pet" or "Empty slot"))
        slot.species:SetText(pet.custom and pet.name or "")
        slot.icon:SetTexture(pet.icon)
        local color = rarityColors[pet.rarity] or { 1, 0.82, 0 }
        slot.border:SetVertexColor(unpack(color))
        slot.name:SetTextColor(unpack(color))
        slot.level:SetText(pet.level and tostring(pet.level) or "")
        slot.levelBack:SetShown(pet.level ~= nil)
        slot.breed:SetText("")
        slot.favorite:SetShown(pet.favorite == true)
        slot.dead:SetShown(pet.health == 0)
        slot.leveling:SetShown(leveling[index] == true)
        slot.back:SetVertexColor(leveling[index] and 0.5 or 1, leveling[index] and 0.75 or 1, 1)
        local health = ""
        if pet.health and pet.maximum and pet.maximum > 0 then
            health = pet.health == 0 and "Dead" or pet.health >= pet.maximum and tostring(pet.maximum)
                or (math.floor(pet.health / pet.maximum * 100) .. "%")
        end
        slot.healthText:SetText(health)
        Fill(slot.health, pet.health, pet.maximum)
        slot.xp:SetShown(pet.level ~= nil and pet.level < 25)
        Fill(slot.xp, pet.xp, pet.maxXP)
        local family = pet.family and families[pet.family]
        slot.family:SetTexture(family and ("Interface\\PetBattles\\PetIcon-" .. family) or nil)
        slot.model:SetShown(pet.display ~= nil)
        if pet.display ~= slot.display then
            slot.model:ClearModel()
            if pet.display then slot.model:SetDisplayInfo(pet.display) end
            slot.display = pet.display
        end
        local reason = LockReason(index)
        slot.lock:SetShown(reason ~= nil)
        slot.lock.text:SetText(reason or "")
        slot.abilityBar:SetShown(not pet.locked)
        for tier, button in ipairs(slot.abilities) do
            local id, required
            for _, position in ipairs({ tier, tier + 3 }) do
                local candidate = Number(Field(pet.abilities, position))
                if candidate and candidate == pet.selected[tier] then
                    id, required = candidate, Number(Field(pet.levels, position))
                end
            end
            Ability(button, id, required, pet.level, false)
        end
    end
end

function Loadout.Mount(frame)
    if host or Read(InCombatLockdown) ~= false then return end
    host = frame
    for _, key in ipairs({ "target", "team", "loadout" }) do if host[key].label then host[key].label:Hide() end end
    local header = host.target
    header.name = Label(header, "GameFontHighlight", "TOPLEFT", 8, -8)
    header.name:SetWidth(240)
    header.name:SetJustifyH("LEFT")
    header.underline = Texture(header, 248, 3, "TOPLEFT", 8, -22)
    header.underline:SetAtlas("_UI-Frame-InnerTopTile")
    header.portrait = Texture(header, 44, 44, "BOTTOMLEFT", 4, 3)
    header.clear = Button(header, 18, 18, "TOPRIGHT", -4, -3)
    header.clear:SetNormalTexture("Interface\\FriendsFrame\\ClearBroadcastIcon")
    header.clear:SetScript("OnClick", function() Loadout.SetTarget(nil) end)
    Tooltip(header.clear, "Clear target")
    header.save = Button(header, 68, 34, "BOTTOMRIGHT", -8, 6, "UIPanelButtonTemplate")
    header.save:SetText("Save")
    header.save:SetScript("OnClick", function() Report("Save Team is not available yet.") end)
    Tooltip(header.save, "Save Team is not available yet.")
    header.enemies = {}
    for i = 1, 3 do
        local enemy = CreateFrame("Frame", nil, header)
        enemy:SetSize(28, 40)
        enemy:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 52 + (i - 1) * 29, 5)
        enemy.icon = Texture(enemy, 28, 28, "TOP", 0, 0)
        enemy.level = Label(enemy, "GameFontHighlightSmall", "BOTTOM", 0, 0)
        header.enemies[i] = enemy
    end
    host.team.back = Texture(host.team, 280, 26, "CENTER", 0, 0, "BACKGROUND")
    host.team.back:SetTexture("Interface\\PetBattles\\_PetJournalHorizTile")
    host.team.name = Label(host.team, "GameFontNormal", "LEFT", 8, 0)
    host.team.name:SetWidth(238)
    host.team.script = Button(host.team, 24, 24, "RIGHT", -2, 0)
    host.team.script.icon = Texture(host.team.script, 20, 20, "CENTER", 0, 0)
    host.team.script.icon:SetTexture("Interface\\Icons\\INV_Scroll_03")
    Tooltip(host.team.script, function()
        return host.team.script.hasScript and "This team has a script. Editing is not available here yet."
            or "This team has no script."
    end)
    Loadout.message = Label(host.loadout, "GameFontHighlightSmall", "BOTTOM", 0, 0)
    Loadout.message:SetWidth(276)
    Loadout.message:SetWordWrap(true)
    Loadout.slots = {}
    for i = 1, 3 do
        local slot = Button(host.loadout, 280, 137, "TOPLEFT", 0, -(i - 1) * 139, "InsetFrameTemplate")
        Loadout.slots[i] = slot
        slot.back = Texture(slot, 276, 133, "CENTER", 0, 0, "BACKGROUND")
        slot.back:SetAtlas("PetJournal-BattleSlot-Active")
        slot.family = Texture(slot, 77, 77, "TOPRIGHT", -4, -4, "BACKGROUND")
        slot.family:SetAlpha(0.25)
        slot.family:SetTexCoord(0.0078125, 0.4765625, 0.50390625, 0.73828125)
        slot.pet = Button(slot, 46, 46, "TOPLEFT", 15, -18)
        slot.icon = Texture(slot.pet, 42, 42, "CENTER", 0, 0)
        slot.pet:SetNormalTexture("Interface\\Buttons\\UI-Quickslot2")
        slot.border = Texture(slot.pet, 50, 50, "CENTER", 0, 0, "OVERLAY")
        slot.border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        slot.levelBack = Texture(slot.pet, 20, 20, "BOTTOMRIGHT", 4, -4, "OVERLAY")
        slot.levelBack:SetColorTexture(0.05, 0.04, 0, 1)
        slot.level = Label(slot.pet, "GameFontNormalSmall", "BOTTOMRIGHT", 1, -2)
        slot.favorite = Texture(slot.pet, 20, 20, "TOPLEFT", -3, 3, "OVERLAY")
        slot.favorite:SetAtlas("PetJournal-FavoritesIcon")
        slot.dead = Texture(slot.pet, 42, 42, "CENTER", 0, 0, "OVERLAY")
        slot.dead:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
        slot.leveling = Texture(slot.pet, 19, 19, "TOPRIGHT", -1, -1, "OVERLAY")
        slot.leveling:SetTexture("Interface\\Buttons\\Arrow-Up-Up")
        slot.name = Label(slot, "GameFontNormal", "TOPLEFT", 70, -21)
        slot.name:SetWidth(194)
        slot.name:SetJustifyH("LEFT")
        slot.species = Label(slot, "GameFontHighlightSmall", "TOPLEFT", 70, -36)
        slot.species:SetWidth(194)
        slot.species:SetJustifyH("LEFT")
        slot.breed = Label(slot, "GameFontHighlightSmall", "TOPRIGHT", -14, -56)
        slot.health = Bar(slot, 60, "BOTTOMLEFT", 14, 26, 0.1, 0.9, 0.1)
        slot.healthText = Label(slot, "GameFontHighlightSmall", "BOTTOMLEFT", 30, 38)
        slot.heart = Texture(slot, 12, 12, "BOTTOMLEFT", 14, 38)
        slot.heart:SetTexture("Interface\\PetBattles\\PetBattle-StatIcons")
        slot.heart:SetTexCoord(0.5, 1, 0.5, 1)
        slot.xp = Bar(slot, 252, "BOTTOM", 0, 7, 0.18, 0.54, 0.9)
        slot.model = CreateFrame("PlayerModel", nil, slot)
        slot.model:SetSize(88, 100)
        slot.model:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -1, 1)
        slot.model:EnableMouse(false)
        slot.shadow = Texture(slot, 69, 42, "BOTTOMRIGHT", 4, 8, "BACKGROUND")
        slot.shadow:SetAtlas("PetJournal-BattleSlot-Shadow")
        slot.abilityBar = CreateFrame("Frame", nil, slot)
        slot.abilityBar:SetSize(112, 36)
        slot.abilityBar:SetPoint("BOTTOM", slot, "BOTTOM", 0, 24)
        slot.abilities = {}
        for tier = 1, 3 do
            local button = AbilityButton(slot.abilityBar, "LEFT", 2 + (tier - 1) * 38, 0)
            slot.abilities[tier] = button
            button:SetScript("OnClick", function() OpenFlyout(i, tier, button) end)
        end
        slot.lock = CreateFrame("Frame", nil, slot)
        slot.lock:SetAllPoints()
        slot.lock.back = Texture(slot.lock, 280, 137, "CENTER", 0, 0)
        slot.lock.back:SetColorTexture(0, 0, 0, 0.5)
        slot.lock.icon = Texture(slot.lock, 32, 32, "CENTER", 0, 8)
        slot.lock.icon:SetTexture("Interface\\PetBattles\\PetBattle-LockIcon")
        slot.lock.text = Label(slot.lock, "GameFontHighlightSmall", "BOTTOM", 0, 22)
        slot.lock.text:SetWidth(260)
        slot.lock.text:SetWordWrap(true)
        for _, surface in ipairs({ slot, slot.pet }) do
            surface:SetScript("OnReceiveDrag", function() CursorDrop(i) end)
            surface:SetScript("OnClick", function() CursorDrop(i) end)
        end
    end
    Loadout.flyout = CreateFrame("Frame", nil, host.loadout, "BackdropTemplate")
    local flyout = Loadout.flyout
    flyout:SetSize(44, 81)
    flyout:SetFrameStrata("DIALOG")
    flyout:EnableMouse(true)
    flyout:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 8 })
    flyout:SetBackdropColor(0.08, 0.06, 0.04, 1)
    flyout.arrow = Texture(flyout, 24, 24, "BOTTOM", 0, -18)
    flyout.arrow:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
    flyout.alternatives = {}
    for i = 1, 2 do
        local button = AbilityButton(flyout, i == 1 and "TOP" or "BOTTOM", 0, i == 1 and -6 or 6)
        flyout.alternatives[i] = button
        button:SetScript("OnClick", function() Loadout.ChooseAbility(flyout.slot, flyout.tier, button.abilityID) end)
    end
    host:HookScript("OnShow", Loadout.Refresh)
    host:HookScript("OnHide", function() flyout:Hide() end)
    ObserveTarget()
    Loadout.Refresh()
end

local function RegisterDev()
    if registeredDev or not BattleBuddyDev then return end
    BattleBuddyDev.RegisterView("window-loadout", function()
        if Read(InCombatLockdown) ~= false or not SetCollectionsJournalShown then return false end
        SetCollectionsJournalShown(true, COLLECTIONS_JOURNAL_TAB_INDEX_PETS)
        return BattleBuddyWindow.Show()
    end, function() BattleBuddyWindow.Hide() end, function() return BattleBuddyWindow.IsActive() end)
    registeredDev = true
end

if hooksecurefunc and BattleBuddyScript then
    hooksecurefunc(BattleBuddyScript, "SetLoadedTeam", function(store, id)
        if store == nil and id == nil then
            loadedStore, loadedID, leveling = nil, nil, {}
        elseif type(store) == "table" and type(id) == "string" then
            local team = BattleBuddyTeams.GetTeam(store, id)
            if not team then return end
            loadedStore, loadedID, leveling = store, id, {}
            for i = 1, 3 do leveling[i] = team.pets[i] == 0 end
        end
        Loadout.Refresh()
    end)
end

if CreateFrame then
    Loadout.events = CreateFrame("Frame")
    for _, event in ipairs({ "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD", "PLAYER_TARGET_CHANGED",
        "PET_JOURNAL_LIST_UPDATE", "PET_JOURNAL_PET_DELETED", "PET_JOURNAL_PETS_HEALED", "PET_BATTLE_LEVEL_CHANGED",
        "COMPANION_UPDATE", "PET_BATTLE_OPENING_START", "PET_BATTLE_CLOSE", "PET_BATTLE_QUEUE_STATUS",
        "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do Loadout.events:RegisterEvent(event) end
    Loadout.events:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_ENTERING_WORLD" then inWorld = true end
        if event == "PLAYER_LEAVING_WORLD" then inWorld = false end
        if event == "PLAYER_TARGET_CHANGED" then ObserveTarget() end
        RegisterDev()
        if not host and BattleBuddyWindow and BattleBuddyWindow.frame then Loadout.Mount(BattleBuddyWindow.frame) end
        Loadout.Refresh()
    end)
    RegisterDev()
end
