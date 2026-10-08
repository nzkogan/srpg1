# Promotion, levelling and abilities -- design and status

Status: **implemented** (first-pass numbers, all tunable in `canon.xlsx`). Drafted 2026-10-05; revised
after the decisions below; the paragon tier and save/load added 2026-10-06; the Capture action 2026-10-07; Shove and Smite 2026-10-08; collision damage 2026-10-09; Bribe 2026-10-10; the miasma and delivery deeds 2026-10-12; the dispersal and talk deeds 2026-10-13. Everything here is a design proposal, not setting canon.

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
  All four deeds that gate paragon are recordable. Four more deeds that don't gate it are too (miasma, delivery,
  dispersal, talk -- see below), so every epithet in canon is now recordable.
- **Which class**: a paragon class whose primary art the unit already knows -- lance: Bogatyr; sword: Fianna
  (sword + bow); bow: Donso; brawl: Toa; axe: Jaguar knight (axe + brawl) or Eagle knight; reason: Tzitzimitl (which also
  needs the Simurgh paralogue won -- a drafted guess at canon's "paralogue"). A Billman, knowing axe *and* lance,
  sees axe and lance paragons. Faith: the **Krivis** (below) -- canon had none, and it is the one paragon class here that
  is *drafted* rather than canon. A hybrid sees the paragons of both its arts: a Miasma Warden (reason + faith) the
  Tzitzimitl and the Krivis, a Pardoner (bow + faith) the Donso and the Krivis, a Ferryman (axe + faith) both axe
  paragons and the Krivis.
  Personal-class units take a *milestone* that keeps their class; Kest goes Thief -> Assassin or Trickster;
  Dietmar and Torvald, already order tier, are eligible at 30 like anyone.
- **What it gives**: another flat **+30** stat jump, **+5 more** growth on every stat, **+1 ability slot**, the class's
  movement type and shape, and the class's canon signature skill as the first ability in its pool (Astra,
  Deadeye, Fierce Iron Fist, Colossus, Stun, Corrosion, Charge, Verdict -- as passive approximations).

### The faith paragon: the Krivis

Canon's paragon list had a class for every art but faith, so no faith unit (Maren, Anselm, a Great shield, a Bishop...)
could ever take the second tier. Drafted to fill it (2026-10-14), in the same shape as the rest:

- **Krivis** -- *Baltic*, after the high priest of the Baltic religion, a judge as much as a priest. It suits a faith that
  rules on the dead and the living, and sets the Krivis against the hermits' refusal to adjudicate. Chosen for a
  culture the list doesn't have yet (the others: Slavic, Celtic, Mande, Polynesian, Aztec, and the in-game Tzitzimitl).
- **Faith art, infantry movement, no second art, no unlock map** (so, like most paragons, it is there once you are
  certified, level 30, have a deed, and can pay). Infantry is the plain default; there is still no armor paragon.
- **Signature skill: Verdict** -- a passive approximation like the others: +6 hit, +6 avoid, +4 dodge, +3 guard, always. It
  leads the Krivis's ability pool, and only a Krivis can pick it.
- Everything about it is a guess: the name, the culture, the movement type and Verdict's numbers are mine, not setting
  canon. It is one row in `classes` (`cls_krivis`) and one in `abilities` (`ab_verdict`); change them there.

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
- Not modelled: pushes off a ledge (no ledges exist).

## Kheldar's Bribe

Canon: "Kheldar; end-map income, bribe one enemy to neutral" (the Factor class). A map action, drafted:

- **How**: **B**, then an arrow key (or a click) on an adjacent enemy. B first lists what each adjacent enemy would
  cost, and you may cancel with any other key. He has to walk up to them -- a merchant with a purse, not a ranged
  attack.
- **Cost**: **40 gold + 10 a level of the enemy** (`bribe_cost_base`, `bribe_cost_per_level`): a level-5 levy is
  90, a level-10 billman 140 -- real money against ~240 a map of income, so it's a choice, not a reflex. Paid from the
  shared gold; if you can't afford it the offer is refused and costs nothing.
- **Limit**: **one a map** (`bribe_per_map`, canon: "one enemy"). Bosses can't be bought.
- **Neutral**: the enemy stops acting for the rest of the map -- it doesn't move or attack, can't be attacked or
  captured, and isn't in the forecast -- but it still stands where it is (it blocks the tile and can still be
  shoved). Its token turns gold and the status line counts it apart ("Enemies alive: 3 (+1 neutral)").
- **Economics**: a neutral enemy is neither a kill nor a capture, so it adds nothing to the map's income; you paid to
  skip a fight, not to win one. It earns no EXP and no deed.
- Not modelled: enemy `behavior` text (a preacher who converts, a looter who preys on civilians) -- a bribed enemy is
  simply inert -- and Kheldar's Act-1 "ch1 cameo unkillable" rule.

## The miasma and delivery deeds

Two of canon's other epithets (they feed the forge vocabulary, not the paragon gate) are now recordable, and the
barracks lists them under "Other deeds" with progress.

- **Miasma** (`ep_miasma`, "Ash-walker", "ends turn on miasma tiles 5+ times"): each main unit that **ends the player
  turn standing on miasma** counts one -- tallied from where the turn *ended*, before the hazard damage lands and before
  the enemy phase, so a unit that is then cut down still counted. The deed is earned at **5** turn-ends
  (`epithets.count_needed`), kept across maps and saved, and the map says "Avatar has ended 3 of 5 turns in the
  miasma." on the way. Which terrain counts is data: `epithets.deed_terrain` = `ter_miasma`. Ice (a different hazard)
  and plain ground don't count. Maps with miasma today: a01, d09, ct19 and the Dove colony.
- **Delivery** (`ep_delivery`, "Carter", "escorts a cargo unit to its goal"): this needed **cargo**, which didn't exist
  -- "escort" maps just let any unit walk to the E tile. Canon now has a `cargo_units` tab (a wagon or cart is a
  player-side unit: it can't fight, has hit points and defences, and moves by its movement type) and
  `maps.cargo_needed`. Drafted for two maps: **d03** -- its three wagons, 2 to deliver (canon: "escort 2 of 3 wagons,
  move 4"; they have armor movement, so a wagon can't take the foot-only ford and must use the bridge) -- and **a01** --
  the medicine cart, 1 to deliver.
  - On a cargo map **only cargo delivers**: a wagon stepping onto E leaves the map as delivered; a person on E
    escapes nowhere. `cargo_needed` deliveries win the map.
  - Enemies attack cargo like any unit, and the miasma and cold hurt it, so the cart steers round a01's miasma.
    If the cargo still on the map plus what's been delivered can no longer reach `cargo_needed`, the map is **lost**.
  - A main unit that is alive and **within 2 tiles of the goal** (`delivery_radius`) when a wagon is delivered has
    escorted it and earns the deed (one delivery is enough). **W** selects the next cargo unit (the number keys only
    reach the first nine units).
  - Maps with the older "escort" shape and no cargo (x11, m21) are unchanged.
  - Not modelled: civilians chasing the cart and looters killing them (a01's own note), the wagons' defence and the
    cart's HP (first-pass numbers), and who stayed *with* the cargo along the way -- only who is near at the end.

## The dispersal and talk deeds

The last two epithets (forge vocabulary only, no paragon gate). Both are canon's own resolution paths for chapter a02
-- its `teaches_system` reads "talk / capture / disperse".

- **Routing** (what dispersal needs). Canon says conscript levies "flee below half HP, counted separately from other
  losses" (map_d02's note), but nothing modelled it. Now `enemy_archetypes.flees_below_pct` (50 for the levy; blank =
  never) makes a non-boss **below** that percent of its HP **break**: in the enemy phase it stops fighting and runs for
  the nearest map-edge tile it can reach (preferring the rim even over safer inland ground), or failing that the tile
  farthest from every player unit. Reaching the rim takes it **off the field, unkilled**. It can still be hit, killed
  or captured on your turn before it gets away. Bosses never break; a bribed (neutral) enemy just stands.
- **Dispersal** (`ep_dispersal`, "Merciful", "routs levies below half HP without killing"): whoever dealt the blow that
  took a levy **below** the line (a hit, a counter, or a collision) is credited; if the levy then runs off the field
  instead of being finished, that unit gets a step. **3** routs earn the deed (`count_needed`; canon gives no number).
  A levy that was killed first, or was already below the line when your blow landed, doesn't count. A routed enemy
  drops nothing (it keeps its weapon).
- **Talk** (`ep_talk`, "Peacemaker", "resolves an enemy by conversation"): **T**, then an arrow key (or a click) on an
  adjacent enemy -- T lists the odds first, and which enemies won't listen at all. Any main unit can try. The chance is
  `40 + 3 x the speaker's Lck + 2 x (speaker level - enemy level) + the enemy's talk_mod`, kept between 5% and 95%.
  Only enemies with a `talk_mod` can be talked to (the conscript levy +20, the garrison soldier +30, Boyan -10;
  looters, privateers, hunters and the war captains are deaf). A war captain and Vashti's seat are canon's
  "will not talk to you" cases, so they stay deaf.
  - **Success**: the enemy leaves the map unharmed saying its `talk_line`; no kill, no drop, EXP as for a kill, 20 gold
    of income at the end, and the speaker earns the deed (one is enough). A **boss that yields still ends a 'defend'
    map** -- answering Boyan on a02 is canon's "answer" path.
  - **Failure**: the action is spent and that enemy **won't listen again this map**. An enemy with nothing to say, or
    that has stopped listening, is refused for free.
  - Talking counts as taking part, like a capture, so a talker who is never struck can still earn a no-hit map.
- **Income** now has four peaceful-or-not rates: 15 a kill, 25 a capture, 20 a talk, 10 a rout, on top of the 200.
- Not modelled: Jost's and Kest's recruit-by-talk conversations, the dialogue itself (the `talk_line`s are placeholder
  flavour), and the preacher converting townsfolk. The odds and rates are first-pass numbers.

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
- On a map: EXP and level-ups after every fight (counters included), **C** to capture and **S** to shove/smite and **B** to bribe (units with them), **T** to talk, income and class unlocks on a win.

## Not built / open

- The Krivis (faith paragon) is drafted, not canon: name, culture, movement and Verdict are all guesses.
- Capture: only Gunnar and the Pardoner can; the
  50% rule, the 25 gold ransom and "anyone but a boss" are first-pass numbers; enemy `behavior` text isn't modelled, so
  no enemy is more or less willing to surrender.
- Shove/Smite: only Gunnar and the Housecarl have it; the 1/2 tile distances, the armor rule and the 10% collision are first-pass numbers.
- Mid-map state isn't saved: you save between maps (and the autosave fires after each win).
- First-pass numbers: the fee curve, the +25 jump, the +5 growth, the EXP formula and the ability values are all
  rows in `promotion_rules` / `abilities` and want playtesting.
- The unlock maps are my thematic guesses; canon doesn't say when hybrids open.
- Support partners don't share EXP (an easy, thematic addition).

## Where it lives

`canon.xlsx`: `promotion_rules` (67 parameters), `abilities` (41), `classes.unlock_map_id`, `classes.map_actions`,
`epithets.tracked`, `epithets.count_needed`, `epithets.deed_terrain`, `cargo_units`, `maps.cargo_needed`, `enemy_archetypes.flees_below_pct/talk_mod/talk_line`;
validator rules c07i. Engine: `scripts/progression.gd` (autoload), `combat.gd` (ability hooks), `equipment.gd`
(current-class proficiency, high-tier gate), `map_grid.gd` (EXP, income, unlocks, deed telemetry),
`barracks_screen.gd`, `forecast_view.gd`, `game_state.gd` + `save_game.gd` (autoload) + `save_screen.gd`. Tests: `test_progression`,
`test_progression_map`, `test_barracks`, `test_paragon`, `test_deeds`, `test_barracks_paragon`, `test_save_game`,
`test_save_screen`, `test_capture`, `test_shove`, `test_bribe`, `test_cargo_miasma`, `test_dispersal_talk`, plus the ability checks in `test_combat_exchange`.
