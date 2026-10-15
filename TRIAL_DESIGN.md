# The Kaisareia Trial -- design and status

Status: **implemented** (first pass). Added 2026-10-31. `ch_h32` was a two-key stub that set `flag_hierophant_verdict`. Canon (`endings.end_hierophant`, `chapters.ch_h32`, `scenes.sc_h32_trial`)
asks for more: the trial is "deliberately NO MAP", "processed through the same systemic machine as everything else", "**the same machine that produces deputies off the epithet ledger** now
processes the largest moral choice in the game, not a special cutscene outside the system", and "**the avatar or whoever holds the relevant commission recommends sentence**". It now is that.

## The docket

The crown reads out the **company's docket** from the ledger the deputy system already keeps (DEPUTY_DESIGN.md):
- **mercies:** the deeds whose epithet canon marks `epithets.trial_reading = mercy` -- **capture, talk, dispersal** (the Taker, the Peacemaker, the Merciful), counted by event (progress toward the deed counts, earned or not);
- **kills:** the kills the auditor wrote down, witnessed and unwitnessed (on writ chapters, as the deputy ledger has always counted them).

Everyone who has joined and not defected is counted.

## Who recommends

- **The avatar, in person:** **M** (mercy) or **E** (execution), pressed **twice** to confirm.
- **The commission:** the **crown's deputy** is the holder of the relevant commission (the writ names them). The screen shows their own docket and what the commission would say: it recommends **mercy when
  their mercies x 3 are at least their kills** (`prm_trial_mercy_weight`: a mercy is worth three kills; a tie is mercy), otherwise **execution**. **Enter** (twice) lets the commission recommend what its record reads.
  Delegating is therefore a real choice: you see the reading first, and you cannot argue with it. With no deputy there is no commission; the sentence is the avatar's alone.

The sentence is **final** (it cannot be re-recommended, and is "written, and stands"). It sets `flag_hierophant_verdict` exactly as before, so the overworld's gating (mercy opens *Subterfuge*, execution opens *The War*) is
unchanged, and is kept in `GameState.trial` with who recommended it and the docket as it stood (saved with the run).

## Drafted guesses to confirm

- Which deeds read as mercy (capture, talk, dispersal) and that kills are the deputy ledger's; the 3:1 weight and mercy on a tie.
- That the deputy is the "relevant commission" holder, and that the commission recommends off its holder's own record rather than the company's.
- That the sentence cannot be taken back (canon: "the largest moral choice in the game").

## Not built

- The trial **scene** as dialogue (the Diadem convening, Methodios's reaction); anything that reads `GameState.trial` later (the endings' text, the epilogue, supports reacting to who recommended it).
- The bill mercy pays (*Subterfuge*) and the war's attrition beyond the existing chapters.

Tests: `tests/test_trial.gd` (30 checks, mutation-checked). The validator's c07y checks the `trial_reading` column and `trial_mercy_weight` is a required parameter.
