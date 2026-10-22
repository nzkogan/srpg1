# The patrons -- design and status

Status: **phases 1 and 2 implemented** (first pass), 2026-11-05 and 2026-11-06. Your direction: five-day increments with a blessing and a curse from the demon/angel pair, proc-chance skills, sigils that show which of the pair a bearer
leans to, the real Ars Goetia, "patrons" for the first two thirds and the demons and angels revealed later, and every place on the map tied to a pair.

## The 72 pairs

- **Real names.** The 72 spirits of the Ars Goetia, each paired **by number** with one of the 72 angels of the Shem ha-Mephorash (Bael and Vehuiah, Agares and Jeliel ... Andromalius and Mumiah). Ranks are the common Ars Goetia ones (king, prince, duke, marquis, earl, president, knight): check against your edition.
- **Five days each.** The traditional correspondence gives each pair five degrees of the zodiac. A year here is 12 signs of 30 days, so each sign holds **six pairs** (`patrons.sign_id`, `first_day`..`last_day`). 72 x 5 = 360: every day belongs to exactly one pair.
- **Blessing and curse.** A sign's virtue and failure mode are the same trait overdrawn (the `signs` tab), so each gives one *blessing* (the angel's gift) and one *curse* (the demon's price). Each sign's three **decans** are ruled by the three signs of its element
  (Latin triplicity: the Ram's decans are ruled by the Ram, Lion, Archer), so a pair's gifts come from its decan's ruling sign. The catalogue is the `patron_effects` tab: six blessings (**Surge** +damage, **Clarity** cannot miss, **Echo** a second blow, **Aegis** damage turned aside, **Veil** the blow misses, **Mending** heal on a hit) and six curses (**Stumble** the blow goes wide, **Recoil** damage to yourself, **Faltering** -damage, **Exposed** +damage taken, **Bleeding** extra HP lost when hurt, **Marked** the blow cannot miss).

## Who is born when

Every roster unit now has `birth_sign` (their sign from the support chains) and `birth_day`; every Named has a birth day; every enemy is born under a fixed sign and day made from its archetype and place (the same soldier is always born alike). The unit's two
gifts follow from its birth day. **The 18 birth days are drafted** (a stable spread): they are yours to set.

## Procs, and how Combat rolls them

Each gift is a **percent chance**, per strike, not a flat bonus. The base chance is the pair's rank (`prm_patron_chance_*`: king 18% down to knight 6%), bent by the bearer's **lean**. Procs roll on a stream of their own (seeded from the main one without advancing it), so a fighter without
any leaves every other roll where it was, and the same seed always gives the same fight. The log names what fired ("Jost's favour answers: a second blow follows."); each fired proc is also recorded on the strike for the UI.

## Lean: the angel or the demon

A bearer leans from the angel (+) to the demon (-), -4 to +4. Birth gives -1..+1 (the first two days of the five lean angel, the middle is balanced, the last two lean demon); **conduct** moves it: the crown's ledger of mercies (capture, talk, dispersal) and kills, read as the Kaisareia Trial reads them (a mercy is worth three kills), one step
per 6 net. Toward the angel blessings come likelier and curses rarer (15% of their base per point); toward the demon the reverse. **The sigil shown is the side the bearer leans to**, so a unit's seal visibly changes hands as the company's conduct does. Enemies lean by birth alone.

## The sigils

A mark generated from the pair's number, in three hands: the **angel's** curved and ringed, the **demon's** straight and barbed, a **balanced** bearer's the straight mark inside a ring (216 distinct seals, no art needed). Every roster unit's token wears its patron's seal; a **boss or Named** enemy wears one too (the pact-holders). The world map draws each place's seal beside its name.

## The places

Every one of the 38 places has `patron_id`, `patron_side` (the side that holds the ground: angel, demon, balanced) and `patron_note` (the office that earns the match, from the Ars Goetia's traditional powers): the capital is Bael's, the drowned lake Focalor's, Ur-Nashet Belial's. The panel says whose ground it was and who holds it now. **All 38 matches are a first guess for you to change.**

## Patrons, then demons

Until the reveal (the win of `prm_patron_reveal_map`, the last court of the Long Reign, F2) the player reads **"patron"**, **"favour"** and **"burden"**, and the name given is the one the old city knew (the demon's). After it: **demon** and **angel**, **blessing** and **curse**, and a bearer is shown under the name of the side they lean to.

## Drafted guesses to confirm

- All 72 effect assignments (from sign and decan), the six-and-six catalogue, the odds by rank, and the lean's numbers.
- The 18 units' birth days, the five Named's, and the 38 places' pairs and sides.
- That the reveal is the last court (F2): it is "what the pact layer costs".

## Phase 2: the Morph gamble

"A gambling-style mechanic where characters can morph into an unlockable demon/angel form, but if they don't end the battle with it they suffer permadeath." Key **G**.

- **Unlock.** A roster unit may ask once it is **level 10** and **leans clearly** (|lean| of 2 or more) to the angel or the demon: the form is the side they lean to (so the gift is earned by conduct, or by being pulled there before).
- **The gamble.** The patron answers with a percent chance: **60% plus 5% per point of lean**. If it does not, the bearer pays **6 HP** (never to death) and **cannot ask again that battle**.
- **The form** lasts **3 player turns**, counting the turn it is taken. The **angel's form**: +3 to str, mag, def, res and spd, blessings doubled, **curses gone**. The **demon's form**: +5 to those stats, blessings 1.5x and **curses doubled**. The token changes colour (gold or blood red).
- **The price.** At the start of each turn the form holds one fewer. **If it runs out before the battle is over, the bearer dies for good**: the fall is recorded in the epilogue as *the price of a patron's form*. On a defend map the last turn is the battle's end, so a form that runs out then has held. Killed in the form by an enemy, they fall as anyone does.
- **Holding it to the end.** A bearer still in the form when the battle is won is **pulled one step further toward that side for good** (`GameState.patron_pull`, added to their lean), which in turn raises their odds of being answered and moves their seal. Memories (flashbacks) have no patrons to ask.
- **Saved** with a suspended battle (the form and its clock).
- **Words.** Until the reveal it is "the patron's answer"; after it, "the angel's form" and "the demon's form".

Drafted guesses: all numbers, the unlock (level plus lean), one asking a battle, a refusal costing HP, the form lasting three turns, and the pull.

Tests: `tests/test_morph.gd` (40 checks, mutation-checked; two survivors are redundant guards: the 95% ceiling can never bind at a lean cap of 4, and a memory's units are already not roster units).

## Not built yet

- The patron of a chapter's day (the calendar footprint and this are still separate), and the proc odds shown in the forecast panel.
- "The image" as one escalating silhouette across the statue, the colossus and the Idol; seals on the ground of a map; the 72 patrons' own offices as skills beyond the six-and-six catalogue.

Tests: `tests/test_patrons.gd` (72 checks, mutation-checked). The validator's c07p checks the 72 pairs, the quinaries, the effects, births and places.
