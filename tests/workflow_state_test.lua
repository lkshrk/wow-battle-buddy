local sourceRoot = (...or "..")
dofile(sourceRoot .. "/BattleBuddy/Config.lua")
dofile(sourceRoot .. "/BattleBuddy/WorkflowState.lua")

local function AssertEqual(actual, expected)
    if actual ~= expected then
        error(("expected %s, got %s"):format(tostring(expected), tostring(actual)))
    end
end

AssertEqual(BattleBuddyConfig.Policy.LevelingCompletionLevel, 25)
BattleBuddyDB = { settingOverrides = {} }
AssertEqual(BattleBuddyConfig.GetSetting("showPetJournalPanel"), true)
AssertEqual(BattleBuddyConfig.GetSetting("showRevisionDetails"), false)
AssertEqual(BattleBuddyConfig.SetSetting("showRevisionDetails", true), true)
AssertEqual(BattleBuddyConfig.GetSetting("showRevisionDetails"), true)
AssertEqual(BattleBuddyConfig.SetSetting("showRevisionDetails", false), true)
AssertEqual(BattleBuddyDB.settingOverrides.showRevisionDetails, nil)
AssertEqual(BattleBuddyConfig.SetSetting("missing", true), false)

local pauseReasons = {
    { reasonID = "reason-1", code = "SCRIPT_FAILURE", workflowGeneration = 7, contextToken = "source-7" },
}
local workflow = BattleBuddyWorkflowState.New({
    generation = 7,
    requestedState = "paused",
    selectedTeamID = "team-1",
    pauseReasons = pauseReasons,
})

pauseReasons[1].code = "CHANGED"
AssertEqual(workflow.generation, 7)
AssertEqual(workflow.requestedState, "paused")
AssertEqual(workflow.selectedTeamID, "team-1")
AssertEqual(workflow.pauseReasons[1].code, "SCRIPT_FAILURE")
AssertEqual(workflow.pauseReasons == pauseReasons, false)
AssertEqual(workflow.pauseReasons[1] == pauseReasons[1], false)
AssertEqual(#workflow.readinessBlockers, 0)
AssertEqual(#workflow.healthWarnings, 0)

local request = {
    workflowGeneration = 7,
    presentedReasons = {
        { reasonID = "reason-1", contextToken = "source-7" },
    },
    expectedContextTokens = { ["reason-1"] = "source-7" },
    choices = { ["reason-1"] = "retry" },
}

local status, returnedWorkflow = BattleBuddyWorkflowState.ReviewResume(workflow, request)
AssertEqual(status, "accepted")
AssertEqual(returnedWorkflow, workflow)

status = BattleBuddyWorkflowState.ReviewResume(workflow, {
    workflowGeneration = 6,
    presentedReasons = request.presentedReasons,
})
AssertEqual(status, "review_required")

status = BattleBuddyWorkflowState.ReviewResume(workflow, {
    workflowGeneration = 7,
    presentedReasons = {
        { reasonID = "reason-1", contextToken = "stale-source" },
    },
    expectedContextTokens = { ["reason-1"] = "stale-source" },
    choices = { ["reason-1"] = "retry" },
})
AssertEqual(status, "review_required")

status = BattleBuddyWorkflowState.ReviewResume(workflow, {
    workflowGeneration = 7,
    presentedReasons = {
        { reasonID = "reason-2", contextToken = "source-7" },
    },
    expectedContextTokens = { ["reason-2"] = "source-7" },
    choices = { ["reason-2"] = "retry" },
})
AssertEqual(status, "review_required")

status = BattleBuddyWorkflowState.ReviewResume(workflow, {
    workflowGeneration = 7,
    presentedReasons = {
        { reasonID = "reason-1", contextToken = "source-7" },
        { reasonID = "reason-1", contextToken = "source-7" },
    },
    expectedContextTokens = { ["reason-1"] = "source-7" },
    choices = { ["reason-1"] = "retry" },
})
AssertEqual(status, "review_required")

status = BattleBuddyWorkflowState.ReviewResume(workflow, {
    workflowGeneration = 7,
    presentedReasons = {
        { reasonID = "reason-1", contextToken = "source-7" },
    },
    expectedContextTokens = {
        ["reason-1"] = "source-7",
        unexpected = "source-7",
    },
    choices = { ["reason-1"] = "retry" },
})
AssertEqual(status, "review_required")

local malformedWorkflow = BattleBuddyWorkflowState.New({
    generation = 7,
    requestedState = "paused",
    pauseReasons = { "SCRIPT_FAILURE" },
})
status = BattleBuddyWorkflowState.ReviewResume(malformedWorkflow, request)
AssertEqual(status, "review_required")

local sparseWorkflow = BattleBuddyWorkflowState.New({
    generation = 7,
    requestedState = "paused",
    pauseReasons = {
        [2] = { reasonID = "reason-1", code = "SCRIPT_FAILURE", workflowGeneration = 7, contextToken = "source-7" },
    },
})
status = BattleBuddyWorkflowState.ReviewResume(sparseWorkflow, request)
AssertEqual(status, "review_required")

local running, startError = BattleBuddyWorkflowState.Start(BattleBuddyWorkflowState.New({
    generation = 3,
    selectedTeamID = "team-2",
}))
AssertEqual(startError, nil)
AssertEqual(running.generation, 4)
AssertEqual(running.requestedState, "running")
AssertEqual(running.selectedTeamID, "team-2")

local startRejected, startRejection = BattleBuddyWorkflowState.Start(workflow)
AssertEqual(startRejected, nil)
AssertEqual(startRejection, "review_required")

local invalidStart = BattleBuddyWorkflowState.New({
    pauseReasons = { "SCRIPT_FAILURE" },
})
startRejected, startRejection = BattleBuddyWorkflowState.Start(invalidStart)
AssertEqual(startRejected, nil)
AssertEqual(startRejection, "invalid_current_reasons")

local stopped = BattleBuddyWorkflowState.Stop(workflow)
AssertEqual(stopped.generation, 8)
AssertEqual(stopped.requestedState, "stopped")
AssertEqual(stopped.selectedTeamID, "team-1")
AssertEqual(stopped.pauseReasons[1].reasonID, "reason-1")
AssertEqual(stopped.pauseReasons == workflow.pauseReasons, false)
AssertEqual(stopped.pauseReasons[1] == workflow.pauseReasons[1], false)

local resumedStatus, resumed = BattleBuddyWorkflowState.Resume(workflow, request)
AssertEqual(resumedStatus, "accepted")
AssertEqual(resumed.generation, 8)
AssertEqual(resumed.requestedState, "running")
AssertEqual(#resumed.pauseReasons, 0)

workflow.pauseReasons[1].contextToken = "changed-after-stop"
AssertEqual(stopped.pauseReasons[1].contextToken, "source-7")

resumedStatus, resumed = BattleBuddyWorkflowState.Resume(stopped, {
    workflowGeneration = 8,
    presentedReasons = {
        { reasonID = "reason-1", contextToken = "source-7" },
    },
    expectedContextTokens = { ["reason-1"] = "source-7" },
    choices = { ["reason-1"] = "retry" },
})
AssertEqual(resumedStatus, "review_required")
AssertEqual(resumed, stopped)

resumedStatus, resumed = BattleBuddyWorkflowState.Resume(workflow, {
    workflowGeneration = 7,
    presentedReasons = request.presentedReasons,
    expectedContextTokens = { ["reason-1"] = "source-7" },
    choices = { ["reason-1"] = "fresh_allowance" },
})
AssertEqual(resumedStatus, "review_required")
AssertEqual(resumed, workflow)

local paused, pauseError = BattleBuddyWorkflowState.Pause(stopped, {
    reasonID = "reason-2",
    code = "LINEUP_CHANGED",
    contextToken = "lineup-8",
})
AssertEqual(pauseError, nil)
AssertEqual(paused.generation, 9)
AssertEqual(paused.requestedState, "paused")
AssertEqual(#paused.pauseReasons, 2)
AssertEqual(paused.pauseReasons[2].reasonID, "reason-2")
AssertEqual(paused.pauseReasons[2].workflowGeneration, 9)

local rejected, rejection = BattleBuddyWorkflowState.Pause(paused, {
    reasonID = "reason-2",
    code = "LINEUP_CHANGED",
    contextToken = "newer-lineup",
})
AssertEqual(rejected, nil)
AssertEqual(rejection, "duplicate_reason")

rejected, rejection = BattleBuddyWorkflowState.Pause(paused, { code = "LOSS_LIMIT" })
AssertEqual(rejected, nil)
AssertEqual(rejection, "invalid_reason")

rejected, rejection = BattleBuddyWorkflowState.Pause(paused, {
    reasonID = "reason-3",
    code = "UNSUPPORTED_REASON",
    contextToken = "unsupported",
})
AssertEqual(rejected, nil)
AssertEqual(rejection, "invalid_reason")
