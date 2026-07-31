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
--- The minimum keeps the bunker at least 1 nautical mile (1852 m) from the
--- airfield so its defenders never end up on the runway.
WE.StrongholdOffsetMin = 1852
WE.StrongholdOffsetMax = 2500

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

--- Track the currently active Stronghold event (area, position, spawned units).
WE.currentStrongholdEvent = nil

--- Counter used to make each spawn's group/unit names unique (DCS rejects
--- duplicate names) and to generate a unique negative F10 mark id.
WE.strongholdSpawnCounter = 0

--- Check whether a point is on land (its terrain surface type is not water or
--- shallow water). DCS's land.getSurfaceType takes a Vec2 {x, y} where y is
--- the north (z) coordinate, so the vec3 point is converted here.
--- @param _point table point {x, y, z}
--- @return boolean true when the point is not water
function WE.isPointOnLand(_point)
    local _surfaceType = land.getSurfaceType({ x = _point.x, y = _point.z })
    if not _surfaceType then
        return false
    end
    if _surfaceType == land.SurfaceType.WATER or _surfaceType == land.SurfaceType.SHALLOW_WATER then
        return false
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

--- Pick a random point near a random airdrome to place the stronghold.
--- Only red and neutral airdromes are used so the stronghold never sits on
--- a blue (player) airfield. Points in water are retried.
--- @return table|nil stronghold point {x, y, z} (y = terrain height)
--- @return string|nil name of the airdrome the stronghold is anchored near
--- @return Airbase|nil the airdrome the stronghold is anchored near
function WE.pickStrongholdLocation()
    local _allAirdromes = {}
    for _, _base in ipairs(WE.getAirdromes('red')) do table.insert(_allAirdromes, _base) end
    for _, _base in ipairs(WE.getAirdromes('neutral')) do table.insert(_allAirdromes, _base) end

    if #_allAirdromes < 1 then
        WE.logWarning("pickStrongholdLocation: no airdromes on this map, cannot place stronghold")
        return nil, nil, nil
    end

    for _ = 1, 10 do
        local _base = _allAirdromes[math.random(1, #_allAirdromes)]
        local _basePoint = _base:getPoint()
        local _point = WE.randomLandPoint(_basePoint.x, _basePoint.z,
            WE.StrongholdOffsetMin, WE.StrongholdOffsetMax, 10)
        if _point then
            _point.y = land.getHeight({ x = _point.x, y = _point.z })
            return _point, _base:getName(), _base
        end
    end

    WE.logWarning("pickStrongholdLocation: no land point found near any airdrome, cancelling stronghold")
    return nil, nil, nil
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
                WE.StrongholdDefenseSpawnMin, WE.StrongholdDefenseSpawnMax)
            if not _spawnPoint then
                WE.logWarning("Stronghold defense: no land point near %s, skipping %s",
                    tostring(_airbase:getName()), _def.type)
            else
                local _unitName = string.format("ShDef-%s-%d-%d", _def.name, _spawnId, _i)
                local _groupObj = coalition.addGroup(WE.StrongholdCountry, Group.Category.GROUND,
                    WE.buildStationaryGroundGroup(
                        string.format("Stronghold_Def_%s_%d_%d", _def.name, _spawnId, _i),
                        WE.getNextGroupId(), _spawnPoint.x, _spawnPoint.z, {
                            [1] = {
                                ["type"] = _def.type,
                                ["unitId"] = WE.getNextUnitId(),
                                ["name"] = _unitName,
                                ["x"] = _spawnPoint.x,
                                ["y"] = _spawnPoint.z,
                                ["heading"] = math.random(0, 360),
                                ["skill"] = "Excellent",
                            },
                        }))
                if _groupObj then
                    WE.logInfo("Stronghold defense spawned: %s (%s)", _unitName, _def.type)
                else
                    WE.logError("Failed to spawn stronghold defense unit: %s (%s)", _unitName, _def.type)
                end
            end
        end
    end
end

--- Destroy all groups spawned for the stronghold event (building, SAM,
--- infantry). Called when the event ends so the bunker and its original
--- defenders don't linger on the battlefield.
--- @param _eventData table stronghold event data
function WE.destroyStrongholdUnits(_eventData)
    if not _eventData.groups then return end
    for _, _group in ipairs(_eventData.groups) do
        if _group and _group:isExist() then
            _group:destroy()
            WE.logInfo("Stronghold: removed group %s", tostring(_group:getName()))
        end
    end
end

--- End the Stronghold event (success or failure) and clean up mission state.
--- @param _result string "SUCCESS" or "FAILURE"
function WE.endStrongholdEvent(_result)
    local _eventData = WE.currentStrongholdEvent
    if not _eventData or _eventData.ended then
        return
    end
    _eventData.ended = true

    if WE.strongholdMarkId then
        trigger.action.removeMark(WE.strongholdMarkId)
        WE.strongholdMarkId = nil
    end

    if _result == "SUCCESS" then
        trigger.action.outText("SUCCESS: The stronghold and all defenders have been destroyed!", 10)
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
                WE.spawnStrongholdDefense(_airbase, WE.strongholdSpawnCounter)
                trigger.action.outText(
                    "The stronghold has reinforced the captured airfield with tanks, APCs and SAM sites!", 15)
            end
        end

        -- The stronghold is over: remove the bunker and the original defenders
        WE.destroyStrongholdUnits(_eventData)
    end

    WE.is_active = 0
    WE.currentStrongholdEvent = nil
    WE.logInfo("Stronghold event ended - result: %s", _result)
end

--- Periodic countdown tick for the active Stronghold event. Ends the event as
--- a failure once the timer reaches zero and announces the remaining time.
--- @return number|nil next check time, or nil to stop the timer
function WE.strongholdCountdownTick()
    local _eventData = WE.currentStrongholdEvent
    if not _eventData or _eventData.ended then
        return nil
    end

    local _remaining = _eventData.endsAt - timer.getTime()
    if _remaining <= 0 then
        WE.endStrongholdEvent("FAILURE")
        return nil
    end

    local _remainingMinutes = math.ceil(_remaining / 60)
    if _eventData.lastAnnouncedMinutes == nil or _remainingMinutes < _eventData.lastAnnouncedMinutes then
        _eventData.lastAnnouncedMinutes = _remainingMinutes
        if _remainingMinutes > 0 then
            trigger.action.outText(string.format("Stronghold countdown: %d minute(s) remaining!", _remainingMinutes), 10)
        end
    end

    return timer.getTime() + 1
end

--- Spawn the Stronghold event: red building + ground troops + short-range SAM.
function WE.EVENT.STRONGHOLD()
    WE.logInfo("Stronghold event triggered")

    -- Check if already active
    if WE.is_active == 1 then
        trigger.action.outText("Stronghold event is already active!", 10)
        WE.logInfo("Stronghold spawn cancelled - event already active")
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
    local _buildingGroupId = WE.getNextGroupId()
    local _buildingUnitName = string.format("Sh-Building-%d", _spawnId)
    local _buildingObj = coalition.addGroup(WE.StrongholdCountry, Group.Category.GROUND,
        WE.buildStationaryGroundGroup(string.format("Stronghold_Building_%d", _spawnId), _buildingGroupId,
            _point.x, _point.z, {
                [1] = {
                    ["type"] = WE.StrongholdBuildingType,
                    ["unitId"] = WE.getNextUnitId(),
                    ["name"] = _buildingUnitName,
                    ["x"] = _point.x,
                    ["y"] = _point.z,
                    ["heading"] = 0,
                    ["skill"] = "Excellent",
                },
            }))
    if not _buildingObj then
        WE.logError("Failed to spawn stronghold building group")
        trigger.action.outText("Failed to spawn stronghold building", 10)
        return
    end
    table.insert(_groups, _buildingObj)
    _unitNames[_buildingUnitName] = true
    WE.logInfo("Stronghold building spawned: %s (group id %s)", _buildingUnitName, tostring(_buildingObj:getID()))

    -- Spawn the short-range SAM to the side of the building (kept on land)
    local _samX, _samZ = WE.randomLandOffsetNear(_point.x, _point.z, 60)
    local _samGroupId = WE.getNextGroupId()
    local _samUnitName = string.format("Sh-SAM-%d", _spawnId)
    local _samObj = coalition.addGroup(WE.StrongholdCountry, Group.Category.GROUND,
        WE.buildStationaryGroundGroup(string.format("Stronghold_SAM_%d", _spawnId), _samGroupId,
            _samX, _samZ, {
                [1] = {
                    ["type"] = WE.StrongholdSAMType,
                    ["unitId"] = WE.getNextUnitId(),
                    ["name"] = _samUnitName,
                    ["x"] = _samX,
                    ["y"] = _samZ,
                    ["heading"] = math.random(0, 360),
                    ["skill"] = "Excellent",
                },
            }))
    if not _samObj then
        WE.logError("Failed to spawn stronghold SAM group")
        trigger.action.outText("Failed to spawn stronghold SAM", 10)
        return
    end
    table.insert(_groups, _samObj)
    _unitNames[_samUnitName] = true
    WE.logInfo("Stronghold SAM spawned: %s (group id %s)", _samUnitName, tostring(_samObj:getID()))

    -- Spawn the defending infantry spread around the stronghold (kept on land)
    local _infantryUnits = {}
    for _i = 1, WE.StrongholdInfantryCount do
        local _unitName = string.format("Sh-Inf-%d-%d", _spawnId, _i)
        local _infX, _infZ = WE.randomLandOffsetNear(_point.x, _point.z, 80)
        _infantryUnits[_i] = {
            ["type"] = WE.StrongholdInfantryType,
            ["unitId"] = WE.getNextUnitId(),
            ["name"] = _unitName,
            ["x"] = _infX,
            ["y"] = _infZ,
            ["heading"] = math.random(0, 360),
            ["skill"] = "Excellent",
        }
        _unitNames[_unitName] = true
    end
    local _infGroupId = WE.getNextGroupId()
    local _infObj = coalition.addGroup(WE.StrongholdCountry, Group.Category.GROUND,
        WE.buildStationaryGroundGroup(string.format("Stronghold_Infantry_%d", _spawnId), _infGroupId,
            _point.x, _point.z, _infantryUnits))
    if not _infObj then
        WE.logError("Failed to spawn stronghold infantry group")
        trigger.action.outText("Failed to spawn stronghold defenders", 10)
        return
    end
    table.insert(_groups, _infObj)
    WE.logInfo("Stronghold infantry spawned: %d soldier(s) (group id %s)", #_infantryUnits, tostring(_infObj:getID()))

    -- Mark the event as active and remember ALL mission state for tracking
    WE.is_active = 1
    local _now = timer.getTime()
    WE.currentStrongholdEvent = {
        area = _areaName,
        point = _point,
        airbase = _airbase,
        duration = WE.StrongholdDurationSeconds,
        spawnedAt = _now,
        endsAt = _now + WE.StrongholdDurationSeconds,
        unitNames = _unitNames,
        groups = _groups,
        ended = false,
    }

    -- Drop an F10 map mark so players can find the stronghold on the ground
    WE.strongholdMarkId = -(1000 + _spawnId)
    trigger.action.markToAll(WE.strongholdMarkId,
        string.format("Stronghold (near %s) - destroy the building and all defenders!", _areaName),
        { x = _point.x, y = _point.y, z = _point.z })

    -- Start the countdown; the mission is a failure if it reaches zero
    timer.scheduleFunction(WE.strongholdCountdownTick, nil, timer.getTime() + 1)

    WE.logInfo("Stronghold event completed successfully - %d unit(s) in %d group(s) near %s",
        WE.countTableEntries(_unitNames), #_groups, tostring(_areaName))

    -- Tell all players where to go
    trigger.action.outText(
        string.format(
            "STRONGHOLD is active near %s! Destroy the red stronghold and all defenders within %d minutes!",
            _areaName, math.ceil(WE.StrongholdDurationSeconds / 60)),
        20)

    trigger.action.outSound("attn_stronghold.ogg")
end

-- Create a table to hold our custom event handler
WE.EVENT.STRONGHOLDEVENT = {}

-- Define the function that DCS calls every time ANY event happens in the world
function WE.EVENT.STRONGHOLDEVENT:onEvent(event)
    if not event then return end
    if not WE.is_active or WE.is_active ~= 1 then return end
    if not event.initiator then return end

    local _unit = event.initiator
    if not _unit.getName or type(_unit.getName) ~= "function" then return end

    local _eventData = WE.currentStrongholdEvent
    if not _eventData or _eventData.ended then return end

    if event.id ~= world.event.S_EVENT_DEAD then return end

    local _name = _unit:getName()
    if not _eventData.unitNames[_name] then return end

    WE.logInfo("Stronghold: %s destroyed, checking remaining defenders", _name)

    if WE.areAllStrongholdUnitsDead(_eventData) then
        WE.endStrongholdEvent("SUCCESS")
    end
end

-- Register the handler with the DCS world engine so it starts listening
world.addEventHandler(WE.EVENT.STRONGHOLDEVENT)

-----------------[[ END OF event_stronghold.lua ]]-----------------
