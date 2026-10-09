extends Node
## Autoload singleton: the crown's ledger and the choice of deputy (canon's deputy_ledger tab).
## Register after Progression, Supports and Defections.
##
## Through the main-story ("writ") chapters of Acts 1-3 the crown's auditor, the surveyor,
## keeps a ledger of what each deputy candidate does, scored by canon's weights. At the writ
## scene (ch_x11, the Second Writ) the crown names the highest scorer as deputy. The player
## may name someone else once; the crown grants it and withholds Column B's supply
## attachment. Counts live in GameState.deputy_ledger as {unit: {factor_id: n}}; the weights
## are read from canon each time, so retuning the tab retunes the game.
##
## Scoring is additive per event (see canon's deputy_ledger note): a deed earned is a
## writ_deed; a delivery / solo hold / dispersal deed is also legible; a kill is a raw_kill if
## witnessed (within the surveyor radius of the camp) else an unwitnessed_kill (worth 0);
## finishing the map's stated objective is on_objective; any of these done within the radius
## also earns witnessed. Paralogue deeds are worth 0. Revealed literacy (Ricberta) is added at
## ranking time as the tiebreak.

const WRIT_CHAPTER := "ch_x11"
const SCREEN_SCENE := "res://scenes/writ_screen.tscn"
const LEGIBLE_DEEDS := ["ep_delivery", "ep_solohold", "ep_dispersal"]
const FACTOR_LABELS := {
	"writ_deed": "deeds on main-story chapters", "paralogue_deed": "deeds on paralogues", "on_objective": "work on a stated objective",
	"witnessed": "witnessed by the surveyor", "unwitnessed_kill": "unwitnessed kills", "legible": "delivery / hold / dispersal",
	"raw_kill": "kills", "literacy": "revealed literacy"}

# ------------------------------------------------------------------- canon

func weight(factor_id: String) -> float:
	for row in Canon.get_table("deputy_ledger"):
		if row.get("factor_id") == factor_id:
			return float(row["weight"])
	return 0.0

## "writ" for a main-story chapter's map, "paralogue", or "" (the prologue, unknown maps).
func map_kind(map_id: String) -> String:
	for ch in Canon.get_table("chapters"):
		if ch.get("map_id") == map_id:
			var act := str(ch.get("act"))
			if act == "paralogue":
				return "paralogue"
			return "writ" if act in ["1", "2", "3"] else ""
	return ""

## Deputy candidates who are with the company: canon's deputy_candidate units who have
## joined and not defected, in canon's order.
func candidates() -> Array:
	var out: Array = []
	for u in Canon.get_table("units"):
		if u.get("deputy_candidate") == "yes" and Defections.joined(u["unit_id"]) and not Defections.is_gone(u["unit_id"]):
			out.append(u["unit_id"])
	return out

func _unit_name(unit_id: String) -> String:
	var u = Canon.find_by("units", "unit_id", unit_id)
	return str(u.get("name")) if u != null else unit_id

# ------------------------------------------------------------------ ledger

## Counts one event for a unit.
func record(unit_id: String, factor_id: String, n: int = 1) -> void:
	if unit_id == "" or n <= 0:
		return
	var mine: Dictionary = GameState.deputy_ledger.get(unit_id, {})
	mine[factor_id] = int(mine.get(factor_id, 0)) + n
	GameState.deputy_ledger[unit_id] = mine

func count(unit_id: String, factor_id: String) -> int:
	return int(GameState.deputy_ledger.get(unit_id, {}).get(factor_id, 0))

## A deed was earned on `map_id` by `unit_id` (`witnessed`: within the surveyor radius).
func on_deed(unit_id: String, epithet_id: String, map_id: String, witnessed: bool) -> void:
	match map_kind(map_id):
		"paralogue":
			record(unit_id, "paralogue_deed")
		"writ":
			record(unit_id, "writ_deed")
			if epithet_id in LEGIBLE_DEEDS:
				record(unit_id, "legible")
			if witnessed:
				record(unit_id, "witnessed")

## A kill on `map_id`. An unwitnessed one is written down as worth nothing.
func on_kill(unit_id: String, map_id: String, witnessed: bool) -> void:
	if map_kind(map_id) != "writ":
		return
	if witnessed:
		record(unit_id, "raw_kill")
		record(unit_id, "witnessed")
	else:
		record(unit_id, "unwitnessed_kill")

## A unit finished the map's stated objective (seized it, escaped, escorted the cargo, felled
## a defend map's boss).
func on_objective(unit_id: String, map_id: String, witnessed: bool) -> void:
	if map_kind(map_id) != "writ":
		return
	record(unit_id, "on_objective")
	if witnessed:
		record(unit_id, "witnessed")

## Whether a support has revealed THIS unit's literacy (canon: supports.reveals / reveals_about -- Ricberta only).
func literacy_revealed(unit_id: String) -> bool:
	for row in Canon.get_table("supports"):
		if row.get("reveals") == "literacy" and row.get("reveals_about") == unit_id:
			var rank := GameState.get_support_rank(row["chain_id"])
			var need := str(row.get("reveals_at_rank"))
			if rank != "" and Supports.RANKS.find(rank) >= Supports.RANKS.find(need):
				return true
	return false

## Every factor line for a unit: [{"factor", "label", "count", "weight", "points"}] -- the
## counted ones, plus literacy if revealed (counted once).
func breakdown(unit_id: String) -> Array:
	var out: Array = []
	for factor in ["writ_deed", "legible", "on_objective", "raw_kill", "unwitnessed_kill", "witnessed", "paralogue_deed"]:
		var n := count(unit_id, factor)
		if n > 0:
			out.append({"factor": factor, "label": FACTOR_LABELS[factor], "count": n, "weight": weight(factor), "points": n * weight(factor)})
	if literacy_revealed(unit_id):
		out.append({"factor": "literacy", "label": FACTOR_LABELS["literacy"], "count": 1, "weight": weight("literacy"), "points": weight("literacy")})
	return out

func score(unit_id: String) -> float:
	var total := 0.0
	for line in breakdown(unit_id):
		total += float(line["points"])
	return total

## The candidates, best first: [{"unit_id", "name", "score"}]. Ties fall to canon's order.
func ranking() -> Array:
	var out: Array = []
	for u in candidates():
		out.append({"unit_id": u, "name": _unit_name(u), "score": score(u)})
	var order := candidates()
	out.sort_custom(func(a, b):
		if not is_equal_approx(a["score"], b["score"]):
			return a["score"] > b["score"]
		return order.find(a["unit_id"]) < order.find(b["unit_id"]))
	return out

func crown_pick() -> String:
	var r := ranking()
	return r[0]["unit_id"] if not r.is_empty() else ""

# ------------------------------------------------------------------ deputy

func decided() -> bool:
	return not GameState.deputy.is_empty()

func deputy() -> String:
	return str(GameState.deputy.get("unit", ""))

func contested() -> bool:
	return bool(GameState.deputy.get("contested", false))

## The writ scene: names `unit_id` deputy. The crown's own pick is simply accepted; anyone
## else is a contest, which the crown grants at the cost of Column B's supply attachment.
## Once only. -> {"ok", "contested", "reason"}.
func decide(unit_id: String) -> Dictionary:
	if decided():
		return {"ok": false, "contested": false, "reason": "the deputy has been named"}
	if not candidates().has(unit_id):
		return {"ok": false, "contested": false, "reason": "not a candidate"}
	var contest := unit_id != crown_pick()
	GameState.deputy = {"unit": unit_id, "contested": contest}
	return {"ok": true, "contested": contest, "reason": ""}

## Safety net: if the Second Writ is won without the scene having happened, the crown's pick stands.
func ensure_decided() -> void:
	if not decided() and crown_pick() != "":
		decide(crown_pick())

## Whether the writ scene is due: the player is about to play the Second Writ and no deputy is named.
func writ_due(chapter_id: String) -> bool:
	return chapter_id == WRIT_CHAPTER and not decided() and crown_pick() != ""

# ----------------------------------------------------------------- supply

## Column B's supply attachment: gold paid when a Column B chapter is newly won, unless the
## crown's pick was contested. 0 for any other map.
func supply_attachment_gold(map_id: String) -> int:
	for ch in Canon.get_table("chapters"):
		if ch.get("map_id") == map_id and ch.get("column") == "B":
			return 0 if (not decided() or contested()) else int(Progression.param("column_b_supply_gold"))
	return 0

func supply_withheld() -> bool:
	return decided() and contested()
