local root = (... or ".")
dofile(root .. "/BattleBuddy/Script/Share.lua")
local S = BattleBuddyScript
local code = "use(123) [enemy.hp < 50]\nchange(#2)\nstandby()"
local metadata = { name = "A ^ ~ team", plugin = "Rematch", key = "123",
    extra = { 7, true, false, "\030\127", 1 / 3, math.huge, -math.huge } }

local libraries, handlers = {}, {}
LibStub = setmetatable({ NewLibrary = function(_, name)
    libraries[name] = {}
    return libraries[name]
end }, { __call = function(_, name) return assert(libraries[name]) end })
local function xor(a, b)
    a, b = a % 4294967296, b % 4294967296
    local result, place = 0, 1
    for _ = 1, 32 do
        if a % 2 ~= b % 2 then result = result + place end
        a, b, place = math.floor(a / 2), math.floor(b / 2), place * 2
    end
    return result
end
bit = { bxor = xor, band = function(a, b) return (a + b - xor(a, b)) / 2 end,
    rshift = function(a, b) return math.floor(a / 2 ^ b) end }
local ns = { Addon = { NewShareHandler = function(_, version)
    handlers[version] = {}
    return handlers[version]
end }, Director = { BuildScript = function() return true end }, L = {} }
string.trim = function(s) return s:match("^%s*(.-)%s*$") end
for _, file in ipairs({ "Libs/AceSerializer-3.0/AceSerializer-3.0.lua",
    "Libs/LibBase64-1.0/LibBase64-1.0.lua", "Libs/LibCRC32-1.0/CRC32-1.0.lua",
    "Share/Version0.lua", "Share/Version1.lua", "Share/Version2.lua" }) do
    assert(loadfile(root .. "/third_party/pbs/" .. file))("PBS", ns)
end
local plugin = { GetPluginName = function() return metadata.plugin end,
    OnExport = function() return metadata.extra end }
local script = { GetDB = function() return { code = code, name = metadata.name } end,
    GetName = function() return metadata.name end, GetCode = function() return code end,
    GetKey = function() return metadata.key end, GetPlugin = function() return plugin end }

for version = 0, 2 do
    metadata.version = version
    local exported = S.Export(code, metadata)
    assert(S.Import(exported) == code, "round trip version " .. version)
    local ok, imported = handlers[version]:Import(exported)
    assert(ok and imported.db.code == code, "PBS must import version " .. version)
    if version > 0 then
        assert(imported.plugin == metadata.plugin and imported.key == metadata.key)
        for i, value in ipairs(metadata.extra) do assert(imported.extra[i] == value, "metadata interchange") end
    end
    local upstream = version == 0 and code or handlers[version]:Export(script)
    assert(S.Import(upstream) == code, "must import PBS version " .. version)
end
assert(S.Export(code):find("# Version: 2", 1, true))
local legacy = handlers[1]:Export(script):gsub("# Version: 1\n", "")
assert(S.Import(legacy) == code, "legacy versionless v1")
for _, bad in ipairs({ "", " ", "# Version: 9\n# Code Start\nstandby()\n# Code End",
    "# Version: 1\n# (Script) : #\n# !!!", "# Version: 1\n# (Script) : #\n# MTIzXjFeVF50Xl4=",
    "# Version: 2\n# Code Start\nstandby()", "# Version: 2\n# Code Start\n# Code End",
    "# Version: 2\n# Data: !!!\n# Code Start\nstandby()\n# Code End" }) do
    local ok, value, err = pcall(S.Import, bad)
    assert(ok and value == nil and type(err) == "string", "bad share must fail cleanly: " .. bad)
end
for _, bad in ipairs({ false, 42, {} }) do
    local ok, value, err = pcall(S.Import, bad)
    assert(ok and value == nil and err)
end
assert(S.Import(nil) == nil)
local payload = handlers[1]:RawExport(script)
local crc, serialized = payload:match("^(%d+)(^.+)$")
local tampered = "# Version: 1\n# (Script) : #\n# "
    .. libraries["LibBase64-1.0"].Encode(crc .. serialized:gsub("use", "bad", 1))
local value, err = S.Import(tampered)
assert(value == nil and err:find("CRC32 error", 1, true), "payload tampering must fail checksum")
assert(S.Import(S.Export(code, { version = 1 })) == code, "bad import must not poison decoder")
assert(S.Import("# Version: 2\n# Code Start\nstandby()\n# Code End") == "standby()")
local binary = "# ^ ~ \030\127\t\nuse(123)\n# Grüße"
assert(S.Import(S.Export(binary, { version = 1 })) == binary)
S.Parse = function(text) if text == "invalid" then return nil, { "bad syntax" } end return {} end
assert(S.Import("invalid") == nil)
print("script_share_test: ok")
