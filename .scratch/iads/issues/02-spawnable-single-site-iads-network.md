# 02: Spawnable single-site IADS network

**What to build:** Choosing IADS from the Spawn Event submenu creates a legal network anchored on a Red airdrome, containing a single Tor **site** and a Bunker **command node**. Spawn places one area SIGINT mark, plays the IADS alert, shows a status line, and starts a 900-second clock. Destroying every **tracked unit** announces success; timeout announces failure, leaves survivors alive, removes the mark, stops the tick, and releases the global lock. No legal anchor or site cancels cleanly. The event is single-instance.

**Blocked by:** 01

**Status:** resolved

- [ ] IADS appears in Spawn Event after Convoy, is blocked while another event is active, and blocks other events while it runs.
- [ ] Spawn places a Tor site and a Bunker command node on legal land near a Red airdrome, never a Blue airdrome.
- [ ] Spawn plays the IADS alert and places exactly one area mark labelled for the area.
- [ ] Event Status reports the area, live site count, and remaining time; whole-minute countdown is announced.
- [ ] Killing every tracked unit announces success exactly once.
- [ ] Timeout at 900 seconds announces failure exactly once and leaves surviving units alive.
- [ ] On end the mark is removed, the tick is stopped, the active state is cleared, and the global lock is released.
- [ ] No legal anchor or site cancels with a clear message and no leaked units, marks, or timers.
- [ ] A config block exposes site count, duration, placement band, mark mode, sound, and enablement.
