# The scene pipeline -- design and status

Status: **implemented** (first pass). Added 2026-11-03. Canon's `scenes` tab lists 36 scenes by chapter -- 31 *post-battle*, 4 *pre-battle*, 1 *narrative* (the Kaisareia Trial, a screen of its own) -- each with speakers, a one-line summary,
and optional conditions. Every one is still `drafted` with `word_count` 0: canon has **summaries, not scripts**. Nothing played them, which is what the "Not built: the scenes" lines in DEFECTIONS, DEPUTY, TRIAL and FLASHBACKS all point at.
This builds the vehicle so a script, once authored, has somewhere to go; until then each scene is a **card** that shows its summary and says it has no script yet.

## How it works

- **When a scene is shown:** a *pre-battle* scene when you press Enter on a chapter (the scene card first, then the map); a *post-battle* scene on the way out of a **won** map (Escape from the victory screen goes through the card, then back to the overworld). Memories (flashbacks) have none.
- **Once:** a scene is shown the first time and counted as seen (saved with the run, `GameState.scenes_seen`); a replay of the chapter does not show it again. A new run sees them all again.
- **Conditions** (canon `depends_on_*`): a scene that reads `flag_hierophant_verdict` waits until a verdict is recommended; one that names units (`u_ricberta|u_emmerich`, `u_maren|u_kest`) shows once **any** of them has joined; `flag_deaths` is the
  epilogue record, always present. A scene whose conditions do not hold is simply not shown.
- **The card:** the chapter and when ("What Feeds the Colossus -- after the battle"), who speaks (units and npcs by name), the summary, and *"(This scene is drafted but has no script yet; this is its summary.)"* until a scene has words. Enter / Space
  for the next card, Escape skips what is left (skipped scenes count as seen). `Scenes.has_script` reads canon's `word_count`; when canon gains a script field, the card is where it appears.

## Drafted guesses to confirm

- "Any" rather than "all" for `depends_on_units` (safer: a canonical scene is not lost because only one of two characters joined).
- Showing summaries as cards rather than skipping unscripted scenes; showing post-battle scenes on leaving the victory screen (not mid-map).
- The 'narrative' scene (the Trial) stays the Trial screen's own; the Second Writ's scene is 'post-battle' in canon even though the writ screen precedes the map.

## Not built

- The scripts themselves (authored dialogue), portraits, choices inside a scene, and scenes for the new systems (defection signposting, the memories, the mounts' leaving) -- there are no canon rows for those yet.
- Scenes flagged to the world map (a scene on arriving somewhere), and replaying a seen scene from a log.

Tests: `tests/test_scenes.gd` (28 checks, mutation-checked; one survivor is the Second Writ guard, equivalent because that chapter has no pre-battle scene).
