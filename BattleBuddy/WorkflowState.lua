BattleBuddyWorkflowState = {}

local WorkflowState = BattleBuddyWorkflowState

WorkflowState.PauseReasonCodes = {
    SCRIPT_FAILURE = { "retry" },
    NO_MATCHING_ACTION = { "retry" },
    LEVELING_COMPLETE = { "continue_without_leveling", "select_unfinished_work" },
    LINEUP_CHANGED = { "reload_saved_team", "accept_actual_lineup" },
    RELOAD_RECOVERY = { "resume_recovered_workflow" },
    LOSS_LIMIT = { "fresh_allowance" },
    OWNERSHIP_CHANGED = { "select_owner" },
}

local function CopyValue(value, copies)
    if type(value) ~= "table" then
        return value
    end

    copies = copies or {}
    if copies[value] then
        return copies[value]
    end

    local copy = {}
    copies[value] = copy
    for key, field in pairs(value) do
        copy[CopyValue(key, copies)] = CopyValue(field, copies)
    end

    return copy
end

local function CopyArray(values)
    return CopyValue(values or {})
end

local function IsSupportedChoice(reason, choice)
    for _, supportedChoice in ipairs(WorkflowState.PauseReasonCodes[reason.code] or {}) do
        if choice == supportedChoice then
            return true
        end
    end

    return false
end

local function IndexReasonsByID(reasons, requireFullReason)
    local indexed = {}
    local reasonCount = 0

    for _, reason in ipairs(reasons) do
        reasonCount = reasonCount + 1
        if type(reason) ~= "table"
            or type(reason.reasonID) ~= "string" or reason.reasonID == ""
            or type(reason.contextToken) ~= "string" or reason.contextToken == ""
            or (requireFullReason and (
                type(reason.code) ~= "string" or not WorkflowState.PauseReasonCodes[reason.code]
                or type(reason.workflowGeneration) ~= "number"
            )) then
            return nil
        end

        if indexed[reason.reasonID] then
            return nil
        end

        indexed[reason.reasonID] = reason
    end

    for index in pairs(reasons) do
        if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > reasonCount then
            return nil
        end
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

    if current.requestedState ~= "paused" or request.workflowGeneration ~= current.generation then
        return "review_required", current
    end

    local currentReasons = IndexReasonsByID(current.pauseReasons, true)
    local presentedReasons = IndexReasonsByID(request.presentedReasons, false)

    if not currentReasons or not next(currentReasons) or not presentedReasons
        or type(request.expectedContextTokens) ~= "table"
        or type(request.choices) ~= "table" then
        return "review_required", current
    end

    for reasonID, currentReason in pairs(currentReasons) do
        local presentedReason = presentedReasons[reasonID]
        if not presentedReason
            or presentedReason.contextToken ~= currentReason.contextToken
            or request.expectedContextTokens[reasonID] ~= currentReason.contextToken
            or not IsSupportedChoice(currentReason, request.choices[reasonID]) then
            return "review_required", current
        end
    end

    for reasonID in pairs(presentedReasons) do
        if not currentReasons[reasonID]
            or request.expectedContextTokens[reasonID] == nil
            or request.choices[reasonID] == nil then
            return "review_required", current
        end
    end

    for reasonID in pairs(request.expectedContextTokens) do
        if not currentReasons[reasonID] then
            return "review_required", current
        end
    end

    for reasonID in pairs(request.choices) do
        if not currentReasons[reasonID] then
            return "review_required", current
        end
    end

    return "accepted", current
end

function WorkflowState.Resume(current, request)
    local status = WorkflowState.ReviewResume(current, request)
    if status ~= "accepted" then
        return status, current
    end

    return "accepted", WorkflowState.New({
        generation = current.generation + 1,
        requestedState = "running",
        selectedTeamID = current.selectedTeamID,
        readinessBlockers = current.readinessBlockers,
        healthWarnings = current.healthWarnings,
        recommendedAction = current.recommendedAction,
    })
end

function WorkflowState.Start(current)
    local reasons = IndexReasonsByID(current.pauseReasons, true)
    if not reasons then
        return nil, "invalid_current_reasons"
    end

    if next(reasons) then
        return nil, "review_required"
    end

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

function WorkflowState.Pause(current, reason)
    local reasonCopy = CopyArray({ reason })[1]
    if type(reasonCopy) ~= "table" then
        return nil, "invalid_reason"
    end

    reasonCopy.workflowGeneration = current.generation + 1
    if not IndexReasonsByID({ reasonCopy }, true) then
        return nil, "invalid_reason"
    end

    local reasons = CopyArray(current.pauseReasons)
    local reasonByID = IndexReasonsByID(reasons, true)
    if not reasonByID then
        return nil, "invalid_current_reasons"
    end

    if reasonByID[reasonCopy.reasonID] then
        return nil, "duplicate_reason"
    end

    reasons[#reasons + 1] = reasonCopy

    return WorkflowState.New({
        generation = current.generation + 1,
        requestedState = "paused",
        selectedTeamID = current.selectedTeamID,
        pauseReasons = reasons,
        readinessBlockers = current.readinessBlockers,
        healthWarnings = current.healthWarnings,
        recommendedAction = current.recommendedAction,
    })
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
