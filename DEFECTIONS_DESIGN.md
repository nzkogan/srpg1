# Defections and the guest unit -- design and status

Status: **implemented** (first pass). Added 2026-10-18. Canon's `defections` and `guest_units` tabs described three
units who leave in Act 2 and a guest who covers for them, but nothing read them. The trigger and appearance maps are my
drafted readings of canon's trigger text; everything else follows canon's own RULES row. Not setting canon.

## Canon's rules, as built

> One scripted defection per route (the story needs one thing the player cannot optimise away) and one conditional.
> Defection is not death: they leave the roster, appear later as a lieutenant standing near someone else's seal, and every
> support chain they earned stays readable. They take their epithets and pact obligations with them, so the title list on
> that pre-battle screen is one the player generated. Never the boss -- the map can be won without killing them.

| Defection | Route / kind | Leaves when... | Appears as a lieutenant at | Way back |
|---|---|---|---|---|
| **Waldrada** | diadem, scripted | the Vashti seat (`map_v21`, *The Unstained Seat*) is won: the campaign becomes an occupation she will not carry orders for | `map_v22`, *Re-Made Clean*, beside the first foe (that map has no boss) | none |
| **Anselm** | assembly, scripted | the Vetch reunion (`map_c21`) is won: the court sect's answer, obedience belongs to the throne | `map_k21`, the Kaisareia granary, beside the boss | none |
| **Maren** | assembly, conditional | the Column B opener (`map_b15`, *The going rate*) is won **and the Ashland column (`map_ct19`, the Cinder Track) was never worked** -- the supply decision that writes the Ashland off | `map_tp19`, the Throat pass, beside the boss | yes: win the Cinder Track afterwards |

A defection fires only for a unit who has actually joined (so a diadem run never loses Anselm) and only the first time its
trigger map is won. Maren's is conditional: do Column A first and she never goes.

## What happens

- **They leave the roster**: off the deploy list, the convoy screen, the barracks, and the squad median that sets late-joiner
  catch-up. They **take their weapons** (kept on their record; Maren gets hers back if she returns). Their levels, supports
  and deeds stay in the save -- every support chain they earned is still readable.
- **They come back as a lieutenant** on the appearance map: an enemy built from the unit as they left (level, stats, movement,
  class art, a silver weapon if they had certified), a normal mook, **never the boss**. The pre-battle line lists the titles
  they earned from your play -- the epithet vocabulary tokens of their deeds ("Waldrada stands near the seal as a lieutenant:
  Untouched, Taker."), or "with no titles earned".
- **Killing a lieutenant is permanent**: they never appear again and, for Maren, there is no way back. Capturing, bribing or
  simply leaving them alone changes nothing; the map is won without killing them.
- **Maren's way back**: winning the Cinder Track while she is gone (and alive) brings her home with the weapons she took. A
  returned Maren no longer appears as a lieutenant.

## Anna, the guest

Canon's guest covers the faith niche the departures could zero out, without bending anyone's arc to protect roster math:

- She **joins only once both Anselm and Maren have gone** ("either departure alone does not trigger her"), immediately, and
  **leaves for good when the reunion (`map_rf20`) is won** -- "regardless of whether Maren is later recovered".
- She is deployed after the squad at the median level less 2 (`guest_level_gap`), from the trained faith baseline grown by the
  healer profile's expected rates, fighting with the basic faith weapon. She is **not a roster unit**: no EXP, no inventory,
  no support chain (canon: "one fixed scene instead", not built), and she isn't part of the 18-unit support grid.

## Not built

- The **scenes**: the signposting dialogue before each goes, Anna's one fixed scene, and the pre-battle *screen* itself (here a
  line in the map's panel).
- **Pact obligations** and epithets "taken with them" beyond the title list; **talking** a defector down (a natural fit for
  Maren's genuine amends) and the ascension signal `sig_defection_handling` that reads how she was handled.
- Anna's Act 3 payoff -- canon's own **reconstruction gap**: the row says the real text is missing.
- A defector's later growth (they are frozen as they left), and the epilogue reading of a defector killed.
- The trigger/appearance maps and Maren's "Column B first" reading of the supply decision are guesses.

## Where it lives

`canon.xlsx`: `defections.trigger_map_id / trigger_unless_map_id / return_map_id / appears_map_id`;
`guest_units.requires_defections / depart_map_id`; `promotion_rules.guest_level_gap`; validator rule c07n. Engine:
`scripts/defections.gd` (autoload), `map_grid.gd` (roster filter, guest rows, lieutenants, the win hook),
`progression.gd` (median), `barracks_screen.gd` / `convoy_screen.gd` (listing), `game_state.gd` (`defections`, `guests`).
Tests: `test_defections`.
