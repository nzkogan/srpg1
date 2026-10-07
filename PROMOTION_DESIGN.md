# Promotion, levelling and abilities -- design and status

Status: **implemented** (first-pass numbers, all tunable in `canon.xlsx`). Drafted 2026-10-05; revised
after the decisions below; the paragon tier and save/load added 2026-10-06; the Capture action 2026-10-07; Shove and Smite 2026-10-08; collision damage 2026-10-09. Everything here is a design proposal, not setting canon.

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

## The paragon tier (second certification)

Canon's paragon classes are "lv30+, deed-gated". The same principles apply: no cap, no gate, the earliest
moment is the cheapest, and nothing can be missed.

- **Requirements** (the barracks shows them as a ticked checklist): already certified, **level 30**, **one deed
  that gates paragon**, and the fee -- **1000 gold at level 30, +150 for every level after**.
- **Deeds** are canon's epithets whose `gates_paragon` is "yes": boss kill, solo hold, no-hit map, capture. They are
  recorded during play per unit, **kept for the whole playthrough and never expire**, and announced the first time
  a unit earns one. Recordable now (`epithets.tracked`): *boss kill* (the killing blow on a boss that only this
  unit damaged -- "single combat" -- by attack or counter), *solo hold* (the same tile for 3 enemy phases running,
  attacked each time, no ally within 2 tiles), *no-hit map* (fought, and never hit, when the map is won; a unit
  that never fought doesn't count) and *capture* (take 5 enemies alive; see below -- the one deed that counts up).
  Miasma, delivery, dispersal and talk need mechanics that don't exist; the barracks lists them as "not recordable
  yet". All four deeds that gate paragon are now recordable.
- **Which class**: a paragon class whose primary art the unit already knows -- lance: Bogatyr; sword: Fianna
  (sword + bow); bow: Donso; brawl: Toa; axe: Jaguar knight (axe + brawl) or Eagle knight; reason: Tzitzimitl (which also
  needs the Simurgh paralogue won -- a drafted guess at canon's "paralogue"). A Billman, knowing axe *and* lance,
  sees axe and lance paragons. **Faith has no paragon class in canon**; I left that as a gap rather than invent one.
  Personal-class units take a *milestone* that keeps their class; Kest goes Thief -> Assassin or Trickster;
  Dietmar and Torvald, already order tier, are eligible at 30 like anyone.
- **What it gives**: another flat **+30** stat jump, **+5 more** growth on every stat, **+1 ability slot**, the class's
  movement type and shape, and the class's canon signature skill as the first ability in its pool (Astra,
  Deadeye, Fierce Iron Fist, Colossus, Stun, Corrosion, Charge -- as passive approximations).

## The Capture action

Canon's `ep_capture` ("captures rather than kills 5+ times") needed an action to earn it, and canon gives that
kit to Gunnar ("Capture + Shove mercy kit"); the Pardoner hybrid's note ("seal not kill") fits it too. Shove isn't
built. A first pass, all drafted:

- **Who**: a class with `capture` in `classes.map_actions` -- the Bounty hunter (Gunnar) and the Pardoner. It follows
  the class, not the person.
- **How**: **C** on a map, aimed like an attack (Tab / click picks the target, the equipped weapon's reach decides
  what's in range -- Gunnar's bow takes range 2, not a neighbour). No dice and no exchange: if the target is
  **at or below 50% of its max HP** (`capture_hp_pct`) and not a boss, it is taken. A boss never surrenders. A
  refusal says why and doesn't spend the action.
- **What it does**: the enemy leaves the map, takes the unit's action for the turn, counts as having fought (so a
  captor can still earn a no-hit map), and earns the **EXP of a kill** -- mercy is never worse than killing. It
  **drops nothing**, but each captive adds **25 gold** to the end-of-map income (`income_per_capture`, against 15
  for a kill; Kheldar's x1.5 applies) -- the price of the weapon you didn't take.
- **The deed**: each capture adds one to the unit's `ep_capture` count; the deed is earned at
  `epithets.count_needed` = **5** and announced then ("Gunnar earns a deed: capture ('Taker')."); until then the map
  reports "Gunnar has taken 3 of 5 captives." and the barracks shows "3 of 5". Counts are kept with the other deeds
  and saved. `count_needed` is a new column on `epithets` (1 for every other deed).
- **UI**: a unit with the action sees a line under the forecast -- "Capture ready: no kill, no drop, +25 gold
  ransom. (C)" in green, or why not in grey -- and the controls line lists [C] when the squad has such a unit.

## Shove and Smite

The other half of Gunnar's canon "Capture + Shove mercy kit", and the Housecarl's canon signature skill (Smite).
A map action, drafted:

- **Who**: `classes.map_actions` -- Gunnar's Bounty hunter has **shove**; the Housecarl has **smite**. A shove unit
  **upgrades to Smite when it certifies** (Gunnar's milestone at level 15 -- one more thing the early certification
  buys, and the barracks says so: "Your Shove becomes Smite"). The Housecarl's older passive Smite (+3 damage) is
  unchanged.
- **How**: **S**, then an arrow key (or a click) on an adjacent unit. The target is pushed **straight away** from the
  pusher: **1 tile** for Shove (`shove_distance`), **2** for Smite (`smite_distance`) -- "an additional space". Any
  other key cancels. It needs no weapon, so Gunnar can do it with his bow in hand.
- **What stops it**: the map's edge, impassable ground (for the target's own movement type) and any unit. **That is a
  collision**: the pushed unit takes **a tenth of its own max HP, rounded down** (`collision_pct`; 20 -> 2, 25 -> 2, under
  10 -> 0), and so does a unit it runs into, a tenth of *that* unit's own max HP. A Smite with a wall one tile behind
  the target moves it one tile and then slams; with a wall directly behind, nothing moves and it still slams. A
  collision is **never lethal** (it stops at 1 HP -- it's a mercy kit, and it keeps kill EXP and deeds out of it). An
  enemy hurt by a slam counts as damaged by the pusher, so a boss it touches is no longer "single combat". A friend's
  slam doesn't count as being struck for the no-hit deed. **Bosses are never pushed** (but one can be hit by a pushed
  unit). **Armor resists a tile** (`shove_armor_resist`): a Shove can't move armor at all (refused, free), a Smite moves
  it one -- resisting isn't a collision. Hazard ground is fine -- shoving a unit onto miasma is the point. There are
  no ledges, so nothing can be pushed off one.
- **What it costs / does**: the unit's action. No counter, no EXP, and it doesn't count as having fought. A push
  that goes the whole way does no damage. It works on **friends** as well as enemies (they keep their own move). A
  pushed unit doesn't trigger objective tiles by landing on them.
- Not modelled: pushes off a ledge (no ledges exist), and Kheldar's bribe.

## Saving and loading

State is split in `GameState` into `PERSISTED` (saved, with the type each must have) and `TRANSIENT` (one-shot UI
hand-offs); a test fails if any new variable is added to neither, so new state can't silently go unsaved.
`SaveGame` writes JSON to `user://saves/`: slots **auto**, **1**, **2**, **3**. Writes are crash-safe (write a temp
file, read it back, then swap; the previous save is kept as `.bak` and load falls back to it if the main file is
damaged). Saves carry a version; a save from a newer build is refused rather than guessed at, and `_migrate()` is
where older formats get upgraded. A load validates every field's type before touching the game, so a bad file can
never half-load.

The **autosave** is written after every won map (after income, deeds and unlocks) and when you leave the barracks or
convoy. It's off in headless runs so the test suites don't write to a real save directory. **L** on the overworld
opens the save screen (save, load, delete, new game; overwriting, deleting and a new game all ask for a second
press). The overworld draws won maps green and, on a fresh game, tells you if an autosave is waiting.

## Why this removes the min-max

| Rule set | What delaying promotion does |
|---|---|
| GBA-style (reset, 20/20 caps) | gains first-class levels (up to ~6 stat points) -- the 20/20 itch |
| This design | gains nothing and costs +100 gold a level; stays free of any cap, so a deliberate solo build is still legal |

A unit that waits loses nothing it can't pay for, a unit that certifies at 15 gets the +25, the movement type,
the +5 growth and the silver weapons immediately, and nobody has to optimise a level number to feel good about it.

## In the game

- **B** on the overworld: the barracks (levels, certification, recertification, abilities, paragon).
- **C**: the convoy (weapons). **S**: support conversations. **L**: save / load / new game.
- On a map: EXP and level-ups after every fight (counters included), **C** to capture and **S** to shove/smite (units with them), income and class unlocks on a win.

## Not built / open

- Faith has no paragon class; the miasma, delivery, dispersal and talk deeds aren't recordable yet.
- Capture: only Gunnar and the Pardoner can; Kheldar's bribe isn't built; the
  50% rule, the 25 gold ransom and "anyone but a boss" are first-pass numbers; enemy `behavior` text isn't modelled, so
  no enemy is more or less willing to surrender.
- Shove/Smite: only Gunnar and the Housecarl have it; the 1/2 tile distances, the armor rule and the 10% collision are first-pass numbers.
- Mid-map state isn't saved: you save between maps (and the autosave fires after each win).
- First-pass numbers: the fee curve, the +25 jump, the +5 growth, the EXP formula and the ability values are all
  rows in `promotion_rules` / `abilities` and want playtesting.
- The unlock maps are my thematic guesses; canon doesn't say when hybrids open.
- Support partners don't share EXP (an easy, thematic addition).

## Where it lives

`canon.xlsx`: `promotion_rules` (56 parameters), `abilities` (40), `classes.unlock_map_id`, `classes.map_actions`,
`epithets.tracked`, `epithets.count_needed`;
validator rules c07i. Engine: `scripts/progression.gd` (autoload), `combat.gd` (ability hooks), `equipment.gd`
(current-class proficiency, high-tier gate), `map_grid.gd` (EXP, income, unlocks, deed telemetry),
`barracks_screen.gd`, `forecast_view.gd`, `game_state.gd` + `save_game.gd` (autoload) + `save_screen.gd`. Tests: `test_progression`,
`test_progression_map`, `test_barracks`, `test_paragon`, `test_deeds`, `test_barracks_paragon`, `test_save_game`,
`test_save_screen`, `test_capture`, `test_shove`, plus the ability checks in `test_combat_exchange`.
