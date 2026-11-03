# Spec: IADS — SAM Network Takedown

Status: ready-for-agent

## Problem Statement

Server operators can already spawn VIP escort, base attack, stronghold, and convoy events, but none of them asks Blue to find and dismantle an integrated air-defence network. SEAD/DEAD flights have no mission that rewards target prioritisation and threat avoidance, CAP has nothing to protect while the strike package works, and the Red side never fields a dispersed, mutually supporting air-defence problem. Players who want a coordinated, multi-role objective have to build it by hand in the mission editor, and it cannot be re-spawned dynamically mid-mission.

## Solution

Add an **IADS** event to the framework. When a player with radio access spawns it, the framework selects a Red airdrome as the **anchor**, places one **network** of three SAM **sites**, one early-warning radar, and a **command node** around it, marks the general **area** on the F10 map, and starts a 15-minute clock. Blue must destroy every tracked unit to succeed. If the clock expires, the event fails, the surviving sites stay active, and the airspace remains contested. The event is single-instance, so it cannot overlap another event, and it cleans up its mark, timer, and global lock when it ends.

## User Stories

1. As a Blue SEAD/DEAD pilot, I want to spawn a SAM-network mission from the radio menu, so that I have a target set that rewards threat avoidance and prioritisation instead of a single bombing run.
2. As a Blue strike pilot, I want a network of dispersed SAM sites, so that planning an attack route matters and one lucky bomb does not finish the mission.
3. As a Blue CAP pilot, I want a network objective that keeps Blue aircraft in one area, so that Red fighters have a reason to contest the airspace and I have someone to protect.
4. As a Blue recon or JTAC player, I want only a general SIGINT area marked on the F10 map, so that locating the actual sites is part of the mission rather than a freebie.
5. As a Blue player, I want a success message when every tracked unit dies, so that the whole server knows the network has been dismantled.
6. As a Blue player, I want a failure message when the clock expires, so that the outcome is clear even though the surviving sites remain dangerous.
7. As a Blue player, I want the surviving SAMs to remain active after a timeout, so that failure has a lasting consequence instead of the threats simply vanishing.
8. As a Blue player, I want the network placed near a Red airbase that was chosen dynamically, so that the event works on any map without hand-authored coordinates.
9. As a Blue player, I want the network never to spawn on a Blue airbase or on water or steep terrain, so that the fight is fair and the units behave correctly.
10. As a Blue player, I want the network's sites spaced apart, so that they are a real network rather than a single cluster.
11. As a Blue player, I want Kub sites to include their radar and launchers, Buk sites to include their command, radar, and launcher vehicles, and Tor sites to be self-contained, so that every site is a functional threat.
12. As a Blue player, I want the network to include an early-warning radar, so that SEAD has a high-value support target as well as launchers.
13. As a Blue player, I want the command node to be a destructible bunker, so that destroying it is a meaningful objective and its death is reliably detected.
14. As a Blue player, I want the SAM crews to be a meaningful but beatable difficulty, so that the event is challenging without being a wall.
15. As a server operator, I want the event to be single-instance, so that it cannot run at the same time as a stronghold, convoy, VIP escort, or base attack.
16. As a server operator, I want the network to run for 15 minutes, so that there is time for a coordinated multi-flight attack without the mission dragging.
17. As a server operator, I want a clean cancellation when no valid anchor or site location exists, so that a bad map never leaves orphaned units, marks, or a stuck global lock.
18. As a server operator, I want a partial network to spawn when only some sites can be placed, so that an awkward coastline or mountain range does not cancel the whole event.
19. As a server operator, I want repeated spawns to use unique group and unit names, so that a new network never collides with survivors from an earlier run.
20. As a server operator, I want the network to avoid airfields that the event is not anchored to, so that SAMs do not appear on top of a player base.
21. As a server operator, I want Event Status to report the number of active sites and the time remaining, so that players can check progress without asking.
22. As a server operator, I want a whole-minute countdown, so that players get progress updates without text spam.
23. As an event designer, I want the IADS key enabled by default and ordered after Convoy in the Spawn Event submenu, so that the new event is discoverable like the existing ones.
24. As an event designer, I want every tuning value exposed as config, so that I can change site count, difficulty, placement band, and clock length without editing logic.
25. As an event designer, I want the event to reuse the shared land, flatness, runway, mark, and all-dead helpers, so that behaviour stays consistent with the other events.
26. As a maintainer, I want the IADS module to follow the existing event-module pattern, so that the codebase stays uniform and the build registry remains predictable.
27. As a maintainer, I want the event to be documented in the README, situation briefing, changelog, design backlog, and agent notes, so that players and future agents can find the behaviour and config.
28. As a player, I want an alert sound on spawn, so that the event is noticeable in a busy multiplayer session.
29. As a player, I want the F10 area mark removed when the event ends, so that the map is not littered with stale objectives.
30. As a player, I want the event to stop its timer when it ends, so that a finished network cannot keep announcing or fail twice.

## Implementation Decisions

- **New event module.** Add an IADS event module following the standard delimiter and load-order conventions, registered before the init module so its event handler exists at load time. The module key is `IADS`; the spawn function is `WE.EVENT.IADS`; the handler table is `WE.EVENT.IADSEVENT`; and the status provider is registered through `WE.registerEventStatus("IADS", ...)` rather than editing the radio menu directly.
- **Single-instance state.** The event keeps one active network in `WE.currentIADSEvent` and a per-spawn counter in `WE.iadsSpawnCounter`. It sets `WE.is_active` while running and clears it only on end. It is gated exactly like VIP Escort and Base Attack: if another event is active, the spawn cancels with a player-facing message.
- **Anchor selection.** Choose the anchor from Red airdromes, falling back to neutral airdromes only when no Red airdrome exists, and never from Blue airdromes. The anchor's name is the player-facing **area**. If no legal anchor exists, cancel cleanly.
- **Placement rules.** Candidate site and radar points sit 6000–18000 m from the anchor; must be on land, flat to within a 5 m height difference, at least 3000 m from the anchor's runways, at least 3000 m from every already-placed site, and at least 5000 m from any Blue airdrome. Each site gets up to 8 candidate attempts. Points that fail are re-rolled; a site that still fails is skipped, and the network proceeds with the sites that did place. If no site places, the event cancels and destroys anything already spawned.
- **Network composition.** Three sites are chosen at random from `{Kub, Buk, Tor}` with repeats allowed. Each site is a single functional group: Kub is one `Kub 1S91 str` plus two `Kub 2P25 ln`; Buk is one `SA-11 Buk CC 9S470M1`, one `SA-11 Buk SR 9S18M1`, and one `SA-11 Buk LN 9A310M1`; Tor is one `Tor 9A331`. One `55G6 EWR` is placed independently in the same band, and one `Bunker` is placed at the anchor as the command node.
- **Difficulty.** All network units spawn at the `High` skill level. The shared ground-unit builder gains an optional skill argument that defaults to the current `Excellent` behaviour, keeping every other event unchanged.
- **Tracked units and win condition.** Every spawned network unit is a **tracked unit**. The event listens for `S_EVENT_DEAD`, ignores events that do not match a tracked unit, and succeeds when `WE.areAllUnitsDead` reports that the whole tracked set is dead. There is no decapitation shortcut: the command node is required, but not sufficient on its own.
- **Timeout.** The network runs for 900 seconds. On expiry the event fails, announces the failure, leaves every surviving site alive, removes the F10 mark, stops the tick, clears the active state, and releases the global lock. No retaliation strike package is spawned.
- **Tick.** Use one scheduled tick every 10 seconds that announces the remaining whole minutes when the minute value changes, checks for timeout, and returns `nil` once the event has ended. The tick is started once at spawn.
- **F10 disclosure.** Place one area mark at the anchor labelled as suspected SIGINT activity near the area, using the shared unique mark-id allocator. A config option may select exact per-site marks, but the default is area only. Remove the mark on end.
- **Status line.** The status provider returns a single line naming the area, the number of sites still alive, and the seconds remaining.
- **Naming and cleanup.** Group and unit names are prefixed with `IADS_` and suffixed with the per-spawn id so repeat runs cannot collide. On cancel, partially spawned groups are destroyed. On success or timeout, the mark is removed and the tick stops.
- **Config surface.** Add an `WE.IADS*` config block covering country, site count, SAM type list, skill, radar type, command-node type, placement band, runway/Blue-base/spacing minima, flatness tolerance, duration, tick interval, per-site attempts, mark mode, and enablement. Add `IADS` to the enabled-events table and to the event order immediately after `CONVOY`.
- **Sound.** Add an IADS alert sound asset, using a placeholder copy of the existing base-attack alert until a dedicated asset exists, and play it inside the spawn function.
- **Documentation.** On ship, update the player-facing README, the situation briefing, the changelog, the event design backlog (status and final config), and the agent notes' event table and config summary.

## Testing Decisions

- **What makes a good test.** Test external, player-visible behaviour: whether the event spawns, whether the network is placed legally, whether success and failure resolve once, whether state and the global lock are released, whether names are unique across runs, and whether the mark and timer are cleaned up. Do not test private helpers unless they are promoted to shared utilities.
- **No automated seam.** The repo has no Lua interpreter, no test framework, and no test files; its documented verification path is compile, run in DCS, and inspect `dcs.log`. Manual testing continues, and the spec records the matrix rather than inventing a harness.
- **Modules covered.** The compiled framework as a whole, invoked from the radio menu in a sample mission, with the IADS module observed through player text, F10 marks, Event Status, and log output.
- **Build gate.** The build script must complete without Lua syntax errors, and the compiled artifact must not be hand-edited.
- **Manual test matrix.**
  - Event enabled and spawned with no valid anchor or site location: clean cancel message, no leaked groups or marks, global lock stays released.
  - Event spawned normally: three sites, one radar, and one command node exist; names are unique; the area mark and alert sound fire.
  - Partial placement: a map or anchor where a site cannot be placed still spawns the rest, with at least one site.
  - Success: killing every tracked unit produces one success message, clears state, removes the mark, and stops the tick.
  - Timeout: the failure fires once at 900 seconds, surviving sites remain alive, the mark is removed, and the state and lock are released.
  - Repeated spawn after success or timeout: new unique names, no collisions with survivors from the previous run.
  - Another event active: IADS is blocked with a clear message; IADS blocks the other events while it runs.
  - Placement legality: no site or radar on water, pavement, steep terrain, a Blue airbase, or inside the spacing minima.
  - F10 and status: only the area mark appears; Event Status reports live site count and remaining time.
  - Log review: only expected framework lines and no Lua errors.
- **Prior art.** The manual test matrix and definition of done in the event design backlog, plus the acceptance criteria recorded for Convoy and Stronghold, and the verification note in the agent notes that there is no test/lint/typecheck command.

## Out of Scope

- A Red retaliation strike package on timeout, including any AI air-spawn, tasking, or strike-target work.
- Exact per-site F10 marks as the default behaviour; this stays a config escape hatch only.
- Multiple concurrent IADS networks or overlapping with another active event.
- Any automated Lua test harness, interpreter install, or continuous integration.
- Modelling or asserting on DCS radar emission/engagement behaviour; success is decided by unit death.
- Capturing or flipping the anchor airbase, or any other territorial consequence.
- A dedicated recorded alert sound; only a placeholder copy is required.
- Changes to the radio menu tree, status menu layout, or other events.

## Further Notes

- Exact DCS unit type strings were verified against primary unit lists: `Kub 2P25 ln`, `Kub 1S91 str`, `SA-11 Buk LN 9A310M1`, `SA-11 Buk SR 9S18M1`, `SA-11 Buk CC 9S470M1`, `Tor 9A331`, `55G6 EWR`, and `Bunker`. The design backlog's earlier strings `"SA-6 Kub"`, `"SA-11 Buk"`, `"SA-15 Tor"`, `"EWR 55G6"`, and `"Command Post"` were wrong; `Command Post` is not a ground-unit type at all.
- A Kub launcher cannot engage without its radar in the same group, which is why Kub sites are multi-vehicle. Buk includes its command and search radar for normal coordinated engagement. Tor and the early-warning radar are self-contained.
- The framework's existing spawn-sound placeholder for the shared menu action is unrelated and out of scope; the IADS sound is played inside the event itself.
- `GLOSSARY.md` was created during design and defines **event**, **event instance**, **anchor**, **area**, **site**, **tracked unit**, **command node**, and **network**; use those terms in tickets and code comments.
- Remaining DCS risks: ground AI pathing is not involved because all network units are stationary; SAM behaviour is engine-controlled, so the win condition is death-based; some maps may lack enough flat land in the placement band, which the partial-network rule handles; total unit count stays bounded to keep AI cost reasonable.
