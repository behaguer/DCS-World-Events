# DCS-World-Events

A multiplayer event framework for DCS World. It spawns scripted objectives into a running
mission and resolves them against their own win and fail conditions.

## Language

**Event**:
A self-contained multiplayer objective the framework can spawn, track, and resolve.
_Avoid_: mission, scenario

**Event instance**:
One live run of an event, from spawn to resolution.
_Avoid_: mission, round

**Anchor**:
The location an event's objective is placed relative to.
_Avoid_: base, center

**Area**:
The player-facing name of an event's location, used in F10 marks and status lines.
_Avoid_: zone, sector

**Site**:
One functional SAM group with all of its component units, such as launcher, radar, and
command vehicle.
_Avoid_: battery, emplacement

**Tracked unit**:
Any spawned unit whose destruction counts toward an event's win condition.
_Avoid_: target, object

**Command node**:
An IADS network's bunker. Its destruction is required for success but is not sufficient on
its own.
_Avoid_: command post, HQ

**Network**:
The complete IADS objective: one anchor, its sites, its early-warning radar, and the command
node.
_Avoid_: system, grid
