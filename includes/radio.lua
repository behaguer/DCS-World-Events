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
    
    -- Add submenu items for this group
    WE.radioMenu[groupId].spawnEventMenu = missionCommands.addCommandForGroup(groupId, "Spawn Event", WE.radioMenu[groupId].mainMenu, WE.spawnEventMenuAction)
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
        WE.radioMenu.spawnEventMenu = missionCommands.addCommand("Spawn Event", WE.radioMenu.mainMenu, WE.spawnEventMenuAction)
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
