# The Martyr and the Quartermaster -- design and status

Status: **implemented** (first pass). Added 2026-10-25. The last two personal classes with no kit. Canon gave one line each:
Martyr "Provoke + Miracle + Resolve", Quartermaster "Merlinus revival; one per column". Neither had a unit. The holders and every rule below are my drafts.

## The Martyr -- Anselm

**Anselm** holds it: the adrift monk, canon's "theology barometer", is a faith unit whose arc is already about what he will and will not stand for. He keeps his faith
art; his class is now personal, so his level-15 and level-30 steps are milestones, not a choice among Bishop, Great shield and the rest. (He still leaves the company in Act 2
and can come back as a lieutenant with his titles; the class is gone with him.) Swap the holder to Maren by editing `units.base_class_id` if you prefer her.

- **Provoke (V):** for the **coming enemy phase** every enemy that can reach the Martyr attacks the Martyr (the best tile and attack against them); enemies that cannot reach him
  act as usual. It takes his action and lasts exactly one phase, and a suspension keeps it.
- **Miracle (passive):** **once a map** (`prm_miracle_per_map`), a blow that would kill the Martyr -- in the enemy phase, on an answering blow, or from the cold -- leaves
  him at **1 HP** instead. The fall is not recorded for the epilogue. The second lethal blow in a map kills.
- **Resolve:** already the ability row `ab_resolve` (pool: War monk, Martyr): +10 avoid and 3 guard at half HP or less.

## The Quartermaster -- two column guests

Not a roster unit (the roster is a fixed 18 with a finished support grid). **Wolfram** keeps the convoy for the main column; **Hildegund** keeps it for **Column B**
(chapters whose column is B: the going-rate and Throat Pass line). Each map has exactly one of them, never both: that is "one per column". They join the company when the
first Act 1 map is won on either route (so a fresh game and every test before that has neither), and never depart. They use the guest machinery Anna uses: a baseline borrowed
from Kheldar (a frail non-combatant), the squad's median level less two, no EXP, no supports, **no art, so they cannot attack**. Their names are my invention; rename freely.

- **Supply (Q):** an adjacent **roster** ally swaps their equipped weapon for the **strongest weapon in the convoy they can wield** (by might; certification still gates silver,
  legendary and mythic), and the convoy takes the old weapon back. It takes the quartermaster's action. If nothing beats what the ally holds, it says so and costs nothing.
  This is the only way to touch the convoy mid-battle: a boss's drop goes into the convoy at once and can be handed on the same turn.

## What changed in the engine and canon

`guest_units` gains `joins_after_map_id` (a pipe list: any one won), `column` (A or B) and `stats_like_unit_id`; `Defections.guest_active` honours them, and `_guest_rows` deploys only
the guest whose column matches the map. `classes`: `cls_martyr` (`map_actions` provoke, `signature_skill` Miracle), `cls_quartermaster` (supply, Convoy Keeper). `units.u_anselm`.
Parameter `miracle_per_map`. Validator c07u: Provoke/Supply/Miracle/Convoy Keeper belong to personal classes; a Quartermaster is needed for each column (A and B); a guest's
`joins_after_map_id` and `stats_like_unit_id` resolve; the "someone holds this class" warnings now count guests.
`test_paragon` now states Anselm's milestone, with a class lent to him for the Krivis check.

## Drafted guesses to confirm

- Anselm as the Martyr; Provoke's single phase; Miracle once a map and at 1 HP; the guests' names, their joining after the first Act 1 win, and a quartermaster being a guest at all.
- That Supply picks the strongest wieldable weapon by might (no choice), and works on roster allies only.

## Not built

- A choice of weapon in Supply, a way to **store** from the map, or a convoy screen in battle; Supply of consumables (there are none).
- A quartermaster who can be hurt, killed or captured with consequences (they are ordinary units on the map; one that falls is simply gone for that map: guests are not
  recorded by the epilogue). A Provoke range; a Martyr deed; Provoke against a boss (bosses are provoked like any enemy that can reach).

Tests: `tests/test_martyr_quartermaster.gd` (39 checks, mutation-checked).
