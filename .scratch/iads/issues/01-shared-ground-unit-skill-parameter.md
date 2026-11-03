# 01: Shared ground-unit skill parameter

**What to build:** The shared stationary ground-unit builder accepts an optional skill level. Existing callers keep today's `Excellent` behaviour; the IADS event can request `High` crews without duplicating the builder.

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent

- [ ] The ground-unit builder accepts an optional skill level and applies it to the spawned unit.
- [ ] Omitting the skill keeps the current `Excellent` default at every existing call site.
- [ ] The compiled build succeeds with no Lua errors and no existing event behaviour changes.
- [ ] The new parameter is documented in the shared-helper annotations.
