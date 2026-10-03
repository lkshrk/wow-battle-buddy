local sourceRoot = (... or ".")
COLLECTIONS_JOURNAL_TAB_INDEX_PETS = 2

dofile(sourceRoot .. "/BattleBuddy/PetJournalSurface.lua")

local function AssertEqual(actual, expected)
    if actual ~= expected then
        error(("expected %s, got %s"):format(tostring(expected), tostring(actual)))
    end
end

local Surface = BattleBuddyPetJournalSurface
local view = Surface.BuildView({
    selectedEncounter = { state = "hidden", label = "Ignored" },
    reasons = { { message = "Team is not selected." }, { message = "Evidence is stale." } },
    actionText = "Review the selected encounter.",
})
AssertEqual(view.selectionText, "The selected encounter is hidden by the current filter. Clear or adjust the filter to review it.")
AssertEqual(#view.reasonLines, 2)
AssertEqual(view.reasonLines[1], "Team is not selected.")
AssertEqual(view.actionText, "Review the selected encounter.")
AssertEqual(view.workflowText, "Workflow status is unavailable.")

view = Surface.BuildView({ selectedEncounter = { state = "missing" } })
AssertEqual(view.selectionText, "The saved encounter is missing. Select an available encounter; BattleBuddy will not substitute another one.")
AssertEqual(view.reasonLines[1], "No workflow blockers are currently reported.")
AssertEqual(view.actionText, "Browse and selection never apply a team or start a battle.")

view = Surface.BuildView({
    selectedEncounter = { state = "selected", label = "Tamer A" },
    reasons = { { message = 12 }, {}, { message = "Known blocker" } },
    statusMessage = "Ignored because a reason exists.",
})
AssertEqual(view.selectionText, "Tamer A")
AssertEqual(#view.reasonLines, 1)
AssertEqual(view.reasonLines[1], "Known blocker")

view = Surface.BuildView({ selectedEncounter = { state = "stale" }, statusMessage = "Catalog update required." })
AssertEqual(view.selectionText, "The selected encounter is stale. Refresh its evidence before continuing.")
AssertEqual(view.reasonLines[1], "Catalog update required.")

view = Surface.BuildView({ statusMessage = "No encounter content has been loaded yet." })
AssertEqual(view.selectionText, "No encounter selected. Choose an encounter when BattleBuddy content is available.")
AssertEqual(view.reasonLines[1], "No encounter content has been loaded yet.")

view = Surface.BuildView({
    workflow = { requestedState = "paused", teamState = "draft" },
})
AssertEqual(view.workflowText, "Workflow reports paused. Team is draft.")

view = Surface.BuildView({
    workflow = { requestedState = "running", teamState = "bound_battle" },
})
AssertEqual(view.workflowText, "Workflow reports running. Team is bound to the current battle.")

view = Surface.BuildView({
    workflow = { requestedState = "unknown", teamState = "applied" },
})
AssertEqual(view.workflowText, "Workflow status is unavailable. Team is applied.")

view = Surface.BuildView(false)
AssertEqual(view.selectionText, "No encounter selected. Choose an encounter when BattleBuddy content is available.")
AssertEqual(view.reasonLines[1], "No workflow blockers are currently reported.")

BattleBuddyEncounterBrowser = {
    BuildView = function()
        return {
            selectedEncounter = { label = "Cinder Pup" },
            selectedState = "selected",
        }
    end,
}
local browserSet, browserView = Surface.SetEncounterBrowserInput({})
AssertEqual(browserSet, true)
AssertEqual(browserView.selectedEncounter.label, "Cinder Pup")
view = Surface.BuildView(Surface.input)
AssertEqual(view.selectionText, "Cinder Pup")

BattleBuddyEncounterBrowser.BuildView = function()
    return {
        selectedState = "none",
        emptyState = "No encounters match these filters.",
    }
end
browserSet, browserView = Surface.SetEncounterBrowserInput({})
AssertEqual(browserSet, true)
AssertEqual(browserView.emptyState, "No encounters match these filters.")
view = Surface.BuildView(Surface.input)
AssertEqual(view.reasonLines[1], "No encounters match these filters.")

BattleBuddyEncounterBrowser.BuildView = function()
    return {
        selectedState = "none",
        inputState = "unavailable",
        emptyState = "Encounter content is unavailable.",
    }
end
browserSet, browserView = Surface.SetEncounterBrowserInput({})
AssertEqual(browserSet, true)
AssertEqual(browserView.inputState, "unavailable")
view = Surface.BuildView(Surface.input)
AssertEqual(view.reasonLines[1], "Encounter content is unavailable.")

BattleBuddyEncounterBrowser = nil
local browserSetState, browserSetReason = Surface.SetEncounterBrowserInput({})
AssertEqual(browserSetState, false)
AssertEqual(browserSetReason, "unavailable")

local opened, state = Surface.Open()
AssertEqual(opened, false)
AssertEqual(state, "unavailable")

local shown, tab
SetCollectionsJournalShown = function(requestedShown, requestedTab)
    shown = requestedShown
    tab = requestedTab
end
opened = Surface.Open()
AssertEqual(opened, true)
AssertEqual(shown, true)
AssertEqual(tab, COLLECTIONS_JOURNAL_TAB_INDEX_PETS)


local function NewFrame()
    local frame = { points = {} }
    function frame:SetSize(width, height) self.width, self.height = width, height end
    function frame:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function frame:SetFrameLevel(level) self.frameLevel = level end
    function frame:CreateFontString()
        local text = {}
        function text:SetPoint(...) end
        function text:SetJustifyH(...) end
        function text:SetWordWrap(...) end
        function text:SetText(value) text.value = value end
        return text
    end
    function frame:SetScript(...) end
    function frame:EnableMouse(...) end
    return frame
end

local createdPanel
CreateFrame = function(_, _, parent)
    createdPanel = NewFrame()
    createdPanel.parent = parent
    return createdPanel
end
local journal = NewFrame()
journal.RightInset = NewFrame()
function journal:GetFrameLevel() return 50 end
Surface.frame = nil
Surface.selection = nil
Surface.workflow = nil
Surface.reasons = nil
PetJournal = journal
AssertEqual(Surface.Attach(), true)
AssertEqual(createdPanel.width, 400)
AssertEqual(createdPanel.height, 50)
AssertEqual(createdPanel.points[1][1], "BOTTOMLEFT")
AssertEqual(createdPanel.points[1][2], journal.RightInset)
AssertEqual(createdPanel.points[2][1], "BOTTOMRIGHT")
AssertEqual(createdPanel.points[2][2], journal.RightInset)
AssertEqual(createdPanel.frameLevel, 51)

Surface.frame = nil
PetJournal = NewFrame()
function PetJournal:GetFrameLevel() return 5 end
AssertEqual(Surface.Attach(), true)
AssertEqual(createdPanel.points[1][1], "BOTTOM")
AssertEqual(createdPanel.points[1][2], PetJournal)
