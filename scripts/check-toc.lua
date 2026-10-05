local root = arg[1] or "BattleBuddy"
local toc = root .. "/BattleBuddy.toc"
local handle = assert(io.open(toc, "r"))
local failures, interface = 0, nil

local function listed(dir)
    local names = {}
    local pipe = assert(io.popen('ls -1 "' .. dir .. '"'))
    for name in pipe:lines() do names[name] = true end
    pipe:close()
    return names
end

local function exists(path)
    local dir, name = root, path
    for part in path:gmatch("[^/\\]+") do name = part end
    local parent = path:match("^(.*)[/\\][^/\\]+$")
    if parent then dir = root .. "/" .. parent:gsub("\\", "/") end
    local ok, names = pcall(listed, dir)
    return ok and names[name] == true
end

for line in handle:lines() do
    line = line:gsub("\r$", "")
    local value = line:match("^## Interface:%s*(.-)%s*$")
    if value then interface = value end
    if line ~= "" and not line:match("^#") then
        if not exists(line) then
            io.stderr:write(("%s: listed file missing or wrong case: %s\n"):format(toc, line))
            failures = failures + 1
        end
    end
end
handle:close()

if not interface or not interface:match("^%d+") then
    io.stderr:write(toc .. ": no ## Interface line\n")
    failures = failures + 1
end
if failures > 0 then os.exit(1) end
print(("%s ok (Interface %s)"):format(toc, interface))
