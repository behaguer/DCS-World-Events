# 03: Full network composition and placement constraints

**What to build:** The network becomes three **sites** drawn at random from Kub, Buk, and Tor with repeats allowed, each a functional multi-vehicle group, plus an independent early-warning radar. Sites are spaced apart and kept clear of Blue airbases, and the **anchor** falls back from Red to neutral airdromes when necessary. All units are **tracked units** at `High` skill.

**Blocked by:** 02

**Status:** resolved

- [ ] Three sites spawn, chosen from the three SAM types with repeats allowed, each as one functional group (Kub radar plus launchers, Buk command plus radar plus launcher, Tor standalone).
- [ ] One early-warning radar spawns at its own validated point in the placement band.
- [ ] Sites are at least 3 km apart and at least 5 km from any Blue airdrome.
- [ ] The anchor is chosen from Red airdromes, neutral only when no Red airdrome exists, and never Blue.
- [ ] Every network unit spawns at `High` skill and is tracked.
- [ ] Death of any tracked unit counts toward the win; the command node is required but not sufficient.
- [ ] Group and unit names are unique per spawn so repeat runs cannot collide with survivors.
