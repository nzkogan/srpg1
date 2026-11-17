# Project handoff

Last rewritten 2026-11-17, after a whole-project review. This replaces the September handoff, which predated the code.

## Where things stand

- **Canon:** `canon.xlsx`, about 50 tabs, validated by `canon_validate.py` (0 blocking). Story questions that canon
  deliberately leaves open, and that the author must answer privately, are in `TRUTH.md`.
- **Game:** a Godot 4.3 project in `game/` that runs end to end: world map, 44 battle maps, two Act 1 routes of six
  chapters, Act 2 columns, the Act 3 branches, eight paralogues, three playable flashbacks, saving, supports, the
  barracks, forges, mounts, the deputy's ledger, the trial, the epilogue roll and the patron procs. About 2,500 headless
  test checks and a map sweep run on every push.
- **Plays in a browser:** CI exports a web build (Compatibility renderer, single-threaded).
- **No art, no audio, no written dialogue.** Every visual is procedural. The 29 scenes are one-line specs; the 153
  support chains are summaries.

## Decisions from the 2026-11-17 review

1. **Systems are frozen.** The game was wide and thin: about 30 systems on maps with one or two enemies. New work goes
   into making a small part of the game good, not into more rules.
2. **Cut:** bound ground (seals), the patron of the day, and the 72 patron offices. All three modified the same rolls as
   the patron procs: the "second stat system" canon warns against. Act 1 cut from ten chapters a route to six; the cut
   chapters had no story job. Their places remain on the world map as waypoints.
3. **Renamed:** the Fire Emblem residue. Indech and Macuil (Three Houses' hermit saints) are now Pambo and Poemen, after
   two Desert Fathers who refused to judge; Anna is Alexia (still after Anna Komnene, via the *Alexiad*); the workbook
   is no longer titled after Fodlan.
4. **Re-anchored:** the Enlightened One's Perverse ending now cites the Great Disappointment, not Sabbatai Zevi, so the
   lending sect's false god no longer leans on a Jewish model. The Hierophant keeps the Sabbatai/Nathan model.
5. **Controls:** a context action menu (Space or right-click) lists what the selected unit can do. The hotkeys remain
   as shortcuts.
6. **Art direction:** painted 2D, in the Chrono Cross sense (painted backdrops, characters on top), anchored on Erin's
   paintings, with grounded character design. The earlier HD-2D Blender diorama plan is parked; the F0 block-out and
   its Blender scripts remain as reference.

## What to do next, in order

1. **Answer `TRUTH.md`** (five decisions). Everything in the story leans on them.
2. **Build the vertical slice:** the prologue, Diadem chapters 1-3 and one paralogue, finished: real enemy rosters
   (most Act 1 maps have one or two enemies), written dialogue for their scenes, portraits and painted maps.
3. **Split `map_grid.gd`** (3,700 lines) into rules and view before the graphics work lands on it.
4. **Confirm or cut the drafted guesses:** each `docs/design/*_DESIGN.md` lists them (about 70 in all).
5. **A playthrough harness:** let the enemy AI drive the player's side so each map can be checked for being winnable,
   which canon's README asks for and nothing yet tests.

## Still open in canon

The validator's 13 warnings: three runs of seize maps, and pacing in Act 3 (the war arc runs about ten chapters without
a warm or wondrous one) and before the Poemen paralogue. Fixing the pacing is a story decision: which chapters change
register, or where a warm chapter is added.

## Art and data pipeline notes that still hold

- Image models restructure a map well only from a flat colour-block layout plus a separate style reference, generated
  fresh. Asking them to edit an existing image preserves its composition.
- Flat files bundled with the build (`game/data/*.json`); no hosted backend.
