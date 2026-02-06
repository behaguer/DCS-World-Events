-----------------[[ utility.lua ]]-----------------

--- print an object for a debugging log
--- @param o any object to print
--- @param level? number depth level for recursion
--- @return string formatted string representation of the object
function ME.p(o, level)
    local MAX_LEVEL = 20
    if level == nil then level = 0 end
    if level > MAX_LEVEL then
        ME.logError("max depth reached in ME.p : " .. tostring(MAX_LEVEL))
        return ""
    end
    local text = ""
    if (type(o) == "table") then
        text = "\n"
        for key, value in pairs(o) do
            for i = 0, level do
                text = text .. " "
            end
            text = text .. "." .. key .. "=" .. ME.p(value, level + 1) .. "\n"
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
function ME.formatText(text, ...)
    if not text then
        return ""
    end
    if type(text) ~= 'string' then
        text = ME.p(text)
    else
        local args = ...
        if args and args.n and args.n > 0 then
            local pArgs = {}
            for i = 1, args.n do
                pArgs[i] = ME.p(args[i])
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
function ME.logError(message, ...)
    message = ME.formatText(message, arg)
    env.info(" E - " .. ME.Id .. message)
end

--- log a warning
--- @param message any message to log
--- @param ... any arguments to format into the message
function ME.logWarning(message, ...)
    message = ME.formatText(message, arg)
    env.info(" W - " .. ME.Id .. message)
end

--- log an info
--- @param message any message to log
--- @param ... any arguments to format into the message
function ME.logInfo(message, ...)
    message = ME.formatText(message, arg)
    env.info(" I - " .. ME.Id .. message)
end

--- log an debug mesage
--- @param message any message to log
--- @param ... any arguments to format into the message
function ME.logDebug(message, ...)
    if message and ME.Debug then
        message = ME.formatText(message, arg)
        env.info(" D - " .. ME.Id .. message)
    end
end

--- log a trace mesage
--- @param message any message to log
--- @param ... any arguments to format into the message
function ME.logTrace(message, ...)
    if message and ME.Trace then
        message = ME.formatText(message, arg)
        env.info(" T - " .. ME.Id .. message)
    end
end

--- Next Unit ID generator
--- @return number next unit ID from state
ME.getNextUnitId = function()
    ME.nextUnitId = ME.nextUnitId + 1
    return ME.nextUnitId
end

--- Next Group ID generator
--- @return number next group ID from state
ME.getNextGroupId = function()
    ME.nextGroupId = ME.nextGroupId + 1
    return ME.nextGroupId
end

--- Get transport unit by name if active and alive
--- @param _unitName string name of the transport unit
--- @return Unit|nil transport unit object if active and alive, otherwise nil
function ME.getTransportUnit(_unitName)
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
function ME.getPointAt12Oclock(_unit, _offset)
    return ME.getPointAtDirection(_unit, _offset, 0)
end

--- Get point at 6 o'clock from unit
--- @param _unit Unit transport unit
--- @param _offset number|nil offset distance in meters
function ME.getPointAt6Oclock(_unit, _offset)
    return ME.getPointAtDirection(_unit, _offset, math.pi)
end

--- Get point at direction from unit
--- @param _unit Unit transport unit
--- @param _offset number|nil offset distance in meters
--- @param _directionInRadian number direction in radians
--- @return table point table with x, y, z coordinates
function ME.getPointAtDirection(_unit, _offset, _directionInRadian)
    if _offset == nil then
        _offset = ME.getSecureDistanceFromUnit(_unit:getName())
    end
    --ME.logTrace("_offset = %s", ME.p(_offset))
    local _randomOffsetX = math.random(0, ME.randomCrateSpacing * 2) - ME.randomCrateSpacing
    local _randomOffsetZ = math.random(0, ME.randomCrateSpacing)
    --ME.logTrace("_randomOffsetX = %s", ME.p(_randomOffsetX))
    --ME.logTrace("_randomOffsetZ = %s", ME.p(_randomOffsetZ))
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
function ME.getRelativePoint(_refPointXZTable, _distance, _angle_radians)  
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
function ME.troopsOnboard(_heli, _troops)
    if ME.inTransitTroops[_heli:getName()] ~= nil then
        local _onboard = ME.inTransitTroops[_heli:getName()]

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
function ME.getPlayerNameOrType(_heli)
    if _heli:getPlayerName() == nil then
        return _heli:getTypeName()
    else
        return _heli:getPlayerName()
    end
end

--- Check if helicopter is in an extract zone
--- @param _heli Unit transport unit
--- @return table|boolean extract zone details table if in extract zone, false otherwise
function ME.inExtractZone(_heli)
    local _heliPoint = _heli:getPoint()

    for _, _zoneDetails in pairs(ME.extractZones) do
        --get distance to center
        local _dist = ME.getDistance(_heliPoint, _zoneDetails.point)

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
function ME.insertIntoTroopsArray(_troopType, _count, _troopArray, _troopName)
    for _i = 1, _count do
        local _unitId = ME.getNextUnitId()
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
function ME.generateTroopTypes(_side, _countOrTemplate, _country)
    local _troops = {}
    local _weight = 0
    local _hasJTAC = false

    local function getSoldiersWeight(count, additionalWeight)
        local _weight = 0
        for i = 1, count do
            local _soldierWeight = math.random(90, 120) * ME.SOLDIER_WEIGHT / 100
            _weight = _weight + _soldierWeight + ME.KIT_WEIGHT + additionalWeight
        end
        return _weight
    end

    if type(_countOrTemplate) == "table" then
        if _countOrTemplate.aa then
            if _side == 2 then
                _troops = ME.insertIntoTroopsArray("Soldier stinger", _countOrTemplate.aa, _troops)
            else
                _troops = ME.insertIntoTroopsArray("SA-18 Igla manpad", _countOrTemplate.aa, _troops)
            end
            _weight = _weight + getSoldiersWeight(_countOrTemplate.aa, ME.MANPAD_WEIGHT)
        end

        if _countOrTemplate.inf then
            if _side == 2 then
                _troops = ME.insertIntoTroopsArray("Soldier M4 GRG", _countOrTemplate.inf, _troops)
            else
                _troops = ME.insertIntoTroopsArray("Infantry AK", _countOrTemplate.inf, _troops)
            end
            _weight = _weight + getSoldiersWeight(_countOrTemplate.inf, ME.RIFLE_WEIGHT)
        end

        if _countOrTemplate.mg then
            if _side == 2 then
                _troops = ME.insertIntoTroopsArray("Soldier M249", _countOrTemplate.mg, _troops)
            else
                _troops = ME.insertIntoTroopsArray("Paratrooper AKS-74", _countOrTemplate.mg, _troops)
            end
            _weight = _weight + getSoldiersWeight(_countOrTemplate.mg, ME.MG_WEIGHT)
        end

        if _countOrTemplate.at then
            _troops = ME.insertIntoTroopsArray("Paratrooper RPG-16", _countOrTemplate.at, _troops)
            _weight = _weight + getSoldiersWeight(_countOrTemplate.at, ME.RPG_WEIGHT)
        end

        if _countOrTemplate.mortar then
            _troops = ME.insertIntoTroopsArray("2B11 mortar", _countOrTemplate.mortar, _troops)
            _weight = _weight + getSoldiersWeight(_countOrTemplate.mortar, ME.MORTAR_WEIGHT)
        end

        if _countOrTemplate.jtac then
            if _side == 2 then
                _troops = ME.insertIntoTroopsArray("Soldier M4 GRG", _countOrTemplate.jtac, _troops, "JTAC")
            else
                _troops = ME.insertIntoTroopsArray("Infantry AK", _countOrTemplate.jtac, _troops, "JTAC")
            end
            _hasJTAC = true
            _weight = _weight + getSoldiersWeight(_countOrTemplate.jtac, ME.JTAC_WEIGHT + ME.RIFLE_WEIGHT)
        end
    else
        for _i = 1, _countOrTemplate do
            local _unitType = "Infantry AK"

            if _side == 2 then
                if _i <= 2 then
                    _unitType = "Soldier M249"
                    _weight = _weight + getSoldiersWeight(1, ME.MG_WEIGHT)
                elseif ME.spawnRPGWithCoalition and _i > 2 and _i <= 4 then
                    _unitType = "Paratrooper RPG-16"
                    _weight = _weight + getSoldiersWeight(1, ME.RPG_WEIGHT)
                elseif ME.spawnStinger and _i > 4 and _i <= 5 then
                    _unitType = "Soldier stinger"
                    _weight = _weight + getSoldiersWeight(1, ME.MANPAD_WEIGHT)
                else
                    _unitType = "Soldier M4 GRG"
                    _weight = _weight + getSoldiersWeight(1, ME.RIFLE_WEIGHT)
                end
            else
                if _i <= 2 then
                    _unitType = "Paratrooper AKS-74"
                    _weight = _weight + getSoldiersWeight(1, ME.MG_WEIGHT)
                elseif ME.spawnRPGWithCoalition and _i > 2 and _i <= 4 then
                    _unitType = "Paratrooper RPG-16"
                    _weight = _weight + getSoldiersWeight(1, ME.RPG_WEIGHT)
                elseif ME.spawnStinger and _i > 4 and _i <= 5 then
                    _unitType = "SA-18 Igla manpad"
                    _weight = _weight + getSoldiersWeight(1, ME.MANPAD_WEIGHT)
                else
                    _unitType = "Infantry AK"
                    _weight = _weight + getSoldiersWeight(1, ME.RIFLE_WEIGHT)
                end
            end

            local _unitId = ME.getNextUnitId()

            _troops[_i] = { type = _unitType, unitId = _unitId, name = string.format("Dropped %s #%i", _unitType, _unitId) }
        end
    end

    local _groupId = ME.getNextGroupId()
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
function ME.unloadExtractTroops(_args)
    local _heli = ME.getTransportUnit(_args[1])

    if _heli == nil then
        return false
    end

    local _extract = nil
    if not ME.inAir(_heli) then
        if _heli:getCoalition() == 1 then
            _extract = ME.findNearestGroup(_heli, ME.droppedTroopsRED)
        else
            _extract = ME.findNearestGroup(_heli, ME.droppedTroopsBLUE)
        end
    end

    if _extract ~= nil and not ME.troopsOnboard(_heli, true) then
        -- search for nearest troops to pickup
        return ME.extractTroops({ _heli:getName(), true })
    else
        return ME.unloadTroops({ _heli:getName(), true, true })
    end
end

--- load troops onto vehicle
--- @param _heli Unit transport unit
--- @param _troops boolean true to load troops, false to load vehicles
--- @param _numberOrTemplate number|table number of troops or template table
function ME.loadTroops(_heli, _troops, _numberOrTemplate)
    -- load troops + vehicles if c130 or herc
    -- "M1045 HMMWV TOW"
    -- "M1043 HMMWV Armament"
    local _onboard = ME.inTransitTroops[_heli:getName()]

    --number doesnt apply to vehicles
    if _numberOrTemplate == nil or (type(_numberOrTemplate) ~= "table" and type(_numberOrTemplate) ~= "number") then
        _numberOrTemplate = ME.getTransportLimit(_heli:getTypeName())
    end

    if _onboard == nil then
        _onboard = { troops = {}, vehicles = {} }
    end

    local _list
    if _heli:getCoalition() == 1 then
        _list = ME.vehiclesForTransportRED
    else
        _list = ME.vehiclesForTransportBLUE
    end

    if _troops then
        _onboard.troops = ME.generateTroopTypes(_heli:getCoalition(), _numberOrTemplate, _heli:getCountry())
        trigger.action.outTextForCoalition(_heli:getCoalition(),
            ME.i18n_translate("%1 loaded troops into %2", ME.getPlayerNameOrType(_heli), _heli:getTypeName()), 10)

        ME.processCallback({ unit = _heli, onboard = _onboard.troops, action = "load_troops" })
    else
        _onboard.vehicles = ME.generateVehiclesForTransport(_heli:getCoalition(), _heli:getCountry())

        local _count = #_list

        ME.processCallback({ unit = _heli, onboard = _onboard.vehicles, action = "load_vehicles" })

        trigger.action.outTextForCoalition(_heli:getCoalition(),
            ME.i18n_translate("%1 loaded %2 vehicles into %3", ME.getPlayerNameOrType(_heli), _count,
                _heli:getTypeName()), 10)
    end

    ME.inTransitTroops[_heli:getName()] = _onboard
    ME.adaptWeightToCargo(_heli:getName())
end

--- Generate vehicle types for transport
--- @param _side number coalition side
--- @param _country number country ID
--- @return table vehicle details table
function ME.generateVehiclesForTransport(_side, _country)
    local _vehicles = {}
    local _list
    if _side == 1 then
        _list = ME.vehiclesForTransportRED
    else
        _list = ME.vehiclesForTransportBLUE
    end


    for _i, _type in ipairs(_list) do
        local _unitId = ME.getNextUnitId()
        local _weight = ME.vehiclesWeight[_type] or 2500
        _vehicles[_i] = { type = _type, unitId = _unitId, name = string.format("Dropped %s #%i", _type, _unitId), weight =
        _weight }
    end


    local _groupId = ME.getNextGroupId()
    local _details = { units = _vehicles, groupId = _groupId, groupName = string.format("Dropped Group %i", _groupId), side =
    _side, country = _country }

    return _details
end

--- Load or unload FOB crate from helicopter
--- @param _args table arguments table
function ME.loadUnloadFOBCrate(_args)
    local _heli = ME.getTransportUnit(_args[1])
    local _troops = _args[2]

    if _heli == nil then
        return
    end

    if ME.inAir(_heli) == true then
        return
    end


    local _side = _heli:getCoalition()

    local _inZone = ME.inLogisticsZone(_heli)
    local _crateOnboard = ME.inTransitFOBCrates[_heli:getName()] ~= nil

    if _inZone == false and _crateOnboard == true then
        ME.inTransitFOBCrates[_heli:getName()] = nil

        local _position = _heli:getPosition()
        local _point = _heli:getPoint()
        local _side = _heli:getCoalition()

        -- Spawn 9 FOB crates in a 3x3 grid pattern
        local _cratesSpawned = 0
        local _spacing = 15 -- Distance between crates
        
        for _row = -1, 1 do
            for _col = -1, 1 do
                local _unitId = ME.getNextUnitId()
                local _name = string.format("FOB Crate #%i", _unitId)
                
                -- Calculate offset from helicopter position
                local _xOffset = _col * _spacing
                local _yOffset = _row * _spacing
                
                -- Try to spawn at 6 oclock with grid offset
                local _angle = math.atan2(_position.x.z, _position.x.x)
                local _baseXOffset = math.cos(_angle) * -60
                local _baseYOffset = math.sin(_angle) * -60
                
                local _spawnedCrate = ME.spawnFOBCrateStatic(_heli:getCountry(), _unitId,
                    { x = _point.x + _baseXOffset + _xOffset, z = _point.z + _baseYOffset + _yOffset }, _name)

                if _side == 1 then
                    ME.droppedFOBCratesRED[_name] = _name
                else
                    ME.droppedFOBCratesBLUE[_name] = _name
                end
                
                _cratesSpawned = _cratesSpawned + 1
            end
        end

        trigger.action.outTextForCoalition(_heli:getCoalition(),
            ME.i18n_translate("%1 delivered %2 FOB Crates", ME.getPlayerNameOrType(_heli), _cratesSpawned), 10)

        ME.displayMessageToGroup(_heli, string.format("Delivered %d FOB Crates in a grid pattern behind you", _cratesSpawned), 10)
    elseif _inZone == true and _crateOnboard == true then
        ME.displayMessageToGroup(_heli, ME.i18n_translate("FOB Crate dropped back to base"), 10)

        ME.inTransitFOBCrates[_heli:getName()] = nil
    elseif _inZone == true and _crateOnboard == false then
        ME.displayMessageToGroup(_heli, ME.i18n_translate("FOB Crate Loaded"), 10)

        ME.inTransitFOBCrates[_heli:getName()] = true

        trigger.action.outTextForCoalition(_heli:getCoalition(),
            ME.i18n_translate("%1 loaded a FOB Crate ready for delivery!", ME.getPlayerNameOrType(_heli)), 10)
    else
        -- nearest Crate
        local _crates = ME.getCratesAndDistance(_heli)
        local _nearestCrate = ME.getClosestCrate(_heli, _crates, "FOB")

        if _nearestCrate ~= nil and _nearestCrate.dist < 150 then
            ME.displayMessageToGroup(_heli, ME.i18n_translate("FOB Crate Loaded"), 10)
            ME.inTransitFOBCrates[_heli:getName()] = true

            trigger.action.outTextForCoalition(_heli:getCoalition(),
                ME.i18n_translate("%1 loaded a FOB Crate ready for delivery!", ME.getPlayerNameOrType(_heli)), 10)

            if _side == 1 then
                ME.droppedFOBCratesRED[_nearestCrate.crateUnit:getName()] = nil
            else
                ME.droppedFOBCratesBLUE[_nearestCrate.crateUnit:getName()] = nil
            end

            --remove
            _nearestCrate.crateUnit:destroy()
        else
            ME.displayMessageToGroup(_heli,
                ME.i18n_translate("There are no friendly logistic units nearby to load a FOB crate from!"), 10)
        end
    end
end

--- Return count of troops in game by Coalition
--- @param params table scheduler params
--- @param t number current time
--- @return number reschedule time in seconds
function ME.updateTroopsInGame(params, t)
 	if t == nil then t = timer.getTime() + 1; end
    ME.InfantryInGameCount  = {0, 0}
    for coalitionId=1, 2 do				-- for each CoaId
        for k,v in ipairs(coalition.getGroups(coalitionId, Group.Category.GROUND)) do   -- for each GROUND type group
			for index, unitObj in pairs(v:getUnits()) do		-- for each unit in group
                if unitObj:getDesc().attributes.Infantry then
                    ME.InfantryInGameCount[coalitionId] = ME.InfantryInGameCount[coalitionId] + 1
                end
            end
        end
    end
    return 5		-- reschedule each 5"
end

--- Load troops onto helicopter from zone or extract nearby troops
--- @param _args table arguments table
--- @return boolean true if troops loaded, false otherwise
function ME.loadTroopsFromZone(_args)
    local _heli = ME.getTransportUnit(_args[1])
    local _troops = _args[2]
    local _groupTemplate = _args[3] or nil
    local _allowExtract = _args[4]

    if _heli == nil then
        return false
    end

    local _zone = ME.inPickupZone(_heli)

    if ME.troopsOnboard(_heli, _troops) then
        if _troops then
            ME.displayMessageToGroup(_heli, ME.i18n_translate("You already have troops onboard."), 10)
        else
            ME.displayMessageToGroup(_heli, ME.i18n_translate("You already have vehicles onboard."), 10)
        end
        return false
    end

    local _extract

    if _allowExtract then
        -- first check for extractable troops regardless of if we're in a zone or not
        if _troops then
            if _heli:getCoalition() == 1 then
                _extract = ME.findNearestGroup(_heli, ME.droppedTroopsRED)
            else
                _extract = ME.findNearestGroup(_heli, ME.droppedTroopsBLUE)
            end
        else

            if _heli:getCoalition() == 1 then
                _extract = ME.findNearestGroup(_heli, ME.droppedVehiclesRED)
            else
                _extract = ME.findNearestGroup(_heli, ME.droppedVehiclesBLUE)
            end
        end
    end

    if _extract ~= nil then
        -- search for nearest troops to pickup
        return ME.extractTroops({_heli:getName(), _troops})
    elseif _zone.inZone == true then

        local heloCoa = _heli:getCoalition()
        ME.logTrace("FG_ heloCoa =  %s", ME.p(heloCoa))
        ME.logTrace("FG_ (ME.nbLimitSpawnedTroops[1]~=0 or ME.nbLimitSpawnedTroops[2]~=0) =  %s", ME.p(ME.nbLimitSpawnedTroops[1]~=0 or ME.nbLimitSpawnedTroops[2]~=0))
        ME.logTrace("FG_ ME.InfantryInGameCount[heloCoa] =  %s", ME.p(ME.InfantryInGameCount[heloCoa]))
        
        local groupTotal = 0
        if _groupTemplate then
            if type(_groupTemplate) == "table" and _groupTemplate.total and type(_groupTemplate.total) == "number" then
                groupTotal = _groupTemplate.total
            elseif type(_groupTemplate) == "number" then
                groupTotal = _groupTemplate
            end
        end

        ME.logTrace("FG_ _groupTemplate.total =  %s", ME.p(groupTotal))
        ME.logTrace("FG_ ME.nbLimitSpawnedTroops[%s].total =  %s", ME.p(heloCoa), ME.p(ME.nbLimitSpawnedTroops[heloCoa]))

        local limitReached = true
        if (ME.nbLimitSpawnedTroops[1]~=0 or ME.nbLimitSpawnedTroops[2]~=0) and (ME.InfantryInGameCount[heloCoa] + groupTotal > ME.nbLimitSpawnedTroops[heloCoa]) then  -- load troops only if Coa limit not reached
            ME.displayMessageToGroup(_heli, ME.i18n_translate("Count Infantries limit in the mission reached, you can't load more troops"), 10)
            return false
        end

        if _zone.limit - 1 >= 0 then
            -- decrease zone counter by 1
            ME.updateZoneCounter(_zone.index, -1)
            ME.loadTroops(_heli, _troops,_groupTemplate)
            return true
        else
            ME.displayMessageToGroup(_heli, ME.i18n_translate("This area has no more reinforcements available!"), 20)
            return false
        end
    else
        if _allowExtract then
            ME.displayMessageToGroup(_heli, ME.i18n_translate("You are not in a pickup zone and no one is nearby to extract"), 10)
        else
            ME.displayMessageToGroup(_heli, ME.i18n_translate("You are not in a pickup zone"), 10)
        end

        return false
    end
end

--- unload troops from helicopter to zone or deploy nearby
--- @param _args table arguments table
--- @return boolean true if troops unloaded, false otherwise
function ME.unloadTroops(_args)
    local _heli = ME.getTransportUnit(_args[1])
    local _troops = _args[2]

    if _heli == nil then
        return false
    end

    local _zone = ME.inPickupZone(_heli)
    if not ME.troopsOnboard(_heli, _troops) then
        ME.displayMessageToGroup(_heli, ME.i18n_translate("No one to unload"), 10)

        return false
    else
        -- troops must be onboard to get here
        if _zone.inZone == true then
            if _troops then
                ME.displayMessageToGroup(_heli, ME.i18n_translate("Dropped troops back to base"), 20)

                ME.processCallback({ unit = _heli, unloaded = ME.inTransitTroops[_heli:getName()].troops, action =
                "unload_troops_zone" })

                ME.inTransitTroops[_heli:getName()].troops = nil
            else
                ME.displayMessageToGroup(_heli, ME.i18n_translate("Dropped vehicles back to base"), 20)

                ME.processCallback({ unit = _heli, unloaded = ME.inTransitTroops[_heli:getName()].vehicles, action =
                "unload_vehicles_zone" })

                ME.inTransitTroops[_heli:getName()].vehicles = nil
            end

            ME.adaptWeightToCargo(_heli:getName())

            -- increase zone counter by 1
            ME.updateZoneCounter(_zone.index, 1)

            return true
        elseif ME.troopsOnboard(_heli, _troops) then
            return ME.deployTroops(_heli, _troops)
        end
    end
    return false
end

--- Display message to unit's group
--- @param _unit Unit unit to get group from
--- @param _text string message text
--- @param _time number display time
--- @param _clear? boolean clear previous messages
function ME.displayMessageToGroup(_unit, _text, _time, _clear)
    local _groupId = ME.getGroupId(_unit)
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
function ME.heightDiff(_unit)
    local _point = _unit:getPoint()
    return _point.y - land.getHeight({ x = _point.x, y = _point.z })
end

--- Get crate static object by name
--- @param _name string crate unit name
--- @return Unit crate static object
function ME.getCrateObject(_name)
    local _crate

    if ME.staticBugWorkaround then
        _crate = Unit.getByName(_name)
    else
        _crate = StaticObject.getByName(_name)
    end
    return _crate
end

--- Gets the center of a bunch of points!
--- @param _points table list of points
--- @return table centroid point with height
function ME.getCentroid(_points)
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
function ME.countTableEntries(_table)
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
function ME.findNearestEnemy(_side, _point, _searchDistance)
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
                    local _dist = ME.getDistance(_heliPoint, _leaderPos)
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
        local _x = _heliPoint.x + math.random(0, ME.maximumMoveDistance) - math.random(0, ME.maximumMoveDistance)
        local _z = _heliPoint.z + math.random(0, ME.maximumMoveDistance) - math.random(0, ME.maximumMoveDistance)
        local _y = _heliPoint.y + math.random(0, ME.maximumMoveDistance) - math.random(0, ME.maximumMoveDistance)

        return { x = _x, z = _z, y = _y }
    end
end

--- Find nearest group from list
--- @param _heli Unit helicopter unit
--- @param _groups table list of group names
--- @return table|nil nearest group and details
function ME.findNearestGroup(_heli, _groups)
    local _closestGroupDetails = {}
    local _closestGroup = nil

    local _closestGroupDist = ME.maxExtractDistance

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
                    local _dist = ME.getDistance(_heliPoint, _leaderPos)
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
function ME.createUnit(_x, _y, _angle, _details)
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
function ME.dropSmoke(_args)
    local _heli = ME.getTransportUnit(_args[1])

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
            ME.i18n_translate("%1 dropped %2 smoke.", ME.getPlayerNameOrType(_heli), _colour), 10)
    end
end

--- Can unit carry vehicles
--- @param _unit Unit unit to check
--- @return boolean can carry vehicles
function ME.unitCanCarryVehicles(_unit)
    local _type = string.lower(_unit:getTypeName())

    for _, _name in ipairs(ME.vehicleTransportEnabled) do
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
function ME.unitDynamicCargoCapable(_unit)
    local cache = {}
    local _type = string.lower(_unit:getTypeName())
    local result = cache[_type]
    if result == nil then
        result = false
        --ME.logDebug("ME.unitDynamicCargoCapable(_type=[%s])", ME.p(_type))
        for _, _name in ipairs(ME.dynamicCargoUnits) do
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
function ME.processCallback(_callbackArgs)
    for _, _callback in pairs(ME.callbacks) do
        local _status, _result = pcall(function()
            _callback(_callbackArgs)
        end)

        if (not _status) then
            env.error(string.format("Callback Error: %s", _result))
        end
    end
end

--- checks the status of all AI troop carriers and auto loads and unloads troops as long as the troops are on the ground
function ME.checkAIStatus()
    timer.scheduleFunction(ME.checkAIStatus, nil, timer.getTime() + 2)
    for _, _unitName in pairs(ME.transportPilotNames) do
        local status, error = pcall(function()
            local _unit = ME.getTransportUnit(_unitName)

            -- no player name means AI!
            if _unit ~= nil and _unit:getPlayerName() == nil then
                local _zone = ME.inPickupZone(_unit)
                --    env.error("Checking.. ".._unit:getName())
                if _zone.inZone == true and not ME.troopsOnboard(_unit, true) then
                    --     env.error("in zone, loading.. ".._unit:getName())

                    if ME.allowRandomAiTeamPickups == true then
                        -- Random troop pickup implementation
                        local _team = nil
                        if _unit:getCoalition() == 1 then
                            _team = math.floor((math.random(#ME.redTeams * 100) / 100) + 1)
                            ME.loadTroopsFromZone({ _unitName, true, ME.loadableGroups[ME.redTeams[_team]], true })
                        else
                            _team = math.floor((math.random(#ME.blueTeams * 100) / 100) + 1)
                            ME.loadTroopsFromZone({ _unitName, true, ME.loadableGroups[ME.blueTeams[_team]], true })
                        end
                    else
                        ME.loadTroopsFromZone({ _unitName, true, "", true })
                    end
                elseif ME.inDropoffZone(_unit) and ME.troopsOnboard(_unit, true) then
                    --         env.error("in dropoff zone, unloading.. ".._unit:getName())
                    ME.unloadTroops({ _unitName, true })
                end

                if ME.unitCanCarryVehicles(_unit) then
                    if _zone.inZone == true and not ME.troopsOnboard(_unit, false) then
                        ME.loadTroopsFromZone({ _unitName, false, "", true })
                    elseif ME.inDropoffZone(_unit) and ME.troopsOnboard(_unit, false) then
                        ME.unloadTroops({ _unitName, false })
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
function ME.getTransportLimit(_unitType)
    if ME.unitLoadLimits[_unitType] then
        return ME.unitLoadLimits[_unitType]
    end

    return ME.numberOfTroops
end

--- Get unit actions for unit type
--- @param _unitType string unit type
--- @return table unit actions
function ME.getUnitActions(_unitType)
    if ME.unitActions[_unitType] then
        return ME.unitActions[_unitType]
    end

    return { crates = true, troops = true }
end

--- Get distance in meters assuming a Flat world
--- @param _point1 table first point with x and z coordinates
--- @param _point2 table second point with x and z coordinates
--- @return number distance in meters
function ME.getDistance(_point1, _point2)
    local xUnit = _point1.x
    local yUnit = _point1.z
    local xZone = _point2.x
    local yZone = _point2.z

    local xDiff = xUnit - xZone
    local yDiff = yUnit - yZone

    return math.sqrt(xDiff * xDiff + yDiff * yDiff)
end

-----------------[[ END OF utility.lua ]]-----------------
