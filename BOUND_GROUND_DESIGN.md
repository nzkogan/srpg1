# Bound ground -- design and status

Status: **implemented** (first pass), 2026-11-08. A map's patron is no longer only a name in the briefing: **seals** mark tiles of the field, and a fighter standing on a seal has their patron gifts scaled by who holds the ground.

## The rule

- Every campaign map has **two seals** on fixed tiles (canon `maps.seal_tiles`, `col:row|col:row`; map_d02's are `6:6|10:6`). Memories (prologue and flashback chapters) have none.
- The ground belongs to the **pair of the chapter's location** (`locations.patron_id`, `patron_side`), so the world map's canonised relationships now matter on the field. Before the reveal it is "bound ground" and the briefing names the patron; afterwards "the angel's ground", "the demon's ground" or "shared ground".
- Anyone standing on a seal (either army) has their patron procs scaled:

| Held by | Blessings | Curses |
|---|---|---|
| the angel | 150% | 50% |
| the demon | 150% | 150% |
| shared (balanced) | 125% | 125% |

- A bearer born under **the very pair the seal belongs to** is at home: their blessings are scaled a further 150%.
- Scaled chances are rounded, dropped if they fall to nothing, and capped at twice `patron_chance_max`. The main RNG is untouched.

## Breaking a seal

A **Pardoner** presses **[U]** to break a seal on or beside them. It takes their action, once a turn, and is refused once the field is won or lost. A broken seal scales no one; the map redraws without it. Suspended battles remember which seals are left (`seals_left` in the snapshot).

Parameters: `seal_angel_blessing_pct`, `seal_angel_curse_pct`, `seal_demon_blessing_pct`, `seal_demon_curse_pct`, `seal_balanced_pct`, `seal_home_pct` (promotion_rules). Validator c07s checks that seal tiles lie inside their map.

## Drafted guesses to confirm

- All the percentages, and that the demon's ground raises curses as well as blessings (the angel's ground softens them).
- Two seals per map, at the tiles I drafted; which tiles matter is a level-design call.
- The Pardoner as the unsealer (it is the class that already captures); a different class or an item is one canon cell (`classes.map_actions`).
- Seals are drawn as the patron's sigil in the holder's colours.

## Not built

- Seals that move, are re-laid by an enemy, or can be held by standing on them for a turn.
- A seal's own effect beyond scaling (healing ground, a ward).
- The patron of a chapter's day.

Tests: `tests/test_seals.gd` (33 checks, mutation-checked: side branches, home bonus, rounding, zero-removal, cap, adjacency, once-a-turn, won-field refusal, unknown-tile break, snapshot, control label).
