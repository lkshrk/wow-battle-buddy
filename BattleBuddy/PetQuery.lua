BattleBuddyPetQuery = {}
local Q = BattleBuddyPetQuery
local stats = { level = true, health = true, power = true, speed = true }
local strong = { 2, 6, 9, 1, 4, 3, 10, 5, 7, 8 }
local tough = { 5, 3, 8, 2, 7, 9, 10, 1, 4, 6 }

local function Comparison(field, text)
    text = text:gsub("%s+", "")
    local low, high = text:match("^=?(%d+)%-(%d+)$")
    if low then
        low, high = tonumber(low), tonumber(high)
        if low <= high then return { field = field, min = low, max = high } end
        return
    end
    local operator, value = text:match("^([<>=]*)(%d+)$")
    if operator ~= "" and operator ~= "=" and operator ~= "<" and operator ~= ">"
        and operator ~= "<=" and operator ~= ">=" then return end
    if value then return { field = field, operator = operator, value = tonumber(value) } end
end

function Q.Parse(text, ranges)
    local query = { valid = true, errors = {}, terms = {}, constraints = {}, active = false }
    text = type(text) == "string" and text:lower() or ""
    text = text:gsub("%s*([<>=]+)%s*", "%1"):gsub("(%d)%s*%-%s*(%d)", "%1-%2")
    for token in text:gmatch("%S+") do
        local field, expression = token:match("^(%a+)([<>=].*)$")
        if stats[field] then
            local constraint = Comparison(field, expression)
            if constraint then query.constraints[#query.constraints + 1] = constraint
            else query.errors.search = true end
        else
            query.terms[#query.terms + 1] = token
        end
        query.active = true
    end
    for _, field in ipairs({ "health", "power", "speed" }) do
        local value = ranges and ranges[field]
        if value ~= nil and value ~= "" and not (type(value) == "string" and value:match("^%s*$")) then
            local constraint = type(value) == "string" and Comparison(field, value)
            if constraint then query.constraints[#query.constraints + 1] = constraint
            else query.errors[field] = true end
            query.active = true
        end
    end
    query.valid = next(query.errors) == nil
    return query
end

local function Public(value, kind, isSecret)
    if isSecret and isSecret(value) then return false end
    return type(value) == kind
end

local function Number(value, isSecret)
    return Public(value, "number", isSecret) and value == value and value > -math.huge and value < math.huge
end

local function Restricted(group)
    local count = 0
    for id = 1, 10 do if group and group[id] then count = count + 1 end end
    return count > 0 and count < 10
end

local function Matches(pet, query, filters, isSecret)
    for _, constraint in ipairs(query.constraints) do
        local value = pet[constraint.field]
        if not Number(value, isSecret) then return false end
        if constraint.min then
            if value < constraint.min or value > constraint.max then return false end
        else
            local operator, target = constraint.operator, constraint.value
            if (operator == "" or operator == "=") and value ~= target
                or operator == ">" and value <= target or operator == "<" and value >= target
                or operator == ">=" and value < target or operator == "<=" and value > target then return false end
        end
    end
    if filters.level25 and (not Number(pet.level, isSecret) or pet.level ~= 25) then return false end
    if filters.rare and (not Number(pet.quality, isSecret) or pet.quality ~= 4) then return false end
    if Restricted(filters.families) and (not Number(pet.petType, isSecret) or not filters.families[pet.petType]) then return false end
    if Restricted(filters.tough) and (not Number(pet.petType, isSecret) or not filters.tough[tough[pet.petType]]) then return false end
    if Restricted(filters.strong) then
        local found = false
        for _, ability in ipairs(pet.abilities or {}) do
            if Number(ability.petType, isSecret) and filters.strong[strong[ability.petType]] then found = true; break end
        end
        if not found then return false end
    end
    if #query.terms > 0 then
        local parts = {}
        local function Add(value)
            if Public(value, "string", isSecret) then parts[#parts + 1] = value:lower() end
        end
        Add(pet.name)
        Add(pet.speciesName)
        for _, ability in ipairs(pet.abilities or {}) do Add(ability.name); Add(ability.description) end
        local haystack = table.concat(parts, "\n")
        for _, term in ipairs(query.terms) do
            if not haystack:find(term, 1, true) then return false end
        end
    end
    return true
end

function Q.Filter(pets, query, filters, isSecret)
    local matches, result = {}, {}
    if not query.valid then return result end
    filters = filters or {}
    for index, pet in ipairs(pets) do
        if Matches(pet, query, filters, isSecret) then
            local name = Public(pet.name, "string", isSecret) and pet.name
                or Public(pet.speciesName, "string", isSecret) and pet.speciesName or ""
            matches[#matches + 1] = { pet = pet, name = name:lower(), index = index }
        end
    end
    table.sort(matches, function(a, b)
        if a.name == b.name then return a.index < b.index end
        return a.name < b.name
    end)
    for index, match in ipairs(matches) do result[index] = match.pet end
    return result
end
