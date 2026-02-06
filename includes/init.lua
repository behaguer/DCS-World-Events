-----------------[[ init.lua ]]-----------------

function WE.initialize()
    WE.logInfo(string.format("Initializing version %s", WE.Version))
    
    -- Initialize radio menu system
    WE.initializeRadioMenu()
    
    -- Initialize event handling system
    WE.initializeEvents()
    
    WE.logInfo("World Events system initialization complete")
end


WE.initialize(); -- Go Time!

-----------------[[ END OF init.lua ]]-----------------
