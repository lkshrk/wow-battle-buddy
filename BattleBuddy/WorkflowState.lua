BattleBuddyWorkflowState = {}

local WorkflowState = BattleBuddyWorkflowState

local function CopyArray(values)
    local copy = {}

    for index, value in ipairs(values or {}) do
        copy[index] = value
    end

    return copy
end

function WorkflowState.New(options)
    options = options or {}

    return {
        generation = options.generation or 0,
        requestedState = options.requestedState or "stopped",
        selectedTeamID = options.selectedTeamID,
        pauseReasons = CopyArray(options.pauseReasons),
        readinessBlockers = CopyArray(options.readinessBlockers),
        healthWarnings = CopyArray(options.healthWarnings),
        recommendedAction = options.recommendedAction,
    }
end

function WorkflowState.Continue(current)
    return WorkflowState.New({
        generation = current.generation + 1,
        requestedState = "running",
        selectedTeamID = current.selectedTeamID,
        pauseReasons = current.pauseReasons,
        readinessBlockers = current.readinessBlockers,
        healthWarnings = current.healthWarnings,
        recommendedAction = current.recommendedAction,
    })
end
