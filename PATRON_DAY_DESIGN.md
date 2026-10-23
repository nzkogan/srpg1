# The patron of the day -- design and status

Status: **implemented** (first pass), 2026-11-09. The calendar already says which *sign* governs a chapter (CALENDAR_DESIGN.md). Each sign holds six five-day bands, one per patron pair, so a chapter's day now falls to one **pair**, and that pair's bearers answer louder on it.

## The rule

- The sign is the calendar's (`Almanac.governing`). The **band** inside it is `((chapter number - 1) / 12) mod 6`: one band each time the wheel comes round, so chapters 1, 13 and 25 under the court's calendar are the Ram's first, second and third bands (Bael, Agares, Vassago). Twelve signs times six bands is the 72, so a long enough campaign visits every pair.
- Chapters whose calendar names no day (the Unstained, the silent) have no patron of the day; neither do the prologue and the flashbacks.
- On a chapter's map, any fighter (either army) born under that pair has their **blessing** chances raised by `patron_day_bonus` (5 points), capped at twice `patron_chance_max`. Curses are untouched; it stacks with bound ground and a morph form. The main RNG is untouched.
- It is legible, with no menu: the briefing adds "The day falls to Amon (days 1 to 5 of the Bull). Their favours run +5%: Brandt." (after the reveal: "Amon and <angel>", "blessings"), and the overworld's next-chapter line says the same.

It is the same size and spirit as the calendar's +5: a nudge for the people born under the day, not a second stat system.

## Drafted guesses to confirm

- The band arithmetic (a band per wheel turn) and that it only touches blessings.
- The +5 points.
- That the enemy's bearers benefit too.

## Not built

- A feast or festival that makes the day matter beyond blessings.
- The 72 patrons' own offices as skills.
- A day indicator on the world map beyond the next-chapter line.

Tests: `tests/test_patron_day.gd` (20 checks, mutation-checked). Parameter: `patron_day_bonus` (promotion_rules).
