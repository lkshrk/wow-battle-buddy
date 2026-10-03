BattleBuddyPetJournalSurface = {}

local Surface = BattleBuddyPetJournalSurface

local function CopyReasons(reasons)
    local copied = {}
    for _, reason in ipairs(reasons or {}) do
        if type(reason) == "table" and type(reason.message) == "string" then
            copied[#copied + 1] = reason.message
        end
    end
    return copied
end

local function WorkflowText(workflow)
    if type(workflow) ~= "table" then
        return "Workflow status is unavailable."
    end

    local state = workflow.requestedState
    local stateText = state == "running" and "Workflow reports running."
        or state == "paused" and "Workflow reports paused."
        or state == "stopped" and "Workflow reports stopped."
        or "Workflow status is unavailable."
    local teamState = workflow.teamState
    local teamText = teamState == "draft" and " Team is draft."
        or teamState == "saved" and " Team is saved."
        or teamState == "selected" and " Team is selected."
        or teamState == "applied" and " Team is applied."
        or teamState == "bound_battle" and " Team is bound to the current battle."
        or ""
    return stateText .. teamText
end

function Surface.BuildView(input)
    input = type(input) == "table" and input or {}

    local selected = input.selectedEncounter
    local selectionText
    if type(selected) ~= "table" then
        selectionText = "No encounter selected. Choose an encounter when BattleBuddy content is available."
    elseif selected.state == "missing" then
        selectionText = "The saved encounter is missing. Select an available encounter; BattleBuddy will not substitute another one."
    elseif selected.state == "hidden" then
        selectionText = "The selected encounter is hidden by the current filter. Clear or adjust the filter to review it."
    elseif selected.state == "stale" then
        selectionText = "The selected encounter is stale. Refresh its evidence before continuing."
    elseif type(selected.label) == "string" and selected.label ~= "" then
        selectionText = selected.label
    else
        selectionText = "Encounter selection is unavailable."
    end

    local reasons = CopyReasons(input.reasons)
    if #reasons == 0 then
        reasons[1] = type(input.statusMessage) == "string" and input.statusMessage
            or "No workflow blockers are currently reported."
    end

    return {
        selectionText = selectionText,
        workflowText = WorkflowText(input.workflow),
        reasonLines = reasons,
        actionText = type(input.actionText) == "string" and input.actionText
            or "Browse and selection never apply a team or start a battle.",
    }
end

local function SetShown(frame, shown)
    if frame and frame.SetShown then frame:SetShown(shown) end
end

local function MakeText(parent, template, point, relative, relativePoint, x, y)
    local text = parent:CreateFontString(nil, "OVERLAY", template)
    text:SetPoint(point, relative, relativePoint, x, y)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(true)
    return text
end

local function CreateSurface(petJournal)
    if Surface.frame then return Surface.frame end

    local panel = CreateFrame("Frame", nil, petJournal, "BackdropTemplate")
    panel:SetSize(310, 390)
    panel:SetPoint("TOPRIGHT", petJournal, "TOPRIGHT", -38, -42)
    panel:SetFrameLevel(petJournal:GetFrameLevel() + 10)
    if panel.SetBackdrop then
        panel:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        panel:SetBackdropColor(0.04, 0.04, 0.04, 0.96)
        panel:SetBackdropBorderColor(0.6, 0.5, 0.2, 1)
    end

    local title = MakeText(panel, "GameFontNormalLarge", "TOPLEFT", panel, "TOPLEFT", 14, -14)
    title:SetText("BattleBuddy")
    local subtitle = MakeText(panel, "GameFontDisableSmall", "TOPLEFT", panel, "TOPLEFT", 14, -38)
    subtitle:SetText("Encounter browser — read-only")
    local listTitle = MakeText(panel, "GameFontNormalSmall", "TOPLEFT", panel, "TOPLEFT", 14, -56)
    listTitle:SetText("Encounter content")

    local search = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    search:SetSize(168, 20)
    search:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -72)
    search:SetAutoFocus(false)
    search:SetTextInsets(6, 6, 0, 0)
    search:SetScript("OnTextChanged", function(self, userInput)
        if userInput then Surface.SetFilter("query", self:GetText()) end
    end)
    local searchLabel = MakeText(panel, "GameFontDisableSmall", "LEFT", search, "RIGHT", 6, 0)
    searchLabel:SetText("Search")

    local filters = { "all", "available", "supported" }
    local filterButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    filterButton:SetSize(82, 20)
    filterButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -14, -72)
    filterButton:SetText("All")
    filterButton:SetScript("OnClick", function(self)
        Surface.filterIndex = (Surface.filterIndex or 1) % #filters + 1
        local choice = filters[Surface.filterIndex]
        self:SetText(choice == "all" and "All" or choice == "available" and "Available" or "Supported")
        if choice == "available" then
            Surface.SetFilter("availability", "available")
        elseif choice == "supported" then
            Surface.SetFilter("support", "supported")
        else
            Surface.SetFilter("availability", nil)
            Surface.SetFilter("support", nil)
        end
    end)

    local rows = {}
    for index = 1, 5 do
        local row = CreateFrame("Button", nil, panel, "BackdropTemplate")
        row:SetSize(278, 29)
        row:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -98 - ((index - 1) * 31))
        if row.SetBackdrop then
            row:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background" })
            row:SetBackdropColor(0, 0, 0, 0.35)
        end
        row.label = MakeText(row, "GameFontHighlightSmall", "LEFT", row, "LEFT", 8, 0)
        row.label:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row:SetScript("OnClick", function(self)
            if self.encounterID then Surface.SelectEncounter(self.encounterID) end
        end)
        rows[index] = row
    end

    local detail = MakeText(panel, "GameFontHighlightSmall", "TOPLEFT", panel, "TOPLEFT", 14, -260)
    detail:SetPoint("RIGHT", panel, "RIGHT", -14, 0)
    local workflow = MakeText(panel, "GameFontDisableSmall", "TOPLEFT", panel, "TOPLEFT", 14, -307)
    workflow:SetPoint("RIGHT", panel, "RIGHT", -14, 0)
    local reasons = MakeText(panel, "GameFontDisableSmall", "TOPLEFT", panel, "TOPLEFT", 14, -334)
    reasons:SetPoint("RIGHT", panel, "RIGHT", -14, 0)
    local action = MakeText(panel, "GameFontHighlightSmall", "TOPLEFT", panel, "TOPLEFT", 14, -365)
    action:SetPoint("RIGHT", panel, "RIGHT", -14, 0)

    local opener = CreateFrame("Button", nil, petJournal, "UIPanelButtonTemplate")
    opener:SetSize(100, 22)
    opener:SetPoint("TOPRIGHT", petJournal, "TOPRIGHT", -45, -21)
    opener:SetText("BattleBuddy")
    opener:SetScript("OnClick", function()
        SetShown(panel, true)
        Surface.Render(Surface.input)
    end)

    Surface.frame = panel
    Surface.rows = rows
    Surface.detail = detail
    Surface.workflow = workflow
    Surface.reasons = reasons
    Surface.action = action
    Surface.opener = opener
    Surface.search = search
    Surface.filterButton = filterButton
    SetShown(panel, false)
    return panel
end

function Surface.Render(input)
    if not Surface.frame then return false end

    local view = Surface.BuildView(input)
    local browser = Surface.browserView or {}
    for index, row in ipairs(Surface.rows or {}) do
        local encounter = browser.rows and browser.rows[index] or nil
        row.encounterID = encounter and encounter.encounterID or nil
        row.label:SetText(encounter and encounter.label or "")
        SetShown(row, encounter ~= nil)
    end

    local selected = browser.selectedEncounter
    local detail = view.selectionText
    if selected then
        detail = selected.label .. "\n" .. (selected.support or "unverified") .. " support · " .. (selected.availability or "unknown") .. " availability"
        if BattleBuddyConfig and BattleBuddyConfig.GetSetting and BattleBuddyConfig.GetSetting("showRevisionDetails") then
            detail = detail .. "\nRecord " .. tostring(selected.recordRevision or "?") .. " · Effective " .. tostring(selected.effectiveRecordRevision or "?")
        end
    end
    Surface.detail:SetText(detail)
    Surface.workflow:SetText(view.workflowText)
    Surface.reasons:SetText(table.concat(view.reasonLines, "\n"))
    Surface.action:SetText(view.actionText)
    return true
end

function Surface.Attach()
    if not PetJournal then return false end

    CreateSurface(PetJournal)
    Surface.Render(Surface.input)
    return true
end

function Surface.SelectEncounter(encounterID)
    if type(encounterID) ~= "string" or type(Surface.browserInput) ~= "table" then return false end

    local input = {}
    for key, value in pairs(Surface.browserInput) do input[key] = value end
    input.selectedEncounterID = encounterID
    return Surface.SetEncounterBrowserInput(input)
end

function Surface.SetFilter(key, value)
    if type(Surface.browserInput) ~= "table" then return false end

    local input = {}
    for inputKey, inputValue in pairs(Surface.browserInput) do input[inputKey] = inputValue end
    input.filters = {}
    for filterKey, filterValue in pairs(Surface.browserInput.filters or {}) do input.filters[filterKey] = filterValue end
    input.filters[key] = value
    return Surface.SetEncounterBrowserInput(input)
end

function Surface.SetInput(input)
    Surface.input = input
    Surface.Render(input)
end

function Surface.SetEncounterBrowserInput(input)
    if type(BattleBuddyEncounterBrowser) ~= "table" then return false, "unavailable" end

    Surface.browserInput = type(input) == "table" and input or {}
    local browserView = BattleBuddyEncounterBrowser.BuildView(Surface.browserInput)
    Surface.browserView = browserView
    local selectedEncounter = browserView.selectedEncounter and {
        state = browserView.selectedState,
        label = browserView.selectedEncounter.label,
    } or {
        state = browserView.selectedState,
    }
    local surfaceInput = {}
    for key, value in pairs(Surface.input or {}) do
        surfaceInput[key] = value
    end
    surfaceInput.selectedEncounter = selectedEncounter
    surfaceInput.statusMessage = browserView.emptyState

    Surface.SetInput(surfaceInput)
    return true, browserView
end

function Surface.Open()
    if type(SetCollectionsJournalShown) ~= "function" then return false, "unavailable" end

    SetCollectionsJournalShown(true, COLLECTIONS_JOURNAL_TAB_INDEX_PETS)
    Surface.Attach()
    if Surface.frame and (not BattleBuddyConfig or not BattleBuddyConfig.GetSetting or BattleBuddyConfig.GetSetting("showPetJournalPanel")) then
        SetShown(Surface.frame, true)
    end
    return true
end

if EventUtil then
    EventUtil.ContinueOnAddOnLoaded("Blizzard_Collections", Surface.Attach)
end
