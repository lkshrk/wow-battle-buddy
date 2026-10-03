BattleBuddyEncounterBrowser = {}

local Browser = BattleBuddyEncounterBrowser

local function IsText(value)
    return type(value) == "string" and value ~= ""
end

local function Normalize(value)
    return value:lower()
end

local function Includes(value, query)
    return not IsText(query) or (IsText(value) and Normalize(value):find(Normalize(query), 1, true) ~= nil)
end

local function MatchesFilter(value, filter)
    return not IsText(filter) or value == filter
end

local function CopyRow(encounter)
    local display = type(encounter.display) == "table" and encounter.display or {}
    local label = IsText(encounter.label) and encounter.label or display.fallbackLabel
    if not IsText(encounter.encounterID) or not IsText(label) then
        return nil
    end

    return {
        encounterID = encounter.encounterID,
        label = label,
        expansion = encounter.expansion,
        zone = encounter.zone,
        availability = encounter.availability or "unknown",
        support = encounter.support or "unverified",
    }
end

function Browser.BuildView(input)
    input = type(input) == "table" and input or {}
    local filters = type(input.filters) == "table" and input.filters or {}
    local encounters = input.encounters
    local rows = {}
    local selected = nil
    local inputState = type(encounters) == "table" and "available" or "unavailable"
    local knownEncounterCount = 0

    for _, encounter in ipairs(encounters or {}) do
        local row = CopyRow(encounter)
        if row then
            knownEncounterCount = knownEncounterCount + 1
            if row.encounterID == input.selectedEncounterID then
                selected = row
            end

            local matches = Includes(row.label, filters.query)
                and MatchesFilter(row.expansion, filters.expansion)
                and MatchesFilter(row.zone, filters.zone)
                and MatchesFilter(row.support, filters.support)
                and (filters.availability ~= "available" or row.availability == "available")
            if matches then
                rows[#rows + 1] = row
            end
        end
    end

    local selectedState = "none"
    if IsText(input.selectedEncounterID) then
        selectedState = selected and "selected" or "missing"
        if selected then
            local isVisible = false
            for _, row in ipairs(rows) do
                if row.encounterID == selected.encounterID then
                    isVisible = true
                    break
                end
            end
            if not isVisible then
                selectedState = "hidden"
            end
        end
    end

    local hasFilters = IsText(filters.query) or IsText(filters.expansion) or IsText(filters.zone)
        or IsText(filters.availability) or IsText(filters.support)
    local emptyState
    if inputState == "unavailable" then
        emptyState = "Encounter content is unavailable."
    elseif #rows == 0 then
        emptyState = hasFilters and "No encounters match these filters."
            or (knownEncounterCount == 0 and "No encounter content has been loaded yet."
                or "No encounters are currently available.")
    end

    return {
        rows = rows,
        selectedEncounter = selected,
        selectedState = selectedState,
        hiddenSelection = selectedState == "hidden",
        inputState = inputState,
        knownEncounterCount = knownEncounterCount,
        emptyState = emptyState,
    }
end
