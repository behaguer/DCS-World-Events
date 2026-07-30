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
                    ["alt"] = _depPoint.y,
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
                    ["y"] = _depPoint.z,
                    ["x"] = _depPoint.x,
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
                ["alt"] = _depPoint.y,
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
                ["psi"] = 0,
                ["onboard_num"] = "014",
                ["y"] = _depPoint.z,
                ["x"] = _depPoint.x,
                ["name"] = "RSD381 VIP",
                ["payload"] = {
                    ["pylons"] = {},
                    ["fuel"] = 15753.6,
                    ["flare"] = 200,
                    ["chaff"] = 220,
                    ["gun"] = 100,
                },
                ["heading"] = 0,
                ["callsign"] = 126,
            },
        },
        ["y"] = _depPoint.z,
        ["x"] = _depPoint.x,
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
                    ["alt"] = _depPoint.y,
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
                    ["y"] = _depPoint.z,
                    ["x"] = _depPoint.x,
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
                ["alt"] = _depPoint.y,
                ["alt_type"] = "BARO",
                ["livery_id"] = "rf standard grey",
                ["skill"] = "Excellent",
                ["speed"] = 220.97222222222,
                ["AddPropAircraft"] = {
                    ["NS430allow"] = true,
                },
                ["type"] = "MiG-29 Fulcrum",
                ["unitId"] = WE.getNextUnitId(),
                ["psi"] = 0,
                ["onboard_num"] = "010",
                ["y"] = _depPoint.z,
                ["x"] = _depPoint.x,
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
                ["heading"] = 0,
                ["callsign"] = 121,
            },
            [2] = {
                ["alt"] = _depPoint.y,
                ["alt_type"] = "BARO",
                ["livery_id"] = "rf standard grey",
                ["skill"] = "High",
                ["speed"] = 220.97222222222,
                ["AddPropAircraft"] = {
                    ["NS430allow"] = true,
                },
                ["type"] = "MiG-29 Fulcrum",
                ["unitId"] = WE.getNextUnitId(),
                ["psi"] = 0,
                ["onboard_num"] = "011",
                ["y"] = _depPoint.z,
                ["x"] = _depPoint.x,
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
                ["heading"] = 0,
                ["callsign"] = 122,
            },
            [3] = {
                ["alt"] = _depPoint.y,
                ["alt_type"] = "BARO",
                ["livery_id"] = "rf standard grey",
                ["skill"] = "High",
                ["speed"] = 220.97222222222,
                ["AddPropAircraft"] = {
                    ["NS430allow"] = true,
                },
                ["type"] = "MiG-29 Fulcrum",
                ["unitId"] = WE.getNextUnitId(),
                ["psi"] = 0,
                ["onboard_num"] = "012",
                ["y"] = _depPoint.z,
                ["x"] = _depPoint.x,
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
                ["heading"] = 0,
                ["callsign"] = 123,
            },
            [4] = {
                ["alt"] = _depPoint.y,
                ["alt_type"] = "BARO",
                ["livery_id"] = "rf standard grey",
                ["skill"] = "High",
                ["speed"] = 220.97222222222,
                ["AddPropAircraft"] = {
                    ["NS430allow"] = true,
                },
                ["type"] = "MiG-29 Fulcrum",
                ["unitId"] = WE.getNextUnitId(),
                ["psi"] = 0,
                ["onboard_num"] = "013",
                ["y"] = _depPoint.z,
                ["x"] = _depPoint.x,
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
                ["heading"] = 0,
                ["callsign"] = 124,
            },
        },
        ["y"] = _depPoint.z,
        ["x"] = _depPoint.x,
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
                
            -- Scenario 2: Plane lands safely
            elseif event.id == world.event.S_EVENT_LAND then
                trigger.action.outText("INFO: The target aircraft has touched down safely get to him before he finishes taxiing!", 5)
                
            -- Scenario 3: Plane shuts down engines after landing
            elseif event.id == world.event.S_EVENT_ENGINE_SHUTDOWN then
                trigger.action.outText("FAILED: The aircraft has landed and shut down engines. Mission Falure!", 10)
                -- Add your custom logic for failure here
            end
            
        end
    else
        WE.logWarning("Event received: %s, but initiator has no valid getName method", tostring(event.id))
    end
end

-- Register the handler with the DCS world engine so it starts listening
world.addEventHandler(WE.EVENT.VIPWING)

-----------------[[ END OF event_vipwing.lua ]]-----------------
