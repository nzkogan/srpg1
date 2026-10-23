# The image -- design and status

Status: **implemented** (first pass), 2026-11-07. You asked for "the image" as one escalating shape, because canon already makes the **Idol**, the **synod's colossus** and the **Hierophant's image** deliberately convergent ("a false godhood
assembled from what was taken", "visual convergence with the Idol, deliberate", a "visual callback" for the movement gone underground). If the same silhouette returns each time, the player recognises it before being told what it is.

## One silhouette, four stages

A procedural figure (no art): a plinth, a robed body, a head with a ring, arms, and a **halo with one dot for each patron the register holds by then**.

| Stage | Where (canon `maps.image_*`) | Looks |
|---|---|---|
| **1** | the prologue's statue (`map_f00`), the church's image on its dais (`map_f02`) | a robed figure, hands folded; a halo of **1** (the one patron written into the book) |
| **2** | the synod's colossus (`map_k22`) | arms raised, conduits feeding the base; a halo of **12** |
| **3** | the Hierophant's colossus (`map_h34_war3`) and the movement's hidden one (`map_h33_mercy`) | four arms, a wider body; a halo of **36** |
| **4** | the Idol (`map_e32_perverse`) | six arms, a chain and coins (what was taken), red-gold edges; a halo of all **72** |

The figure is drawn over the map's tiles and under the tokens, on the tiles canon assigns (`image_col`, `image_row`, `image_w`, `image_h`, in tiles). **When the prologue's statue is destroyed the figure breaks**: the same pieces, fallen, the halo spilled on the ground.
It goes still only once it is rubble, as the prologue's design note says.

## The forecast shows the odds

The forecast panel now has a line for each side's patron gifts, in the words of the moment ("Yours: favour Echo 16%, burden Recoil 12%.  Theirs: ..."; "blessing" and "curse" after the reveal).

## Drafted guesses to confirm

- Which maps carry the image and the stage of each (the church's image in the last court as stage 1; the hidden image in *Subterfuge* and the war's last field as stage 3).
- The shape itself: a robed figure with a growing number of arms, and the halo-as-register. A different silhouette is one function (`ImageFigure.build`).

## Not built

- Seals on the ground of a map (bound ground), the image as a thing with a health bar or an effect in play (it is still scenery, apart from the prologue's statue), and an image on the world map.
- (A patron of the day for each chapter is built: PATRON_DAY_DESIGN.md.)

Tests: `tests/test_image.gd` (28 checks, mutation-checked); the forecast line is in `test_patrons`. The validator's c07i checks the stage and the placement inside the map.
