extends SceneTree
## Headless checks for patron offices: the canon (72 offices in 13 families), rank scaling, who carries one (a clear lean or a
## form), what it does on the map and in EXP, and the barracks line.
## Run from the repo root:
##   godot --headless --path game --script res://tests/test_offices.gd
## Exits 0 if every check passes, 1 otherwise.

var _failures: int = 0
var _checks: int = 0
var _p: Node
var _gs: Node
var _canon: Node
var _pa: Node
var _combat: GDScript

func check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: ", label)

func _initialize() -> void:
	_p = root.get_node("Progression")
	_gs = root.get_node("GameState")
	_canon = root.get_node("Canon")
	_pa = root.get_node("Patrons")
	_combat = load("res://scripts/combat.gd")
	await process_frame
	await _run()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)

func _join(ids: Array, level := 10) -> void:
	for u in ids:
		_p.state(u)
		_gs.progression[u]["level"] = level

func _map(scene: String, deploy: Array) -> Node:
	var m: Node = load("res://scenes/%s.tscn" % scene).instantiate()
	var ids: Array[String] = []
	ids.assign(deploy)
	m.deploy_unit_ids = ids
	m.enemy_phase_enabled = false
	root.add_child(m)
	await process_frame
	return m

## Sets a unit's lean to exactly `lean` by way of the pull.
func _lean(unit: String, lean: int) -> void:
	_gs.patron_pull.erase(unit)
	_gs.patron_pull[unit] = lean - _pa.lean_of_unit(unit)

## Gives a unit's own patron an office (canon rows are live dictionaries); returns the old one to restore.
func _give(unit: String, office: String) -> String:
	var b: Dictionary = _pa.birth_of_unit(unit)
	var pat: Dictionary = _pa.patron_for(str(b["sign"]), int(b["day"]))
	var old := str(pat["office_id"])
	pat["office_id"] = office
	return old

func _run() -> void:
	# ---- canon
	var offices: Array = _canon.get_table("offices")
	check(offices.size() == 13, "thirteen families of office")
	var all_ok := true
	for pt in _pa.rows():
		all_ok = all_ok and _canon.find_by("offices", "office_id", str(pt["office_id"])) != null and str(pt["office_text"]) != ""
	check(_pa.rows().size() == 72 and all_ok, "every one of the 72 has an office in the old books' words and a family")
	check(_p.param("office_unlock_lean") == 2 and _p.param("office_pct_high") == 150 and _p.param("office_pct_mid") == 125 and _p.param("office_pct_low") == 100, "parameters: lean 2; King/Prince 150%, Duke/Marquis/Earl 125%, President/Knight 100%")
	check(_pa.rows()[0]["demon_name"] == "Bael" and _pa.rows()[0]["office_id"] == "off_veil", "Bael's office is the Veil")

	# ---- scaling by rank
	var base := {"patron_id": "pat_x", "office_id": "off_veil", "office_text": "x"}
	var k: Dictionary = _pa.office_of_patron(base.merged({"demon_rank": "King"}))
	check(k["avoid"] == 12 and k["hit"] == 0 and k["cond"] == "always" and k["ability_id"] == "off_veil", "a King's Veil: avoid 8 to 12")
	check(_pa.office_of_patron(base.merged({"demon_rank": "Earl"}))["avoid"] == 10 and _pa.office_of_patron(base.merged({"demon_rank": "Knight"}))["avoid"] == 8 and _pa.office_of_patron(base.merged({"demon_rank": "Prince"}))["avoid"] == 12, "an Earl 10, a Knight 8, a Prince 12")
	var hoard: Dictionary = _pa.office_of_patron({"patron_id": "pat_x", "office_id": "off_hoard", "demon_rank": "King"})
	check(hoard["guard"] == 2 and hoard["dodge"] == 5 and _pa.office_of_patron({"patron_id": "pat_x", "office_id": "off_hoard", "demon_rank": "Duke"})["guard"] == 1, "a small number never rounds to nothing: guard 1 stays 1 at 125%, 2 at 150%")
	var dead: Dictionary = _pa.office_of_patron({"patron_id": "pat_x", "office_id": "off_dead", "demon_rank": "President"})
	check(dead["cond"] == "hp_low" and dead["dmg"] == 3 and dead["crit"] == 5, "the condition rides with it: the dead speak at half HP")
	check(_pa.office_of_patron({"patron_id": "pat_x", "office_id": "off_nope", "demon_rank": "King"}).is_empty(), "no such office, none")

	# ---- who carries one
	_gs.reset()
	_join(["u_brandt", "u_jost"])
	_lean("u_brandt", 1)
	check(_pa.office_of_unit("u_brandt").is_empty(), "a lean of 1 earns nothing")
	_lean("u_brandt", 2)
	check(not _pa.office_of_unit("u_brandt").is_empty(), "a lean of 2 toward the angel does")
	_lean("u_brandt", -2)
	check(not _pa.office_of_unit("u_brandt").is_empty(), "...and 2 toward the demon")
	_lean("u_brandt", 0)
	check(_pa.office_of_unit("u_brandt").is_empty() and not _pa.office_of_unit("u_brandt", "angel").is_empty(), "balanced has none, but holding a form carries it")
	check(_pa.office_of_unit("u_nobody").is_empty(), "someone with no patron has none")
	_pa.enabled = false
	_lean("u_brandt", 3)
	check(_pa.office_of_unit("u_brandt").is_empty(), "with the patrons off, none")
	_pa.enabled = true

	# ---- EXP
	var was_b := _give("u_brandt", "off_tongues")
	_lean("u_brandt", 0)
	var plain: float = _p.exp_multiplier("u_brandt")
	_lean("u_brandt", 2)
	var with_office: float = _p.exp_multiplier("u_brandt")
	var rank_pct: float = 125.0 if str(_pa.patron_for(str(_pa.birth_of_unit("u_brandt")["sign"]), int(_pa.birth_of_unit("u_brandt")["day"]))["demon_rank"]) in ["Duke", "Marquis", "Earl"] else 100.0
	check(is_equal_approx(with_office - plain, 0.20 * rank_pct / 100.0), "Tongues raise EXP: +%.2f (from %.2f to %.2f)" % [with_office - plain, plain, with_office])
	_give("u_brandt", was_b)

	# ---- the line in the barracks
	_lean("u_brandt", 0)
	check(_pa.office_line("u_brandt").contains("answers only a bearer who leans clearly"), "locked: the line says what it waits on: %s" % _pa.office_line("u_brandt"))
	_lean("u_brandt", 2)
	var line: String = _pa.office_line("u_brandt")
	check(line.begins_with("Office of ") and not line.contains("answers only") and line.contains("+"), "unlocked: the line says what it does: %s" % line)
	check(_pa.office_line("u_nobody") == "", "nothing for no one")

	# ---- on the map
	var old := _give("u_brandt", "off_veil")
	_lean("u_brandt", 1)
	var m: Node = await _map("map_d02", ["u_brandt", "u_jost"])
	var c0: Dictionary = m._combatant_for_unit("u_brandt")
	check(not (c0.get("abilities", []) as Array).any(func(a): return a.get("ability_id") == "off_veil"), "a lean of 1: no office in the fight")
	_lean("u_brandt", 2)
	var c1: Dictionary = m._combatant_for_unit("u_brandt")
	var held: Array = (c1.get("abilities", []) as Array).filter(func(a): return a.get("ability_id") == "off_veil")
	var expect: int = _pa.office_of_unit("u_brandt")["avoid"]
	check(held.size() == 1 and _combat.ability_bonus(c1, {}, {}, "avoid") - _combat.ability_bonus(c0, {}, {}, "avoid") == expect and expect >= 8, "a clear lean puts the Veil in the fight: +%d avoid" % expect)
	var c2: Dictionary = m._combatant_for_unit("u_brandt")
	check((c2["abilities"] as Array).size() == (c1["abilities"] as Array).size(), "asking again does not stack it")
	_lean("u_brandt", 0)
	m.morphs["u_brandt"] = {"side": "angel", "turns": 3}
	var c3: Dictionary = m._combatant_for_unit("u_brandt")
	check((c3.get("abilities", []) as Array).any(func(a): return a.get("ability_id") == "off_veil"), "in a form, a balanced bearer carries it")
	m.morphs.erase("u_brandt")
	var other: Dictionary = m._combatant_for_unit("u_jost")
	check(not (other.get("abilities", []) as Array).any(func(a): return str(a.get("ability_id", "")).begins_with("off_")), "someone who leans nowhere carries none")
	var foe_ok := true
	for e in m.enemies:
		foe_ok = foe_ok and not (m._enemy_combatant(e).get("abilities", []) as Array).any(func(a): return str(a.get("ability_id", "")).begins_with("off_"))
	check(not m.enemies.is_empty() and foe_ok, "no enemy carries an office")
	m.queue_free()
	await process_frame
	_give("u_brandt", old)
