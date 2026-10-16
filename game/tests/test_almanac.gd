extends SceneTree
## Headless checks for the calendar's soft footprint: each sect's calendar, the sign that governs a chapter,
## who the day favours (units and Named), the briefing line, and the +hit/avoid on the map.
## Run from the repo root:
##   godot --headless --path game --script res://tests/test_almanac.gd
## Exits 0 if every check passes, 1 otherwise.

var _failures: int = 0
var _checks: int = 0
var _p: Node
var _gs: Node
var _a: Node

func check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: ", label)

func _initialize() -> void:
	_p = root.get_node("Progression")
	_gs = root.get_node("GameState")
	_a = root.get_node("Almanac")
	await process_frame
	await _run()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)

func _join(ids: Array, level := 10) -> void:
	for u in ids:
		_p.state(u)
		_gs.progression[u]["level"] = level

func _canon_units() -> Array:
	return root.get_node("Canon").get_table("units").filter(func(u): return u.get("status") == "recruitable").map(func(u): return u["unit_id"])

func _arch(name: String, over := {}) -> Dictionary:
	var d := {"enemy_id": "ea_t_" + name, "name": name, "weapon_art": "sword", "weapon_tier": "basic", "movement_type": "infantry",
		"level": 5, "hp": 200, "str": 0, "mag": 0, "dex": 0, "spd": 0, "lck": 0, "def": 0, "res": 0, "affiliation": "state", "death_noun": "lance"}
	d.merge(over, true)
	return d

func _run() -> void:
	# ---- canon
	check(_a.wheel().size() == 12 and _a.wheel()[0] == "sgn_ram" and _a.wheel()[11] == "sgn_fishes" and _a.bonus() == 5, "twelve signs in wheel order; the soft advantage is 5")
	check(_a.calendar_sign("sect_court") == "sgn_ram" and _a.calendar_sign("sect_march") == "sgn_vessel" and _a.calendar_sign("sect_road") == "sgn_scales", "the court keeps the Ram, the Continuing Word the Vessel, the Company of the Road the Scales")
	check(_a.calendar_sign("sect_vashti") == "" and _a.calendar_sign("sect_coast") == "", "the Unstained and the silent keep none")
	check(_a.named_sign("nmd_karkadann") == "sgn_bull" and _a.named_sign("nmd_simurgh") == "sgn_crab" and _a.named_sign("nmd_nobody") == "", "every Named has a sign")

	# ---- whose calendar, which sign
	check(_a.calendar_of("ch_d01") == {"sect_id": "sect_court", "sign_id": "sgn_ram"}, "a chapter with no sect keeps the court's calendar")
	check(_a.calendar_of("ch_h31")["sect_id"] == "sect_march" and _a.calendar_of("ch_nope")["sign_id"] == "", "a sect's chapter keeps its sect's; no chapter, none")
	check(_a.governing("ch_d01") == "sgn_ram" and _a.governing("ch_d02") == "sgn_bull" and _a.governing("ch_d03") == "sgn_twins", "the court's calendar runs a sign a chapter from the Ram")
	check(_a.governing("ch_d07") == "sgn_scales" and _a.governing("ch_x11") == "sgn_vessel", "...chapter 7 is the Scales, chapter 11 the Vessel")
	check(_a.governing("ch_h31") == "sgn_lion", "the March keeps the Vessel's calendar: chapter 31 is 10 + 30 mod 12 = the Lion")
	check(_a.governing("ch_p_huma") == "sgn_maiden", "the Road's: the Scales + 95 wraps round to the Maiden")
	check(_a.governing("ch_v21") == "" and _a.governing("ch_p_indech") == "", "no day is favoured on an Unstained or a silent chapter")

	# ---- who it favours
	check(_a.sign_of("u_jost") == "sgn_ram" and _a.sign_of("u_avatar") == "sgn_scorpion" and _a.sign_of("u_waldrada") == "sgn_scales" and _a.sign_of("u_nobody") == "", "a unit's sign comes from its supports")
	check(_a.unit_bonus("u_jost", "ch_d01") == 5 and _a.unit_bonus("u_jost", "ch_d02") == 0 and _a.unit_bonus("u_brandt", "ch_d02") == 5, "Jost's day is the first, Brandt's the second")
	check(_a.unit_bonus("u_jost", "ch_v21") == 0 and _a.unit_bonus("u_nobody", "ch_d01") == 0 and _a.unit_bonus("u_nobody", "ch_v21") == 0, "none on a chapter with no day, or for a stranger (even on a dayless chapter)")
	var unsigned: Array = _canon_units().filter(func(u): return _a.sign_of(u) == "")
	check(unsigned.is_empty(), "every roster unit has a sign, whichever side of a chain it is on (%s)" % str(unsigned))
	check(_a.named_bonus("nmd_karkadann", "ch_d02") == 5 and _a.named_bonus("nmd_karkadann", "ch_d01") == 0, "the Karkadann (the Bull) has the second chapter's day")
	_gs.reset()
	check(_a.favoured_units("ch_d07").is_empty(), "no one has joined, so no one is favoured")
	_join(["u_waldrada", "u_gunnar"])
	check(_a.favoured_units("ch_d07") == ["u_waldrada"], "chapter 7 favours Waldrada, who has joined -- and not the Scales unit who has not")
	_gs.defections["def_waldrada"] = {"state": "gone"}
	check(_a.favoured_units("ch_d07").is_empty(), "...nor a defector")
	check(_a.favoured_units("ch_v21").is_empty(), "no one on a day that names none")
	_gs.reset()
	_join(["u_brandt", "u_jost"])
	var b: String = _a.briefing("ch_d02")
	check(b.contains("the court's calendar") and b.contains("Bull") and b.contains("Brandt") and not b.contains("Jost") and b.contains("+5"), "the briefing says whose day it is: %s" % b)
	check(_a.briefing("ch_v21") == "" and _a.briefing("ch_h31").contains("Vessel") == false and _a.briefing("ch_h31").contains("Lion"), "no briefing on a dayless chapter; a March chapter names the March's calendar")

	# ---- on the map
	_gs.reset()
	_join(["u_brandt", "u_jost"])
	var m: Node = load("res://scenes/map_d02.tscn").instantiate()
	var ids: Array[String] = ["u_brandt", "u_jost"]
	m.deploy_unit_ids = ids
	m.enemy_phase_enabled = false
	root.add_child(m)
	await process_frame
	check(m._day_chapter() == "ch_d02", "the map reads its chapter's calendar")
	check(m.info_label.text.contains("Bull") and m.info_label.text.contains("Brandt"), "the briefing opens the map: %s" % m.info_label.text.substr(0, 140))
	var bc: Dictionary = m._combatant_for_unit("u_brandt")
	var jc: Dictionary = m._combatant_for_unit("u_jost")
	check(int(bc.get("sup_hit", 0)) == 5 and int(bc.get("sup_avoid", 0)) == 5 and int(jc.get("sup_hit", 0)) == 0, "Brandt gets +5 hit and avoid on the Bull's day; Jost nothing")
	for e in m.enemies:
		m._remove_enemy_token(e)
	m.enemies.clear(); m.dens.clear()
	m._spawn_enemy_instance(_arch("Beast", {"named_id": "nmd_karkadann"}), Vector2i(10, 8), "boss", 0)
	m._spawn_enemy_instance(_arch("Other", {"named_id": "nmd_anzu"}), Vector2i(11, 8), "boss", 1)
	m._spawn_enemy_instance(_arch("Plain"), Vector2i(12, 8), "mook", 2)
	check(int(m._enemy_combatant(m.enemies[0]).get("sup_hit", 0)) == 5 and int(m._enemy_combatant(m.enemies[1]).get("sup_hit", 0)) == 0 and int(m._enemy_combatant(m.enemies[2]).get("sup_avoid", 0)) == 0, "the Karkadann is favoured on its day; the Anzu and a plain soldier are not")
	# it flows into the fight
	var plain_hit: int = int(m._enemy_combatant(m.enemies[2]).get("sup_hit", 0))
	check(int(bc["sup_hit"]) > plain_hit, "(and is what Combat.hit_chance reads)")
	m.map_id = "map_f00"
	m._flash = -1                       # (the map reads its kind once)
	check(m._day_chapter() == "" and m.map_row != null, "the prologue keeps no calendar")
	m.queue_free()
	await process_frame
