# The forge: master smiths, beast materials and legendary weapons -- design and status

Status: **implemented** (first pass; every number and access rule here is drafted from canon's `forges` and `materials`
tabs, which were never wired into the game). Added 2026-10-17. Everything here is a design proposal, not setting canon.

## The gap

Canon has two tabs the game never read: `forges` (three master smiths and two abstract standard forges) and `materials`
(what each Named creature leaves behind, and the weapon it becomes), plus a hard cap of **3 master works per run against
5 possible drops**. The paralogue bosses (the Simurgh, the Karkadann, the Anzu, the Shadhavar) already existed as fightable
stand-ins and dropped nothing. This builds the loop that connects them.

## The loop

1. **Defeat a Named stand-in on its paralogue.** Canon's three-way answer to a Named is intact / harvest / kill. Two of the
   three are built: **kill** it for a **prime** material, or **capture** it (Gunnar's or a Pardoner's Capture, now allowed on a
   Named boss at half HP -- an ordinary boss still can't be captured) for a **diminished** one, "harvested". One material per
   Named per run; replaying the map yields nothing more. The Huma, per canon, yields none and is never fought.
2. **Take it to the right master.** They are fixed buildings on the overworld: the **edged master** at Kaisareia, the
   **hafted master** at Vashti gate, the **missile master** at Ostrova (drafted: the Herd Clans have no city, so their smith
   stands on the steppe edge). **F** opens the forge where one works.
3. **Commission the work.** Each master has an access rule, one per canon logic ("three different access logics on purpose"):

   | Master | Canon logic | Drafted rule |
   |---|---|---|
   | edged (Kaisareia) | state legitimacy: the crown permits | always open |
   | hafted (Vashti) | military control: hold the Vashti road, tied to Column A | the Cinder Track won |
   | missile (Herd) | diplomatic standing: granted passage | the Second Writ won |

   At most **3** works a run (`master_works_cap`); the material is spent. "Access can be lost mid-run" is **not** modelled.
4. **Wait two chapters.** A work finishes after **2 newly won maps** (`cycle_n`); replaying a won map doesn't count. The win
   screen says when one is done.
5. **Collect it** at the forge into the convoy. A diminished material makes a weapon with **half the uses**.

Materials never expire, so banking them is legal, as canon says.

## The four weapons

A new **legendary** tier (above silver; it needs a certified class like silver does), never found or bought. One on-hit
special each (`weapons.effect`):

| Material | Weapon | Art | Special |
|---|---|---|---|
| the Simurgh's feather (edged) | **Feather Blade** | sword | `heal_allies`: every hit heals each ally standing beside the wielder for 5 -- canon's "heals its wielder's allies on contact rather than the wielder" |
| the Karkadann's horn (hafted) | **Karkadann Lance** | lance | effective vs riding (x2), "nothing special vs. infantry" -- "the plain one on purpose" |
| the Anzu's torn pinions (edged) | **Anzu Edge** | sword | `unmake`: every hit wears the foe's weapon one step down; a worn weapon goes at once, a silver one after four hits, and a weapon that is gone leaves the foe **unarmed, not dead** -- canon's "only bites what is already worn" |
| the Shadhavar's hollow horn (missile) | **Shadhavar Bow** | bow (range 2) | `pull`: a hit foe is dragged a tile toward the archer (never a boss, never into an occupied tile) -- "can't be turned off", a liability against a melee line |

The forecast panel prints the special in gold. An unarmed enemy neither attacks nor counters nor moves. A suspended battle
remembers the wear.

## Not built

- **Intact** capture (a marked weapon that keeps its ability / a Named mount) and the kill-taboo on the Huma.
- "Better weapon" for a kill (here a kill gives a prime material, which just means full uses), the Named's mutual
  knowledge ("kill one and the next will not be captured"), and the Anzu's cost ("weapons it unmakes cannot be captured").
- The **standard forges** (requisition tier orders) and the **epithet naming grammar** (blood-on-the-blade marks, reforging
  clears epithets) -- the deeds' forge vocabulary tokens are still unused.
- A smith's access being **lost** mid-run; the requisition tier; Named riding.
- The legendary weapons' numbers (might 11-14, 30 uses) and the access rules are first-pass guesses.

## Where it lives

`canon.xlsx`: `weapons.effect` and the four `legendary` rows; `forges.location_id/access_rule/cycle_n`;
`materials.enemy_id/weapon_id`; `enemy_archetypes.named_id`; `promotion_rules` (`master_works_cap`, `forge_heal`,
`diminished_uses_pct`); validator rule c07m. Engine: `scripts/forge.gd` (autoload: materials, access, commissions, cycle),
`forge_screen.gd` + `forge_screen.tscn`, `map_grid.gd` (yields, the specials, the cycle on a win), `overworld.gd` (F),
`game_state.gd` (`materials`, `materials_claimed`, `forge_orders`, `works_started`). Tests: `test_forge`.
