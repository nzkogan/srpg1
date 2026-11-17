# Standard forges and the requisition tier -- design and status

Status: **implemented** (first pass). Added 2026-10-26. Canon's `forges` tab described the two standard forges in one line each: "requisition tier only (1/2/3 open
orders at tier 1/2/3)", "the ordinary spine sidequest; no master required", one-chapter cycle, no place on the map ("wherever your column currently is"), and
the masters' access rules mention requisition tier as the thing a master's door does or does not depend on. Nothing defined the tier. The tier's source, the catalogue,
the prices and every number are my drafts.

## Requisition tier

A number from 1 to 3 that rises with the war: **tier 2 once the Second Writ (map_x11) is won, tier 3 once the Reunion (map_rf20) is.** Both maps are `promotion_rules` rows
(`prm_requisition_tier_2` / `_3`, the map in the text column), so you can retarget them. The tier is how many standard orders may be open at once, across both forges
(canon's "1/2/3"), and tier 3 also opens silver weapons.

## The orders  (key O on the overworld)

- **Where:** anywhere the party stands: O opens the requisitions screen (the forge screen in requisitions mode). The forge that takes the order is the **Assembly's
  (`frg_standard_b`) at a place whose chapters run on the Assembly route, the Diadem's (`frg_standard_a`) everywhere else.** Finished and in-progress orders of both forges
  always show, so moving columns loses nothing.
- **What:** every ordinary weapon (a basic or mid one-art weapon -- the Iron and Steel of every art, plus the Morningstar -- and at tier 3 the Silver ones). Not overlap weapons,
  relics or scavenged gear. Prices: **150** basic, **300** mid, **800** silver gold.
- **House arts, 20% off:** the **Diadem's forge** makes sword, lance, reason and faith for less (the capital's armories and library); the **Assembly's** makes axe, bow and
  brawl for less (timber, horse country, the lake towns). Set in `forges.house_arts`.
- **The cycle:** the order is ready after **one newly won chapter** (`forges.cycle_n` 1; a replayed map does not count). The win screen says so; the order is **collected** into the convoy at full
  uses from the same screen. A finished order still occupies a slot until collected.
- Orders are saved with the master works (`GameState.forge_orders`) but are not master works: no material, and they do not count toward the cap of three.

## Drafted guesses to confirm

- The tier's source (two story maps), prices, the 20% house discount and which arts are whose, silver only at tier 3, the Morningstar being orderable (it is a plain mid axe weapon).
- One shared limit on open orders across both forges, rather than one per forge.
- "Wherever your column currently is": read as the chapter route of the place the party stands.

## Not built

- Orders for **marked** weapons, upgrades (a Steel from an Iron) or a trade-in; a sell-back of convoy weapons; a quantity discount; the tier rising from the deputy ledger or the writ scene (it is
  a plain map check); showing the tier on the barracks screen.
- A way to see what you could order **without** being at the overworld (no map-side buying).

## Where it lives

`canon.xlsx`: `forges.house_arts` and the standard rows' `access_rule` (always) and `cycle_n` (1); `promotion_rules` (`requisition_tier_2`, `requisition_tier_3`, `standard_cost_basic`,
`standard_cost_mid`, `standard_cost_high`, `standard_house_discount_pct`); validator c07v. Engine: `forge.gd` (`requisition_tier`, `catalogue`, `can_order`, `order`, `standard_forge_for`),
`forge_screen.gd` (requisitions mode), `overworld.gd` (O). Tests: `test_standard_forge` (42 checks, mutation-checked; one defensive filter is an equivalent mutant: no
ordinary weapon carries an effect today).
