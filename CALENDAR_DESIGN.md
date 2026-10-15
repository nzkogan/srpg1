# The calendar's soft footprint -- design and status

Status: **implemented** (first pass). Added 2026-11-01. Canon's `calendar` tab says: "**Each Named and each pact-holder is governed by a decan. The calendar tells you which, so certain chapters carry a
soft advantage, legible from the briefing, with no new menu. The sect you side with changes which days favour you** -- which is astrology doing what people actually used it for. **Do not let this become a second
stat system.**" Nothing used the `signs` tab outside supports. The mapping from chapters to days, and the size of the advantage, are my drafts; everything else is read from canon.

## How a day is decided

- **Each sect keeps a calendar that starts at the sign its Venerated was born under** (the schism, `calendar` tab): the **court / Diadem keeps the Ram**, the **Continuing Word (sect_march) the Vessel**,
  the **Company of the Road (sect_road) the Scales** (`sects.calendar_sign_id`). The **Unstained** (sect_vashti, "no feast is valid") and **the silent** (sect_coast, "refuse to say") keep none, so on
  their chapters **no day is favoured**.
- A chapter keeps **its sect's calendar**; a chapter with no sect keeps **the court's**, the state's own.
- The sign that **governs the chapter** is the calendar's sign advanced by the chapter's number, **one sign a chapter, twelve to the wheel** (chapter 1 under the court's calendar is the Ram, 2 the Bull, 11 the Vessel,
  13 the Ram again; a March chapter 31 is the Vessel + 30 = the Lion). So the same chapter number falls on a different day under a different sect's calendar -- "the sect you side with changes which days favour you".

## What it does

- A **unit whose sign is the governing sign** gets **+5 hit and avoid** (`prm_calendar_bonus`) for that chapter. A unit's sign is the one its support chains already give it (every roster unit has one).
- A **Named whose sign is the governing sign** gets the same (`named.sign_id`, drafted from each creature's behaviour, as the `signs` tab asks: Simurgh the Crab, Karkadann the Bull, Anzu the Maiden, Shadhavar the Fishes, Huma the Lion).
- It is **legible from the briefing, with no menu**: the map opens with "Under the court's calendar the Bull governs the day. Favoured (+5 hit and avoid): Brandt." (plus "It is the Karkadann's day too" if one is on the field), and the overworld's
  next-chapter line says the same before you go. The prologue keeps no calendar.

The bonus is deliberately small and flat: it is the same size as a Skald's first aura step, and it never touches damage or stats.

## Drafted guesses to confirm

- The wheel arithmetic (a sign a chapter, from the sect's birth sign) and that sectless chapters keep the court's calendar.
- Which sect keeps which calendar: the Diadem/court the Ram, sect_march the Vessel ("the seer says so, new scripture still arriving"), sect_road the Scales (canon's rows by name).
- The +5, and each Named's sign.

## Not built

- **Pact-holders** (canon: "each pact-holder is governed by a decan") -- no pact-holder exists as a unit or enemy yet beyond the five Named; the decans (36 ten-degree divisions, two spirits each, 72 in all) and the Goetic register are not modelled, only the twelve signs.
- A chosen calendar: the player does not pick a sect's calendar, it follows each chapter's sect. Feast days, and anything the schism's Act 3 evidence (Anna's token) would change.
- The sign shown on the unit panels, and a day indicator on the world map beyond the next-chapter line.

Tests: `tests/test_almanac.gd` (28 checks, mutation-checked). The validator's c07z checks the sects' and Named's signs and that every roster unit has one.
