BattleBuddyDev = {}

local Dev = BattleBuddyDev
local SETTLE_DELAY = 0.5
local views, names = {}, {}
local active
local OFF_MESSAGE = "BattleBuddy dev tools are off; enable with /bb dev on."

function Dev.RegisterView(name, show, hide, isShown)
    if type(name) ~= "string" or name == "" or names[name]
        or type(show) ~= "function" or type(hide) ~= "function" then
        return false
    end
    names[name] = true
    views[#views + 1] = { name = name, show = show, hide = hide, isShown = isShown }
    return true
end

function Dev.Views()
    local result = {}
    for index, view in ipairs(views) do result[index] = view.name end
    return result
end

function Dev.IsEnabled()
    return BattleBuddyConfig.GetSetting("devTools") == true
end

local function Call(run, view, action)
    local ok, result = pcall(view[action])
    if not ok then
        run.print("BattleBuddy shots: " .. view.name .. " " .. action .. " error: " .. tostring(result))
    end
    return ok, result
end

local function Finish(run, status)
    if active ~= run then return end
    active = nil
    local skipped = false
    for index, view in ipairs(run.views) do
        if run.touched[index] then
            if run.inCombat() then skipped = true else Call(run, view, "hide") end
        end
    end
    for index, view in ipairs(run.views) do
        if run.shown[index] then
            if run.inCombat() then skipped = true else Call(run, view, "show") end
        end
    end
    if skipped then run.print("BattleBuddy shots: combat; skipped unsafe hide and restore actions.") end
    run.print("BattleBuddy shots: " .. status)
end

local function CanContinue(run)
    if active ~= run then return false end
    if run.inCombat() then
        run.print("BattleBuddy shots: combat started.")
        Finish(run, "stopped")
        return false
    end
    return true
end

local Step

local function Advance(run)
    if not CanContinue(run) then return end
    run.waiting = false
    Call(run, run.views[run.index], "hide")
    run.index = run.index + 1
    Step(run)
end

local function WaitForNext(run, index)
    run.schedule(SETTLE_DELAY, function()
        if not CanContinue(run) or run.index ~= index or not run.waiting then return end
        WaitForNext(run, index)
    end)
end

Step = function(run)
    if not CanContinue(run) then return end
    local view = run.views[run.index]
    if not view then
        Finish(run, "done")
        return
    end
    run.touched[run.index] = true
    local shown = Call(run, view, "show")
    run.schedule(SETTLE_DELAY, function()
        if not CanContinue(run) then return end
        run.print(("BattleBuddy shots: %d/%d %s"):format(run.index, #run.views, view.name))
        if not shown then
            Advance(run)
            return
        end
        if not run.stepping then
            local ok = false
            if type(run.capture) == "function" then ok = pcall(run.capture) end
            run.stepping = not ok
        end
        if run.stepping then
            run.waiting = true
            run.print("BattleBuddy shots: " .. view.name .. "; press your screenshot key, then /bb dev next.")
            WaitForNext(run, run.index)
        else
            -- Screenshot captures at frame end, so keep this view until a later timer.
            run.schedule(SETTLE_DELAY, function() Advance(run) end)
        end
    end)
end

function Dev.RunShots(options)
    options = options or {}
    local output = options.print or print
    if not Dev.IsEnabled() then output(OFF_MESSAGE); return false end
    local inCombat = options.inCombat or InCombatLockdown
    if inCombat() then output("BattleBuddy shots: cannot run in combat."); return false end
    if active then output("BattleBuddy shots: a run is already active."); return false end
    if #views == 0 then output("BattleBuddy shots: no views registered."); return false end
    local run = {
        capture = options.capture,
        schedule = options.schedule or C_Timer.After,
        inCombat = inCombat,
        print = output,
        index = 1,
        views = {},
        shown = {},
        touched = {},
    }
    if run.capture == nil then run.capture = Screenshot end
    for index, view in ipairs(views) do run.views[index] = view end
    active = run
    for index, view in ipairs(run.views) do
        if type(view.isShown) == "function" then
            local ok, shown = Call(run, view, "isShown")
            run.shown[index] = ok and shown
        end
    end
    Step(run)
    return true
end

function Dev.Next()
    local run = active
    if not run then print("BattleBuddy shots: no run is active."); return end
    if not CanContinue(run) then return end
    if run.waiting then Advance(run) end
end

function Dev.Stop()
    if not active then print("BattleBuddy shots: no run is active."); return end
    Finish(active, "stopped")
end

function Dev.HandleCommand(command)
    if command == "on" or command == "off" then
        local enabled = command == "on"
        if BattleBuddyConfig.SetSetting("devTools", enabled) then
            print(enabled and "BattleBuddy dev tools are on." or OFF_MESSAGE)
        else
            print("BattleBuddy dev tools: settings are unavailable.")
        end
    elseif command == "shots" then
        Dev.RunShots()
    elseif command == "views" then
        if not Dev.IsEnabled() then print(OFF_MESSAGE); return end
        print("BattleBuddy dev views: " .. (#views == 0 and "no views registered." or table.concat(Dev.Views(), ", ")))
    elseif command == "next" then
        Dev.Next()
    elseif command == "stop" then
        Dev.Stop()
    elseif names[command] then
        if not Dev.IsEnabled() then print(OFF_MESSAGE); return end
        if InCombatLockdown() then print("BattleBuddy dev tools: cannot show views in combat."); return end
        for _, view in ipairs(views) do
            if view.name == command then view.show(); return end
        end
    else
        print("BattleBuddy dev: on, off, views, shots, next, stop.")
    end
end
