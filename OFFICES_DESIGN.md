# Patron offices -- design and status

Status: **implemented** (first pass), 2026-11-10. The last patron item from your direction: each of the 72 spirits of the Ars Goetia has an **office** (what the old books say it does), and now that office is a small passive for a bearer who earns it.

## The rule

- Every patron has `office_text` (the Goetic office in plain words: "teaches every tongue; makes runaways return; destroys dignities") and an `office_id`, one of **13 families** in the new `offices` tab. A family is an abilities-shaped effect (the same columns and conditions as the `abilities` tab, so nothing new in combat):

| Family | Effect |
|---|---|
| Veil of Glamour | +8 avoid |
| Tongues | +20% EXP |
| Sight of the Hidden | +8 hit |
| Liberal Sciences | +10% EXP, +3 crit |
| Herbs and Stones | at half HP or less, +3 guard |
| Light Fingers | +6 dodge |
| Concord | +4 hit, +4 avoid |
| Strife | +1 damage, +3 crit |
| Voice of Beasts | against mounted foes, +10 hit and avoid |
| Swift Carrying | +2 speed |
| Storm and Water | with a bow, +10 hit, +4 crit |
| Speaking Dead | at half HP or less, +3 damage, +5 crit |
| Treasure and Coin | +1 guard, +3 dodge |

- The numbers are scaled by the patron's **rank** (`office_pct_high` 150% for a King or Prince, `office_pct_mid` 125% for a Duke, Marquis or Earl, `office_pct_low` 100% for a President or Knight), never rounding a nonzero number to nothing.
- A bearer carries **their own patron's office** (the pair they were born under) when their **lean** toward the angel or the demon is at least `office_unlock_lean` (2), or while they **hold a patron's form** (the Morph gamble). So it is earned by conduct (mercies and kills move the lean), by a trial's weight, or by the gamble. Enemies never lean past one step, so offices are the company's.
- It is a free ability: it does not use a slot and it is not in the ability list. In a fight it is added to the combatant; the EXP families add to the unit's EXP multiplier.
- The barracks shows a line under the birth line: "Office of Bael: makes men invisible... Veil of Glamour: +12 avoid." and, before it is earned, "...It answers only a bearer who leans clearly toward one side."
- Flashbacks and enemies carry none.

## Drafted guesses to confirm

- **Which family each of the 72 offices belongs to** (patrons.office_id): I read the Ars Goetia's descriptions as I remember them and wrote them in my own words. Check them against your edition; each is one cell.
- Every number in the table, the rank scaling, and the unlock at lean 2.
- That an office is the same whether the bearer leans angel or demon.

## Not built

- Different offices for the angel's side and the demon's (the same spirit teaching vs. tempting).
- Offices that are map actions or income (treasure finding, teleporting), a seer's reveal of hidden things, or a love office that touches supports.
- An office for enemies and Named.

Tests: `tests/test_offices.gd` (25 checks, mutation-checked; survivors are equivalent: the "no patron" guard is covered by the birth check, the minimum-of-one only matters if a scale below 100% is set, and the flashback guard is unobservable because no memory unit is a known roster unit). The validator's c07o checks every patron has an office and every office does something with a real condition.
