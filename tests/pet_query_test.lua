local root = (... or ".")
dofile(root .. "/BattleBuddy/PetQuery.lua")
local Q = BattleBuddyPetQuery
local pets = {
    { name = "Zebra", speciesName = "Striped Beast", level = 25, health = 1400, power = 300, speed = 275,
        quality = 4, petType = 8, owned = true, abilities = {{ name = "Bite", description = "Deals piercing damage", petType = 8 }} },
    { name = "Alpha", level = 12, health = 800, power = 200, speed = 300, quality = 3, petType = 3,
        abilities = {{ name = "Gust", description = "A chilling wind", petType = 3 }} },
    { name = "ALPHA", level = 25, health = 1000, power = 250, speed = 200, quality = 4, petType = 9,
        abilities = {{ name = "Wave", description = "Water damage", petType = 9 }} },
    { name = "Unknown", owned = false, petType = 1 },
}
local function Count(text, ranges, filters, expected)
    local query = Q.Parse(text, ranges)
    assert(query.valid, text)
    local results = Q.Filter(pets, query, filters)
    assert(#results == expected, text .. ": " .. #results .. " ~= " .. expected)
    return results
end
local all = Count("", nil, nil, 4)
assert(all[1] == pets[2] and all[2] == pets[3] and all[4] == pets[1])
assert(pets[1].name == "Zebra")
Count("zEbRa", nil, nil, 1)
Count("striped", nil, nil, 1)
Count("bite", nil, nil, 1)
Count("PIERCING damage", nil, nil, 1)
Count("wind", nil, nil, 1)
Count("nothing", nil, nil, 0)
Count("level=25", nil, nil, 2)
Count("health>1000", nil, nil, 1)
Count("power<250", nil, nil, 1)
Count("speed>=275", nil, nil, 2)
Count("speed<=275", nil, nil, 2)
Count("level=12-25", nil, nil, 3)
Count("level = 25 health >= 1000 power = 250 - 300", nil, nil, 2)
Count("alpha level=25", nil, nil, 1)
for _, field in ipairs({ "health", "power", "speed" }) do
    local value = pets[1][field]
    for _, expression in ipairs({ tostring(value), "=" .. value, ">=" .. value, "<=" .. value,
        ">" .. (value - 1), "<" .. (value + 1), (value - 1) .. " - " .. (value + 1) }) do
        local result = Q.Filter({ pets[1] }, Q.Parse("", {[field] = expression}))
        assert(#result == 1, field .. expression)
    end
end
for _, value in ipairs({ "abc", "=", ">=", "20-10", "1.5", "-1", "1e3", "==25", "25x", ">20-30", "1--2" }) do
    assert(not Q.Parse("", { health = value }).valid, value)
    local query = Q.Parse("health=" .. value)
    assert(not query.valid and #Q.Filter(pets, query) == 0, value)
end
assert(Q.Parse("", { health = "bad" }).errors.health)
assert(Q.Parse("level=bad").errors.search)
Count("", { health = "" }, nil, 4)
Count("", nil, { families = {[8] = true} }, 1)
Count("", nil, { strong = {[5] = true} }, 1)
Count("", nil, { tough = {[1] = true} }, 1)
Count("", nil, { families = {[8] = true}, strong = {[9] = true} }, 0)
Count("", nil, { level25 = true }, 2)
Count("", nil, { rare = true }, 2)
Count("", nil, { level25 = true, rare = true }, 2)
local mixed = {
    {level = 25, quality = 3}, {level = 12, quality = 4}, {level = 25, quality = 4},
}
assert(#Q.Filter(mixed, Q.Parse(""), {level25 = true}) == 2)
assert(#Q.Filter(mixed, Q.Parse(""), {rare = true}) == 2)
assert(#Q.Filter(mixed, Q.Parse(""), {level25 = true, rare = true}) == 1)
local unusual = {{petType = 6, abilities = {{petType = 8}}}}
assert(#Q.Filter(unusual, Q.Parse(""), {strong = {[5] = true}}) == 1)
assert(#Q.Filter(unusual, Q.Parse(""), {strong = {[3] = true}}) == 0)
assert(#Q.Filter(unusual, Q.Parse(""), {tough = {[9] = true}}) == 1)
assert(#Q.Filter(unusual, Q.Parse(""), {tough = {[1] = true}}) == 0)
Count("damage", { power = ">=250" }, { families = {[8] = true}, level25 = true, rare = true }, 1)
local everything = {}
for id = 1, 10 do everything[id] = true end
Count("", nil, { strong = everything, tough = everything, families = everything }, 4)
local sentinel = setmetatable({}, { __lt = function() error("secret compared") end, __eq = function() error("secret compared") end })
for _, value in ipairs({ sentinel, "25", false, math.huge, 0/0 }) do
    assert(#Q.Filter({{level = value}}, Q.Parse("level>=1")) == 0)
end
assert(#Q.Filter({{level = 25}}, Q.Parse("level=25"), nil, function(value) return value == 25 end) == 0)
assert(#Q.Filter({{level = sentinel}}, Q.Parse(""), {level25 = true}) == 0)
assert(#Q.Filter({{quality = sentinel}}, Q.Parse(""), {rare = true}) == 0)
print("pet_query_test: ok")
