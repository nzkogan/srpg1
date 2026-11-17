# Alexia's fixed scene and the enrolment of the dead -- design and status

Status: **implemented** (first pass). Added 2026-11-04. Canon's `guest_units.gst_alexia` (the faith guest who covers for Anselm and Maren once both have gone, DEFECTIONS_DESIGN.md) says: *"No tiered support chain -- one fixed scene instead"*, and that on leaving she
*"continues the Continuing Word's rebaptism fieldwork (prc_rebaptism) off-screen -- cross-referencing parish/decan lists to enroll the plague dead by name."* Neither was built. Her **Act 3 payoff is not**: canon marks it a RECONSTRUCTION GAP ("needs the
real text from the source session"), and the calendar tab's decan-token row depends on it. That text is not mine to make up, so it stays open.

## Her one fixed scene

`scenes.sc_alexia_fixed` -- a drafted **pre-battle scene on the eve of the Reunion** (`ch_rf20`, the map she leaves on). Speakers: the avatar and Alexia. It shows (SCENES_DESIGN.md) while she is with the company, or after: the scene condition `depends_on_units: gst_alexia`
now understands guests. The summary is a draft: Alexia lays the parish lists she has been cross-referencing beside the decan tables and shows the avatar where they will not agree; she does not say what that means, only that someone must go on enrolling the dead by name.
It settles nothing about the calendar.

## The enrolment of the dead

Once Alexia has departed, **the fallen roll** (key R on the overworld, EPILOGUE_DESIGN.md) closes with *"Each of them is entered by name in the parish lists, and the name is spoken."* (`epilogue_text.epi_roll_enrolled`): her off-screen work, and `prc_rebaptism`'s own claim that nobody is
enrolled without their name being spoken. An empty roll stays empty. `prc_rebaptism` is the one sect practice the game now carries.

## Drafted guesses to confirm

- That the fixed scene sits at the Reunion (her last map) rather than the map she joins on, and its summary.
- That the enrolment shows as the roll's closing line.
- The name itself: renamed from Anna to **Alexia** on 2026-11-17, because "Anna" with red hair and a ponytail reads as Fire Emblem's merchant. It still comes from **Anna Komnene**, through the *Alexiad*, the history of her father's reign that she wrote: a fit for the one who might know the date.

## Not built

- The scene's script, and Alexia's Act 3 payoff (the decan token: what it proves and who contests it) -- authored content.
- The other practices (the pilgrimage's forbidden summit, the oracle's fee, the sky burial) -- nothing in canon says what they do in play.

Tests: `test_scenes` (Alexia's scene, guest conditions) and `test_epilogue` (the roll's closing line); mutation-checked, with one equivalent survivor (the `departed` test against a state that only ever holds `departed`).
