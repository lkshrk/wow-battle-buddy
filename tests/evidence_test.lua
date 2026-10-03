local sourceRoot = (... or ".")
dofile(sourceRoot .. "/BattleBuddy/Evidence.lua")

local function AssertEqual(actual, expected)
    if actual ~= expected then
        error(("expected %s, got %s"):format(tostring(expected), tostring(actual)))
    end
end

local evidence, errorCode = BattleBuddyEvidence.New({
    domain = "battle",
    subjectID = "session-42",
    revision = 7,
    runtimeGeneration = 3,
    sessionID = "session-42",
    phase = "input",
    opportunityID = "turn-4",
    source = "adapter",
    fields = { activePet = 1 },
})
AssertEqual(errorCode, nil)
AssertEqual(evidence.domain, "battle")
AssertEqual(evidence.subjectID, "session-42")
AssertEqual(evidence.revision, 7)
AssertEqual(evidence.runtimeGeneration, 3)
AssertEqual(evidence.fields.activePet, 1)
evidence.fields.activePet = 2
AssertEqual(evidence.fields.activePet, 2)

local sourceFields = { activePet = 1, nested = { ability = 2 } }
evidence, errorCode = BattleBuddyEvidence.New({
    domain = "battle",
    subjectID = "session-42",
    revision = 8,
    runtimeGeneration = 3,
    fields = sourceFields,
})
AssertEqual(errorCode, nil)
sourceFields.nested.ability = 3
AssertEqual(evidence.fields.nested.ability, 2)

local invalid, invalidCode = BattleBuddyEvidence.New({
    subjectID = "session-42",
    revision = 0,
    runtimeGeneration = 0,
})
AssertEqual(invalid, nil)
AssertEqual(invalidCode, "invalid_domain")

invalid, invalidCode = BattleBuddyEvidence.New({
    domain = "battle",
    subjectId = "",
    revision = 0,
    runtimeGeneration = 0,
})
AssertEqual(invalid, nil)
AssertEqual(invalidCode, "invalid_subject_id")

invalid, invalidCode = BattleBuddyEvidence.New({
    domain = "battle",
    subjectID = "session-42",
    revision = -1,
    runtimeGeneration = 0,
})
AssertEqual(invalid, nil)
AssertEqual(invalidCode, "invalid_revision")

invalid, invalidCode = BattleBuddyEvidence.New({
    domain = "battle",
    subjectID = "session-42",
    revision = 0,
    runtimeGeneration = 1.5,
})
AssertEqual(invalid, nil)
AssertEqual(invalidCode, "invalid_runtime_generation")

invalid, invalidCode = BattleBuddyEvidence.New({
    domain = "battle",
    subjectID = "session-42",
    revision = 0,
    runtimeGeneration = 0,
    sessionID = "",
})
AssertEqual(invalid, nil)
AssertEqual(invalidCode, "invalid_session_id")
