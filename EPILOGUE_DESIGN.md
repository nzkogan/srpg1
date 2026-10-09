# The fallen and the epilogue death text -- design and status

Status: **implemented** (first pass). Added 2026-10-09. Canon's `epilogue_generation` tab gave a schema and a four-clause
grammar and said, plainly, that it is *a generator, not a script*; but the game had no deaths to write about (a unit that fell
simply reappeared on the next map). So this adds **permadeath**, the **death record**, and the **generator**. The wording and
every rule that canon did not decide are drafts, flagged below; all text lives in the new `epilogue_text` tab.

## Permadeath (new)

- A **main-roster unit** (the 18 minus the avatar) who falls on a map is *pending*. **Winning the map makes it final.** Losing,
  or restarting the map, discards the pending falls (`Epilogue.begin_map()` on a fresh start; a resumed suspension keeps them,
  since the mid-map snapshot is the whole `GameState`).
- A fallen unit has **left the company**: `Defections.is_gone()` answers true for them, so deployment, the barracks, the convoy
  screen and the deputy pool already hide them. A fallen unit never defects.
- **Not recorded:** the avatar (their fall would end the story, not write an epilogue), Anna (a guest), cargo units, the
  prologue (`map_f00`), and everything when `GameState.flags["casual"]` is true.
- **Their things:** the *pack* (everything but the weapon carried) goes to the convoy; the **carried weapon** meets its fate.
- Replaying a won map with permadeath still on is allowed; it is not special-cased.

## The record (taken at the moment of the fall)

`GameState.epilogue` -> `deaths[unit_id]` = canon's schema: `unit_id`, `chapter_id` (the map's chapter), `killed_by_type` and
`killed_by_id`, `epithets` (deeds held), `weapon_id` + `weapon_fate`, and the support partner and tier -- plus `slain` (what the
unit's `Slayer of` was earned against), `seq` (the order of falling), `own_action` and the killer's index (for the fate).

**Killer** (`Epilogue.classify`), in canon's order of credit:

| Type | When | Clause |
|---|---|---|
| `defector` | a lieutenant who left the company | named: `Waldrada` |
| `named_creature` | the archetype stands for a Named | its `named.death_phrase`: `the Karkadann's charge` |
| `boss` | a boss-kind enemy | named: `Boyan`, `the warlord` |
| `polity` | a `state` soldier on a map whose `enemy_polity_id` is set | `a Diadem lance`, `an Assembly arrow` |
| `band` | anyone else (looters, relic hunters, privateers, or a soldier on a map that names no polity) | `a looter's axe` |
| `hazard` | the cold | `the cold` |
| `unknown` | nothing named it | `, in the chaos, to no blade anyone could name` |

`band` and `hazard` are **extensions to canon's enum**: the original five left looters and the weather with nowhere to be
credited. `unknown` is built and tested but nothing in the current rules produces it yet (it is for routs and unwitnessed deaths,
which the game does not have) -- except a fall whose cause was not passed, which reads as the chaos.

**Weapon fate** (`Epilogue.fate_for`, canon's four values): a **hazard** death leaves it `with_the_body`; an unnamed death,
`lost_to_enemy`; otherwise, if the one who struck the blow was **killed or captured by the end of the map**, `retrieved` (it goes to
the convoy -- "tied to the capture-supply loop"); if that enemy lives or fled (or was talked down) it keeps it: `thrown_and_lost`
when the unit died on its *own* attack (answering its counter), else `lost_to_enemy`. A unit with nothing wieldable has no weapon
and no clause.

**Support** is `Supports.support_status` (built earlier for this): the closest living bond (highest tier, then chain order), else
the closest bond at all. *Romantic* means the bond reached S.

## The sentence

`[NAME], [TITLE], fell at [PLACE][KILLER TAIL]. [WEAPON]. [SUPPORT].` -- assembled when asked, never stored, from `epilogue_text`:

- **Title** -- the strongest held deed: a paragon-gating one beats one that does not, ties in canon order. A token ending in "of"
  takes the quarry (`Slayer of the Karkadann`); one starting "of " stands (`of the Ford`); any other is `the Untouched`. No deed:
  the name stands alone.
- **Place** -- the chapter's title, a leading "The" lowered (`the tally house`).
- **Weapon** -- one line per fate: *passed to no one*, *came home in the convoy*, *was thrown, and not found again*, *was buried
  still holding it*. Absent if unarmed.
- **Support** -- seven lines (platonic C/B/A, romantic C/B/A/S), read **at display time** so they follow the partner: *had fallen
  already*, *did not outlive the war either*, *was gone from the company by then*; unpaired is the quiet indictment, *No one at the
  fire was close enough to grieve properly.*
- **No pronouns.** Canon's worked examples say "His axe" / "He carried nothing"; the game does not know anyone's pronouns, so every
  line names instead. (A validator warning catches a pronoun in a phrase.) Canon's second example also has "He carried nothing
  worth a clause" for an unarmed unit; the rule text says the clause is *absent* in that case, so it is.

## Where it shows

- On the **win screen**, after the rewards: the sentence for each unit that fell and is now final.
- **R** on the overworld: *The Fallen* -- the whole roll in order; the place panel says how many have fallen.

## Canon additions (all in `canon.xlsx`; validator rule c07p)

`epilogue_text` (new tab, 31 phrases), `enemy_archetypes.affiliation` (state / band / individual / named) and `death_noun`,
`named.death_phrase`, `polities.epilogue_adjective`, `maps.enemy_polity_id`, and `band` / `hazard` in the `killed_by_type` enum.

## Drafted guesses to confirm

- **`maps.enemy_polity_id`**: state soldiers belong to the polity *opposite the chapter's route* (a Diadem-route map fields Assembly
  soldiers); both-route maps name none, so those soldiers read as a band. This asserts something about the world; tune it map by map.
- **Permadeath on a win, not on a fall** (a lost or retried map costs no one), the avatar exempt, replays allowed.
- Weapon fates as above, especially `retrieved` meaning the convoy gets the weapon back.
- The Named's verbs (the Simurgh's light, the Huma's shadow, the Anzu's stoop, the Karkadann's charge, the Shadhavar's song) and
  every line of the support set are my wording.

## Not built

- `unknown` deaths from routs and unwitnessed kills (no such mechanic yet); a *forged* weapon's provenance name
  (done in WEAPON_NAMES_DESIGN.md: `weapon_carried` is the weapon's provenance name).
- A game-over rule if the whole roster falls; anything that consumes the roll at the end of the game (the ending screens do not
  exist yet); a deputy who falls after the writ; scenes where a partner reacts.
- Cold is the only hazard; each new one needs an `epi_hazard_<id>` phrase.

Tests: `tests/test_epilogue.gd` (101 checks, mutation-checked).
