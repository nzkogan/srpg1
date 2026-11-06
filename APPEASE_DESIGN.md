# Appeasing a Named mount -- design and status

Status: **implemented** (first pass), 2026-11-11; the vigil (the non-gold offering) added 2026-11-12 at your direction. NAMED_DEFECTIONS_DESIGN.md listed this as not built: "a way to keep the creature by appeasing it". Canon also wants the signposting before a defection. This builds both for the three Named mounts that can leave (the Simurgh, the Karkadann, the Anzu).

## The rule

- **Signpost.** Each mount that can leave has a `leaves_warning` in canon, shown in the barracks Mount mode on the mount's own entry: what the creature is watching for ("It guards the doves of the Ashland, and will not carry a company that writes the Ashland off or takes the crown's orders.").
- **Offering.** In the same mode, an extra line for each such mount in the company: "Appease the Karkadann: grain for the doves, laid at its stall (300 gold)". Enter pays `appease_cost` (300 gold) and sets a **pledge**. Only one stands at a time; it is saved with the mounts.
- **Vigil (no gold).** The other offering costs a **unit's availability**: with a unit selected, "Vigil for the Karkadann: Jost keeps watch over the doves through the night, sitting out the next chapter". Enter sets the same pledge, and that unit is **not deployed** (the map's roster skips them) until the next real chapter is **won**; then the win screen says "The vigil is over: Jost is back with the company." A flashback neither takes nor ends a vigil. It lasts through a lost attempt, a retry or a resumed battle, since the chapter has not been won. Rules: the company must keep `appease_vigil_company` (4) other fielded units free, the unit must be fielded and living and not already resting, and only one offering (gold or vigil) stands per creature. The resting list is saved with the mounts.
- **A pledge holds back one departure.** When the creature's trigger fires (the Ashland written off, the crown's writ, a literacy it lacks, the feather changing hands), the pledge is spent instead: the creature stays and the map's win screen (or the barracks message, for a hand-off) shows its `appease_line`. The triggers happen once, so a mount with two triggers (the Karkadann: the write-off and the writ) needs a second offering for the second.
- A pledge is **not** spent when the trigger would not have taken it anyway (Ricberta riding the Anzu), when the first hand takes the Simurgh back, or when nothing happens. A creature lost with its rider takes its pledge with it.
- When a pledge holds the Simurgh's hand-off, the **new rider becomes the holder of the feather**; handing her on again needs another offering.
- The Shadhavar, the Warhorse and the Huma have nothing to appease.

## Drafted guesses to confirm

- **The price (300 gold)** and the vigil's reading: the unit is unavailable for one chapter, anyone may keep it, and four others must remain. Whether it should instead be a *specific* unit (the rider, the deputy, the one with the matching support) is open.
- **The signposts, gifts and lines** for all three creatures (my wording; yours to rewrite). The validator requires all three on every mount that can leave and none on the others.
- That one offering buys exactly one reprieve rather than ending the trigger for good.

## Not built

- A scene for the signposting or for the offering, and the creature reacting (hurt, grudging) in the next paralogue.
- A way to make amends once the creature has gone; a vigil that only certain units can keep (the rider, a literate unit for the Anzu).
- A map-side signpost (a line in the briefing before the trigger map).

Tests: `tests/test_appeasement.gd` (54 checks, mutation-checked; the one equivalent survivor is the pledge cleanup in `_depart`, which a pledged mount can never reach). The validator's c07 checks the new columns and `appease_cost` / `appease_vigil_company`.
