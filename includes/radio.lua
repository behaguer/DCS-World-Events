-----------------[[ radio.lua ]]-----------------

--- Radio menu references for World Events
WE.radioMenu = {}
WE.radioMenu.mainMenu = nil
WE.radioMenu.spawnEventMenu = nil
WE.radioMenu.eventStatusMenu = nil

--- Initialize the radio menu system for World Events
function WE.initializeRadioMenu()
    WE.logInfo("Initializing World Events radio menu system")
    
    -- Create main WorldEvents menu
    WE.radioMenu.mainMenu = missionCommands.addSubMenu("WorldEvents")
    
    -- Add submenu items
    WE.radioMenu.spawnEventMenu = missionCommands.addCommand("Spawn Event", WE.radioMenu.mainMenu, WE.spawnEventMenuAction)
    WE.radioMenu.eventStatusMenu = missionCommands.addCommand("Event Status", WE.radioMenu.mainMenu, WE.showEventStatusAction)
    
    WE.logInfo("World Events radio menu initialized successfully")
end

--- Action for Spawn Event menu option
function WE.spawnEventMenuAction()
    WE.logInfo("Spawn Event menu action triggered")
    
    -- Check if an event is already active
    if WE.is_active == 1 then
        trigger.action.outText("A World Event is already active! Check Event Status for details.", 10)
        return
    end
    
    -- For now, this is a placeholder - you would implement actual event spawning logic here
    WE.is_active = 1
    trigger.action.outText("World Event spawned! Use Event Status to check details.", 10)
    WE.logInfo("World Event spawned via radio menu")
end

--- Action for Event Status menu option
function WE.showEventStatusAction()
    WE.logInfo("Event Status menu action triggered")
    
    local statusMessage = ""
    if WE.is_active == 1 then
        statusMessage = "World Event Status: ACTIVE\n\nAn event is currently running. Check the F10 map for event details."
    else
        statusMessage = "World Event Status: INACTIVE\n\nNo events are currently active. Use 'Spawn Event' to start a new event."
    end
    
    trigger.action.outText(statusMessage, 15)
    WE.logInfo("Event status displayed via radio menu")
end

--- Remove all World Events radio menus (cleanup function)
function WE.removeRadioMenu()
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
    
    WE.logInfo("World Events radio menu removed")
end

-----------------[[ END OF radio.lua ]]-----------------
