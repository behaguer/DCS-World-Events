-----------------[[ init.lua ]]-----------------

function WE.initialize()
    WE.logInfo(string.format("Initializing version %s", WE.Version))
    
    -- Initialize editor functions state
    WE.initializeEditorFunctions()
    
    -- Initialize radio menu system
    WE.initializeRadioMenu()
    
    WE.logInfo("World Events system initialization complete")
end

-----------------[[ END OF init.lua ]]-----------------
