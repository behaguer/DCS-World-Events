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
