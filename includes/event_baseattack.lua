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

--- Get all currently airdrome-category airbases (excludes ships/FARPs/helipads)
--- @side 'red' or 'blue'
--- @return table list of Airbase objects
function WE.getAirdromes(side)
    local _airdromes = {}

    if side == nil then
        side = coalition.side.RED
    elseif side == 'red' then
        side = coalition.side.RED
    elseif side == 'blue' then
        side = coalition.side.BLUE
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

    WE.logInfo("BASE_ATTACK: departure=%s (id %s), destination=%s (id %s)", _depName, tostring(_depId), _destName,
        tostring(_destId))

    WE.logInfo("Spawning Base Attack Wing groups...")

    -- Reserve the CAS group's id up front (used as a hint - see the real id capture below)
    local _attackCASGroupId = WE.getNextGroupId()

    -- Operational altitude in meters for the transit/attack waypoint
    local _cruiseAlt = 2000

    -- Base Attack CAS Group ("ShAP" - 3x Su-25, livery/loadout from the exported
    -- shap.stm static template). Route: take off from the departure (red) airfield,
    -- attack the destination (blue) airfield, then land back at the SAME airfield
    -- they took off from.

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
                    ["alt"] = _depPoint.y,
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
                    ["y"] = _depPoint.z,
                    ["x"] = _depPoint.x,
                    ["speed_locked"] = true,
                    ["formation_template"] = "",
                },
                -- WAYPOINT 2: Attack the blue base (target mission - bomb the airfield)
                [2] = {
                    ["alt"] = _cruiseAlt,
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
                                    ["id"] = "Bombing",
                                    ["enabled"] = true,
                                    ["params"] = {
                                        ["point"] = { ["x"] = _destPoint.x, ["y"] = _destPoint.z },
                                        ["x"] = _destPoint.x,
                                        ["y"] = _destPoint.z,
                                        ["groupAttack"] = true,
                                        ["attackQtyLimit"] = false,
                                        ["expend"] = "All",
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
                -- WAYPOINT 3: Land back at the SAME (departure/red) airfield after the
                -- attack. DCS AI will divert to RTB earlier on its own if fuel runs low
                -- before reaching this point, so no extra bingo-fuel scripting is needed.
                [3] = {
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
                ["alt"] = _depPoint.y,
                ["alt_type"] = "BARO",
                ["livery_id"] = "field camo scheme #2 (native). 960th shap",
                ["skill"] = "High",
                ["speed"] = 138.88888888889,
                ["type"] = "Su-25",
                ["unitId"] = WE.getNextUnitId(),
                ["psi"] = 0,
                ["onboard_num"] = "010",
                ["y"] = _depPoint.z,
                ["x"] = _depPoint.x,
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
                ["heading"] = 0,
                ["callsign"] = 103,
            },
            [2] = {
                ["alt"] = _depPoint.y,
                ["alt_type"] = "BARO",
                ["livery_id"] = "field camo scheme #2 (native). 960th shap",
                ["skill"] = "High",
                ["speed"] = 138.88888888889,
                ["type"] = "Su-25",
                ["unitId"] = WE.getNextUnitId(),
                ["psi"] = 0,
                ["onboard_num"] = "011",
                ["y"] = _depPoint.z,
                ["x"] = _depPoint.x,
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
                ["heading"] = 0,
                ["callsign"] = 104,
            },
            [3] = {
                ["alt"] = _depPoint.y,
                ["alt_type"] = "BARO",
                ["livery_id"] = "field camo scheme #2 (native). 960th shap",
                ["skill"] = "High",
                ["speed"] = 138.88888888889,
                ["type"] = "Su-25",
                ["unitId"] = WE.getNextUnitId(),
                ["psi"] = 0,
                ["onboard_num"] = "012",
                ["y"] = _depPoint.z,
                ["x"] = _depPoint.x,
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
                ["heading"] = 0,
                ["callsign"] = 105,
            },
        },
        ["y"] = _depPoint.z,
        ["x"] = _depPoint.x,
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
                    ["y"] = _depPoint.z,
                    ["x"] = _depPoint.x,
                    ["speed_locked"] = true,
                    ["formation_template"] = "",
                },
                -- WAYPOINT 2: 10 NM Rendezvous / Join Point
                [2] = {
                    ["alt"] = _cruiseAlt,
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
                ["heading"] = 0,
                ["callsign"] = 124,
            },
        },
        ["y"] = _depPoint.z,
        ["x"] = _depPoint.x,
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
end

-- Create a table to hold our custom event handler
WE.EVENT.BASEATTACK = {}

-- Define the function that DCS calls every time ANY event happens in the world
function WE.EVENT.BASEATTACK:onEvent(event)
    -- Check if the event has a valid initiator (the unit causing the event)
    if not event.initiator then return end
    
    -- Optimize by getting the unit's name up front
    if event.initiator.getName and type(event.initiator.getName) == "function" then
        local unitName = event.initiator:getName()
        WE.logInfo("Event received: %s, Unit: %s", tostring(event.id), tostring(unitName))
        
        -- TODO: WE need to change this to check for the destruction of the whole CAS group.
        if unitName == "RSD381 VIP" then
        
            -- Scenario 1: Plane is destroyed
            if event.id == world.event.S_EVENT_CRASH then
                trigger.action.outText("SUCCESS: The attacking aircraft have been completely destroyed!", 10)
                -- Add your custom logic for success here ( Award points, trigger next event, etc. )
                
            -- Scenario 2: Attacking Planes lands safely
            elseif event.id == world.event.S_EVENT_LAND then
                trigger.action.outText("INFO: The attacking aircraft have touched down safely.", 5)
                
            -- Scenario 3: Plane shuts down engines after landing
            elseif event.id == world.event.S_EVENT_ENGINE_SHUTDOWN then
                trigger.action.outText("FAILED: The attacking aircraft has landed and shut down engines. Mission Failure!", 10)
                -- Add your custom logic for failure here
            end
            
        end
    else
        WE.logWarning("Event received: %s, but initiator has no valid getName method", tostring(event.id))
    end
end

-- Register the handler with the DCS world engine so it starts listening
world.addEventHandler(WE.EVENT.BASEATTACK)

-----------------[[ END OF event_baseattack.lua ]]-----------------
