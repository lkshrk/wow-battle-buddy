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
    input = input or {}

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

local function CreateSurface(petJournal)
    if Surface.frame then
        return Surface.frame
    end

    local panel = CreateFrame("Frame", nil, petJournal)
    panel:SetSize(360, 50)
    panel:SetPoint("BOTTOM", petJournal, "BOTTOM", 0, 2)
    panel:SetFrameLevel(petJournal:GetFrameLevel() + 1)

    local header = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    header:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    header:SetText("BattleBuddy")

    local selection = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    selection:SetPoint("LEFT", header, "RIGHT", 8, 0)
    selection:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
    selection:SetJustifyH("LEFT")
    selection:SetWordWrap(false)

    local workflow = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    workflow:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -16)
    workflow:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -16)
    workflow:SetJustifyH("LEFT")
    workflow:SetWordWrap(false)

    local reasons = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    reasons:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -32)
    reasons:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -32)
    reasons:SetJustifyH("LEFT")
    reasons:SetWordWrap(false)

    panel:SetScript("OnEnter", function(self)
        local view = Surface.BuildView(Surface.input)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("BattleBuddy")
        GameTooltip:AddLine(view.selectionText, 1, 1, 1, true)
        GameTooltip:AddLine(view.workflowText, 0.8, 0.8, 0.8, true)
        for _, reason in ipairs(view.reasonLines) do
            GameTooltip:AddLine(reason, 0.8, 0.8, 0.8, true)
        end
        GameTooltip:AddLine(view.actionText, 0.6, 0.8, 1, true)
        GameTooltip:Show()
    end)
    panel:SetScript("OnLeave", GameTooltip_Hide)
    panel:EnableMouse(true)

    Surface.frame = panel
    Surface.selection = selection
    Surface.workflow = workflow
    Surface.reasons = reasons
    return panel
end

function Surface.Render(input)
    if not Surface.frame then
        return false
    end

    local view = Surface.BuildView(input)
    Surface.selection:SetText(view.selectionText)
    Surface.workflow:SetText(view.workflowText)
    Surface.reasons:SetText(table.concat(view.reasonLines, " · "))
    return true
end

function Surface.Attach()
    if not PetJournal then
        return false
    end

    CreateSurface(PetJournal)
    Surface.Render(Surface.input)
    return true
end

function Surface.SetInput(input)
    Surface.input = input
    Surface.Render(input)
end

function Surface.SetEncounterBrowserInput(input)
    if type(BattleBuddyEncounterBrowser) ~= "table" then
        return false, "unavailable"
    end

    local browserView = BattleBuddyEncounterBrowser.BuildView(input)
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
    if browserView.emptyState then
        surfaceInput.statusMessage = browserView.emptyState
    end

    Surface.SetInput(surfaceInput)
    return true, browserView
end

function Surface.Open()
    if type(SetCollectionsJournalShown) ~= "function" then
        return false, "unavailable"
    end

    SetCollectionsJournalShown(true, COLLECTIONS_JOURNAL_TAB_INDEX_PETS)
    Surface.Attach()
    return true
end

if EventUtil then
    EventUtil.ContinueOnAddOnLoaded("Blizzard_Collections", Surface.Attach)
end
