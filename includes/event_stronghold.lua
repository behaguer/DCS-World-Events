-----------------[[ event_stronghold.lua ]]-----------------
---
--- Stronghold event spawning module
--- Spawns a red stronghold (a destructible building defended by ground troops
--- and a short-range SAM) at a random location when triggered by the radio menu.
--- Players must destroy the stronghold AND every defender before the countdown
--- timer reaches zero, otherwise the mission is a failure.
---

--- Country used to spawn the Stronghold units. Change this if your red side
--- isn't Russia on the map/mod you're using.
WE.StrongholdCountry = country.id.RUSSIA

--- How long (seconds) the stronghold mission lasts once it has been spawned.
--- The mission fails if the timer reaches 0 before the stronghold is destroyed.
WE.StrongholdDurationSeconds = 600

--- Allow more than one Stronghold mission to run at the same time. When false
--- only a single stronghold may be active, matching the rest of the World
--- Events framework. When true the user can spawn several missions and the
--- global WE.is_active flag stays set while ANY of them is running.
WE.StrongholdAllowMultiple = true

--- Maximum number of Stronghold missions that can be active at the same time.
--- Only used when StrongholdAllowMultiple is true.
WE.StrongholdMaxConcurrent = 5

--- DCS unit type used for the stronghold building itself. It is spawned as a
--- ground fortification unit (not a static object) so its destruction can be
--- detected and tracked via S_EVENT_DEAD.
WE.StrongholdBuildingType = "Bunker"

--- Short-range SAM defending the stronghold.
WE.StrongholdSAMType = "Strela-10M3"

--- Infantry type and count defending the stronghold.
WE.StrongholdInfantryType = "Infantry AK"
WE.StrongholdInfantryCount = 4

--- The stronghold is placed at a random offset (meters) from a random airdrome
--- (red or neutral), so it works on any map and has flat-ish ground to sit on.
--- The minimum keeps the bunker at least 2.5 nautical miles (4630 m) from the
--- airfield so its defenders never end up on the runway.
WE.StrongholdOffsetMin = 4630
WE.StrongholdOffsetMax = 7408

--- The stronghold spawn zone must be at least this far (meters) from any runway
--- of the chosen airdrome (2.5 nm). Measured perpendicular to the full runway
--- segment (not just its ends) so it holds even on maps with long runways.
WE.StrongholdRunwayMinDistance = 4630

--- Maximum allowed height difference (meters) across the stronghold's footprint
--- (sampled a short distance around the spawn point). Points on steeper terrain
--- (cliffs, ravines) are rejected so the bunker and vehicles sit on flat ground.
WE.StrongholdMaxSlope = 3

--- Tanks / APCs / SAM sites spawned to defend the airfield after a failed
--- stronghold, when there are not enough red units already nearby.
WE.StrongholdDefenseTankType = "T-72B3"
WE.StrongholdDefenseTankCount = 3
WE.StrongholdDefenseAPCType = "BTR-80"
WE.StrongholdDefenseAPCCount = 2
WE.StrongholdDefenseSAMType = "Strela-10M3"
WE.StrongholdDefenseSAMCount = 2

--- Radius (meters) around the airfield used to count red units already
--- stationed there; defenses are only spawned when fewer than
--- StrongholdDefenseMinRedUnits red ground units are found within it. The
--- stronghold's own garrison is excluded from the count.
WE.StrongholdDefenseRadius = 5000
WE.StrongholdDefenseMinRedUnits = 4

--- Defense units spawn at a random bearing, between these distances (meters)
--- from the airfield.
WE.StrongholdDefenseSpawnMin = 300
WE.StrongholdDefenseSpawnMax = 1500

--- List of currently active Stronghold events (one entry per mission). Each
--- entry holds its own area, position, spawned units and countdown state so
--- several missions can run at once.
WE.activeStrongholdEvents = {}

--- Counter used to make each spawn's group/unit names unique (DCS rejects
--- duplicate names) and to generate a unique negative F10 mark id.
WE.strongholdSpawnCounter = 0

--- Check whether a point is usable as a stronghold spawn: it must not be water,
--- must not be paved airfield surface, and must not be on a road. DCS reports
--- runways, taxiways, ramps and aprons all as land.SurfaceType.RUNWAY, and roads
--- as land.SurfaceType.ROAD, so this check alone guarantees the stronghold never
--- spawns on any pavement.
--- @param _point table point {x, y, z}
--- @return boolean true when the point is not water and not paved
function WE.isPointOnLand(_point)
    local _surfaceType = land.getSurfaceType({ x = _point.x, y = _point.z })
    if not _surfaceType then
        return false
    end
    if _surfaceType == land.SurfaceType.WATER or _surfaceType == land.SurfaceType.SHALLOW_WATER then
        return false
    end
    if land.SurfaceType.RUNWAY and _surfaceType == land.SurfaceType.RUNWAY then
        return false
    end
    if land.SurfaceType.ROAD and _surfaceType == land.SurfaceType.ROAD then
        return false
    end
    return true
end

--- Check that the terrain around _point is flat enough for the stronghold to sit
--- on (no cliffs, ravines or steep slopes). Samples the terrain height at the
--- point and at a small offset in each direction.
--- @param _point table point {x, y, z}
--- @param _sampleRadius number distance (meters) to sample around the point
--- @return boolean true when the terrain is flat enough
function WE.isPointFlat(_point, _sampleRadius)
    _sampleRadius = _sampleRadius or 30
    local _height = land.getHeight({ x = _point.x, y = _point.z })
    local _offsets = {
        { _sampleRadius, 0 },
        { -_sampleRadius, 0 },
        { 0, _sampleRadius },
        { 0, -_sampleRadius },
    }
    for _, _offset in ipairs(_offsets) do
        local _sampleHeight = land.getHeight({ x = _point.x + _offset[1], y = _point.z + _offset[2] })
        if math.abs(_sampleHeight - _height) > WE.StrongholdMaxSlope then
            return false
        end
    end
    return true
end

--- Pick a random point between _min and _max meters from (_x, _z) on a random
--- bearing that is on land (not water).
--- @param _x number anchor east coordinate
--- @param _z number anchor north coordinate
--- @param _min number minimum distance in meters
--- @param _max number maximum distance in meters
--- @param _attempts number retry attempts (default 10)
--- @return table|nil point {x, y, z}, or nil when no land point was found
function WE.randomLandPoint(_x, _z, _min, _max, _attempts)
    _attempts = _attempts or 10
    if _min > _max then
        WE.logWarning("randomLandPoint: _min (%d) > _max (%d), swapping", _min, _max)
        _min, _max = _max, _min
    end
    local _point = { x = _x, y = 0, z = _z }
    for _ = 1, _attempts do
        local _bearing = math.random() * math.pi * 2
        local _distance = math.random(_min, _max)
        _point.x = _x + math.cos(_bearing) * _distance
        _point.z = _z + math.sin(_bearing) * _distance
        if WE.isPointOnLand(_point) then
            return _point
        end
    end
    return nil
end

--- Random offset within _maxOffset meters of (_x, _z) that is on land. Falls
--- back to the anchor point when no land offset is found.
--- @param _x number anchor east coordinate
--- @param _z number anchor north coordinate
--- @param _maxOffset number maximum offset in meters
--- @return number x, number z
function WE.randomLandOffsetNear(_x, _z, _maxOffset)
    for _ = 1, 5 do
        local _ux = _x + math.random(-_maxOffset, _maxOffset)
        local _uz = _z + math.random(-_maxOffset, _maxOffset)
        if WE.isPointOnLand({ x = _ux, y = 0, z = _uz }) then
            return _ux, _uz
        end
    end
    return _x, _z
end

--- Build a set of airdrome NAMES that already host an active stronghold mission
--- so a new mission never doubles up on the same airfield. Keyed by name rather
--- than the Airbase object because DCS may return fresh object wrappers on each
--- query.
--- @return table set of used airdrome names
function WE.getUsedStrongholdAirdromes()
    local _used = {}
    for _, _eventData in ipairs(WE.activeStrongholdEvents) do
        local _base = _eventData.airbase
        if _base and _base.getName and type(_base.getName) == "function" then
            _used[_base:getName()] = true
        end
    end
    return _used
end

--- Pick a random point near a random airdrome to place the stronghold.
--- Only red and neutral airdromes are used so the stronghold never sits on
--- a blue (player) airfield, and airdromes that already host an active
--- stronghold mission are excluded so no two missions share an airfield.
--- Points in water, closer than StrongholdRunwayMinDistance to any runway of
--- the airdrome, or on terrain steeper than StrongholdMaxSlope are retried.
--- @return table|nil stronghold point {x, y, z} (y = terrain height)
--- @return string|nil name of the airdrome the stronghold is anchored near
--- @return Airbase|nil the airdrome the stronghold is anchored near
function WE.pickStrongholdLocation()
    local _usedAirdromes = WE.getUsedStrongholdAirdromes()

    local _allAirdromes = {}
    for _, _base in ipairs(WE.getAirdromes('red')) do
        if not _usedAirdromes[_base:getName()] then table.insert(_allAirdromes, _base) end
    end
    for _, _base in ipairs(WE.getAirdromes('neutral')) do
        if not _usedAirdromes[_base:getName()] then table.insert(_allAirdromes, _base) end
    end

    if #_allAirdromes < 1 then
        WE.logWarning("pickStrongholdLocation: no free airdromes (all already host an active stronghold), cannot place stronghold")
        return nil, nil, nil
    end

    for _ = 1, 10 do
        local _base = _allAirdromes[math.random(1, #_allAirdromes)]
        local _basePoint = _base:getPoint()
        local _runwaySegments = WE.getRunwaySegments(_base)
        for _ = 1, 15 do
            local _point = WE.randomLandPoint(_basePoint.x, _basePoint.z,
                WE.StrongholdOffsetMin, WE.StrongholdOffsetMax, 10)
            if _point and WE.minDistanceToRunway(_runwaySegments, _point) >= WE.StrongholdRunwayMinDistance then
                _point.y = land.getHeight({ x = _point.x, y = _point.z })
                if WE.isPointFlat(_point, 30) then
                    return _point, _base:getName(), _base
                end
            end
        end
    end

    WE.logWarning("pickStrongholdLocation: no suitable point (land, >= %.0fm from runways, flat) near any airdrome, cancelling stronghold",
        WE.StrongholdRunwayMinDistance)
    return nil, nil, nil
end

--- Extract a flat list of runway segments from an airbase. Each entry is a
--- { x1, z1, x2, z2, halfWidth } array, ready for repeated distance checks
--- without re-querying the airbase. Returns nil when there are no runways.
--- @param _airbase Airbase
--- @return table|nil list of runway segment arrays
function WE.getRunwaySegments(_airbase)
    if not _airbase.getRunways or type(_airbase.getRunways) ~= "function" then
        return nil
    end
    local _runways = _airbase:getRunways()
    if not _runways or #_runways == 0 then
        return nil
    end
    local _segments = {}
    for _, _runway in ipairs(_runways) do
        local _end1, _end2 = _runway.end1, _runway.end2
        if _end1 and _end2 then
            table.insert(_segments, {
                _end1.x, _end1.z, _end2.x, _end2.z, (_runway.width or 0) / 2,
            })
        end
    end
    if #_segments == 0 then
        return nil
    end
    return _segments
end

--- Minimum distance (meters) from a point to any runway segment produced by
--- WE.getRunwaySegments, measured perpendicular to each full segment and reduced
--- by its half width so the runway surface itself counts as distance 0. Returns
--- math.huge when _segments is nil (no runway to avoid).
--- @param _segments table|nil runway segment list
--- @param _point table point {x, y, z}
--- @return number minimum distance in meters
function WE.minDistanceToRunway(_segments, _point)
    if not _segments then
        return math.huge
    end
    local _min = math.huge
    for _, _seg in ipairs(_segments) do
        local _distance = WE.distanceToSegmentXY(_seg[1], _seg[2], _seg[3], _seg[4], _point)
        _distance = math.max(0, _distance - _seg[5])
        if _distance < _min then
            _min = _distance
        end
    end
    return _min
end

--- Shortest distance (meters) from a point to a line segment, measured in the
--- horizontal x/z plane. Takes raw coordinates to avoid per-call table churn.
--- @param _ax number segment start x
--- @param _az number segment start z
--- @param _bx number segment end x
--- @param _bz number segment end z
--- @param _point table point {x, y, z}
--- @return number distance in meters
function WE.distanceToSegmentXY(_ax, _az, _bx, _bz, _point)
    local _dx = _bx - _ax
    local _dz = _bz - _az
    local _lenSq = _dx * _dx + _dz * _dz
    if _lenSq == 0 then
        local _dpx = _point.x - _ax
        local _dpz = _point.z - _az
        return math.sqrt(_dpx * _dpx + _dpz * _dpz)
    end

    local _t = ((_point.x - _ax) * _dx + (_point.z - _az) * _dz) / _lenSq
    if _t < 0 then
        _t = 0
    elseif _t > 1 then
        _t = 1
    end

    local _cx = _ax + _t * _dx
    local _cz = _az + _t * _dz
    local _dpx = _point.x - _cx
    local _dpz = _point.z - _cz
    return math.sqrt(_dpx * _dpx + _dpz * _dpz)
end

--- Build a stationary ground group table for DCS.
--- Ground group positions use x/y where y is the north coordinate.
--- @param _name string group name
--- @param _groupId number group id
--- @param _x number east coordinate
--- @param _z number north coordinate
--- @param _units table unit definitions
--- @return table ground group table
function WE.buildStationaryGroundGroup(_name, _groupId, _x, _z, _units)
    return {
        ["modulation"] = 0,
        ["tasks"] = {},
        ["task"] = "Ground Nothing",
        ["uncontrolled"] = false,
        ["hidden"] = false,
        ["route"] = {
            ["points"] = {
                [1] = {
                    ["name"] = "UNIT",
                    ["type"] = "Turning Point",
                    ["ETA"] = 0,
                    ["speed"] = 10,
                    ["task"] = {
                        ["id"] = "ComboTask",
                        ["params"] = { ["tasks"] = {} },
                    },
                    ["y"] = _z,
                    ["x"] = _x,
                },
            },
        },
        ["units"] = _units,
        ["y"] = _z,
        ["x"] = _x,
        ["name"] = _name,
        ["start_time"] = 0,
        ["groupId"] = _groupId,
    }
end

--- Spawn a stationary ground group and return it. Shared by all stronghold
--- spawns (building, SAM, infantry, defense) so the group table and the
--- success/failure logging only exist once.
--- @param _groupName string group name (must be unique per spawn)
--- @param _x number east coordinate
--- @param _z number north coordinate
--- @param _units table unit definitions for the group
--- @param _logLabel string label used in the spawn log line
--- @return Group|nil the spawned group, or nil when spawning failed
function WE.spawnStrongholdGroundGroup(_groupName, _x, _z, _units, _logLabel)
    local _groupObj = coalition.addGroup(WE.StrongholdCountry, Group.Category.GROUND,
        WE.buildStationaryGroundGroup(_groupName, WE.getNextGroupId(), _x, _z, _units))
    if _groupObj then
        WE.logInfo("Stronghold %s spawned: %s (group id %s)", _logLabel, _groupName, tostring(_groupObj:getID()))
    else
        WE.logError("Failed to spawn stronghold %s: %s", _logLabel, _groupName)
    end
    return _groupObj
end

--- Build a single-unit definition table for a stationary ground unit.
--- @param _unitName string unit name (must be unique per spawn)
--- @param _unitType string DCS unit type
--- @param _x number east coordinate
--- @param _z number north coordinate
--- @param _heading number heading in degrees
--- @return table unit definition
function WE.buildStrongholdUnit(_unitName, _unitType, _x, _z, _heading)
    return {
        ["type"] = _unitType,
        ["unitId"] = WE.getNextUnitId(),
        ["name"] = _unitName,
        ["x"] = _x,
        ["y"] = _z,
        ["heading"] = _heading,
        ["skill"] = "Excellent",
    }
end

--- Check whether every unit spawned for the stronghold has been destroyed.
--- @param _eventData table stronghold event data
--- @return boolean true when all tracked units are dead
function WE.areAllStrongholdUnitsDead(_eventData)
    for _name, _ in pairs(_eventData.unitNames) do
        local _unit = Unit.getByName(_name)
        if _unit and _unit:isExist() and _unit:getLife() > 0 then
            return false
        end
    end
    return true
end

--- Count alive red GROUND units within _radius meters of _point, excluding any
--- units whose names appear in _excludedNames (e.g. the stronghold's own
--- garrison). Used to decide whether the captured airfield already has red
--- units stationed at it and therefore doesn't need extra defenders.
--- @param _point table point {x, y, z}
--- @param _radius number search radius in meters
--- @param _excludedNames table|nil set of unit names to skip
--- @return number alive red ground unit count
function WE.countRedGroundUnitsNear(_point, _radius, _excludedNames)
    local _count = 0
    local _groups = coalition.getGroups(coalition.side.RED, Group.Category.GROUND)
    if not _groups then return 0 end

    for _, _group in pairs(_groups) do
        if _group and _group:isExist() then
            local _units = _group:getUnits()
            for _, _unit in pairs(_units) do
                if _unit and _unit:isExist() and _unit:getLife() > 0 then
                    local _name = _unit:getName()
                    if not _excludedNames or not _excludedNames[_name] then
                        local _up = _unit:getPoint()
                        local _dx = _up.x - _point.x
                        local _dz = _up.z - _point.z
                        if _dx * _dx + _dz * _dz <= _radius * _radius then
                            _count = _count + 1
                        end
                    end
                end
            end
        end
    end

    return _count
end

--- Flip a still-neutral airfield to red when a stronghold mission fails.
--- @param _airbase Airbase|nil the airdrome near the failed stronghold
function WE.captureStrongholdAirfield(_airbase)
    if not _airbase then return end
    if not _airbase.isExist or type(_airbase.isExist) ~= "function" then return end
    if not _airbase:isExist() then return end

    if _airbase:getCoalition() ~= coalition.side.NEUTRAL then return end

    if _airbase.setCoalition and type(_airbase.setCoalition) == "function" then
        _airbase:setCoalition(coalition.side.RED)
        if _airbase.autoCapture and type(_airbase.autoCapture) == "function" then
            _airbase:autoCapture(false)
        end
        WE.logInfo("Stronghold captured neutral airfield: %s", tostring(_airbase:getName()))
        trigger.action.outText(
            string.format("STRONGHOLD CAPTURED: the stronghold has seized %s for the red coalition!",
                tostring(_airbase:getName())), 15)
    else
        WE.logWarning("Stronghold: Airbase.setCoalition not available, cannot capture %s",
            tostring(_airbase:getName()))
    end
end

--- Spawn tank / APC / SAM defenders around the captured airfield, one group per
--- unit, at a random bearing and distance from the airfield center.
--- @param _airbase Airbase object
--- @param _spawnId number per-spawn counter used to make names unique
function WE.spawnStrongholdDefense(_airbase, _spawnId)
    local _point = _airbase:getPoint()
    local _defenses = {
        { ["type"] = WE.StrongholdDefenseTankType, ["count"] = WE.StrongholdDefenseTankCount, ["name"] = "Tank" },
        { ["type"] = WE.StrongholdDefenseAPCType, ["count"] = WE.StrongholdDefenseAPCCount, ["name"] = "APC" },
        { ["type"] = WE.StrongholdDefenseSAMType, ["count"] = WE.StrongholdDefenseSAMCount, ["name"] = "SAM" },
    }

    for _, _def in ipairs(_defenses) do
        for _i = 1, _def.count do
            local _spawnPoint = WE.randomLandPoint(_point.x, _point.z,
                WE.StrongholdDefenseSpawnMin, WE.StrongholdDefenseSpawnMax, 10)
            if not _spawnPoint then
                WE.logWarning("Stronghold defense: no land point near %s, skipping %s",
                    tostring(_airbase:getName()), _def.type)
            else
                local _unitName = string.format("ShDef-%s-%d-%d", _def.name, _spawnId, _i)
                WE.spawnStrongholdGroundGroup(
                    string.format("Stronghold_Def_%s_%d_%d", _def.name, _spawnId, _i),
                    _spawnPoint.x, _spawnPoint.z,
                    { [1] = WE.buildStrongholdUnit(_unitName, _def.type, _spawnPoint.x, _spawnPoint.z,
                        math.random(0, 360)) },
                    "defense")
            end
        end
    end
end

--- Destroy a list of groups if they still exist.
--- @param _groups table list of Group objects
function WE.destroyGroupList(_groups)
    if not _groups then return end
    for _, _group in ipairs(_groups) do
        if _group and _group:isExist() then
            _group:destroy()
            WE.logInfo("Stronghold: removed group %s", tostring(_group:getName()))
        end
    end
end

--- Destroy all groups spawned for the stronghold event (building, SAM,
--- infantry). Called when the event ends so the bunker and its original
--- defenders don't linger on the battlefield.
--- @param _eventData table stronghold event data
function WE.destroyStrongholdUnits(_eventData)
    if not _eventData.groups then return end
    WE.destroyGroupList(_eventData.groups)
end

--- End a Stronghold mission (success or failure) and clean up its mission state.
--- The mission is removed from the active list and the global WE.is_active flag
--- is cleared once the last active stronghold mission ends.
--- @param _eventData table stronghold event data
--- @param _result string "SUCCESS" or "FAILURE"
function WE.endStrongholdEvent(_eventData, _result)
    if not _eventData or _eventData.ended then
        return
    end
    _eventData.ended = true

    if _eventData.markId then
        trigger.action.removeMark(_eventData.markId)
    end

    if _result == "SUCCESS" then
        trigger.action.outText("SUCCESS: The stronghold and all defenders have been destroyed!", 10)
    else
        -- If the bunker was destroyed before the clock ran out, the attack
        -- succeeded despite a few surviving defenders: no airfield capture,
        -- the remaining troops simply scatter.
        local _building = _eventData.buildingUnitName and Unit.getByName(_eventData.buildingUnitName)
        if not _building or not _building:isExist() or _building:getLife() <= 0 then
            trigger.action.outText("The stronghold has been successfully destroyed, remaining troops have scattered.", 10)
        else
            trigger.action.outText("FAILURE: Time ran out! The stronghold survived the attack.", 10)

            -- The stronghold captures the nearby airfield and re-garrisons it
            local _airbase = _eventData.airbase
            WE.captureStrongholdAirfield(_airbase)

            if _airbase and _airbase:isExist() then
                local _airbasePoint = _airbase:getPoint()
                local _redUnitCount = WE.countRedGroundUnitsNear(_airbasePoint, WE.StrongholdDefenseRadius,
                    _eventData.unitNames)
                WE.logInfo("Stronghold failure: %d red ground unit(s) stationed within %dm of %s",
                    _redUnitCount, WE.StrongholdDefenseRadius, tostring(_airbase:getName()))
                if _redUnitCount < WE.StrongholdDefenseMinRedUnits then
                    WE.spawnStrongholdDefense(_airbase, _eventData.spawnId)
                    trigger.action.outText(
                        "The stronghold has reinforced the captured airfield with tanks, APCs and SAM sites!", 15)
                end
            end
        end

        -- The stronghold is over: remove the bunker and the original defenders
        WE.destroyStrongholdUnits(_eventData)
    end

    -- Remove this mission from the active list
    for _i, _active in ipairs(WE.activeStrongholdEvents) do
        if _active == _eventData then
            table.remove(WE.activeStrongholdEvents, _i)
            break
        end
    end

    -- The overall mission flag reflects ANY active stronghold mission
    if #WE.activeStrongholdEvents == 0 then
        WE.is_active = 0
    end
    WE.logInfo("Stronghold event ended - result: %s (%d active mission(s) remaining)",
        _result, #WE.activeStrongholdEvents)
end

--- Periodic countdown tick for all active Stronghold missions. Ends each mission
--- as a failure once its timer reaches zero and announces the remaining time.
--- @return number|nil next check time, or nil to stop the timer
function WE.strongholdCountdownTick()
    if #WE.activeStrongholdEvents == 0 then
        return nil
    end

    local _now = timer.getTime()
    local _expiredEvents = {}
    for _, _eventData in ipairs(WE.activeStrongholdEvents) do
        local _remaining = _eventData.endsAt - _now
        if _remaining <= 0 then
            table.insert(_expiredEvents, _eventData)
        else
            local _remainingMinutes = math.ceil(_remaining / 60)
            if _eventData.lastAnnouncedMinutes == nil or _remainingMinutes < _eventData.lastAnnouncedMinutes then
                _eventData.lastAnnouncedMinutes = _remainingMinutes
                if _remainingMinutes > 0 then
                    trigger.action.outText(string.format(
                        "Stronghold countdown: %d minute(s) remaining (near %s)!",
                        _remainingMinutes, _eventData.area), 10)
                end
            end
        end
    end

    -- End expired missions after the iteration so the list isn't mutated while
    -- being walked.
    for _, _eventData in ipairs(_expiredEvents) do
        WE.endStrongholdEvent(_eventData, "FAILURE")
    end

    if #WE.activeStrongholdEvents == 0 then
        return nil
    end
    return _now + 1
end

--- Spawn the Stronghold event: red building + ground troops + short-range SAM.
function WE.EVENT.STRONGHOLD()
    WE.logInfo("Stronghold event triggered (%d active mission(s))", #WE.activeStrongholdEvents)

    local _activeStrongholds = #WE.activeStrongholdEvents

    -- Block starting a stronghold while a DIFFERENT event type is running; the
    -- stronghold missions manage their own concurrency once one is active.
    if WE.is_active == 1 and _activeStrongholds == 0 then
        trigger.action.outText("Another world event is already active!", 10)
        WE.logInfo("Stronghold spawn cancelled - another event already active")
        return
    end

    if not WE.StrongholdAllowMultiple then
        -- Default behaviour: only one stronghold at a time
        if _activeStrongholds > 0 then
            trigger.action.outText("Stronghold event is already active!", 10)
            WE.logInfo("Stronghold spawn cancelled - event already active")
            return
        end
    elseif _activeStrongholds >= WE.StrongholdMaxConcurrent then
        trigger.action.outText(string.format(
            "Maximum %d active stronghold mission(s) reached!", WE.StrongholdMaxConcurrent), 10)
        WE.logInfo("Stronghold spawn cancelled - %d mission(s) already active", _activeStrongholds)
        return
    end

    -- Pick a random spot near a random airdrome so this works on any map
    local _point, _areaName, _airbase = WE.pickStrongholdLocation()
    if not _point then
        WE.logError("STRONGHOLD: no valid location on this map - event cancelled")
        trigger.action.outText("Stronghold event could not start: no valid location on this map!", 10)
        return
    end

    WE.logInfo("STRONGHOLD: location=%s near %s", WE.p(_point), tostring(_areaName))

    -- Make every group/unit name unique per spawn so repeat events never
    -- collide with surviving units from a previous (failed) stronghold.
    WE.strongholdSpawnCounter = WE.strongholdSpawnCounter + 1
    local _spawnId = WE.strongholdSpawnCounter

    local _unitNames = {}
    local _groups = {}

    -- Spawn the building (destructible fortification) at the center
    local _buildingUnitName = string.format("Sh-Building-%d", _spawnId)
    local _buildingObj = WE.spawnStrongholdGroundGroup(
        string.format("Stronghold_Building_%d", _spawnId),
        _point.x, _point.z,
        { [1] = WE.buildStrongholdUnit(_buildingUnitName, WE.StrongholdBuildingType, _point.x, _point.z, 0) },
        "building")
    if not _buildingObj then
        trigger.action.outText("Failed to spawn stronghold building", 10)
        return
    end
    table.insert(_groups, _buildingObj)
    _unitNames[_buildingUnitName] = true

    -- Spawn the short-range SAM to the side of the building (kept on land)
    local _samX, _samZ = WE.randomLandOffsetNear(_point.x, _point.z, 60)
    local _samUnitName = string.format("Sh-SAM-%d", _spawnId)
    local _samObj = WE.spawnStrongholdGroundGroup(
        string.format("Stronghold_SAM_%d", _spawnId),
        _samX, _samZ,
        { [1] = WE.buildStrongholdUnit(_samUnitName, WE.StrongholdSAMType, _samX, _samZ, math.random(0, 360)) },
        "SAM")
    if not _samObj then
        trigger.action.outText("Failed to spawn stronghold SAM", 10)
        WE.destroyGroupList(_groups)
        return
    end
    table.insert(_groups, _samObj)
    _unitNames[_samUnitName] = true

    -- Spawn the defending infantry spread around the stronghold (kept on land)
    local _infantryUnits = {}
    for _i = 1, WE.StrongholdInfantryCount do
        local _unitName = string.format("Sh-Inf-%d-%d", _spawnId, _i)
        local _infX, _infZ = WE.randomLandOffsetNear(_point.x, _point.z, 80)
        _infantryUnits[_i] = WE.buildStrongholdUnit(_unitName, WE.StrongholdInfantryType,
            _infX, _infZ, math.random(0, 360))
        _unitNames[_unitName] = true
    end
    local _infObj = WE.spawnStrongholdGroundGroup(
        string.format("Stronghold_Infantry_%d", _spawnId),
        _point.x, _point.z, _infantryUnits, "infantry")
    if not _infObj then
        trigger.action.outText("Failed to spawn stronghold defenders", 10)
        WE.destroyGroupList(_groups)
        return
    end
    table.insert(_groups, _infObj)
    WE.logInfo("Stronghold infantry spawned: %d soldier(s) (group id %s)", #_infantryUnits, tostring(_infObj:getID()))

    -- Mark the mission as active and remember ALL mission state for tracking
    local _now = timer.getTime()
    local _markId = -(1000 + _spawnId)
    local _eventData = {
        area = _areaName,
        point = _point,
        airbase = _airbase,
        duration = WE.StrongholdDurationSeconds,
        spawnedAt = _now,
        endsAt = _now + WE.StrongholdDurationSeconds,
        unitNames = _unitNames,
        groups = _groups,
        markId = _markId,
        spawnId = _spawnId,
        buildingUnitName = _buildingUnitName,
        ended = false,
    }
    table.insert(WE.activeStrongholdEvents, _eventData)
    WE.is_active = 1
    local _missionIndex = #WE.activeStrongholdEvents

    -- Drop an F10 map mark so players can find the stronghold on the ground
    trigger.action.markToAll(_markId,
        string.format("Stronghold (near %s) - destroy the building and all defenders!", _areaName),
        { x = _point.x, y = _point.y, z = _point.z })

    -- The shared countdown timer walks every active mission; only start it when
    -- this is the first active mission, otherwise it is already running.
    if _missionIndex == 1 then
        timer.scheduleFunction(WE.strongholdCountdownTick, nil, _now + 1)
    end

    WE.logInfo("Stronghold event completed successfully - %d unit(s) in %d group(s) near %s",
        WE.countTableEntries(_unitNames), #_groups, tostring(_areaName))

    -- Tell all players where to go
    local _minutes = math.ceil(WE.StrongholdDurationSeconds / 60)
    if WE.StrongholdAllowMultiple then
        trigger.action.outText(
            string.format(
                "STRONGHOLD %d of %d is active near %s! Destroy the red stronghold and all defenders within %d minutes!",
                _missionIndex, WE.StrongholdMaxConcurrent, _areaName, _minutes),
            20)
    else
        trigger.action.outText(
            string.format(
                "STRONGHOLD is active near %s! Destroy the red stronghold and all defenders within %d minutes!",
                _areaName, _minutes),
            20)
    end

    trigger.action.outSound("attn_stronghold.ogg")
end

-- Create a table to hold our custom event handler
WE.EVENT.STRONGHOLDEVENT = {}

-- Define the function that DCS calls every time ANY event happens in the world
function WE.EVENT.STRONGHOLDEVENT:onEvent(event)
    if not event then return end
    if #WE.activeStrongholdEvents == 0 then return end
    if not event.initiator then return end

    local _unit = event.initiator
    if not _unit.getName or type(_unit.getName) ~= "function" then return end

    if event.id ~= world.event.S_EVENT_DEAD then return end

    local _name = _unit:getName()

    -- Check every active mission: the destroyed unit may belong to any of them
    for _, _eventData in ipairs(WE.activeStrongholdEvents) do
        if not _eventData.ended and _eventData.unitNames[_name] then
            WE.logInfo("Stronghold: %s destroyed, checking remaining defenders (mission near %s)",
                _name, tostring(_eventData.area))

            if WE.areAllStrongholdUnitsDead(_eventData) then
                WE.endStrongholdEvent(_eventData, "SUCCESS")
            end
        end
    end
end

-- Register the handler with the DCS world engine so it starts listening
world.addEventHandler(WE.EVENT.STRONGHOLDEVENT)

-----------------[[ END OF event_stronghold.lua ]]-----------------
