extends Node
## Autoload singleton: the patrons (canon patrons / patron_effects tabs). Register after Scenes.
##
## Every day of the year belongs to a PATRON PAIR: a demon of the Ars Goetia and the angel of the Shem ha-Mephorash with
## the same number, five days each (72 pairs; a year is 12 signs of 30 days). Whoever is born in a pair's five days -- a
## unit, a Named, an enemy -- carries its BLESSING (the angel's gift) and its CURSE (the demon's price), both PERCENT-CHANCE
## procs: the base chance is the pair's rank, bent by the bearer's LEAN. Lean runs from the angel (+) to the demon (-): the
## birth day gives -1..+1 (the first two days of the five lean angel, the last two demon), and conduct moves it (mercies against
## kills in the crown's ledger, as the Kaisareia Trial reads them). Toward the angel blessings come likelier and curses rarer;
## toward the demon the reverse. The sigil shown is the side the bearer leans to.
## In Acts 1 and 2 the player is told "patron", "favour" and "burden"; the demons and angels are named once the reveal map
## (promotion_rules prm_patron_reveal_map) is won.
## `enabled` switches the procs off (the tests that pin exact combat numbers do).

var enabled := true

const SigilScript := preload("res://scripts/sigil.gd")

const RANK_PARAM := {"King": "patron_chance_king", "Prince": "patron_chance_prince", "Duke": "patron_chance_duke", "Marquis": "patron_chance_marquis",
	"Earl": "patron_chance_earl", "President": "patron_chance_president", "Knight": "patron_chance_knight"}

func rows() -> Array:
	return Canon.get_table("patrons").filter(func(r): return str(r.get("patron_id", "")).begins_with("pat_"))

func row(patron_id: String) -> Dictionary:
	for r in rows():
		if r["patron_id"] == patron_id:
			return r
	return {}

func effect(effect_id: String) -> Dictionary:
	var e = Canon.find_by("patron_effects", "effect_id", effect_id)
	return e if e != null else {}

## The pair that holds a day: sign id and day 1-30.
func patron_for(sign_id: String, day: int) -> Dictionary:
	for r in rows():
		if r.get("sign_id") == sign_id and day >= int(r["first_day"]) and day <= int(r["last_day"]):
			return r
	return {}

# ----------------------------------------------------------------- births

## {"sign", "day"} a unit was born under ("" / 0 if it has no birth).
func birth_of_unit(unit_id: String) -> Dictionary:
	var u = Canon.find_by("units", "unit_id", unit_id)
	if u == null or u.get("birth_sign") == null:
		return {"sign": "", "day": 0}
	return {"sign": str(u["birth_sign"]), "day": int(u.get("birth_day", 0))}

## A Named's birth (named.sign_id, named.birth_day).
func birth_of_named(named_id: String) -> Dictionary:
	var n = Canon.find_by("named", "named_id", named_id)
	if n == null or n.get("sign_id") == null:
		return {"sign": "", "day": 0}
	return {"sign": str(n["sign_id"]), "day": int(n.get("birth_day", 1))}

func _hash(s: String) -> int:
	return absi(hash(s))

## An enemy's birth: a Named's own, else a fixed one from its archetype and place (so the same soldier is always born under
## the same sign, whatever the run). `key` is whatever tells two of the same archetype apart (spawn id and instance).
func birth_of_enemy(archetype: Dictionary, key: String) -> Dictionary:
	if archetype.get("named_id") != null:
		return birth_of_named(str(archetype["named_id"]))
	var signs := _sign_ids()
	if signs.is_empty():
		return {"sign": "", "day": 0}
	var h := _hash(str(archetype.get("enemy_id", "")) + "|" + key)
	return {"sign": signs[h % signs.size()], "day": (h / signs.size()) % 30 + 1}

func _sign_ids() -> Array:
	var out: Array = []
	for s in Canon.get_table("signs"):
		if str(s.get("sign_id", "")).begins_with("sgn_"):
			out.append(s["sign_id"])
	return out

# ------------------------------------------------------------------- lean

## The lean a birth day gives: the first two days of a pair's five lean toward its angel, the last two toward its demon.
func birth_lean(day: int) -> int:
	var d := (day - 1) % 5
	return 1 if d <= 1 else (0 if d == 2 else -1)

## A unit's lean, -cap..+cap (+ is the angel): its birth day, and its conduct (mercies x the trial's weight, less kills).
func lean_of_unit(unit_id: String) -> int:
	var b := birth_of_unit(unit_id)
	if b["sign"] == "":
		return 0
	var cap := int(Progression.param("patron_lean_cap"))
	var d := Deputy.docket(unit_id)
	var net := int(d["mercies"]) * int(Progression.param("trial_mercy_weight")) - int(d["kills"])
	var shift := clampi(int(net / maxi(1, int(Progression.param("patron_lean_step")))), -(cap - 1), cap - 1)
	return clampi(birth_lean(b["day"]) + shift, -cap, cap)

func lean_of_enemy(birth: Dictionary) -> int:
	return birth_lean(int(birth.get("day", 3))) if birth.get("sign", "") != "" else 0

## "angel", "demon" or "balanced".
func side_of(lean: int) -> String:
	return "angel" if lean > 0 else ("demon" if lean < 0 else "balanced")

# ------------------------------------------------------------------ procs

## The percent chance of a proc: the pair's rank, bent by the lean (blessings up toward the angel, curses up toward the demon).
func chance(patron: Dictionary, side: String, lean: int) -> int:
	var base := float(Progression.param(RANK_PARAM.get(str(patron.get("demon_rank")), "patron_chance_knight")))
	var bend := float(Progression.param("patron_lean_pct")) / 100.0 * lean
	var c := base * (1.0 + bend) if side == "blessing" else base * (1.0 - bend)
	return clampi(int(round(c)), int(Progression.param("patron_chance_min")), int(Progression.param("patron_chance_max")))

## The two procs a birth carries, for Combat: [{"side", "trigger", "kind", "amount", "chance", "label", "patron"}].
func procs_for(birth: Dictionary, lean: int) -> Array:
	var out: Array = []
	if not enabled or birth.get("sign", "") == "":
		return out
	var p := patron_for(str(birth["sign"]), int(birth["day"]))
	if p.is_empty():
		return out
	for pair in [["blessing", str(p["blessing_effect"])], ["curse", str(p["curse_effect"])]]:
		var e := effect(pair[1])
		if e.is_empty():
			continue
		out.append({"side": pair[0], "trigger": e["trigger"], "kind": e["kind"], "amount": int(e.get("amount", 0)), "chance": chance(p, pair[0], lean),
			"label": str(e["name"]), "patron": p["patron_id"]})
	return out

func procs_for_unit(unit_id: String) -> Array:
	return procs_for(birth_of_unit(unit_id), lean_of_unit(unit_id))

func procs_for_enemy(archetype: Dictionary, key: String) -> Array:
	var b := birth_of_enemy(archetype, key)
	return procs_for(b, lean_of_enemy(b))

# ------------------------------------------------------------------ words

## Whether the patrons have been shown for what they are.
func revealed() -> bool:
	var r = Canon.find_by("promotion_rules", "param_id", "prm_patron_reveal_map")
	return r != null and r.get("text") != null and GameState.won_maps.has(str(r["text"]))

## What a gift is called: before the reveal a favour or a burden, after it a blessing or a curse.
func gift_word(side: String) -> String:
	if revealed():
		return "blessing" if side == "blessing" else "curse"
	return "favour" if side == "blessing" else "burden"

## What the one a unit leans to is called ("patron" until the reveal, then "angel" or "demon").
func holder_word(side: String) -> String:
	if not revealed():
		return "patron"
	return "angel" if side == "angel" else ("demon" if side == "demon" else "pair")

## The name shown for a pair: before the reveal the one patron (the demon's name, as the old city knew it), after it the one the
## bearer leans to.
func name_for(patron: Dictionary, side: String) -> String:
	if not revealed():
		return str(patron.get("demon_name", ""))
	return str(patron.get("angel_name", "")) if side == "angel" else str(patron.get("demon_name", ""))

## One line for a bearer's panel: "Born under the Ram, day 6: Bael's favour Echo 18%, burden Recoil 14%".
func describe(birth: Dictionary, lean: int) -> String:
	var p := patron_for(str(birth.get("sign", "")), int(birth.get("day", 0)))
	if p.is_empty():
		return ""
	var side := side_of(lean)
	var parts: Array[String] = []
	for pr in procs_for(birth, lean):
		parts.append("%s %s %d%%" % [gift_word(pr["side"]), pr["label"], pr["chance"]])
	var who := name_for(p, side)
	return "%s (%s): %s" % [who, holder_word(side), ", ".join(parts)]

## "the Ram, day 6" -- where a birth falls in the year.
func born_text(birth: Dictionary) -> String:
	if birth.get("sign", "") == "":
		return ""
	return "%s, day %d" % [Almanac.sign_name(str(birth["sign"])), int(birth["day"])]

## The sigil colour for a side: the angel's gold, the demon's red, the balanced bearer's grey.
func sigil_color(side: String) -> Color:
	return Color(0.96, 0.84, 0.45, 0.95) if side == "angel" else (Color(0.9, 0.3, 0.28, 0.95) if side == "demon" else Color(0.78, 0.78, 0.8, 0.9))

## A ready Sigil node for a patron pair and a side (null if there is no such pair).
func make_sigil(patron: Dictionary, side: String, radius: float) -> Node2D:
	if patron.is_empty():
		return null
	var sg: Node2D = SigilScript.new()
	sg.number = int(patron["number"])
	sg.side = side
	sg.radius = radius
	sg.color = sigil_color(side)
	return sg

## The line for a place: whose ground it was, and who holds it now ("" if it has none).
func ground_text(location_row: Dictionary) -> String:
	var p := row(str(location_row.get("patron_id", "")))
	if p.is_empty():
		return ""
	var side := str(location_row.get("patron_side", "balanced"))
	var note := str(location_row.get("patron_note", ""))
	if not revealed():
		return "The old city's patron here was %s (%s)." % [p["demon_name"], note]
	match side:
		"angel": return "Ground of the demon %s, held now by the angel %s (%s)." % [p["demon_name"], p["angel_name"], note]
		"demon": return "Ground of the angel %s, held now by the demon %s (%s)." % [p["angel_name"], p["demon_name"], note]
	return "The demon %s and the angel %s share this ground (%s)." % [p["demon_name"], p["angel_name"], note]
