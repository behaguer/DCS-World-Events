# SITUATION BRIEFING — WORLD EVENTS

Classification: UNCLASSIFIED
Prepared by: BS MYTH
Version: 0.1.0

---

## 1. SITUATION

Red forces are conducting three distinct types of operation across the theatre. Each is triggered on-demand and operates independently on any map. You will not know which event is active until it triggers — be prepared for anything.

One event at a time. When it's done, another can follow.

---

## 2. THREATS

### 2.1 VIP Escort Flight

What to expect: A C-130J transport ("RSD381 VIP") escorted by a 4-ship of MiG-29 Fulcrums.

Behaviour:
- The C-130 takes off first from a red airfield.
- 15 seconds later the MiG wing spawns behind it on the runway and takes off in formation.
- The flight transits at low level to a second red airfield.
- The MiGs stay close. They will break off to engage any threat within 60km, then return to the escort.

How to intercept:
- You'll be told the departure and destination airfields the moment it spawns.
- Get airborne fast — the transit is short.
- Focus fire on the C-130. The MiGs are dangerous but secondary.
- If the C-130 lands and shuts down engines, the mission is a failure.

Kill: C-130 destroyed.
Fail: C-130 lands safely.

---

### 2.2 Base Attack Strike Package

What to expect: 3x Su-25 Frogfoots ("ShAP") loaded for ground attack, escorted by 4x MiG-29 Fulcrums.

Behaviour:
- The strike package launches from a red airfield.
- They transit at safe altitude, then descend to the deck for a low-level attack run on a blue airfield.
- Engages anything on the ground at the target — vehicles, units, infrastructure.
- RTB to the same red airfield they launched from.
- The MiGs escort the Su-25s throughout, engaging threats within 60km.

How to intercept:
- You'll be told the red departure airfield and the blue target airfield on spawn.
- The attack is fast — get up and engage before they reach the target.
- Prioritise the Su-25s. Once they're in the attack run they're focused on the ground and vulnerable.
- If the Su-25s complete their attack run and return to base, the mission is a failure.

Kill: All Su-25s destroyed or driven off before they hit the target.
Fail: Su-25s successfully attack and RTB.

---

### 2.3 Stronghold

What to expect: A red fortified position — a bunker defended by 4x infantry and a Strela-10M3 SAM site.

Location: Placed at a random offset (2.5–4nm) from a red or neutral airfield. You'll be given the airfield name and a map mark.

Timer: 15 minutes from spawn. Countdown announced every 60 seconds.

Defence:
- Bunker — must be destroyed. This is the primary objective.
- Strela-10M3 — short-range SAM. Engage from beyond its envelope or suppress it first.
- 4x Infantry AK — spread around the bunker. Must all be eliminated.

Win condition: Everything destroyed before the timer hits zero.

Failure consequences:
- If the bunker was already destroyed when time runs out: remaining troops scatter. Partial success.
- If the bunker survives: the nearby airfield falls to red. It is immediately garrisoned with:
  - 3x T-72B3 main battle tanks
  - 2x BTR-80 armoured personnel carriers
  - 2x Strela-10M3 SAM sites
- The original bunker and defenders are removed. The airfield is now a red stronghold.

Multiple strongholds: Up to 5 can be active simultaneously. Each is tracked independently with its own timer and map mark. Airdromes already hosting a stronghold won't be picked again.

Kill: Bunker + all defenders destroyed within 15 minutes.
Fail: Timer expires with bunker intact — airfield captured.

---

## 3. RULES OF ENGAGEMENT

- All red aircraft and ground units are weapons free.
- Escorts will engage you if you threaten the formation — plan accordingly.
- Stronghold SAMs (Strela-10M3) are active and will engage inbound aircraft. Approach low or from outside their range.
- VIP and Base Attack MiG escorts use radar continuously and will visually acquire targets. Do not assume they haven't seen you.

---

## 4. COMMAND AND CONTROL

| | |
|---|---|
| Trigger | F10 Radio Menu > WorldEvents > Spawn Event |
| Status | F10 Radio Menu > WorldEvents > Event Status |
| Notifications | Text message to all players on spawn (airfield names, countdown) |
| Audio | Alert sound played on event trigger |
| Map Marks | Stronghold locations marked on F10 map, removed on completion |

---

## 5. NOTES

- Airfield selection is dynamic — it changes every time based on what's on the map. You may get familiar territory or somewhere you've never been.
- The VIP Wing only spawns at airfields with runways long enough for a C-130 (1,000m+). Small strips are excluded.
- Only one event type can be active at a time (exception: multiple strongholds).
- Events can be spawned repeatedly. There is no cooldown.
