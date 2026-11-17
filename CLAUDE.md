# CLAUDE.md

Original-IP tactics RPG in Godot 4.3. One developer (Nick), who owns the story and lore; Claude builds code, tools and drafts.

## The rules that matter most

- **canon.xlsx is the source of truth.** Never hand-edit `game/data/*.json` or `canon.db`; they are generated. Change the
  workbook with a small script in `tools/canon_edits/` (openpyxl), then regenerate:
  `rm -f canon.db && python3 build_sqlite.py && python3 export_canon_json.py && python3 canon_validate.py canon.xlsx`.
  CI fails if `game/data` is stale or the validator reports a blocking finding.
- **Nick writes the lore.** Don't author canon story, names or dialogue unasked. When a build needs a story fact canon
  doesn't have, draft it, mark the cell or doc line `DRAFTED`, and say so in your reply. Open story questions live in
  `TRUTH.md`; never answer them yourself.
- **Systems are frozen** (2026-11-17 review). Don't add new mechanics. Current priority is a playable, polished vertical
  slice: the prologue, Diadem chapters 1-3, one paralogue. See `PROJECT_HANDOFF.md`.
- **Ask before anything that touches outside systems** (Google Drive, GitHub settings, pushing to `main`).
- Pronouns: use they/them for anyone whose pronouns aren't stated. Generated game text avoids pronouns for units.

## Layout

- `canon.xlsx` workbook; `build_sqlite.py` -> `canon.db`; `export_canon_json.py` -> `game/data/*.json`;
  `canon_validate.py` (rules c01-c16; baseline 0 blocking / 13 warning / 12 info).
- `game/` the Godot project. Main scene `scenes/overworld.tscn`. Battle maps are `scenes/map_*.tscn` driven by
  `scripts/map_grid.gd` (large; rules and drawing are mixed, so split it before big UI or graphics work).
- Autoloads (`game/project.godot`, in order): Canon, GameState, Supports, Equipment, Progression, Forge, Defections,
  Deputy, Epilogue, Provenance, Mounts, Huma, Almanac, Flashback, Scenes, Patrons, SaveGame.
- `game/tests/test_*.gd` headless tests; `game/tools/sweep.gd` loads every map.
- `docs/design/*_DESIGN.md` one doc per built system, each with "Drafted guesses to confirm" and "Not built".
- `tools/` flipbook/timeline generators, `run_tests.sh`, and `canon_edits/` (every scripted workbook change, kept so it
  can be re-run or reversed). `blender/` scripts for the F0 block-out (the glb is in Git LFS).

## Running things

```
export GODOT=/path/to/Godot_v4.3-stable_linux.x86_64
$GODOT --headless --path game --import        # once per fresh checkout
tools/run_tests.sh                            # every test + the map sweep; or name tests: tools/run_tests.sh test_trial
$GODOT --headless --path game --export-release "Web" ../build/web/index.html   # needs the 4.3 web export templates
```

A cloud container may not have Godot: download `Godot_v4.3-stable_linux.x86_64.zip` from the godotengine GitHub
releases. Run `git lfs pull` if `game/assets/*.glb` is a text pointer.

## Godot gotchas seen here

- Headless `--script` tests extend SceneTree: reach autoloads with `root.get_node("Name")`, and `class_name` scripts
  are not registered, so `preload`/`load` them.
- `GameState.PERSISTED` holds saved state (type-checked through a JSON round trip); `TRANSIENT` must stay
  `["support_focus"]`. Transient hand-offs live on autoloads (e.g. `Scenes.queue`).
- Flashback maps (chapter act `prologue`/`flashback`) skip permadeath, forge, income, deputy ledger, suspend and patrons.
- The web build uses the Compatibility renderer, single-threaded (no special server headers needed).

## Git

Work on the branch you are given; commit with the attribution trailers the session specifies; no PRs unless asked.
