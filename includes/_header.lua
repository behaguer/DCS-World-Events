--[[ 
        DCS-WORLD-Events - Dynamic world events for DCS World

        Allows the addition of dynamic world events to your mission. 
        These events can be accessed through the radio menu item World Event. 
        They can be triggered manually by users with access to the radio item or they can be set to randomly spawn. 
        Only one event can be active at a time and events will have a timer. 
        The world event has its own state management and doesn't rely on any external scripts, just plug the script into your mission and go.

]]

WE = {}

--- Identifier. All output in DCS.log will start with this.
WE.Id = "World Event - "

--- Version.
WE.Version = "0.0.1"

