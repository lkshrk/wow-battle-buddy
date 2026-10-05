BattleBuddyAutoLoad = {}

local A, T, D = BattleBuddyAutoLoad, BattleBuddyTeams, BattleBuddyTargetDetection
local Public = BattleBuddyCompatibility.PublicValueOfType
local loadedStore, loadedID, lastKey, activeBattle
local mutating, recording = 0, false
local sources = { { "mouseover", "onMouseover" }, { "softinteract", "onSoftInteract" }, { "target", "onTarget" } }

local function Setting(key) return BattleBuddyConfig.GetSetting(key) end

local function Read(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, value = pcall(fn, ...)
    if ok then return BattleBuddyCompatibility.PublicValue(value) end
end

local function Locked()
    return Read(InCombatLockdown) ~= false or Read(C_PetBattles and C_PetBattles.IsInBattle) ~= false
end

local function Key(target)
    if Public(target.state, "string") ~= "unique" or Public(target.ambiguous, "boolean") == true then return end
    local key = Public(target.key, "number") or Public(target.key, "string")
    if type(key) == "number" then
        if key > 0 and key < math.huge and key % 1 == 0 then return key end
    elseif key and key:match("^name:.+") then return key end
end

local function Candidate()
    local actual, actualTeams = D.ForUnit("target", BattleBuddyDB)
    local current = D.Current()
    if current.source == "npc" and Key(current) then
        actual, actualTeams = current, D.TeamsForCurrent(BattleBuddyDB)
    end
    for _, source in ipairs(sources) do
        local unit, mode = source[1], Setting(source[2])
        if mode ~= "none" and (unit == "target" or Read(UnitExists, unit) ~= false) then
            if unit == "target" then return actual, actualTeams, mode end
            if not (Key(actual) and #actualTeams > 0) then
                local target, teams = D.ForUnit(unit, BattleBuddyDB)
                return target, teams, mode
            end
        end
    end
end

local function OpenWindow()
    if BattleBuddyWindow and BattleBuddyWindow.IsActive() then return true end
    return BattleBuddyPetJournalSurface.Open()
end

function A.Cancel()
    A.prompt = nil
    if A.frame then A.frame:Hide() end
end

local function PaintPrompt()
    local prompt, frame = A.prompt, A.frame
    frame.target:SetText(prompt.name)
    frame.team:SetText(prompt.teams[prompt.index].name)
    frame.count:SetText(prompt.index .. " / " .. #prompt.teams)
    frame:Show()
end

function A.Cycle(delta)
    if not A.prompt or Locked() then return end
    A.prompt.index = (A.prompt.index - 1 + delta) % #A.prompt.teams + 1
    PaintPrompt()
end

function A.LoadPrompt()
    local prompt = A.prompt
    if not prompt or prompt.preview or Locked() then return false end
    local target, teams = Candidate()
    if not target or Key(target) ~= prompt.key then A.Cancel(); return false end
    local selected = prompt.teams[prompt.index].teamID
    for _, team in ipairs(teams) do
        if team.teamID == selected then
            local ok = BattleBuddyTeamsPanel.Load(selected)
            if ok then A.Cancel() end
            return ok
        end
    end
    A.Cancel()
    return false
end

local function ShowPrompt(target, teams, preview)
    if not A.frame then
        local frame = CreateFrame("Frame", "BattleBuddyAutoLoadPrompt", UIParent, "BackdropTemplate")
        A.frame = frame
        frame:SetSize(340, 158)
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        frame:SetFrameStrata("DIALOG")
        frame:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16 })
        frame:SetBackdropColor(0.04, 0.04, 0.04, 1)
        local function Label(font, y)
            local label = frame:CreateFontString(nil, "OVERLAY", font)
            label:SetPoint("TOP", frame, "TOP", 0, y)
            label:SetWidth(260)
            label:SetWordWrap(false)
            return label
        end
        frame.title = Label("GameFontNormal", -14)
        frame.title:SetText("Prompt To Load")
        frame.target = Label("GameFontHighlight", -36)
        frame.team = Label("GameFontNormal", -63)
        frame.team:SetWidth(220)
        frame.count = Label("GameFontHighlightSmall", -85)
        local function Button(text, width, x, y, callback)
            local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
            button:SetSize(width, 24)
            button:SetPoint("TOP", frame, "TOP", x, y)
            button:SetText(text)
            button:SetScript("OnClick", callback)
            return button
        end
        frame.previous = Button("<", 26, -143, -58, function() A.Cycle(-1) end)
        frame.next = Button(">", 26, 143, -58, function() A.Cycle(1) end)
        frame.load = Button("Load", 110, -60, -117, A.LoadPrompt)
        frame.cancel = Button("Cancel", 110, 60, -117, A.Cancel)
    end
    A.prompt = { key = Key(target), name = Public(target.name, "string") or "Unknown target",
        teams = teams, index = 1, preview = preview }
    PaintPrompt()
end

function A.OnObservation(changed)
    if not BattleBuddyDB or mutating > 0 or recording then return end
    if Locked() then A.Cancel(); return end
    local target, teams, mode = Candidate()
    local key = target and Key(target)
    if not key or #teams == 0 then lastKey = nil; A.Cancel(); return end
    if A.prompt and (A.prompt.key ~= key or changed) then A.Cancel() end
    if key == lastKey and not Setting("alwaysInteract") and not changed then return end
    local preferred = teams[1]
    if Setting("preferUninjuredTeams") then
        for _, team in ipairs(teams) do
            if BattleBuddyHealthiestPets.IsUninjured(team) then preferred = team; break end
        end
    end
    for _, team in ipairs(teams) do
        if loadedStore == BattleBuddyDB and loadedID == team.teamID then
            if not (Setting("alwaysInteract") and Setting("evenIfTeamLoaded"))
                or preferred.teamID == loadedID then A.Cancel(); return end
        end
    end
    local interacted
    if mode == "prompt" then
        ShowPrompt(target, teams)
        interacted = true
    elseif mode == "window" then
        A.Cancel()
        interacted = OpenWindow()
    elseif mode == "autoload" then
        A.Cancel()
        interacted = BattleBuddyTeamsPanel.Load(preferred.teamID)
        if interacted and Setting("showWindowAfterLoading")
            and (not Setting("onlyWhenAnyPetsInjured") or BattleBuddyHealthiestPets.AnyInjured()) then
            if OpenWindow() then BattleBuddyHealthiestPets.FlashInjured() end
        end
    end
    if interacted then lastKey = key end
end

local function AllDead(owner)
    local count = Public(Read(C_PetBattles.GetNumPets, owner), "number")
    if not count or count < 1 or count > 3 or count % 1 ~= 0 then return false end
    for index = 1, count do
        if Public(Read(C_PetBattles.GetHealth, owner, index), "number") ~= 0 then return false end
    end
    return true
end

function A.OnEvent(event, winner)
    if event == "PLAYER_REGEN_DISABLED" then A.Cancel()
    elseif event == "PET_BATTLE_OPENING_START" then
        A.Cancel()
        activeBattle = { store = loadedStore, id = loadedID,
            eligible = Setting("autoTrackWinRecord") and (not Setting("forPVPBattlesOnly")
                or Read(C_PetBattles.IsPlayerNPC, 2) == false) }
    elseif event == "PET_BATTLE_FINAL_ROUND" and activeBattle and not activeBattle.finished then
        activeBattle.finished = true
        winner = Public(winner, "number")
        if (winner == 0 or winner == 1 or winner == 2) and AllDead(1) and AllDead(2) then
            activeBattle.result = "draws"
        elseif winner == 1 then activeBattle.result = "wins"
        elseif winner == 2 then activeBattle.result = "losses"
        end
    elseif event == "PET_BATTLE_OVER" and activeBattle then
        local result = activeBattle.result
        if activeBattle.eligible and result and activeBattle.store and activeBattle.id then
            local team = T.GetTeam(activeBattle.store, activeBattle.id)
            if team then
                local record = team.winrecord or { wins = 0, losses = 0, draws = 0 }
                record[result] = record[result] + 1
                recording = true
                T.EditTeam(activeBattle.store, activeBattle.id, { winrecord = record })
                recording = false
                BattleBuddyTeamsPanel.Refresh()
            end
        end
        activeBattle.eligible = false
    elseif event == "PET_BATTLE_CLOSE" then
        local finished = activeBattle
        activeBattle = nil
        if finished and finished.id and finished.store == loadedStore and finished.id == loadedID
            and Setting("loadHealthiestPets") and Setting("afterPetBattlesToo") and not Locked() then
            if not BattleBuddyHealthiestPets.Apply() then BattleBuddyScript.SetLoadedTeam(nil, nil) end
        end
    end
end

hooksecurefunc(BattleBuddyScript, "SetLoadedTeam", function(store, id)
    if store == nil and id == nil then loadedStore, loadedID = nil, nil
    elseif type(store) == "table" and type(id) == "string" and T.GetTeam(store, id) then
        loadedStore, loadedID = store, id
    end
end)

local function Watch(object, name)
    local original = object and object[name]
    if not original then return end
    object[name] = function(store, ...)
        mutating = mutating + 1
        local result, reason = original(store, ...)
        mutating = mutating - 1
        if result and store == BattleBuddyDB then A.OnObservation(true) end
        return result, reason
    end
end
for _, method in ipairs({ "CreateTeam", "EditTeam", "DeleteTeam", "SetTargetTeams" }) do Watch(T, method) end
Watch(BattleBuddyTeamStrings, "ApplyImport")

A.events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_REGEN_DISABLED", "PET_BATTLE_OPENING_START", "PET_BATTLE_FINAL_ROUND",
    "PET_BATTLE_OVER", "PET_BATTLE_CLOSE" }) do A.events:RegisterEvent(event) end
A.events:SetScript("OnEvent", function(_, event, ...) A.OnEvent(event, ...) end)
BattleBuddyDev.RegisterView("autoload-prompt", function()
    if Locked() then return false end
    ShowPrompt({ state = "unique", key = 1, name = "Preview target" },
        { { name = "Preview team" }, { name = "Another preview team" } }, true)
    return true
end, A.Cancel, function() return A.frame and A.frame:IsShown() end)
