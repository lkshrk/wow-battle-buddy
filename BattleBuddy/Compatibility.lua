BattleBuddyCompatibility = {}

local Compatibility = BattleBuddyCompatibility

function Compatibility.ClassifyValue(value)
    if issecretvalue(value) then
        return nil, "secret"
    end

    if not canaccessvalue(value) then
        return nil, "restricted"
    end

    if value == nil then
        return nil, "unavailable"
    end

    return value, "usable"
end
