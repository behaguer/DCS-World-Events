-----------------[[ event_iads.lua ]]-----------------
---
--- IADS event spawning module
--- Spawns an integrated air-defence network (SAM sites, an early-warning
--- radar, and a bunker command node) anchored on a red airdrome. Players must
--- destroy every tracked unit before the countdown expires.
---

--- Country used to spawn the IADS units. Change this if your red side isn't
--- Russia on the map/mod you're using.
WE.IADSCountry = country.id.RUSSIA

--- Number of SAM sites to place around the anchor.
WE.IADSSiteCount = 3

--- SAM site compositions the event may place, chosen at random with repeats
--- allowed. Each entry is one functional group: `units` lists the DCS unit
--- types that must spawn together inside that group.
WE.IADSSAMTypes = {
    {
        name = "Kub",
        units = { "Kub 1S91 str", "Kub 2P25 ln", "Kub 2P25 ln" },
    },
    {
        name = "Buk",
        units = { "SA-11 Buk CC 9S470M1", "SA-11 Buk SR 9S18M1", "SA-11 Buk LN 9A310M1" },
    },
    {
        name = "Tor",
        units = { "Tor 9A331" },
    },
}

--- Skill level applied to every network unit.
WE.IADSSkill = "High"

--- Destructible ground unit used as the network command node.
WE.IADSCommandType = "Bunker"

--- Independent early-warning radar placed in the network band.
WE.IADSRadarType = "55G6 EWR"

--- Candidate sites sit between these distances (meters) from the anchor.
WE.IADSPlacementMin = 6000
WE.IADSPlacementMax = 18000

--- Sites must be at least this far (meters) from any runway of the anchor.
WE.IADSRunwayMinDistance = 3000

--- Sites and the radar must be at least this far (meters) apart.
WE.IADSSiteMinDistance = 3000

--- Network points must be at least this far (meters) from any Blue airdrome.
WE.IADSBlueBaseMinDistance = 5000

--- Maximum allowed height difference (meters) across a site footprint.
WE.IADSMaxSlope = 5

--- Placement attempts made for each site and for the radar.
WE.IADSPlacementAttempts = 8

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

--- Pick an airdrome to anchor the network on. Red airdromes are preferred;
--- neutral airdromes are used only when the map has no red airdrome. Blue
--- airdromes are never used.
--- @return Airbase|nil anchor airdrome
function WE.pickIADSAnchor()
    local _redAirdromes = WE.getAirdromes('red')
    if #_redAirdromes > 0 then
        return _redAirdromes[math.random(1, #_redAirdromes)]
    end

    local _neutralAirdromes = WE.getAirdromes('neutral')
    if #_neutralAirdromes > 0 then
        WE.logWarning("pickIADSAnchor: no red airdromes available, falling back to neutral")
        return _neutralAirdromes[math.random(1, #_neutralAirdromes)]
    end

    WE.logWarning("pickIADSAnchor: no red or neutral airdromes available")
    return nil
end

--- Check a candidate network point against the Blue airdrome spacing rule.
--- @param _point table candidate point {x, y, z}
--- @param _blueAirdromes table list of Blue airdrome objects
--- @return boolean true when the point is far enough from every Blue airdrome
function WE.isIADSPointClearOfBlueBases(_point, _blueAirdromes)
    for _, _base in ipairs(_blueAirdromes) do
        local _basePoint = _base:getPoint()
        if _basePoint and WE.getDistance(_point, _basePoint) < WE.IADSBlueBaseMinDistance then
            return false
        end
    end
    return true
end

--- Check a candidate network point against the spacing rule for points that
--- have already been placed (other sites and the radar).
--- @param _point table candidate point {x, y, z}
--- @param _placedPoints table list of already placed points
--- @return boolean true when the point is far enough from every placed point
function WE.isIADSPointClearOfSites(_point, _placedPoints)
    for _, _placed in ipairs(_placedPoints) do
        if WE.getDistance(_point, _placed) < WE.IADSSiteMinDistance then
            return false
        end
    end
    return true
end

--- Pick a legal network point in the placement band around the anchor: on
--- land, flat within WE.IADSMaxSlope, clear of the anchor's runways, clear of
--- every Blue airdrome, and spaced apart from points already placed.
--- @param _anchor Airbase anchor airdrome
--- @param _runwaySegments table|nil runway segments for the anchor
--- @param _blueAirdromes table list of Blue airdrome objects
--- @param _placedPoints table list of already placed network points
--- @return table|nil point {x, y, z}
function WE.pickIADSNetworkPoint(_anchor, _runwaySegments, _blueAirdromes, _placedPoints)
    local _anchorPoint = _anchor:getPoint()
    local _attempts = math.max(1, WE.IADSPlacementAttempts or 1)
    for _ = 1, _attempts do
        local _point = WE.randomLandPoint(_anchorPoint.x, _anchorPoint.z,
            WE.IADSPlacementMin, WE.IADSPlacementMax, 10)
        if _point then
            _point.y = land.getHeight({ x = _point.x, y = _point.z })
            if WE.minDistanceToRunway(_runwaySegments, _point) >= WE.IADSRunwayMinDistance
                and WE.isPointFlat(_point, 50, WE.IADSMaxSlope)
                and WE.isIADSPointClearOfBlueBases(_point, _blueAirdromes)
                and WE.isIADSPointClearOfSites(_point, _placedPoints) then
                return _point
            end
        end
    end
    return nil
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

--- Return the local x/z offset (meters) for one unit inside a site group. The
--- first unit sits at the site point and the rest form a small ring around it.
--- @param _index number 1-based unit index within the site
--- @param _count number total number of units in the site
--- @return number x offset
--- @return number z offset
function WE.getIADSUnitOffset(_index, _count)
    if _index == 1 or _count <= 1 then
        return 0, 0
    end

    local _angle = (2 * math.pi * (_index - 2)) / (_count - 1)
    local _radius = 35
    return math.cos(_angle) * _radius, math.sin(_angle) * _radius
end

--- Spawn one SAM site as a single functional group. All of the site's units
--- are placed at small local offsets around the site point.
--- @param _siteIndex number 1-based site index within this spawn
--- @param _siteDef table SAM site definition {name, units}
--- @param _point table site point {x, y, z}
--- @param _spawnId number per-spawn counter used to make names unique
--- @return Group|nil spawned group
--- @return table|nil tracked unit names for this site
function WE.spawnIADSSite(_siteIndex, _siteDef, _point, _spawnId)
    local _groupName = string.format("IADS_Site_%d_%d", _spawnId, _siteIndex)
    local _unitNames = {}
    local _units = {}

    for _unitIndex, _unitType in ipairs(_siteDef.units) do
        local _unitName = string.format("IADS_Site_%d_%d_%d", _spawnId, _siteIndex, _unitIndex)
        local _offsetX, _offsetZ = WE.getIADSUnitOffset(_unitIndex, #_siteDef.units)
        _units[_unitIndex] = WE.buildGroundUnit(_unitName, _unitType,
            _point.x + _offsetX, _point.z + _offsetZ, math.random(0, 360), WE.IADSSkill)
        table.insert(_unitNames, _unitName)
    end

    local _group = WE.spawnIADSGroundGroup(_groupName, _point.x, _point.z, _units,
        string.format("%s site", tostring(_siteDef.name)))
    if not _group then
        return nil, nil
    end
    return _group, _unitNames
end

--- Spawn the independent early-warning radar group.
--- @param _point table radar point {x, y, z}
--- @param _spawnId number per-spawn counter used to make names unique
--- @return Group|nil spawned group
--- @return string|nil tracked unit name
function WE.spawnIADSRadar(_point, _spawnId)
    local _groupName = string.format("IADS_Radar_%d", _spawnId)
    local _unitName = string.format("IADS_Radar_%d_1", _spawnId)
    local _group = WE.spawnIADSGroundGroup(_groupName, _point.x, _point.z, {
        [1] = WE.buildGroundUnit(_unitName, WE.IADSRadarType, _point.x, _point.z,
            math.random(0, 360), WE.IADSSkill),
    }, "radar")
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
        local _siteAlive = false
        for _, _unitName in ipairs(_site.unitNames or {}) do
            local _unit = Unit.getByName(_unitName)
            if _unit and _unit:isExist() and _unit:getLife() > 0 then
                _siteAlive = true
                break
            end
        end
        if _siteAlive then
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

--- Cancel an in-progress IADS spawn. Destroys any groups already placed,
--- removes a mark if one was placed, stops a scheduled tick if one was started,
--- and releases the event state and global lock.
--- @param _groups table|nil groups spawned so far
--- @param _markId number|nil mark id placed so far
--- @param _timerHandle number|nil scheduled tick handle
function WE.cancelIADSSpawn(_groups, _markId, _timerHandle)
    WE.destroyGroupList(_groups)
    if _markId then
        trigger.action.removeMark(_markId)
    end
    if _timerHandle and type(timer.removeFunction) == "function" then
        timer.removeFunction(_timerHandle)
    end
    WE.currentIADSEvent = nil
    WE.is_active = 0
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
        trigger.action.outText("IADS event could not start: no red or neutral airdrome available on this map!", 10)
        WE.logError("IADS: no legal anchor airdrome - event cancelled")
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
        trigger.action.outText("IADS event could not start: no SAM site types configured!", 10)
        WE.logError("IADS: WE.IADSSAMTypes is empty - event cancelled")
        return
    end
    for _, _siteDef in ipairs(_samTypes) do
        if not _siteDef.units or #_siteDef.units < 1 then
            trigger.action.outText("IADS event could not start: a SAM site type has no units configured!", 10)
            WE.logError("IADS: SAM site type '%s' has no units - event cancelled", tostring(_siteDef.name))
            return
        end
    end

    local _blueAirdromes = WE.getAirdromes('blue')
    local _siteCount = math.max(1, WE.IADSSiteCount or 1)

    WE.iadsSpawnCounter = WE.iadsSpawnCounter + 1
    local _spawnId = WE.iadsSpawnCounter

    local _groups = {}
    local _unitNames = {}
    local _sites = {}
    local _placedPoints = {}

    local _commandGroup, _commandUnitName = WE.spawnIADSCommandNode(_commandPoint, _spawnId)
    if not _commandGroup then
        WE.cancelIADSSpawn(_groups, nil, nil)
        trigger.action.outText("Failed to spawn the IADS command node!", 10)
        return
    end
    table.insert(_groups, _commandGroup)
    _unitNames[_commandUnitName] = true

    for _i = 1, _siteCount do
        local _point = WE.pickIADSNetworkPoint(_anchor, _runwaySegments, _blueAirdromes, _placedPoints)
        if not _point then
            WE.logWarning("IADS: no legal location for site %d of %d near %s - skipping site",
                _i, _siteCount, tostring(_areaName))
        else
            local _siteDef = _samTypes[math.random(1, #_samTypes)]
            local _group, _unitNameList = WE.spawnIADSSite(_i, _siteDef, _point, _spawnId)
            if not _group then
                WE.logWarning("IADS: site %d failed to spawn near %s - skipping site",
                    _i, tostring(_areaName))
            else
                table.insert(_groups, _group)
                for _, _unitName in ipairs(_unitNameList) do
                    _unitNames[_unitName] = true
                end
                table.insert(_sites, {
                    type = _siteDef.name,
                    group = _group,
                    unitNames = _unitNameList,
                    point = _point,
                })
                table.insert(_placedPoints, _point)
            end
        end
    end

    if #_sites == 0 then
        WE.cancelIADSSpawn(_groups, nil, nil)
        trigger.action.outText(string.format(
            "IADS event could not start: no legal SAM site location near %s!", _areaName), 10)
        WE.logError("IADS: no site location near %s - event cancelled", tostring(_areaName))
        return
    end

    local _radarSpawned = false
    local _radarPoint = WE.pickIADSNetworkPoint(_anchor, _runwaySegments, _blueAirdromes, _placedPoints)
    if not _radarPoint then
        WE.logWarning("IADS: no legal radar location near %s - continuing without radar",
            tostring(_areaName))
    else
        local _radarGroup, _radarUnitName = WE.spawnIADSRadar(_radarPoint, _spawnId)
        if not _radarGroup then
            WE.logWarning("IADS: radar failed to spawn near %s - continuing without radar",
                tostring(_areaName))
        else
            table.insert(_groups, _radarGroup)
            _unitNames[_radarUnitName] = true
            _radarSpawned = true
        end
    end

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

    WE.logInfo("IADS event spawned near %s: %d site(s), %s, 1 command node, %d tracked unit(s)",
        tostring(_areaName), #_sites, _radarSpawned and "1 radar" or "no radar",
        WE.countTableEntries(_unitNames))
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
