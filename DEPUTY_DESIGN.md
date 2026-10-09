# The crown's ledger and the deputy -- design and status

Status: **implemented** (first pass). Added 2026-10-19. Canon's `deputy_ledger` tab gave the weights and one rule -- "the
crown picks the deputy off this; the player may contest once at the writ scene; the crown grants it and withholds Column
B's supply attachment" -- but nothing kept the ledger or made the pick. The weights are canon's, read from the tab each
time; how events map onto them, the surveyor's whereabouts, and the shape of the contest's penalty are my drafted readings.

## The ledger

On the **main-story ("writ") chapters** of Acts 1-3 the crown's auditor, the surveyor, writes down what each deputy
candidate does. Canon's factors are **added per event**:

| Factor (canon) | Weight | What counts |
|---|---|---|
| writ chapter deed | 2 | any deed earned on a main-story chapter |
| delivery / hold / dispersal | 1.5 | on top of the deed: a delivery, a solo hold or a dispersal deed ("legible categories outweigh kills") |
| on stated objective | 1 | finishing the map's briefed goal: seizing it, escaping, escorting the cargo in, felling a defend map's boss |
| raw kill | 0.5 | a kill |
| within 4 tiles of surveyor | 1 | **any** of the above done within 4 tiles of the surveyor ("witnessed by the auditor") |
| unwitnessed kill | 0 | a kill made farther away ("far-corner heroics do not appear in the report") -- counted, worth nothing |
| paralogue deed | 0 | deeds on unofficial work, off the books |
| revealed literacy (tiebreak) | 0.25 | **Ricberta only**, once a support has revealed it |

So a witnessed kill is worth 0.5 + 1 = 1.5; a witnessed solo hold 2 + 1.5 + 1 = 4.5; a kill across the map, 0.

- **The surveyor** isn't a unit. He stands at the **camp** -- the middle of the deploy row -- and a small gold marker shows
  where; the radius (4) is `prm_surveyor_radius`.
- **Literacy** (`supports.reveals / reveals_about / reveals_at_rank`): six of Ricberta's chains reveal it -- at B for the avatar,
  Sigrun, Gunnar and Edda (who notice), at A for Waldrada and Emmerich (who are told). It is added at ranking time, once,
  and only breaks ties or tips a near-tie (0.25); it can't overturn a real lead.
- Prologue and paralogue maps score nothing (a paralogue's deeds are written down at weight 0).

## The writ scene

- **Candidates** are canon's `deputy_candidate` units (Ricberta, Emmerich, Sigrun, Waldrada, Brandt, Solveig, Gunnar, Anselm)
  who have joined and not defected. **The crown's pick** is the highest score; an exact tie falls to canon's order.
- The scene comes **before the Second Writ** (ch_x11): playing that chapter from the overworld first opens the **writ screen**,
  which lists the candidates with their scores and, for the highlighted one, every factor (count x weight). **Enter accepts the
  crown's choice.** To name someone else, choose them and press **Enter twice**: that is the **contest** -- the crown grants it,
  **once**, and **withholds Column B's supply attachment**. Escape leaves without deciding (the writ is still due).
  If the Second Writ is somehow won with no scene, the crown's pick stands.
- **Column B's supply attachment**, drafted as gold: **+100** (`prm_column_b_supply_gold`) each time a Column B chapter (*The going
  rate*, *The Throat Pass*) is newly won -- unless the deputy was contested, in which case the win says it is withheld.
- The deputy is shown on the overworld ("The crown's deputy: ...") and in the barracks.

## Not built

- The writ **scene** as a scene: the dialogue, the surveyor's reveal at x11 as the crown's auditor ("retroactively load-bearing"),
  and the player's contest as an argument rather than a menu.
- What a deputy **does** beyond being named: canon says nothing more here, so nothing is attached (no stats, no Act 3 role, no
  epilogue clause). The one consequence is the lost supply attachment.
- The attachment as a real **supply attachment** (units, wagons) rather than gold, and *which* of Column B's chapters carry it.
- A surveyor who **moves** with the column or appears on the map as a unit; "unwitnessed" is judged against the camp only.
- Whether a deed already counted keeps counting if the unit later defects (it is simply removed from candidacy).
- Weighting `delivery`, `hold` and `dispersal` as separate objectives (they share one weight, as in canon).

## Where it lives

`canon.xlsx`: `deputy_ledger.factor_id`; `supports.reveals / reveals_about / reveals_at_rank`; `promotion_rules`
(`surveyor_radius`, `column_b_supply_gold`); validator rule c07o. Engine: `scripts/deputy.gd` (autoload: ledger, ranking,
decision, supply), `writ_screen.gd` + `writ_screen.tscn`, `map_grid.gd` (surveyor, witnessing, the event hooks, the income),
`overworld.gd` (the writ scene before ch_x11; `scene_for()`), `barracks_screen.gd`, `game_state.gd` (`deputy_ledger`, `deputy`).
Tests: `test_deputy`.
