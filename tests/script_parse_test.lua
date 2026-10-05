local root = (... or ".")
issecretvalue = function(value) return type(value) == "table" and value.secret == true end
canaccessvalue = function() return true end
dofile(root .. "/BattleBuddy/Compatibility.lua")
dofile(root .. "/BattleBuddy/Script/Parser.lua")
local S = BattleBuddyScript
local function parse(text)
    local script, errors = S.Parse(text)
    assert(script, errors and errors[1] and errors[1].message)
    return script
end
local script = parse("-- comment [ignored]\r\n\n/if [self.hp < 500 & !enemy.dead]\n use(Bite:110)\n if [round~1, 3]\n change(next)\n ei\nendif\nstandby")
assert(#script.lines == 3)
assert(script.lines[2].line == 3)
assert(script.lines[2].conditions[1].owner == "ally")
assert(script.lines[2].children[1].action.arg == 110)
assert(script.lines[2].children[2].conditions[1].value[3])
for _, action in ipairs({ "test(hello)", "change(#2)", "ability(#1)", "use(110)", "quit", "standby", "catch", "-- comment" }) do parse(action) end
local fixtures = {
    "dead", "hp=3", "hp.full", "hp.can_be_exploded", "hp.can_explode", "hp.low", "hp.high",
    "hpp>30", "hp.diff>=0", "hpp.diff<=0", "aura(123).exists", "aura(123).duration=1",
    "active", "ability(#1).usable", "ability(#1).duration=0", "ability(#1).strong", "ability(#1).weak",
    "ability(#1).type=beast", "round=2", "played", "speed=100", "power=100", "level=25",
    "level.max", "speed.fast", "speed.slow", "type!~humanoid,dragonkin", "quality>=rare", "exists",
    "is(Pet:123)", "id==123", "collected", "collected.count!=2", "collected.max=3",
}
for _, condition in ipairs(fixtures) do parse("quit [ally." .. condition .. "]") end
for _, condition in ipairs({ "weather(123)", "weather(123).exists", "weather(123).duration>0", "round=1", "trap" }) do parse("catch [" .. condition .. "]") end
assert(parse("quit [enemy(Pet:123).type=Beast:8]").lines[1].conditions[1].pet == 123)
for _, bad in ipairs({ "bogus", "use()", "quit [hp=3]", "quit [ally.trap]", "quit [ally(#1).speed.fast]", "quit [ally.hp(1)=2]", "quit [ally.hp]", "quit [ally.dead=1]", "quit [!ally.hp=1]", "quit [ally.id>1]", "quit [ally.type=unknown]", "quit [ally.hp=x]", "quit []", "endif", "if\nquit", "quit [ally.hp=>1]" }) do
    local result, errors = S.Parse("\n" .. bad)
    assert(not result and errors[1].line == 2, bad)
end
assert(not S.Parse({}))
local list, columns = S.Snippets("sta")
assert(columns == 1 and list[1].value == "ndby")
list = S.Snippets("use [ally.hp.")
assert(#list >= 4)
list = S.Snippets("use [!ally.hp.")
for _, item in ipairs(list) do assert(item.value ~= "diff") end
local snapshot = { ally = { active = 1, pets = { { name = "Cat", speciesID = 1, icon = 7, abilities = { { id = 110, name = "Bite", icon = 9 } } } } } }
list, columns = S.Snippets("use", snapshot)
assert(columns == 3 and list[2].value == "(Bite:110)" and list[3].value == "(#1)")
list, columns = S.Snippets("use [ally", snapshot)
assert(columns == 3 and list[2].value == "(Cat:1)")
list, columns = S.Snippets("change", snapshot)
assert(columns == 3 and list[5].value == "(next)")
snapshot.ally.pets[1].auras = { { id = 7, name = "Buff", duration = 3 } }
snapshot.ally.auras = { { id = 8, name = "Pad", duration = 2 } }
list, columns = S.Snippets("use [ally.aura", snapshot)
assert(columns == 2 and list[2].value == "(Buff:7)" and list[4].value == "(Pad:8)")
snapshot.weathers = { { id = 171, name = "Burnt Earth" } }
list, columns = S.Snippets("use [weather", snapshot)
assert(columns == 2 and list[2].value == "(Burnt Earth:171)")
snapshot.ally.pets[1].abilities[1].name = { secret = true }
list = S.Snippets("use", snapshot)
assert(not list)
print("script_parse_test: ok")
