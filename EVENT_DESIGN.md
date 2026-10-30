# Event Design Backlog — DCS-World-Events

> Implementation-ready design notes for expanding the multiplayer event library.
> Read `AGENTS.md` first. Work **one event at a time**, complete the shared
> refactor first, and update this file as designs change.

---

## 0. How to use this document

1. Read `AGENTS.md` for the current build/runtime contract.
2. Complete **Phase 0 — shared helper refactor** once (section 2).
3. Pick the next event from section 4 in the recommended order.
4. Create the module, add it to the registry/config, implement, build, and test.
5. Update `README.md`, `SITUATION_BRIEFING.md`, `changelog.md`, and this file.
6. Mark the event's status in the table below.

### Status legend

| Status | Meaning |
|---|---|
| `READY` | Can start immediately after Phase 0 |
| `BLOCKED` | Depends on a shared helper or design decision |
| `IN PROGRESS` | Being implemented |
| `DONE` | Implemented, tested, documented |

### Backlog overview

| Order | Event key | Module | Main roles | Complexity | Depends on |
|---|---|---|---|---|---|
| 0 | — | shared helpers | — | Medium | — |
| 1 | `CONVOY` | `event_convoy.lua` | Strike/CAS, SEAD, CAP | Medium | Phase 0 |
| 2 | `IADS` | `event_iads.lua` | SEAD/DEAD, CAP, recon | Medium | Phase 0 |
| 3 | `CSAR` | `event_csar.lua` | Helicopter, escort/CAS, CAP | Medium | Phase 0 + zone helper |
| 4 | `BASE_DEFENSE` | `event_basedefense.lua` | CAP, CAS, ground defense | Medium–High | Phase 0 + wave helper |
| 5 | `FARP_CAPTURE` | `event_farpcapture.lua` | Helo transport, CAS, CAP | High | Phase 0 + capture/zone helper |

---

## 1. Current event contract (baseline)

Every event must fit the existing framework:

- One module in `includes/event_<name>.lua`, wrapped in the standard
  `-----------------[[ ... ]]-----------------` delimiters.
- One registry entry in `includes/_compiler_registry.txt` **before `init.lua`**.
- One key in `WE.EnabledEvents` and `WE.EventOrder` in `includes/config.lua`.
- A spawn function named `WE.EVENT.<KEY>()`.
- Optional state table (`WE.current<Event>` or `WE.active<Event>s`).
- Optional handler table `WE.EVENT.<NAME>EVENT` registered with
  `world.addEventHandler(...)` at module load.
- Optional status reporting in `WE.showEventStatusAction` (or a status provider,
  see section 2).
- Optional event sound played inside the spawn function.
- Rebuild with:

```powershell
.\build.ps1 -InputFilePath "WorldEvents.lua"
```

### Concurrency rules

- `WE.is_active` is the global single-event lock.
- Stronghold is the only event that supports multiple concurrent instances; it
  uses `WE.activeStrongholdEvents` and bypasses the radio gate when
  `WE.StrongholdAllowMultiple` is true.
- New events default to **single instance** unless explicitly designed
  otherwise. If an event should overlap a stronghold or other events, extend the
  gate deliberately and document it here.

### Required module skeleton

```lua
-----------------[[ event_convoy.lua ]]-----------------
WE.ConvoyCountry = country.id.RUSSIA
WE.ConvoyTruckCount = 6
-- ...event config...

WE.currentConvoyEvent = nil

function WE.EVENT.CONVOY()
    -- validate, pick location, spawn, set state, notify, play sound
end

WE.EVENT.CONVOYEVENT = {}

function WE.EVENT.CONVOYEVENT:onEvent(event)
    if not event then return end
    if event.id ~= world.event.S_EVENT_DEAD then return end
    if not WE.currentConvoyEvent then return end
    -- cheap relevance checks, then win/lose logic
end

world.addEventHandler(WE.EVENT.CONVOYEVENT)

-----------------[[ END OF event_convoy.lua ]]-----------------
```

---

## 2. Phase 0 — shared helpers and performance rules

Do this **before** implementing the first new event. It avoids duplicating
Stronghold's ground-spawn/placement logic in every module and keeps new modules
independent of registry order.

### 2.1 Move reusable helpers into `utility.lua`

Currently these live in `includes/event_stronghold.lua` but are generic:

| Helper | Action |
|---|---|
| `WE.isPointOnLand(point)` | Move to `utility.lua` unchanged |
| `WE.isPointFlat(point, radius)` | Move to `utility.lua` unchanged |
| `WE.randomLandPoint(x, z, min, max, attempts)` | Move to `utility.lua` unchanged |
| `WE.randomLandOffsetNear(x, z, maxOffset)` | Move to `utility.lua` unchanged |
| `WE.getRunwaySegments(airbase)` | Move to `utility.lua` unchanged |
| `WE.minDistanceToRunway(segments, point)` | Move to `utility.lua` unchanged |
| `WE.distanceToSegmentXY(ax, az, bx, bz, point)` | Move to `utility.lua` unchanged |
| `WE.buildStationaryGroundGroup(name, groupId, x, z, units)` | Move to `utility.lua` unchanged |
| `WE.buildStrongholdUnit(...)` | Move and rename to `WE.buildGroundUnit(...)` |
| `WE.areAllStrongholdUnitsDead(eventData)` | Move and generalize to `WE.areAllUnitsDead(unitNames)` |
| `WE.countRedGroundUnitsNear(point, radius, excludedNames)` | Move and generalize to `WE.countUnitsInRadius(side, point, radius, category, excludedNames)` |
| `WE.destroyGroupList(groups)` | Move to `utility.lua` unchanged |

Keep Stronghold-specific logic in `event_stronghold.lua`:
`getUsedStrongholdAirdromes`, `pickStrongholdLocation`,
`spawnStrongholdGroundGroup`, `captureStrongholdAirfield`,
`spawnStrongholdDefense`, `destroyStrongholdUnits`, `endStrongholdEvent`,
`strongholdCountdownTick`.

### 2.2 Add shared helpers

Add to `state.lua`:

```lua
WE.nextMarkId = 1000
```

Add to `utility.lua`:

```lua
function WE.getNextMarkId()
    WE.nextMarkId = WE.nextMarkId + 1
    return -WE.nextMarkId
end
```

Then refactor Stronghold's mark ID from `-(1000 + spawnId)` to
`WE.getNextMarkId()` so new event types cannot collide with Stronghold marks.

### 2.3 Recommended status-provider refactor

Five new event types would make `WE.showEventStatusAction` large and fragile.
Add a small registry in `radio.lua`:

```lua
WE.eventStatusProviders = {}

function WE.registerEventStatus(eventKey, provider)
    WE.eventStatusProviders[eventKey] = provider
end
```

`WE.showEventStatusAction` should iterate the providers and append their output.
Each event module registers a provider at load time. If you do not want this
refactor yet, add a clearly separated branch in `showEventStatusAction` and keep
the status logic in the event module.

### 2.4 Performance rules for all new events

- **Early-return in `onEvent`:** check `event`, `event.id`, `WE.is_active`/state,
  `event.initiator`, then group/name before any expensive work.
- **Never scan all groups from `onEvent`.** Use tracked unit names and
  `Unit.getByName` / `Group.getByName`, or pre-captured group IDs.
- **Tick at 2–5 s**, not every frame. Use one shared tick per event type, and
  return `nil` to stop it when no instances remain.
- **Prefer scheduled timeouts** for simple timers (e.g. IADS deadline) over a
  constant tick.
- **Cache static data** (airbase points, runway segments, routes) at spawn.
- **Limit unit counts:** e.g. 6–10 convoy vehicles, 2–4 SAM sites, 3–5 waves.
- **Scan only the needed coalition/category** when using
  `coalition.getGroups(side, category)`.
- **Use `pcall`** around `Airbase:getRunways()` and other APIs that can fail.
- **Unique names and real IDs:** use `WE.getNextGroupId()` /
  `WE.getNextUnitId()` and always read the returned group's real ID after
  `coalition.addGroup`.
- **Clean up:** remove F10 marks, destroy leftover spawned groups, and stop
  timers on success/failure.
- **Avoid text spam:** `trigger.action.outText` only on spawn, meaningful
  countdowns (whole minutes), and end states.
- **No static-object kill detection:** static objects do not reliably fire
  `S_EVENT_DEAD`; use a destructible ground unit when the objective must die.

### 2.5 Phase 0 acceptance criteria

- [ ] All moved helpers are available from `utility.lua`.
- [ ] Stronghold still spawns, counts defenders, captures airfields, and
  removes marks after the refactor.
- [ ] `WE.getNextMarkId()` is used by Stronghold and produces unique negative
  IDs.
- [ ] `build.ps1` completes and Stronghold passes an in-game smoke test.
- [ ] No new event modules were added yet.

---

## 3. Shared names and conventions

Use these conventions so the modules feel consistent and are easy to review:

| Item | Convention |
|---|---|
| Module file | `includes/event_<name>.lua` (lowercase, underscores) |
| Event key | uppercase snake case, e.g. `BASE_DEFENSE` |
| Spawn function | `WE.EVENT.<KEY>()` |
| Handler table | `WE.EVENT.<KEY>EVENT` |
| State (single) | `WE.current<Event>Event` |
| State (multiple) | `WE.active<Event>Events = {}` |
| Tick function | `WE.<event>CountdownTick` or `WE.<event>Tick` |
| Spawn counter | `WE.<event>SpawnCounter` (or use helper IDs) |
| Sound | `attn_<event>.ogg` |
| Mark ID | `WE.getNextMarkId()` |
| Group/unit prefix | `Convoy_`, `IADS_`, `CSAR_`, `BaseDef_`, `FARP_` |

---

## 4. Event designs

### 4.1 `CONVOY` — Convoy Interdiction

**Status:** `READY` after Phase 0  
**Module:** `includes/event_convoy.lua`  
**Spawn function:** `WE.EVENT.CONVOY()`  
**Handler:** `WE.EVENT.CONVOYEVENT`  
**Complexity:** Medium

**Pitch:** A red supply convoy leaves a rear airbase and drives to a front-line
base. Blue must destroy it before it delivers reinforcements.

**Why it works in multiplayer:** It creates a moving ground target that rewards
coordination: strike/CAS aircraft attack the convoy, SEAD/escort aircraft
suppress mobile AAA/SAM, and CAP handles any fighter escort. Failure has a
visible consequence at the destination.

**Dynamic placement**

- Origin: random red airdrome.
- Destination: random red or neutral airdrome.
- Reject spawn/route points on water; use `WE.isPointOnLand`.
- Use 3–5 route waypoints. Keep the route simple; let DCS ground AI path the
  group.
- Optional synergy: if a Stronghold is active, the destination may be that
  Stronghold's airfield (only if concurrency is explicitly enabled).

**Spawn plan**

- One moving ground group with:
  - 6–8 trucks/fuel trucks (`Ural-375`, `GAZ-66`, etc. — verify exact DCS
    type names).
  - 2–4 escorts (`BMP-2`, `BTR-80`).
  - Optional `ZSU-23-4 Shilka` and `Strela-10M3`.
- Optional 2× MiG-29 escort if the server needs more air pressure.
- Use `WE.buildGroundUnit` / `WE.buildStationaryGroundGroup` as a base, then
  attach a route with waypoints to the destination.

**State schema**

```lua
WE.currentConvoyEvent = {
    origin = "airbase name",
    destination = "airbase name",
    destinationPoint = { x = 0, y = 0, z = 0 },
    groupId = 0,
    groupName = "Convoy_1",
    unitNames = { ["Convoy_Truck_1"] = true, ... },
    spawnedAt = 0,
    endsAt = 0,
    delivered = false,
    markId = 0,
}
```

**Handlers and tick**

- `WE.EVENT.CONVOYEVENT:onEvent`:
  - Only `S_EVENT_DEAD`.
  - Ignore units not in `unitNames`.
  - When all tracked units are dead → success.
- `WE.convoyTick` every 5 s:
  - If the leader (first alive unit) is within
    `WE.ConvoyArrivalRadiusMeters` of the destination → failure.
  - If `timer.getTime() >= endsAt` → failure.
  - If all units are dead → success.
  - Return `now + 5` while active, `nil` when finished.

**Win condition:** all convoy units destroyed.

**Failure condition and consequence**

- Failure when the convoy reaches the destination or the timeout expires.
- On failure: announce delivery and spawn a small red defense group at the
  destination (reuse the Stronghold defense pieces or a simple 2× BTR-80 +
  1× Shilka group). Optionally reinforce the destination airbase.

**Config**

| Key | Default | Notes |
|---|---|---|
| `WE.ConvoyCountry` | `country.id.RUSSIA` | Spawn country |
| `WE.ConvoyTruckTypes` | `{ "Ural-375", "GAZ-66" }` | Verify DCS type names |
| `WE.ConvoyTruckCount` | `6` | Keep total units reasonable |
| `WE.ConvoyEscortTypes` | `{ "BMP-2", "BTR-80" }` | Ground escorts |
| `WE.ConvoyEscortCount` | `3` | |
| `WE.ConvoyAAAType` | `"ZSU-23-4 Shilka"` | Optional |
| `WE.ConvoySAMType` | `"Strela-10M3"` | Optional |
| `WE.ConvoySpeedKph` | `30` | Route speed |
| `WE.ConvoyArrivalRadiusMeters` | `500` | Delivery radius |
| `WE.ConvoyTimeoutSeconds` | `1800` | Hard deadline |
| `WE.ConvoyAllowMultiple` | `false` | Keep false initially |
| `WE.ConvoyMaxConcurrent` | `2` | Only if multiple is enabled |

**Status line:** `Convoy: en route from <origin> to <destination>, <seconds>
remaining.`

**Sound:** `attn_convoy.ogg`.

**Performance notes**

- One ground group, one tick every 5 s.
- Do not query all ground groups; track `unitNames`.
- Route data is built once at spawn.

**DCS/Lua risks**

- Ground AI route following can be slow over rough terrain; test on each map.
- Exact DCS type names vary; verify before shipping.
- If the destination is captured during the event, decide whether to fail,
  divert, or cancel; simplest is to fail/deliver at the original point.

**Implementation checklist**

- [ ] Add module + delimiters + registry entry.
- [ ] Add `WE.EnabledEvents["CONVOY"]`, `WE.EventOrder`.
- [ ] Add config block.
- [ ] Implement spawn, state, handler, tick.
- [ ] Add status line.
- [ ] Add sound asset.
- [ ] Build + DCS test (success, timeout, arrival, repeated spawn).
- [ ] Update docs/changelog.

**Acceptance criteria**

- Convoy spawns on land, follows a route, and reaches the destination.
- Killing every unit produces a success message and clears `WE.is_active`.
- Reaching the destination produces a failure message and defense spawn.
- Repeated runs never produce duplicate unit names.
- The tick stops after the event ends.

---

### 4.2 `IADS` — SAM Network Takedown

**Status:** `READY` after Phase 0  
**Module:** `includes/event_iads.lua`  
**Spawn function:** `WE.EVENT.IADS()`  
**Handler:** `WE.EVENT.IADSEVENT`  
**Complexity:** Medium

**Pitch:** Red has dispersed a small integrated air-defense network around a
strategic sector. Blue must destroy the command node and SAM sites before the
window closes and red retaliates.

**Why it works in multiplayer:** Dedicated SEAD/DEAD flights, a CAP screen, and
recon/JTAC work together. The event rewards target prioritization and threat
avoidance rather than a single bombing run.

**Dynamic placement**

- Pick a red/neutral airdrome or strategic point.
- Place 2–4 SAM sites at 6–18 km offsets, 1 EWR, and 1 command post/bunker.
- Reject water, pavement, and steep terrain with `WE.isPointOnLand`,
  `WE.minDistanceToRunway`, and `WE.isPointFlat`.
- Mark only a general “SIGINT area” on F10 by default; optional exact marks for
  easier servers.

**Spawn plan**

- SAM types: `SA-6 Kub`, `SA-11 Buk`, `SA-15 Tor`, `SA-13 Gopher` (verify exact
  DCS type names).
- EWR type: `EWR 55G6` or equivalent.
- Command node: destructible ground unit (`Bunker` / `Command Post`) so
  `S_EVENT_DEAD` fires.
- Optional AAA/Shilka for low-level pressure.

**State schema**

```lua
WE.currentIADSEvent = {
    area = "airbase or sector name",
    point = { x = 0, y = 0, z = 0 },
    sites = { { type = "SA-6 Kub", groupId = 0, unitName = "IADS_SAM_1" }, ... },
    unitNames = { ["IADS_SAM_1"] = true, ... },
    groups = { ... },
    spawnedAt = 0,
    endsAt = 0,
    markId = 0,
    retaliationSpawned = false,
}
```

**Handlers and tick**

- `WE.EVENT.IADSEVENT:onEvent`:
  - Only `S_EVENT_DEAD`.
  - Check tracked unit names.
  - When all tracked units are dead → success.
- `WE.iadsTick` every 10 s:
  - Announce remaining whole minutes when they change.
  - On timeout, spawn retaliation once and fail.
  - Return `now + 10` while active, `nil` when finished.

**Win condition:** all SAM/EWR/command units destroyed.

**Failure condition and consequence**

- Failure when the timer expires.
- On failure: spawn a red retaliation strike package (e.g. 2× `Su-24M`) against
  a blue airbase, or announce that the airspace is closed and leave surviving
  SAMs active. Keep the consequence configurable.

**Config**

| Key | Default | Notes |
|---|---|---|
| `WE.IADSCountry` | `country.id.RUSSIA` | Spawn country |
| `WE.IADSSiteCount` | `3` | 2–4 recommended |
| `WE.IADSSAMTypes` | `{ "SA-6 Kub", "SA-11 Buk", "SA-15 Tor" }` | Verify DCS names |
| `WE.IADSEWRType` | `"EWR 55G6"` | Verify DCS name |
| `WE.IADSCommandType` | `"Command Post"` | Must be a ground unit |
| `WE.IADSAAAType` | `"ZSU-23-4 Shilka"` | Optional |
| `WE.IADSPlacementMin` | `6000` | Meters from anchor |
| `WE.IADSPlacementMax` | `18000` | Meters from anchor |
| `WE.IADSRunwayMinDistance` | `3000` | Keep sites off runways |
| `WE.IADSMaxSlope` | `5` | Flatness tolerance |
| `WE.IADSDurationSeconds` | `1800` | Window length |
| `WE.IADSRetaliationEnabled` | `true` | Spawn strike on timeout |
| `WE.IADSRetaliationTypes` | `{ "Su-24M" }` | Verify DCS names |
| `WE.IADSRetaliationCount` | `2` | |
| `WE.IADSMarkMode` | `"area"` | `"area"` or `"exact"` |

**Status line:** `IADS: <n> site(s) active near <area>, <seconds> remaining.`

**Sound:** `attn_iads.ogg`.

**Performance notes**

- Place sites once at spawn; do not re-query terrain every tick.
- Use `S_EVENT_DEAD` for win detection instead of scanning all groups.
- The deadline tick can be 10 s; IADS does not need per-second updates.

**DCS/Lua risks**

- SAM AI emission behavior is controlled by DCS and may vary; win on unit death,
  not on radar state.
- Some SAM types may not be available on all maps/mods; fall back to a default
  type or cancel cleanly.
- Ensure the command post is a ground unit, not a static object.

**Implementation checklist**

- [ ] Add module + delimiters + registry entry.
- [ ] Add config keys.
- [ ] Implement site placement with land/flat/runway checks.
- [ ] Implement spawn, state, handler, deadline tick.
- [ ] Add status line.
- [ ] Add sound asset.
- [ ] Build + DCS test (success, timeout, no suitable location).
- [ ] Update docs/changelog.

**Acceptance criteria**

- Sites spawn on land, away from runways, at valid offsets.
- Destroying every tracked unit produces success and clears state.
- Timeout produces the configured retaliation/failure exactly once.
- No duplicate names across repeated runs.
- The deadline tick stops after the event ends.

---

### 4.3 `CSAR` — Downed Pilot Recovery

**Status:** `READY` after Phase 0 + `WE.countUnitsInRadius`  
**Module:** `includes/event_csar.lua`  
**Spawn function:** `WE.EVENT.CSAR()`  
**Handler:** `WE.EVENT.CSAREVENT`  
**Complexity:** Medium

**Pitch:** A friendly aircrew is down behind enemy lines. Blue must locate and
recover them by helicopter before red search patrols capture them.

**Why it works in multiplayer:** A helicopter crew performs the pickup while
fixed-wing players escort, suppress patrols, and keep red air away. It is tense,
communication-heavy, and gives helicopters a real objective.

**Dynamic placement**

- Pick a random blue airdrome as the reference point.
- Choose a land point 15–40 km away, biased toward red territory.
- Spawn the pilot as a non-drivable ground unit (e.g. `Soldier M4 GRG`).
- Add an approximate F10 mark or smoke/beacon.
- Spawn 2–3 red search groups (infantry + BTR) 2–4 km away, moving toward the
  pilot.
- Timer: 10–15 minutes.

**State schema**

```lua
WE.currentCSAREvent = {
    point = { x = 0, y = 0, z = 0 },
    pilotName = "CSAR_Pilot",
    pilotGroupId = 0,
    searchUnitNames = { ["CSAR_Search_1"] = true, ... },
    searchGroupIds = { ... },
    spawnedAt = 0,
    endsAt = 0,
    markId = 0,
    recovered = false,
}
```

**Win condition**

- A **blue helicopter** is within `WE.CSARPickupRadius` of the pilot, is not in
  the air (or below the speed threshold), and remains there for
  `WE.CSARPickupHoldSeconds`.
- On success: despawn the pilot, announce recovery, clear state.

**Failure condition and consequence**

- Timer expires, the pilot is killed (`S_EVENT_DEAD`), or a red ground unit gets
  within `WE.CSARCaptureRadius` of the pilot.
- On failure: announce capture/loss and clear state. Optionally spawn a red
  infantry group at the pilot position.

**Handlers and tick**

- `WE.EVENT.CSAREVENT:onEvent`:
  - Only `S_EVENT_DEAD`.
  - If the pilot dies → failure.
  - If a red search unit dies, remove it from tracking (does not end the event).
- `WE.csarTick` every 2 s:
  - Check blue helicopter proximity/pickup hold.
  - Check red ground unit capture radius.
  - Check timeout.
  - Return `now + 2` while active, `nil` when finished.

**Config**

| Key | Default | Notes |
|---|---|---|
| `WE.CSARPilotCountry` | `country.id.USA` | Blue/player coalition |
| `WE.CSARPilotType` | `"Soldier M4 GRG"` | Verify DCS name |
| `WE.CSARSearchCountry` | `country.id.RUSSIA` | Red search teams |
| `WE.CSARSearchTypes` | `{ "Infantry AK", "BTR-80" }` | |
| `WE.CSARSearchCount` | `3` | Groups or squads |
| `WE.CSARMinDistanceFromBlueBase` | `15000` | Meters |
| `WE.CSARMaxDistanceFromBlueBase` | `40000` | Meters |
| `WE.CSARPickupRadius` | `150` | Meters |
| `WE.CSARPickupHoldSeconds` | `20` | Seconds |
| `WE.CSARCaptureRadius` | `100` | Red capture radius |
| `WE.CSARDurationSeconds` | `900` | 15 minutes |

**Status line:** `CSAR: pilot down near <area>, <seconds> remaining.`

**Sound:** `attn_csar.ogg`.

**Performance notes**

- Scan only `coalition.getGroups(coalition.side.BLUE,
  Group.Category.HELICOPTER)` for pickup checks.
- For red capture checks, scan only `RED` / `Group.Category.GROUND`.
- Use `Unit.getByName(pilotName)` rather than scanning for the pilot.

**DCS/Lua risks**

- The pilot unit may shoot at red patrols; set low skill and, if possible, ROE
  hold fire. If that is unreliable, accept it as a last stand.
- AI search groups may path poorly; keep spawn points on flat land and test.
- Helicopter “landed” detection: use `not helo:inAir()` plus a low-speed check
  if available.
- Do not rely on AI cargo loading/unloading; despawn the pilot on recovery.

**Implementation checklist**

- [ ] Add module + delimiters + registry entry.
- [ ] Add config keys.
- [ ] Implement pilot/search spawn and state.
- [ ] Implement handler + 2 s tick.
- [ ] Add status line.
- [ ] Add sound asset.
- [ ] Build + DCS test (pickup, capture, timeout, pilot killed).
- [ ] Update docs/changelog.

**Acceptance criteria**

- A blue helicopter can recover the pilot and get a success message.
- Red units can capture/kill the pilot and trigger failure.
- Timeout clears the event and removes marks.
- Repeated runs produce unique names.
- The tick stops after the event ends.

---

### 4.4 `BASE_DEFENSE` — Airbase Assault

**Status:** `READY` after Phase 0 + wave scheduler helper  
**Module:** `includes/event_basedefense.lua`  
**Spawn function:** `WE.EVENT.BASE_DEFENSE()`  
**Handler:** `WE.EVENT.BASEDEFENSEEVENT`  
**Complexity:** Medium–High

**Pitch:** Red launches a multi-wave assault on a blue airbase. Blue must hold
the base and destroy the attackers.

**Why it works in multiplayer:** CAP fights helicopter/air waves, CAS engages
armor, and ground/JTAC players coordinate base defense. Everyone shares the same
failure state: losing the base.

**Dynamic placement**

- Pick a **blue** airdrome as the defended base.
- Pick 2–3 land staging points 15–25 km away.
- Spawn waves at configured times, each with a route toward the base.
- Announce wave timing and keep the base marked on F10.

**Spawn plan**

Suggested waves:

| Wave | Time | Composition |
|---|---|---|
| 1 | 0 min | 3× T-72B3, 3× BMP-2, 1× ZSU-23-4 Shilka |
| 2 | 3 min | 2× Mi-8MT (attack/transport) or 4× BTR-80 + infantry |
| 3 | 6 min | 4× T-72B3, 3× BTR-80, 2× 2S1 Gvozdika |

> Reliability note: DCS AI cargo unloading is unreliable. Prefer treating
> helicopters as attack units, or spawn infantry directly at a secondary landing
> point on a timer instead of relying on AI unload.

**State schema**

```lua
WE.currentBaseDefenseEvent = {
    airbase = Airbase,
    basePoint = { x = 0, y = 0, z = 0 },
    waves = {
        { index = 1, spawnedAt = 0, unitNames = { ... }, groups = { ... } },
        ...
    },
    unitNames = { ... },
    groups = { ... },
    spawnedAt = 0,
    endsAt = 0,
    captureStartedAt = nil,
    markId = 0,
    failed = false,
}
```

**Handlers and tick**

- `WE.EVENT.BASEDEFENSEEVENT:onEvent`:
  - Only `S_EVENT_DEAD`.
  - Remove dead units from tracking.
  - If all waves have spawned and all tracked units are dead → success.
- `WE.baseDefenseTick` every 2–5 s:
  - Spawn the next wave when its time arrives.
  - Count red ground units within `WE.BaseDefenseCaptureRadius` of the base.
  - If red units are present, start/continue `captureStartedAt`; if they hold for
    `WE.BaseDefenseCaptureHoldSeconds`, fail.
  - If the timer expires:
    - if red units are inside the capture radius → failure;
    - otherwise → success.
  - Return `now + 5` while active, `nil` when finished.

**Win condition**

- All waves spawned and all attacker units destroyed; or the defense timer
  expires with no red ground units inside the capture radius.

**Failure condition and consequence**

- Red units hold the capture radius for the configured duration, or the timer
  expires with red units inside the radius.
- On failure: announce the base is overrun, spawn a red garrison at the base,
  and optionally set `WE.BaseDefenseCaptureBaseOnFailure = true` to flip the
  airbase to red. Default: **false** to avoid breaking missions unexpectedly.

**Config**

| Key | Default | Notes |
|---|---|---|
| `WE.BaseDefenseCountry` | `country.id.RUSSIA` | Spawn country |
| `WE.BaseDefenseDurationSeconds` | `900` | 15 minutes |
| `WE.BaseDefenseCaptureRadius` | `1200` | Base capture radius |
| `WE.BaseDefenseCaptureHoldSeconds` | `60` | Red hold time |
| `WE.BaseDefenseWaveIntervalSeconds` | `180` | If not using explicit times |
| `WE.BaseDefenseStagingMin` | `15000` | Meters from base |
| `WE.BaseDefenseStagingMax` | `25000` | Meters from base |
| `WE.BaseDefenseWaves` | see wave table | Types/counts/times |
| `WE.BaseDefenseCaptureBaseOnFailure` | `false` | Flip base to red |
| `WE.BaseDefenseMaxUnitsPerWave` | `12` | Performance guard |

**Status line:** `Base Defense: <base> under attack, wave <n>, <seconds>
remaining.`

**Sound:** `attn_basedefense.ogg`.

**Performance notes**

- One tick every 5 s; spawn each wave only once.
- Track group IDs/unit names, not all red groups.
- For capture checks, scan only `RED` / `GROUND`.
- Keep total attackers bounded; DCS AI pathing and CPU cost grow quickly.

**DCS/Lua risks**

- Many ground units can be expensive; cap wave size.
- Ground AI pathing to a base may fail on rough terrain; test staging points.
- Airbase capture (`setCoalition`) can be disruptive; keep it opt-in.
- Blue base selection should prefer a base players actually use.

**Implementation checklist**

- [ ] Add module + delimiters + registry entry.
- [ ] Add config keys and wave table.
- [ ] Implement base/staging selection.
- [ ] Implement wave spawning and state.
- [ ] Implement handler + capture tick.
- [ ] Add status line.
- [ ] Add sound asset.
- [ ] Build + DCS test (all waves killed, base captured, timeout).
- [ ] Update docs/changelog.

**Acceptance criteria**

- Waves spawn at their configured times and move toward the base.
- Destroying all attackers produces success.
- Red units holding the capture radius produce failure.
- Timer expiry resolves correctly and clears state.
- Repeated runs produce unique names and no duplicate groups.
- The tick stops after the event ends.

---

### 4.5 `FARP_CAPTURE` — Seize and Hold

**Status:** `READY` after Phase 0 + capture/zone helper  
**Module:** `includes/event_farpcapture.lua`  
**Spawn function:** `WE.EVENT.FARP_CAPTURE()`  
**Handler:** `WE.EVENT.FARPCAPTUREEVENT`  
**Complexity:** High

**Pitch:** A neutral forward arming/refuelling point becomes the objective. Blue
must land a helicopter with troops, capture it, and hold it against red
counterattacks.

**Why it works in multiplayer:** Helicopter transport is essential, CAS
suppresses counterattacks, CAP protects the airspace, and ground-attack players
shape the battlefield. It gives helicopter pilots a real objective beyond VIP
escort.

**Dynamic placement**

- Pick a blue airdrome as the reference point.
- Choose a remote land point 10–20 km away; reject water/pavement/steep terrain.
- Spawn a neutral FARP marker/flag and an F10 objective mark.
- Capture condition: a blue helicopter lands within
  `WE.FARPCaptureCaptureRadius` and stays for
  `WE.FARPCaptureCaptureHoldSeconds`, or blue ground units occupy the zone.
- Once captured: switch the marker/flag to blue and start the hold timer.
- Red counterattack waves spawn from nearby staging points on a timer.

**State schema**

```lua
WE.currentFARPCaptureEvent = {
    point = { x = 0, y = 0, z = 0 },
    farpName = "FARP Alpha",
    captured = false,
    capturedAt = nil,
    endsAt = nil,
    waveIndex = 0,
    redWaveGroups = {},
    redUnitNames = {},
    markId = 0,
    recaptureStartedAt = nil,
    failed = false,
}
```

**Capture and hold logic**

- Before capture:
  - Check for a blue helicopter within `CaptureRadius`, `not inAir()`, held for
    `CaptureHoldSeconds`.
  - Or check for blue ground units within `CaptureRadius` for the same hold
    time.
  - On capture: set `captured = true`, `capturedAt = now`,
    `endsAt = now + WE.FARPCaptureHoldSeconds`, update the F10 mark/flag, and
    announce.
- After capture:
  - Spawn counterattack waves at configured intervals.
  - Check for red ground units inside `CaptureRadius`; if red presence is
    unopposed by blue units, accumulate `recaptureStartedAt`.
  - If red holds for `WE.FARPCaptureRecaptureHoldSeconds` → failure.
  - If `now >= endsAt` and not recaptured → success.

**Win condition:** hold the FARP for `WE.FARPCaptureHoldSeconds` after capture.

**Failure condition and consequence**

- Red units recapture the zone, or the hold timer expires without blue presence.
- On failure: announce red control, remove the blue marker, and optionally spawn
  a red garrison at the FARP.

**Handlers and tick**

- `WE.EVENT.FARPCAPTUREEVENT:onEvent`:
  - Only `S_EVENT_DEAD`.
  - Remove dead red wave units from tracking.
  - If a FARP static/unit can be destroyed, fail on its death (optional).
- `WE.farpCaptureTick` every 2–5 s:
  - Capture check / hold check / recapture check.
  - Spawn counterattack waves.
  - Resolve success/failure.
  - Return `now + 5` while active, `nil` when finished.

**Config**

| Key | Default | Notes |
|---|---|---|
| `WE.FARPCaptureCountry` | `country.id.RUSSIA` | Counterattack country |
| `WE.FARPCaptureHoldSeconds` | `600` | 10 minutes |
| `WE.FARPCaptureCaptureRadius` | `150` | Meters |
| `WE.FARPCaptureCaptureHoldSeconds` | `30` | Seconds |
| `WE.FARPCaptureBluePresenceRadius` | `300` | Hold check radius |
| `WE.FARPCaptureRecaptureHoldSeconds` | `60` | Red hold time |
| `WE.FARPCaptureWaveIntervalSeconds` | `180` | Counterattack cadence |
| `WE.FARPCaptureWaves` | see below | Types/counts |
| `WE.FARPCaptureFARPMinDistance` | `10000` | From blue base |
| `WE.FARPCaptureFARPMaxDistance` | `20000` | From blue base |
| `WE.FARPCaptureMarkerRadius` | `300` | F10 mark radius |
| `WE.FARPCaptureFARPType` | `"FARP Tent"` | Verify DCS static name |

Suggested counterattack waves:

| Wave | Composition |
|---|---|
| 1 | 2× BTR-80 + 6× Infantry AK |
| 2 | 3× BMP-2 + 4× Infantry AK |
| 3 | 3× T-72B3 + 2× ZSU-23-4 Shilka |

**Status line:** `FARP Capture: <name> <uncaptured/captured>, <seconds>
remaining.`

**Sound:** `attn_farp.ogg`.

**Performance notes**

- Use one 5 s tick for capture/hold/recapture; no per-frame checks.
- Scan only blue helicopters/ground and red ground in the relevant radius.
- Keep counterattack waves bounded (maximum 3 waves, ~10 units each).
- Cache the FARP point and marker ID; do not recompute terrain each tick.

**DCS/Lua risks**

- Player-dropped troops/CTLD are not part of the current framework. Use
  proximity/landing detection rather than relying on cargo APIs.
- Static FARP objects may not be destructible or may not fire `S_EVENT_DEAD`;
  treat the zone, not the object, as the objective unless using a ground unit.
- Helicopter landing detection should include `not helo:inAir()` and optionally
  a speed threshold.
- Recapture logic must distinguish “red present” from “blue present”; define
  clearly and test both.

**Implementation checklist**

- [ ] Add module + delimiters + registry entry.
- [ ] Add config keys and wave table.
- [ ] Implement FARP placement and marker.
- [ ] Implement capture/hold/recapture tick.
- [ ] Implement counterattack waves and handler.
- [ ] Add status line.
- [ ] Add sound asset.
- [ ] Build + DCS test (capture, hold success, recapture failure, no valid
  location).
- [ ] Update docs/changelog.

**Acceptance criteria**

- A blue helicopter can capture the FARP and start the hold timer.
- Red counterattacks spawn and can recapture the zone.
- Holding for the full timer produces success.
- Recapture or timeout produces failure.
- Repeated runs produce unique names and no duplicate marks.
- The tick stops after the event ends.

---

## 5. Recommended development sequence

### Phase 0 — Shared refactor (no gameplay change)

- Move generic helpers from `event_stronghold.lua` to `utility.lua`.
- Add `WE.getNextMarkId()` and refactor Stronghold marks.
- Add `WE.countUnitsInRadius` and `WE.areAllUnitsDead`.
- Optional: add `WE.registerEventStatus` and refactor status output.
- Build and smoke-test Stronghold.

### Phase 1 — `CONVOY`

- Reuses ground helpers, route spawning, and the all-dead check.
- Adds moving-target and arrival detection.
- Lowest risk of the five; good first event.

### Phase 2 — `IADS`

- Adds multi-site placement, flat/runway checks, and timeout retaliation.
- Reuses the same all-dead check and mark allocator.

### Phase 3 — `CSAR`

- Adds zone/helo proximity checks (`WE.countUnitsInRadius`).
- Exercises `Unit.getByName`, capture radius, and pickup hold logic.

### Phase 4 — `BASE_DEFENSE`

- Adds the wave scheduler, staged spawns, and base capture-zone logic.
- Highest unit count; verify performance before merging.

### Phase 5 — `FARP_CAPTURE`

- Combines ground placement, helicopter proximity, capture/hold, wave spawning,
  and recapture logic.
- Do this last, after the earlier events have proven the shared helpers.

---

## 6. Definition of done (per event)

An event is complete only when all of these are true:

- [ ] Module exists with the standard delimiters.
- [ ] Registry entry added before `init.lua`.
- [ ] `WE.EnabledEvents` and `WE.EventOrder` updated.
- [ ] Spawn function, state, handler, and tick implemented.
- [ ] Unique group/unit names and real IDs after `coalition.addGroup`.
- [ ] F10 marks use `WE.getNextMarkId()` and are removed on end.
- [ ] All timers stop when the event ends.
- [ ] Status report added.
- [ ] Sound asset added (`attn_<event>.ogg`) or sound intentionally omitted.
- [ ] `build.ps1` completes successfully.
- [ ] In-game test passes on at least one map.
- [ ] Failure paths tested: timeout, no valid location, all units dead,
  repeated spawn.
- [ ] `README.md`, `SITUATION_BRIEFING.md`, and `changelog.md` updated.
- [ ] This design file updated with final config names and status.

### Manual test matrix

| Scenario | Expected result |
|---|---|
| Event enabled, no valid location | Clean cancel message, no error spam, `WE.is_active` stays 0 |
| Event spawns | Units/groups unique, state set, mark placed, sound plays |
| Success path | Success text, state cleared, mark removed, tick stops |
| Failure/timeout path | Failure text, consequence applied, state cleared, tick stops |
| Repeated spawn after failure | New unique names, no collision with survivors |
| Another event active | Blocked by `WE.is_active` with clear message |
| Player reslots during event | Radio menu rebuilds; event state unaffected |
| `dcs.log` review | Only expected `World Event - ` lines; no Lua errors |

---

## 7. DCS/Lua pitfalls to remember

- `coalition.addGroup` may reassign requested group IDs; always use the returned
  `Group:getID()`.
- `S_EVENT_DEAD` is reliable for units; static objects are not a safe win
  condition.
- `land.getSurfaceType` expects a 2D point `{ x = east, y = north }`.
- `Airbase:getRunways()` can return `nil` or throw; wrap in `pcall`.
- Ground group tables use `x` = east, `y` = north at group and waypoint level.
- DCS Lua is 5.1: no `goto`, no bitwise operators, no `table.unpack` (use
  `unpack`).
- Event handlers receive **every** world event; the first checks must be cheap.
- Do not spam `outText`; use whole-minute countdowns and end-state messages.
- Avoid AI cargo/load/unload dependencies; the legacy cargo code in
  `utility.lua` is not wired up.
- Keep event modules independent: share helpers through `utility.lua`, not by
  calling another event module's private state.

---

## 8. Documentation updates required per event

When an event ships:

1. `README.md` — add the event to the Events section, configuration, and radio
   menu behavior if needed.
2. `SITUATION_BRIEFING.md` — add a player-facing threat/opportunity description
   with win/fail conditions and multiplayer guidance.
3. `changelog.md` — add the event under the next version.
4. `AGENTS.md` — update the event list, state names, config keys, and known
   issues if the architecture changed.
5. `EVENT_DESIGN.md` — change the status to `DONE` and record any deviations
   from this design.
