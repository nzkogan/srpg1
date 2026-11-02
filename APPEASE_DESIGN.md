# Appeasing a Named mount -- design and status

Status: **implemented** (first pass), 2026-11-11. NAMED_DEFECTIONS_DESIGN.md listed this as not built: "a way to keep the creature by appeasing it". Canon also wants the signposting before a defection. This builds both for the three Named mounts that can leave (the Simurgh, the Karkadann, the Anzu).

## The rule

- **Signpost.** Each mount that can leave has a `leaves_warning` in canon, shown in the barracks Mount mode on the mount's own entry: what the creature is watching for ("It guards the doves of the Ashland, and will not carry a company that writes the Ashland off or takes the crown's orders.").
- **Offering.** In the same mode, an extra line for each such mount in the company: "Appease the Karkadann: grain for the doves, laid at its stall (300 gold)". Enter pays `appease_cost` (300 gold) and sets a **pledge**. Only one stands at a time; it is saved with the mounts.
- **A pledge holds back one departure.** When the creature's trigger fires (the Ashland written off, the crown's writ, a literacy it lacks, the feather changing hands), the pledge is spent instead: the creature stays and the map's win screen (or the barracks message, for a hand-off) shows its `appease_line`. The triggers happen once, so a mount with two triggers (the Karkadann: the write-off and the writ) needs a second offering for the second.
- A pledge is **not** spent when the trigger would not have taken it anyway (Ricberta riding the Anzu), when the first hand takes the Simurgh back, or when nothing happens. A creature lost with its rider takes its pledge with it.
- When a pledge holds the Simurgh's hand-off, the **new rider becomes the holder of the feather**; handing her on again needs another offering.
- The Shadhavar, the Warhorse and the Huma have nothing to appease.

## Drafted guesses to confirm

- **The price (300 gold) and that gold is the currency.** It could instead be a deed, a mercy, a support rank or an item; the cost is one parameter (`prm_appease_cost`).
- **The signposts, gifts and lines** for all three creatures (my wording; yours to rewrite). The validator requires all three on every mount that can leave and none on the others.
- That one offering buys exactly one reprieve rather than ending the trigger for good.

## Not built

- A scene for the signposting or for the offering, and the creature reacting (hurt, grudging) in the next paralogue.
- A cheaper non-gold way, or a way to make amends once the creature has gone.
- A map-side signpost (a line in the briefing before the trigger map).

Tests: `tests/test_appeasement.gd` (32 checks, mutation-checked; the one equivalent survivor is the pledge cleanup in `_depart`, which a pledged mount can never reach). The validator's c07 checks the new columns and `appease_cost`.
