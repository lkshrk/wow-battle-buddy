BattleBuddyWorkflowState = {}

local WorkflowState = BattleBuddyWorkflowState

local function CopyArray(values)
    local copy = {}

    for index, value in ipairs(values or {}) do
        if type(value) == "table" then
            local copiedValue = {}
            for key, field in pairs(value) do
                copiedValue[key] = field
            end
            copy[index] = copiedValue
        else
            copy[index] = value
        end
    end

    return copy
end

local function IndexReasonsByID(reasons)
    local indexed = {}

    for _, reason in ipairs(reasons) do
        if type(reason) ~= "table" or type(reason.reasonID) ~= "string" or reason.reasonID == "" then
            return nil
        end

        if indexed[reason.reasonID] then
            return nil
        end

        indexed[reason.reasonID] = reason
    end

    return indexed
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

function WorkflowState.ReviewResume(current, request)
    request = request or {}

    if request.workflowGeneration ~= current.generation then
        return "review_required", current
    end

    local currentReasons = IndexReasonsByID(current.pauseReasons)
    local presentedReasons = IndexReasonsByID(request.presentedReasons)

    if not currentReasons or not presentedReasons then
        return "review_required", current
    end

    for reasonID, currentReason in pairs(currentReasons) do
        local presentedReason = presentedReasons[reasonID]
        if not presentedReason or presentedReason.contextToken ~= currentReason.contextToken then
            return "review_required", current
        end
    end

    for reasonID in pairs(presentedReasons) do
        if not currentReasons[reasonID] then
            return "review_required", current
        end
    end

    return "accepted", current
end

function WorkflowState.Stop(current)
    return WorkflowState.New({
        generation = current.generation + 1,
        requestedState = "stopped",
        selectedTeamID = current.selectedTeamID,
        pauseReasons = current.pauseReasons,
        readinessBlockers = current.readinessBlockers,
        healthWarnings = current.healthWarnings,
        recommendedAction = current.recommendedAction,
    })
end
