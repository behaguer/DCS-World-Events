-----------------[[ event.lua ]]-----------------

--- Event handling system for World Events
WE.eventHandlers = {}

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
        if event.initiator then
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

-----------------[[ END OF event.lua ]]-----------------