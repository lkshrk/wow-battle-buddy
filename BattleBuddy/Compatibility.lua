BattleBuddyCompatibility = {}

local Compatibility = BattleBuddyCompatibility

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
