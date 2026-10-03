local sourceRoot = (...or "..")
dofile(sourceRoot .. "/BattleBuddy/Config.lua")
dofile(sourceRoot .. "/BattleBuddy/WorkflowState.lua")

local function AssertEqual(actual, expected)
    if actual ~= expected then
        error(("expected %s, got %s"):format(tostring(expected), tostring(actual)))
    end
end

AssertEqual(BattleBuddyConfig.Policy.LevelingCompletionLevel, 25)

local pauseReasons = {
    { reasonID = "reason-1", code = "SCRIPT_FAILURE", contextToken = "source-7" },
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
})
AssertEqual(status, "review_required")

status = BattleBuddyWorkflowState.ReviewResume(workflow, {
    workflowGeneration = 7,
    presentedReasons = {
        { reasonID = "reason-2", contextToken = "source-7" },
    },
})
AssertEqual(status, "review_required")

status = BattleBuddyWorkflowState.ReviewResume(workflow, {
    workflowGeneration = 7,
    presentedReasons = {
        { reasonID = "reason-1", contextToken = "source-7" },
        { reasonID = "reason-1", contextToken = "source-7" },
    },
})
AssertEqual(status, "review_required")

local malformedWorkflow = BattleBuddyWorkflowState.New({
    generation = 7,
    pauseReasons = { "SCRIPT_FAILURE" },
})
status = BattleBuddyWorkflowState.ReviewResume(malformedWorkflow, request)
AssertEqual(status, "review_required")

local stopped = BattleBuddyWorkflowState.Stop(workflow)
AssertEqual(stopped.generation, 8)
AssertEqual(stopped.requestedState, "stopped")
AssertEqual(stopped.selectedTeamID, "team-1")
AssertEqual(stopped.pauseReasons[1].reasonID, "reason-1")
AssertEqual(stopped.pauseReasons == workflow.pauseReasons, false)
AssertEqual(stopped.pauseReasons[1] == workflow.pauseReasons[1], false)

workflow.pauseReasons[1].contextToken = "changed-after-stop"
AssertEqual(stopped.pauseReasons[1].contextToken, "source-7")
