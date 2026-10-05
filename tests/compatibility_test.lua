local sourceRoot = (... or ".")

issecretvalue = function()
    error("test must inject the secret inspector")
end
canaccessvalue = function()
    error("test must inject the access inspector")
end
dofile(sourceRoot .. "/BattleBuddy/Compatibility.lua")

local function AssertEqual(actual, expected)
    if actual ~= expected then
        error(("expected %s, got %s"):format(tostring(expected), tostring(actual)))
    end
end

local function Classify(value, secret, accessible)
    return BattleBuddyCompatibility.ClassifyValue(value, {
        isSecret = function() return secret end,
        canAccess = function() return accessible end,
    })
end

local value, state = Classify("secret text", true, true)
AssertEqual(value, nil)
AssertEqual(state, "secret")

value, state = Classify("restricted text", false, false)
AssertEqual(value, nil)
AssertEqual(state, "restricted")

value, state = Classify(nil, false, true)
AssertEqual(value, nil)
AssertEqual(state, "unavailable")

value, state = Classify(0, false, true)
AssertEqual(value, 0)
AssertEqual(state, "usable")

issecretvalue = function(candidate) return candidate == "secret" end
canaccessvalue = function(candidate) return candidate ~= "restricted" end
AssertEqual(BattleBuddyCompatibility.PublicValueOfType("secret", "string"), nil)
AssertEqual(BattleBuddyCompatibility.PublicValueOfType("restricted", "string"), nil)
AssertEqual(BattleBuddyCompatibility.PublicValueOfType({}, "string"), nil)
AssertEqual(BattleBuddyCompatibility.PublicValueOfType("public", "string"), "public")
issecretvalue = nil
AssertEqual(BattleBuddyCompatibility.PublicValueOfType("public", "string"), nil)

value, state = Classify(false, false, true)
AssertEqual(value, false)
AssertEqual(state, "usable")
