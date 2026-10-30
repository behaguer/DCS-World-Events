# Changelog

All notable changes to DCS-WORLD-EVENTS will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-08-03

### Added
- New **Stronghold** world event (`WE.EVENT.STRONGHOLD`)
  - Spawns a red stronghold (destructible building + infantry + short-range SAM) at a random location
  - Stronghold is placed near a random **red or neutral** airdrome (never blue, so it can't land on a player base), at least 1 nautical mile away so its defenders never spawn on the runway
  - Configurable mission timer (default 10 minutes) that ends the mission in failure on expiry
  - On failure, a still-neutral airdrome is captured for red (`Airbase:setCoalition` + `autoCapture(false)`) and re-garrisoned with 3 tanks, 2 APCs and 2 SAM sites when fewer than 4 red units are already stationed at the airfield (the stronghold's own garrison is excluded from the count); the bunker and the original stronghold defenders are then removed
  - All spawn points (stronghold, infantry, SAM, defense garrison) are checked with `land.getSurfaceType` (as a Vec2 `{x, y}` with `y` = north) and retried/relocated until on land — both `WATER` and `SHALLOW_WATER` are rejected so nothing spawns in the sea or near the shore
  - Success when the stronghold and all defenders are destroyed
  - All spawned units tracked in mission state (`WE.currentStrongholdEvent`)
  - F10 map mark at the stronghold location, removed on event end
  - Added to the "Spawn Event" radio menu via `WE.EnabledEvents`/`WE.EventOrder`
  - New `includes/event_stronghold.lua` module
- `WE.getAirdromes(side)` now also accepts `'neutral'` (in addition to `'red'`/`'blue'`)
- Radio menu system with F10 integration
  - "WorldEvents > Spawn Event" menu option for triggering events
  - "WorldEvents > Event Status" menu option for checking event status
- Group-based radio access control system
  - Access control via `WE.RadioUsers` configuration table
  - Support for universal access ("ALL") or name-based matching
  - Group name matching with plain text search (no pattern matching)
- Modular event handling system
  - New `event.lua` module for all event handling logic
  - Support for multiple event types (S_EVENT_PLAYER_ENTER_UNIT, S_EVENT_BIRTH, S_EVENT_PLAYER_LEAVE_UNIT)
  - Automatic radio menu management on player join/leave/respawn
  - Proper DCS event handler format with cleanup support
- Dynamic menu assignment
  - Per-group radio menus for better organization
  - Automatic menu creation/removal on player reslotting
  - Fallback global menu support when group detection fails

### Changed
- Stronghold spawn location hardened so it never lands on a runway, taxiway/apron, road, or in the sea:
  - spawn zone must be at least `StrongholdRunwayMinDistance` (default 4630 m = 2.5 nm) from any runway, measured perpendicular to the full runway segment (cached `Airbase:getRunways()` segments) rather than just the endpoints
  - spawn points checked with `land.getSurfaceType` reject `RUNWAY` and `ROAD` in addition to `WATER`/`SHALLOW_WATER` (DCS reports runways, taxiways, ramps and aprons all as `RUNWAY`)
  - new flatness check (`isPointFlat`) rejects terrain steeper than `StrongholdMaxSlope` (default 3 m) so the bunker and vehicles sit on level ground
- `randomLandPoint` now swaps `_min`/`_max` (with a warning) instead of erroring when a config passes them inverted
- Multiple concurrent Stronghold missions:
  - new `activeStrongholdEvents` list (one state entry per mission) replaces the single `currentStrongholdEvent`
  - `StrongholdAllowMultiple` / `StrongholdMaxConcurrent` config; the shared countdown tick walks every mission, the `S_EVENT_DEAD` handler resolves each independently, F10 marks are unique per mission, and `WE.is_active` stays set while any mission runs
  - the radio menu bypasses the global one-event-at-a-time gate for Stronghold when multiple missions are enabled
  - each mission stores its own `spawnId`, `buildingUnitName`, `markId`, `unitNames` and `groups`
- One Stronghold per airfield: airdromes already hosting an active stronghold mission are excluded when picking the location (`getUsedStrongholdAirdromes`), so missions never double up on the same airfield
- Failure outcome depends on the bunker: if it was destroyed before the timer ran out the airfield is **not** captured and remaining troops scatter; otherwise the airfield is still captured and re-garrisoned
- Build system separated into `build.ps1` (combine files) and `extract.ps1` (split files)
- Radio access control moved from player name to aircraft group name matching
- Event handling logic separated from radio functions for better modularity
- Enhanced logging system for debugging access control and event detection

### Fixed
- Red defense units only spawned at **one** airfield when several strongholds failed at the same time — all missions shared the same `strongholdSpawnCounter` value, producing duplicate group names so later spawns overwrote earlier ones. Defense units now use each mission's unique `spawnId`, so every captured airfield gets its own garrison.
- String pattern matching issue with special characters in user strings (e.g., "[Patreon]")
- Event handler format corrected for proper DCS API compatibility
- Radio menu persistence issues during player reslotting
- Access control logic to use plain text matching instead of Lua patterns

### Technical Details
- Files added: `includes/event.lua`, `includes/radio_functions.lua` 
- Files modified: `includes/config.lua`, `includes/init.lua`, `includes/_compiler_registry.txt`
- Event system now properly handles player spawn/respawn/reslot scenarios
- Radio menus dynamically created per group with access validation
- Debug logging enhanced for troubleshooting access control decisions
