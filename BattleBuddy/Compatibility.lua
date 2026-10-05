BattleBuddyCompatibility = {}

local Compatibility = BattleBuddyCompatibility

function Compatibility.PublicValue(value, expectedType)
    local ok, public = pcall(Compatibility.ClassifyValue, value)
    if ok and type(public) == expectedType then return public end
end

function Compatibility.ClassifyValue(value, inspectors)
    inspectors = inspectors or {}
    local isSecret = inspectors.isSecret or issecretvalue
    local canAccess = inspectors.canAccess or canaccessvalue

    if isSecret(value) then
        return nil, "secret"
    end

    if not canAccess(value) then
        return nil, "restricted"
    end

    if value == nil then
        return nil, "unavailable"
    end

    return value, "usable"
end

function Compatibility.PublicValue(value, inspectors)
    local ok, result, state = pcall(Compatibility.ClassifyValue, value, inspectors)
    if ok then return result, state end
    return nil, "unavailable"
end

function Compatibility.ReadField(container, key, inspectors)
    container = Compatibility.PublicValue(container, inspectors)
    key = Compatibility.PublicValue(key, inspectors)
    if type(container) ~= "table" or key == nil then return nil, "unavailable" end
    local ok, value = pcall(function() return container[key] end)
    if not ok then return nil, "unavailable" end
    return Compatibility.PublicValue(value, inspectors)
end
