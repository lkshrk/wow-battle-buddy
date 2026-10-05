BattleBuddyTeamStrings = {}

local X = BattleBuddyTeamStrings
local alphabet = "0123456789ABCDEFGHIJKLMNOPQRSTUV"
local preferenceKeys = { "minHP", "allowMM", "expectedDD", "maxHP", "minXP", "maxXP" }
local sorts = { "alpha", "wins", "custom" }
local beginScript = "-----BEGIN PET BATTLE SCRIPT-----"
local endScript = "-----END PET BATTLE SCRIPT-----"
local originals = setmetatable({}, { __mode = "k" })
local previews = setmetatable({}, { __mode = "k" })

local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = Copy(item) end
    return result
end

local function Equal(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for key, value in pairs(a) do if not Equal(value, b[key]) then return false end end
    for key in pairs(b) do if a[key] == nil then return false end end
    return true
end

local function Safe(fn, ...)
    local ok, result = pcall(fn, ...)
    if ok then return result end
    return nil, tostring(result)
end

local function Trim(text) return text:match("^%s*(.-)%s*$") end

local function Split(text, separator)
    local parts, start = {}, 1
    while true do
        local finish = text:find(separator, start, true)
        parts[#parts + 1] = text:sub(start, finish and finish - 1)
        if not finish then return parts end
        start = finish + #separator
    end
end

local function Number(text, base)
    assert(text ~= "" and not text:find(base == 32 and "[^0-9A-Va-v]" or "[^%d.]"), "Invalid number")
    local value = tonumber(text, base)
    assert(value and value >= 0 and value < 2 ^ 53, "Number out of range")
    return value
end

local function Base32(value)
    assert(type(value) == "number" and value >= 0 and value < 2 ^ 53 and value % 1 == 0, "Invalid base32 value")
    local result = ""
    repeat
        local digit = value % 32 + 1
        result, value = alphabet:sub(digit, digit) .. result, math.floor(value / 32)
    until value == 0
    return result
end

local function ReadPreferences(text)
    local fields = Split(text, ":")
    assert(#fields == 7 and fields[7] == "", "Truncated preferences")
    local result = {}
    for index, key in ipairs(preferenceKeys) do
        if fields[index] ~= "" then
            local value = Number(fields[index], 10)
            if key == "allowMM" then
                assert(value == 0 or value == 1, "Invalid allowMM")
                value = value == 1
            end
            result[key] = value
        end
    end
    return result
end

local function WritePreferences(value)
    if not value or not next(value) then return "" end
    local fields = {}
    for index, key in ipairs(preferenceKeys) do
        local item = value[key]
        if key == "allowMM" and item ~= nil then item = item and 1 or 0 end
        fields[index] = item == nil and "" or tostring(item)
        if item ~= nil then Number(fields[index], 10) end
    end
    return "P:" .. table.concat(fields, ":") .. ":"
end

local function PetTag(text)
    if text == "" or text == "ZU" then return "empty", {} end
    if text == "ZL" then return 0, {} end
    if text == "ZI" then return "ignored", {} end
    if text:match("^ZR[0-9A]$") then return "random:" .. Number(text:sub(3), 32), {} end
    if text:match("^ZN[0-9A-V]+$") then
        Number(text:sub(3), 32)
        return "empty", {}
    end
    local level, rarity, queueBreed, queueSpecies = text:match("^Q([0-9A-P])([0-4])([0-9A-C])([0-9A-V]+)$")
    if queueSpecies then
        local species, tag = PetTag("000" .. queueBreed .. queueSpecies)
        return species, tag, { minLevel = Number(level, 32), minRarity = Number(rarity, 32), maxLevel = 24 }
    end
    local a, b, c, breed, species = text:match("^([012])([012])([012])([0-9A-Ca-c])([0-9A-Va-v]+)$")
    assert(species, "Invalid or unsupported pet descriptor")
    species, breed = Number(species, 32), Number(breed, 32)
    assert(species > 0 and (breed == 0 or breed >= 3), "Invalid species or breed")
    return species, { speciesID = species, breedID = breed, abilities = { tonumber(a), tonumber(b), tonumber(c) } }
end

local function ValidateScript(code)
    assert(BattleBuddyScript and BattleBuddyScript.Parse, "Script parser unavailable")
    assert(BattleBuddyScript.Parse(code), "Invalid script syntax")
    return code
end

local function ExtractScript(notes)
    local first, finish = notes:find(beginScript, 1, true)
    local last, ending = notes:find(endScript, 1, true)
    if not first and not last then return notes end
    assert(first and last and last > finish and notes:sub(finish + 1, finish + 1) == "\n", "Truncated script block")
    assert(not notes:find(beginScript, finish + 1, true) and not notes:find(endScript, ending + 1, true), "Multiple script blocks")
    local code = notes:sub(finish + 2, last - 1):gsub("\n$", "")
    ValidateScript(code)
    local before, after = notes:sub(1, first - 1):gsub("\n$", ""), notes:sub(ending + 1):gsub("^\n", "")
    return before .. (before ~= "" and after ~= "" and "\n" or "") .. after, code
end

local function ReadTeam(line)
    local name, targets, a, b, c, tail
    local position = 0
    for _ = 1, 256 do
        position = line:find(":", position + 1, true)
        if not position then break end
        local ids, first, second, third, rest = line:sub(position + 1):match("^([0-9A-Va-v,]*):([^:]*):([^:]*):([^:]*):(.*)$")
        if ids and (rest == "" or rest:sub(1, 2) == "P:" or rest:sub(1, 2) == "N:")
            and pcall(PetTag, first) and pcall(PetTag, second) and pcall(PetTag, third) then
            name, targets, a, b, c, tail = line:sub(1, position - 1), ids, first, second, third, rest
            break
        end
    end
    assert(name and Trim(name) ~= "", "Invalid or truncated team")
    local team = { name = Trim(name), pets = {}, tags = {} }
    local descriptors = { a, b, c }
    for index, tag in ipairs(descriptors) do team.pets[index], team.tags[index] = PetTag(tag) end
    if targets ~= "" then
        team.targets = {}
        for _, target in ipairs(Split(targets, ",")) do
            local id = Number(target, 32)
            assert(id > 0, "Invalid target")
            team.targets[#team.targets + 1] = id
        end
    end
    if tail:sub(1, 2) == "P:" then
        local fields = Split(tail:sub(3), ":")
        assert(#fields >= 7, "Truncated preferences")
        local prefs = {}
        for index = 1, 6 do prefs[index] = fields[index] end
        local prefix = "P:" .. table.concat(prefs, ":") .. ":"
        team.preferences = ReadPreferences(prefix:sub(3))
        tail = tail:sub(#prefix + 1)
    end
    if tail:sub(1, 2) == "N:" then
        team.notes, team.script = ExtractScript((tail:sub(3):gsub("\\n", "\n")))
        if team.notes == "" then team.notes = nil end
    else
        assert(tail == "", "Unsupported team section or version")
    end
    return team, descriptors
end

local function ReadGroup(line)
    local body = assert(line:match("^__ (.*) __$"), "Invalid group header")
    local fields = Split(body, ":")
    local group, version = { teams = {}, sortMode = "alpha" }, "legacy"
    if #fields == 1 or (#fields < 4 and body:sub(-1) ~= ":") then group.name = Trim(body)
    else
        local name, sort, icon, color, rest = body:match("^(.-):([123]?):([0-9A-Va-v]*):(%x*):(.*)$")
        assert(name, "Unsupported group header or sort mode")
        group.name, group.sortMode = Trim(name), sorts[tonumber(sort) or 1]
        if icon ~= "" then group.icon = Number(icon, 32) end
        if color ~= "" then assert(#color == 6, "Invalid group color"); group.color = color end
        version = "legacy-fields"
        if rest:sub(1, 2) == "1:" or rest:sub(1, 1) == ":" then
            local show, remainder = rest:match("^([^:]*):(.*)$")
            group.showTab, rest, version = show == "1", remainder, "current"
        end
        if rest ~= "" then
            assert(rest:sub(1, 2) == "P:", "Unsupported group section")
            group.preferences = ReadPreferences(rest:sub(3))
        end
    end
    assert(group.name ~= "", "Empty group name")
    return group, version
end

local function ShareMetadata(text, version)
    local encoded
    if version == 2 then encoded = text:match("# Data: (%S+)")
    else encoded = text:match("%(Script%) : (.+)"); encoded = encoded and encoded:gsub("[#%s]", "") end
    assert(encoded, "Missing team metadata")
    local digits = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local bytes, accumulator, bits = {}, 0, 0
    for char in encoded:gmatch(".") do
        if char ~= "=" then
            local value = assert(digits:find(char, 1, true), "Invalid metadata encoding") - 1
            accumulator, bits = accumulator * 64 + value, bits + 6
            if bits >= 8 then
                bits = bits - 8
                bytes[#bytes + 1] = string.char(math.floor(accumulator / 2 ^ bits))
                accumulator = accumulator % 2 ^ bits
            end
        end
    end
    local data = table.concat(bytes)
    if version == 1 then data = assert(data:match("^%d+(%^.*)$"), "Missing metadata checksum") end
    data = data:gsub("[%c ]", "")
    local position, count = 1, 0
    local function Token()
        assert(data:sub(position, position) == "^", "Invalid metadata token")
        local marker = data:sub(position + 1, position + 1)
        local finish = data:find("^", position + 2, true) or (#data + 1)
        local value = data:sub(position + 2, finish - 1)
        position = finish
        return marker, value
    end
    local function Value(marker, value, depth)
        count = count + 1
        assert(depth < 50 and count <= 20000, "Metadata limit exceeded")
        if marker == "S" then
            assert(not value:find("~$"), "Truncated metadata escape")
            return (value:gsub("~(.)", function(char)
                local special = { z = 30, ["{"] = 127, ["|"] = 126, ["}"] = 94 }
                local byte = special[char] or char:byte() - 64
                assert(byte >= 0 and byte <= 127, "Invalid metadata escape")
                return string.char(byte)
            end))
        elseif marker == "N" then
            local number = assert(tonumber(value), "Invalid metadata number")
            assert(number == number and math.abs(number) < math.huge, "Invalid metadata number")
            return number
        elseif marker == "B" then return true
        elseif marker == "b" then return false
        elseif marker == "T" then
            local result = {}
            while true do
                local keyMarker, keyValue = Token()
                if keyMarker == "t" then return result end
                local key = Value(keyMarker, keyValue, depth + 1)
                assert(type(key) == "string" or type(key) == "number", "Invalid metadata key")
                local itemMarker, itemValue = Token()
                assert(result[key] == nil, "Duplicate metadata field")
                result[key] = Value(itemMarker, itemValue, depth + 1)
            end
        end
        error("Unsupported metadata token")
    end
    assert(Token() == "1", "Unsupported metadata version")
    local marker, value = Token()
    local result = Value(marker, value, 0)
    assert(data:sub(position) == "^^" and type(result) == "table", "Invalid metadata ending")
    return result
end

local function Decode(text)
    assert(type(text) == "string" and #text <= 1024 * 1024 and not text:find("%z"), "Invalid input or size limit")
    local originalText = text
    local script, shareVersion
    if text:match("^%s*#") then
        shareVersion = tonumber(text:match("# Version: (%d+)"))
        if not shareVersion and text:find("(Script)", 1, true) then shareVersion = 1 end
        assert(shareVersion == 1 or shareVersion == 2, "Unsupported share version or missing team")
        if shareVersion == 2 then
            local normalized = text:gsub("\r\n", "\n")
            local headers = normalized:match("^(.-)\n# Code Start\n.-\n# Code End%s*$")
            assert(headers, "Invalid script envelope boundaries")
            for _, line in ipairs(Split(headers, "\n")) do
                assert(line:match("^#") or Trim(line) == "", "Invalid script header")
            end
        end
        assert(BattleBuddyScript and BattleBuddyScript.Import, "Script share codec unavailable")
        script = assert(BattleBuddyScript.Import(text))
        ValidateScript(script)
        local metadata = ShareMetadata(text, shareVersion)
        assert(metadata.plugin == "Rematch" and type(metadata.extra) == "string", "Missing Rematch team metadata")
        text = metadata.extra
        assert(#text <= 1024 * 1024 and not text:find("%z"), "Invalid decoded team data")
    end
    local document = { teams = {}, groups = {}, entries = {}, descriptors = {}, groupVersions = {} }
    local current
    for _, line in ipairs(Split(text:gsub("\r\n", "\n"), "\n")) do
        if Trim(line) ~= "" then
            assert(not line:find("\r", 1, true), "Invalid line ending")
            if line:sub(1, 3) == "__ " then
                local group, version = ReadGroup(line)
                if document.grouped == nil then document.grouped = true end
                if document.grouped then
                    current = #document.groups + 1
                    document.groups[current], document.groupVersions[current] = group, version
                    document.entries[#document.entries + 1] = { group = current }
                end
            else
                if document.grouped == nil then document.grouped = false end
                local team, descriptors = ReadTeam(line)
                local index = #document.teams + 1
                document.teams[index], document.descriptors[index] = team, descriptors
                document.entries[#document.entries + 1] = { team = index, group = current }
                if current then table.insert(document.groups[current].teams, index) end
            end
            assert(#document.entries <= 10000, "Record limit exceeded")
        end
    end
    assert(#document.entries > 0, "No teams or groups found")
    document.kind = document.grouped and (#document.groups > 1 and "backup" or "group")
        or (#document.teams == 1 and "team" or "teams")
    if script then
        assert(#document.teams == 1, "Script share requires exactly one team")
        assert(not document.teams[1].script or document.teams[1].script == script, "Conflicting attached scripts")
        document.teams[1].script, document.shareVersion = script, shareVersion
    end
    originals[document] = { text = originalText, snapshot = Copy(document) }
    return document
end

function X.Decode(text) return Safe(Decode, text) end

local function WriteTag(pet, tag)
    if pet == nil or pet == "empty" then return "" end
    if pet == 0 then return "ZL" end
    if pet == "ignored" then return "ZI" end
    if type(pet) == "string" and pet:match("^random:%d+$") then
        local family = tonumber(pet:sub(8))
        assert(family <= 10, "Invalid random family")
        return "ZR" .. Base32(family)
    end
    tag = tag or {}
    local species = tag.speciesID or (type(pet) == "number" and pet)
    assert(species and species > 0, "Owned pet requires a portable species tag")
    local choices, digits = tag.abilities or { 0, 0, 0 }, {}
    for index = 1, 3 do
        local choice = choices[index]
        assert(choice == 0 or choice == 1 or choice == 2, "Invalid ability choice")
        digits[index] = tostring(choice)
    end
    local breed = tag.breedID or 0
    assert(breed == 0 or (breed >= 3 and breed <= 12), "Invalid breed")
    return table.concat(digits) .. Base32(breed) .. Base32(species)
end

local function WriteTeam(team, options, descriptors)
    assert(type(team.name) == "string" and Trim(team.name) ~= "" and not team.name:find("[\r\n]"), "Invalid team name")
    local targets, fields = {}, { team.name }
    for _, id in ipairs(team.targets or {}) do
        assert(id > 0, "Invalid target")
        targets[#targets + 1] = Base32(id)
    end
    fields[2] = table.concat(targets, ",")
    for index = 1, 3 do
        local tag = WriteTag(team.pets[index], team.tags[index])
        if descriptors and descriptors[index] then
            local pet, originalTag = PetTag(descriptors[index])
            if pet == team.pets[index] and Equal(originalTag, team.tags[index]) then tag = descriptors[index] end
        end
        fields[index + 2] = tag
    end
    local line = table.concat(fields, ":") .. ":"
    if options.includePreferences ~= false then line = line .. WritePreferences(team.preferences) end
    local notes = options.includeNotes ~= false and team.notes or ""
    notes = notes or ""
    if team.script and options.includeScript ~= false then
        ValidateScript(team.script)
        assert(not team.script:find(beginScript, 1, true) and not team.script:find(endScript, 1, true), "Script contains envelope delimiter")
        notes = notes .. "\n" .. beginScript .. "\n" .. team.script .. "\n" .. endScript .. "\n"
    end
    if notes ~= "" then
        assert(not notes:find("\r", 1, true), "Carriage return cannot be exported")
        assert(not notes:find("\\n", 1, true), "Literal backslash-n cannot be represented without changing its meaning")
        line = line .. "N:" .. notes:gsub("\n", "\\n")
    end
    return line
end

local function WriteGroup(group, options, version)
    assert(type(group.name) == "string" and Trim(group.name) ~= "" and not group.name:find("[\r\n]"), "Invalid group name")
    if version == "legacy" and not group.icon and not group.color and not group.showTab
        and not group.preferences and group.sortMode == "alpha" then return "__ " .. group.name .. " __" end
    local sort
    for index, value in ipairs(sorts) do if group.sortMode == value then sort = index end end
    assert(sort, "Invalid group sort")
    local icon = group.icon
    assert(icon == nil or type(icon) == "number", "Group icon requires a numeric file ID")
    local line = "__ " .. group.name .. ":" .. sort .. ":" .. (icon and Base32(icon) or "") .. ":" .. (group.color or "") .. ":"
    if version ~= "legacy-fields" or group.showTab then line = line .. (group.showTab and "1" or "") .. ":" end
    if options.includePreferences ~= false then line = line .. WritePreferences(group.preferences) end
    return line .. " __"
end

local function Encode(document, options)
    options = options or {}
    local original = originals[document]
    if next(options) == nil and original and Equal(document, original.snapshot) then return original.text end
    local lines = {}
    for _, entry in ipairs(document.entries) do
        if entry.team then
            lines[#lines + 1] = WriteTeam(document.teams[entry.team], options, (document.descriptors or {})[entry.team])
        else
            lines[#lines + 1] = WriteGroup(document.groups[entry.group], options, (document.groupVersions or {})[entry.group])
        end
    end
    local result = table.concat(lines, "\n")
    Decode(result)
    return result
end

function X.Encode(document, options) return Safe(Encode, document, options) end

function X.Import(store, text, resolver)
    return Safe(function()
        assert(resolver == nil or type(resolver) == "function", "Invalid pet resolver")
        local preview = Decode(text)
        preview.conflicts, preview.pets, preview.scriptPresent, preview.warnings = {}, {}, {}, {}
        local seen = {}
        for index, team in ipairs(preview.teams) do
            local owner = BattleBuddyTeams.FindByName(store, team.name)
            if owner or seen[team.name:lower()] then
                preview.conflicts[#preview.conflicts + 1] = { index = index, teamID = owner and owner.teamID,
                    previousIndex = seen[team.name:lower()], name = team.name }
            end
            seen[team.name:lower()] = index
            preview.scriptPresent[index], preview.pets[index] = team.script ~= nil, {}
            for slot = 1, 3 do
                local pet, tag = team.pets[slot], team.tags[slot]
                local raw = preview.descriptors[index][slot]
                local _, _, selection = PetTag(raw)
                local needs = pet ~= "empty" and pet ~= "ignored"
                local resolved
                if needs and resolver then
                    local ok, value = pcall(resolver, pet, Copy(tag), slot, Copy(selection))
                    if ok and type(value) == "string" and value:match("^BattlePet%-.+") then resolved = value end
                end
                preview.pets[index][slot] = { petID = pet, tag = Copy(tag), resolvedPetID = resolved,
                    unresolved = needs and not resolved or false, selection = selection }
                if selection then
                    preview.warnings[#preview.warnings + 1] = { team = index, slot = slot, descriptor = raw,
                        reason = "Queue selection retained in preview; saved team retains species and breed only" }
                end
                if raw == "ZU" or raw:sub(1, 2) == "ZN" then
                    preview.warnings[#preview.warnings + 1] = { team = index, slot = slot, descriptor = raw,
                        reason = "Runtime placeholder retained in preview; saved as an empty slot" }
                    preview.pets[index][slot].unresolved = true
                end
            end
        end
        previews[preview] = Copy(preview)
        originals[preview].snapshot = Copy(preview)
        return preview
    end)
end

local function Apply(store, preview, choices)
    local T, result, groups = BattleBuddyTeams, { teams = {}, groups = {} }, {}
    for index, source in ipairs(preview.groups) do
        local group = Copy(source)
        group.teams = {}
        local saved, reason = T.CreateGroup(store, group)
        assert(saved, reason)
        groups[index], result.groups[index] = saved.groupID, saved
    end
    for _, entry in ipairs(preview.entries) do
        if entry.team then
            local team = Copy(preview.teams[entry.team])
            team.groupID = groups[entry.group] or choices.groupID or "group:none"
            for slot, pet in ipairs(preview.pets[entry.team]) do
                if pet.resolvedPetID and type(team.pets[slot]) == "number" and team.pets[slot] > 0 then
                    team.pets[slot] = pet.resolvedPetID
                end
            end
            local owner = T.FindByName(store, team.name)
            local saved, reason
            if owner and choices.conflicts == "replace" then
                team.notes, team.script = team.notes or "", team.script or ""
                team.targets, team.preferences = team.targets or {}, team.preferences or {}
                team.winrecord, team.favorite = { wins = 0, losses = 0, draws = 0 }, false
                saved, reason = T.EditTeam(store, owner.teamID, team)
            else saved, reason = T.CreateTeam(store, team) end
            assert(saved, reason)
            result.teams[#result.teams + 1] = saved
        end
    end
    for index, id in ipairs(groups) do result.groups[index] = T.GetGroup(store, id) end
    return result
end

function X.ApplyImport(store, preview, choices)
    return Safe(function()
        assert(previews[preview] and Equal(preview, previews[preview]), "Invalid or edited import preview")
        choices = choices or {}
        assert(choices.conflicts == nil or choices.conflicts == "copy" or choices.conflicts == "replace", "Invalid conflict choice")
        assert(choices.groupID == nil or BattleBuddyTeams.GetGroup(store, choices.groupID), "Unknown destination group")
        local trial = assert(BattleBuddyTeams.Initialize(store))
        Apply(trial, preview, choices)
        return Apply(store, preview, choices)
    end)
end

function X.ExportTeam(store, id, options)
    return Safe(function()
        local team = assert(BattleBuddyTeams.GetTeam(store, id), "Unknown team")
        return Encode({ teams = { team }, groups = {}, entries = { { team = 1 } } }, options)
    end)
end

local function ExportGroups(store, groups, options)
    local document = { teams = {}, groups = {}, entries = {} }
    for index, group in ipairs(groups) do
        group = Copy(group)
        if group.meta then group.icon = nil end
        document.groups[index] = group
        document.entries[#document.entries + 1] = { group = index }
        for _, id in ipairs(group.teams) do
            local team = assert(BattleBuddyTeams.GetTeam(store, id), "Unknown team")
            document.teams[#document.teams + 1] = team
            document.entries[#document.entries + 1] = { team = #document.teams, group = index }
        end
    end
    return Encode(document, options)
end

function X.ExportGroup(store, id, options)
    return Safe(function()
        local group = assert(BattleBuddyTeams.GetGroup(store, id), "Unknown group")
        return ExportGroups(store, { group }, options)
    end)
end

function X.ExportBackup(store, options)
    return Safe(function() return ExportGroups(store, BattleBuddyTeams.ListGroups(store), options) end)
end

function X.PlainText(team, options)
    return Safe(function()
        options = options or {}
        local lines = { team.name }
        for slot = 1, 3 do
            local tag, pet = team.tags[slot] or {}, team.pets[slot]
            local name = pet == 0 and "Leveling pet" or pet == "ignored" and "Ignored slot"
                or (pet == nil or pet == "empty") and "Empty slot" or "Species " .. tostring(tag.speciesID or pet)
            if options.petName then name = options.petName(pet, Copy(tag)) or name end
            local abilities = tag.abilities or { 0, 0, 0 }
            lines[#lines + 1] = slot .. ". " .. name .. " (" .. table.concat(abilities, "/") .. ")"
        end
        if team.targets then lines[#lines + 1] = "Targets: " .. table.concat(team.targets, ", ") end
        if options.includePreferences ~= false and team.preferences then
            for _, key in ipairs(preferenceKeys) do
                if team.preferences[key] ~= nil then lines[#lines + 1] = key .. ": " .. tostring(team.preferences[key]) end
            end
        end
        if options.includeNotes ~= false and team.notes then lines[#lines + 1] = team.notes end
        return table.concat(lines, "\n")
    end)
end
