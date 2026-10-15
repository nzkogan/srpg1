# The Named know each other -- design and status

Status: **implemented** (first pass). Added 2026-10-29. Canon (`named.notes`): "Three-way capture: intact / harvest / kill. **The Named know each other: kill one and the next
will not be captured.**" Capture was built with FORGE_DESIGN.md and MOUNTS_DESIGN.md; this is the rule that gives killing its price.

## The rule

The game remembers which Named creatures' stand-ins you have **killed** (`GameState.named_slain`, one entry per creature, saved with the run). Once that count reaches
`prm_named_wary_kills` (canon-literal **1**, so a single kill), **no Named can be captured**: no intact mount, no harvest. Killing them stays open as ever and still yields the prime
material, so the choice is real: **a kill is irreversible, and ends the intact mounts and the harvests for every creature you have not yet dealt with.**

- The first kill's line adds *"The Named know each other: word of it will go before you, and none of the rest will be taken now."* (shown once, at the count that trips it).
- Afterwards the forecast's Capture line reads *"Capture: the Named know each other, and it has heard of the death of the <first creature to fall>."* and pressing [C] is refused with the
  same reason. An ordinary enemy is captured exactly as before, and a Named already captured or taken intact stays yours.
- A capture is not a kill: nothing is remembered. Replaying a Named's map and killing its stand-in again counts only the once.
- Mid-map saves roll it back with the rest of the run (it is persisted state).

## The Anzu's cost (the other half of the notes)

Canon: "COST: weapons it unmakes cannot be captured, so riding it starves your only supply line." This was built with the mounts: an enemy the Anzu leaves unarmed drops nothing.

## Drafted guesses to confirm

- The reading of "the next": **every** Named after the first kill, not only the next one met. `named_wary_kills` is the dial (2 would let the first kill pass unpunished).
- That a kill is remembered for the whole run (not per act), and that the count is of creatures, not of fights.
- That the refusal is absolute (a Pardoner, a low HP or a talk makes no difference).

## Not built

- The Named's own reactions (a dialogue at the next paralogue, a stand-in that flees or fights harder); a way to make amends.
- The Named *defection triggers* from canon (the feather changing hands, the doves threatened, the register read by someone literate) for Named already in the stable.

Tests: `tests/test_named_rules.gd` (20 checks, mutation-checked). The validator's required-parameters list includes `named_wary_kills`.
