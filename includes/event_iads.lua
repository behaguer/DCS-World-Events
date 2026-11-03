-----------------[[ event_iads.lua ]]-----------------
---
--- IADS event spawning module
--- Spawns a small integrated air-defence network (SAM site(s) plus a bunker
--- command node) anchored on a red airdrome. Players must destroy every
--- tracked unit before the countdown expires.
---

--- Country used to spawn the IADS units. Change this if your red side isn't
--- Russia on the map/mod you're using.
WE.IADSCountry = country.id.RUSSIA

--- Number of SAM sites to place around the anchor. This ticket ships a single
--- Tor site; later work expands the composition.
WE.IADSSiteCount = 1

--- SAM unit types the event may place. This ticket only uses the first entry
--- (Tor); later work selects from the full Kub/Buk/Tor list.
WE.IADSSAMTypes = { "Tor 9A331" }

--- Skill level applied to every network unit.
WE.IADSSkill = "High"

--- Destructible ground unit used as the network command node.
WE.IADSCommandType = "Bunker"

--- Candidate sites sit between these distances (meters) from the anchor.
WE.IADSPlacementMin = 6000
WE.IADSPlacementMax = 18000

--- Sites must be at least this far (meters) from any runway of the anchor.
WE.IADSRunwayMinDistance = 3000

--- Maximum allowed height difference (meters) across a site footprint.
WE.IADSMaxSlope = 5

--- How long (seconds) the network mission lasts once spawned.
WE.IADSDurationSeconds = 900

--- How often (seconds) the countdown tick runs.
WE.IADSTickIntervalSeconds = 10

--- F10 disclosure mode. "area" places one mark at the anchor; other modes are
--- reserved for later work and currently fall back to the area mark.
WE.IADSMarkMode = "area"

--- Alert sound played when the event spawns.
WE.IADSSound = "attn_iads.ogg"

--- Secondary enable flag. The radio menu itself is driven by WE.EnabledEvents.
WE.IADSEnabled = true

--- The currently active IADS network (the event is single-instance).
WE.currentIADSEvent = nil

--- Counter used to make each spawn's group/unit names unique.
WE.iadsSpawnCounter = 0

--- Pick a red airdrome to anchor the network on. This ticket only considers
--- red airdromes; the neutral fallback arrives with the full network work.
--- @return Airbase|nil anchor airdrome
function WE.pickIADSAnchor()
    local _redAirdromes = WE.getAirdromes('red')
    if #_redAirdromes < 1 then
        WE.logWarning("pickIADSAnchor: no red airdromes available")
        return nil
    end
    return _redAirdromes[math.random(1, #_redAirdromes)]
end

--- Pick a legal site point in the placement band around the anchor: on land,
--- flat within WE.IADSMaxSlope, and at least WE.IADSRunwayMinDistance from the
--- anchor's runways.
--- @param _anchor Airbase anchor airdrome
--- @param _runwaySegments table|nil runway segments for the anchor
--- @return table|nil site point {x, y, z}
function WE.pickIADSSitePoint(_anchor, _runwaySegments)
    local _anchorPoint = _anchor:getPoint()
    local _point = WE.randomLandPoint(_anchorPoint.x, _anchorPoint.z,
        WE.IADSPlacementMin, WE.IADSPlacementMax, 10)
    if not _point then
        return nil
    end

    _point.y = land.getHeight({ x = _point.x, y = _point.z })
    if WE.minDistanceToRunway(_runwaySegments, _point) < WE.IADSRunwayMinDistance then
        return nil
    end
    if not WE.isPointFlat(_point, 30, WE.IADSMaxSlope) then
        return nil
    end
    return _point
end

--- Pick a legal land point for the command node near the anchor. The anchor
--- reference point often sits on pavement, so fall back to a nearby land point.
--- @param _anchor Airbase anchor airdrome
--- @return table|nil command point {x, y, z}
function WE.pickIADSCommandPoint(_anchor)
    local _anchorPoint = _anchor:getPoint()
    local _candidates = { { x = _anchorPoint.x, z = _anchorPoint.z } }

    local _randomPoint = WE.randomLandPoint(_anchorPoint.x, _anchorPoint.z, 300, 1500, 10)
    if _randomPoint then
        table.insert(_candidates, _randomPoint)
    end

    for _, _candidate in ipairs(_candidates) do
        local _point = { x = _candidate.x, y = 0, z = _candidate.z }
        if WE.isPointOnLand(_point) then
            _point.y = land.getHeight({ x = _point.x, y = _point.z })
            if WE.isPointFlat(_point, 30, WE.IADSMaxSlope) then
                return _point
            end
        end
    end
    return nil
end

--- Spawn a stationary ground group for the IADS network.
--- @param _groupName string unique group name
--- @param _x number east coordinate
--- @param _z number north coordinate
--- @param _units table unit definitions
--- @param _logLabel string label used in log lines
--- @return Group|nil spawned group
function WE.spawnIADSGroundGroup(_groupName, _x, _z, _units, _logLabel)
    local _group = coalition.addGroup(WE.IADSCountry, Group.Category.GROUND,
        WE.buildStationaryGroundGroup(_groupName, WE.getNextGroupId(), _x, _z, _units))
    if _group then
        WE.logInfo("IADS %s spawned: %s (group id %s)", _logLabel, _groupName, tostring(_group:getID()))
    else
        WE.logError("Failed to spawn IADS %s: %s", _logLabel, _groupName)
    end
    return _group
end

--- Spawn one SAM site group.
--- @param _siteIndex number 1-based site index within this spawn
--- @param _samType string DCS unit type
--- @param _point table site point {x, y, z}
--- @param _spawnId number per-spawn counter used to make names unique
--- @return Group|nil spawned group
--- @return string|nil tracked unit name
function WE.spawnIADSSite(_siteIndex, _samType, _point, _spawnId)
    local _groupName = string.format("IADS_Site_%d_%d", _spawnId, _siteIndex)
    local _unitName = string.format("IADS_Site_%d_%d_1", _spawnId, _siteIndex)
    local _group = WE.spawnIADSGroundGroup(_groupName, _point.x, _point.z, {
        [1] = WE.buildGroundUnit(_unitName, _samType, _point.x, _point.z,
            math.random(0, 360), WE.IADSSkill),
    }, "site")
    if not _group then
        return nil, nil
    end
    return _group, _unitName
end

--- Spawn the bunker command node group.
--- @param _point table command point {x, y, z}
--- @param _spawnId number per-spawn counter used to make names unique
--- @return Group|nil spawned group
--- @return string|nil tracked unit name
function WE.spawnIADSCommandNode(_point, _spawnId)
    local _groupName = string.format("IADS_Command_%d", _spawnId)
    local _unitName = string.format("IADS_Command_%d_1", _spawnId)
    local _group = WE.spawnIADSGroundGroup(_groupName, _point.x, _point.z, {
        [1] = WE.buildGroundUnit(_unitName, WE.IADSCommandType, _point.x, _point.z, 0, WE.IADSSkill),
    }, "command node")
    if not _group then
        return nil, nil
    end
    return _group, _unitName
end

--- Count how many tracked sites still have at least one living unit.
--- @param _eventData table IADS event data
--- @return number alive site count
function WE.countAliveIADSSites(_eventData)
    if not _eventData or not _eventData.sites then
        return 0
    end

    local _alive = 0
    for _, _site in ipairs(_eventData.sites) do
        local _unit = _site.unitName and Unit.getByName(_site.unitName)
        if _unit and _unit:isExist() and _unit:getLife() > 0 then
            _alive = _alive + 1
        end
    end
    return _alive
end

--- End the IADS event (success or timeout) and clean up its shared state.
--- On timeout the surviving network units are intentionally left alive.
--- @param _eventData table IADS event data
--- @param _result string "SUCCESS" or "FAILURE"
function WE.endIADSEvent(_eventData, _result)
    if not _eventData or _eventData.ended then
        return
    end
    _eventData.ended = true

    if _eventData.markId then
        trigger.action.removeMark(_eventData.markId)
    end

    if _result == "SUCCESS" then
        trigger.action.outText("SUCCESS: The IADS network has been dismantled!", 10)
    else
        trigger.action.outText(string.format(
            "MISSION FAILED: Time ran out near %s! Surviving IADS units remain active.", _eventData.area), 10)
    end

    if WE.currentIADSEvent == _eventData then
        WE.currentIADSEvent = nil
    end
    WE.is_active = 0
    WE.logInfo("IADS event ended - result: %s near %s", tostring(_result), tostring(_eventData.area))
end

--- Periodic countdown tick: announces the remaining whole minutes when the
--- value changes, fails the event on timeout, and returns nil once it has ended.
--- @return number|nil next check time, or nil to stop the timer
function WE.iadsTick()
    local _eventData = WE.currentIADSEvent
    if not _eventData or _eventData.ended then
        return nil
    end

    local _now = timer.getTime()
    local _remaining = _eventData.endsAt - _now
    if _remaining <= 0 then
        WE.endIADSEvent(_eventData, "FAILURE")
        return nil
    end

    local _remainingMinutes = math.ceil(_remaining / 60)
    if _eventData.lastAnnouncedMinutes == nil or _remainingMinutes < _eventData.lastAnnouncedMinutes then
        _eventData.lastAnnouncedMinutes = _remainingMinutes
        if _remainingMinutes > 0 then
            trigger.action.outText(string.format(
                "IADS countdown: %d minute(s) remaining (near %s)!", _remainingMinutes, _eventData.area), 10)
        end
    end

    return _now + WE.IADSTickIntervalSeconds
end

--- Spawn the IADS network event.
function WE.EVENT.IADS()
    WE.logInfo("IADS event triggered")

    if not WE.IADSEnabled then
        trigger.action.outText("The IADS event is disabled.", 10)
        WE.logInfo("IADS spawn cancelled - disabled in config")
        return
    end

    if WE.is_active == 1 or WE.currentIADSEvent then
        trigger.action.outText("A World Event is already active! Check Event Status for details.", 10)
        WE.logInfo("IADS spawn cancelled - another event already active")
        return
    end

    local _anchor = WE.pickIADSAnchor()
    if not _anchor then
        trigger.action.outText("IADS event could not start: no red airdrome available on this map!", 10)
        WE.logError("IADS: no red airdrome anchor - event cancelled")
        return
    end

    local _areaName = _anchor:getName()
    local _runwaySegments = WE.getRunwaySegments(_anchor)

    local _commandPoint = WE.pickIADSCommandPoint(_anchor)
    if not _commandPoint then
        trigger.action.outText(string.format(
            "IADS event could not start: no legal command-node location near %s!", _areaName), 10)
        WE.logError("IADS: no command-node location near %s - event cancelled", tostring(_areaName))
        return
    end

    local _samTypes = WE.IADSSAMTypes or {}
    if #_samTypes < 1 then
        trigger.action.outText("IADS event could not start: no SAM types configured!", 10)
        WE.logError("IADS: WE.IADSSAMTypes is empty - event cancelled")
        return
    end
    local _samType = _samTypes[1]

    local _siteCount = math.max(1, WE.IADSSiteCount or 1)
    local _sitePoints = {}
    for _i = 1, _siteCount do
        local _point = WE.pickIADSSitePoint(_anchor, _runwaySegments)
        if not _point then
            trigger.action.outText(string.format(
                "IADS event could not start: no legal SAM site location near %s!", _areaName), 10)
            WE.logError("IADS: no site location near %s - event cancelled", tostring(_areaName))
            return
        end
        table.insert(_sitePoints, _point)
    end

    WE.iadsSpawnCounter = WE.iadsSpawnCounter + 1
    local _spawnId = WE.iadsSpawnCounter

    local _groups = {}
    local _unitNames = {}
    local _sites = {}

    for _i, _point in ipairs(_sitePoints) do
        local _group, _unitName = WE.spawnIADSSite(_i, _samType, _point, _spawnId)
        if not _group then
            WE.destroyGroupList(_groups)
            trigger.action.outText("Failed to spawn the IADS SAM site!", 10)
            return
        end
        table.insert(_groups, _group)
        _unitNames[_unitName] = true
        table.insert(_sites, {
            type = _samType,
            group = _group,
            unitName = _unitName,
            point = _point,
        })
    end

    local _commandGroup, _commandUnitName = WE.spawnIADSCommandNode(_commandPoint, _spawnId)
    if not _commandGroup then
        WE.destroyGroupList(_groups)
        trigger.action.outText("Failed to spawn the IADS command node!", 10)
        return
    end
    table.insert(_groups, _commandGroup)
    _unitNames[_commandUnitName] = true

    local _now = timer.getTime()
    local _markId = WE.getNextMarkId()
    local _eventData = {
        area = _areaName,
        point = _anchor:getPoint(),
        airbase = _anchor,
        sites = _sites,
        groups = _groups,
        unitNames = _unitNames,
        spawnId = _spawnId,
        spawnedAt = _now,
        endsAt = _now + WE.IADSDurationSeconds,
        markId = _markId,
        lastAnnouncedMinutes = nil,
        ended = false,
    }
    WE.currentIADSEvent = _eventData
    WE.is_active = 1

    if WE.IADSMarkMode ~= "area" then
        WE.logWarning("IADS: unsupported mark mode '%s', using area mark", tostring(WE.IADSMarkMode))
    end
    trigger.action.markToAll(_markId,
        string.format("Suspected SIGINT activity near %s", _areaName),
        _eventData.point)

    timer.scheduleFunction(WE.iadsTick, nil, _now + WE.IADSTickIntervalSeconds)

    local _minutes = math.ceil(WE.IADSDurationSeconds / 60)
    trigger.action.outText(string.format(
        "IADS is active near %s! Destroy every network unit within %d minutes!\nF10: suspected SIGINT activity is marked near the area.",
        _areaName, _minutes), 20)
    trigger.action.outSound(WE.IADSSound)

    WE.logInfo("IADS event spawned near %s: %d site(s), 1 command node, %d tracked unit(s)",
        tostring(_areaName), #_sites, WE.countTableEntries(_unitNames))
end

WE.registerEventStatus("IADS", function()
    local _eventData = WE.currentIADSEvent
    if not _eventData or _eventData.ended then
        return nil
    end

    local _remaining = math.max(0, math.ceil(_eventData.endsAt - timer.getTime()))
    return string.format("IADS: %d site(s) active near %s, %d seconds remaining.",
        WE.countAliveIADSSites(_eventData), tostring(_eventData.area), _remaining)
end)

--- Event handler table for the IADS event.
WE.EVENT.IADSEVENT = {}

--- DCS event handler: resolves the network once every tracked unit is dead.
--- @param event table DCS world event
function WE.EVENT.IADSEVENT:onEvent(event)
    if not event then return end
    if event.id ~= world.event.S_EVENT_DEAD then return end

    local _eventData = WE.currentIADSEvent
    if not _eventData or _eventData.ended then return end
    if not event.initiator then return end

    local _unit = event.initiator
    if not _unit.getName or type(_unit.getName) ~= "function" then return end

    local _name = _unit:getName()
    if not _eventData.unitNames[_name] then return end

    WE.logInfo("IADS: %s destroyed, checking remaining units near %s",
        _name, tostring(_eventData.area))

    if WE.areAllUnitsDead(_eventData.unitNames) then
        WE.endIADSEvent(_eventData, "SUCCESS")
    end
end

world.addEventHandler(WE.EVENT.IADSEVENT)

-----------------[[ END OF event_iads.lua ]]-----------------
