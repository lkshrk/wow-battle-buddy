local root = (... or ".")
local corpus = dofile(root .. "/tests/fixtures/exchange_manifest.lua")
local function Assert(value, message) if not value then error(message) end end
local outcomes = { faithful = true, reduced = true, blocked = true }
local origins = { synthetic = true, ["user-authored"] = true, ["sanitized-reference-produced"] = true, unknown = true }
local levels, IDs = {}, {}
for _, level in ipairs(corpus.evidenceLevels) do levels[level] = true end
Assert(corpus.schemaVersion == 1, "manifest schema version is required")
for _, fixture in ipairs(corpus.fixtures) do
  Assert(type(fixture.id) == "string" and not IDs[fixture.id], "fixture IDs must be unique")
  IDs[fixture.id] = true
  for _, field in ipairs({ "family", "targetVersion", "direction", "provenance", "inputDigest", "expectedDetection", "expectedCanonicalMeaning", "expectedPreservation", "status" }) do
    Assert(type(fixture[field]) == "string" and fixture[field] ~= "", fixture.id .. " requires " .. field)
  end
  Assert(origins[fixture.origin], fixture.id .. " has invalid origin")
  Assert(type(fixture.expectedComponents) == "table", fixture.id .. " requires components")
  Assert(outcomes[fixture.expectedOutcome], fixture.id .. " requires an outcome")
  Assert(type(fixture.expectedDiagnostics) == "table", fixture.id .. " requires diagnostics")
  for _, level in ipairs(fixture.evidence) do Assert(levels[level], fixture.id .. " has unknown evidence") end
end
for _, id in ipairs({ "RM-CORE-001", "RM-SPECIAL-002", "PBS-BOUNDARIES-001", "EMBED-001" }) do Assert(IDs[id], "missing " .. id) end
Assert(#corpus.exclusions == 3, "excluded exchange forms must be explicit")
