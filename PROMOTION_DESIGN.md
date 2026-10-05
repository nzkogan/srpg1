# Promotion rules -- design proposal

Status: **design only, nothing implemented.** Drafted 2026-10-05. Every number here is a proposal to
tune; the structural claims about canon are checked against `canon.xlsx` (cited inline).

## The problem to design against

In the GBA Fire Emblems a unit's level resets on promotion and both classes cap at 20. That makes the
*timing* of promotion a puzzle with a right answer: promote at 20/20, because every level you skip in
the first class is a level-up you never get back. Promoting "early" is a mistake you are punished for
slowly, and the game never tells you. The goal here is the opposite: **promotion has no timing puzzle.
There is one correct moment, it is the earliest one, and the game makes that moment obvious.**

## What canon already gives us

- Levels are one continuous scale with tier floors: `trained` **lv5+**, `order` **lv15+**, `paragon`
  **lv30+** (`classes.notes`, `unit_base_stats` note). Nothing in canon resets a level on promotion.
- Order classes are `art + movement type` pairs (28 cells, 3 deliberate gaps = 25 classes); hybrids are
  `art + art`; paragon is deed-gated.
- Dietmar and Torvald are already order tier at lv15 with the low-growth `gp_jagen` profile.
- Growth is per *unit* (`growths`, ~315 points a level for recruits), not per class, so a class change
  never rewrites a unit's growth rolls -- it can only add a flat overlay.
- There is currently **no EXP, level-up or promotion system in the game at all** (a unit's class sets its
  arts and movement and nothing else). The gate below needs a minimal EXP rule; see "Prerequisite".

## The rules

1. **One continuous level, no reset, one global cap (proposed 40).** The tier floors are *gates*, not
   separate level tracks. Total levels you can ever earn do not depend on when you promote, so there is
   no "wasted potential" to min-max.
2. **The gate is level 14 -> 15.** A trained unit stops at level 14 with a full EXP bar and is marked
   *Ready to certify*. Nobody can promote earlier (canon's lv15 floor); nobody gains anything by
   waiting. Paragon works the same way at 29 -> 30.
3. **EXP earned while gated is banked, up to one level's worth, and credited on promotion.** Past the
   bank it is lost. This is the only cost of dithering, and it is small and visible: at ~45 EXP a map,
   waiting 3 maps wastes 35 EXP, 5 maps 125, 8 maps 260 (about 8 stat points). The player never has to
   work out the trade-off; a banner on the unit says it.
4. **Promotion is free, instant, unlimited and not a consumable.** No Master Seals, no one-per-map
   limit, nothing to hoard or to be unlucky about. It is done between maps (the "certification" in
   canon's order-class provenance is paperwork the home front handles, not a drop).
5. **What you get, all at once, on promotion** -- the actual pull toward promoting immediately:
   - **A flat stat jump of +25 total** (HP 4, Str 3, Mag 2, Dex 4, Spd 3, Lck 2, Def 4, Res 3). This is
     calibrated from canon's own numbers: a trained recruit who levels naturally from 5 to 15 totals
     ~97.5 stat points while the order-tier baseline for the same growth profile is ~124 (mean gap
     26.2), so +25 puts a freshly promoted recruit at ~122-123 -- parity with the order tier, and in
     range of Dietmar and Torvald's 115.
   - **A movement type.** Infantry units can become riding (move 9), flying (7) or armor; this is the
     biggest tactical change in the game, and it is immediate.
   - **Higher growth from then on: +5 on every stat's growth rate** (about +0.4 stat per level, ~13%
     more than a recruit's 3.1). Every level spent unpromoted is therefore a small standing loss.
   - **High-tier weapons.** `high` weapons (silver, 13 might) need an order or paragon class; mid and
     basic stay open to everyone. Act 2's high-tier boss drops (see the drop table) become the pull.
   - **The class's signature skill** where canon has one (Smite, Stake, Resolve, Pavise/Aegis...).
6. **The decision is *what*, never *when*.** The menu at 15 is the 4 movement types for the unit's art
   (e.g. sword: Swordmaster / Sentinel / Cavalier / Dragoon), plus any hybrid siblings the unit has
   unlocked (axe: Ferryman, Billman).
7. **Recertification (optional, recommended).** Between maps a promoted unit may switch to another
   order class of the *same art* for free; it keeps its level and every stat it earned, and only the
   class's flat shape modifier and movement type change. No choice is permanent, so there is no
   "missed the right class" regret either.

## Why this removes the min-max

| Rule set | What delaying promotion does | Why a min-maxer would delay |
|---|---|---|
| GBA-style (reset, 20/20) | extra first-class levels, up to ~6 stat points | the 20/20 build |
| This design | wastes EXP past the bank (0 for 2 maps, ~4 stat points at 5, ~8 at 8) | nothing |

For a unit with 35 levels of EXP by endgame, GBA-style promotion at lv10 uses only 28 of them (87.6
stat points), lv15 uses 33 (103.3), and lv18-20 uses all 35 (109.5): that 6-point swing is the 20/20
itch. Here every timing ends at the same level, so the only variable left is how soon you start
collecting the +25, the movement type and the +5 growth.

## Everyone who is not a plain trained recruit

- **Dietmar, Torvald** (order, lv15, `gp_jagen`): already promoted. Their next gate is paragon at 29 -> 30
  (deed-gated, the one place a promotion is not free; deeds should never expire so they can't be missed).
- **Personal classes** (Avatar/Strategist, Gunnar, Edda, Kheldar): they have no tier ladder. They get a
  *milestone* at 15 and 30 with the same +25 jump and growth bonus, no class menu, and a personal
  signature skill instead -- same timing rules, so they are never left behind.
- **Kest** (shadow): Footpad -> Thief at 15, Assassin or Trickster at 30; same gate and bank.
- **Late joiners** (Rinsa, Kest, Anselm...): this is where FE's carry-the-few habit bites. Proposed:
  a recruit joining more than 3 levels under the squad median is raised to median - 3, and units below
  the median earn +25% EXP per level of deficit (cap +100%). It is the same anti-min/max idea: broad
  squads, not three 20/20 carries.

## Suggested promotions, from each unit's own growth profile

| Unit | Now | Natural fit |
|---|---|---|
| Sigrun | Trained (sword), cavalry growths | Cavalier |
| Ricberta, Brandt | Trained (lance), armor growths | General |
| Waldrada, Solveig | Trained (lance), flier growths | Falcon knight |
| Jost | Trained (axe), bruiser | Warrior, or Housecarl (Smite) |
| Tancred | Trained (bow), archer | Sniper or Sky archer |
| Rinsa | Trained (brawl), bruiser | Grappler or War monk |
| Emmerich | Trained (reason), mage | Warlock or Mage knight |
| Maren, Anselm | Trained (faith), healer | Bishop (Valkyrie for mounted support) |

These are suggestions for the menu's default highlight, not locks.

## Prerequisite: a minimal EXP rule

The gate needs something to gate. Smallest thing that works, in the FE lineage the project cites:
100 EXP a level; a strike earns `clamp(10 + 3 x (enemy level - unit level), 1, 30)`, a kill adds
`30 + 5 x (enemy level - unit level)`, with the underdog bonus above. Enemy levels already exist
(`enemy_archetypes.level`). Tuned so a regular deployer earns ~45 EXP a map, which takes lv5 -> lv15
in about 20 maps -- roughly the end of Act 2.

## Decisions I need from you before building this

1. **Gate with bank (above), or let units keep levelling past 15 unpromoted?** The second has no gate
   and no waste but also no pull; the bank is what makes "promote now" the obvious play.
2. **Recertification: yes or no?** It removes class regret but makes every promotion reversible.
3. **Are hybrid classes (Billman, Ferryman, Pardoner, Ash Ascetic, Miasma Warden) menu options at 15, or
   unlocked later by story/sect practices?** Canon doesn't say. Unlocking them is how the halberd,
   maul and censer finally get wielders.
4. **Global level cap 40, or something else?** (Canon only gives paragon 30+.)
5. **Late-joiner catch-up: in or out?**

## What implementing it would touch (not done)

- `canon.xlsx`: a `promotion_rules` tab (gate level, bank size, jump, growth bonus, movement modifiers);
  a promotion-options column on classes; the second parent for hybrids (`promotes_from` holds only one).
- Engine: EXP and level-up on the battle map, a `Promotion` autoload, a barracks screen next to the
  convoy screen, high-tier weapon gating in `Equipment`/`Combat`, and tests for each rule above.
