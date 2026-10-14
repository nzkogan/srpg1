# The Skald (Edda's kit) -- design and status

Status: **implemented** (first pass). Added 2026-10-24. The next gap I found in canon: `cls_skald` read only "Edda; Refresh + Steal + epithet aura".
Edda has no weapon art, so before this she had no kit at all (an Epithet Aura ability row gave her a flat +5 hit and avoid, nothing more). The three
parts of the kit now exist; the rules for each are my drafts, flagged below. Canon's `ascension_signals` tab was the other candidate and is left alone: it says it is
an authored decision, not a drafting job.

## Refresh  (key R)

An **adjacent ally who has already moved or acted** may move and act again; the Skald's own action is the price. An ally who has done nothing needs nothing (refused,
and Edda keeps her action), a tile with no ally in it is refused, and cargo units are not refreshed. One Refresh a turn, because it takes her action.

## Steal  (key X)

Lift an **adjacent enemy's weapon**: it goes into the convoy as a real weapon (an Iron Sword from a sword levy; a Silver Lance from a high-tier captain) and the enemy is
left **unarmed** (it neither attacks, counters nor moves, as with the Anzu Edge). This is also the first way to get a Worn weapon, which nothing else gives you.

- **Chance:** 50%, plus 5 points for each point of the Skald's speed over the enemy's, minus 5 for each under, never below 5% or above 95%.
- **A boss holds its weapon fast**, always.
- **A failed try** is seen: that enemy is on its guard and cannot be robbed again, and her action is spent. An enemy with nothing left (already robbed, or unarmed
  some other way) says so, and costs her nothing.

## The Epithet Aura  (passive)

Every ally (herself included) within **2 tiles** of a living Skald gains **+3 hit and +3 avoid for each epithet it has earned**, up to **+9** (three deeds' worth). A deed part-way
(1 of 5 miasma tiles) does not count. The bonus rides on the same `sup_hit` / `sup_avoid` keys the support bonuses use, so the forecast panel and every exchange already
read it, and it adds to a support partner's effect rather than replacing it. Several Skalds would not stack (the first in range counts); there is only one. The
prologue has none. It makes the deeds a player earns a reason to keep Edda close, and a unit with no deeds gets nothing, which is the point.

## Drafted guesses to confirm

- Refresh as a plain "act again" with her action as the price (no limit per map), Steal's formula, the 5% floor and the boss rule.
- The aura numbers (2 tiles, 3 a deed, cap 9) and that it counts earned deeds, not kills.
- That Steal gives the weapon to the **convoy**, not to Edda (she has no weapon art and cannot wield it).
- The old `ab_epithet_aura` ability row is kept (a small personal extra for Edda) and its note now says so; if you would rather retire it, delete the row.

## Not built

- Skald deeds (nothing scores Refresh or Steal for the deputy ledger or the epithets); a Steal that picks which item (enemies carry one weapon); Steal of a Named creature's pact object;
  a Refresh that grants only the action or only the move.
- The other personal classes with no kit: the **Martyr** (Provoke + Miracle + Resolve; only Resolve exists, as an ability) and the **Quartermaster** ("one per column"). Neither has a
  unit holding it yet.

## Where it lives

`canon.xlsx`: `classes.cls_skald` (map_actions `refresh|steal`, signature_skill `Epithet Aura`), `promotion_rules` (`steal_base`, `steal_per_spd`, `aura_radius`, `aura_per_deed`,
`aura_cap`), the `abilities` note; validator rule c07t. Engine: `progression.gd` (`can_refresh`, `can_steal`, `has_epithet_aura`, `earned_deed_count`, `aura_bonus`, `steal_chance`),
`map_grid.gd` (`_begin_skald`, `_skald_toward`, `_aura_for`, `_combatant_for_unit`). Tests: `test_skald` (34 checks, mutation-checked).
