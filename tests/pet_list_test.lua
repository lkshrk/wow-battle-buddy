local root = (... or ".")
local Frames = dofile(root .. "/tests/support/frames.lua")
Frames.Reset()
Frames.Install()
local function eq(actual, expected)
    assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local create = Frames.Create
Frames.Create = function(...)
    local frame = create(...)
    function frame:SetTextColor(...) self.textColor = { ... } end
    function frame:SetVertexColor(...) self.vertexColor = { ... } end
    function frame:SetAlpha(alpha) self.alpha = alpha end
    function frame:SetDesaturated(value) self.desaturated = value end
    function frame:SetTexCoord(...) self.texCoord = { ... } end
    function frame:SetAtlas(atlas) self.atlas = atlas end
    function frame:SetNormalTexture(texture) self.normalTexture = texture end
    function frame:SetHighlightTexture(texture) self.highlightTexture = texture end
    function frame:SetPushedTexture(texture) self.pushedTexture = texture end
    function frame:RegisterForClicks(...) self.clicks = { ... } end
    function frame:RegisterForDrag(...) self.dragButtons = { ... } end
    function frame:SetEnabled(enabled) self.enabled = enabled end
    function frame:SetMaxLetters(count) self.maxLetters = count end
    function frame:ClearFocus() self.focused = false end
    function frame:SetFontObject(font) self.fontObject = font end
    function frame:SetChecked(value) self.checked = value end
    function frame:GetChecked() return self.checked end
    function frame:SetDataProvider(provider, retain)
        self.provider, self.retain = provider, retain
    end
    return frame
end
CreateFrame = Frames.Create
CreateScrollBoxListLinearView = function()
    return {
        SetElementInitializer = function(self, template, callback) self.template, self.initialize = template, callback end,
        SetElementExtent = function(self, extent) self.extent = extent end,
        SetPadding = function(self, ...) self.padding = { ... } end,
    }
end
CreateDataProvider = function(data) return { data = data } end
ScrollUtil = { InitScrollBoxListWithScrollBar = function(box, bar, view) box.view, box.bar = view, bar end }
local combat, reads, pickups, applies, summons = false, 0, 0, 0, 0
InCombatLockdown = function() return combat end
IsShiftKeyDown = function() return false end
IsAltKeyDown = function() return false end
issecretvalue = function() return false end
canaccessvalue = function() return true end
C_Timer = { After = function() error("timer forbidden") end, NewTimer = function() error("timer forbidden") end }
C_PetJournal = {
    PickupPet = function(id) eq(id, "BattlePet-a"); pickups = pickups + 1 end,
    SetPetLoadOutInfo = function() applies = applies + 1 end,
    SummonPetByGUID = function() summons = summons + 1 end,
}
BattleBuddyLoadout = { DropPet = function() applies = applies + 1 end }
local pets = {
    { petID = "BattlePet-a", speciesID = 1, name = "Azure", speciesName = "Azure", owned = true,
      icon = 123, level = 25, health = 1500, power = 300, speed = 280, quality = 4, petType = 2,
      favorite = true, summoned = true, abilities = { { name = "Flame", description = "Burns enemies", petType = 7 } } },
    { petID = "BattlePet-b", speciesID = 1, name = "Azure", owned = true,
      level = 10, quality = 2, petType = 2, abilities = {} },
    { speciesID = 2, name = "Missing", owned = false, petType = 5, abilities = {} },
}
BattleBuddyDB = { teamsByID = { ["team:1"] = { pets = { "BattlePet-a" } } } }
dofile(root .. "/BattleBuddy/Compatibility.lua")
BattleBuddyCompatibility.ReadPetCollection = function() reads = reads + 1; return pets end
BattleBuddyCompatibility.PickupPet = function(id) C_PetJournal.PickupPet(id); return true end
local views = {}
BattleBuddyDev = { RegisterView = function(name, show, hide, shown)
    views[name] = { show = show, hide = hide, shown = shown }; return true
end }
UIParent = CreateFrame("Frame")
local parent = CreateFrame("Frame", nil, UIParent)
parent:SetSize(280, 535)
local active = false
BattleBuddyWindow = { frame = { pets = parent }, Show = function() active = true; return true end,
    Hide = function() active = false end, IsActive = function() return active end }
COLLECTIONS_JOURNAL_TAB_INDEX_PETS = 2
SetCollectionsJournalShown = function() end
CollectionsJournal = CreateFrame("Frame")
HideUIPanel = function() active = false end
dofile(root .. "/BattleBuddy/PetList.lua")
assert(BattleBuddyPetList, "pet list module missing")
dofile(root .. "/BattleBuddy/PetQuery.lua")
local List = BattleBuddyPetList
local frame = assert(List.Mount(parent))
eq(List.Mount(parent), frame)
eq(frame:GetParent(), parent)
eq(frame.search.frameType, "EditBox")
eq(frame.search.autoFocus, false)
for _, field in ipairs({ "health", "power", "speed" }) do
    eq(frame.ranges[field].frameType, "EditBox")
end
eq(#frame.families, 10)
for _, tab in ipairs({ "families", "strong", "tough" }) do assert(frame.tabs[tab]) end
eq(frame.scrollBox.template, "WowScrollBoxList")
eq(frame.scrollBar.template, "MinimalScrollBar")
eq(frame.scrollBox.view.extent, 44)
eq(frame.scrollBox.view.template, "Button")
Frames.AssertAnchor(frame.scrollBox, 1, { "TOPLEFT", frame, "TOPLEFT", 3, -115 })
Frames.AssertAnchor(frame.scrollBox, 2, { "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 3 })
Frames.AssertAnchor(frame.search, 1, { "TOPLEFT", frame, "TOPLEFT", 30, -3 })
for index, field in ipairs({ "health", "power", "speed" }) do
    Frames.AssertSize(frame.ranges[field], 82, 22)
    Frames.AssertAnchor(frame.ranges[field], 1, { "TOPLEFT", frame, "TOPLEFT", 8 + (index - 1) * 90, -30 })
end
List.Refresh()
eq(#List.results, 3)
eq(frame.summary:IsShown(), false)
local row = CreateFrame("Button", nil, frame.scrollBox)
frame.scrollBox.view.initialize(row, List.results[1])
eq(row.name:GetText(), "Azure")
eq(row.level:GetText(), "25")
eq(row.breed:GetText(), "")
eq(row.favorite:IsShown(), true)
eq(row.duplicate:IsShown(), true)
eq(row.inTeam:IsShown(), true)
eq(row.summoned:IsShown(), true)
eq(row.icon.texture, 123)
Frames.AssertSize(row.icon, 40, 40)
Frames.AssertAnchor(row.level, 1, { "BOTTOMRIGHT", row.icon, "BOTTOMRIGHT", 0, -1 })
eq(row.name.wordWrap, false)
local rareColor = row.name.textColor
Frames.Fire(row, "OnDragStart", "LeftButton")
eq(pickups, 1)
eq(applies, 0)
eq(summons, 0)
List.BindRow(row, List.results[3])
eq(row.favorite:IsShown(), false)
eq(row.inTeam:IsShown(), false)
eq(row.duplicate:IsShown(), false)
eq(row.summoned:IsShown(), false)
eq(row.breed:GetText(), "")
assert(row.name.textColor[1] ~= rareColor[1] or row.name.textColor[3] ~= rareColor[3])
Frames.Fire(row, "OnDragStart", "LeftButton")
eq(pickups, 1)
frame.search:SetText("burns")
Frames.Fire(frame.search, "OnTextChanged", true)
eq(#List.results, 1)
eq(frame.summary:IsShown(), true)
frame.search:SetText("")
Frames.Fire(frame.search, "OnTextChanged", true)
eq(#List.results, 3)
frame.ranges.health:SetText(">1400")
Frames.Fire(frame.ranges.health, "OnTextChanged", true)
eq(#List.results, 1)
frame.ranges.health:SetText("nonsense")
Frames.Fire(frame.ranges.health, "OnTextChanged", true)
eq(List.query.valid, false)
eq(#List.results, 0)
frame.ranges.health:SetText("")
Frames.Fire(frame.ranges.health, "OnTextChanged", true)
eq(List.query.valid, true)
eq(#List.results, 3)
Frames.Fire(frame.level25, "OnClick", "LeftButton")
eq(#List.results, 1)
Frames.Fire(frame.level25, "OnClick", "LeftButton")
eq(#List.results, 3)
Frames.Fire(frame.level25, "OnClick", "RightButton")
eq(List.filters.level25, true)
eq(List.filters.rare, true)
Frames.Fire(frame.level25, "OnClick", "RightButton")
eq(#List.results, 3)
Frames.Fire(frame.families[2], "OnClick", "LeftButton")
eq(#List.results, 2)
Frames.Fire(frame.families[2], "OnClick", "LeftButton")
eq(#List.results, 3)
Frames.Fire(frame.expand, "OnClick", "LeftButton")
eq(frame.search:IsShown(), true)
eq(frame.families[1]:IsVisible(), false)
Frames.AssertAnchor(frame.scrollBox, 1, { "TOPLEFT", frame, "TOPLEFT", 3, -56 })
Frames.Fire(frame.expand, "OnClick", "LeftButton")
eq(frame.families[1]:IsVisible(), true)
assert(views["window-pets"])
eq(views["window-pets"].show(), true)
eq(views["window-pets"].shown(), true)
views["window-pets"].hide()
local events = assert(List.events)
assert(events.events.PET_JOURNAL_LIST_UPDATE)
local before = reads
Frames.Fire(events, "OnEvent", "PET_JOURNAL_LIST_UPDATE")
assert(reads > before)
combat = true
before = reads
Frames.Fire(events, "OnEvent", "PET_JOURNAL_LIST_UPDATE")
eq(reads, before)
combat = false
Frames.Fire(events, "OnEvent", "PLAYER_REGEN_ENABLED")
assert(reads > before)
eq(applies, 0)
eq(summons, 0)
eq(frame.scrollBox.retain, true)
List.BindRow(row, List.results[1])
Frames.Fire(row, "OnClick", "LeftButton")
local copy = {}
for key, value in pairs(pets[1]) do copy[key] = value end
pets[1] = copy
List.Refresh()
List.BindRow(row, List.results[1])
eq(row.selected:IsShown(), true)
frame.search:SetText("Missing")
Frames.Fire(frame.search, "OnTextChanged", true)
assert(frame.scrollBox.retain ~= true, "changed search must reset scrolling")
frame.search:SetText("")
Frames.Fire(frame.search, "OnTextChanged", true)
IsAltKeyDown = function() return true end
Frames.Fire(frame.families[2], "OnClick", "LeftButton")
eq(#List.results, 2)
IsAltKeyDown = function() return false end
IsShiftKeyDown = function() return true end
Frames.Fire(frame.families[2], "OnClick", "LeftButton")
eq(#List.results, 1)
IsShiftKeyDown = function() return false end
Frames.Fire(frame.families[2], "OnClick", "LeftButton")
eq(next(List.filters.families), nil)
eq(#List.results, 3)
Frames.Fire(frame.tabs.strong, "OnClick", "LeftButton")
Frames.Fire(frame.families[10], "OnClick", "LeftButton")
eq(#List.results, 1)
Frames.Fire(frame.tabs.tough, "OnClick", "LeftButton")
eq(frame.tabs.strong:GetText(), "* Strong Vs")
Frames.Fire(frame.families[3], "OnClick", "LeftButton")
eq(#List.results, 1)
eq(List.filters.strong[10], true)
eq(List.filters.tough[3], true)
eq(applies, 0)
eq(summons, 0)
local function noUpdates(object)
    assert(not object.scripts.OnUpdate, "OnUpdate forbidden")
    for _, child in ipairs(object.children) do noUpdates(child) end
end
noUpdates(UIParent)
BattleBuddyDev = nil
dofile(root .. "/BattleBuddy/PetList.lua")
local lateView
BattleBuddyDev = { RegisterView = function(name) lateView = name; return true end }
Frames.Fire(BattleBuddyPetList.events, "OnEvent", "ADDON_LOADED", "BattleBuddy")
eq(lateView, "window-pets")
print("pet_list_test.lua: passed")
