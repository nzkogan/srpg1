# Named mounts that leave -- design and status

Status: **implemented** (first pass). Added 2026-10-30. Each Named creature in canon has a `defection_trigger`. A Named taken intact is now a mount (MOUNTS_DESIGN.md), so the
trigger can happen to the player: the creature leaves the company. Triggers are data (`mounts.leaves_when`, `leaves_map_id`, `leaves_unless_map_id`, `leaves_line`); the readings are mine.

| Creature | Canon trigger | Built as |
|---|---|---|
| **Simurgh** | "the feather changes hands; she arrives green and stops being green" | `handed_on`: she answers whoever holds the feather, so the unit who **first rode her** keeps her. Give her to a **different** rider while that one is still living and with you, and she is gone. The same hand may give her up and take her again; if the first holder is dead (or the rider fell and she was recovered) an heir takes her freely. The barracks tells you at once. |
| **Karkadann** | "turns the moment you threaten the doves; state orders and its terms are simply incompatible" | `map_won`: winning *The going rate* (`map_b15`) for the first time with the Cinder Track (`map_ct19`) never worked -- the **Ashland written off**, the same supply decision that sends Maren away. `writ`: the crown's **deputy is decided** (the writ, on either route): state orders. |
| **Anzu** | "someone demonstrates literacy you lack; ties to the hidden-literacy thread" | `literacy`: the first time **Ricberta's literacy is revealed** by a support (the same reveal the deputy tiebreak reads), the Anzu turns to the one who can read the register -- unless **Ricberta herself is riding it**. |
| **Shadhavar** | "uncontrolled by design" | none: it was never yours to lose. |
| **Huma** | "never defects because it was never yours" | none (not a mount). |

## What leaving means

The mount is removed from the stable (or from its rider) and **returns to the wild**: the creature can be won again (its paralogue replayed, subject to the Named's mutual knowledge, NAMED_RULES_DESIGN.md).
The player is told with the canon `leaves_line` (the win screen for map-won, writ and literacy triggers; the barracks message for a hand-off). Triggers are noticed when a map is won (after its supports settle, so a literacy
reveal by that win is caught). The writ and literacy triggers remember that they have already happened, so a creature won *afterwards* is not hit by an old event; the map trigger fires only on the first win of its map.

## Drafted guesses to confirm

- All the readings above, in particular: the "doves" as the Ashland write-off (there is no dove colony on a map to threaten); "state orders" as the writ; "literacy you lack" as Ricberta's reveal.
- That the Simurgh's first rider is the feather's holder, and that a dead holder frees her.
- That a creature that left can be won again, rather than gone for good (a defection "is not death"; Maren has a way back too).
- On the diadem route `map_b15` is never played, so there the Karkadann leaves only with the writ.

## Not built

- Any scene for the leaving (the signposting canon wants before a defection), a way to keep the creature by appeasing it, or a lieutenant version of it (as a creature that returns hostile).
- The Anzu turning to a *specific* literate unit (it just leaves).

Tests: `tests/test_named_defections.gd` (29 checks, mutation-checked). The validator's c07 checks the `leaves_*` columns.
