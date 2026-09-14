# Project Handoff — Tactics RPG (working title none yet)

Original-IP tactics RPG, mechanically descended from Fire Emblem but no longer
using any of its nouns. Byzantine/Balkan/Near-East register, an administrator
protagonist rather than a chosen one, and a central conceit that institutions
outlast people: paperwork, not bloodline, is what actually carries power
across eight hundred years of this world's history.

## Where things stand

Fully de-pivoted: zero Fire Emblem references anywhere in the canon (verified
by search, twice). Design lives in a validated relational workbook rather than
prose. Roster is complete at 18. The prologue is fully specified down to tile
data and art direction. The endgame is locked into four terminal branches.
No code exists yet — everything so far is design and data modeling.

## The artifacts

These are the files to actually hand to a build session, not this chat log:

- **`canon.xlsx`** — the source of truth. 30 tabs: sects, classes, growths,
  units, maps, chapters, epithets, regions, named creatures, polities,
  settlements, eras, forges, materials, endings, and several writer-reference
  tabs (christian_allegory, naming_reference, signs, calendar). Every table
  uses a consistent `prefix_id` convention (`u_` units, `ch_` chapters,
  `map_` maps, etc.) so foreign keys are greppable.
- **`canon_validate.py`** — referential integrity checker. Run it after any
  edit to the workbook: `python canon_validate.py canon.xlsx --out
  violations.csv`. Currently zero blocking, zero warnings, 8 info-level items
  (all "not yet written," not bugs).
- **`canon.db`** + **`build_sqlite.py`** — a derived SQLite export of the
  runtime-relevant tabs with real enforced `FOREIGN KEY` constraints, built
  from `canon.xlsx`. Regenerate it with `python build_sqlite.py` any time the
  xlsx changes; it is not itself a source of truth. 282KB total — the whole
  game's data model is smaller than one sprite sheet.
- **`maps/map_f00.txt`** + **`analyze.py`** — the prologue's actual tile grid
  (24x16, plain-text terrain legend) and a script that computes movement
  reachability, chokepoint width, and reinforcement legality from any such
  grid. Use this pattern for future maps rather than inventing terrain by eye.
- **`map_f00_reference.png`** — a flat color-block render of that same grid,
  used to constrain an image model's layout (see art pipeline note below).
- **`world_map_chapters_v2.png`**, **`world_map_with_forges.png`** — the
  continent map with chapter locations and master-smith forges plotted.
  Coordinates are eyeballed, not survey-accurate.

## World and systems, briefly (full detail lives in the workbook)

**Setting.** Two exhausted co-claimant states, the Diadem (crowned
succession, capital Kaisareia, the sea power) and the Assembly (elective,
seat Vetch, currently in constitutional collapse from plague deaths among the
great houses). They fought each other to exhaustion before the game opens —
the real threat was never either of them.

**Theology.** Five sects, each a real historical Christian position mirrored
rather than sourced (Donatism, Montanist/LDS hybrid, Pauline/Church-of-the-East,
Arianism, apophatic/Desert Fathers), arguing over a Venerated figure whose
death, tomb, and even depiction are all disputed on purpose — the game never
settles it. A sixth position (Bogomil-style dualism) is scouted but unbuilt.

**Cosmology.** The Lesser Key of Solomon's ranked spirits are the deposed
patron-gods of a Hundred Cities era, bound into one register 800 years ago by
a king named Sargath. Crests are replaced by pacts with these entities;
legion count gates their combat strength; stripping a pact is a Faith action.

**Core mechanics.** Berwick-style acquirable mounts (movement is set, not
added); a hard cap of 3 master-worked legendary weapons against 5 possible
beast-material drops; an epithet ledger that reads telemetry back into power
(deputy selection, forge vocabulary, paragon gating) without ever
rubber-banding; map laws against reinforcement ambushes, single-unit
solutions, and unbudgeted forced deploys; a complete 18-unit support grid,
one tier per act, with a platonic/romantic fork only at the final tier.

**Endgame — four terminal states, not a menu choice:**
- *Sanctified* / *Perverse* — the Enlightened One (Company of the Road
  claimant) ascends honestly or corruptly, gated by a hidden telemetry
  threshold (candidates listed in `ascension_signals`, not yet locked).
- *Hierophant-Mercy* / *Hierophant-Execution* — a captured rival claimant is
  spared (triggering a second, underground battle) or executed (triggering an
  attritional war against former allies).

**Prologue (F0).** Playable flashback, 800 years before the main story:
Sargath's warband takes the city of Ur-Nashet. Eight non-recruitable
"ancestor" units, each previewing a modern class line. A wall dies to one
spell; a statue takes the whole army several turns to destroy — spectacle
versus erosion is the whole prologue's argument. The patron's name is
written and never shown to the player, in the prologue or ever after.

## Production decisions made

- **Engine: Godot.** Plain-text scenes an agent can read and diff, no
  royalties, GDScript is close enough to Python to generate reliably.
  Rejected: Unity (messier for agents), Unreal (binary Blueprints),
  SRPG Studio (closed editor, stylistically self-branding), Wesnoth's engine
  (hex grid conflicts with the whole design; resolution ceiling baked into
  its rendering pipeline, confirmed by its own artists downscaling
  higher-res originals to fit).
- **Camera: top-down oblique, axis-aligned square grid.** Explicitly not
  isometric — tiles are squares, not diamonds, rows and columns run straight.
  Reference register: Fire Emblem Awakening / Advance Wars, not Wesnoth.
- **Art pipeline: Blender for 3D diorama environments → glTF → Godot,** flat
  sprites on top, HD-2D style (Octopath/Triangle Strategy lineage). This
  avoids the fixed-resolution ceiling a sprite-based engine like Wesnoth's
  bakes in. Treat Blender as a separate skill to build up before pointing it
  at real scenes.
- **Data format: flat files / SQLite bundled with the build.** Explicitly
  not a hosted backend — a single-player packaged game has no need for a
  live database, and standing up Supabase for this would solve a problem
  the genre doesn't have. `canon.db` is the shape of what should ship.
- **Map art method that actually works, after ~6 failed attempts:** hand the
  image model a flat color-block tile-layout render (see
  `map_f00_reference.png`) plus a separate style-reference image, and ask it
  to repaint the layout. Asking it to edit or restructure an existing image
  never works — it preserves composition and edits locally. Restructuring
  always needs a fresh generation with geometry supplied as an image.

## Explicitly open, not decided by default

- The exact `ascension_signals` weighting (Sanctified vs Perverse trigger).
- Which sect Methodios preaches from / the Hierophant's sect of origin —
  currently two separate open questions that probably want to collapse into
  one answer.
- Kest's decan token's specific Act 3 payoff in the calendar schism (flagged
  dependency, not authored).
- `chapters.map_id` / `maps.chapter_id` store the same relationship twice in
  opposite directions — harmless (verified consistent) but redundant; worth
  deleting one side.
- Pipe-delimited multi-value fields (`recruits_unit_ids` etc.) are a real 1NF
  violation carried from the xlsx; proper fix is junction tables, deferred
  until a real build exists to design them around.
- No Godot project, no GDScript, no actual game code exists yet.

## Where a Claude Code session should probably start

1. Stand up a bare Godot 4 project, confirm `canon.db` can be read from
   GDScript (SQLite bindings or a JSON export step).
2. Build the F0 prologue map first — it's the most completely specified
   piece (tile grid, roster, structure HP, tuning already verified in
   `prologue_tuning`), and it deliberately breaks the normal map laws, so
   it's a good test of whether the data model actually drives a real map.
3. Get one Blender diorama scene into Godot via glTF before attempting real
   art production, to prove the pipeline before spending art time on it.
