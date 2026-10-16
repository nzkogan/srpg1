# Flashbacks F1 and F2 -- design and status

Status: **implemented** (first pass). Added 2026-11-02. Canon's `flashbacks` tab lists three memories: **F0** (the prologue, built from the start), **F1** *The scribes' quarter* (act 1 -> 2) and **F2** *The last court of
the Long Reign* (act 2 -> 3). "A flashback may legally break the map laws: it is a memory and it is teaching, not testing. ... Different roster each time; nobody in a flashback is recruitable." F1 and F2 had no chapter, map or
roster. The rosters, enemies, grids and numbers are my drafts; the rules each flashback names are canon's.

## The shared laws (a memory is not a campaign map)

The prologue's rules were hard-coded to `map_f00`. They are now a **flashback** concept (the `Flashback` autoload): a map whose chapter's act is `prologue` or `flashback` has no permadeath (no fall is recorded), no forge, no
requisition, no income or deputy ledger, no suspending, no Named, and one weapon each with no repair; it deploys **its own roster** (`prologue_roster`, by `flashbacks.flashback_id`), and nobody in it joins the company.
The wall, the statue and the Sargath-only seize stay F0's alone. `flashbacks.engine_rule` names each memory's own mechanics.

## F1 -- The scribes' quarter (`ch_f01`, after the Act 1 finale `ch_d10|ch_a10`)

"The First Register is copied for the first time, under deadline. Protect the copyists; a page is lost and the game does not tell you which. Teaches the epithet ledger, by showing you a clerk recording deeds. The missing name
enters the world here, as an accident nobody notices."
- **Five defenders** of the quarter (Hadda, Zimri, Nuru, Abil, Sinna) hold a walled quarter round one scriptorium against eight raiders who come in by three gates. **Four copyists** sit at their desks (cargo units): **three must live**
  eight turns (`defend`, turn limit 8); if two fall the memory must be tried again.
- **The clerk**: every kill is written down as it happens -- *"The clerk writes it under Hadda's name: brought down a looter."* -- and the next turn opens with the entries and a tally (*Hadda 2, Zimri 1*). That is the epithet ledger shown as a
  clerk's hand, before the game asks you to read it.
- **The lost page**: when the copy is finished, one of its twelve pages (`prm_flashback_register_pages`) is lost. The choice is kept as a hidden flag (`flashback_f1_page_lost`) that **no text ever shows**: the win line is only *"The clerk counts the sheets and is
  satisfied."*

## F2 -- The last court of the Long Reign (`ch_f02`, after the Reunion `ch_rf20`)

"The church that held the realm together, on the day it stopped being believed. A defence with no reinforcements and no supply; the state simply runs out. Teaches what the pact layer costs, by letting you spend it freely and lose anyway.
The only flashback the player can lose without a restart; losing is the ending."
- **Six defenders** on the dais against **fourteen** levies all on the field from the start: no dens, nothing reinforces, no drops.
- **The free pact**: every one of the six has a pact that answers **once, free** -- a blow that would fell them leaves them standing on 1 HP ("The pact answers: ...").
- **The court falls**: hold until the eighth turn (dawn) and the memory ends with *"It falls regardless"*; or let the company fall first. **Either way the chapter counts as played** (losing is the ending); which way is remembered as a hidden flag (`flashback_f2_court`: dawn / fell).

## Entering a memory

The overworld takes the party into a memory when one **falls due**: after the Act 1 finale the party stands in *The scribes' quarter* (a memory in the world map's corner, beside Ur-Nashet) and Enter plays it; after the Reunion, *The last court*.
Once played, the party is back where it stood. The validator treats a flashback's location as standing alone, lets a flashback chapter keep cargo on a `defend` map, and leaves memories out of the tone pacing.

## Drafted guesses to confirm

- The names, stats and layouts of both memories; reused enemy archetypes (looters and levies) for the raiders and the unbelieving provinces.
- "Protect the copyists" as three-of-four on a defend map; the clerk as ledger lines rather than a unit; twelve pages.
- That F2's free pact is the once-per-map Miracle for all six, and that dawn and total loss both count as played.
- That the party is *taken* into a memory (it cannot be skipped or delayed) the moment it falls due.

## Not built

- The memories' **scenes** (dialogue, Nashar's hand covering the page in F1 beyond the withheld name, the last court's liturgy), and whatever **reads** the hidden flags later (the register's missing name, F2's outcome).
- Anything that makes the flashbacks teach by *differing* rules beyond what is above (chariots in F0 aside); the era tab's "F3"; flashback-specific music/art.

Tests: `tests/test_flashbacks.gd` (44 checks, mutation-checked); `test_overworld`, `test_cargo_miasma` and `test_almanac` updated for the new locations, cargo and the flashback cache.
