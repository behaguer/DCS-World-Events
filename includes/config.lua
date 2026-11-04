-----------------[[ config.lua ]]-----------------

------------------- To add debugging messages to dcs.log, change the following log levels to `true`; `Debug` is less detailed than `Trace`
WE.Debug = true
WE.Trace = true
WE.RadioUsers = { -- starting names of airframes that can access the radio menu
    [1] = "[Commander]",
    [2] = "[Patreon]",
    -- [3] = "All"
}
WE.EnabledEvents = {
    ["VIP_ESCORT"] = true,
    ["BASE_ATTACK"] = true,
    ["STRONGHOLD"] = true,
    ["CONVOY"] = true,
    ["IADS"] = true,
}
-- Controls the order events appear in the "Spawn Event" radio submenu.
-- Any event not listed here still works, it's just appended at the end.
WE.EventOrder = {
    "VIP_ESCORT",
    "BASE_ATTACK",
    "STRONGHOLD",
    "CONVOY",
    "IADS",
}
-- Automatic event scheduling. When enabled, a random event from
-- WE.EnabledEvents spawns every interval, but only while no event is already
-- active. Intervals below 10 minutes are clamped. Leave disabled to keep
-- spawning fully manual via the radio menu.
WE.AutoRunEnabled = false
WE.AutoRunIntervalMinutes = 30

-----------------[[ END OF config.lua ]]-----------------
