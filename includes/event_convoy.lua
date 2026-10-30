-----------------[[ event_convoy.lua ]]-----------------
---
--- Convoy Interdiction event spawning module
--- Spawns a red supply convoy that drives from a rear airbase to a front-line
--- airbase. Players must destroy every convoy unit before it reaches the
--- destination or the timeout expires.
---

--- Country used to spawn the Convoy units. Change this if your red side isn't
--- Russia on the map/mod you're using.
WE.ConvoyCountry = country.id.RUSSIA

--- Ground unit types used for the convoy. Truck types are picked in order from
--- the list, so add or remove entries to change the mix.
WE.ConvoyTruckTypes = { "Ural-375", "GAZ-66" }
WE.ConvoyTruckCount = 6

--- Armed escorts mixed into the convoy.
WE.ConvoyEscortTypes = { "BMP-2", "BTR-80" }
WE.ConvoyEscortCount = 3

--- Optional mobile air defences. Set either to nil to leave it out.
WE.ConvoyAAAType = "ZSU-23-4 Shilka"
WE.ConvoySAMType = "Strela-10M3"

--- Route speed in kilometres per hour and how often the route is checked.
WE.ConvoySpeedKph = 30
WE.ConvoyTickIntervalSeconds = 5

--- The convoy fails once its lead unit gets within this radius (meters) of the
--- destination point.
WE.ConvoyArrivalRadiusMeters = 500

--- Additional arrival radius around the destination airbase reference point.
--- This avoids edge cases where road routing stops just short of the exact
--- destination waypoint but the convoy has effectively arrived at the base.
WE.ConvoyArrivalAirbaseRadiusMeters = 2500

--- Hard deadline (seconds) for the convoy to reach the destination.
WE.ConvoyTimeoutSeconds = 1800

--- Allow more than one Convoy mission to run at the same time. When false only
--- a single convoy may be active, matching the rest of the World Events
--- framework. The global WE.is_active flag stays set while ANY convoy runs.
WE.ConvoyAllowMultiple = false
WE.ConvoyMaxConcurrent = 2

--- Routes shorter than this (meters) are rejected so the convoy isn't spawned
--- between two airfields that are practically next to each other.
WE.ConvoyMinRouteDistanceMeters = 5000

--- Maximum direct airfield-to-airfield distance for a convoy route. This keeps
--- the mission in the local theatre instead of sending the convoy across the map.
WE.ConvoyMaxRouteDistanceMeters = 30 * 1852

--- Number of route points including the start and destination (3-5 recommended).
WE.ConvoyRoutePointCount = 4

--- List of currently active Convoy events, one entry per mission.
WE.activeConvoyEvents = {}

--- The most recently spawned convoy, kept for callers that expect a single
--- current event (see EVENT_DESIGN.md).
WE.currentConvoyEvent = nil

--- Counter used to make each spawn's group/unit names unique (DCS rejects
--- duplicate names).
WE.convoySpawnCounter = 0

--- Collect the airdromes a convoy can start from and drive to. The origin must
--- be red; the destination may be red or neutral, but never blue.
--- @return table red origin candidates
--- @return table destination candidates
function WE.getConvoyAirdromes()
    local _originCandidates = WE.getAirdromes('red')
    local _destinationCandidates = {}
    local _seen = {}

    local function _add(_list)
        for _, _airbase in ipairs(_list) do
            local _name = _airbase:getName()
            if _name and not _seen[_name] then
                _seen[_name] = true
                table.insert(_destinationCandidates, _airbase)
            end
        end
    end

    _add(_originCandidates)
    _add(WE.getAirdromes('neutral'))

    return _originCandidates, _destinationCandidates
end

--- Pick a random land point near an airbase, used as the convoy's start or
--- destination. Returns nil when no usable point is found.
--- @param _airbase Airbase airbase to anchor the point near
--- @param _min number minimum distance from the airbase reference point
--- @param _max number maximum distance from the airbase reference point
--- @return table|nil point {x, y, z}
function WE.getConvoyAirbasePoint(_airbase, _min, _max)
    if not _airbase then return nil end
    local _basePoint = _airbase:getPoint()
    if not _basePoint then return nil end
    local _point = WE.randomLandPoint(_basePoint.x, _basePoint.z, _min, _max, 30)
    if not _point then
        return nil
    end
    _point.y = land.getHeight({ x = _point.x, y = _point.z })
    return _point
end

--- Check whether a route waypoint is usable. Unlike a spawn point, a route
--- waypoint may sit on a road, so only water and paved airfield surfaces are
--- rejected.
--- @param _point table point {x, y, z}
--- @return boolean true when the point is usable on land
function WE.isConvoyRoutePoint(_point)
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
    return true
end

--- Build a simple 3-5 point ground route between two land points. Intermediate
--- points are placed along the direct line; when a point falls on water or
--- pavement it is nudged sideways until a usable point is found.
--- @param _start table start point {x, y, z}
--- @param _finish table finish point {x, y, z}
--- @return table|nil list of route points, or nil when no usable route exists
function WE.buildConvoyRoute(_start, _finish)
    if not _start or not _finish then return nil end

    local _dx = _finish.x - _start.x
    local _dz = _finish.z - _start.z
    local _distance = math.sqrt(_dx * _dx + _dz * _dz)
    if _distance < WE.ConvoyMinRouteDistanceMeters then
        return nil
    end
    if _distance > (WE.ConvoyMaxRouteDistanceMeters or 100000000) then
        return nil
    end

    local _pointCount = math.max(3, math.min(5, WE.ConvoyRoutePointCount))
    local _points = { _start }
    local _sideX = -_dz / _distance
    local _sideZ = _dx / _distance

    for _i = 1, _pointCount - 2 do
        local _t = _i / (_pointCount - 1)
        local _x = _start.x + _dx * _t
        local _z = _start.z + _dz * _t
        local _point = { x = _x, y = 0, z = _z }

        if not WE.isConvoyRoutePoint(_point) then
            local _found = nil
            for _, _offset in ipairs({ 1000, -1000, 2000, -2000, 3000, -3000 }) do
                local _candidate = {
                    x = _x + _sideX * _offset,
                    y = 0,
                    z = _z + _sideZ * _offset,
                }
                if WE.isConvoyRoutePoint(_candidate) then
                    _found = _candidate
                    break
                end
            end
            if not _found then
                return nil
            end
            _point = _found
        end

        _point.y = land.getHeight({ x = _point.x, y = _point.z })
        table.insert(_points, _point)
    end

    table.insert(_points, _finish)
    return _points
end

--- Pick a route, origin airdrome and destination airdrome for a new convoy.
--- Tries several random origin/destination pairs so an unlucky coastal or
--- mountainous pair cannot cancel the event outright.
--- @return table|nil route points
--- @return Airbase|nil origin airdrome
--- @return Airbase|nil destination airdrome
function WE.pickConvoyRoute()
    local _originCandidates, _destinationCandidates = WE.getConvoyAirdromes()
    if #_originCandidates == 0 then
        WE.logWarning("pickConvoyRoute: no red airdromes available")
        return nil, nil, nil
    end
    if #_destinationCandidates == 0 then
        WE.logWarning("pickConvoyRoute: no destination airdromes available")
        return nil, nil, nil
    end

    local _candidatePairs = {}
    local _maxDistance = WE.ConvoyMaxRouteDistanceMeters or 100000000

    for _, _origin in ipairs(_originCandidates) do
        local _originPoint = _origin:getPoint()
        if _originPoint then
            for _, _destination in ipairs(_destinationCandidates) do
                if _origin:getName() ~= _destination:getName() then
                    local _destinationPoint = _destination:getPoint()
                    if _destinationPoint then
                        local _airbaseDistance = WE.getDistance(_originPoint, _destinationPoint)
                        if _airbaseDistance <= _maxDistance then
                            table.insert(_candidatePairs, {
                                origin = _origin,
                                destination = _destination,
                            })
                        end
                    end
                end
            end
        end
    end

    if #_candidatePairs == 0 then
        WE.logWarning("pickConvoyRoute: no origin/destination pairs within %.0f nm",
            (_maxDistance / 1852))
        return nil, nil, nil
    end

    for _i = #_candidatePairs, 2, -1 do
        local _j = math.random(1, _i)
        _candidatePairs[_i], _candidatePairs[_j] = _candidatePairs[_j], _candidatePairs[_i]
    end

    for _, _pair in ipairs(_candidatePairs) do
        for _attempt = 1, 6 do
            local _start = WE.getConvoyAirbasePoint(_pair.origin, 300, 1500)
            local _finish = WE.getConvoyAirbasePoint(_pair.destination, 500, 2000)
            if _start and _finish and WE.isConvoyRoutePoint(_start) and WE.isConvoyRoutePoint(_finish) then
                local _route = WE.buildConvoyRoute(_start, _finish)
                if _route then
                    return _route, _pair.origin, _pair.destination
                end
            end
        end
    end

    WE.logWarning("pickConvoyRoute: no usable route after checking %d nearby pair(s)", #_candidatePairs)
    return nil, nil, nil
end

--- Build a unit position behind the convoy's lead point so the group spawns in
--- a column instead of stacked on one coordinate.
--- @param _start table lead point {x, y, z}
--- @param _heading number heading in radians
--- @param _index number unit index (1 = lead)
--- @return number x
--- @return number z
function WE.getConvoyUnitPosition(_start, _heading, _index)
    local _spacing = 18
    local _distance = (_index - 1) * _spacing
    local _x = _start.x - math.sin(_heading) * _distance
    local _z = _start.z - math.cos(_heading) * _distance

    if WE.isConvoyRoutePoint({ x = _x, y = 0, z = _z }) then
        return _x, _z
    end

    for _, _direction in ipairs({ 1, -1 }) do
        local _sideDistance = _distance + 12
        local _sideX = _start.x + math.cos(_heading) * _direction * _sideDistance
        local _sideZ = _start.z - math.sin(_heading) * _direction * _sideDistance
        if WE.isConvoyRoutePoint({ x = _sideX, y = 0, z = _sideZ }) then
            return _sideX, _sideZ
        end
    end

    return _start.x + math.random(-5, 5), _start.z + math.random(-5, 5)
end

--- Build a ground group table with a moving route.
--- @param _name string group name
--- @param _groupId number group id
--- @param _route table list of route points
--- @param _units table unit definitions
--- @return table ground group table
function WE.buildConvoyGroundGroup(_name, _groupId, _route, _units)
    local _points = {}
    local _speed = WE.ConvoySpeedKph / 3.6

    for _i, _point in ipairs(_route) do
        _points[_i] = {
            ["alt"] = _point.y,
            ["action"] = "On Road",
            ["alt_type"] = "BARO",
            ["speed"] = _speed,
            ["task"] = {
                ["id"] = "ComboTask",
                ["params"] = { ["tasks"] = {} },
            },
            ["type"] = "Turning Point",
            ["ETA_locked"] = false,
            ["y"] = _point.z,
            ["x"] = _point.x,
            ["speed_locked"] = true,
            ["formation_template"] = "",
        }
    end

    local _start = _route[1]
    return {
        ["modulation"] = 0,
        ["tasks"] = {},
        ["task"] = "Ground Nothing",
        ["uncontrolled"] = false,
        ["hidden"] = false,
        ["route"] = {
            ["points"] = _points,
        },
        ["units"] = _units,
        ["y"] = _start.z,
        ["x"] = _start.x,
        ["name"] = _name,
        ["start_time"] = 0,
        ["groupId"] = _groupId,
    }
end

--- Spawn a convoy group of trucks and escorts.
--- @param _route table route points
--- @param _spawnId number unique per-spawn id
--- @return Group|nil spawned group
--- @return table unit names set
--- @return table unit names in spawn order
function WE.spawnConvoyGroup(_route, _spawnId)
    local _start = _route[1]
    local _next = _route[2] or _start
    local _heading = math.atan2(_next.x - _start.x, _next.z - _start.z)

    local _units = {}
    local _unitNames = {}
    local _unitOrder = {}

    local function _addUnit(_unitType, _label)
        local _index = #_unitOrder + 1
        local _unitName = string.format("Convoy_%d_%s_%d", _spawnId, _label, _index)
        local _x, _z = WE.getConvoyUnitPosition(_start, _heading, _index)
        _units[_index] = WE.buildGroundUnit(_unitName, _unitType, _x, _z, _heading)
        _unitNames[_unitName] = true
        _unitOrder[_index] = _unitName
    end

    local _truckTypes = WE.ConvoyTruckTypes or {}
    if #_truckTypes == 0 then
        WE.logError("spawnConvoyGroup: WE.ConvoyTruckTypes is empty")
        return nil, {}, {}
    end
    for _i = 1, WE.ConvoyTruckCount do
        _addUnit(_truckTypes[((_i - 1) % #_truckTypes) + 1], "Truck")
    end

    local _escortTypes = WE.ConvoyEscortTypes or {}
    if #_escortTypes > 0 then
        for _i = 1, WE.ConvoyEscortCount do
            _addUnit(_escortTypes[((_i - 1) % #_escortTypes) + 1], "Escort")
        end
    end

    if WE.ConvoyAAAType then
        _addUnit(WE.ConvoyAAAType, "AAA")
    end
    if WE.ConvoySAMType then
        _addUnit(WE.ConvoySAMType, "SAM")
    end

    local _groupName = string.format("Convoy_%d", _spawnId)
    local _group = coalition.addGroup(WE.ConvoyCountry, Group.Category.GROUND,
        WE.buildConvoyGroundGroup(_groupName, WE.getNextGroupId(), _route, _units))
    if not _group then
        WE.logError("Failed to spawn convoy group %s", _groupName)
        return nil, {}, {}
    end

    WE.logInfo("Convoy spawned: %s (group id %s, %d unit(s))",
        _groupName, tostring(_group:getID()), #_unitOrder)
    return _group, _unitNames, _unitOrder
end

--- Spawn a small red garrison at the convoy's destination after it delivers.
--- @param _point table destination point {x, y, z}
--- @param _spawnId number unique per-spawn id
function WE.spawnConvoyDefense(_point, _spawnId)
    local _defenses = {
        { ["type"] = "BTR-80", ["name"] = "APC" },
        { ["type"] = "BTR-80", ["name"] = "APC" },
        { ["type"] = "ZSU-23-4 Shilka", ["name"] = "AAA" },
    }
    local _units = {}

    for _i, _def in ipairs(_defenses) do
        local _x, _z = WE.randomLandOffsetNear(_point.x, _point.z, 150)
        local _unitName = string.format("Convoy_Def_%d_%s_%d", _spawnId, _def.name, _i)
        _units[_i] = WE.buildGroundUnit(_unitName, _def.type, _x, _z, math.random(0, 360))
    end

    local _groupName = string.format("Convoy_Defense_%d", _spawnId)
    local _group = coalition.addGroup(WE.ConvoyCountry, Group.Category.GROUND,
        WE.buildStationaryGroundGroup(_groupName, WE.getNextGroupId(), _point.x, _point.z, _units))
    if _group then
        WE.logInfo("Convoy defense spawned at destination: %s (group id %s)",
            _groupName, tostring(_group:getID()))
    else
        WE.logError("Failed to spawn convoy defense: %s", _groupName)
    end
end

--- Return the first living unit in a convoy, used to check arrival.
--- @param _eventData table convoy event data
--- @return Unit|nil leader unit
function WE.getConvoyLeader(_eventData)
    if not _eventData or not _eventData.unitOrder then return nil end
    for _, _unitName in ipairs(_eventData.unitOrder) do
        local _unit = Unit.getByName(_unitName)
        if _unit and _unit:isExist() and _unit:getLife() > 0 then
            return _unit
        end
    end
    return nil
end

--- Draw the convoy route on the F10 map so players can see where it is moving.
--- Falls back to waypoint markers when the line API is unavailable.
--- @param _eventData table convoy event data
function WE.drawConvoyRouteOnMap(_eventData)
    if not _eventData or not _eventData.route then return end

    _eventData.routeMarkerIds = {}
    _eventData.routeLineIds = {}

    local function _drawRouteMarkers()
        for _i, _point in ipairs(_eventData.route) do
            local _markerId = WE.getNextMarkId()
            _eventData.routeMarkerIds[_i] = _markerId
            if trigger.action and type(trigger.action.markToAll) == "function" then
                local _label = string.format("Convoy path %d", _i)
                if _i == 1 then
                    _label = "CONVOY ROUTE START"
                elseif _i == #_eventData.route then
                    _label = "CONVOY ROUTE END"
                end
                trigger.action.markToAll(_markerId,
                    _label,
                    _point)
            end
        end
    end

    local function _drawShapeAttempt()
        if not trigger.action then
            _drawRouteMarkers()
            return
        end

        local _useArrow = type(trigger.action.arrowToAll) == "function"
        local _useLine = type(trigger.action.lineToAll) == "function"
        if not _useArrow and not _useLine then
            _drawRouteMarkers()
            return
        end

        for _i = 1, #_eventData.route - 1 do
            local _shapeId = (_eventData.spawnId or 1) * 100 + _i
            _eventData.routeLineIds[_i] = _shapeId
            local _startPoint = _eventData.route[_i]
            local _endPoint = _eventData.route[_i + 1]

            if _useArrow then
                -- DCS arrowToAll points the arrow head at the first vec3 argument.
                -- To have the convoy route point toward the destination, draw each
                -- segment in reverse so the arrow head lands on the next waypoint.
                trigger.action.arrowToAll(-1,
                    _shapeId,
                    _endPoint,
                    _startPoint,
                    { 1, 1, 0, 1 },
                    { 1, 1, 0, 0.15 },
                    3,
                    false,
                    "CONVOY ROUTE")
            else
                trigger.action.lineToAll(-1,
                    _shapeId,
                    _startPoint,
                    _endPoint,
                    { 1, 1, 0, 1 },
                    3,
                    false,
                    "CONVOY ROUTE")
            end
        end
        WE.logDebug("Convoy route overlay drawn with %d segment(s)", #_eventData.routeLineIds)
    end

    local _ok, _err = pcall(_drawShapeAttempt)
    if not _ok then
        WE.logWarning("Convoy route overlay draw failed: %s", tostring(_err))
        _drawRouteMarkers()
        trigger.action.outText("F10 MAP: Convoy route overlay failed on this DCS build; follow CONVOY ROUTE START/END markers.", 10)
    end

    if #_eventData.routeMarkerIds == 0 then
        _drawRouteMarkers()
    end

    if trigger.action and type(trigger.action.textToAll) == "function" then
        _eventData.routeTextId = WE.getNextMarkId()
        local _midIndex = math.max(1, math.floor(#_eventData.route / 2))
        local _midPoint = _eventData.route[_midIndex]
        if _midPoint then
            local _textPoint = { x = _midPoint.x, y = 0, z = _midPoint.z }
            trigger.action.textToAll(-1,
                _eventData.routeTextId,
                _textPoint,
                { 1, 1, 0, 1 },
                { 0, 0, 0, 0.05 },
                18,
                false,
                "ENEMY CONVOY ROUTE")
            WE.logDebug("Convoy route text label placed: %s", tostring(_eventData.routeTextId))
        end
    end

    if trigger.action and type(trigger.action.markToAll) == "function" then
        _eventData.routeLabelMarkId = WE.getNextMarkId()
        local _midIndex = math.max(1, math.floor(#_eventData.route / 2))
        local _midPoint = _eventData.route[_midIndex]
        if _midPoint then
            trigger.action.markToAll(_eventData.routeLabelMarkId,
                "CONVOY ROUTE - FOLLOW THE ARROW",
                _midPoint)
            WE.logDebug("Convoy route label mark placed: %s", tostring(_eventData.routeLabelMarkId))
        end
    end
end

--- End a convoy mission, clean up its mark and apply the failure consequence.
--- @param _eventData table convoy event data
--- @param _result string "SUCCESS", "ARRIVED" or "TIMEOUT"
function WE.endConvoyEvent(_eventData, _result)
    if not _eventData or _eventData.ended then return end
    _eventData.ended = true

    if _eventData.markId then
        trigger.action.removeMark(_eventData.markId)
    end

    if _eventData.routeMarkerIds then
        for _, _markerId in ipairs(_eventData.routeMarkerIds) do
            if _markerId then
                pcall(function() trigger.action.removeMark(_markerId) end)
            end
        end
    end

    if _eventData.routeLineIds then
        for _, _lineId in ipairs(_eventData.routeLineIds) do
            if _lineId then
                pcall(function() trigger.action.removeMark(_lineId) end)
            end
        end
    end

    if _eventData.routeLabelMarkId then
        pcall(function() trigger.action.removeMark(_eventData.routeLabelMarkId) end)
    end

    if _eventData.routeTextId then
        pcall(function() trigger.action.removeMark(_eventData.routeTextId) end)
    end

    if _result == "SUCCESS" then
        trigger.action.outText("SUCCESS: The convoy has been destroyed before delivering its supplies!", 10)
    elseif _result == "ARRIVED" then
        trigger.action.outText(string.format(
            "MISSION FAILED: The convoy reached %s and delivered reinforcements!", _eventData.destination), 10)
        _eventData.delivered = true
        WE.spawnConvoyDefense(_eventData.destinationPoint, _eventData.spawnId)
    else
        trigger.action.outText(string.format(
            "MISSION FAILED: Time ran out and the convoy delivered supplies to %s!", _eventData.destination), 10)
        _eventData.delivered = true
        WE.spawnConvoyDefense(_eventData.destinationPoint, _eventData.spawnId)
    end

    for _i, _active in ipairs(WE.activeConvoyEvents) do
        if _active == _eventData then
            table.remove(WE.activeConvoyEvents, _i)
            break
        end
    end

    if WE.currentConvoyEvent == _eventData then
        WE.currentConvoyEvent = WE.activeConvoyEvents[#WE.activeConvoyEvents]
    end

    if #WE.activeConvoyEvents == 0 then
        WE.is_active = 0
    end

    WE.logInfo("Convoy event ended - result: %s (%d active convoy(s) remaining)",
        _result, #WE.activeConvoyEvents)
end

--- Periodic convoy tick: checks arrival, timeout and total destruction every
--- WE.ConvoyTickIntervalSeconds seconds.
--- @return number|nil next check time, or nil to stop the timer
function WE.convoyTick()
    if #WE.activeConvoyEvents == 0 then
        return nil
    end

    local _now = timer.getTime()
    local _finished = {}

    for _i = #WE.activeConvoyEvents, 1, -1 do
        local _eventData = WE.activeConvoyEvents[_i]
        if not _eventData.ended then
            if WE.areAllUnitsDead(_eventData.unitNames) then
                table.insert(_finished, { _eventData, "SUCCESS" })
            else
                local _leader = WE.getConvoyLeader(_eventData)
                if _leader then
                    local _leaderPoint = _leader:getPoint()
                    local _atDestinationPoint =
                        WE.getDistance(_leaderPoint, _eventData.destinationPoint) <= WE.ConvoyArrivalRadiusMeters
                    local _atDestinationAirbase = false
                    if _eventData.destinationAirbasePoint then
                        _atDestinationAirbase =
                            WE.getDistance(_leaderPoint, _eventData.destinationAirbasePoint) <=
                            WE.ConvoyArrivalAirbaseRadiusMeters
                    end
                    if _atDestinationPoint or _atDestinationAirbase then
                        table.insert(_finished, { _eventData, "ARRIVED" })
                    end
                end

                if not _eventData.ended and _now >= _eventData.endsAt then
                    table.insert(_finished, { _eventData, "TIMEOUT" })
                end
            end
        end
    end

    for _, _result in ipairs(_finished) do
        WE.endConvoyEvent(_result[1], _result[2])
    end

    if #WE.activeConvoyEvents == 0 then
        return nil
    end
    return _now + WE.ConvoyTickIntervalSeconds
end

--- Spawn the Convoy Interdiction event.
function WE.EVENT.CONVOY()
    WE.logInfo("Convoy event triggered (%d active convoy(s))", #WE.activeConvoyEvents)

    local _activeConvoys = #WE.activeConvoyEvents

    if WE.is_active == 1 and _activeConvoys == 0 then
        trigger.action.outText("Another world event is already active!", 10)
        WE.logInfo("Convoy spawn cancelled - another event already active")
        return
    end

    if not WE.ConvoyAllowMultiple then
        if _activeConvoys > 0 then
            trigger.action.outText("Convoy event is already active!", 10)
            WE.logInfo("Convoy spawn cancelled - event already active")
            return
        end
    elseif _activeConvoys >= WE.ConvoyMaxConcurrent then
        trigger.action.outText(string.format(
            "Maximum %d active convoy mission(s) reached!", WE.ConvoyMaxConcurrent), 10)
        WE.logInfo("Convoy spawn cancelled - %d mission(s) already active", _activeConvoys)
        return
    end

    local _route, _origin, _destination = WE.pickConvoyRoute()
    if not _route then
        WE.logError("CONVOY: no valid route on this map - event cancelled")
        trigger.action.outText("Convoy event could not start: no valid route on this map!", 10)
        return
    end

    WE.convoySpawnCounter = WE.convoySpawnCounter + 1
    local _spawnId = WE.convoySpawnCounter
    local _group, _unitNames, _unitOrder = WE.spawnConvoyGroup(_route, _spawnId)
    if not _group then
        trigger.action.outText("Failed to spawn the convoy!", 10)
        return
    end

    local _now = timer.getTime()
    local _markId = WE.getNextMarkId()
    local _eventData = {
        origin = _origin:getName(),
        destination = _destination:getName(),
        destinationPoint = _route[#_route],
        destinationAirbasePoint = _destination:getPoint(),
        route = _route,
        groupId = _group:getID(),
        groupName = _group:getName(),
        unitNames = _unitNames,
        unitOrder = _unitOrder,
        spawnedAt = _now,
        endsAt = _now + WE.ConvoyTimeoutSeconds,
        delivered = false,
        markId = _markId,
        spawnId = _spawnId,
        ended = false,
    }
    table.insert(WE.activeConvoyEvents, _eventData)
    WE.currentConvoyEvent = _eventData
    WE.is_active = 1

    trigger.action.markToAll(_markId,
        string.format("Convoy destination: %s", _eventData.destination),
        _eventData.destinationPoint)

    if #WE.activeConvoyEvents == 1 then
        timer.scheduleFunction(WE.convoyTick, nil, _now + WE.ConvoyTickIntervalSeconds)
    end

    WE.logInfo("CONVOY: %s -> %s, %d unit(s), %d route point(s)",
        _eventData.origin, _eventData.destination, #_unitOrder, #_route)

    local _minutes = math.ceil(WE.ConvoyTimeoutSeconds / 60)
    trigger.action.outText(string.format(
        "CONVOY is en route from %s to %s! Destroy every convoy unit or it will deliver reinforcements!\nConvoy route is marked on the F10 map with an arrow route and route markers.",
        _eventData.origin, _eventData.destination), 20)

    WE.drawConvoyRouteOnMap(_eventData)
    trigger.action.outText("F10 MAP: CONVOY ROUTE - follow the yellow arrow route and the START/END path markers.", 15)
    trigger.action.outSound("attn_convoy.ogg")
end

WE.registerEventStatus("CONVOY", function()
    if #WE.activeConvoyEvents == 0 then
        return nil
    end

    local _lines = {}
    for _i, _eventData in ipairs(WE.activeConvoyEvents) do
        local _remaining = math.max(0, math.ceil(_eventData.endsAt - timer.getTime()))
        local _prefix = #WE.activeConvoyEvents > 1 and string.format("Convoy %d: ", _i) or "Convoy: "
        table.insert(_lines, string.format("%sen route from %s to %s, %d seconds remaining.",
            _prefix, _eventData.origin, _eventData.destination, _remaining))
    end
    return table.concat(_lines, "\n\n")
end)

WE.EVENT.CONVOYEVENT = {}

--- DCS event handler: resolves a convoy mission once every tracked unit is dead.
--- @param event table DCS world event
function WE.EVENT.CONVOYEVENT:onEvent(event)
    if not event then return end
    if event.id ~= world.event.S_EVENT_DEAD then return end
    if #WE.activeConvoyEvents == 0 then return end
    if not event.initiator then return end

    local _unit = event.initiator
    if not _unit.getName or type(_unit.getName) ~= "function" then return end

    local _name = _unit:getName()
    for _i = #WE.activeConvoyEvents, 1, -1 do
        local _eventData = WE.activeConvoyEvents[_i]
        if not _eventData.ended and _eventData.unitNames[_name] then
            WE.logInfo("Convoy: %s destroyed, checking remaining units (mission %s -> %s)",
                _name, _eventData.origin, _eventData.destination)
            if WE.areAllUnitsDead(_eventData.unitNames) then
                WE.endConvoyEvent(_eventData, "SUCCESS")
            end
        end
    end
end

world.addEventHandler(WE.EVENT.CONVOYEVENT)

-----------------[[ END OF event_convoy.lua ]]-----------------
