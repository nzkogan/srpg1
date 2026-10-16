# Anna's fixed scene and the enrolment of the dead -- design and status

Status: **implemented** (first pass). Added 2026-11-04. Canon's `guest_units.gst_anna` (the faith guest who covers for Anselm and Maren once both have gone, DEFECTIONS_DESIGN.md) says: *"No tiered support chain -- one fixed scene instead"*, and that on leaving she
*"continues the Continuing Word's rebaptism fieldwork (prc_rebaptism) off-screen -- cross-referencing parish/decan lists to enroll the plague dead by name."* Neither was built. Her **Act 3 payoff is not**: canon marks it a RECONSTRUCTION GAP ("needs the
real text from the source session"), and the calendar tab's decan-token row depends on it. That text is not mine to make up, so it stays open.

## Her one fixed scene

`scenes.sc_anna_fixed` -- a drafted **pre-battle scene on the eve of the Reunion** (`ch_rf20`, the map she leaves on). Speakers: the avatar and Anna. It shows (SCENES_DESIGN.md) while she is with the company, or after: the scene condition `depends_on_units: gst_anna`
now understands guests. The summary is a draft: Anna lays the parish lists she has been cross-referencing beside the decan tables and shows the avatar where they will not agree; she does not say what that means, only that someone must go on enrolling the dead by name.
It settles nothing about the calendar.

## The enrolment of the dead

Once Anna has departed, **the fallen roll** (key R on the overworld, EPILOGUE_DESIGN.md) closes with *"Each of them is entered by name in the parish lists, and the name is spoken."* (`epilogue_text.epi_roll_enrolled`): her off-screen work, and `prc_rebaptism`'s own claim that nobody is
enrolled without their name being spoken. An empty roll stays empty. `prc_rebaptism` is the one sect practice the game now carries.

## Drafted guesses to confirm

- That the fixed scene sits at the Reunion (her last map) rather than the map she joins on, and its summary.
- That the enrolment shows as the roll's closing line.
- The name itself: canon's `naming_reference` takes it from **Anna Komnene**, the Byzantine historian who wrote the record of her father's reign -- a fit for the one who might know the date -- but it will also read as Fire Emblem's Anna. It is a one-cell rename in `guest_units` and `naming_reference` if you want one.

## Not built

- The scene's script, and Anna's Act 3 payoff (the decan token: what it proves and who contests it) -- authored content.
- The other practices (the pilgrimage's forbidden summit, the oracle's fee, the sky burial) -- nothing in canon says what they do in play.

Tests: `test_scenes` (Anna's scene, guest conditions) and `test_epilogue` (the roll's closing line); mutation-checked, with one equivalent survivor (the `departed` test against a state that only ever holds `departed`).
