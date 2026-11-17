# Weapon names -- design and status

Status: **implemented** (first pass). Added 2026-10-20. Canon carried a promise with no rules behind it: the forge's "provenance
grammar" -- *blood on the blade*, *reforging clears epithets* -- and a `forge_vocab_token` on every deed that nothing used. The design
chat that produced it was never tabulated, so the rules below are my reading of those two phrases; the words are drafts.

## Marks

A weapon is "Iron Axe" until someone earns a deed **with it**. The deed that completes while the weapon is the unit's equipped one
(every deed funnels through `_earn_deed`) is written on the blade as a **mark**. Marks live on the inventory entry --
`{"weapon_id", "uses", "marks": [{"ep", "object"}]}` -- so they are saved, carried, stored in the convoy and passed on with it,
and **outlive the wielder**: a fallen unit's marked weapon comes home to the convoy (or is lost) still named.

- A weapon keeps at most **3** marks (`prm_weapon_marks_max`); a new one drops the oldest. Earning a deed the weapon already carries
  just moves it to the newest place.
- A Slayer's mark remembers **what was slain** (`the Karkadann`, `Boyan`, `the warlord`).
- No weapon in hand (unarmed or broken) means no mark: the deed is still the *unit's*.

## The name

The **strongest** mark names the weapon: a paragon-gating deed beats one that does not, then the newest wins (the same rule as a
person's title, with recency in place of canon order since marks have an order). Each deed has a `weapon_form` in `epithets`; it must
contain the deed's own `forge_vocab_token`, which the validator checks:

| Deed | Form | Example |
|---|---|---|
| boss kill (gating) | `{BASE}, Slayer of {OBJECT}` (bare: `Slayer's {BASE}`) | Iron Axe, Slayer of the Karkadann |
| solo hold (gating) | `{BASE} of the Ford` | Steel Lance of the Ford |
| no-hit map (gating) | `Untouched {BASE}` | Untouched Iron Sword |
| capture x5 (gating) | `Taker's {BASE}` | Taker's Iron Axe |
| miasma x5 | `Ash-walker's {BASE}` | |
| delivery | `Carter's {BASE}` | |
| dispersal x3 | `Merciful {BASE}` | |
| talk | `Peacemaker's {BASE}` | |

`Equipment.describe` (convoy screen, barracks, "equips the...") and the "breaks!" line use the marked name. Legendary weapons take
marks like any other (a `Taker's Feather Blade`).

## Reforging

At a **master smith**, on the forge screen, a marked **convoy** weapon of the master's craft shows a *Reforge* row. It costs
**150 gold** (`prm_reforge_fee`), clears the marks, and leaves the uses alone. Refused: a plain weapon, a **legendary** one ("a
legendary weapon's history is not the smith's to clear"), a weapon outside the master's craft (edged = swords, hafted = lances and
axes, missile = bows -- so gauntlets, tomes and rites cannot be reforged), a closed smith, too little gold, a standard forge.

## Epilogue

`weapon_carried` is now the provenance name. A name can already be a possessive, so the four weapon lines read **"The {WEAPON} ..."**
(*The Taker's Iron Axe passed to no one.*) instead of "{NAME}'s {WEAPON}"; the death record keeps the marks, and a retrieved
weapon returns to the convoy still marked.

## Drafted guesses to confirm

- Marks come only from **deeds**, not kills ("blood on the blade" could also mean every kill); and only from the **equipped** weapon at that moment.
- The form wording, the cap of 3, the fee of 150, and that reforging is convoy-only and master-only.
- Whether a marked weapon should be *better* (it is not -- names only; no stats change).

## Not built

- Marks on **enemy** weapons (a defector's marked weapon, a captured one in enemy hands -- canon's "found back in enemy hands"),
  a weapon's history shown in the convoy screen's detail (`Provenance.history` exists and the forge screen uses it), and the
  "three-name rule" that `naming_reference` mentions.
- Random **forge-name permutations** for standard forges and the unnamed requisition orders; unique proper names for ordinary weapons.

## Where it lives

`canon.xlsx`: `epithets.weapon_form / weapon_form_bare`, `promotion_rules` (`weapon_marks_max`, `reforge_fee`), the four weapon lines
of `epilogue_text`; validator rule c07q. Engine: `scripts/provenance.gd` (autoload), `equipment.gd` (describe, spend_use),
`map_grid.gd` (`_earn_deed`), `forge_screen.gd` (reforge row), `epilogue.gd`. Tests: `test_weapon_names` (63 checks, mutation-checked).
