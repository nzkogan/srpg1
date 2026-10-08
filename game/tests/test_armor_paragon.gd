extends SceneTree
## Headless checks for the Immortal (the armor paragon) and for certified units taking
## their CURRENT class's movement onto the battle map.
## Run from the repo root:
##   godot --headless --path game --script res://tests/test_armor_paragon.gd
## Exits 0 if every check passes, 1 otherwise.

var _failures: int = 0
var _checks: int = 0
var _p: Node
var _gs: Node
var _eq: Node
var _canon: Node

func check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: ", label)

func _initialize() -> void:
	_p = root.get_node("Progression")
	_gs = root.get_node("GameState")
	_eq = root.get_node("Equipment")
	_canon = root.get_node("Canon")
	await process_frame
	await _run()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)

func _total(d: Dictionary) -> int:
	var t := 0
	for k in d:
		t += int(d[k])
	return t

func _certified(uid: String, class_id: String, level: int) -> void:
	_p.state(uid)
	_gs.progression[uid]["level"] = level
	_gs.gold = 100000
	if not _gs.progression[uid]["promoted"]:
		_p.promote(uid, class_id)
	_gs.gold = 0
	_gs.progression[uid]["level"] = level

func _names(opts: Array) -> Array:
	var out: Array = []
	for o in opts:
		out.append(o["name"])
	return out

func _map(deploy: Array) -> Node:
	var m: Node = load("res://scenes/map_d03.tscn").instantiate()
	var ids: Array[String] = []
	ids.assign(deploy)
	m.deploy_unit_ids = ids
	m.enemy_phase_enabled = false
	root.add_child(m)
	await process_frame
	return m

func _unit(m: Node, pid: String) -> Dictionary:
	for u in m.units:
		if u.get("punit_id", "") == pid:
			return u
	return {}

func _run() -> void:
	# ---- canon
	_gs.reset()
	var im: Dictionary = _canon.find_by("classes", "class_id", "cls_immortal")
	check(im["tier"] == "paragon" and im["art_primary"] == "lance" and im["art_secondary"] == "bow" and im["movement"] == "armor" and im["provenance"] == "Persian", "cls_immortal: a Persian armor paragon, lance and bow")
	check(im["signature_skill"] == "Ten Thousand" and im["unlock_map_id"] == null, "its signature is Ten Thousand, and no map gates it")
	var armor_paragons := 0
	for c in _canon.get_table("classes"):
		if c["tier"] == "paragon" and c["movement"] == "armor":
			armor_paragons += 1
	check(armor_paragons == 1, "it is the one paragon with armor movement")
	var tt: Dictionary = _p.ability_row("ab_ten_thousand")
	check(tt["pool"] == "class:cls_immortal" and tt["cond"] == "always" and tt["dmg"] == 2 and tt["guard"] == 3 and tt["speed"] == 2, "Ten Thousand: +2 damage, +3 guard, +2 speed, always")

	# ---- who sees it
	_certified("u_ricberta", "cls_paladin", 30)
	_certified("u_dietmar", "cls_general", 30)
	check(_names(_p.paragon_options("u_ricberta")) == ["Bogatyr", "Immortal"], "a Paladin sees the Bogatyr and the Immortal")
	check(_names(_p.paragon_options("u_dietmar")) == ["Bogatyr", "Immortal"], "a General sees the same (lance is lance)")
	_certified("u_tancred", "cls_sniper", 30)
	check(_names(_p.paragon_options("u_tancred")) == ["Donso"], "a bow unit does not: the Immortal's primary art is the lance")
	_certified("u_jost", "cls_warrior", 30)
	check(_names(_p.paragon_options("u_jost")) == ["Jaguar knight", "Eagle knight"], "nor does an axe unit")

	# ---- taking it
	_gs.gold = 5000
	check(_p.take_paragon("u_ricberta", "cls_immortal")["reason"] == "needs a deed that gates paragon", "it wants a deed like any paragon")
	_p.record_deed("u_ricberta", "ep_nohit")
	var before: Dictionary = _p.stats_for("u_ricberta")
	var slots: int = _p.slots("u_ricberta")
	var rate: int = _p.growth_rate("u_ricberta", "str")
	var arts_before: Array = _eq.unit_arts("u_ricberta")
	var preview: Dictionary = _p.preview_paragon("u_ricberta", "cls_immortal")
	var r: Dictionary = _p.take_paragon("u_ricberta", "cls_immortal")
	check(r["ok"] and r["fee"] == 1000 and _p.is_paragon("u_ricberta") and _p.class_id_of("u_ricberta") == "cls_immortal", "Ricberta takes the Immortal for 1000")
	var after: Dictionary = _p.stats_for("u_ricberta")
	check(after == preview, "the preview equals the result")
	check(_total(after) - _total(before) == 30, "the +30 jump (the armor shape is zero-sum)")
	# a Paladin (riding) -> Immortal (armor): the riding shape comes off and the armor shape goes on
	check(int(after["def"]) > int(before["def"]) + 3 and int(after["hp"]) > int(before["hp"]) + 4, "heavy armour: well more HP and Def than the Paladin had (after the jump of 4 and 4)")
	check(int(after["spd"]) < int(before["spd"]) + 4, "and less Spd than the jump alone would give (the weight)")
	check(_p.growth_rate("u_ricberta", "str") == rate + 5 and _p.slots("u_ricberta") == slots + 1, "+5 growth, +1 slot")
	check(_p.chosen("u_ricberta")[0] == "ab_ten_thousand", "Ten Thousand leads her kit")
	check(not _p.pool("u_dietmar").any(func(a): return a["ability_id"] == "ab_ten_thousand") and _p.pool("u_ricberta").size() > 0, "(only an Immortal can pick it)")
	check(_eq.unit_arts("u_ricberta") == ["lance", "bow"] and arts_before == ["lance"], "an Immortal knows lance AND bow")
	check(_eq.can_wield("u_ricberta", "wpn_bow_basic") and _eq.can_wield("u_ricberta", "wpn_lance_basic"), "so she can wield a bow as well as her lance")
	check(not _eq.can_wield("u_dietmar", "wpn_bow_basic"), "(a General cannot)")
	check(_p.class_row("u_ricberta")["movement"] == "armor", "her class is armor movement")

	# ---- a Billman (axe + lance) sees four
	_gs.reset()
	_certified("u_jost", "cls_warrior", 30)
	_gs.progression["u_jost"]["class_id"] = "cls_billman"
	check(_names(_p.paragon_options("u_jost")) == ["Bogatyr", "Jaguar knight", "Eagle knight", "Immortal"], "a Billman sees both lance paragons and both axe ones (%s)" % str(_names(_p.paragon_options("u_jost"))))

	# ---- on the map: a certified unit moves as its current class
	_gs.reset()
	var m: Node = await _map(["u_ricberta", "u_dietmar"])
	check(_unit(m, "u_ricberta")["movement_type"] == "infantry" and _unit(m, "u_ricberta")["move"] == 5, "uncertified, she moves as the infantry she was recruited as")
	m.queue_free()
	await process_frame
	_certified("u_ricberta", "cls_paladin", 15)
	m = await _map(["u_ricberta", "u_dietmar"])
	check(_unit(m, "u_ricberta")["movement_type"] == "riding" and _unit(m, "u_ricberta")["move"] == 9, "certified as a Paladin, she rides (move 9)")
	check(_unit(m, "u_dietmar")["movement_type"] == "riding", "(Dietmar, a Paladin from the start, did already)")
	var ford := Vector2i(16, 6)
	check(m._terrain_cost(ford, "riding") >= m.IMPASSABLE, "d03's ford is foot-only: she can't cross it any more")
	m.queue_free()
	await process_frame
	_gs.progression["u_ricberta"]["level"] = 30
	_gs.gold = 5000
	_p.record_deed("u_ricberta", "ep_nohit")
	_p.take_paragon("u_ricberta", "cls_immortal")
	m = await _map(["u_ricberta"])
	var imm: Dictionary = _unit(m, "u_ricberta")
	check(imm["movement_type"] == "armor" and imm["move"] == 4, "an Immortal moves as armor: 4 (%s, %d)" % [imm["movement_type"], imm["move"]])
	check(m._terrain_cost(ford, "armor") >= m.IMPASSABLE and m._terrain_cost(Vector2i(4, 6), "armor") < m.IMPASSABLE, "and, like a wagon, must use the bridge rather than the ford")
	m.unit_positions["u_ricberta"] = Vector2i(8, 10)
	m._select_unit(0)
	check(m.current_reachable.has(Vector2i(12, 10)) and not m.current_reachable.has(Vector2i(13, 10)), "her reach is 4 tiles along open ground, not 5 (%d tiles reachable)" % m.current_reachable.size())
	check(m.units[0]["weapon_art"] == "lance", "she still fights with the lance")
	# a heavy unit resists a Shove
	check(_p.push_distance_for(1, imm["movement_type"]) == 0 and _p.push_distance_for(2, imm["movement_type"]) == 1, "and, being armor, resists a shove by one tile")
	m.queue_free()
	await process_frame
	_gs.reset()
