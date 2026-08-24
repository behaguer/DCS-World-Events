--[[ 
        DCS-WORLD-Events - Dynamic world events for DCS World

        Allows the addition of dynamic world events to your mission. 
        These events can be accessed through the radio menu item World Event. 
        They can be triggered manually by users with access to the radio item or they can be set to randomly spawn. 
        Only one event can be active at a time and events will have a timer. 
        The world event has its own state management and doesn't rely on any external scripts, just plug the script into your mission and go.

]]

WE = {}

--- Identifier. All output in DCS.log will start with this.
WE.Id = "World Event - "

--- Version.
WE.Version = "0.1.0"

WE.EVENT = {}
-----------------[[ types.lua ]]-----------------

-- DCS Type Definitions

---@class Unit DCS Unit object
---@field getByName fun(name: string): Unit|nil
---@field getName fun(self: Unit): string
---@field isActive fun(self: Unit): boolean
---@field getLife fun(self: Unit): number
---@field getPoint fun(self: Unit): table
---@field getPosition fun(self: Unit): table
---@field getCoalition fun(self: Unit): number
---@field getCountry fun(self: Unit): number
---@field getTypeName fun(self: Unit): string
---@field getPlayerName fun(self: Unit): string|nil
---@field getVelocity fun(self: Unit): table
---@field getID fun(self: Unit): number

---@class Group DCS Group object
---@field getByName fun(name: string): Group|nil
---@field getName fun(self: Group): string
---@field isExist fun(self: Group): boolean
---@field getID fun(self: Group): number
---@field getUnits fun(self: Group): Unit[]
---@field getCoalition fun(self: Group): number

---@class Object DCS Object
---@field getName fun(self: Object): string
---@field getPoint fun(self: Object): table
---@field getPosition fun(self: Object): table
---@field isExist fun(self: Object): boolean

---@class StaticObject DCS Static Object
---@field getByName fun(name: string): StaticObject|nil
---@field getName fun(self: StaticObject): string
---@field getPoint fun(self: StaticObject): table
---@field getPosition fun(self: StaticObject): table

---@class Airbase DCS Airbase object
---@field getByName fun(name: string): Airbase|nil
---@field getName fun(self: Airbase): string
---@field getPoint fun(self: Airbase): table
---@field getCoalition fun(self: Airbase): number
---@field getID fun(self: Airbase): number
---@field isExist fun(self: Airbase): boolean
---@field getRunways fun(self: Airbase): table|nil
---@field setCoalition fun(self: Airbase, coalition: number)
---@field autoCapture fun(self: Airbase, auto: boolean)

---@class GroupTemplate
---@field name string Template name
---@field units table[] Array of unit definitions
---@field total? number Total count of units (set by function if missing)
---@field country? number Country ID
---@field category? number Unit category

-----------------[[ END OF types.lua ]]-----------------
-----------------[[ config.lua ]]-----------------

------------------- To add debugging messages to dcs.log, change the following log levels to `true`; `Debug` is less detailed than `Trace`
WE.Debug = true
WE.Trace = true
WE.RadioUsers = { -- starting names of airframes that can access the radio menu
    [1] = "Player",
    [2] = "[Patreon]",
    -- [3] = "All"
}
WE.EnabledEvents = {
    ["VIP_ESCORT"] = true,
    ["BASE_ATTACK"] = true,
    ["STRONGHOLD"] = true,
}
-- Controls the order events appear in the "Spawn Event" radio submenu.
-- Any event not listed here still works, it's just appended at the end.
WE.EventOrder = {
    "VIP_ESCORT",
    "BASE_ATTACK",
    "STRONGHOLD",
}

-----------------[[ END OF config.lua ]]-----------------
-----------------[[ state.lua ]]-----------------

--- default states
WE.nextUnitId = 1;
WE.nextGroupId = 1;
WE.is_active = 0;

--- Event handling system for World Events
WE.eventHandlers = {}

WE.events = {}

-----------------[[ END OF state.lua ]]-----------------
-----------------[[ utility.lua ]]-----------------

--- print an object for a debugging log
--- @param o any object to print
--- @param level? number depth level for recursion
--- @return string formatted string representation of the object
function WE.p(o, level)
    local MAX_LEVEL = 20
    if level == nil then level = 0 end
    if level > MAX_LEVEL then
        WE.logError("max depth reached in WE.p : " .. tostring(MAX_LEVEL))
        return ""
    end
    local text = ""
    if (type(o) == "table") then
        text = "\n"
        for key, value in pairs(o) do
            for i = 0, level do
                text = text .. " "
            end
            text = text .. "." .. key .. "=" .. WE.p(value, level + 1) .. "\n"
        end
    elseif (type(o) == "function") then
        text = "[function]"
    elseif (type(o) == "boolean") then
        if o == true then
            text = "[true]"
        else
            text = "[false]"
        end
    else
        if o == nil then
            text = "[nil]"
        else
            text = tostring(o)
        end
    end
    return text
end

--- Format text for output
--- @param text string text to format
--- @param ... any arguments to format into the text
--- @return string formatted text
function WE.formatText(text, ...)
    if not text then
        return ""
    end
    if type(text) ~= 'string' then
        text = WE.p(text)
    else
        local args = ...
        if args and args.n and args.n > 0 then
            local pArgs = {}
            for i = 1, args.n do
                pArgs[i] = WE.p(args[i])
            end
            text = text:format(unpack(pArgs))
        end
    end
    local fName = nil
    local cLine = nil
    if debug and debug.getinfo then
        local dInfo = debug.getinfo(3)
        fName = dInfo.name
        cLine = dInfo.currentline
    end
    if fName and cLine then
        return fName .. '|' .. cLine .. ': ' .. text
    elseif cLine then
        return cLine .. ': ' .. text
    else
        return ' ' .. text
    end
end

--- log an error
--- @param message any message to log
--- @param ... any arguments to format into the message
function WE.logError(message, ...)
    message = WE.formatText(message, arg)
    env.info(" E - " .. WE.Id .. message)
end

--- log a warning
--- @param message any message to log
--- @param ... any arguments to format into the message
function WE.logWarning(message, ...)
    message = WE.formatText(message, arg)
    env.info(" W - " .. WE.Id .. message)
end

--- log an info
--- @param message any message to log
--- @param ... any arguments to format into the message
function WE.logInfo(message, ...)
    message = WE.formatText(message, arg)
    env.info(" I - " .. WE.Id .. message)
end

--- log an debug mesage
--- @param message any message to log
--- @param ... any arguments to format into the message
function WE.logDebug(message, ...)
    if message and WE.Debug then
        message = WE.formatText(message, arg)
        env.info(" D - " .. WE.Id .. message)
    end
end

--- log a trace mesage
--- @param message any message to log
--- @param ... any arguments to format into the message
function WE.logTrace(message, ...)
    if message and WE.Trace then
        message = WE.formatText(message, arg)
        env.info(" T - " .. WE.Id .. message)
    end
end

--- Next Unit ID generator
--- @return number next unit ID from state
WE.getNextUnitId = function()
    WE.nextUnitId = WE.nextUnitId + 1
    return WE.nextUnitId
end

--- Next Group ID generator
--- @return number next group ID from state
WE.getNextGroupId = function()
    WE.nextGroupId = WE.nextGroupId + 1
    return WE.nextGroupId
end

--- Get all currently airdrome-category airbases (excludes ships/FARPs/helipads)
--- @side 'red', 'blue' or 'neutral'
--- @return table list of Airbase objects
function WE.getAirdromes(side)
    local _airdromes = {}

    if side == nil then
        side = coalition.side.RED
    elseif side == 'red' then
        side = coalition.side.RED
    elseif side == 'blue' then
        side = coalition.side.BLUE
    elseif side == 'neutral' then
        side = coalition.side.NEUTRAL
    else
        WE.logWarning("getRedAirdromes: invalid side '%s', defaulting to RED", tostring(side))
        side = coalition.side.RED
    end

    local _bases = coalition.getAirbases(side)

    if _bases then
        for _, _base in pairs(_bases) do
            if _base and _base:isExist() then
                local _desc = _base:getDesc()
                if _desc and _desc.category == Airbase.Category.AIRDROME then
                    table.insert(_airdromes, _base)
                end
            end
        end
    end

    return _airdromes
end

--- Get a runway-aligned takeoff spawn point for an airbase.
--- Spawning aircraft "From Runway" at the airbase reference point leaves them
--- misaligned wherever the reference point is not on a runway (aircraft sit
--- stuck and never take off), so use real runway data instead and fall back to
--- the reference point only when no runway data is available. The returned
--- position sits just past the runway threshold, facing down the runway.
--- @param _airbase Airbase airbase to query
--- @return table|nil point {x, z, y, heading} takeoff position and heading in radians
function WE.getTakeoffPoint(_airbase)
    local _fallback = nil
    if _airbase and _airbase.getPoint and type(_airbase.getPoint) == "function" then
        local _point = _airbase:getPoint()
        _fallback = { x = _point.x, z = _point.z, y = _point.y, heading = 0 }
    end

    if not _airbase.getRunways or type(_airbase.getRunways) ~= "function" then
        return _fallback
    end

    local _ok, _runways = pcall(function() return _airbase:getRunways() end)
    if not _ok or type(_runways) ~= "table" or #_runways == 0 then
        WE.logWarning("getTakeoffPoint: no runway data for %s, falling back to airbase reference point",
            tostring(_airbase:getName()))
        return _fallback
    end

    -- use the longest runway that exposes usable end coordinates
    local _best = nil
    for _, _runway in ipairs(_runways) do
        if _runway.end1 and _runway.end2 then
            if _best == nil or (_runway.length or 0) > (_best.length or 0) then
                _best = _runway
            end
        end
    end

    if _best == nil then
        WE.logWarning("getTakeoffPoint: no usable runway ends for %s, falling back to airbase reference point",
            tostring(_airbase:getName()))
        return _fallback
    end

    local _e1, _e2 = _best.end1, _best.end2
    local _dx = _e2.x - _e1.x
    local _dz = _e2.z - _e1.z
    local _len = math.sqrt(_dx * _dx + _dz * _dz)

    -- spawn on end1 rolling toward end2 unless the runway heading says otherwise
    local _spawnX, _spawnZ, _spawnY = _e1.x, _e1.z, _e1.y
    local _dirX, _dirZ = 0, 0
    if _len > 0 then
        _dirX = _dx / _len
        _dirZ = _dz / _len
    end

    -- align the roll direction with the runway heading when available,
    -- starting from the opposite end so the aircraft uses the full length.
    -- Only trust the heading when it is a plausible radian value.
    if type(_best.heading) == "number" and math.abs(_best.heading) <= (2 * math.pi) then
        local _headingX = math.sin(_best.heading)
        local _headingZ = math.cos(_best.heading)
        if _headingX * _dirX + _headingZ * _dirZ < 0 then
            _spawnX = _e2.x
            _spawnZ = _e2.z
            _spawnY = _e2.y
            _dirX = -_dirX
            _dirZ = -_dirZ
        end
    end

    -- step the spawn point down the runway from the threshold: DCS snaps
    -- "From Runway" groups to the runway end nearest the spawn position, so
    -- spawning exactly ON the threshold can leave the aircraft facing back
    -- toward the threshold instead of down the runway. A small offset makes
    -- the intended takeoff end unambiguous and matches the returned heading.
    local _spawnOffsetMeters = 60

    return {
        x = _spawnX + _dirX * _spawnOffsetMeters,
        z = _spawnZ + _dirZ * _spawnOffsetMeters,
        y = _spawnY,
        heading = math.atan2(_dirX, _dirZ),
    }
end

--- Sample terrain height at evenly spaced points along a line and return the maximum.
--- @param x1 number start x
--- @param z1 number start z
--- @param x2 number end x
--- @param z2 number end z
--- @param numSamples number of sample points (default 5)
--- @return number maximum terrain height found across all samples
function WE.getMaxTerrainHeight(x1, z1, x2, z2, numSamples)
    numSamples = numSamples or 5
    local _maxH = -1e9
    for i = 0, numSamples - 1 do
        local _t = i / (numSamples - 1)
        local _x = x1 + (x2 - x1) * _t
        local _y = z1 + (z2 - z1) * _t
        local _h = land.getHeight({ x = _x, y = _y })
        if _h > _maxH then
            _maxH = _h
        end
    end
    return _maxH
end

--- Get transport unit by name if active and alive
--- @param _unitName string name of the transport unit
--- @return Unit|nil transport unit object if active and alive, otherwise nil
function WE.getTransportUnit(_unitName)
    if _unitName == nil then
        return nil
    end

    local transportUnitObject = Unit.getByName(_unitName)

    if transportUnitObject ~= nil and transportUnitObject:isActive() and transportUnitObject:getLife() > 0 then
        return transportUnitObject
    end
    return nil
end



--- Get point at 12 o'clock from unit
--- @param _unit Unit transport unit
--- @param _offset number|nil offset distance in meters
function WE.getPointAt12Oclock(_unit, _offset)
    return WE.getPointAtDirection(_unit, _offset, 0)
end

--- Get point at 6 o'clock from unit
--- @param _unit Unit transport unit
--- @param _offset number|nil offset distance in meters
function WE.getPointAt6Oclock(_unit, _offset)
    return WE.getPointAtDirection(_unit, _offset, math.pi)
end

--- Get point at direction from unit
--- @param _unit Unit transport unit
--- @param _offset number|nil offset distance in meters
--- @param _directionInRadian number direction in radians
--- @return table point table with x, y, z coordinates
function WE.getPointAtDirection(_unit, _offset, _directionInRadian)
    if _offset == nil then
        _offset = WE.getSecureDistanceFromUnit(_unit:getName())
    end
    --WE.logTrace("_offset = %s", WE.p(_offset))
    local _randomOffsetX = math.random(0, WE.randomCrateSpacing * 2) - WE.randomCrateSpacing
    local _randomOffsetZ = math.random(0, WE.randomCrateSpacing)
    --WE.logTrace("_randomOffsetX = %s", WE.p(_randomOffsetX))
    --WE.logTrace("_randomOffsetZ = %s", WE.p(_randomOffsetZ))
    local _position = _unit:getPosition()
    local _angle    = math.atan2(_position.x.z, _position.x.x) + _directionInRadian
    local _xOffset  = math.cos(_angle) * (_offset + _randomOffsetX)
    local _zOffset  = math.sin(_angle) * (_offset + _randomOffsetZ)
    local _point    = _unit:getPoint()
    return { x = _point.x + _xOffset, z = _point.z + _zOffset, y = _point.y }
end

--- Get relative point from reference point -- return coord point at distance and angle from _refPointXZTable
--- @param _refPointXZTable table reference point with x, y, z coordinates
--- @param _distance number distance from reference point
--- @param _angle_radians number angle in radians from reference point
--- @return table relative point with x, y, z coordinates
function WE.getRelativePoint(_refPointXZTable, _distance, _angle_radians)  
    local relativePoint = {}
    relativePoint.x = _refPointXZTable.x + _distance * math.cos(_angle_radians)
    if _refPointXZTable.z == nil then
        relativePoint.y = _refPointXZTable.y + _distance * math.sin(_angle_radians)
    else
        relativePoint.z = _refPointXZTable.z + _distance * math.sin(_angle_radians)
    end
    return relativePoint
end

--- Check if troops or vehicles are onboard a helicopter
--- @param _heli Unit transport unit
--- @param _troops boolean true to check for troops, false to check for vehicles
--- @return boolean true if troops/vehicles are onboard, false otherwise
function WE.troopsOnboard(_heli, _troops)
    if WE.inTransitTroops[_heli:getName()] ~= nil then
        local _onboard = WE.inTransitTroops[_heli:getName()]

        if _troops then
            if _onboard.troops ~= nil and _onboard.troops.units ~= nil and #_onboard.troops.units > 0 then
                return true
            else
                return false
            end
        else
            if _onboard.vehicles ~= nil and _onboard.vehicles.units ~= nil and #_onboard.vehicles.units > 0 then
                return true
            else
                return false
            end
        end
    else
        return false
    end
end

--- Get player name or type if dropped by AI (no player name)
--- @param _heli Unit transport unit
--- @return string|nil player name or unit type
function WE.getPlayerNameOrType(_heli)
    if _heli:getPlayerName() == nil then
        return _heli:getTypeName()
    else
        return _heli:getPlayerName()
    end
end

--- Check if helicopter is in an extract zone
--- @param _heli Unit transport unit
--- @return table|boolean extract zone details table if in extract zone, false otherwise
function WE.inExtractZone(_heli)
    local _heliPoint = _heli:getPoint()

    for _, _zoneDetails in pairs(WE.extractZones) do
        --get distance to center
        local _dist = WE.getDistance(_heliPoint, _zoneDetails.point)

        if _dist <= _zoneDetails.radius then
            return _zoneDetails
        end
    end

    return false
end




--- Insert troop types into troop array
--- @param _troopType string troop unit type
--- @param _count number number of troops to insert
--- @param _troopArray table troop array to insert into
--- @param _troopName string|nil troop name to use instead of type
--- @return table updated troop array
function WE.insertIntoTroopsArray(_troopType, _count, _troopArray, _troopName)
    for _i = 1, _count do
        local _unitId = WE.getNextUnitId()
        table.insert(_troopArray,
            { type = _troopType, unitId = _unitId, name = string.format("Dropped %s #%i", _troopName or _troopType,
                _unitId) })
    end

    return _troopArray
end

--- Generate troop types for transport
--- @param _side number coalition side
--- @param _countOrTemplate number|table number of troops or template table
--- @param _country number country ID
--- @return table troop details table
function WE.generateTroopTypes(_side, _countOrTemplate, _country)
    local _troops = {}
    local _weight = 0
    local _hasJTAC = false

    local function getSoldiersWeight(count, additionalWeight)
        local _weight = 0
        for i = 1, count do
            local _soldierWeight = math.random(90, 120) * WE.SOLDIER_WEIGHT / 100
            _weight = _weight + _soldierWeight + WE.KIT_WEIGHT + additionalWeight
        end
        return _weight
    end

    if type(_countOrTemplate) == "table" then
        if _countOrTemplate.aa then
            if _side == 2 then
                _troops = WE.insertIntoTroopsArray("Soldier stinger", _countOrTemplate.aa, _troops)
            else
                _troops = WE.insertIntoTroopsArray("SA-18 Igla manpad", _countOrTemplate.aa, _troops)
            end
            _weight = _weight + getSoldiersWeight(_countOrTemplate.aa, WE.MANPAD_WEIGHT)
        end

        if _countOrTemplate.inf then
            if _side == 2 then
                _troops = WE.insertIntoTroopsArray("Soldier M4 GRG", _countOrTemplate.inf, _troops)
            else
                _troops = WE.insertIntoTroopsArray("Infantry AK", _countOrTemplate.inf, _troops)
            end
            _weight = _weight + getSoldiersWeight(_countOrTemplate.inf, WE.RIFLE_WEIGHT)
        end

        if _countOrTemplate.mg then
            if _side == 2 then
                _troops = WE.insertIntoTroopsArray("Soldier M249", _countOrTemplate.mg, _troops)
            else
                _troops = WE.insertIntoTroopsArray("Paratrooper AKS-74", _countOrTemplate.mg, _troops)
            end
            _weight = _weight + getSoldiersWeight(_countOrTemplate.mg, WE.MG_WEIGHT)
        end

        if _countOrTemplate.at then
            _troops = WE.insertIntoTroopsArray("Paratrooper RPG-16", _countOrTemplate.at, _troops)
            _weight = _weight + getSoldiersWeight(_countOrTemplate.at, WE.RPG_WEIGHT)
        end

        if _countOrTemplate.mortar then
            _troops = WE.insertIntoTroopsArray("2B11 mortar", _countOrTemplate.mortar, _troops)
            _weight = _weight + getSoldiersWeight(_countOrTemplate.mortar, WE.MORTAR_WEIGHT)
        end

        if _countOrTemplate.jtac then
            if _side == 2 then
                _troops = WE.insertIntoTroopsArray("Soldier M4 GRG", _countOrTemplate.jtac, _troops, "JTAC")
            else
                _troops = WE.insertIntoTroopsArray("Infantry AK", _countOrTemplate.jtac, _troops, "JTAC")
            end
            _hasJTAC = true
            _weight = _weight + getSoldiersWeight(_countOrTemplate.jtac, WE.JTAC_WEIGHT + WE.RIFLE_WEIGHT)
        end
    else
        for _i = 1, _countOrTemplate do
            local _unitType = "Infantry AK"

            if _side == 2 then
                if _i <= 2 then
                    _unitType = "Soldier M249"
                    _weight = _weight + getSoldiersWeight(1, WE.MG_WEIGHT)
                elseif WE.spawnRPGWithCoalition and _i > 2 and _i <= 4 then
                    _unitType = "Paratrooper RPG-16"
                    _weight = _weight + getSoldiersWeight(1, WE.RPG_WEIGHT)
                elseif WE.spawnStinger and _i > 4 and _i <= 5 then
                    _unitType = "Soldier stinger"
                    _weight = _weight + getSoldiersWeight(1, WE.MANPAD_WEIGHT)
                else
                    _unitType = "Soldier M4 GRG"
                    _weight = _weight + getSoldiersWeight(1, WE.RIFLE_WEIGHT)
                end
            else
                if _i <= 2 then
                    _unitType = "Paratrooper AKS-74"
                    _weight = _weight + getSoldiersWeight(1, WE.MG_WEIGHT)
                elseif WE.spawnRPGWithCoalition and _i > 2 and _i <= 4 then
                    _unitType = "Paratrooper RPG-16"
                    _weight = _weight + getSoldiersWeight(1, WE.RPG_WEIGHT)
                elseif WE.spawnStinger and _i > 4 and _i <= 5 then
                    _unitType = "SA-18 Igla manpad"
                    _weight = _weight + getSoldiersWeight(1, WE.MANPAD_WEIGHT)
                else
                    _unitType = "Infantry AK"
                    _weight = _weight + getSoldiersWeight(1, WE.RIFLE_WEIGHT)
                end
            end

            local _unitId = WE.getNextUnitId()

            _troops[_i] = { type = _unitType, unitId = _unitId, name = string.format("Dropped %s #%i", _unitType, _unitId) }
        end
    end

    local _groupId = WE.getNextGroupId()
    local _groupName = "Dropped Group"
    if _hasJTAC then
        _groupName = "Dropped JTAC Group"
    end
    local _details = { units = _troops, groupId = _groupId, groupName = string.format("%s %i", _groupName, _groupId), side =
    _side, country = _country, weight = _weight, jtac = _hasJTAC }

    return _details
end

--- Special F10 function for players for troops
--- @param _args table arguments table
--- @return boolean true if troops extracted or unloaded, false otherwise
function WE.unloadExtractTroops(_args)
    local _heli = WE.getTransportUnit(_args[1])

    if _heli == nil then
        return false
    end

    local _extract = nil
    if not WE.inAir(_heli) then
        if _heli:getCoalition() == 1 then
            _extract = WE.findNearestGroup(_heli, WE.droppedTroopsRED)
        else
            _extract = WE.findNearestGroup(_heli, WE.droppedTroopsBLUE)
        end
    end

    if _extract ~= nil and not WE.troopsOnboard(_heli, true) then
        -- search for nearest troops to pickup
        return WE.extractTroops({ _heli:getName(), true })
    else
        return WE.unloadTroops({ _heli:getName(), true, true })
    end
end

--- load troops onto vehicle
--- @param _heli Unit transport unit
--- @param _troops boolean true to load troops, false to load vehicles
--- @param _numberOrTemplate number|table number of troops or template table
function WE.loadTroops(_heli, _troops, _numberOrTemplate)
    -- load troops + vehicles if c130 or herc
    -- "M1045 HMMWV TOW"
    -- "M1043 HMMWV Armament"
    local _onboard = WE.inTransitTroops[_heli:getName()]

    --number doesnt apply to vehicles
    if _numberOrTemplate == nil or (type(_numberOrTemplate) ~= "table" and type(_numberOrTemplate) ~= "number") then
        _numberOrTemplate = WE.getTransportLimit(_heli:getTypeName())
    end

    if _onboard == nil then
        _onboard = { troops = {}, vehicles = {} }
    end

    local _list
    if _heli:getCoalition() == 1 then
        _list = WE.vehiclesForTransportRED
    else
        _list = WE.vehiclesForTransportBLUE
    end

    if _troops then
        _onboard.troops = WE.generateTroopTypes(_heli:getCoalition(), _numberOrTemplate, _heli:getCountry())
        trigger.action.outTextForCoalition(_heli:getCoalition(),
            WE.i18n_translate("%1 loaded troops into %2", WE.getPlayerNameOrType(_heli), _heli:getTypeName()), 10)

        WE.processCallback({ unit = _heli, onboard = _onboard.troops, action = "load_troops" })
    else
        _onboard.vehicles = WE.generateVehiclesForTransport(_heli:getCoalition(), _heli:getCountry())

        local _count = #_list

        WE.processCallback({ unit = _heli, onboard = _onboard.vehicles, action = "load_vehicles" })

        trigger.action.outTextForCoalition(_heli:getCoalition(),
            WE.i18n_translate("%1 loaded %2 vehicles into %3", WE.getPlayerNameOrType(_heli), _count,
                _heli:getTypeName()), 10)
    end

    WE.inTransitTroops[_heli:getName()] = _onboard
    WE.adaptWeightToCargo(_heli:getName())
end

--- Generate vehicle types for transport
--- @param _side number coalition side
--- @param _country number country ID
--- @return table vehicle details table
function WE.generateVehiclesForTransport(_side, _country)
    local _vehicles = {}
    local _list
    if _side == 1 then
        _list = WE.vehiclesForTransportRED
    else
        _list = WE.vehiclesForTransportBLUE
    end


    for _i, _type in ipairs(_list) do
        local _unitId = WE.getNextUnitId()
        local _weight = WE.vehiclesWeight[_type] or 2500
        _vehicles[_i] = { type = _type, unitId = _unitId, name = string.format("Dropped %s #%i", _type, _unitId), weight =
        _weight }
    end


    local _groupId = WE.getNextGroupId()
    local _details = { units = _vehicles, groupId = _groupId, groupName = string.format("Dropped Group %i", _groupId), side =
    _side, country = _country }

    return _details
end

--- Load or unload FOB crate from helicopter
--- @param _args table arguments table
function WE.loadUnloadFOBCrate(_args)
    local _heli = WE.getTransportUnit(_args[1])
    local _troops = _args[2]

    if _heli == nil then
        return
    end

    if WE.inAir(_heli) == true then
        return
    end


    local _side = _heli:getCoalition()

    local _inZone = WE.inLogisticsZone(_heli)
    local _crateOnboard = WE.inTransitFOBCrates[_heli:getName()] ~= nil

    if _inZone == false and _crateOnboard == true then
        WE.inTransitFOBCrates[_heli:getName()] = nil

        local _position = _heli:getPosition()
        local _point = _heli:getPoint()
        local _side = _heli:getCoalition()

        -- Spawn 9 FOB crates in a 3x3 grid pattern
        local _cratesSpawned = 0
        local _spacing = 15 -- Distance between crates
        
        for _row = -1, 1 do
            for _col = -1, 1 do
                local _unitId = WE.getNextUnitId()
                local _name = string.format("FOB Crate #%i", _unitId)
                
                -- Calculate offset from helicopter position
                local _xOffset = _col * _spacing
                local _yOffset = _row * _spacing
                
                -- Try to spawn at 6 oclock with grid offset
                local _angle = math.atan2(_position.x.z, _position.x.x)
                local _baseXOffset = math.cos(_angle) * -60
                local _baseYOffset = math.sin(_angle) * -60
                
                local _spawnedCrate = WE.spawnFOBCrateStatic(_heli:getCountry(), _unitId,
                    { x = _point.x + _baseXOffset + _xOffset, z = _point.z + _baseYOffset + _yOffset }, _name)

                if _side == 1 then
                    WE.droppedFOBCratesRED[_name] = _name
                else
                    WE.droppedFOBCratesBLUE[_name] = _name
                end
                
                _cratesSpawned = _cratesSpawned + 1
            end
        end

        trigger.action.outTextForCoalition(_heli:getCoalition(),
            WE.i18n_translate("%1 delivered %2 FOB Crates", WE.getPlayerNameOrType(_heli), _cratesSpawned), 10)

        WE.displayMessageToGroup(_heli, string.format("Delivered %d FOB Crates in a grid pattern behind you", _cratesSpawned), 10)
    elseif _inZone == true and _crateOnboard == true then
        WE.displayMessageToGroup(_heli, WE.i18n_translate("FOB Crate dropped back to base"), 10)

        WE.inTransitFOBCrates[_heli:getName()] = nil
    elseif _inZone == true and _crateOnboard == false then
        WE.displayMessageToGroup(_heli, WE.i18n_translate("FOB Crate Loaded"), 10)

        WE.inTransitFOBCrates[_heli:getName()] = true

        trigger.action.outTextForCoalition(_heli:getCoalition(),
            WE.i18n_translate("%1 loaded a FOB Crate ready for delivery!", WE.getPlayerNameOrType(_heli)), 10)
    else
        -- nearest Crate
        local _crates = WE.getCratesAndDistance(_heli)
        local _nearestCrate = WE.getClosestCrate(_heli, _crates, "FOB")

        if _nearestCrate ~= nil and _nearestCrate.dist < 150 then
            WE.displayMessageToGroup(_heli, WE.i18n_translate("FOB Crate Loaded"), 10)
            WE.inTransitFOBCrates[_heli:getName()] = true

            trigger.action.outTextForCoalition(_heli:getCoalition(),
                WE.i18n_translate("%1 loaded a FOB Crate ready for delivery!", WE.getPlayerNameOrType(_heli)), 10)

            if _side == 1 then
                WE.droppedFOBCratesRED[_nearestCrate.crateUnit:getName()] = nil
            else
                WE.droppedFOBCratesBLUE[_nearestCrate.crateUnit:getName()] = nil
            end

            --remove
            _nearestCrate.crateUnit:destroy()
        else
            WE.displayMessageToGroup(_heli,
                WE.i18n_translate("There are no friendly logistic units nearby to load a FOB crate from!"), 10)
        end
    end
end

--- Return count of troops in game by Coalition
--- @param params table scheduler params
--- @param t number current time
--- @return number reschedule time in seconds
function WE.updateTroopsInGame(params, t)
 	if t == nil then t = timer.getTime() + 1; end
    WE.InfantryInGameCount  = {0, 0}
    for coalitionId=1, 2 do				-- for each CoaId
        for k,v in ipairs(coalition.getGroups(coalitionId, Group.Category.GROUND)) do   -- for each GROUND type group
			for index, unitObj in pairs(v:getUnits()) do		-- for each unit in group
                if unitObj:getDesc().attributes.Infantry then
                    WE.InfantryInGameCount[coalitionId] = WE.InfantryInGameCount[coalitionId] + 1
                end
            end
        end
    end
    return 5		-- reschedule each 5"
end

--- Load troops onto helicopter from zone or extract nearby troops
--- @param _args table arguments table
--- @return boolean true if troops loaded, false otherwise
function WE.loadTroopsFromZone(_args)
    local _heli = WE.getTransportUnit(_args[1])
    local _troops = _args[2]
    local _groupTemplate = _args[3] or nil
    local _allowExtract = _args[4]

    if _heli == nil then
        return false
    end

    local _zone = WE.inPickupZone(_heli)

    if WE.troopsOnboard(_heli, _troops) then
        if _troops then
            WE.displayMessageToGroup(_heli, WE.i18n_translate("You already have troops onboard."), 10)
        else
            WE.displayMessageToGroup(_heli, WE.i18n_translate("You already have vehicles onboard."), 10)
        end
        return false
    end

    local _extract

    if _allowExtract then
        -- first check for extractable troops regardless of if we're in a zone or not
        if _troops then
            if _heli:getCoalition() == 1 then
                _extract = WE.findNearestGroup(_heli, WE.droppedTroopsRED)
            else
                _extract = WE.findNearestGroup(_heli, WE.droppedTroopsBLUE)
            end
        else

            if _heli:getCoalition() == 1 then
                _extract = WE.findNearestGroup(_heli, WE.droppedVehiclesRED)
            else
                _extract = WE.findNearestGroup(_heli, WE.droppedVehiclesBLUE)
            end
        end
    end

    if _extract ~= nil then
        -- search for nearest troops to pickup
        return WE.extractTroops({_heli:getName(), _troops})
    elseif _zone.inZone == true then

        local heloCoa = _heli:getCoalition()
        WE.logTrace("FG_ heloCoa =  %s", WE.p(heloCoa))
        WE.logTrace("FG_ (WE.nbLimitSpawnedTroops[1]~=0 or WE.nbLimitSpawnedTroops[2]~=0) =  %s", WE.p(WE.nbLimitSpawnedTroops[1]~=0 or WE.nbLimitSpawnedTroops[2]~=0))
        WE.logTrace("FG_ WE.InfantryInGameCount[heloCoa] =  %s", WE.p(WE.InfantryInGameCount[heloCoa]))
        
        local groupTotal = 0
        if _groupTemplate then
            if type(_groupTemplate) == "table" and _groupTemplate.total and type(_groupTemplate.total) == "number" then
                groupTotal = _groupTemplate.total
            elseif type(_groupTemplate) == "number" then
                groupTotal = _groupTemplate
            end
        end

        WE.logTrace("FG_ _groupTemplate.total =  %s", WE.p(groupTotal))
        WE.logTrace("FG_ WE.nbLimitSpawnedTroops[%s].total =  %s", WE.p(heloCoa), WE.p(WE.nbLimitSpawnedTroops[heloCoa]))

        local limitReached = true
        if (WE.nbLimitSpawnedTroops[1]~=0 or WE.nbLimitSpawnedTroops[2]~=0) and (WE.InfantryInGameCount[heloCoa] + groupTotal > WE.nbLimitSpawnedTroops[heloCoa]) then  -- load troops only if Coa limit not reached
            WE.displayMessageToGroup(_heli, WE.i18n_translate("Count Infantries limit in the mission reached, you can't load more troops"), 10)
            return false
        end

        if _zone.limit - 1 >= 0 then
            -- decrease zone counter by 1
            WE.updateZoneCounter(_zone.index, -1)
            WE.loadTroops(_heli, _troops,_groupTemplate)
            return true
        else
            WE.displayMessageToGroup(_heli, WE.i18n_translate("This area has no more reinforcements available!"), 20)
            return false
        end
    else
        if _allowExtract then
            WE.displayMessageToGroup(_heli, WE.i18n_translate("You are not in a pickup zone and no one is nearby to extract"), 10)
        else
            WE.displayMessageToGroup(_heli, WE.i18n_translate("You are not in a pickup zone"), 10)
        end

        return false
    end
end

--- unload troops from helicopter to zone or deploy nearby
--- @param _args table arguments table
--- @return boolean true if troops unloaded, false otherwise
function WE.unloadTroops(_args)
    local _heli = WE.getTransportUnit(_args[1])
    local _troops = _args[2]

    if _heli == nil then
        return false
    end

    local _zone = WE.inPickupZone(_heli)
    if not WE.troopsOnboard(_heli, _troops) then
        WE.displayMessageToGroup(_heli, WE.i18n_translate("No one to unload"), 10)

        return false
    else
        -- troops must be onboard to get here
        if _zone.inZone == true then
            if _troops then
                WE.displayMessageToGroup(_heli, WE.i18n_translate("Dropped troops back to base"), 20)

                WE.processCallback({ unit = _heli, unloaded = WE.inTransitTroops[_heli:getName()].troops, action =
                "unload_troops_zone" })

                WE.inTransitTroops[_heli:getName()].troops = nil
            else
                WE.displayMessageToGroup(_heli, WE.i18n_translate("Dropped vehicles back to base"), 20)

                WE.processCallback({ unit = _heli, unloaded = WE.inTransitTroops[_heli:getName()].vehicles, action =
                "unload_vehicles_zone" })

                WE.inTransitTroops[_heli:getName()].vehicles = nil
            end

            WE.adaptWeightToCargo(_heli:getName())

            -- increase zone counter by 1
            WE.updateZoneCounter(_zone.index, 1)

            return true
        elseif WE.troopsOnboard(_heli, _troops) then
            return WE.deployTroops(_heli, _troops)
        end
    end
    return false
end

--- Display message to unit's group
--- @param _unit Unit unit to get group from
--- @param _text string message text
--- @param _time number display time
--- @param _clear? boolean clear previous messages
function WE.displayMessageToGroup(_unit, _text, _time, _clear)
    local _groupId = WE.getGroupId(_unit)
    if _groupId then
        if _clear == true then
            trigger.action.outTextForGroup(_groupId, _text, _time, _clear)
        else
            trigger.action.outTextForGroup(_groupId, _text, _time)
        end
    end
end

--- Get height difference between unit and ground
--- @param _unit Unit unit to check
--- @return number height difference
function WE.heightDiff(_unit)
    local _point = _unit:getPoint()
    return _point.y - land.getHeight({ x = _point.x, y = _point.z })
end

--- Get crate static object by name
--- @param _name string crate unit name
--- @return Unit crate static object
function WE.getCrateObject(_name)
    local _crate

    if WE.staticBugWorkaround then
        _crate = Unit.getByName(_name)
    else
        _crate = StaticObject.getByName(_name)
    end
    return _crate
end

--- Gets the center of a bunch of points!
--- @param _points table list of points
--- @return table centroid point with height
function WE.getCentroid(_points)
    local _tx, _ty = 0, 0
    for _index, _point in ipairs(_points) do
        _tx = _tx + _point.x
        _ty = _ty + _point.z
    end

    local _npoints = #_points

    local _point = { x = _tx / _npoints, z = _ty / _npoints }

    _point.y = land.getHeight({ _point.x, _point.z })

    return _point
end

--- Count the number of entries in a table
--- @param _table table input table
--- @return number count of entries
function WE.countTableEntries(_table)
    if _table == nil then
        return 0
    end


    local _count = 0

    for _key, _value in pairs(_table) do
        _count = _count + 1
    end

    return _count
end

--- Find nearest enemy ground unit from point
--- @param _side number side of searching unit
--- @param _point table point to search from
--- @param _searchDistance number maximum search distance
--- @return table point of nearest enemy or random point
function WE.findNearestEnemy(_side, _point, _searchDistance)
    local _closestEnemy = nil

    local _groups

    local _closestEnemyDist = _searchDistance

    local _heliPoint = _point

    if _side == 2 then
        _groups = coalition.getGroups(1, Group.Category.GROUND)
    else
        _groups = coalition.getGroups(2, Group.Category.GROUND)
    end

    for _, _group in pairs(_groups) do
        if _group ~= nil then
            local _units = _group:getUnits()

            if _units ~= nil and #_units > 0 then
                local _leader = nil

                -- find alive leader
                for x = 1, #_units do
                    if _units[x]:getLife() > 0 then
                        _leader = _units[x]
                        break
                    end
                end

                if _leader ~= nil then
                    local _leaderPos = _leader:getPoint()
                    local _dist = WE.getDistance(_heliPoint, _leaderPos)
                    if _dist < _closestEnemyDist then
                        _closestEnemyDist = _dist
                        _closestEnemy = _leaderPos
                    end
                end
            end
        end
    end


    -- no enemy - move to random point
    if _closestEnemy ~= nil then
        -- env.info("found enemy")
        return _closestEnemy
    else
        local _x = _heliPoint.x + math.random(0, WE.maximumMoveDistance) - math.random(0, WE.maximumMoveDistance)
        local _z = _heliPoint.z + math.random(0, WE.maximumMoveDistance) - math.random(0, WE.maximumMoveDistance)
        local _y = _heliPoint.y + math.random(0, WE.maximumMoveDistance) - math.random(0, WE.maximumMoveDistance)

        return { x = _x, z = _z, y = _y }
    end
end

--- Find nearest group from list
--- @param _heli Unit helicopter unit
--- @param _groups table list of group names
--- @return table|nil nearest group and details
function WE.findNearestGroup(_heli, _groups)
    local _closestGroupDetails = {}
    local _closestGroup = nil

    local _closestGroupDist = WE.maxExtractDistance

    local _heliPoint = _heli:getPoint()

    for _, _groupName in pairs(_groups) do
        local _group = Group.getByName(_groupName)

        if _group ~= nil then
            local _units = _group:getUnits()

            if _units ~= nil and #_units > 0 then
                local _leader = nil

                local _groupDetails = { groupId = _group:getID(), groupName = _group:getName(), side = _group
                :getCoalition(), units = {} }

                -- find alive leader
                for x = 1, #_units do
                    if _units[x]:getLife() > 0 then
                        if _leader == nil then
                            _leader = _units[x]
                            -- set country based on leader
                            _groupDetails.country = _leader:getCountry()
                        end

                        local _unitDetails = { type = _units[x]:getTypeName(), unitId = _units[x]:getID(), name = _units
                        [x]:getName() }

                        table.insert(_groupDetails.units, _unitDetails)
                    end
                end

                if _leader ~= nil then
                    local _leaderPos = _leader:getPoint()
                    local _dist = WE.getDistance(_heliPoint, _leaderPos)
                    if _dist < _closestGroupDist then
                        _closestGroupDist = _dist
                        _closestGroupDetails = _groupDetails
                        _closestGroup = _group
                    end
                end
            end
        end
    end


    if _closestGroup ~= nil then
        return { group = _closestGroup, details = _closestGroupDetails }
    else
        return nil
    end
end

--- Create unit table for spawning
--- @param _x number x position
--- @param _y number y position
--- @param _angle number heading angle in radians
--- @param _details table unit details
--- @return table unit table
function WE.createUnit(_x, _y, _angle, _details)
    local _newUnit = {
        ["y"] = _y,
        ["type"] = _details.type,
        ["name"] = _details.name,
        --    ["unitId"] = _details.unitId,
        ["heading"] = _angle,
        ["playerCanDrive"] = true,
        ["skill"] = "Excellent",
        ["x"] = _x,
    }

    return _newUnit
end


--- Drop smoke from helicopter
--- @param _args table arguments (heli name, smoke color)
function WE.dropSmoke(_args)
    local _heli = WE.getTransportUnit(_args[1])

    if _heli ~= nil then
        local _colour = ""

        if _args[2] == trigger.smokeColor.Red then
            _colour = "RED"
        elseif _args[2] == trigger.smokeColor.Blue then
            _colour = "BLUE"
        elseif _args[2] == trigger.smokeColor.Green then
            _colour = "GREEN"
        elseif _args[2] == trigger.smokeColor.Orange then
            _colour = "ORANGE"
        end

        local _point = _heli:getPoint()

        local _pos2 = { x = _point.x, y = _point.z }
        local _alt = land.getHeight(_pos2)
        local _pos3 = { x = _point.x, y = _alt, z = _point.z }

        trigger.action.smoke(_pos3, _args[2])

        trigger.action.outTextForCoalition(_heli:getCoalition(),
            WE.i18n_translate("%1 dropped %2 smoke.", WE.getPlayerNameOrType(_heli), _colour), 10)
    end
end

--- Can unit carry vehicles
--- @param _unit Unit unit to check
--- @return boolean can carry vehicles
function WE.unitCanCarryVehicles(_unit)
    local _type = string.lower(_unit:getTypeName())

    for _, _name in ipairs(WE.vehicleTransportEnabled) do
        local _nameLower = string.lower(_name)
        if string.find(_type, _nameLower, 1, true) then
            return true
        end
    end

    return false
end

--- Is unit capable of dynamic cargo operations
--- @param _unit Unit unit to check
--- @return boolean capable
function WE.unitDynamicCargoCapable(_unit)
    local cache = {}
    local _type = string.lower(_unit:getTypeName())
    local result = cache[_type]
    if result == nil then
        result = false
        --WE.logDebug("WE.unitDynamicCargoCapable(_type=[%s])", WE.p(_type))
        for _, _name in ipairs(WE.dynamicCargoUnits) do
            local _nameLower = string.lower(_name)
            if string.find(_type, _nameLower, 1, true) then    --string.match does not work with patterns containing '-' as it is a magic character
                result = true
                break
            end
        end
        cache[_type] = result
    end
    return result
end

--- Process all registered callbacks
--- @param _callbackArgs table arguments to pass to callbacks
function WE.processCallback(_callbackArgs)
    for _, _callback in pairs(WE.callbacks) do
        local _status, _result = pcall(function()
            _callback(_callbackArgs)
        end)

        if (not _status) then
            env.error(string.format("Callback Error: %s", _result))
        end
    end
end

--- checks the status of all AI troop carriers and auto loads and unloads troops as long as the troops are on the ground
function WE.checkAIStatus()
    timer.scheduleFunction(WE.checkAIStatus, nil, timer.getTime() + 2)
    for _, _unitName in pairs(WE.transportPilotNames) do
        local status, error = pcall(function()
            local _unit = WE.getTransportUnit(_unitName)

            -- no player name means AI!
            if _unit ~= nil and _unit:getPlayerName() == nil then
                local _zone = WE.inPickupZone(_unit)
                --    env.error("Checking.. ".._unit:getName())
                if _zone.inZone == true and not WE.troopsOnboard(_unit, true) then
                    --     env.error("in zone, loading.. ".._unit:getName())

                    if WE.allowRandomAiTeamPickups == true then
                        -- Random troop pickup implementation
                        local _team = nil
                        if _unit:getCoalition() == 1 then
                            _team = math.floor((math.random(#WE.redTeams * 100) / 100) + 1)
                            WE.loadTroopsFromZone({ _unitName, true, WE.loadableGroups[WE.redTeams[_team]], true })
                        else
                            _team = math.floor((math.random(#WE.blueTeams * 100) / 100) + 1)
                            WE.loadTroopsFromZone({ _unitName, true, WE.loadableGroups[WE.blueTeams[_team]], true })
                        end
                    else
                        WE.loadTroopsFromZone({ _unitName, true, "", true })
                    end
                elseif WE.inDropoffZone(_unit) and WE.troopsOnboard(_unit, true) then
                    --         env.error("in dropoff zone, unloading.. ".._unit:getName())
                    WE.unloadTroops({ _unitName, true })
                end

                if WE.unitCanCarryVehicles(_unit) then
                    if _zone.inZone == true and not WE.troopsOnboard(_unit, false) then
                        WE.loadTroopsFromZone({ _unitName, false, "", true })
                    elseif WE.inDropoffZone(_unit) and WE.troopsOnboard(_unit, false) then
                        WE.unloadTroops({ _unitName, false })
                    end
                end
            end
        end)

        if (not status) then
            env.error(string.format("Error with ai status: %s", error), false)
        end
    end
end

--- Get transport limit for unit type
--- @param _unitType string unit type
--- @return number transport limit
function WE.getTransportLimit(_unitType)
    if WE.unitLoadLimits[_unitType] then
        return WE.unitLoadLimits[_unitType]
    end

    return WE.numberOfTroops
end

--- Get unit actions for unit type
--- @param _unitType string unit type
--- @return table unit actions
function WE.getUnitActions(_unitType)
    if WE.unitActions[_unitType] then
        return WE.unitActions[_unitType]
    end

    return { crates = true, troops = true }
end

--- Get distance in meters assuming a Flat world
--- @param _point1 table first point with x and z coordinates
--- @param _point2 table second point with x and z coordinates
--- @return number distance in meters
function WE.getDistance(_point1, _point2)
    local xUnit = _point1.x
    local yUnit = _point1.z
    local xZone = _point2.x
    local yZone = _point2.z

    local xDiff = xUnit - xZone
    local yDiff = yUnit - yZone

    return math.sqrt(xDiff * xDiff + yDiff * yDiff)
end

-----------------[[ END OF utility.lua ]]-----------------
-----------------[[ radio.lua ]]-----------------

--- Radio menu references for World Events
WE.radioMenu = {}

--- Check if group has access to radio commands
--- @param groupName string the name of the aircraft group
--- @return boolean true if group has access, false otherwise
function WE.hasRadioAccess(groupName)
    if not WE.RadioUsers or not groupName then
        WE.logInfo("hasRadioAccess: Missing RadioUsers or groupName - RadioUsers: %s, groupName: %s", tostring(WE.RadioUsers), tostring(groupName))
        return false
    end
    
    -- Check if "ALL" is in the RadioUsers table
    for _, user in pairs(WE.RadioUsers) do
        if string.upper(user) == "ALL" then
            WE.logInfo("hasRadioAccess: Found 'ALL' access for group %s", groupName)
            return true
        end
    end
    
    -- Check if any of the RadioUsers strings are contained in the group name
    for _, user in pairs(WE.RadioUsers) do
        WE.logInfo("hasRadioAccess: Checking if group '%s' contains user string '%s'", groupName, user)
        if string.find(string.upper(groupName), string.upper(user), 1, true) then
            WE.logInfo("hasRadioAccess: Group '%s' GRANTED access (matches user string '%s')", groupName, user)
            return true
        end
    end
    
    WE.logInfo("hasRadioAccess: Group '%s' DENIED access - no matching user strings", groupName)
    return false
end

--- Get the list of currently enabled event names, in the order they should
--- appear in the radio menu (per WE.EventOrder, with any enabled event not
--- listed there appended at the end so it's never silently missed)
--- @return table list of enabled event name strings
function WE.getEnabledEventNames()
    local _names = {}
    local _seen = {}

    if WE.EventOrder then
        for _, _eventName in ipairs(WE.EventOrder) do
            if WE.EnabledEvents and WE.EnabledEvents[_eventName] then
                table.insert(_names, _eventName)
                _seen[_eventName] = true
            end
        end
    end

    if WE.EnabledEvents then
        for _eventName, _enabled in pairs(WE.EnabledEvents) do
            if _enabled and not _seen[_eventName] then
                table.insert(_names, _eventName)
            end
        end
    end

    return _names
end

--- Turn an event key like "BASE_ATTACK" into a readable radio menu label
--- @param _eventName string the event key
--- @return string display label
function WE.getEventDisplayName(_eventName)
    if not _eventName then
        return ""
    end
    return (_eventName:gsub("_", " "))
end

--- Initialize radio menus for a specific group
--- @param groupId number the group ID to add menus for
--- @param groupName string the group name to check permissions
function WE.initializePlayerRadioMenu(groupId, groupName)
    if not WE.hasRadioAccess(groupName) then
        WE.logInfo("Group %s does not have radio access", groupName)
        return
    end
    
    WE.logInfo("Initializing World Events radio menu for group: %s (Group ID: %d)", groupName, groupId)
    
    if not WE.radioMenu[groupId] then
        WE.radioMenu[groupId] = {}
    end
    
    -- Create main WorldEvents menu for this group
    WE.radioMenu[groupId].mainMenu = missionCommands.addSubMenuForGroup(groupId, "WorldEvents")
    
    -- "Spawn Event" is now a submenu listing every currently enabled event, so
    -- new events only need to be added to WE.EnabledEvents to show up here
    WE.radioMenu[groupId].spawnEventMenu = missionCommands.addSubMenuForGroup(groupId, "Spawn Event", WE.radioMenu[groupId].mainMenu)
    WE.radioMenu[groupId].spawnEventCommands = {}
    for _, _eventName in ipairs(WE.getEnabledEventNames()) do
        WE.radioMenu[groupId].spawnEventCommands[_eventName] = missionCommands.addCommandForGroup(
            groupId, WE.getEventDisplayName(_eventName), WE.radioMenu[groupId].spawnEventMenu,
            WE.spawnEventMenuAction, _eventName)
    end

    WE.radioMenu[groupId].eventStatusMenu = missionCommands.addCommandForGroup(groupId, "Event Status", WE.radioMenu[groupId].mainMenu, WE.showEventStatusAction)
    
    WE.logInfo("World Events radio menu initialized successfully for group: %s", groupName)
end

--- Initialize the radio menu system for World Events (checks all players)
function WE.initializeRadioMenu()
    WE.logInfo("Initializing World Events radio menu system")
    
    -- Check if "ALL" is configured for universal access
    local hasAllAccess = false
    if WE.RadioUsers then
        for _, user in pairs(WE.RadioUsers) do
            if string.upper(user) == "ALL" then
                hasAllAccess = true
                break
            end
        end
    end
    
    if hasAllAccess then
        -- Create global menu for everyone
        WE.radioMenu.mainMenu = missionCommands.addSubMenu("WorldEvents")
        WE.radioMenu.spawnEventMenu = missionCommands.addSubMenu("Spawn Event", WE.radioMenu.mainMenu)
        WE.radioMenu.spawnEventCommands = {}
        for _, _eventName in ipairs(WE.getEnabledEventNames()) do
            WE.radioMenu.spawnEventCommands[_eventName] = missionCommands.addCommand(
                WE.getEventDisplayName(_eventName), WE.radioMenu.spawnEventMenu, WE.spawnEventMenuAction, _eventName)
        end
        WE.radioMenu.eventStatusMenu = missionCommands.addCommand("Event Status", WE.radioMenu.mainMenu, WE.showEventStatusAction)
        WE.logInfo("World Events radio menu initialized globally for all players")
    else
        -- Check each player group and add menus individually
        for coalitionId = 1, 2 do
            local groups = coalition.getGroups(coalitionId, Group.Category.AIRPLANE)
            for _, group in pairs(groups) do
                if group and group:isExist() then
                    local units = group:getUnits()
                    if units and #units > 0 then
                        local unit = units[1]
                        if unit and unit:isExist() then
                            local playerName = unit:getPlayerName()
                            if playerName then
                                WE.initializePlayerRadioMenu(group:getID(), group:getName())
                            end
                        end
                    end
                end
            end
            
            -- Also check helicopter groups
            local heliGroups = coalition.getGroups(coalitionId, Group.Category.HELICOPTER)
            for _, group in pairs(heliGroups) do
                if group and group:isExist() then
                    local units = group:getUnits()
                    if units and #units > 0 then
                        local unit = units[1]
                        if unit and unit:isExist() then
                            local playerName = unit:getPlayerName()
                            if playerName then
                                WE.initializePlayerRadioMenu(group:getID(), group:getName())
                            end
                        end
                    end
                end
            end
        end
    end
    
    WE.logInfo("World Events radio menu initialization complete")
end

--- Action for a "Spawn Event" radio menu item
--- @param _eventName string the event key selected (e.g. "VIP_ESCORT", "BASE_ATTACK")
function WE.spawnEventMenuAction(_eventName)
    WE.logInfo("Spawn Event menu action triggered for '%s'", tostring(_eventName))
    
    -- Check if an event is already active. Stronghold missions manage their own
    -- concurrency, so when multiple strongholds are enabled let them through and
    -- let the stronghold module enforce its own limits.
    if WE.is_active == 1 then
        local _isStronghold = _eventName == "STRONGHOLD"
        if not (_isStronghold and WE.StrongholdAllowMultiple) then
            trigger.action.outText("A World Event is already active! Check Event Status for details.", 10)
            return
        end
    end

    if not _eventName or not WE.EnabledEvents[_eventName] then
        WE.logError("spawnEventMenuAction: '%s' is not a currently enabled event", tostring(_eventName))
        trigger.action.outText("That event is not currently enabled.", 10)
        return
    end

    if not WE.EVENT[_eventName] then
        WE.logError("spawnEventMenuAction: no WE.EVENT.%s function is defined", tostring(_eventName))
        trigger.action.outText("That event isn't implemented yet.", 10)
        return
    end

    WE.EVENT[_eventName]()
    trigger.action.outSound("vip-enroute.wav")
    
    WE.logInfo("World Event '%s' spawned via radio menu", _eventName)
end

--- Action for Event Status menu option
function WE.showEventStatusAction()
    WE.logInfo("Event Status menu action triggered")
    
    local statusMessage = ""
    if WE.is_active == 1 then
        statusMessage = "World Event Status: ACTIVE\n\nAn event is currently running. Check the F10 map for event details."
        if WE.currentVIPEvent then
            statusMessage = statusMessage .. string.format("\n\nVIP Escort: departed %s, en route to %s.",
                tostring(WE.currentVIPEvent.departure), tostring(WE.currentVIPEvent.destination))
        end
        if WE.currentBaseAttackEvent then
            statusMessage = statusMessage .. string.format("\n\nBase Attack: departed %s, attacking %s.",
                tostring(WE.currentBaseAttackEvent.departure), tostring(WE.currentBaseAttackEvent.destination))
        end
        if #WE.activeStrongholdEvents > 0 then
            for _i, _eventData in ipairs(WE.activeStrongholdEvents) do
                local _remaining = math.max(0, math.ceil(_eventData.endsAt - timer.getTime()))
                statusMessage = statusMessage .. string.format("\n\nStronghold %d: located near %s, %d seconds remaining.",
                    _i, tostring(_eventData.area), _remaining)
            end
        end
    else
        statusMessage = "World Event Status: INACTIVE\n\nNo events are currently active. Use 'Spawn Event' to start a new event."
    end
    
    trigger.action.outText(statusMessage, 15)
    WE.logInfo("Event status displayed via radio menu")
end

--- Remove all World Events radio menus (cleanup function)
function WE.removeRadioMenu()
    -- Remove global menus if they exist
    if WE.radioMenu.spawnEventMenu then
        missionCommands.removeItem(WE.radioMenu.spawnEventMenu)
        WE.radioMenu.spawnEventMenu = nil
    end
    
    if WE.radioMenu.eventStatusMenu then
        missionCommands.removeItem(WE.radioMenu.eventStatusMenu)
        WE.radioMenu.eventStatusMenu = nil
    end
    
    if WE.radioMenu.mainMenu then
        missionCommands.removeItem(WE.radioMenu.mainMenu)
        WE.radioMenu.mainMenu = nil
    end
    
    -- Remove per-group menus
    for groupId, menuData in pairs(WE.radioMenu) do
        if type(groupId) == "number" and type(menuData) == "table" then
            if menuData.spawnEventMenu then
                missionCommands.removeItemForGroup(groupId, menuData.spawnEventMenu)
            end
            if menuData.eventStatusMenu then
                missionCommands.removeItemForGroup(groupId, menuData.eventStatusMenu)
            end
            if menuData.mainMenu then
                missionCommands.removeItemForGroup(groupId, menuData.mainMenu)
            end
            WE.radioMenu[groupId] = nil
        end
    end
    
    WE.logInfo("World Events radio menu removed")
end

-----------------[[ END OF radio.lua ]]-----------------
-----------------[[ event.lua ]]-----------------



--- Event handler for when players join/leave to update radio menus
function WE.onPlayerEvent(event)
    if not event then
        WE.logInfo("Event received: event object is nil!")
        return
    end
    
    WE.logInfo("Event received: %s (event type: %s)", tostring(event.id), type(event.id))
    
    if event.id == world.event.S_EVENT_PLAYER_ENTER_UNIT then
        if event.initiator and event.initiator:getPlayerName() then
            local playerName = event.initiator:getPlayerName()
            local group = event.initiator:getGroup()
            if group then
                local groupId = group:getID()
                local groupName = group:getName()
                WE.logInfo("Player '%s' entering unit in group '%s' (ID: %d)", playerName, groupName, groupId)
                
                -- Small delay to ensure unit is fully initialized
                timer.scheduleFunction(function()
                    -- Remove any existing menu for this group first (in case of reslotting)
                    if WE.radioMenu[groupId] then
                        WE.logInfo("Removing existing radio menu for group %d before re-creating", groupId)
                        if WE.radioMenu[groupId].spawnEventMenu then
                            missionCommands.removeItemForGroup(groupId, WE.radioMenu[groupId].spawnEventMenu)
                        end
                        if WE.radioMenu[groupId].eventStatusMenu then
                            missionCommands.removeItemForGroup(groupId, WE.radioMenu[groupId].eventStatusMenu)
                        end
                        if WE.radioMenu[groupId].mainMenu then
                            missionCommands.removeItemForGroup(groupId, WE.radioMenu[groupId].mainMenu)
                        end
                        WE.radioMenu[groupId] = nil
                    end
                    
                    -- Now initialize menu with proper access control
                    WE.initializePlayerRadioMenu(groupId, groupName)
                end, nil, timer.getTime() + 1)
            end
        end
    elseif event.id == world.event.S_EVENT_BIRTH then
        -- Handle unit birth (spawning) events
        if event.initiator and event.initiator:getPlayerName() then
            local playerName = event.initiator:getPlayerName()
            local group = event.initiator:getGroup()
            if group then
                local groupId = group:getID()
                local groupName = group:getName()
                WE.logInfo("Player '%s' spawned in group '%s' (ID: %d) via BIRTH event", playerName, groupName, groupId)
                
                -- Small delay to ensure unit is fully initialized
                timer.scheduleFunction(function()
                    -- Remove any existing menu for this group first
                    if WE.radioMenu[groupId] then
                        WE.logInfo("Removing existing radio menu for group %d before re-creating (BIRTH)", groupId)
                        if WE.radioMenu[groupId].spawnEventMenu then
                            missionCommands.removeItemForGroup(groupId, WE.radioMenu[groupId].spawnEventMenu)
                        end
                        if WE.radioMenu[groupId].eventStatusMenu then
                            missionCommands.removeItemForGroup(groupId, WE.radioMenu[groupId].eventStatusMenu)
                        end
                        if WE.radioMenu[groupId].mainMenu then
                            missionCommands.removeItemForGroup(groupId, WE.radioMenu[groupId].mainMenu)
                        end
                        WE.radioMenu[groupId] = nil
                    end
                    
                    -- Initialize menu with proper access control
                    WE.initializePlayerRadioMenu(groupId, groupName)
                end, nil, timer.getTime() + 2)
            end
        end
    elseif event.id == world.event.S_EVENT_PLAYER_LEAVE_UNIT then
        if event.initiator and event.initiator.getGroup and type(event.initiator.getGroup) == "function" then
            local group = event.initiator:getGroup()
            if group then
                local groupId = group:getID()
                local groupName = group:getName() or "Unknown"
                WE.logInfo("Player leaving unit in group '%s' (ID: %d)", groupName, groupId)
                
                -- Remove radio menu for this group
                if WE.radioMenu[groupId] then
                    WE.logInfo("Removing radio menu for group %d due to player leaving", groupId)
                    if WE.radioMenu[groupId].spawnEventMenu then
                        missionCommands.removeItemForGroup(groupId, WE.radioMenu[groupId].spawnEventMenu)
                    end
                    if WE.radioMenu[groupId].eventStatusMenu then
                        missionCommands.removeItemForGroup(groupId, WE.radioMenu[groupId].eventStatusMenu)
                    end
                    if WE.radioMenu[groupId].mainMenu then
                        missionCommands.removeItemForGroup(groupId, WE.radioMenu[groupId].mainMenu)
                    end
                    WE.radioMenu[groupId] = nil
                end
            end
        end
    end
end

--- Initialize the event handling system
function WE.initializeEvents()
    WE.logInfo("Initializing World Events event handling system")
    
    -- Create event handler object for player events using proper DCS format
    WE.playerEventHandler = {}
    function WE.playerEventHandler:onEvent(event)
        WE.onPlayerEvent(event)
    end
    
    -- Register event handlers
    world.addEventHandler(WE.playerEventHandler)
    WE.logInfo("Player event handler registered for radio menu management")
    
    -- Store reference for cleanup
    WE.eventHandlers.playerEventHandler = WE.playerEventHandler
    
    WE.logInfo("World Events event handling system initialization complete")
end

--- Cleanup event handlers
function WE.cleanupEvents()
    WE.logInfo("Cleaning up World Events event handlers")
    
    if WE.eventHandlers.playerEventHandler then
        world.removeEventHandler(WE.eventHandlers.playerEventHandler)
        WE.eventHandlers.playerEventHandler = nil
        WE.logInfo("Player event handler removed")
    end
    
    WE.logInfo("World Events event handling system cleanup complete")
end

function WE.addEvent(event)
    -- Placeholder for adding a new world event
    WE.logInfo("Adding a new world event. Event details: %s", tostring(event))
    
    -- Add the event to the WE.events table
    table.insert(WE.events, event)
end

function WE.removeEvent(eventId)
    -- Placeholder for removing a world event by ID
    WE.logInfo("Removing world event with ID: %s", tostring(eventId))
    
    for index, event in ipairs(WE.events) do
        if event.id == eventId then
            table.remove(WE.events, index)
            WE.logInfo("World event with ID %s removed", tostring(eventId))
            return
        end
    end
    
    WE.logInfo("World event with ID %s not found", tostring(eventId))
end

-----------------[[ END OF event.lua ]]-----------------
-----------------[[ event_vipwing.lua ]]-----------------
---
--- VIP Wing event spawning module
--- Spawns a VIP transport with fighter escort when triggered by radio menu
--- Unit data is taken directly from the exported Vip_Wing static template
--- ("Vip_Transport" C-130J-30 + "Vip_Wing_fighter" 4x MiG-29 Fulcrum), but
--- spawn/destination airfields are picked dynamically so this works on any map.
---

--- Country used to spawn the VIP Wing units. Change this if your red side
--- isn't Russia on the map/mod you're using.
WE.VIPCountry = country.id.RUSSIA

--- Distance (meters) the fighters will break off to engage an air threat
--- to the escorted transport before returning to escort duty.
WE.VIPEscortEngagementDistMax = 60000

--- Track the currently active VIP Wing event (departure/destination names, group ids)
WE.currentVIPEvent = nil

--- Get all currently red-owned airdrome-category airbases (excludes ships/FARPs/helipads)
--- @return table list of Airbase objects
function WE.getRedAirdromes()
    return WE.getAirdromes('red')
end

--- Pick two different random red airdromes to use as departure and destination
--- @return Airbase|nil departure airbase
--- @return Airbase|nil destination airbase
function WE.pickVIPAirfields()
    local _airdromes = WE.getRedAirdromes()

    if #_airdromes < 2 then
        WE.logWarning("pickVIPAirfields: found only %d red airdrome(s) on this map, need at least 2", #_airdromes)
        return nil, nil
    end

    local _depIndex = math.random(1, #_airdromes)
    local _departure = _airdromes[_depIndex]

    local _destIndex = _depIndex
    while _destIndex == _depIndex do
        _destIndex = math.random(1, #_airdromes)
    end
    local _destination = _airdromes[_destIndex]

    return _departure, _destination
end

--- Spawn VIP Wing with fighter escort
--- This function spawns two groups: a VIP transport aircraft flying from a random
--- red airfield to another random red airfield, and a fighter escort that stays
--- close to the transport but will break off to engage any blue air threat.
function WE.EVENT.VIP_ESCORT()
    WE.logInfo("VIP Wing spawn event triggered")

    -- Check if already active
    if WE.is_active == 1 then
        trigger.action.outText("VIP Wing event is already active!", 10)
        WE.logInfo("VIP Wing spawn cancelled - event already active")
        return
    end

    -- Pick a departure and destination airfield dynamically so this works on any map
    local _departureAirfield, _destinationAirfield = WE.pickVIPAirfields()

    if _departureAirfield == nil or _destinationAirfield == nil then
        WE.logError("VIP_ESCORT: not enough red airdromes on this map - event cancelled")
        trigger.action.outText("VIP Wing event could not start: not enough red-controlled airfields on this map!", 10)
        return
    end

    local _depPoint = _departureAirfield:getPoint()
    local _destPoint = _destinationAirfield:getPoint()
    local _depName = _departureAirfield:getName()
    local _destName = _destinationAirfield:getName()
    local _depId = _departureAirfield:getID()
    local _destId = _destinationAirfield:getID()

    -- Spawn/takeoff coordinates must come from the actual runway, not the airbase
    -- reference point: on some maps (e.g. Syria) the reference point sits off the
    -- runway and "From Runway" aircraft spawn misaligned and never take off.
    local _depRunway = WE.getTakeoffPoint(_departureAirfield)

    if _depRunway == nil then
        WE.logError("VIP_ESCORT: could not determine a takeoff point at %s - event cancelled", _depName)
        trigger.action.outText("VIP Wing event could not start: no usable runway at departure airfield!", 10)
        return
    end

    WE.logInfo("VIP_ESCORT: takeoff spawn at %s x=%.0f z=%.0f alt=%.0f heading=%.2f rad", _depName, _depRunway.x,
        _depRunway.z, _depRunway.y, _depRunway.heading)

    WE.logInfo("VIP_ESCORT: departure=%s (id %s), destination=%s (id %s)", _depName, tostring(_depId), _destName,
        tostring(_destId))

    WE.logInfo("Spawning VIP Wing groups...")

    -- Reserve the transport's group id up front so the fighter escort task can reference it
    local _transportGroupId = WE.getNextGroupId()

    -- VIP Transport Group (unit data from static template group "Vip_Transport"),
    -- route now flies from the departure airfield to the destination airfield
    local vipTransportGroup = {
        ["modulation"] = 0,
        ["tasks"] = {},
        ["task"] = "Transport",
        ["uncontrolled"] = false,
        ["taskSelected"] = true,
        ["hidden"] = false,
        ["route"] = {
            ["points"] = {
                [1] = {
                    ["alt"] = _depRunway.y,
                    ["action"] = "From Runway",
                    ["alt_type"] = "BARO",
                    ["speed"] = 154.16666666667,
                    ["airdromeId"] = _depId,
                    ["task"] = {
                        ["id"] = "ComboTask",
                        ["params"] = {
                            ["tasks"] = {
                                [1] = {
                                    ["number"] = 1,
                                    ["auto"] = true,
                                    ["id"] = "WrappedAction",
                                    ["enabled"] = true,
                                    ["params"] = {
                                        ["action"] = {
                                            ["id"] = "Option",
                                            ["params"] = {
                                                ["value"] = true,
                                                ["name"] = 35,
                                            },
                                        },
                                    },
                                },
                            },
                        },
                    },
                    ["type"] = "TakeOff",
                    ["ETA"] = 0,
                    ["ETA_locked"] = true,
                    ["y"] = _depRunway.z,
                    ["x"] = _depRunway.x,
                    ["speed_locked"] = true,
                    ["formation_template"] = "",
                },
                [2] = {
                    ["alt"] = _destPoint.y,
                    ["action"] = "Landing",
                    ["alt_type"] = "BARO",
                    ["speed"] = 154.16666666667,
                    ["airdromeId"] = _destId,
                    ["task"] = {
                        ["id"] = "ComboTask",
                        ["params"] = {
                            ["tasks"] = {},
                        },
                    },
                    ["type"] = "Land",
                    ["ETA_locked"] = false,
                    ["y"] = _destPoint.z,
                    ["x"] = _destPoint.x,
                    ["speed_locked"] = true,
                    ["formation_template"] = "",
                },
            },
        },
        ["units"] = {
            [1] = {
                ["alt"] = _depRunway.y,
                ["alt_type"] = "BARO",
                ["livery_id"] = "iqaf 23rd sqn, new al muthana air base",
                ["skill"] = "Excellent",
                ["speed"] = 154.16666666667,
                ["AddPropAircraft"] = {
                    ["allow_air_load"] = false,
                    ["pre_flight_complete"] = false,
                    ["save_custom_data"] = true,
                    ["ramp_down"] = false,
                    ["allow_moab"] = true,
                },
                ["type"] = "C-130J-30",
                ["unitId"] = WE.getNextUnitId(),
                ["psi"] = _depRunway.heading,
                ["onboard_num"] = "014",
                ["y"] = _depRunway.z,
                ["x"] = _depRunway.x,
                ["name"] = "RSD381 VIP",
                ["payload"] = {
                    ["pylons"] = {},
                    ["fuel"] = 15753.6,
                    ["flare"] = 200,
                    ["chaff"] = 220,
                    ["gun"] = 100,
                },
                ["heading"] = _depRunway.heading,
                ["callsign"] = 126,
            },
        },
        ["y"] = _depRunway.z,
        ["x"] = _depRunway.x,
        ["name"] = "Vip_Transport",
        ["communication"] = true,
        ["start_time"] = 0,
        ["groupId"] = _transportGroupId,
        ["frequency"] = 305,
    }

    local transportGroupObj = coalition.addGroup(WE.VIPCountry, Group.Category.AIRPLANE, vipTransportGroup)
    if not transportGroupObj then
        WE.logError("Failed to spawn VIP Transport group")
        trigger.action.outText("Failed to spawn VIP Transport aircraft", 10)
        return
    end

    -- Workaround to get the actual id if reassigned by DCS
    local _actualTransportGroupId = transportGroupObj:getID()
    WE.logInfo("VIP Transport group spawned successfully with actual group ID: %s", tostring(_actualTransportGroupId))

    -- 10 NM rendezvous calculation (10 NM = 18,520 meters)
    local _rendezvousDistMeters = 10 * 1852
    local _dx = _destPoint.x - _depPoint.x
    local _dz = _destPoint.z - _depPoint.z
    local _totalDist = math.sqrt(_dx * _dx + _dz * _dz)

    local _actualDist = math.min(_rendezvousDistMeters, _totalDist)
    local _midX = _depPoint.x + (_dx / _totalDist) * _actualDist
    local _midY = _depPoint.z + (_dz / _totalDist) * _actualDist
    local _cruiseAlt = 6000 -- Operational altitude in meters (~20,000 ft)
    local _maxTerrainHeight = WE.getMaxTerrainHeight(_depPoint.x, _depPoint.z, _midX, _midY, 5)
    local _safeCruiseAlt = math.max(_cruiseAlt, _maxTerrainHeight + 500)

    -- VIP Fighter Escort Group (unit data from static template group "Vip_Wing_fighter").
    -- Takes off from the same airfield and is tasked to escort the transport: stay
    -- close to it, but break off to engage any air threat within engagement range.
    local vipFighterGroup = {
        ["modulation"] = 0,
        ["tasks"] = {},
        ["task"] = "Escort",
        ["uncontrolled"] = false,
        ["taskSelected"] = true,
        ["hidden"] = false,
        ["route"] = {
            ["routeRelativeTOT"] = true,
            ["points"] = {
                -- WAYPOINT 1: Takeoff / Departure Airfield
                [1] = {
                    ["alt"] = _depRunway.y,
                    ["action"] = "From Runway",
                    ["alt_type"] = "BARO",
                    ["speed"] = 220.97222222222,
                    ["airdromeId"] = _depId,
                    ["task"] = {
                        ["id"] = "ComboTask",
                        ["params"] = {
                            ["tasks"] = {
                                [1] = {
                                    ["number"] = 1,
                                    ["auto"] = true,
                                    ["id"] = "Escort",
                                    ["enabled"] = true,
                                    ["params"] = {
                                        ["groupId"] = _actualTransportGroupId,
                                        ["lastWptIndexFlagChangedManually"] = false,
                                        ["lastWptIndex"] = 3,
                                        ["engagementDistMax"] = WE.VIPEscortEngagementDistMax,
                                        ["targetTypes"] = { [1] = "Air" },
                                        ["pos"] = { ["x"] = -200, ["y"] = 50, ["z"] = 300 },
                                    },
                                },
                                [2] = {
                                    ["number"] = 2,
                                    ["key"] = "CAP",
                                    ["id"] = "EngageTargets",
                                    ["enabled"] = true,
                                    ["auto"] = true,
                                    ["params"] = {
                                        ["targetTypes"] = { [1] = "Air" },
                                        ["priority"] = 0,
                                    },
                                },
                                -- Fixed Option 1: ROE (Option.Air.val.ROE = 0) -> Open Fire (2)
                                [3] = {
                                    ["number"] = 3,
                                    ["auto"] = true,
                                    ["id"] = "WrappedAction",
                                    ["enabled"] = true,
                                    ["params"] = {
                                        ["action"] = {
                                            ["id"] = "Option",
                                            ["params"] = {
                                                ["name"] = 0, -- ROE
                                                ["value"] = 2, -- Open Fire
                                            },
                                        },
                                    },
                                },
                                -- Fixed Option 2: Reaction To Threat (Option.Air.val.REACTION_ON_THREAT = 1) -> Evade Fire (4)
                                [4] = {
                                    ["number"] = 4,
                                    ["auto"] = true,
                                    ["id"] = "WrappedAction",
                                    ["enabled"] = true,
                                    ["params"] = {
                                        ["action"] = {
                                            ["id"] = "Option",
                                            ["params"] = {
                                                ["name"] = 1, -- Reaction To Threat
                                                ["value"] = 4, -- Evade Fire
                                            },
                                        },
                                    },
                                },
                                -- Fixed Option 3: Radar Using (Option.Air.val.RADAR_USING = 16) -> Continuous (1)
                                [5] = {
                                    ["number"] = 5,
                                    ["auto"] = true,
                                    ["id"] = "WrappedAction",
                                    ["enabled"] = true,
                                    ["params"] = {
                                        ["action"] = {
                                            ["id"] = "Option",
                                            ["params"] = {
                                                ["name"] = 16, -- Radar Using
                                                ["value"] = 1,  -- Continuous Readout
                                            },
                                        },
                                    },
                                },
                                -- Fixed Option 4: Prohibit Jettison (Option.Air.val.PROHIBIT_JETT = 22) -> true
                                [6] = {
                                    ["number"] = 6,
                                    ["auto"] = true,
                                    ["id"] = "WrappedAction",
                                    ["enabled"] = true,
                                    ["params"] = {
                                        ["action"] = {
                                            ["id"] = "Option",
                                            ["params"] = {
                                                ["name"] = 22, -- Prohibit Jettison
                                                ["value"] = true,
                                            },
                                        },
                                    },
                                },
                            },
                        },
                    },
                    ["type"] = "TakeOff",
                    ["ETA"] = 0,
                    ["ETA_locked"] = true,
                    ["y"] = _depRunway.z,
                    ["x"] = _depRunway.x,
                    ["speed_locked"] = true,
                    ["formation_template"] = "",
                },
                -- WAYPOINT 2: 10 NM Rendezvous / Join Point
                [2] = {
                    ["alt"] = _safeCruiseAlt,
                    ["action"] = "Turning Point",
                    ["alt_type"] = "BARO",
                    ["speed"] = 220.97222222222,
                    ["task"] = {
                        ["id"] = "ComboTask",
                        ["params"] = {
                            ["tasks"] = {},
                        },
                    },
                    ["type"] = "Turning Point",
                    ["ETA_locked"] = false,
                    ["y"] = _midY,
                    ["x"] = _midX,
                    ["speed_locked"] = true,
                    ["formation_template"] = "",
                },
                -- WAYPOINT 3: Landing Destination Airfield
                [3] = {
                    ["alt"] = _destPoint.y,
                    ["action"] = "Landing",
                    ["alt_type"] = "BARO",
                    ["speed"] = 220.97222222222,
                    ["airdromeId"] = _destId,
                    ["task"] = {
                        ["id"] = "ComboTask",
                        ["params"] = {
                            ["tasks"] = {},
                        },
                    },
                    ["type"] = "Land",
                    ["ETA_locked"] = false,
                    ["y"] = _destPoint.z,
                    ["x"] = _destPoint.x,
                    ["speed_locked"] = true,
                    ["formation_template"] = "",
                },
            },
        },
        ["units"] = {
            [1] = {
                ["alt"] = _depRunway.y,
                ["alt_type"] = "BARO",
                ["livery_id"] = "rf standard grey",
                ["skill"] = "Excellent",
                ["speed"] = 220.97222222222,
                ["AddPropAircraft"] = {
                    ["NS430allow"] = true,
                },
                ["type"] = "MiG-29 Fulcrum",
                ["unitId"] = WE.getNextUnitId(),
                ["psi"] = _depRunway.heading,
                ["onboard_num"] = "010",
                ["y"] = _depRunway.z,
                ["x"] = _depRunway.x,
                ["name"] = "Aerial-2-1",
                ["payload"] = {
                    ["pylons"] = {
                        [1] = { ["CLSID"] = "{682A481F-0CB5-4693-A382-D00DD4A156D7}" },
                        [2] = { ["CLSID"] = "{682A481F-0CB5-4693-A382-D00DD4A156D7}" },
                        [3] = { ["CLSID"] = "{9B25D316-0434-4954-868F-D51DB1A38DF0}" },
                        [5] = { ["CLSID"] = "{9B25D316-0434-4954-868F-D51DB1A38DF0}" },
                        [6] = { ["CLSID"] = "{682A481F-0CB5-4693-A382-D00DD4A156D7}" },
                        [7] = { ["CLSID"] = "{682A481F-0CB5-4693-A382-D00DD4A156D7}" },
                    },
                    ["fuel"] = 3376,
                    ["flare"] = 30,
                    ["ammo_type"] = 5,
                    ["chaff"] = 30,
                    ["gun"] = 100,
                },
                ["heading"] = _depRunway.heading,
                ["callsign"] = 121,
            },
            [2] = {
                ["alt"] = _depRunway.y,
                ["alt_type"] = "BARO",
                ["livery_id"] = "rf standard grey",
                ["skill"] = "High",
                ["speed"] = 220.97222222222,
                ["AddPropAircraft"] = {
                    ["NS430allow"] = true,
                },
                ["type"] = "MiG-29 Fulcrum",
                ["unitId"] = WE.getNextUnitId(),
                ["psi"] = _depRunway.heading,
                ["onboard_num"] = "011",
                ["y"] = _depRunway.z,
                ["x"] = _depRunway.x,
                ["name"] = "Vip_Wing-1",
                ["payload"] = {
                    ["pylons"] = {
                        [1] = { ["CLSID"] = "{682A481F-0CB5-4693-A382-D00DD4A156D7}" },
                        [2] = { ["CLSID"] = "{682A481F-0CB5-4693-A382-D00DD4A156D7}" },
                        [3] = { ["CLSID"] = "{E8069896-8435-4B90-95C0-01A03AE6E400}" },
                        [5] = { ["CLSID"] = "{E8069896-8435-4B90-95C0-01A03AE6E400}" },
                        [6] = { ["CLSID"] = "{682A481F-0CB5-4693-A382-D00DD4A156D7}" },
                        [7] = { ["CLSID"] = "{682A481F-0CB5-4693-A382-D00DD4A156D7}" },
                    },
                    ["fuel"] = 3376,
                    ["flare"] = 30,
                    ["ammo_type"] = 5,
                    ["chaff"] = 30,
                    ["gun"] = 100,
                },
                ["heading"] = _depRunway.heading,
                ["callsign"] = 122,
            },
            [3] = {
                ["alt"] = _depRunway.y,
                ["alt_type"] = "BARO",
                ["livery_id"] = "rf standard grey",
                ["skill"] = "High",
                ["speed"] = 220.97222222222,
                ["AddPropAircraft"] = {
                    ["NS430allow"] = true,
                },
                ["type"] = "MiG-29 Fulcrum",
                ["unitId"] = WE.getNextUnitId(),
                ["psi"] = _depRunway.heading,
                ["onboard_num"] = "012",
                ["y"] = _depRunway.z,
                ["x"] = _depRunway.x,
                ["name"] = "Vip_Wing-2",
                ["payload"] = {
                    ["pylons"] = {
                        [1] = { ["CLSID"] = "{682A481F-0CB5-4693-A382-D00DD4A156D7}" },
                        [2] = { ["CLSID"] = "{682A481F-0CB5-4693-A382-D00DD4A156D7}" },
                        [3] = { ["CLSID"] = "{E8069896-8435-4B90-95C0-01A03AE6E400}" },
                        [5] = { ["CLSID"] = "{E8069896-8435-4B90-95C0-01A03AE6E400}" },
                        [6] = { ["CLSID"] = "{682A481F-0CB5-4693-A382-D00DD4A156D7}" },
                        [7] = { ["CLSID"] = "{682A481F-0CB5-4693-A382-D00DD4A156D7}" },
                    },
                    ["fuel"] = 3376,
                    ["flare"] = 30,
                    ["ammo_type"] = 5,
                    ["chaff"] = 30,
                    ["gun"] = 100,
                },
                ["heading"] = _depRunway.heading,
                ["callsign"] = 123,
            },
            [4] = {
                ["alt"] = _depRunway.y,
                ["alt_type"] = "BARO",
                ["livery_id"] = "rf standard grey",
                ["skill"] = "High",
                ["speed"] = 220.97222222222,
                ["AddPropAircraft"] = {
                    ["NS430allow"] = true,
                },
                ["type"] = "MiG-29 Fulcrum",
                ["unitId"] = WE.getNextUnitId(),
                ["psi"] = _depRunway.heading,
                ["onboard_num"] = "013",
                ["y"] = _depRunway.z,
                ["x"] = _depRunway.x,
                ["name"] = "Vip_Wing-3",
                ["payload"] = {
                    ["pylons"] = {
                        [1] = { ["CLSID"] = "{682A481F-0CB5-4693-A382-D00DD4A156D7}" },
                        [2] = { ["CLSID"] = "{682A481F-0CB5-4693-A382-D00DD4A156D7}" },
                        [3] = { ["CLSID"] = "{E8069896-8435-4B90-95C0-01A03AE6E400}" },
                        [5] = { ["CLSID"] = "{E8069896-8435-4B90-95C0-01A03AE6E400}" },
                        [6] = { ["CLSID"] = "{682A481F-0CB5-4693-A382-D00DD4A156D7}" },
                        [7] = { ["CLSID"] = "{682A481F-0CB5-4693-A382-D00DD4A156D7}" },
                    },
                    ["fuel"] = 3376,
                    ["flare"] = 30,
                    ["ammo_type"] = 5,
                    ["chaff"] = 30,
                    ["gun"] = 100,
                },
                ["heading"] = _depRunway.heading,
                ["callsign"] = 124,
            },
        },
        ["y"] = _depRunway.z,
        ["x"] = _depRunway.x,
        ["name"] = "Vip_Wing_fighter",
        ["communication"] = true,
        ["start_time"] = 0,
        ["groupId"] = WE.getNextGroupId(),
        ["frequency"] = 124,
    }

    -- Spawn the fighter escort group
    local fighterGroupId = coalition.addGroup(WE.VIPCountry, Group.Category.AIRPLANE, vipFighterGroup)
    if fighterGroupId then
        WE.logInfo("VIP Fighter Escort group spawned successfully with group ID: %s", tostring(fighterGroupId))
    else
        WE.logError("Failed to spawn VIP Fighter Escort group")
        trigger.action.outText("Failed to spawn VIP Fighter Escort", 10)
    end

    -- Mark event as active and remember the mission details for Event Status
    WE.is_active = 1
    WE.currentVIPEvent = {
        departure = _depName,
        destination = _destName,
        transportGroupId = _actualTransportGroupId,
        fighterGroupId = fighterGroupId,
    }

    WE.logInfo("VIP Wing event completed successfully - Transport ID: %s, Escort ID: %s",
        tostring(_actualTransportGroupId), tostring(fighterGroupId))

    -- Communicate the airfields to all players so they know where to look
    trigger.action.outText(
        string.format(
            "VIP Wing mission is active! A VIP transport with 4 fighter escorts is departing %s, bound for %s. intercept it!",
            _depName, _destName),
        20)

    trigger.action.outSound("attn_vip.ogg")
end

-- Create a table to hold our custom event handler
WE.EVENT.VIPWING = {}

-- Define the function that DCS calls every time ANY event happens in the world
function WE.EVENT.VIPWING:onEvent(event)
    -- Check if the event has a valid initiator (the unit causing the event)
    if not event.initiator then return end
    
    -- Optimize by getting the unit's name up front
    if event.initiator.getName and type(event.initiator.getName) == "function" then
        local unitName = event.initiator:getName()
        WE.logInfo("Event received: %s, Unit: %s", tostring(event.id), tostring(unitName))
        
        if unitName == "RSD381 VIP" then
        
            -- Scenario 1: Plane is destroyed
            if event.id == world.event.S_EVENT_CRASH then
                trigger.action.outText("SUCCESS: The target aircraft has been completely destroyed!", 10)
                -- Add your custom logic for success here ( Award points, trigger next event, etc. )
                WE.is_active = 0
                WE.currentVIPEvent = nil
                
            -- Scenario 2: Plane lands safely
            elseif event.id == world.event.S_EVENT_LAND then
                trigger.action.outText("INFO: The target aircraft has touched down safely get to him before he finishes taxiing!", 5)

            -- Scenario 3: Plane shuts down engines after landing
            elseif event.id == world.event.S_EVENT_ENGINE_SHUTDOWN then
                trigger.action.outText("FAILED: The aircraft has landed and shut down engines. Mission Failure!", 10)
                -- Add your custom logic for failure here
                WE.is_active = 0
                WE.currentVIPEvent = nil
            end
            
        end
    else
        WE.logWarning("Event received: %s, but initiator has no valid getName method", tostring(event.id))
    end
end

-- Register the handler with the DCS world engine so it starts listening
world.addEventHandler(WE.EVENT.VIPWING)

-----------------[[ END OF event_vipwing.lua ]]-----------------
-----------------[[ event_baseattack.lua ]]-----------------
---
--- Base Attack event spawning module
--- Spawns a base attack mission when triggered by radio menu
--- Unit data is taken directly from the exported Base_Attack static template
--- ("Base_Attack" group), but spawn/destination airfields are picked dynamically so this works on any map.
---

--- Country used to spawn the Base Attack units. Change this if your red side
--- isn't Russia on the map/mod you're using.
WE.AttackerCountry = country.id.RUSSIA

--- Distance (meters) the fighters will break off to engage an air threat
--- to the escorted transport before returning to escort duty.
WE.EscortEngagementDistMax = 60000

--- Track the currently active Base Attack event (departure/destination names, group ids)
WE.currentBaseAttackEvent = nil

--- Pick a random departure airfield and a random destination (target) airfield to attack
--- @return Airbase|nil departure airbase
--- @return Airbase|nil destination airbase
function WE.pickAirfields()
    local _redAirdromes = WE.getAirdromes('red')

    if #_redAirdromes < 1 then
        WE.logWarning("pickAirfields: found only %d red airdrome(s) on this map, need at least 1", #_redAirdromes)
        return nil, nil
    end

    local _blueAirdromes = WE.getAirdromes('blue')

    if #_blueAirdromes < 1 then
        WE.logWarning("pickAirfields: found only %d blue airdrome(s) on this map, need at least 1", #_blueAirdromes)
        return nil, nil
    end

    local _depIndex = math.random(1, #_redAirdromes)
    local _departure = _redAirdromes[_depIndex]

    local _destIndex = math.random(1, #_blueAirdromes)
    local _destination = _blueAirdromes[_destIndex]

    return _departure, _destination
end

--- Spawn Base Attack with fighter escort
--- This function spawns two groups: a VIP transport aircraft flying from a random
--- red airfield to another random red airfield, and a fighter escort that stays
--- close to the transport but will break off to engage any blue air threat.
function WE.EVENT.BASE_ATTACK()
    WE.logInfo("Base Attack event triggered")

    -- Check if already active
    if WE.is_active == 1 then
        trigger.action.outText("Base Attack event is already active!", 10)
        WE.logInfo("Base Attack spawn cancelled - event already active")
        return
    end

    -- Pick a departure and destination airfield dynamically so this works on any map
    local _departureAirfield, _destinationAirfield = WE.pickAirfields()

    if _departureAirfield == nil or _destinationAirfield == nil then
        WE.logError("BASE_ATTACK: not enough airdromes on this map - event cancelled")
        trigger.action.outText("Base Attack event could not start: not enough airdromes of type on this map!", 10)
        return
    end

    local _depPoint = _departureAirfield:getPoint()
    local _destPoint = _destinationAirfield:getPoint()
    local _depName = _departureAirfield:getName()
    local _destName = _destinationAirfield:getName()
    local _depId = _departureAirfield:getID()
    local _destId = _destinationAirfield:getID()

    -- Spawn/takeoff coordinates must come from the actual runway, not the airbase
    -- reference point: on some maps (e.g. Syria) the reference point sits off the
    -- runway and "From Runway" aircraft spawn misaligned and never take off.
    local _depRunway = WE.getTakeoffPoint(_departureAirfield)

    if _depRunway == nil then
        WE.logError("BASE_ATTACK: could not determine a takeoff point at %s - event cancelled", _depName)
        trigger.action.outText("Base Attack event could not start: no usable runway at departure airfield!", 10)
        return
    end

    WE.logInfo("BASE_ATTACK: takeoff spawn at %s x=%.0f z=%.0f alt=%.0f heading=%.2f rad", _depName, _depRunway.x,
        _depRunway.z, _depRunway.y, _depRunway.heading)

    WE.logInfo("BASE_ATTACK: departure=%s (id %s), destination=%s (id %s)", _depName, tostring(_depId), _destName,
        tostring(_destId))

    WE.logInfo("Spawning Base Attack Wing groups...")

    -- Reserve the CAS group's id up front (used as a hint - see the real id capture below)
    local _attackCASGroupId = WE.getNextGroupId()

    -- Transit altitude in meters: keeps the flight above the highest terrain on
    -- the departure -> destination leg so they clear the mountains.
    local _cruiseAlt = 2000
    local _maxTerrainHeight = WE.getMaxTerrainHeight(_depPoint.x, _depPoint.z, _destPoint.x, _destPoint.z, 5)
    local _safeCruiseAlt = math.max(_cruiseAlt, _maxTerrainHeight + 500)

    -- Attack altitude in meters for the low-level attack run at the destination.
    -- Kept low (only ~500 m above local ground) so the AI can visually acquire
    -- ground units; the high _safeCruiseAlt waypoint above it handles mountain
    -- clearance during transit and the AI descends over the (flat) airfield.
    local _destTerrainHeight = land.getHeight({ x = _destPoint.x, y = _destPoint.z })
    local _attackAlt = math.max(1200, _destTerrainHeight + 500)

    -- Base Attack CAS Group ("ShAP" - 3x Su-25, livery/loadout from the exported
    -- shap.stm static template). Route: take off from the departure (red) airfield,
    -- attack enemy ground units at the destination (blue) airfield, then land back
    -- at the SAME airfield they took off from.

    local attackCASGroup = {
        ["modulation"] = 0,
        ["tasks"] = {},
        ["task"] = "CAS",
        ["uncontrolled"] = false,
        ["taskSelected"] = true,
        ["hidden"] = false,
        ["route"] = {
            ["points"] = {
                -- WAYPOINT 1: Takeoff / Departure (red) Airfield
                [1] = {
                    ["alt"] = _depRunway.y,
                    ["action"] = "From Runway",
                    ["alt_type"] = "BARO",
                    ["speed"] = 138.88888888889,
                    ["airdromeId"] = _depId,
                    ["task"] = {
                        ["id"] = "ComboTask",
                        ["params"] = {
                            ["tasks"] = {
                                -- Engage anything threatening en route (from the exported template)
                                [1] = {
                                    ["number"] = 1,
                                    ["key"] = "CAS",
                                    ["id"] = "EngageTargets",
                                    ["enabled"] = true,
                                    ["auto"] = true,
                                    ["params"] = {
                                        ["targetTypes"] = {
                                            [1] = "Helicopters",
                                            [2] = "Ground Units",
                                            [3] = "Light armed ships",
                                        },
                                        ["priority"] = 0,
                                    },
                                },
                                -- ROE -> Open Fire
                                [2] = {
                                    ["number"] = 2,
                                    ["auto"] = true,
                                    ["id"] = "WrappedAction",
                                    ["enabled"] = true,
                                    ["params"] = {
                                        ["action"] = {
                                            ["id"] = "Option",
                                            ["params"] = { ["value"] = 2, ["name"] = 1 },
                                        },
                                    },
                                },
                                -- Reaction To Threat -> Evade Fire
                                [3] = {
                                    ["number"] = 3,
                                    ["auto"] = true,
                                    ["id"] = "WrappedAction",
                                    ["enabled"] = true,
                                    ["params"] = {
                                        ["action"] = {
                                            ["id"] = "Option",
                                            ["params"] = { ["value"] = 1, ["name"] = 3 },
                                        },
                                    },
                                },
                                [4] = {
                                    ["number"] = 4,
                                    ["auto"] = true,
                                    ["id"] = "WrappedAction",
                                    ["enabled"] = true,
                                    ["params"] = {
                                        ["action"] = {
                                            ["id"] = "Option",
                                            ["params"] = { ["value"] = 131074, ["name"] = 5 },
                                        },
                                    },
                                },
                                [5] = {
                                    ["number"] = 5,
                                    ["auto"] = true,
                                    ["id"] = "WrappedAction",
                                    ["enabled"] = true,
                                    ["params"] = {
                                        ["action"] = {
                                            ["id"] = "Option",
                                            ["params"] = { ["value"] = true, ["name"] = 15 },
                                        },
                                    },
                                },
                                [6] = {
                                    ["number"] = 6,
                                    ["auto"] = true,
                                    ["id"] = "WrappedAction",
                                    ["enabled"] = true,
                                    ["params"] = {
                                        ["action"] = {
                                            ["id"] = "Option",
                                            ["params"] = {
                                                ["targetTypes"] = {},
                                                ["name"] = 21,
                                                ["value"] = "none;",
                                                ["noTargetTypes"] = {
                                                    [1] = "Fighters", [2] = "Multirole fighters", [3] = "Bombers",
                                                    [4] = "Helicopters", [5] = "UAVs", [6] = "Infantry",
                                                    [7] = "Fortifications", [8] = "Tanks", [9] = "IFV", [10] = "APC",
                                                    [11] = "Artillery", [12] = "Unarmed vehicles", [13] = "AAA",
                                                    [14] = "SR SAM", [15] = "MR SAM", [16] = "LR SAM",
                                                    [17] = "Aircraft Carriers", [18] = "Cruisers", [19] = "Destroyers",
                                                    [20] = "Frigates", [21] = "Corvettes", [22] = "Light armed ships",
                                                    [23] = "Unarmed ships", [24] = "Submarines", [25] = "Cruise missiles",
                                                    [26] = "Antiship Missiles", [27] = "AA Missiles", [28] = "AG Missiles",
                                                    [29] = "SA Missiles",
                                                },
                                            },
                                        },
                                    },
                                },
                                [7] = {
                                    ["number"] = 7,
                                    ["auto"] = true,
                                    ["id"] = "WrappedAction",
                                    ["enabled"] = true,
                                    ["params"] = {
                                        ["action"] = {
                                            ["id"] = "Option",
                                            ["params"] = { ["value"] = true, ["name"] = 19 },
                                        },
                                    },
                                },
                                [8] = {
                                    ["number"] = 8,
                                    ["auto"] = true,
                                    ["id"] = "WrappedAction",
                                    ["enabled"] = true,
                                    ["params"] = {
                                        ["action"] = {
                                            ["id"] = "Option",
                                            ["params"] = { ["value"] = true, ["name"] = 35 },
                                        },
                                    },
                                },
                            },
                        },
                    },
                    ["type"] = "TakeOff",
                    ["ETA"] = 0,
                    ["ETA_locked"] = true,
                    ["y"] = _depRunway.z,
                    ["x"] = _depRunway.x,
                    ["speed_locked"] = true,
                    ["formation_template"] = "",
                },
                -- WAYPOINT 2: Transit to the destination (blue) airfield at cruise
                -- altitude so the flight clears any mountains between here and the target.
                [2] = {
                    ["alt"] = _safeCruiseAlt,
                    ["action"] = "Turning Point",
                    ["alt_type"] = "BARO",
                    ["speed"] = 138.88888888889,
                    ["task"] = {
                        ["id"] = "ComboTask",
                        ["params"] = {
                            ["tasks"] = {},
                        },
                    },
                    ["type"] = "Turning Point",
                    ["ETA_locked"] = false,
                    ["y"] = _destPoint.z,
                    ["x"] = _destPoint.x,
                    ["speed_locked"] = true,
                    ["formation_template"] = "",
                },
                -- WAYPOINT 3: Descend to a low attack altitude over the destination and
                -- attack any enemy ground units in a 10 km zone around the airfield.
                [3] = {
                    ["alt"] = _attackAlt,
                    ["action"] = "Turning Point",
                    ["alt_type"] = "BARO",
                    ["speed"] = 138.88888888889,
                    ["task"] = {
                        ["id"] = "ComboTask",
                        ["params"] = {
                            ["tasks"] = {
                                [1] = {
                                    ["number"] = 1,
                                    ["auto"] = false,
                                    ["id"] = "EngageTargetsInZone",
                                    ["enabled"] = true,
                                    ["params"] = {
                                        ["point"] = { ["x"] = _destPoint.x, ["y"] = _destPoint.z },
                                        ["zoneRadius"] = 10000,
                                        ["targetTypes"] = {
                                            [1] = "Ground Units",
                                            [2] = "Tanks",
                                            [3] = "IFV",
                                            [4] = "APC",
                                            [5] = "Artillery",
                                            [6] = "AAA",
                                            [7] = "SR SAM",
                                            [8] = "MR SAM",
                                            [9] = "Infantry",
                                            [10] = "Fortifications",
                                            [11] = "Unarmed vehicles",
                                        },
                                        ["priority"] = 0,
                                        ["groupAttack"] = true,
                                    },
                                },
                            },
                        },
                    },
                    ["type"] = "Turning Point",
                    ["ETA_locked"] = false,
                    ["y"] = _destPoint.z,
                    ["x"] = _destPoint.x,
                    ["speed_locked"] = true,
                    ["formation_template"] = "",
                },
                -- WAYPOINT 4: Land back at the SAME (departure/red) airfield after the
                -- attack. DCS AI will divert to RTB earlier on its own if fuel runs low
                -- before reaching this point, so no extra bingo-fuel scripting is needed.
                [4] = {
                    ["alt"] = _depPoint.y,
                    ["action"] = "Landing",
                    ["alt_type"] = "BARO",
                    ["speed"] = 138.88888888889,
                    ["airdromeId"] = _depId,
                    ["task"] = {
                        ["id"] = "ComboTask",
                        ["params"] = {
                            ["tasks"] = {},
                        },
                    },
                    ["type"] = "Land",
                    ["ETA_locked"] = false,
                    ["y"] = _depPoint.z,
                    ["x"] = _depPoint.x,
                    ["speed_locked"] = true,
                    ["formation_template"] = "",
                },
            },
        },
        ["units"] = {
            [1] = {
                ["alt"] = _depRunway.y,
                ["alt_type"] = "BARO",
                ["livery_id"] = "field camo scheme #2 (native). 960th shap",
                ["skill"] = "High",
                ["speed"] = 138.88888888889,
                ["type"] = "Su-25",
                ["unitId"] = WE.getNextUnitId(),
                ["psi"] = _depRunway.heading,
                ["onboard_num"] = "010",
                ["y"] = _depRunway.z,
                ["x"] = _depRunway.x,
                ["name"] = "Grif-1-1",
                ["payload"] = {
                    ["pylons"] = {
                        [1] = { ["CLSID"] = "{682A481F-0CB5-4693-A382-D00DD4A156D7}" },
                        [2] = { ["CLSID"] = "{0180F983-C14A-11d8-9897-000476191836}" },
                        [3] = { ["CLSID"] = "{79D73885-0801-45a9-917F-C90FE1CE3DFC}" },
                        [4] = { ["CLSID"] = "{79D73885-0801-45a9-917F-C90FE1CE3DFC}" },
                        [5] = { ["CLSID"] = "{D4A8D9B9-5C45-42e7-BBD2-0E54F8308432}" },
                        [6] = { ["CLSID"] = "{D4A8D9B9-5C45-42e7-BBD2-0E54F8308432}" },
                        [7] = { ["CLSID"] = "{79D73885-0801-45a9-917F-C90FE1CE3DFC}" },
                        [8] = { ["CLSID"] = "{79D73885-0801-45a9-917F-C90FE1CE3DFC}" },
                        [9] = { ["CLSID"] = "{0180F983-C14A-11d8-9897-000476191836}" },
                        [10] = { ["CLSID"] = "{682A481F-0CB5-4693-A382-D00DD4A156D7}" },
                    },
                    ["fuel"] = 2835,
                    ["flare"] = 128,
                    ["chaff"] = 128,
                    ["gun"] = 100,
                },
                ["heading"] = _depRunway.heading,
                ["callsign"] = 103,
            },
            [2] = {
                ["alt"] = _depRunway.y,
                ["alt_type"] = "BARO",
                ["livery_id"] = "field camo scheme #2 (native). 960th shap",
                ["skill"] = "High",
                ["speed"] = 138.88888888889,
                ["type"] = "Su-25",
                ["unitId"] = WE.getNextUnitId(),
                ["psi"] = _depRunway.heading,
                ["onboard_num"] = "011",
                ["y"] = _depRunway.z,
                ["x"] = _depRunway.x,
                ["name"] = "Grif-1-2",
                ["payload"] = {
                    ["pylons"] = {
                        [1] = { ["CLSID"] = "{682A481F-0CB5-4693-A382-D00DD4A156D7}" },
                        [2] = { ["CLSID"] = "{0180F983-C14A-11d8-9897-000476191836}" },
                        [3] = { ["CLSID"] = "{79D73885-0801-45a9-917F-C90FE1CE3DFC}" },
                        [4] = { ["CLSID"] = "{79D73885-0801-45a9-917F-C90FE1CE3DFC}" },
                        [5] = { ["CLSID"] = "{D4A8D9B9-5C45-42e7-BBD2-0E54F8308432}" },
                        [6] = { ["CLSID"] = "{D4A8D9B9-5C45-42e7-BBD2-0E54F8308432}" },
                        [7] = { ["CLSID"] = "{79D73885-0801-45a9-917F-C90FE1CE3DFC}" },
                        [8] = { ["CLSID"] = "{79D73885-0801-45a9-917F-C90FE1CE3DFC}" },
                        [9] = { ["CLSID"] = "{0180F983-C14A-11d8-9897-000476191836}" },
                        [10] = { ["CLSID"] = "{682A481F-0CB5-4693-A382-D00DD4A156D7}" },
                    },
                    ["fuel"] = 2835,
                    ["flare"] = 128,
                    ["chaff"] = 128,
                    ["gun"] = 100,
                },
                ["heading"] = _depRunway.heading,
                ["callsign"] = 104,
            },
            [3] = {
                ["alt"] = _depRunway.y,
                ["alt_type"] = "BARO",
                ["livery_id"] = "field camo scheme #2 (native). 960th shap",
                ["skill"] = "High",
                ["speed"] = 138.88888888889,
                ["type"] = "Su-25",
                ["unitId"] = WE.getNextUnitId(),
                ["psi"] = _depRunway.heading,
                ["onboard_num"] = "012",
                ["y"] = _depRunway.z,
                ["x"] = _depRunway.x,
                ["name"] = "Grif-1-3",
                ["payload"] = {
                    ["pylons"] = {
                        [1] = { ["CLSID"] = "{682A481F-0CB5-4693-A382-D00DD4A156D7}" },
                        [2] = { ["CLSID"] = "{0180F983-C14A-11d8-9897-000476191836}" },
                        [3] = { ["CLSID"] = "{79D73885-0801-45a9-917F-C90FE1CE3DFC}" },
                        [4] = { ["CLSID"] = "{79D73885-0801-45a9-917F-C90FE1CE3DFC}" },
                        [5] = { ["CLSID"] = "{D4A8D9B9-5C45-42e7-BBD2-0E54F8308432}" },
                        [6] = { ["CLSID"] = "{D4A8D9B9-5C45-42e7-BBD2-0E54F8308432}" },
                        [7] = { ["CLSID"] = "{79D73885-0801-45a9-917F-C90FE1CE3DFC}" },
                        [8] = { ["CLSID"] = "{79D73885-0801-45a9-917F-C90FE1CE3DFC}" },
                        [9] = { ["CLSID"] = "{0180F983-C14A-11d8-9897-000476191836}" },
                        [10] = { ["CLSID"] = "{682A481F-0CB5-4693-A382-D00DD4A156D7}" },
                    },
                    ["fuel"] = 2835,
                    ["flare"] = 128,
                    ["chaff"] = 128,
                    ["gun"] = 100,
                },
                ["heading"] = _depRunway.heading,
                ["callsign"] = 105,
            },
        },
        ["y"] = _depRunway.z,
        ["x"] = _depRunway.x,
        ["name"] = "ShAP",
        ["communication"] = true,
        ["start_time"] = 0,
        ["groupId"] = _attackCASGroupId,
        ["frequency"] = 124,
    }

    local attackCASGroupObj = coalition.addGroup(WE.AttackerCountry, Group.Category.AIRPLANE, attackCASGroup)
    if not attackCASGroupObj then
        WE.logError("Failed to spawn base attack CAS group")
        trigger.action.outText("Failed to spawn base attack CAS aircraft", 10)
        return
    end

    -- Workaround to get the actual id if reassigned by DCS
    local _actualAttackCASGroupId = attackCASGroupObj:getID()
    WE.logInfo("Attack CAS group spawned successfully with actual group ID: %s", tostring(_actualAttackCASGroupId))

    -- 10 NM rendezvous calculation (10 NM = 18,520 meters)
    local _rendezvousDistMeters = 10 * 1852
    local _dx = _destPoint.x - _depPoint.x
    local _dz = _destPoint.z - _depPoint.z
    local _totalDist = math.sqrt(_dx * _dx + _dz * _dz)

    local _actualDist = math.min(_rendezvousDistMeters, _totalDist)
    local _midX = _depPoint.x + (_dx / _totalDist) * _actualDist
    local _midY = _depPoint.z + (_dz / _totalDist) * _actualDist
    local _cruiseAlt = 6000 -- Operational altitude in meters (~20,000 ft)
    local _maxTerrainHeight = WE.getMaxTerrainHeight(_depPoint.x, _depPoint.z, _midX, _midY, 5)
    local _safeCruiseAlt = math.max(_cruiseAlt, _maxTerrainHeight + 500)

    -- Attack Fighter Escort Group (unit data from static template group "Vip_Wing_fighter").
    -- Takes off from the same airfield and is tasked to escort the transport: stay
    -- close to it, but break off to engage any air threat within engagement range.
    local attackFighterGroup = {
        ["modulation"] = 0,
        ["tasks"] = {},
        ["task"] = "Escort",
        ["uncontrolled"] = false,
        ["taskSelected"] = true,
        ["hidden"] = false,
        ["route"] = {
            ["routeRelativeTOT"] = true,
            ["points"] = {
                -- WAYPOINT 1: Takeoff / Departure Airfield
                [1] = {
                    ["alt"] = _depRunway.y,
                    ["action"] = "From Runway",
                    ["alt_type"] = "BARO",
                    ["speed"] = 220.97222222222,
                    ["airdromeId"] = _depId,
                    ["task"] = {
                        ["id"] = "ComboTask",
                        ["params"] = {
                            ["tasks"] = {
                                [1] = {
                                    ["number"] = 1,
                                    ["auto"] = true,
                                    ["id"] = "Escort",
                                    ["enabled"] = true,
                                    ["params"] = {
                                        ["groupId"] = _actualAttackCASGroupId,
                                        ["lastWptIndexFlagChangedManually"] = false,
                                        ["lastWptIndex"] = 3,
                                        ["engagementDistMax"] = WE.VIPEscortEngagementDistMax,
                                        ["targetTypes"] = { [1] = "Air" },
                                        ["pos"] = { ["x"] = -200, ["y"] = 250, ["z"] = 300 },
                                    },
                                },
                                [2] = {
                                    ["number"] = 2,
                                    ["key"] = "CAP",
                                    ["id"] = "EngageTargets",
                                    ["enabled"] = true,
                                    ["auto"] = true,
                                    ["params"] = {
                                        ["targetTypes"] = { [1] = "Air" },
                                        ["priority"] = 0,
                                    },
                                },
                                -- Fixed Option 1: ROE (Option.Air.val.ROE = 0) -> Open Fire (2)
                                [3] = {
                                    ["number"] = 3,
                                    ["auto"] = true,
                                    ["id"] = "WrappedAction",
                                    ["enabled"] = true,
                                    ["params"] = {
                                        ["action"] = {
                                            ["id"] = "Option",
                                            ["params"] = {
                                                ["name"] = 0, -- ROE
                                                ["value"] = 2, -- Open Fire
                                            },
                                        },
                                    },
                                },
                                -- Fixed Option 2: Reaction To Threat (Option.Air.val.REACTION_ON_THREAT = 1) -> Evade Fire (4)
                                [4] = {
                                    ["number"] = 4,
                                    ["auto"] = true,
                                    ["id"] = "WrappedAction",
                                    ["enabled"] = true,
                                    ["params"] = {
                                        ["action"] = {
                                            ["id"] = "Option",
                                            ["params"] = {
                                                ["name"] = 1, -- Reaction To Threat
                                                ["value"] = 4, -- Evade Fire
                                            },
                                        },
                                    },
                                },
                                -- Fixed Option 3: Radar Using (Option.Air.val.RADAR_USING = 16) -> Continuous (1)
                                [5] = {
                                    ["number"] = 5,
                                    ["auto"] = true,
                                    ["id"] = "WrappedAction",
                                    ["enabled"] = true,
                                    ["params"] = {
                                        ["action"] = {
                                            ["id"] = "Option",
                                            ["params"] = {
                                                ["name"] = 16, -- Radar Using
                                                ["value"] = 1,  -- Continuous Readout
                                            },
                                        },
                                    },
                                },
                                -- Fixed Option 4: Prohibit Jettison (Option.Air.val.PROHIBIT_JETT = 22) -> true
                                [6] = {
                                    ["number"] = 6,
                                    ["auto"] = true,
                                    ["id"] = "WrappedAction",
                                    ["enabled"] = true,
                                    ["params"] = {
                                        ["action"] = {
                                            ["id"] = "Option",
                                            ["params"] = {
                                                ["name"] = 22, -- Prohibit Jettison
                                                ["value"] = true,
                                            },
                                        },
                                    },
                                },
                            },
                        },
                    },
                    ["type"] = "TakeOff",
                    ["ETA"] = 0,
                    ["ETA_locked"] = true,
                    ["y"] = _depRunway.z,
                    ["x"] = _depRunway.x,
                    ["speed_locked"] = true,
                    ["formation_template"] = "",
                },
                -- WAYPOINT 2: 10 NM Rendezvous / Join Point
                [2] = {
                    ["alt"] = _safeCruiseAlt,
                    ["action"] = "Turning Point",
                    ["alt_type"] = "BARO",
                    ["speed"] = 220.97222222222,
                    ["task"] = {
                        ["id"] = "ComboTask",
                        ["params"] = {
                            ["tasks"] = {},
                        },
                    },
                    ["type"] = "Turning Point",
                    ["ETA_locked"] = false,
                    ["y"] = _midY,
                    ["x"] = _midX,
                    ["speed_locked"] = true,
                    ["formation_template"] = "",
                },
                -- WAYPOINT 3: Landing Destination Airfield
                [3] = {
                    ["alt"] = _destPoint.y,
                    ["action"] = "Landing",
                    ["alt_type"] = "BARO",
                    ["speed"] = 220.97222222222,
                    ["airdromeId"] = _destId,
                    ["task"] = {
                        ["id"] = "ComboTask",
                        ["params"] = {
                            ["tasks"] = {},
                        },
                    },
                    ["type"] = "Land",
                    ["ETA_locked"] = false,
                    ["y"] = _destPoint.z,
                    ["x"] = _destPoint.x,
                    ["speed_locked"] = true,
                    ["formation_template"] = "",
                },
            },
        },
        ["units"] = {
            [1] = {
                ["alt"] = _depRunway.y,
                ["alt_type"] = "BARO",
                ["livery_id"] = "rf standard grey",
                ["skill"] = "Excellent",
                ["speed"] = 220.97222222222,
                ["AddPropAircraft"] = {
                    ["NS430allow"] = true,
                },
                ["type"] = "MiG-29 Fulcrum",
                ["unitId"] = WE.getNextUnitId(),
                ["psi"] = _depRunway.heading,
                ["onboard_num"] = "010",
                ["y"] = _depRunway.z,
                ["x"] = _depRunway.x,
                ["name"] = "Sokol-21",
                ["payload"] = {
                    ["pylons"] = {
                        [1] = { ["CLSID"] = "{682A481F-0CB5-4693-A382-D00DD4A156D7}" },
                        [2] = { ["CLSID"] = "{682A481F-0CB5-4693-A382-D00DD4A156D7}" },
                        [3] = { ["CLSID"] = "{9B25D316-0434-4954-868F-D51DB1A38DF0}" },
                        [5] = { ["CLSID"] = "{9B25D316-0434-4954-868F-D51DB1A38DF0}" },
                        [6] = { ["CLSID"] = "{682A481F-0CB5-4693-A382-D00DD4A156D7}" },
                        [7] = { ["CLSID"] = "{682A481F-0CB5-4693-A382-D00DD4A156D7}" },
                    },
                    ["fuel"] = 3376,
                    ["flare"] = 30,
                    ["ammo_type"] = 5,
                    ["chaff"] = 30,
                    ["gun"] = 100,
                },
                ["heading"] = _depRunway.heading,
                ["callsign"] = 121,
            },
            [2] = {
                ["alt"] = _depRunway.y,
                ["alt_type"] = "BARO",
                ["livery_id"] = "rf standard grey",
                ["skill"] = "High",
                ["speed"] = 220.97222222222,
                ["AddPropAircraft"] = {
                    ["NS430allow"] = true,
                },
                ["type"] = "MiG-29 Fulcrum",
                ["unitId"] = WE.getNextUnitId(),
                ["psi"] = _depRunway.heading,
                ["onboard_num"] = "011",
                ["y"] = _depRunway.z,
                ["x"] = _depRunway.x,
                ["name"] = "Sokol-22",
                ["payload"] = {
                    ["pylons"] = {
                        [1] = { ["CLSID"] = "{682A481F-0CB5-4693-A382-D00DD4A156D7}" },
                        [2] = { ["CLSID"] = "{682A481F-0CB5-4693-A382-D00DD4A156D7}" },
                        [3] = { ["CLSID"] = "{E8069896-8435-4B90-95C0-01A03AE6E400}" },
                        [5] = { ["CLSID"] = "{E8069896-8435-4B90-95C0-01A03AE6E400}" },
                        [6] = { ["CLSID"] = "{682A481F-0CB5-4693-A382-D00DD4A156D7}" },
                        [7] = { ["CLSID"] = "{682A481F-0CB5-4693-A382-D00DD4A156D7}" },
                    },
                    ["fuel"] = 3376,
                    ["flare"] = 30,
                    ["ammo_type"] = 5,
                    ["chaff"] = 30,
                    ["gun"] = 100,
                },
                ["heading"] = _depRunway.heading,
                ["callsign"] = 122,
            },
            [3] = {
                ["alt"] = _depRunway.y,
                ["alt_type"] = "BARO",
                ["livery_id"] = "rf standard grey",
                ["skill"] = "High",
                ["speed"] = 220.97222222222,
                ["AddPropAircraft"] = {
                    ["NS430allow"] = true,
                },
                ["type"] = "MiG-29 Fulcrum",
                ["unitId"] = WE.getNextUnitId(),
                ["psi"] = _depRunway.heading,
                ["onboard_num"] = "012",
                ["y"] = _depRunway.z,
                ["x"] = _depRunway.x,
                ["name"] = "Sokol-23",
                ["payload"] = {
                    ["pylons"] = {
                        [1] = { ["CLSID"] = "{682A481F-0CB5-4693-A382-D00DD4A156D7}" },
                        [2] = { ["CLSID"] = "{682A481F-0CB5-4693-A382-D00DD4A156D7}" },
                        [3] = { ["CLSID"] = "{E8069896-8435-4B90-95C0-01A03AE6E400}" },
                        [5] = { ["CLSID"] = "{E8069896-8435-4B90-95C0-01A03AE6E400}" },
                        [6] = { ["CLSID"] = "{682A481F-0CB5-4693-A382-D00DD4A156D7}" },
                        [7] = { ["CLSID"] = "{682A481F-0CB5-4693-A382-D00DD4A156D7}" },
                    },
                    ["fuel"] = 3376,
                    ["flare"] = 30,
                    ["ammo_type"] = 5,
                    ["chaff"] = 30,
                    ["gun"] = 100,
                },
                ["heading"] = _depRunway.heading,
                ["callsign"] = 123,
            },
            [4] = {
                ["alt"] = _depRunway.y,
                ["alt_type"] = "BARO",
                ["livery_id"] = "rf standard grey",
                ["skill"] = "High",
                ["speed"] = 220.97222222222,
                ["AddPropAircraft"] = {
                    ["NS430allow"] = true,
                },
                ["type"] = "MiG-29 Fulcrum",
                ["unitId"] = WE.getNextUnitId(),
                ["psi"] = _depRunway.heading,
                ["onboard_num"] = "013",
                ["y"] = _depRunway.z,
                ["x"] = _depRunway.x,
                ["name"] = "Sokol-24",
                ["payload"] = {
                    ["pylons"] = {
                        [1] = { ["CLSID"] = "{682A481F-0CB5-4693-A382-D00DD4A156D7}" },
                        [2] = { ["CLSID"] = "{682A481F-0CB5-4693-A382-D00DD4A156D7}" },
                        [3] = { ["CLSID"] = "{E8069896-8435-4B90-95C0-01A03AE6E400}" },
                        [5] = { ["CLSID"] = "{E8069896-8435-4B90-95C0-01A03AE6E400}" },
                        [6] = { ["CLSID"] = "{682A481F-0CB5-4693-A382-D00DD4A156D7}" },
                        [7] = { ["CLSID"] = "{682A481F-0CB5-4693-A382-D00DD4A156D7}" },
                    },
                    ["fuel"] = 3376,
                    ["flare"] = 30,
                    ["ammo_type"] = 5,
                    ["chaff"] = 30,
                    ["gun"] = 100,
                },
                ["heading"] = _depRunway.heading,
                ["callsign"] = 124,
            },
        },
        ["y"] = _depRunway.z,
        ["x"] = _depRunway.x,
        ["name"] = "Sokol_Fighter_Wing",
        ["communication"] = true,
        ["start_time"] = 0,
        ["groupId"] = WE.getNextGroupId(),
        ["frequency"] = 124,
    }

    -- Spawn the fighter escort group
    local attackFighterGroupId = coalition.addGroup(WE.AttackerCountry, Group.Category.AIRPLANE, attackFighterGroup)
    if attackFighterGroupId then
        WE.logInfo("Attack Fighter Escort group spawned successfully with group ID: %s", tostring(attackFighterGroupId))
    else
        WE.logError("Failed to spawn Attack Fighter Escort group")
        trigger.action.outText("Failed to spawn Attack Fighter Escort", 10)
    end
    local _actualAttackFighterGroupId = attackFighterGroupId

    -- Mark event as active and remember the mission details for Event Status
    WE.is_active = 1
    WE.currentBaseAttackEvent = {
        departure = _depName,
        destination = _destName,
        attackCASGroupGroupId = _actualAttackCASGroupId,
        fighterGroupId = _actualAttackFighterGroupId,
    }

    WE.logInfo("Base Attack event completed successfully - CAS Group ID: %s, Fighter Group ID: %s",
        tostring(_actualAttackCASGroupId), tostring(_actualAttackFighterGroupId))

    -- Communicate the airfields to all players so they know where to look
    trigger.action.outText(
        string.format(
            "Base Attack mission is active! An enemy attack mission targeting our base is imminent. They are departing %s, bound for %s. Intercept it!",
            _depName, _destName),
        20)

    trigger.action.outSound("attn_attack.ogg")
end

-- Create a table to hold our custom event handler
WE.EVENT.BASEATTACK = {}

-- Define the function that DCS calls every time ANY event happens in the world
function WE.EVENT.BASEATTACK:onEvent(event)
    if not event then return end
    if not WE.is_active or WE.is_active ~= 1 then return end
    if not event.initiator then return end

    local _unit = event.initiator
    if not _unit.getName or type(_unit.getName) ~= "function" then return end
    if not _unit.getGroup or type(_unit.getGroup) ~= "function" then return end

    local _eventData = WE.currentBaseAttackEvent
    if not _eventData then return end

    -- Only care about units from the ShAP (Grif) CAS group
    local _unitGroup = _unit:getGroup()
    if not _unitGroup then return end
    if not _unitGroup:isExist() then return end
    if _unitGroup:getID() ~= _eventData.attackCASGroupGroupId then return end

    if event.id == world.event.S_EVENT_DEAD then
        WE.logInfo("Base Attack: Grif unit %s destroyed, checking if all are eliminated", _unit:getName())

        local _allDead = true
        local _casGroup = Group.getByName("ShAP")
        if _casGroup and _casGroup:isExist() then
            local _units = _casGroup:getUnits()
            for _, _u in pairs(_units) do
                if _u:getLife() > 0 then
                    _allDead = false
                    break
                end
            end
        end

        if _allDead then
            trigger.action.outText("SUCCESS: All Grif attack aircraft have been destroyed! The base is safe!", 10)
            WE.is_active = 0
            WE.currentBaseAttackEvent = nil
            WE.logInfo("Base Attack event ended - all Grif aircraft destroyed (success)")
        end

    elseif event.id == world.event.S_EVENT_ENGINE_SHUTDOWN then
        WE.logInfo("Base Attack: Grif unit %s shut down engines, attack failed", _unit:getName())

        trigger.action.outText("FAILURE: Grif attack aircraft have landed safely at their home base. The base was not protected!", 10)
        WE.is_active = 0
        WE.currentBaseAttackEvent = nil
        WE.logInfo("Base Attack event ended - Grif aircraft landed and shut down (failure)")
    end
end

-- Register the handler with the DCS world engine so it starts listening
world.addEventHandler(WE.EVENT.BASEATTACK)

-----------------[[ END OF event_baseattack.lua ]]-----------------
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
-----------------[[ init.lua ]]-----------------

function WE.initialize()
    WE.logInfo(string.format("Initializing version %s", WE.Version))
    
    -- Initialize radio menu system
    WE.initializeRadioMenu()
    
    -- Initialize event handling system
    WE.initializeEvents()
    
    WE.logInfo("World Events system initialization complete")
end


WE.initialize(); -- Go Time!

-----------------[[ END OF init.lua ]]-----------------
