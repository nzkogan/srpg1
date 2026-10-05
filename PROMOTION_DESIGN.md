# Promotion, levelling and abilities -- design and status

Status: **implemented** (first-pass numbers, all tunable in `canon.xlsx`). Drafted 2026-10-05; revised
after the decisions below. Everything here is a design proposal, not setting canon.

## The goal

In the GBA Fire Emblems promotion has a right answer you can get wrong: level resets, both classes cap at
20, so promoting at 20/20 banks the most levels and promoting early quietly costs you. The goal here is the
opposite: **no timing puzzle, and no feeling of missing out.** You should never have to wonder whether to
hold a unit back to squeeze out more levels.

## Decisions that shaped it (yours)

| Question | Decision |
|---|---|
| Gate at 14, or keep levelling unpromoted? | **Keep levelling.** No gate, no bank. |
| Level cap | **None.** "If someone wants to solo with a character god bless 'em." |
| Is certification free? | **No.** A gold fee that rises the later you wait. |
| Recertification free? | **No** (half the promotion fee). |
| Hybrid classes | **Unlocked later**, by winning a specific map. |
| Late-joiner catch-up | **Yes**, plus flexible ability choice. |
| Abilities | **Pick N from a class pool.** |

## How it works

**Levels.** One continuous scale, no reset, no cap, no gate. Canon's tier floors (trained 5+, order 15+) are
the earliest you may *certify*, not a wall: an unpromoted unit keeps levelling forever. EXP is 100 a level; a
fight earns `clamp(10 + 3 x (enemy level - unit level), 1, 30)`, and a kill adds `clamp(30 + 5 x diff, 0, 60)`.
Level-ups roll the unit's own growth profile (`growths`), +5 on every stat once promoted.

**Certification (promotion).** Available from level 15. It costs gold: **300 at level 15, plus 100 for every
level after.** Because levels never reset and nothing is capped, the *only* thing waiting changes is the price
-- the earliest moment is simply the cheapest, and the barracks screen says so ("every level you wait adds
100"). What you get, all at once:

- a flat **+25 stat jump** (HP 4, Str 3, Mag 2, Dex 4, Spd 3, Lck 2, Def 4, Res 3), calibrated from canon's own
  numbers: a trained recruit that levels 5 -> 15 totals ~97.5 stats while the order-tier baseline for the same
  profile is ~124 (mean gap 26.2), so a promoted recruit lands ~122 -- parity with the order tier, and in range
  of Dietmar and Torvald's 115;
- the class's **movement type** and a small zero-sum **shape** (armor +HP/Def -Spd, riding +Spd -Def, flying
  +Spd -HP/Def); infantry has none;
- **+5 growth** on every stat for every later level, so each level spent unpromoted is a small standing loss;
- **+1 ability slot**;
- the **high-tier weapons** (silver): `high` needs an order, paragon or hybrid class; basic/mid stay open;
- the new class's art/proficiency (a Billman knows axe *and* lance, which is how the halberd finally gets a
  wielder).

The menu is which class, never when: the four order classes of the unit's art (one per movement type), plus any
hybrid sibling whose unlock map you've won. Personal-class units (Avatar, Gunnar, Edda, Kheldar) have a
*milestone* at 15 -- same cost, jump, growth and slot, no class change. Kest advances Footpad -> Thief.
Dietmar and Torvald are already order tier and have nothing to certify.

**Recertification.** A certified order-class unit may switch to another order class *of the same art* for half the
current fee. Level and every earned stat are kept; only the class's shape overlay and movement type change, and
ability picks the new class can't offer are dropped. Hybrids are not a recertification target.

**Hybrid unlocks** (`classes.unlock_map_id`, drafted, thematic): Billman = Throat Pass (map_tp19, where the
halberd-bearers stand), Ferryman = the Drowned March's lake (map_p_macuil), Pardoner = the mercy chapter
(map_h33_mercy), Ash Ascetic = the Stepped Coast's lake (map_p_indech), Miasma Warden = the Dove Colony
(map_p_karkadann). Until then they show red and locked, with the map to win.

**Late joiners.** The first time a unit is fielded (not merely looked at), if it is more than 3 levels under the
squad median it is raised to **median - 3** by its own expected growth (no dice, so it is repeatable). Units
below the median also earn **+25% EXP per level of deficit, up to +100%**, and Quick Study adds 15% on top.
Rinsa joining a level-15 squad arrives at 12 with a full kit, not 5 with a blank one.

**Abilities.** 34 passive abilities in canon's `abilities` tab, pooled by class tags (any / art / movement /
tier / class), seeded from canon's signature skills (Smite, Stake, Resolve, Pavise, Jump-lunge, Casting Tank,
Surveyor Kit, Deadshot...). Slots = **1, +1 at every 10th level, +1 once promoted**; you pick which, freely and
any time. Until you edit them a unit's kit fills itself with defaults (class skills first), so nobody arrives
empty. Effects are flat hit / avoid / crit / dodge / damage / guard / attack speed / EXP with conditions
(always, full HP, half HP or less, vs a movement type, wielding an art), and feed straight into the combat
forecast. Only passive combat effects: canon's map-action skills (Shove, Steal, Refresh, Provoke) need systems
that don't exist.

**Gold.** End-map income: **200 + 15 per enemy defeated, x1.5 with Kheldar alive** (his class is canon's
"end-map income"), once per map per playthrough. Roughly 240 a map over Acts 1-2, so ~4,800 by the end of
Act 2 against ~3,600 to certify twelve units at 300 -- enough to certify almost everyone around level 15-17,
not enough to do it carelessly.

## Why this removes the min-max

| Rule set | What delaying promotion does |
|---|---|
| GBA-style (reset, 20/20 caps) | gains first-class levels (up to ~6 stat points) -- the 20/20 itch |
| This design | gains nothing and costs +100 gold a level; stays free of any cap, so a deliberate solo build is still legal |

A unit that waits loses nothing it can't pay for, a unit that certifies at 15 gets the +25, the movement type,
the +5 growth and the silver weapons immediately, and nobody has to optimise a level number to feel good about it.

## In the game

- **B** on the overworld: the barracks (levels, certification, recertification, abilities).
- **C**: the convoy (weapons). **S**: support conversations.
- On a map: EXP and level-ups after every fight (counters included), income and class unlocks on a win.

## Not built / open

- Only the first tier. Canon's paragon tier (lv30+, deed-gated) and a second milestone for personal classes are
  not implemented; deeds should never expire if they are.
- No save/load: progress resets on restart, like supports and equipment.
- First-pass numbers: the fee curve, the +25 jump, the +5 growth, the EXP formula and the ability values are all
  rows in `promotion_rules` / `abilities` and want playtesting.
- The unlock maps are my thematic guesses; canon doesn't say when hybrids open.
- Support partners don't share EXP (an easy, thematic addition).

## Where it lives

`canon.xlsx`: `promotion_rules` (34 parameters), `abilities` (34), `classes.unlock_map_id`; validator rules c07i.
Engine: `scripts/progression.gd` (autoload), `combat.gd` (ability hooks), `equipment.gd` (current-class
proficiency, high-tier gate), `map_grid.gd` (EXP, income, unlocks), `barracks_screen.gd`. Tests:
`test_progression`, `test_progression_map`, `test_barracks`, plus the ability checks in `test_combat_exchange`.
