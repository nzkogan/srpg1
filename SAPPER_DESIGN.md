# The Sapper -- design and status

Status: **implemented** (first pass). Added 2026-10-21. Canon had `cls_sapper` as a row with no art, no actions and the note
"IN DRAWER, not yet placed". The class, the unit who holds it and both of its actions are my drafts, flagged below.

## Who and what

**Rinsa** is the Sapper (you chose her). Canon's own line for her is the descender, paid staff at the oracle of the dead who
leads people down into the dark: someone who knows how to get under a thing. The class is **personal** (no paperwork exists, no one
else can take it), **infantry**, and **brawl**, so she keeps her gauntlets and still fights. Her base stats are unchanged; her
starting tier is now `personal`, so she takes a personal milestone at 15 and 30 instead of choosing among trained-brawl classes
(Grappler, War monk, Ash Ascetic) or, at the paragon tier, the Toa. That is a real cost and the first thing to reverse if you dislike it
(`units.base_class_id`).

## Breach  (key D)

Bring an adjacent **wall or building** down into a **breach**: a new terrain (`ter_breach`, symbol `v`) that costs 2 on foot, 3 for
armor and riders, 1 for fliers, with no hazard. A breach is a way through **for everyone, enemies included**, and it is permanent for the map.
Which tiles can be breached is per map (`maps.breach_symbols`), because a letter means different things on different maps (`x` is a cliff
on one and a wall on another): the warehouses of d01, the ruins of d06 and d07, the buildings of a02 and a06, the granary silos of k21, the
walls of d10, a09's shrine, a10's chapel and the Buried Works. Cliffs, the bell tower, the river, the Throat Pass flanks and the
Idol's body cannot be breached.

## Mine  (key M)

Lay a charge on an adjacent open tile (not a wall, not occupied, not already mined; a breach is fine). The **first enemy to end a move
on it** takes **12** damage and the charge is spent. It works on an enemy that walks into it, **and on one shoved onto it**. The damage is the Sapper's:
it counts as touching a boss (so a boss a mine has hurt is no longer a "single combat" kill), a kill by mine is a real defeat (drops, boss
logic, the Deputy ledger's kill credit) and the Sapper gets the kill. Mines are marked in red, and only enemies set them off.

## Charges

**3 per map**, shared between Breach and Mine (`prm_sapper_charges`), and each uses the unit's action for the turn. A suspended battle remembers
the charges, the breaches and the mines.

## Drafted guesses to confirm

- Rinsa as the holder (a straight swap of her class), her art being brawl, and her losing the trained-brawl and Toa routes.
- Three charges, mine damage 12 (a bit under a steel sword), mines visible and hurting only enemies.
- The list of breachable maps; and that a breach is permanent and usable by the enemy.

## Not built

- Charges that **grow** with level or the paragon milestone; a breach that kills a unit standing behind it; mines the enemy can **see and avoid**
  (enemy movement ignores them), or disarm; a third action. There is no Sapper-specific ability or epithet yet.
- Breaching the destructible wall of the prologue (`ter_wall`, the map_f00 script) -- it has its own scripted removal.

## Where it lives

`canon.xlsx`: `classes.cls_sapper`, `units.u_rinsa`, `unit_base_stats.u_rinsa`, `terrain_costs.ter_breach`, `maps.breach_symbols`,
`promotion_rules` (`sapper_charges`, `mine_damage`); validator rule c07r (the breach terrain is passable, breachable symbols are impassable
ones, only a personal class carries the actions, someone holds it). Engine: `progression.gd` (`can_breach`, `can_mine`, the two parameters),
`map_grid.gd` (the actions, `_trip_mine`, `breached`/`mines`, the snapshot). Tests: `test_sapper` (35 checks, mutation-checked); `test_paragon`
now states Rinsa's milestone.
