# The Huma's shadow -- design and status

Status: **implemented** (first pass). Added 2026-10-28. Canon (`named.nmd_huma`) says the Huma is a **map hazard, not a mount**: it "drifts overhead; marked units gain stats and
become targeting priority for every enemy", its shadow "legitimizes whoever it falls on", it "never defects because it was never yours", and it carries a **kill-taboo**
(whoever lands the blow dies in forty days, no reload undoes it). `chapters.ch_p_huma` adds that it never lands, so it is **never a unit on the grid**. Every number below is my draft.

## The shadow

A patch on **`map_p_huma`** (the open road; the map list is `prm_huma_maps`, so another road can be added in canon). On turn 1 its centre lies over column **8** (`huma_start_col`)
on the map's middle row; each turn it **drifts 2 columns east** (`huma_drift`), wrapping to the west edge at the far end. It covers everything within **2 tiles** of the centre in both
directions (`huma_radius`: a 5 x 5 patch). The same patch holds for both phases of a turn. It is drawn as a purple wash over the map, redrawn each turn, and the panel says which
columns it lies over and whether the selected unit is in it. The deploy screen shows turn 1's.

## Marked

A unit standing in the shadow, **yours or theirs**, is *marked*: **+2 to str, mag, def, res and spd** (`huma_bonus`) for as long as it stands there. The forecast and the exchange
both read it, so stepping in or out changes the numbers you see. **Every enemy that can reach a marked unit of yours goes for it** instead of the easy kill (a Martyr's Provoke still
outranks the mark, which outranks everyone else). So the shadow is a gamble: the stats are worth having, and the whole road comes for you.

A unit of yours who **falls while marked** is recorded as killed by the Huma (`killed_by_type` named_creature, `nmd_huma`), and the epilogue says "to the Huma's shadow" (the death phrase
canon already gave it). The weapon's fate follows the usual rule for whoever struck the blow.

## The taboo

The Huma is no enemy archetype, no mount and no unit, so nothing in the game (an attack, a shove, a mine, a breach, a charge) can ever land the blow. The taboo is kept by making
it impossible; there is no forty-day clock, since there is no calendar to run it on.

## Drafted guesses to confirm

- Every number (radius, drift, start column, +2) and that the patch drifts east along a fixed row rather than weaving.
- Enemies in the shadow are marked too (canon says "marked units" without saying whose).
- The mark draws enemies with the same weight a Provoke would if there were no Provoke: they pick the marked unit if they can reach one at all.
- Crediting a death in the shadow to the Huma, rather than to the enemy that struck.

## Not built

- The forty-day curse itself, or any way to strike the Huma (no unit to strike); the Huma on maps other than the open road (nothing in canon puts it elsewhere, but the list is data).
- The scene where it passes ("legitimizes whoever it falls on" as dialogue, and whatever a sect makes of a marked leader).
- Marked status in the unit panels beyond the map's panel line; enemies that avoid or seek the shadow.

Tests: `tests/test_huma.gd` (27 checks, mutation-checked). The validator's c07x checks the parameters.
