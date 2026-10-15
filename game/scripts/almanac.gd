extends Node
## Autoload singleton: the calendar's soft footprint (canon calendar tab, "MECHANICAL FOOTPRINT -- keep it light").
## Register after Huma.
##
## Each sect keeps a calendar that starts at its Venerated-birth sign (sects.calendar_sign_id: the court keeps the
## Ram, the Continuing Word the Vessel, the Company of the Road the Scales; the Unstained and the silent keep none,
## so no day is favoured on their chapters). A chapter keeps its sect's calendar -- a chapter with no sect keeps
## the court's, the state's own -- and the sign that governs it is the calendar's sign advanced by the chapter's
## number, a sign a chapter, twelve to the wheel. A unit whose sign (its supports' sign_a/sign_b) is the governing
## sign, and a Named whose named.sign_id is, gains calendar_bonus hit and avoid. The briefing says whose day it is.

const COURT := "sect_court"

## The twelve sign ids in wheel order.
func wheel() -> Array:
	var out: Array = []
	for s in Canon.get_table("signs"):
		if str(s.get("sign_id", "")).begins_with("sgn_"):
			out.append(s["sign_id"])
	return out

func sign_name(sign_id: String) -> String:
	var s = Canon.find_by("signs", "sign_id", sign_id)
	return str(s.get("name")) if s != null else sign_id

func bonus() -> int:
	return int(Progression.param("calendar_bonus"))

## The sign a sect's calendar starts at ("" if it keeps none).
func calendar_sign(sect_id: String) -> String:
	var s = Canon.find_by("sects", "sect_id", sect_id)
	return str(s.get("calendar_sign_id")) if s != null and s.get("calendar_sign_id") != null else ""

## The calendar a chapter keeps: its sect's, or the court's if it has none. {"sect_id", "sign_id"}.
func calendar_of(chapter_id: String) -> Dictionary:
	var ch = Canon.find_by("chapters", "chapter_id", chapter_id)
	if ch == null:
		return {"sect_id": "", "sign_id": ""}
	var sect: String = str(ch.get("sect_id")) if ch.get("sect_id") != null else COURT
	return {"sect_id": sect, "sign_id": calendar_sign(sect)}

## The sign that governs a chapter ("" if its calendar names none, or it is no chapter).
func governing(chapter_id: String) -> String:
	var ch = Canon.find_by("chapters", "chapter_id", chapter_id)
	var start := str(calendar_of(chapter_id)["sign_id"])
	var w := wheel()
	if ch == null or start == "" or w.is_empty() or not w.has(start):
		return ""
	return w[(w.find(start) + int(ch.get("number", 1)) - 1) % w.size()]

## A roster unit's sign (from the supports tab: the same sign in every chain it appears in), "" if none.
func sign_of(unit_id: String) -> String:
	for r in Canon.get_table("supports"):
		if r.get("unit_a_id") == unit_id and r.get("sign_a") != null:
			return str(r["sign_a"])
		if r.get("unit_b_id") == unit_id and r.get("sign_b") != null:
			return str(r["sign_b"])
	return ""

func named_sign(named_id: String) -> String:
	var n = Canon.find_by("named", "named_id", named_id)
	return str(n.get("sign_id")) if n != null and n.get("sign_id") != null else ""

## The hit/avoid bonus a unit gets on this chapter (0 if the day is not theirs).
func unit_bonus(unit_id: String, chapter_id: String) -> int:
	var g := governing(chapter_id)
	return bonus() if g != "" and sign_of(unit_id) == g else 0

## Same for a Named creature.
func named_bonus(named_id: String, chapter_id: String) -> int:
	var g := governing(chapter_id)
	return bonus() if g != "" and named_sign(named_id) == g else 0

## The company's units the day favours: joined, still with the company.
func favoured_units(chapter_id: String) -> Array:
	var out: Array = []
	var g := governing(chapter_id)
	if g == "":
		return out
	for u in Canon.get_table("units"):
		var uid: String = u["unit_id"]
		if sign_of(uid) == g and Defections.joined(uid) and not Defections.is_gone(uid):
			out.append(uid)
	return out

## The briefing line: whose day it is, under which calendar ("" when no day is favoured).
func briefing(chapter_id: String) -> String:
	var g := governing(chapter_id)
	if g == "":
		return ""
	var cal := calendar_of(chapter_id)
	var names: Array[String] = []
	for uid in favoured_units(chapter_id):
		var u = Canon.find_by("units", "unit_id", uid)
		names.append(str(u.get("name")) if u != null else uid)
	var out := "Under %s's calendar the %s governs the day." % [_calendar_name(cal["sect_id"]), sign_name(g).trim_prefix("the ")]
	if not names.is_empty():
		out += " Favoured (+%d hit and avoid): %s." % [bonus(), ", ".join(names)]
	return out

func _calendar_name(sect_id: String) -> String:
	if sect_id == COURT:
		return "the court"
	var s = Canon.find_by("sects", "sect_id", sect_id)
	return str(s.get("common_name")) if s != null else sect_id
