-----------------[[ autorun.lua ]]-----------------
---
--- Automatic event scheduling
--- When WE.AutoRunEnabled is true, a random enabled event is spawned every
--- WE.AutoRunIntervalMinutes minutes, but only while no event is active. With
--- the flag false this module is inert and events spawn only from the radio menu.
---

--- Pick a random enabled event that has a spawn function.
--- @return string|nil event key
function WE.pickAutoRunEvent()
    local _candidates = {}
    for _, _eventName in ipairs(WE.getEnabledEventNames()) do
        if type(WE.EVENT[_eventName]) == "function" then
            table.insert(_candidates, _eventName)
        end
    end

    if #_candidates == 0 then
        return nil
    end

    return _candidates[math.random(1, #_candidates)]
end

--- Interval between auto-run attempts, clamped to a 10 minute minimum.
--- @return number interval in seconds
function WE.getAutoRunIntervalSeconds()
    local _minutes = tonumber(WE.AutoRunIntervalMinutes) or 30
    return math.max(10, _minutes) * 60
end

--- Periodic auto-run tick. Spawns a random enabled event when nothing is
--- active, then always schedules the next attempt.
--- @return number|nil next tick time, or nil to stop the scheduler
function WE.autoRunTick()
    if not WE.AutoRunEnabled then
        WE.logInfo("Auto-run disabled - stopping scheduler")
        return nil
    end

    local _now = timer.getTime()

    if WE.is_active ~= 1 then
        local _eventName = WE.pickAutoRunEvent()
        if _eventName then
            WE.logInfo("Auto-run spawning event '%s'", _eventName)
            local _ok, _err = pcall(WE.EVENT[_eventName])
            if not _ok then
                WE.logError("Auto-run event '%s' failed: %s", _eventName, tostring(_err))
            end
        end
    end

    return _now + WE.getAutoRunIntervalSeconds()
end

--- Start the auto-run scheduler when enabled. The first attempt happens one
--- full interval after mission load.
function WE.initializeAutoRun()
    if not WE.AutoRunEnabled then
        WE.logInfo("Auto-run disabled - events spawn via the radio menu")
        return
    end

    local _intervalSeconds = WE.getAutoRunIntervalSeconds()
    WE.logInfo("Auto-run enabled - first attempt in %d minute(s), then every %d minute(s)",
        math.floor(_intervalSeconds / 60), math.floor(_intervalSeconds / 60))
    timer.scheduleFunction(WE.autoRunTick, nil, timer.getTime() + _intervalSeconds)
end

-----------------[[ END OF autorun.lua ]]-----------------
