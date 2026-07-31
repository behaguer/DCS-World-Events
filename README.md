
# DCS-WORLD-EVENTS By BS MYTH

A single drop-in Lua script (`WorldEvents.lua`) that adds dynamic, on-demand
"world events" to a DCS World mission, events are triggered by players through the F10
radio menu. No external scripts or frameworks are required.

## Contents
- [Overview](#overview)
- [Installation](#installation)
- [Script structure](#script-structure)
- [Configuration](#configuration)
- [Radio menu](#radio-menu)
- [Events](#events)
  - [VIP Escort](#vip-escort-weeventvip_escort)
  - [Base Attack](#base-attack-weeventbase_attack)
- [Event status tracking](#event-status-tracking)
- [Logging](#logging)
- [Included but currently inactive: troop transport & FOB crates](#included-but-currently-inactive-troop-transport--fob-crates)
- [Known limitations / TODO](#known-limitations--todo)

---

## Overview

Players (or specific "radio user" groups, per config) get a **WorldEvents**
radio menu item. From it they can:

- **Spawn Event** — pick from whichever events are currently enabled, e.g.
  *VIP Escort* or *Base Attack*.
- **Event Status** — check whether an event is currently running, and get
  its departure/destination airfields.

Only one event can be active at a time (`WE.is_active`), and each event
picks its own airfields at random from whatever's actually on the loaded
map/mission, so the same script works unmodified across different theatres.

## Installation

1. Add a `DO SCRIPT FILE` (or `DO SCRIPT`) trigger action pointing at
   `WorldEvents.lua`, on a `MISSION START` trigger (once).
2. Add the sounds for the events you want to use. (see example missions for examples)
2. That's it — `WE.initialize()` runs automatically at the bottom of the
   file and sets up the radio menu and event handlers.

## Script structure

The file is one script but organized into clearly-delimited sections
(look for `-----------------[[ name.lua ]]-----------------` markers):

| Section | Contents |
|---|---|
| `types.lua` | LuaCATS-style `---@class` annotations for DCS's `Unit`, `Group`, `Airbase`, etc., for editor autocomplete/type-checking only — no runtime code. |
| `config.lua` | All user-tunable settings — see [Configuration](#configuration). |
| `state.lua` | Runtime state: ID counters, `WE.is_active`, event/handler registries. |
| `utility.lua` | A large general-purpose helper library — logging, distance/geometry math, and a troop-transport/FOB-crate cargo system (see [below](#included-but-currently-inactive-troop-transport--fob-crates); this part is **not currently wired up**). |
| `radio.lua` | Builds and tears down the F10 `WorldEvents` menu, access control, and the `Spawn Event` / `Event Status` actions. |
| `event.lua` | Generic event-handling scaffolding: reacts to players entering/leaving units to (re)build their radio menu, plus `WE.addEvent`/`WE.removeEvent` bookkeeping stubs. |
| `event_vipwing.lua` | The **VIP Escort** event. |
| `event_baseattack.lua` | The **Base Attack** event. |
| `init.lua` | Calls `WE.initialize()`, which starts the radio menu and event system. This is the only code that runs unconditionally at load. |

---

## Configuration

Everything you're likely to want to tune lives at the top, in `config.lua`
and the top of each event's own section:

```lua
-- config.lua
WE.Debug = true   -- verbose "D" log lines in dcs.log
WE.Trace = true   -- even more verbose "T" log lines

WE.RadioUsers = {              -- group-name substrings allowed to see the menu
    [1] = "Player",
    [2] = "[Patreon]",
    -- [3] = "All"             -- uncomment for "everyone gets the menu"
}

WE.EnabledEvents = {            -- master on/off switch per event
    ["VIP_ESCORT"] = true,
    ["BASE_ATTACK"] = true,
}

WE.EventOrder = {               -- display order in the "Spawn Event" submenu;
    "VIP_ESCORT",               -- anything enabled-but-not-listed is appended
    "BASE_ATTACK",               -- at the end automatically
}
```

```lua
-- event_vipwing.lua
WE.VIPCountry = country.id.RUSSIA          -- country VIP Escort spawns under
WE.VIPEscortEngagementDistMax = 60000      -- meters the escort will break off to engage an air threat

-- event_baseattack.lua
WE.AttackerCountry = country.id.RUSSIA     -- country Base Attack spawns under
WE.EscortEngagementDistMax = 60000         -- same idea, for the Base Attack escort
```

`WE.RadioUsers` works as a substring match against each player's **group
name** (not their in-game player name) — a group named `Player-1-Viper`
would match the `"Player"` entry, for example. Add `"All"` (any case) to
give every group the menu regardless of name.

---

## Radio menu

The menu is built per-player-group (`WE.initializePlayerRadioMenu`), and is
rebuilt automatically whenever a player enters or spawns into a unit
(`S_EVENT_PLAYER_ENTER_UNIT` / `S_EVENT_BIRTH`) and torn down when they
leave (`S_EVENT_PLAYER_LEAVE_UNIT`) — handled centrally in `event.lua`'s
`WE.onPlayerEvent`. If `"All"` is set in `WE.RadioUsers`, a single global
menu is built once instead of per-group (`WE.initializeRadioMenu`).

Menu layout:

```
WorldEvents
├── Spawn Event
│   ├── VIP ESCORT      (only shown if WE.EnabledEvents["VIP_ESCORT"] == true)
│   └── BASE ATTACK     (only shown if WE.EnabledEvents["BASE_ATTACK"] == true)
└── Event Status
```

`Spawn Event` is generated dynamically from config — `WE.getEnabledEventNames()`
returns the enabled events in `WE.EventOrder`, `WE.getEventDisplayName()`
turns each key into a readable label (`BASE_ATTACK` → `BASE ATTACK`), and one
radio command per event is created, each passing its event name through to
the shared handler:

```lua
function WE.spawnEventMenuAction(_eventName)
    if WE.is_active == 1 then ... return end
    if not WE.EnabledEvents[_eventName] then ... return end
    if not WE.EVENT[_eventName] then ... return end
    WE.EVENT[_eventName]()
end
```

**To add a new event to the menu:** implement `WE.EVENT.YOUR_EVENT()`
somewhere in the file, then add `"YOUR_EVENT"` to both `WE.EnabledEvents`
and `WE.EventOrder`. No other radio menu code needs to change.

---

## Events

Both events follow the same overall pattern: pick real airfields from the
currently loaded map/mission (so nothing is hardcoded to a specific
theatre), spawn a main group plus a fighter escort, and hand the escort a
DCS `Escort` task so it stays with the main group and engages air threats.

### VIP Escort (`WE.EVENT.VIP_ESCORT`)

Spawns a VIP transport flight with a 4-ship fighter escort, flying from one
random red-controlled airfield to another.

- **Airfields** — `WE.getRedAirdromes()` collects every currently
  red-owned, `Airbase.Category.AIRDROME` base (via `coalition.getAirbases`,
  so ownership changes in a dynamic campaign are respected; ships/FARPs/
  helipads are excluded since the transport can't use them).
  `WE.pickVIPAirfields()` picks two different ones. If fewer than two red
  airdromes exist, the event cancels cleanly instead of erroring.
- **Route**: Takeoff (`From Runway`) → a 10 NM rendezvous point along the
  line between departure and destination (so the escort actually joins up
  with the transport instead of racing ahead of it) → Landing at the
  destination.
- **Escort**: 4x MiG-29 Fulcrum, tasked with DCS's `Escort` task pointed at
  the transport's *actual* spawned group ID (captured from the `Group`
  object returned by `coalition.addGroup`, not a pre-guessed one — DCS will
  silently reassign a requested ID if it collides with another group
  already in the mission, so the real one has to be read back after
  spawning). Station-keeping offset is set via the task's `pos` field
  (behind and to the side of the transport), and `engagementDistMax`
  (`WE.VIPEscortEngagementDistMax`) controls how far they'll break off to
  fight an air threat before returning to escort.
- On spawn, all players get a text naming both airfields so they know where
  to look.

### Base Attack (`WE.EVENT.BASE_ATTACK`)

Spawns an enemy CAS strike package ("ShAP") that takes off from a red
airfield, bombs a random blue airfield, and returns to base.

- **Airfields** — `WE.getAirdromes(side)` is the same idea as VIP Escort's
  airfield helper, but parameterized by coalition side. `WE.pickAirfields()`
  picks a **red** departure airfield and a **blue** destination (the
  target), each independently at random.
- **Units** — 3x Su-25 ("ShAP"), livery and loadout taken from an exported
  static template (`shap.stm`).
- **Route**: Takeoff from the red departure airfield (carrying the group's
  enroute tasking — engage helicopters/ground units/light armed ships, ROE
  Open Fire, Reaction to Threat Evade Fire) → transit to the destination at a
  terrain-safe cruise altitude (`_safeCruiseAlt`, sampled from the highest of
  5 ground heights along the leg) → descend to a low attack altitude
  (`_attackAlt`, ~500 m AGL over the airfield) and run an
  `EngageTargetsInZone` task (10 km radius, ground-unit target types only) →
  Land back at the **same** airfield they departed from. DCS's own AI already
  diverts to RTB on low fuel before reaching the final waypoint if needed, so
  no separate bingo-fuel logic was required.
- **Escort**: 4x MiG-29 Fulcrum, using the same real-group-ID-after-spawn
  and `pos`-offset `Escort` task pattern as VIP Escort, attached to the CAS
  group instead of a transport.
- On spawn, all players get a text naming both airfields.

---

## Event status tracking

Each event records its own state on spawn:

```lua
WE.currentVIPEvent = { departure = ..., destination = ..., transportGroupId = ..., fighterGroupId = ... }
WE.currentBaseAttackEvent = { departure = ..., destination = ..., attackCASGroupGroupId = ..., fighterGroupId = ... }
```

`WE.showEventStatusAction` (the `Event Status` radio item) reports whether
`WE.is_active` is set, and currently also prints `WE.currentVIPEvent`'s
departure/destination if present.

There's also a per-event `world.addEventHandler` (`WE.EVENT.VIPWING`,
`WE.EVENT.BASEATTACK`) intended to report mission success/failure based on
whether the spawned aircraft are shot down, land safely, or shut down
engines.

---

## Logging

Everything logs through `WE.logError` / `WE.logWarning` / `WE.logInfo` /
`WE.logDebug` / `WE.logTrace` to `dcs.log`, each prefixed with `WE.Id`
(`"World Event - "`) and a severity marker (`E`/`W`/`I`/`D`/`T`). `WE.Debug`
and `WE.Trace` in config gate the two most verbose levels — turn both off
for a quieter log in a live/production mission.

---

## Included but currently inactive: troop transport & FOB crates

`utility.lua` contains a substantial helicopter troop-transport and FOB
(forward operating base) resupply system: loading/unloading troops or
vehicles from helicopters at pickup/dropoff zones, extracting dropped
troops, delivering FOB crates, generating troop loadouts by role (AA, MG,
AT, mortar, JTAC), and an AI auto-load/unload loop (`WE.checkAIStatus`).

**This subsystem is not currently active.** It depends on a number of
globals — `WE.extractZones`, `WE.inPickupZone`/`WE.inDropoffZone`/
`WE.inLogisticsZone`, `WE.droppedTroopsRED`/`BLUE`,
`WE.vehiclesForTransportRED`/`BLUE`, `WE.transportPilotNames`,
`WE.maxExtractDistance`, `WE.numberOfTroops`, `WE.SOLDIER_WEIGHT`, etc. —
that are referenced throughout but **never defined anywhere in this file**,
and its scheduler (`WE.checkAIStatus`) is never started from
`WE.initialize()`. It looks like leftover/imported groundwork from a
separate troop-transport script rather than something built for the current
VIP Escort / Base Attack events. If you want to use it, you'll need to
define those zone/config globals and kick off `WE.checkAIStatus()`
yourself; otherwise it's safe to ignore (or delete) for now.

---

## Known limitations / TODO

- **Shared `is_active` flag.** Both events use the same `WE.is_active`, so
  by design only one world event (of either type) can run at a time.
- **Troop transport / FOB crate system** — see the section above; present
  in the file but not wired up.