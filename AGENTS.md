# DCS-World-Events — Agent Notes

> DCS World multiplayer event framework. The game loads **one compiled Lua file**
> (`WorldEvents.lua`); authoritative source lives in split modules under `includes/` and is
> reassembled by PowerShell. Lua 5.1, version `0.1.0`.

## Build / verify

```powershell
.\build.ps1 -InputFilePath "WorldEvents.lua"   # includes/ -> repo-root WorldEvents.lua
.\extract.ps1 -InputFilePath "WorldEvents.lua" # WorldEvents.lua -> includes/, rewrites registry
```

- **No tests, lint, or typecheck command exists.** Verify by rebuilding, running a sample
  mission in DCS, and checking `dcs.log` for lines prefixed `World Event - `.
- `build.ps1` reads `includes/_compiler_registry.txt` and concatenates the listed files
  verbatim (delimiters included). Output name comes from `-InputFilePath`; it always writes
  to the repo root. `-OutputDirectory` (default `includes`) is the **source** directory, not
  the output location — the name is misleading.
- `_header.lua` is prepended only when it is the first registry entry.
- `extract.ps1` is for adopting edits made directly in `WorldEvents.lua`; it rewrites the
  registry in file order and forces `_header.lua` first.
- **Never hand-edit `WorldEvents.lua`.** Edit `includes/*.lua`, then rebuild.
- `.luarc.json` deliberately ignores the compiled `WorldEvents.lua`; Lua 5.1 typing comes
  from `includes/types.lua` (runtime-free LuaCATS annotations).

## Source layout and delimiters

Every include file except `_header.lua` must be wrapped exactly like this (17 hyphens;
`extract.ps1` matches it with a regex):

```lua
-----------------[[ event_convoy.lua ]]-----------------
...content...
-----------------[[ END OF event_convoy.lua ]]-----------------
```

`_header.lua` has **no** delimiters — it is everything before the first start marker.

Registry order (`includes/_compiler_registry.txt`):

```
_header.lua, types.lua, config.lua, state.lua, utility.lua, radio.lua,
event.lua, event_vipwing.lua, event_baseattack.lua, event_stronghold.lua,
event_convoy.lua, event_iads.lua, autorun.lua, init.lua
```

Order matters: `_header.lua` defines `WE` first; `init.lua` must stay last because it calls
`WE.initialize()` immediately at load. Config lives in `includes/config.lua`; per-event config
lives at the top of each `event_*.lua`.

Other paths: `assets/` (alert `.ogg` files), `sample-missions/` (`.miz` examples),
`EVENT_DESIGN.md` (backlog/designs), `README.md` (full player-facing details),
`SITUATION_BRIEFING.md`, `changelog.md`.

## Adding an event

1. Create `includes/event_<name>.lua` with the delimiter wrapper.
2. Add it to `includes/_compiler_registry.txt` **before `init.lua`**.
3. Add the key to `WE.EnabledEvents` and `WE.EventOrder` in `includes/config.lua`.
4. Define `WE.EVENT.<KEY>()` (spawn function).
5. Optionally define `WE.EVENT.<NAME>EVENT` and register it with
   `world.addEventHandler(...)` at module load.
6. Register a status provider with `WE.registerEventStatus("<KEY>", provider)`; do **not**
   edit `WE.showEventStatusAction`.
7. Rebuild. The radio menu auto-generates from config.

Keys are uppercase snake case (`CONVOY`); display labels replace `_` with spaces. Module files
are `event_<lowercase>.lua`. `types.lua` is annotations only.

## Runtime wiring

- `_header.lua` creates `WE = {}`, `WE.Id`, `WE.Version`, `WE.EVENT`.
- `init.lua` runs `WE.initialize()` at load: `initializeRadioMenu()` then
  `initializeEvents()` (registers the player enter/birth/leave handler).
- Event modules register their own `world.addEventHandler(...)` at file-load time, so handlers
  exist regardless of initialization order.
- `WE.eventStatusProviders` is initialized in `radio.lua`, not `state.lua`.

### State (`state.lua` + event modules)

```lua
WE.nextUnitId = 1
WE.nextGroupId = 1
WE.nextMarkId = 1000        -- WE.getNextMarkId() returns negative IDs
WE.is_active = 0            -- global single-event lock
WE.eventHandlers = {}
WE.events = {}
```

Per-event state: `WE.currentVIPEvent`, `WE.currentBaseAttackEvent`,
`WE.activeConvoyEvents` (+ `WE.currentConvoyEvent` alias, `WE.convoySpawnCounter`),
`WE.activeStrongholdEvents` (+ `WE.strongholdSpawnCounter`), and `WE.currentIADSEvent`
(+ `WE.iadsSpawnCounter`). Lists hold one entry per active mission; `WE.is_active` stays `1`
while any tracked mission remains and clears when the list is empty. IADS is single-instance.

### Radio menu

- Access is a **case-insensitive plain-substring match against the player group's name**, not
  player name, in `WE.RadioUsers`. `"All"` anywhere grants everyone.
- Global menu when `"All"` is present; otherwise one menu per plane/heli group. Menus are
  rebuilt on `S_EVENT_PLAYER_ENTER_UNIT` / `S_EVENT_BIRTH` (delayed) and removed on
  `S_EVENT_PLAYER_LEAVE_UNIT` (`event.lua`).
- Layout: `WorldEvents > Spawn Event > <enabled events in EventOrder>`, plus `Event Status`.
- `WE.spawnEventMenuAction` enforces the single-active-event gate, except `STRONGHOLD` when
  `WE.StrongholdAllowMultiple` and `CONVOY` when `WE.ConvoyAllowMultiple`. After any spawn it
  calls `trigger.action.outSound("vip-enroute.wav")` — that asset is missing from `assets/`
  (harmless); real event alerts are played inside each event.

## Events at a glance

| Key | Module | Handler table | Active state | Alert |
|---|---|---|---|---|
| `VIP_ESCORT` | `event_vipwing.lua` | `WE.EVENT.VIPWING` | `WE.currentVIPEvent` | `attn_vip.ogg` |
| `BASE_ATTACK` | `event_baseattack.lua` | `WE.EVENT.BASEATTACK` | `WE.currentBaseAttackEvent` | `attn_attack.ogg` |
| `CONVOY` | `event_convoy.lua` | `WE.EVENT.CONVOYEVENT` | `WE.activeConvoyEvents` | `attn_convoy.ogg` |
| `STRONGHOLD` | `event_stronghold.lua` | `WE.EVENT.STRONGHOLDEVENT` | `WE.activeStrongholdEvents` | `attn_stronghold.ogg` |
| `IADS` | `event_iads.lua` | `WE.EVENT.IADSEVENT` | `WE.currentIADSEvent` | `attn_iads.ogg` |

- **VIP Escort:** two distinct red airdromes with a runway ≥ `VIPMinRunwayLengthMeters`
  (1000 m); C-130J-30 `RSD381 VIP` plus 4 MiG-29 escort after
  `VIPFighterSpawnDelaySeconds` (15 s). Crash of the transport = success; engine shutdown =
  failure.
- **Base Attack:** red departure → blue target → same red departure; 3 Su-25 (`ShAP`) plus 4
  MiG-29 escort (`Sokol_Fighter_Wing`). All `ShAP` dead = success; engine shutdown = failure.
- **Convoy:** red origin → red/neutral destination (never blue); kill every tracked unit
  before arrival/timeout = success. Arrival or timeout = failure and spawns a 2× BTR-80 + 1×
  Shilka garrison at the destination. Route must be 5000 m–30 nm and continuously on land.
  Multiple missions only when `WE.ConvoyAllowMultiple` (default `false`).
- **Stronghold:** random red/neutral airdrome (never blue), one active mission per airdrome,
  up to `StrongholdMaxConcurrent` (5). Building is a destructible ground **unit** so
  `S_EVENT_DEAD` fires. Destroy all tracked units = success. On timeout, a still-neutral
  airfield is captured for red unless the bunker was already destroyed.
- **IADS:** random red airdrome (neutral fallback, never blue); single instance. Three SAM
  sites (Kub `Kub 1S91 str` + 2x `Kub 2P25 ln`, Buk `SA-11 Buk CC 9S470M1` +
  `SA-11 Buk SR 9S18M1` + `SA-11 Buk LN 9A310M1`, or Tor `Tor 9A331`), one `55G6 EWR`, and
  one `Bunker` command node. Kill every tracked unit within `IADSDurationSeconds` (900 s) for
  success; timeout fails once, leaves survivors alive, and spawns **no** retaliation. Only an
  area SIGINT mark is placed. Config: `IADSCountry`, `IADSSiteCount`, `IADSSAMTypes`,
  `IADSSkill`, `IADSCommandType`, `IADSRadarType`, `IADSPlacementMin`/`Max`,
  `IADSRunwayMinDistance`, `IADSSiteMinDistance`, `IADSBlueBaseMinDistance`, `IADSMaxSlope`,
  `IADSPlacementAttempts`, `IADSDurationSeconds`, `IADSTickIntervalSeconds`, `IADSMarkMode`,
  `IADSSound`, `IADSEnabled`.

See `README.md` for full event behavior and `EVENT_DESIGN.md` for the shared helper contract.

## Hard-won pitfalls

- **Dynamic map data only.** Never hardcode airbase names or coordinates. Use
  `WE.getAirdromes(side)` (AIRDROME category only — excludes ships/FARPs/helipads),
  `WE.getTakeoffPoint`, `land.getHeight`, `WE.getMaxTerrainHeight`.
- **Use `WE.getTakeoffPoint` for air spawns.** Spawning "From Runway" at the airbase
  reference point leaves aircraft stuck; it returns a runway-aligned point and heading.
- **Capture real IDs after spawning.** `coalition.addGroup` may reassign requested IDs; read
  `Group:getID()` from the returned object before referencing it (e.g. escort targets).
- **Unique names.** DCS rejects duplicates. Use spawn counters / `WE.getNext*Id()`; suffix
  long-lived event names with a per-spawn ID.
- **F10 marks.** `WE.getNextMarkId()` returns unique negative IDs; remove marks on event end.
- **Terrain placement.** `WE.isPointOnLand` rejects water, shallow water, RUNWAY (includes
  taxiways/aprons) and ROAD. Use `WE.isPointFlat` before ground spawns.
- **Event handlers fire for every world event.** Early-return unless `event.id`, group ID, or
  unit name matches the active event.
- **`WE.is_active` is one global flag.** Do not treat it as per-event state.
- **Lua 5.1 only:** no `goto`, no bitwise operators, use `unpack` (not `table.unpack`).
- **Trust event modules over `changelog.md` and prose for defaults.** The 0.1.0 changelog says
  Stronghold lasts 10 minutes; the code default is 900 s (15 min).
- **Known config inconsistency:** Base Attack defines `WE.EscortEngagementDistMax` but its
  escort task actually reads `WE.VIPEscortEngagementDistMax` (both default 60000).
- **Assets are not auto-loaded.** Sound names are resolved from the mission (or its sound
  folder); copy the required `assets/*.ogg` into each mission.
- **Legacy cargo subsystem in `utility.lua` is inactive.** The troop/FOB/extraction functions
  reference globals that are never defined; `WE.checkAIStatus()` is never started. Ignore it
  unless you explicitly wire config and the scheduler.
- Reuse the shared helpers in `utility.lua`: `isPointOnLand`, `isPointFlat`,
  `randomLandPoint`, `randomLandOffsetNear`, `getRunwaySegments`, `minDistanceToRunway`,
  `distanceToSegmentXY`, `buildStationaryGroundGroup`, `buildGroundUnit`, `areAllUnitsDead`,
  `countUnitsInRadius`, `destroyGroupList`.

## Where to change what

| I want to… | Edit |
|---|---|
| Enable/reorder events in the menu | `includes/config.lua` (`EnabledEvents`, `EventOrder`) |
| Change radio access | `WE.RadioUsers` in `includes/config.lua` |
| Enable automatic event scheduling | `WE.AutoRunEnabled` / `WE.AutoRunIntervalMinutes` in `includes/config.lua`; logic in `includes/autorun.lua` |
| Create/change an event | `includes/event_<name>.lua` (+ registry + config) |
| Add shared spawn/terrain helpers | `includes/utility.lua` |
| Change menu lifecycle or status report | `includes/event.lua`, `includes/radio.lua` |
| Change logging | `WE.log*` in `utility.lua`; `WE.Debug` / `WE.Trace` in `config.lua` |
| Plan the next event | `EVENT_DESIGN.md` |
| Deploy / split source | `build.ps1` / `extract.ps1` |

## Docs and conventions

- Update `README.md`, `SITUATION_BRIEFING.md`, `changelog.md`, and `EVENT_DESIGN.md` whenever
  behavior or config changes. `EVENT_DESIGN.md` currently marks `CONVOY` and `IADS`
  code-complete/shipped (DCS test pending) and holds designs for `CSAR`, `BASE_DEFENSE`,
  `FARP_CAPTURE`.
- Keep `_header.lua` first and `init.lua` last in the registry; preserve delimiter format.
- Style: `WE.camelCase` public functions; event locals use `snake_case` with a leading `_`.
- Existing code uses LuaCATS `---@` annotations. Add comments only for non-obvious behavior.
- Always rebuild the compiled file after editing includes; do not commit a stale build.

## Agent skills

### Issue tracker

Work is tracked as markdown files under `.scratch/<feature>/`. See `docs/agents/issue-tracker.md`.

### Triage labels

Default role names: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `GLOSSARY.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.
