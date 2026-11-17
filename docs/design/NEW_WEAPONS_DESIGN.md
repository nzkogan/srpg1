# New weapons (batch 2) -- design and status

Status: **implemented** (first pass). Added 2026-10-22. Eight new weapons: a lightning sword, a two-range morningstar, two legendary
bows, two sacred texts and two grimoires. All stats, names and sources are my drafts. These are **relics**: legendary weapons that a
boss **drops**, not weapons a smith forges (the forge keeps its four Named works). Every legendary weapon, these included, still needs a
certified wielder.

## The weapons

| Weapon | Art | Tier | Range | Might / Hit / Crit / Wt | Special | Found |
|---|---|---|---|---|---|---|
| **Perun's Brand** | sword | legendary | 1-2 | 11 / 85 / 8 / 9 | `res_strike`: the blow is physical (STR) but only RES turns it aside | the second captain of the Second Writ (Act 2) |
| **Morningstar** | axe | mid | **2 only** | 9 / 70 / 0 / 10 | cannot answer an adjacent foe (like a bow) | the harbour bosses (Thessala Harbour, Halder Harbour) |
| **Vila's Moonbow** | bow | legendary | **2-3** | 12 / 90 / 10 / 6 | effective against flying | the Timber Road boss |
| **Neith's Bow** | bow | legendary | 2 | 10 / 95 / 20 / 3 | nearly weightless: follows up easily, crits often | the Stranded Harbour boss |
| **Miroslav Gospel** | faith | legendary | 1-2 | 14 / 85 / 0 / 6 | `renew`: the reader recovers 5 HP with every blow that lands | the March Shrine boss |
| **Zographos Codex** | faith | legendary | 1-2 | 16 / 80 / 0 / 8 | none: the hardest-hitting text, plain on purpose | Boyan, the preacher of the still night |
| **Goetia of Astaroth** | reason | legendary | 1-2 | 14 / 80 / 5 / 7 | `drain`: half of the damage it deals returns as health | the boss of What Feeds the Colossus (replaces an axe) |
| **The Lemegeton** | reason | legendary | 1-2 | 18 / 75 / 10 / 9 | `recoil`: 3 HP each time it is opened, never the last HP | the boss of the Buried Works (replaces a steel sword) |

Names and their roots: **Perun** is the Slavic thunder god (the brand is his lightning); the **vila** (Serbian) and **samodiva** (Bulgarian) are the
mountain and forest archers, the Balkan Artemis; **Neith** is the Libyan-born bow-and-weaving goddess of Sais; the **Miroslav Gospel** is a Serbian
12th-century manuscript and the **Codex Zographensis** an early Glagolitic gospel; **Astaroth** and the **Lemegeton** (the Lesser Key itself) are
the grimoire tradition you have been reading.

## What changed in the engine

- `weapons.effect` gains `res_strike`, `renew`, `drain` and `recoil` (validator c07m knows them). `Combat.damage` mitigates with RES for a `res_strike`
  weapon as it does for a magic art; the forecast reads each special through `Forge.effect_text`.
- On the map: `renew` and `drain` heal the wielder when a blow lands (never past full HP); `recoil` costs HP whenever the wielder strikes at least once, on
  their own attack or a counter, down to 1 HP and no further. Parameters in `promotion_rules`: `renew_heal` 5, `drain_pct` 50, `recoil_damage` 3.
- Ranges 2-only and 2-3 needed no new code (ranges are read from the weapon); a Morningstar cannot counter at 1 and the Moonbow cannot shoot at 1.
- Two existing drops are replaced (`spn_k22_boss`: Silver Axe, `spn_pburiedworks_boss`: Steel Sword) and seven bosses that dropped nothing now drop a weapon,
  so canon holds 29 drops, not 22. The validator no longer warns about a legendary weapon that is dropped rather than forged.

## Drafted guesses to confirm

- All the numbers; especially the Lemegeton's 18 might (the strongest hit in the game, with a price) and the Zographos Codex coming from a chapter-2 boss, which
  makes a legendary text available in Act 1 (usable only once a faith unit certifies at level 15).
- The sources: Neith at a ruined harbour, the Moonbow in a forest, the grimoires at the dark places. Move any with one `drop_weapon_id` edit.
- "High level magic" is read as a second legendary rank for faith and reason. There is no tier above `legendary`, and no mid-tier magic between Silver and these.

## Not built

- A grimoire being *evil* beyond its recoil (no corruption mechanic, no sect reaction, no effect on supports); the Moonbow's moon (no night or time of day).
- A weapon the player can **buy**; a second Morningstar tier; enemies carrying these (a boss still drops its relic, it does not wield it).
- The weapon flipbook now shows all 43 weapons, with a new drawing for each of the eight.

Tests: `tests/test_new_weapons.gd` (44 checks, mutation-checked); `test_forge` now counts only the *forged* legendary weapons and `test_equipment` the 29 drops.


## Update 2026-10-23: the might ladder and the mythic tier

Silver (13) out-hit most of the legendary weapons (10-14), so the ladder was wrong. Now **worn 1 < basic 5 < mid 8-10 < high 13 < legendary 15-17 < mythic 18-21**,
and the validator warns if a tier's weakest weapon does not beat the one below it (rule c07s).

- **Legendary raised to 15-17**: Feather Blade 15, Anzu Edge 15, Shadhavar Bow 15, Neith's Bow 15, Perun's Brand 16, Vila's Moonbow 16, Miroslav Gospel 16,
  Goetia of Astaroth 16, Karkadann Lance 17 (the plain one on purpose), Zographos Codex 17.
- **Mythic (new tier), one weapon for every art, 20 uses, paragon wielders only** (`Progression.can_use_tier`: a certified class is not enough):

| Weapon | Art | Range | Might / Hit / Crit / Wt | Special | Found |
|---|---|---|---|---|---|
| **Marko's Claymore** | sword | 1 | 19 / 70 / 5 / 16 | none: the biggest sword | the Reunion boss (end of Act 2), with a Silver Sword |
| **Saint George's Spear** | lance | 1 | 20 / 75 / 5 / 14 | effective against flying | the Reckoning boss, with a Silver Axe |
| **Svarog's Cleaver** | axe | 1 | 21 / 65 / 0 / 18 | none: the hardest hitter | the Granary District boss, with a Silver Axe |
| **Rostam's Tamarisk Bow** | bow | 2-3 | 18 / 85 / 10 / 8 | none | the North Wind Winds boss, with a Silver Axe |
| **Svyatogor's Grip** | brawl | 1 | 19 / 80 / 10 / 12 | none | the His Lake boss, with a Silver Axe |
| **The Lemegeton** | reason | 1-2 | 20 / 75 / 10 / 9 | `recoil`, 3 HP a fight | the Colossus boss (moved up from legendary, 18 -> 20) |
| **Slavonic Enoch** | faith | 1-2 | 18 / 85 / 0 / 7 | `heal_allies`: every blow heals the allies beside its reader | the Throat Pass boss, with a Silver Lance |

Roots: Kraljevic Marko (Serbian epic hero), Saint George (the dragon-slayer), Svarog (Slavic smith-god), Rostam of the Shahnameh (his tamarisk arrow, shown him by the Simurgh),
Svyatogor (the bylina giant), the Lemegeton, and 2 Enoch (kept only in Old Church Slavonic).

Engine: a boss's `drop_weapon_id` may now be a pipe list (`wpn_axe_high|wpn_svarog_cleaver`) and drops all of them; the Goetia of Astaroth moved to the Buried Works. The foreign key from
`drop_weapon_id` to weapons is gone (the validator checks every id). **Drafted guesses:** the paragon gate (relax it in `Progression.can_use_tier`), all the numbers, and the
sources. Two mythic weapons sit on paralogues that open early, so the chapter reference reads early even though a paragon is level 30 or more; move a drop if you want them later.
Tests: `test_mythic` (37 checks).
