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
