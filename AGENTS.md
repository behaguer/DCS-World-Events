# DCS-World-Events — Codebase Summary (Agent Context)

> Purpose: fast, accurate orientation for future work. This project is a **DCS World**
> multiplayer mission scripting framework. Game only loads **one compiled Lua file**
> (`WorldEvents.lua`); development happens in split modules under `includes/` and is
> reassembled by a PowerShell compiler (`build.ps1` / `extract.ps1`).

---

## 1. Project at a glance

- **Name:** DCS-WORLD-EVENTS by BS MYTH
- **Version:** `0.1.0` (see `changelog.md`; header defines `WE.Version`)
- **Language/runtime:** Lua 5.1 (DCS embedded Lua)
- **Entry point (source):** `includes/init.lua` → calls `WE.initialize()` at file bottom
- **Entry point (game):** compiled `WorldEvents.lua`, loaded once via `MISSION START` → `DO SCRIPT FILE`
- **What it does:** Adds on-demand "world events" that players trigger from the F10 radio menu.
  Events spawn AI flights/ground forces dynamically using the currently loaded map's airfields
  and terrain. No external scripts/frameworks required.
- **Design goals:** modular events, dynamic map-agnostic spawning, single-file deployment,
  per-group radio access control, in-file state tracking, no hardcoded theatre data.

### Repository layout

```
build.ps1                 PowerShell compiler: includes/ -> WorldEvents.lua
extract.ps1               PowerShell splitter: WorldEvents.lua -> includes/
includes/                 Source modules (authoritative code)
  _header.lua             Global WE table, Id, Version, WE.EVENT registry
  types.lua               LuaCATS DCS type annotations (no runtime code)
  config.lua              User-tunable settings + enabled events/order
  state.lua               Runtime counters + event registries
  utility.lua             Logging + math/geometry + shared ground/terrain spawn helpers + legacy cargo subsystem
  radio.lua               F10 menu construction + spawn/status actions + status-provider registry
  event.lua               Player join/leave menu lifecycle + event bookkeeping stubs
  event_vipwing.lua       VIP Escort event + handler
  event_baseattack.lua    Base Attack event + handler
  event_stronghold.lua    Stronghold event + handler
  init.lua                WE.initialize() + unconditional startup
  _compiler_registry.txt  Exact concatenation order for build.ps1
WorldEvents.lua           Compiled/generated output (do not hand-edit; regenerate)
assets/                   .ogg alert sounds + PNG
sample-missions/          Example .miz missions (Caucasus, Marianas, Syria)
SITUATION_BRIEFING.md     Player-facing briefing (keep in sync with behavior)
README.md                 Human documentation
changelog.md              Version history
EVENT_DESIGN.md           Implementation backlog for planned events (read before adding one)
.luarc.json / .vscode/    LuaLS config (Lua 5.1, DCS globals, types.lua library)
```

### Source delimiters (critical)

Every include file must be wrapped **exactly** like this (case/spacing matters to extract.ps1):

```lua
-----------------[[ filename.lua ]]-----------------
...content...
-----------------[[ END OF filename.lua ]]-----------------
```

`_header.lua` has no delimiters; extract.ps1 saves everything before the first start
delimiter as `_header.lua`.

---

## 2. Build / extract workflow

### Build (normal edit → deploy)

```powershell
.\build.ps1 -InputFilePath "WorldEvents.lua"
# or run without args to be prompted
```

- Reads `includes\_compiler_registry.txt` (one filename per line) for order.
- Concatenates the raw contents (delimiters included) into the output file named after
  `-InputFilePath` (default `WorldEvents.lua`) in the repo root.
- `_header.lua` is processed first if it is the first registry entry.
- Missing files are skipped with a warning; registry must exist.
- **The compiled `WorldEvents.lua` is generated output.** Edit `includes/*.lua`, then rebuild.

### Extract (compiled file → modules)

```powershell
.\extract.ps1 -InputFilePath "WorldEvents.lua"
```

- Splits by the start/end delimiters above.
- Writes each block to `includes\<filename>.lua` (including delimiters).
- Writes content before the first block to `includes\_header.lua`.
- Rewrites `includes\_compiler_registry.txt` in encounter order (header forced first).
- Useful when importing/merging changes made directly in the large file.

### Registry order (current)

```
_header.lua
types.lua
config.lua
state.lua
utility.lua
radio.lua
event.lua
event_vipwing.lua
event_baseattack.lua
event_stronghold.lua
init.lua
```

> Order matters. `_header.lua` must define `WE` first. `init.lua` must stay last because it
> calls `WE.initialize()` immediately.

### Adding a new event module (required steps)

1. Create `includes/event_<name>.lua` using the delimiter wrapper.
2. Add the filename to `includes/_compiler_registry.txt` **before `init.lua`**.
3. Add the event key to `WE.EnabledEvents` and `WE.EventOrder` in `includes/config.lua`.
4. Define `WE.EVENT.<KEY>()` (the spawn function).
5. Optionally define a handler table + `world.addEventHandler(...)` for win/lose detection.
6. Register a status provider with `WE.registerEventStatus("<KEY>", provider)` if the event
   should report status (no need to edit `WE.showEventStatusAction`).
7. Rebuild with `build.ps1`.
8. The radio menu auto-generates from config — no menu code changes needed.

**Naming convention:** event module files are prefixed `event_`, e.g. `event_convoy.lua`.
Event keys are uppercase snake case, e.g. `"CONVOY"`; radio label is derived by
replacing `_` with spaces.

---

## 3. Runtime architecture

### Globals created at load

`_header.lua`:

```lua
WE = {}
WE.Id = "World Event - "
WE.Version = "0.1.0"
WE.EVENT = {}   -- event key -> spawn function (and some handler tables)
```

### Startup

`init.lua` end:

```lua
WE.initialize()
```

`WE.initialize()`:
1. `WE.initializeRadioMenu()` — global or per-group F10 menu.
2. `WE.initializeEvents()` — registers `WE.playerEventHandler` for player enter/birth/leave.

Additionally, each event module calls `world.addEventHandler(...)` **at file load time**,
so all event handlers are registered regardless of `WE.initialize()`.

### Public API surface (most-used `WE` members)

| Member | Purpose |
|---|---|
| `WE.logError/Warning/Info/Debug/Trace` | Log to `dcs.log` with `WE.Id` + severity marker; Debug/Trace gated by config |
| `WE.getAirdromes(side)` | Airdrome-category airbases for `'red'`, `'blue'`, `'neutral'` (or coalition number); excludes ships/FARPs/helipads |
| `WE.getTakeoffPoint(airbase)` | Runway-aligned takeoff `{x,z,y,heading}`; falls back to airbase point |
| `WE.getMaxTerrainHeight(x1,z1,x2,z2,n)` | Max terrain height along a line (safe cruise altitude) |
| `WE.getDistance(p1,p2)` | Flat x/z distance |
| `WE.getNextUnitId()` / `WE.getNextGroupId()` / `WE.getNextMarkId()` | Monotonic ID generators from state; mark IDs are negative |
| `WE.getEnabledEventNames()` | Enabled events in `WE.EventOrder` order, extras appended |
| `WE.getEventDisplayName(key)` | `"BASE_ATTACK"` → `"BASE ATTACK"` |
| `WE.spawnEventMenuAction(name)` | Shared radio action: validates, calls `WE.EVENT[name]()` |
| `WE.showEventStatusAction()` | Radio "Event Status" report; calls registered providers |
| `WE.registerEventStatus(key, provider)` | Register an event-specific status text function |
| `WE.hasRadioAccess(groupName)` | Substring match against `WE.RadioUsers`; `"All"` grants everyone |
| `WE.addEvent` / `WE.removeEvent` | Bookkeeping stubs over `WE.events` (not central to spawning) |

Shared ground/terrain helpers in `utility.lua` (available to every event module):
`WE.isPointOnLand`, `WE.isPointFlat`, `WE.randomLandPoint`, `WE.randomLandOffsetNear`,
`WE.getRunwaySegments`, `WE.minDistanceToRunway`, `WE.distanceToSegmentXY`,
`WE.buildStationaryGroundGroup`, `WE.buildGroundUnit`, `WE.areAllUnitsDead`,
`WE.countUnitsInRadius`, `WE.destroyGroupList`.

Other geometry helpers in `utility.lua`: `getPointAt12Oclock`, `getPointAt6Oclock`,
`getPointAtDirection`, `getRelativePoint`, `getCentroid`, `countTableEntries`,
`findNearestEnemy`/`findNearestGroup` (used only by legacy cargo code), etc.

### Radio menu

- **Access:** `WE.RadioUsers` entries are matched case-insensitively as plain substrings
  against the player group's **group name** (not player name). `"All"` anywhere grants all.
- **Per-group mode:** `initializeRadioMenu()` scans plane/heli groups with a player unit and
  builds a menu per group. Menus are rebuilt on `S_EVENT_PLAYER_ENTER_UNIT` and
  `S_EVENT_BIRTH` (1s/2s delayed) and removed on `S_EVENT_PLAYER_LEAVE_UNIT`
  (`event.lua`).
- **Global mode:** if `"All"` is present, a single global menu is built once via
  `missionCommands.addSubMenu`/`addCommand`.
- **Layout:**
  ```
  WorldEvents
  ├── Spawn Event
  │   ├── <enabled event display names, in WE.EventOrder>
  └── Event Status
  ```
- `spawnEventMenuAction` enforces the single-active-event gate (`WE.is_active == 1`)
  except when the requested event is `STRONGHOLD` and `WE.StrongholdAllowMultiple` is true.
  It also plays `trigger.action.outSound("vip-enroute.wav")` after any event spawns.
  > Note: `vip-enroute.wav` is **not** present in `assets/`; actual event sounds are
  > `attn_vip.ogg`, `attn_attack.ogg`, `attn_stronghold.ogg`, played inside each event.

### State (`state.lua` + per-event)

```lua
WE.nextUnitId = 1
WE.nextGroupId = 1
WE.nextMarkId = 1000        -- getNextMarkId() returns -(nextMarkId + 1)
WE.is_active = 0            -- global single-event lock (stronghold shares it)
WE.eventHandlers = {}
WE.events = {}
WE.eventStatusProviders = {} -- event key -> status text provider
```

Per-event state:
- `WE.currentVIPEvent = { departure, destination, transportGroupId, fighterGroupId }`
- `WE.currentBaseAttackEvent = { departure, destination, attackCASGroupGroupId, fighterGroupId }`
- `WE.activeStrongholdEvents = { [1] = { area, point, airbase, duration, spawnedAt, endsAt,
  unitNames, groups, markId, spawnId, buildingUnitName, ended, lastAnnouncedMinutes }, ... }`
- `WE.strongholdSpawnCounter` for unique group/unit names; F10 marks use
  `WE.getNextMarkId()`.

`WE.is_active` is a **single global flag**. For strongholds it stays `1` while any
stronghold mission is active and clears only when the list is empty.

---

## 4. Event implementations

### VIP Escort — `WE.EVENT.VIP_ESCORT` (`event_vipwing.lua`)

- Config: `WE.VIPCountry` (RUSSIA), `WE.VIPEscortEngagementDistMax` (60000 m),
  `WE.VIPFighterSpawnDelaySeconds` (15 s), `WE.VIPMinRunwayLengthMeters` (1000 m).
- Picks two distinct **red** airdromes whose longest runway ≥ 1000 m (`pickVIPAirfields`,
  `hasLongEnoughRunway`). Cancels cleanly if fewer than 2.
- Takeoff point comes from real runway data (`WE.getTakeoffPoint`).
- Spawns one **C-130J-30** ("RSD381 VIP") group `Vip_Transport`, route:
  `From Runway` (departure) → `Land` (destination). The fighter escort route
  adds a 10 NM rendezvous waypoint at a terrain-safe cruise altitude.
- Spawns 4× **MiG-29 Fulcrum** group `Vip_Wing_fighter` after a 15 s timer so the C-130
  clears the runway. Escort task targets the **actual** transport group ID captured from
  `coalition.addGroup` return value; `pos` offset behind/side; engagement distance from config.
- Sets `WE.is_active = 1`, `WE.currentVIPEvent`, notifies all players, plays `attn_vip.ogg`.
- Handler `WE.EVENT.VIPWING:onEvent` (registered globally):
  - `S_EVENT_CRASH` on `"RSD381 VIP"` → success text, clears active/state.
  - `S_EVENT_LAND` → informational text.
  - `S_EVENT_ENGINE_SHUTDOWN` → failure text, clears active/state.

### Base Attack — `WE.EVENT.BASE_ATTACK` (`event_baseattack.lua`)

- Config: `WE.AttackerCountry` (RUSSIA), `WE.EscortEngagementDistMax` (60000 m).
  (Escort task currently references `WE.VIPEscortEngagementDistMax`.)
- Picks one **red** departure airdrome and one **blue** target airdrome (`pickAirfields`).
  Cancels if either side has none.
- Spawns 3× **Su-25** ("Grif-1-1..3") group `ShAP`, route:
  departure → cruise waypoint over target (terrain-safe alt) → descend to attack alt
  (`max(1200, terrain+500)`) with `EngageTargetsInZone` (10 km, ground types) → land back at
  the **same** red departure.
- Spawns 4× **MiG-29** ("Sokol-21..24") group `Sokol_Fighter_Wing`, escorting the CAS group
  using its actual group ID.
- Sets `WE.is_active = 1`, `WE.currentBaseAttackEvent`, notifies all, plays `attn_attack.ogg`.
- Handler `WE.EVENT.BASEATTACK:onEvent` (registered globally), only when active and only for
  units in the CAS group ID:
  - `S_EVENT_DEAD` → if all `ShAP` units dead, success (clears state).
  - `S_EVENT_ENGINE_SHUTDOWN` → failure (aircraft landed safely).
  - Uses `Group.getByName("ShAP")` for the all-dead check.

### Stronghold — `WE.EVENT.STRONGHOLD` (`event_stronghold.lua`)

- Config defaults (actual code): `WE.StrongholdDurationSeconds = 900` (15 min),
  `StrongholdAllowMultiple = true`, `StrongholdMaxConcurrent = 5`,
  `StrongholdBuildingType = "Bunker"`, `StrongholdSAMType = "Strela-10M3"`,
  `StrongholdInfantryType = "Infantry AK"`, `StrongholdInfantryCount = 4`,
  `StrongholdOffsetMin/Max = 4630/7408`, `StrongholdRunwayMinDistance = 4630`,
  `StrongholdMaxSlope = 3`, defense T-72B3 ×3 / BTR-80 ×2 / Strela-10M3 ×2,
  defense radius 5000 m, min existing red units 4, defense spawn 300–1500 m.
- Location: random **red or neutral** airdrome (never blue), excluding airdromes already
  hosting an active stronghold (`getUsedStrongholdAirdromes`). Random offset/bearing;
  spawn must be on land (rejects WATER, SHALLOW_WATER, RUNWAY/pavement, ROAD), at least
  `StrongholdRunwayMinDistance` from any runway segment (perpendicular distance), and
  flat enough (`isPointFlat`).
- Spawns three red ground groups: building (destructible ground **unit**, so `S_EVENT_DEAD`
  fires), 1× SAM, 4× infantry. All names suffixed with unique `spawnId`.
- Sets `WE.is_active = 1`, pushes state into `WE.activeStrongholdEvents`, drops a unique
  negative-id F10 mark (`markToAll`), starts a shared 1-second countdown tick on the first
  mission, announces remaining minutes, plays `attn_stronghold.ogg`.
- Win: handler `WE.EVENT.STRONGHOLDEVENT:onEvent` on `S_EVENT_DEAD`; when all tracked units
  are dead → `endStrongholdEvent(..., "SUCCESS")`.
- Timeout failure:
  - If bunker already destroyed: partial success message, **no** capture.
  - If bunker alive: captures a still-neutral airbase for red
    (`setCoalition` + `autoCapture(false)`) and spawns defense garrison only if fewer than
    `StrongholdDefenseMinRedUnits` red ground units are within `StrongholdDefenseRadius`
    (own garrison excluded). Removes bunker + original defenders.
- Cleanup removes mark, destroys original groups, removes mission from active list, clears
  `WE.is_active` only when no strongholds remain. One mission per airfield; up to 5 concurrent.

---

## 5. Common patterns for new events

- **Dynamic map data only.** Never hardcode airbase names/coordinates. Use
  `WE.getAirdromes`, `WE.getTakeoffPoint`, `land.getHeight`, `WE.getMaxTerrainHeight`.
- **Unique names.** DCS rejects duplicate group/unit names; suffix with a spawn counter
  (`WE.getNextGroupId`/`getNextUnitId` or a module counter).
- **Capture actual IDs.** `coalition.addGroup` may reassign requested IDs; always read the
  returned `Group:getID()` before referencing the group (e.g. escort `groupId`).
- **Reserve IDs** with `WE.getNextGroupId()` when building a group table, then use the
  returned object's real ID for cross-references.
- **State + status.** Store enough in a `WE.current<Event>`/`WE.active<Event>s` table for
  the event's own handler and status provider; register the provider with
  `WE.registerEventStatus("<KEY>", provider)` at module load.
- **Concurrency.** Respect `WE.is_active`; if your event supports multiple instances, follow
  the stronghold model (own list, unique spawn IDs, per-instance timer/win logic, clear the
  global flag only when the list empties).
- **Announcements.** `trigger.action.outText(...)` for all players, `outSound(...)` for the
  alert, `markToAll(...)` for map markers (remove on end).
- **Event handlers.** DCS calls `onEvent` for *every* world event; early-return unless the
  event is relevant (check `WE.is_active`, group ID, unit name, `event.id`). Register with
  `world.addEventHandler(HandlerTable)` at load.
- **Logging.** Use `WE.logInfo`/`logWarning`/`logError`; `logDebug`/`logTrace` only for
  verbose diagnostics (gated by `WE.Debug`/`WE.Trace`).
- **DCS Lua 5.1.** No `goto`, no bitwise operators, no `table.unpack` (use `unpack`).
- **Sound files** live in `assets/` (or mission sound folder) and are referenced by name.

---

## 6. Configuration reference (`includes/config.lua`)

```lua
WE.Debug = true                 -- verbose D logs
WE.Trace = true                 -- very verbose T logs
WE.RadioUsers = {               -- group-name substrings; "All" = everyone
    [1] = "[Commander]",
    [2] = "[Patreon]",
}
WE.EnabledEvents = {            -- master on/off per event key
    ["VIP_ESCORT"] = true,
    ["BASE_ATTACK"] = true,
    ["STRONGHOLD"] = true,
}
WE.EventOrder = {               -- menu display order; unlisted enabled events appended
    "VIP_ESCORT", "BASE_ATTACK", "STRONGHOLD",
}
```

Event-specific config lives at the top of each `event_*.lua` (country IDs, distances,
unit types/counts, timers, etc.).

---

## 7. Known issues / caveats

- **Compiled output is generated.** Do not hand-edit `WorldEvents.lua`; rebuild from
  `includes/` with `build.ps1` (or run `extract.ps1` if you must adopt direct edits).
- **Docs:** `README.md`, `SITUATION_BRIEFING.md`, `changelog.md`, and `EVENT_DESIGN.md` are
  kept in sync with the code (Stronghold duration is 900 s / 15 min, and state uses
  `WE.activeStrongholdEvents`). Update them when behavior/config changes.
- **Planned events:** `EVENT_DESIGN.md` holds implementation-ready designs for `CONVOY`,
  `IADS`, `CSAR`, `BASE_DEFENSE`, and `FARP_CAPTURE`. Phase 0 (shared helper refactor) is
  complete; follow the file one event at a time and keep its status table current.
- **Missing sound:** `radio.lua` plays `"vip-enroute.wav"`, but `assets/` only contains
  `attn_vip.ogg`, `attn_attack.ogg`, `attn_stronghold.ogg`. Adjust or add the file if needed.
- **Legacy cargo subsystem in `utility.lua` is inactive.** Functions for troop transport,
  FOB crates, extraction, AI load/unload reference many globals that are never defined
  (`WE.extractZones`, `WE.inTransitTroops`, `WE.droppedTroopsRED`, `WE.transportPilotNames`,
  `WE.maxExtractDistance`, `WE.SOLDIER_WEIGHT`, etc.). `WE.checkAIStatus()` is never started.
  Safe to ignore; do not assume it works without wiring config + scheduler.
- **Base Attack config inconsistency:** escort uses `WE.VIPEscortEngagementDistMax` rather
  than `WE.EscortEngagementDistMax` in the task payload. Both default to 60000.
- **Single active event by design** except strongholds (when `StrongholdAllowMultiple`).
- **No automated tests.** Verification is: rebuild via `build.ps1`, then run in a DCS mission
  and inspect `dcs.log` (all lines prefixed `World Event - `). LuaLS diagnostics are
  configured via `.luarc.json` / `.vscode/settings.json`.
- `_header.lua` has no delimiter block, so `extract.ps1` regenerates it from the file prefix;
  keep it that way.
- Source files use CRLF-friendly plain text; build reads/writes line arrays via .NET.

---

## 8. Quick reference: where to change what

| I want to… | Edit |
|---|---|
| Add an event to the menu | `config.lua` (`EnabledEvents`, `EventOrder`) |
| Create a new event | `EVENT_DESIGN.md`, then new `includes/event_<name>.lua` + registry + config |
| Plan or track a new event | `EVENT_DESIGN.md` |
| Change radio access | `WE.RadioUsers` in `config.lua` |
| Change an event's status text | its `WE.registerEventStatus` provider |
| Change shared status behavior | `WE.showEventStatusAction` in `radio.lua` |
| Change player menu lifecycle | `event.lua` |
| Change VIP/base/stronghold behavior | corresponding `event_*.lua` |
| Add/modify shared helpers | `utility.lua` |
| Change logging behavior | `WE.log*` in `utility.lua`, `WE.Debug`/`WE.Trace` |
| Rebuild deployable script | `.\build.ps1 -InputFilePath "WorldEvents.lua"` |
| Re-split a large script | `.\extract.ps1 -InputFilePath "WorldEvents.lua"` |

---

## 9. Conventions checklist for edits

- Preserve delimiter format exactly in every include file.
- Keep `init.lua` last in the registry; keep `_header.lua` first.
- Prefer existing helpers and naming style (`snake_case` locals with leading `_` in events,
  `WE.camelCase` public functions).
- Use `WE.getNext*Id()`, unique names, and capture real group IDs after spawning.
- Update `README.md`, `SITUATION_BRIEFING.md`, `changelog.md`, and `EVENT_DESIGN.md` when
  behavior/config changes.
- Rebuild `WorldEvents.lua` after editing includes; never commit a stale compiled file.
- Do not add comments unless they clarify non-obvious behavior (existing code is documented
  with LuaCATS `---@` annotations).
