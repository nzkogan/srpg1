# The overworld map -- design and status

Status: **implemented** (first pass; the layout and unlock chain are drafted and live in `canon.xlsx`). Added
2026-10-11. Everything here is a design proposal, not setting canon.

## Before

The overworld was a single straight line of 50-odd chapter squares, left to right, with no sense of place, no
movement and no gating -- any square could be clicked at any time. `world_map_with_forges.png` is a painted
reference with 38 numbered pins, but it is **out of step with canon** (its pin numbering and locations predate
the renumbered chapters, and it puts the Cindered Plains in the west where `regions.direction` says east), and
it carries no coordinates, so the game could not use it.

## Now: a Super-Mario-World-style map

- **Locations are nodes, paths are roads.** `locations` (35 places plus the Ur-Nashet memory) each have a screen
  position, `map_x` / `map_y`, on a 1152x540 canvas. The new `world_paths` tab (38 rows) joins them: each row is a
  two-way path with a `route` (diadem / assembly / both -- sets the line's colour), a `kind` (road / trail) and
  optional `waypoints` ("x,y;x,y") so a line can bend round other places instead of cutting through them.
- **The party is a marker.** Click a place and the party walks the shortest chain of paths to it (Dijkstra over road
  length, along the bends). It can't be redirected mid-walk. Where it stands is saved
  (`GameState.world_location`), so a loaded game puts it back.
- **Chapters live at locations.** `chapters.location_id` places each chapter (several can share a place: Vashti gate
  has three, the Lade caravanserai five). **Enter** -- or clicking the place you're standing on -- plays the next
  open chapter there; once everything is won it replays the last one.
- **The map fills in as you play.** `chapters.unlock_after` is a pipe-separated list of chapter ids; winning *any*
  of them opens the chapter (blank = open from the start). Blue = something to play here, green = everything here
  is won, grey = locked. The panel under the map says why a chapter is locked ("opens after The winter dole").
  Drafted chain: the prologue -> either route's first chapter -> each route in order -> the muster field (either
  route's last chapter) -> Act 2's two routes -> the Vetch reunion -> columns A and B -> the reunion field -> the
  capital -> Act 3's Road and March arcs; paralogues open at fixed points. The Hierophant's verdict gate on the
  Kaisareia Trial's branches is unchanged and sits on top.
- **The prologue is a memory.** Ur-Nashet is a flashback to a city that no longer exists, so it sits boxed in the
  corner with no road. The party starts there, and gets in and out of it by memory (an instant jump, no walk).
  Once the prologue is won, a fresh game's party stands at the tally house (where the avatar starts as a clerk).
- **U** toggles free roam (ignore the progress locks; the verdict still holds) -- a testing aid, not saved.

## Placement

Regions follow `regions.direction`: the Drowned March in the north (the whole Assembly route -- Vetch, the
chapterhouse, Halder, the lake, Ostrova, the Scar, the timber road, the March shrine), the Stepped Coast in the
west, the capital's hinterland in the middle (the Diadem route starts on its docks and fields), the Ashland in the
east (Vashti, the cinder track), the Glass Flats south and the Throat far south-east. Nothing is to scale.

`chapters.location_id` is **my** mapping: the older `locations.chapters` numbers (e.g. "13, 15" at the caravanserai)
no longer match the renumbered chapters, so I placed each by name and sect instead. The Act 3 placements (the Road's
ledger at Lade, the March's capture at its shrine, the war's fronts at the muster field, the Flats' edge and the
capital) are guesses.

## Validation

`canon_validate.py` rule c07j: every location is on the canvas; every path joins real, distinct locations with a
valid route/kind/waypoints; the path graph is connected; every chapter has a place that a path reaches (only the
prologue may stand alone); every `unlock_after` names a real chapter and the chain has no cycle and reaches every
chapter.

## Not built

- Map art: nodes are squares over soft regional ovals, not the painted map. The PNG would need new pins to match canon.
- Random encounters, shops or events on the road; travel is free and instant in story time.
- The painted map's extra places (Sarn and Kesh as separate oases, the herd camps): canon's `locations` doesn't have them.
- Unlocking by anything but a won chapter (flags, supports, the supply network that "some paralogues stay dark" on).

## Where it lives

`canon.xlsx`: `locations.map_x/map_y`, `chapters.location_id/unlock_after`, `world_paths`. Engine:
`scripts/overworld.gd` (graph, unlocks, walking, panel), `game_state.gd` (`world_location`). Tests:
`test_overworld` (87), plus the node-colour check in `test_save_screen`.
