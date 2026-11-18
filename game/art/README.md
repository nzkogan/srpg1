# Art slots

Drop finished art here and the game picks it up; nothing else needs changing. Until a file exists, a placeholder
stands in.

- `portraits/<speaker_id>.png` (or `.jpg`, `.webp`): a speaker's portrait in the dialogue box, shown at 132 x 164,
  so paint at 2x or 3x that (for example 396 x 492), portrait orientation. The id is the canon id: `u_avatar`,
  `u_kest`, `pu_sargath`, `npc_methodios`, `gst_alexia`.
- `backdrops/<chapter_id>.png`: the painting behind a chapter's scenes, full screen (1152 x 648 or larger, 16:9),
  cropped to cover. For example `ch_d01.png` for the tally house.

The style anchor is Erin's painting; see `PROJECT_HANDOFF.md` (art direction).
