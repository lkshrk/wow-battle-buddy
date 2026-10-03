BattleBuddyEvidence = {}

local Evidence = BattleBuddyEvidence

local function IsNonEmptyString(value)
    return type(value) == "string" and value ~= ""
end

local function IsNonNegativeInteger(value)
    return type(value) == "number" and value >= 0 and value % 1 == 0
end

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
    for key, nestedValue in pairs(value) do
        copy[CopyValue(key, copies)] = CopyValue(nestedValue, copies)
    end
    return copy
end

function Evidence.New(options)
    options = options or {}

    if not IsNonEmptyString(options.domain) then
        return nil, "invalid_domain"
    end

    if not IsNonEmptyString(options.subjectID) then
        return nil, "invalid_subject_id"
    end

    if not IsNonNegativeInteger(options.revision) then
        return nil, "invalid_revision"
    end

    if not IsNonNegativeInteger(options.runtimeGeneration) then
        return nil, "invalid_runtime_generation"
    end

    if options.sessionID ~= nil and not IsNonEmptyString(options.sessionID) then
        return nil, "invalid_session_id"
    end

    return {
        domain = options.domain,
        subjectID = options.subjectID,
        revision = options.revision,
        runtimeGeneration = options.runtimeGeneration,
        sessionID = options.sessionID,
        phase = options.phase,
        opportunityID = options.opportunityID,
        source = options.source,
        diagnostics = CopyValue(options.diagnostics),
        fields = CopyValue(options.fields),
    }
end
