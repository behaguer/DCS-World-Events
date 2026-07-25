-----------------[[ event_vipwing.lua ]]-----------------
---
--- VIP Wing event spawning module
--- Spawns a VIP transport with fighter escort when triggered by radio menu
--- Unit data below is taken directly from the exported Vip_Wing static template
--- (red coalition, Russia: "Vip_Transport" C-130J-30 + "Vip_Wing_fighter" 4x MiG-29 Fulcrum)
---

--- Spawn VIP Wing with fighter escort
--- This function spawns two groups: VIP transport aircraft and fighter escort
function WE.EVENT.VIP_ESCORT()
    WE.logInfo("VIP Wing spawn event triggered")

    -- Check if already active
    if WE.is_active == 1 then
        trigger.action.outText("VIP Wing event is already active!", 10)
        WE.logInfo("VIP Wing spawn cancelled - event already active")
        return
    end

    WE.logInfo("Spawning VIP Wing groups...")

    -- VIP Transport Group (from static template group "Vip_Transport")
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
                    ["alt"] = 4572,
                    ["action"] = "Turning Point",
                    ["alt_type"] = "BARO",
                    ["speed"] = 154.16666666667,
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
                    ["type"] = "Turning Point",
                    ["ETA"] = 0,
                    ["ETA_locked"] = true,
                    ["y"] = 26485.503976522,
                    ["x"] = 13241.662677759,
                    ["speed_locked"] = true,
                    ["formation_template"] = "",
                },
            },
        },
        ["units"] = {
            [1] = {
                ["alt"] = 4572,
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
                ["y"] = 26485.503976522,
                ["x"] = 13241.662677759,
                ["name"] = "Aerial-2-2",
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
        ["y"] = 26485.503976522,
        ["x"] = 13241.662677759,
        ["name"] = "Vip_Transport",
        ["communication"] = true,
        ["start_time"] = 0,
        ["groupId"] = WE.getNextGroupId(),
        ["frequency"] = 305,
    }

    -- VIP Fighter Escort Group (from static template group "Vip_Wing_fighter")
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
                [1] = {
                    ["alt"] = 4572,
                    ["action"] = "Turning Point",
                    ["alt_type"] = "BARO",
                    ["speed"] = 220.97222222222,
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
                                                ["name"] = 17,
                                            },
                                        },
                                    },
                                },
                                [2] = {
                                    ["number"] = 2,
                                    ["auto"] = true,
                                    ["id"] = "WrappedAction",
                                    ["enabled"] = true,
                                    ["params"] = {
                                        ["action"] = {
                                            ["id"] = "Option",
                                            ["params"] = {
                                                ["value"] = 4,
                                                ["name"] = 18,
                                            },
                                        },
                                    },
                                },
                                [3] = {
                                    ["number"] = 3,
                                    ["auto"] = true,
                                    ["id"] = "WrappedAction",
                                    ["enabled"] = true,
                                    ["params"] = {
                                        ["action"] = {
                                            ["id"] = "Option",
                                            ["params"] = {
                                                ["value"] = true,
                                                ["name"] = 19,
                                            },
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
                                            ["params"] = {
                                                ["targetTypes"] = {},
                                                ["name"] = 21,
                                                ["value"] = "none;",
                                                ["noTargetTypes"] = {
                                                    [1] = "Fighters",
                                                    [2] = "Multirole fighters",
                                                    [3] = "Bombers",
                                                    [4] = "Helicopters",
                                                    [5] = "UAVs",
                                                    [6] = "Infantry",
                                                    [7] = "Fortifications",
                                                    [8] = "Tanks",
                                                    [9] = "IFV",
                                                    [10] = "APC",
                                                    [11] = "Artillery",
                                                    [12] = "Unarmed vehicles",
                                                    [13] = "AAA",
                                                    [14] = "SR SAM",
                                                    [15] = "MR SAM",
                                                    [16] = "LR SAM",
                                                    [17] = "Aircraft Carriers",
                                                    [18] = "Cruisers",
                                                    [19] = "Destroyers",
                                                    [20] = "Frigates",
                                                    [21] = "Corvettes",
                                                    [22] = "Light armed ships",
                                                    [23] = "Unarmed ships",
                                                    [24] = "Submarines",
                                                    [25] = "Cruise missiles",
                                                    [26] = "Antiship Missiles",
                                                    [27] = "AA Missiles",
                                                    [28] = "AG Missiles",
                                                    [29] = "SA Missiles",
                                                },
                                            },
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
                    ["type"] = "Turning Point",
                    ["ETA"] = 0,
                    ["ETA_locked"] = true,
                    ["y"] = 26589.647053231,
                    ["x"] = 13128.434149097,
                    ["speed_locked"] = true,
                    ["formation_template"] = "",
                },
            },
        },
        ["units"] = {
            [1] = {
                ["alt"] = 4572,
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
                ["y"] = 26589.647053231,
                ["x"] = 13128.434149097,
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
                ["alt"] = 4572,
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
                ["y"] = 26629.647053231,
                ["x"] = 13088.434149097,
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
                ["alt"] = 4572,
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
                ["y"] = 26669.647053231,
                ["x"] = 13048.434149097,
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
                ["alt"] = 4572,
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
                ["y"] = 26709.647053231,
                ["x"] = 13008.434149097,
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
        ["y"] = 26589.647053231,
        ["x"] = 13128.434149097,
        ["name"] = "Vip_Wing_fighter",
        ["communication"] = true,
        ["start_time"] = 0,
        ["groupId"] = WE.getNextGroupId(),
        ["frequency"] = 124,
    }

    -- Spawn the VIP transport group (fixed-wing, so use AIRPLANE category, not HELICOPTER)
    local transportGroupId = coalition.addGroup(country.id.RUSSIA, Group.Category.AIRPLANE, vipTransportGroup)
    if transportGroupId then
        WE.logInfo("VIP Transport group spawned successfully with group ID: %s", tostring(transportGroupId))
        trigger.action.outText("VIP Transport aircraft has been dispatched!", 10)
    else
        WE.logError("Failed to spawn VIP Transport group")
        trigger.action.outText("Failed to spawn VIP Transport aircraft", 10)
        return
    end

    -- Spawn the fighter escort group
    local fighterGroupId = coalition.addGroup(country.id.RUSSIA, Group.Category.AIRPLANE, vipFighterGroup)
    if fighterGroupId then
        WE.logInfo("VIP Fighter Escort group spawned successfully with group ID: %s", tostring(fighterGroupId))
        trigger.action.outText("VIP Fighter Escort is airborne!", 10)
    else
        WE.logError("Failed to spawn VIP Fighter Escort group")
        trigger.action.outText("Failed to spawn VIP Fighter Escort", 10)
    end

    -- Mark event as active
    WE.is_active = 1
    WE.logInfo("VIP Wing event completed successfully - Transport ID: %s, Escort ID: %s",
        tostring(transportGroupId), tostring(fighterGroupId))

    trigger.action.outText("VIP Wing mission is now active! Protect the VIP transport.", 15)
end

-----------------[[ END OF event_vipwing.lua ]]-----------------