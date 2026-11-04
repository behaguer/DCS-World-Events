# 04: Placement resilience and partial networks

**What to build:** A **site** that cannot be placed re-rolls up to eight candidates before being skipped. A network with some failed sites still spawns the remaining sites and reports only those that placed. Only zero placed sites cancels the event, and that cancel destroys anything already spawned. Attempt and spacing values come from config.

**Blocked by:** 03

**Status:** resolved

- [ ] Each site gets up to eight candidate attempts before it is skipped.
- [ ] A network with failed sites still spawns at least one site and reports only the sites that placed.
- [ ] When no site places, the event cancels cleanly and destroys all partial spawns.
- [ ] Attempt count, placement band, and spacing minima are config-driven.
- [ ] A cancelled partial spawn leaves no mark, tick, active state, or global lock behind.
