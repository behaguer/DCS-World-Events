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

-----------------[[ DCS Type Definitions ]]-----------------

---@class Unit DCS Unit object
---@field getByName fun(name: string): Unit|nil
---@field getName fun(self: Unit): string
---@field isActive fun(self: Unit): boolean
---@field getLife fun(self: Unit): number
---@field getPoint fun(self: Unit): table
---@field getPosition fun(self: Unit): table
---@field getCoalition fun(self: Unit): number
---@field getCountry fun(self: Unit): number
---@field getTypeName fun(self: Unit): string
---@field getPlayerName fun(self: Unit): string|nil
---@field getVelocity fun(self: Unit): table
---@field getID fun(self: Unit): number

---@class Group DCS Group object
---@field getByName fun(name: string): Group|nil
---@field getName fun(self: Group): string
---@field isExist fun(self: Group): boolean
---@field getUnits fun(self: Group): Unit[]
---@field getCoalition fun(self: Group): number

---@class Object DCS Object
---@field getName fun(self: Object): string
---@field getPoint fun(self: Object): table
---@field getPosition fun(self: Object): table
---@field isExist fun(self: Object): boolean

---@class StaticObject DCS Static Object
---@field getByName fun(name: string): StaticObject|nil
---@field getName fun(self: StaticObject): string
---@field getPoint fun(self: StaticObject): table
---@field getPosition fun(self: StaticObject): table

---@class Airbase DCS Airbase object
---@field getByName fun(name: string): Airbase|nil
---@field getName fun(self: Airbase): string
---@field getPoint fun(self: Airbase): table
---@field getCoalition fun(self: Airbase): number

---@class GroupTemplate
---@field name string Template name
---@field units table[] Array of unit definitions
---@field total? number Total count of units (set by function if missing)
---@field country? number Country ID
---@field category? number Unit category

-----------------[[ END OF DCS Type Definitions ]]-----------------
