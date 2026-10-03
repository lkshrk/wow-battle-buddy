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
    input = input or {}
    local filters = type(input.filters) == "table" and input.filters or {}
    local rows = {}
    local selected = nil

    for _, encounter in ipairs(input.encounters or {}) do
        local row = CopyRow(encounter)
        if row then
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

    return {
        rows = rows,
        selectedEncounter = selected,
        selectedState = selectedState,
        hiddenSelection = selectedState == "hidden",
        emptyState = #rows == 0 and "No encounters match these filters." or nil,
    }
end
