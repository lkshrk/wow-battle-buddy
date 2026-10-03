local sourceRoot = (...or "..")
dofile(sourceRoot .. "/BattleBuddy/Config.lua")
dofile(sourceRoot .. "/BattleBuddy/WorkflowState.lua")

local function AssertEqual(actual, expected)
    if actual ~= expected then
        error(("expected %s, got %s"):format(tostring(expected), tostring(actual)))
    end
end

AssertEqual(BattleBuddyConfig.Policy.LevelingCompletionLevel, 25)

local pauseReasons = { "SCRIPT_FAILURE" }
local workflow = BattleBuddyWorkflowState.New({
    generation = 7,
    requestedState = "paused",
    selectedTeamID = "team-1",
    pauseReasons = pauseReasons,
})

pauseReasons[1] = "CHANGED"
AssertEqual(workflow.generation, 7)
AssertEqual(workflow.requestedState, "paused")
AssertEqual(workflow.selectedTeamID, "team-1")
AssertEqual(workflow.pauseReasons[1], "SCRIPT_FAILURE")
AssertEqual(#workflow.readinessBlockers, 0)
AssertEqual(#workflow.healthWarnings, 0)

local continued = BattleBuddyWorkflowState.Continue(workflow)
AssertEqual(continued.generation, 8)
AssertEqual(continued.requestedState, "running")
AssertEqual(continued.pauseReasons[1], "SCRIPT_FAILURE")
AssertEqual(continued.pauseReasons == workflow.pauseReasons, false)
