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
    
    -- Check if an event is already active
    if WE.is_active == 1 then
        trigger.action.outText("A World Event is already active! Check Event Status for details.", 10)
        return
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
        if WE.currentStrongholdEvent then
            local _remaining = math.max(0, math.ceil(WE.currentStrongholdEvent.endsAt - timer.getTime()))
            statusMessage = statusMessage .. string.format("\n\nStronghold: located near %s, %d seconds remaining.",
                tostring(WE.currentStrongholdEvent.area), _remaining)
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
