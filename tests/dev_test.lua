local sourceRoot = (... or ".")
local Frames = dofile(sourceRoot .. "/tests/support/frames.lua")

local function AssertEqual(actual, expected)
    if actual ~= expected then
        error(("expected %s, got %s"):format(tostring(expected), tostring(actual)))
    end
end

local function NewRun()
    dofile(sourceRoot .. "/BattleBuddy/Config.lua")
    dofile(sourceRoot .. "/BattleBuddy/Dev.lua")
    BattleBuddyDB = { settingOverrides = {} }
    local state = { queue = {}, lines = {}, actions = {}, combat = false }
    state.options = {
        capture = function() state.actions[#state.actions + 1] = "capture" end,
        schedule = function(delay, fn)
            AssertEqual(delay > 0, true)
            state.queue[#state.queue + 1] = fn
        end,
        inCombat = function() return state.combat end,
        print = function(line) state.lines[#state.lines + 1] = line end,
    }
    function state.Tick()
        local fn = table.remove(state.queue, 1)
        assert(fn, "expected scheduled callback")
        fn()
    end
    function state.Drain()
        local count = 0
        while #state.queue > 0 do
            count = count + 1
            assert(count < 100, "scheduler did not finish")
            state.Tick()
        end
    end
    function state.Contains(text)
        return table.concat(state.lines, "\n"):find(text, 1, true) ~= nil
    end
    function state.View(name, shown, failShow, failHide)
        local frame = Frames.Create("Frame")
        frame:SetShown(shown or false)
        AssertEqual(BattleBuddyDev.RegisterView(name, function()
            state.actions[#state.actions + 1] = "show " .. name
            frame:Show()
            if failShow then error("show failed") end
        end, function()
            state.actions[#state.actions + 1] = "hide " .. name
            frame:Hide()
            if failHide then error("hide failed") end
        end, function() return frame:IsShown() end), true)
        return frame
    end
    return state
end

local state = NewRun()
local noop = function() end
AssertEqual(BattleBuddyDev.RegisterView("", noop, noop), false)
AssertEqual(BattleBuddyDev.RegisterView(nil, noop, noop), false)
AssertEqual(BattleBuddyDev.RegisterView(1, noop, noop), false)
AssertEqual(BattleBuddyDev.RegisterView("bad", false, noop), false)
AssertEqual(BattleBuddyDev.RegisterView("bad", noop, nil), false)
state.View("first")
state.View("second")
AssertEqual(BattleBuddyDev.RegisterView("first", noop, noop), false)
local names = BattleBuddyDev.Views()
AssertEqual(table.concat(names, ","), "first,second")
names[1] = "changed"
AssertEqual(BattleBuddyDev.Views()[1], "first")
AssertEqual(BattleBuddyDev.IsEnabled(), false)
BattleBuddyDev.RunShots(state.options)
AssertEqual(#state.actions, 0)
AssertEqual(#state.queue, 0)
AssertEqual(state.Contains("/bb dev on"), true)
AssertEqual(BattleBuddyConfig.SetSetting("devTools", true), true)
AssertEqual(BattleBuddyDB.settingOverrides.devTools, true)
AssertEqual(BattleBuddyConfig.SetSetting("devTools", false), true)
AssertEqual(BattleBuddyDB.settingOverrides.devTools, nil)

state = NewRun()
BattleBuddyConfig.SetSetting("devTools", true)
local first = state.View("first", true)
local second = state.View("second")
BattleBuddyDev.RunShots(state.options)
AssertEqual(table.concat(state.actions, ","), "show first")
state.Tick()
AssertEqual(table.concat(state.actions, ","), "show first,capture")
Frames.AssertVisible(first, true)
Frames.AssertVisible(second, false)
state.Tick()
AssertEqual(table.concat(state.actions, ","), "show first,capture,hide first,show second")
state.Drain()
AssertEqual(state.Contains("BattleBuddy shots: 1/2 first"), true)
AssertEqual(state.Contains("BattleBuddy shots: 2/2 second"), true)
AssertEqual(state.Contains("done"), true)
Frames.AssertVisible(first, true)
Frames.AssertVisible(second, false)
AssertEqual(next(BattleBuddyDB.settingOverrides), "devTools")

local realPrint = print
local function InstallSlash(s)
    print = s.options.print
    Screenshot = s.options.capture
    C_Timer = { After = s.options.schedule }
    InCombatLockdown = s.options.inCombat
    EventUtil = { ContinueOnAddOnLoaded = function(_, fn) fn() end }
    BattleBuddyPersistence = { Load = function() end }
    BattleBuddyEncounterContent = nil
    BattleBuddyPetJournalSurface = { Open = function() s.opened = true; return false end }
    Settings = {
        RegisterVerticalLayoutCategory = function() return { GetID = function() return 1 end } end,
        RegisterAddOnCategory = noop,
        OpenToCategory = function() s.settings = true end,
    }
    SlashCmdList = {}
    dofile(sourceRoot .. "/BattleBuddy/BattleBuddy.lua")
end

for _, capture in ipairs({ false, function() error("unavailable") end }) do
    state = NewRun()
    state.options.capture = capture
    first = state.View("first", true)
    second = state.View("second")
    InstallSlash(state)
    SlashCmdList.BATTLEBUDDY("dev views")
    AssertEqual(state.Contains("/bb dev on"), true)
    SlashCmdList.BATTLEBUDDY("dev off")
    AssertEqual(state.lines[#state.lines]:find("/bb dev on", 1, true) ~= nil, true)
    SlashCmdList.BATTLEBUDDY(" DEV ON ")
    AssertEqual(BattleBuddyDev.IsEnabled(), true)
    SlashCmdList.BATTLEBUDDY("dev views")
    AssertEqual(state.Contains("first"), true)
    SlashCmdList.BATTLEBUDDY("dev shots")
    state.Tick()
    Frames.AssertVisible(first, true)
    AssertEqual(state.Contains("/bb dev next"), true)
    SlashCmdList.BATTLEBUDDY("dev next")
    while not state.Contains("2/2 second") do state.Tick() end
    Frames.AssertVisible(first, false)
    Frames.AssertVisible(second, true)
    SlashCmdList.BATTLEBUDDY("dev stop")
    state.Drain()
    Frames.AssertVisible(first, true)
    Frames.AssertVisible(second, false)
    AssertEqual(state.Contains("stopped"), true)
    SlashCmdList.BATTLEBUDDY("dev next")
    AssertEqual(state.Contains("no run is active"), true)
    SlashCmdList.BATTLEBUDDY("dev stop")
    SlashCmdList.BATTLEBUDDY("dev off")
    AssertEqual(BattleBuddyDev.IsEnabled(), false)
    AssertEqual(BattleBuddyDB.settingOverrides.devTools, nil)
    SlashCmdList.BATTLEBUDDY("")
    AssertEqual(state.opened, true)
    AssertEqual(state.settings, true)
    state.settings = false
    SlashCmdList.BATTLEBUDDY("config")
    AssertEqual(state.settings, true)
    local before = #state.lines
    SlashCmdList.BATTLEBUDDY("help")
    AssertEqual(#state.lines - before, 4)
    AssertEqual(state.lines[#state.lines], "  |cffffd100/bb help|r — Show this command list.")
end
print = realPrint

state = NewRun()
BattleBuddyConfig.SetSetting("devTools", true)
BattleBuddyDev.RunShots(state.options)
AssertEqual(state.Contains("no views"), true)
first = state.View("first")
state.combat = true
BattleBuddyDev.RunShots(state.options)
AssertEqual(state.Contains("combat"), true)
AssertEqual(#state.actions, 0)
state.combat = false
BattleBuddyDev.RunShots(state.options)
BattleBuddyDev.RunShots(state.options)
AssertEqual(state.Contains("already active"), true)
AssertEqual(#state.actions, 1)
state.combat = true
state.Drain()
AssertEqual(#state.actions, 1)
AssertEqual(state.Contains("stopped"), true)
Frames.AssertVisible(first, true)

state = NewRun()
BattleBuddyConfig.SetSetting("devTools", true)
first = state.View("broken", false, true, true)
second = state.View("working")
BattleBuddyDev.RunShots(state.options)
state.Drain()
AssertEqual(state.Contains("broken"), true)
AssertEqual(state.Contains("show failed"), true)
AssertEqual(state.Contains("hide failed"), true)
AssertEqual(state.Contains("2/2 working"), true)
Frames.AssertVisible(first, false)
Frames.AssertVisible(second, false)

state = NewRun()
BattleBuddyConfig.SetSetting("devTools", true)
state.options.capture = false
first = state.View("manual")
BattleBuddyDev.RunShots(state.options)
state.Tick()
state.combat = true
local before = #state.actions
state.Drain()
AssertEqual(#state.actions, before)
AssertEqual(state.Contains("combat"), true)
AssertEqual(state.Contains("stopped"), true)

state = NewRun()
BattleBuddyConfig.SetSetting("devTools", true)
local captureCalls = 0
state.options.capture = function()
    captureCalls = captureCalls + 1
    error("capture failed")
end
first = state.View("first")
second = state.View("second")
BattleBuddyDev.RunShots(state.options)
state.Tick()
BattleBuddyDev.Next()
while not state.Contains("2/2 second") do state.Tick() end
AssertEqual(captureCalls, 1)
BattleBuddyDev.Next()
state.Drain()
AssertEqual(state.Contains("done"), true)
Frames.AssertVisible(first, false)
Frames.AssertVisible(second, false)

state = NewRun()
BattleBuddyConfig.SetSetting("devTools", true)
first = state.View("first", true)
second = state.View("second")
BattleBuddyDev.RunShots(state.options)
state.Tick()
BattleBuddyDev.Stop()
Frames.AssertVisible(first, true)
Frames.AssertVisible(second, false)
local previousActions = #state.actions
BattleBuddyDev.RunShots(state.options)
state.Tick()
AssertEqual(#state.actions, previousActions + 1)
state.Drain()
AssertEqual(state.Contains("done"), true)
Frames.AssertVisible(first, true)
Frames.AssertVisible(second, false)

state = NewRun()
BattleBuddyConfig.SetSetting("devTools", true)
state.options.capture = nil
Screenshot = nil
first = state.View("missing capture")
BattleBuddyDev.RunShots(state.options)
state.Tick()
Frames.AssertVisible(first, true)
AssertEqual(state.Contains("/bb dev next"), true)
BattleBuddyDev.Next()
state.Drain()
Frames.AssertVisible(first, false)
AssertEqual(state.Contains("done"), true)

Frames.Reset()
print("dev_test: passed")
