# Mounts and Named riding -- design and status

Status: **implemented** (first pass). Added 2026-10-27. Canon (`roster_gaps`) says mounts are acquirable equipment -- capture, inheritance or requisition -- and not a
class trait, so any of the 18 can end up mounted; the `named` tab gives each Named creature a signature mechanic; FORGE_DESIGN listed "intact" capture as unbuilt.
The mechanics numbers, the Warhorse and the acquisition rules are my drafts.

## The catalogue (`mounts` tab, canon-first)

| Mount | Kind | Movement | Effect |
|---|---|---|---|
| Warhorse | horse | riding | none; 400 gold by requisition |
| the Simurgh | Named | flying | rider and every adjacent ally recover 5 HP at the start of each turn (`mount_heal`) |
| the Shadhavar | Named | riding | each enemy phase the nearest non-boss enemy is pulled one tile toward the rider; cannot be turned off |
| the Karkadann | Named | riding | effective against riding enemies; a **charge** (moved 3+ tiles, `charge_distance`) adds +4 damage (`charge_bonus`) and leaves the rider stuck the next turn |
| the Anzu | Named | flying | every hit wears the foe's weapon down (the unmake effect); an enemy it leaves unarmed drops nothing |

The Huma stays a map hazard, not a mount. A mount's movement type **replaces** the class's. The validator (rule c07w) checks the tab: known movement and effect,
horses carry an integer requisition cost, a Named mount points at a Named with an enemy stand-in and is never the Huma, and at least one ordinary horse exists.

## Who may ride

Declared gaps hold: **brawl classes cannot ride or fly, readers cannot fly.** A unit that already moves as riding, flying or armor takes no mount. Everyone else may, in
the barracks (key `5`, the Mount mode; Enter gives or takes back).

## Getting one

- **Requisition:** the standard forges' order list gains a Warhorse row (400 gold, takes an order slot, one-chapter cycle); collecting it sends it to the stable.
- **Capture a mounted enemy** (non-Named, riding): a Warhorse joins the stable, **once per map** (`mount_capture_per_map`).
- **Capture a Named at or below 25% HP** (`capture_intact_hp_pct`): the creature is taken **intact** and joins the stable, once a run per Named. The three-way answer is now
  complete: **<=25% intact mount, 26-50% harvest (diminished material), kill = prime material.** If the Named is already bonded the capture falls back to a harvest.
- **Inheritance:** a rider who falls takes the mount with them. The mount's fate follows the weapon fate rule: **recovered** (the body or weapon is retrieved) goes back to the
  stable; **lost** is gone, and a lost Named returns to the wild and can be won again. The epilogue line says which.

## Saved state

`GameState.mounts = {stable, assigned, claimed}` is persisted and round-trips through the save file. The map's mid-battle snapshot keeps the charge lock, move cost and
the per-map horse count.

## Drafted guesses to confirm

- The HP thresholds for intact, the Warhorse price (400), and the order-slot cost; one horse per capture-map.
- Charge numbers (3 tiles, +4, stuck one turn), 5 HP for the Simurgh, the Shadhavar's one-tile pull, bosses exempt from the pull.
- A mount replaces class movement rather than adding to it; riders may not already be mounted-class.
- Unarmed enemies drop nothing under the Anzu (that is the canon cost); a lost Named can be recaptured.

## Not built

- Mounts in the flipbooks; mount HP, stats or deeds; the Named's mutual-knowledge rule; the Huma (a hazard, see HUMA_DESIGN.md); inheritance beyond recovery (no heirloom passing between riders).
