extends SceneTree
## Headless checks for the Martyr (Anselm: Provoke, Miracle, Resolve) and the Quartermaster (two column
## guests, Wolfram and Hildegund, whose Supply hands an ally the best convoy weapon it can wield).
## Run from the repo root:
##   godot --headless --path game --script res://tests/test_martyr_quartermaster.gd
## Exits 0 if every check passes, 1 otherwise.

var _failures: int = 0
var _checks: int = 0
var _p: Node
var _gs: Node
var _eq: Node
var _canon: Node
var _d: Node

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
	_d = root.get_node("Defections")
	await process_frame
	await _run()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)

func _join(ids: Array, level := 10) -> void:
	for u in ids:
		_p.state(u)
		_gs.progression[u]["level"] = level

func _map(scene: String, deploy: Array, positions: Array, specs: Array = [], phase := false) -> Node:
	var m: Node = load("res://scenes/%s.tscn" % scene).instantiate()
	var ids: Array[String] = []
	ids.assign(deploy)
	m.deploy_unit_ids = ids
	m.enemy_phase_enabled = phase
	root.add_child(m)
	await process_frame
	for e in m.enemies:
		m._remove_enemy_token(e)
	m.enemies.clear(); m.dens.clear()
	for i in deploy.size():
		m.unit_positions[deploy[i]] = positions[i]
	var nid := 0
	for spec in specs:
		nid = m._spawn_enemy_instance(spec["arch"], spec["pos"], spec.get("kind", "mook"), nid)
	var r := RandomNumberGenerator.new()
	r.seed = 3
	m.rng_override = r
	return m

func _arch(name: String, over := {}) -> Dictionary:
	var d := {"enemy_id": "ea_t_" + name, "name": name, "weapon_art": "sword", "weapon_tier": "basic", "movement_type": "infantry",
		"level": 5, "hp": 500, "str": 20, "mag": 0, "dex": 90, "spd": 0, "lck": 0, "def": 0, "res": 0, "affiliation": "state", "death_noun": "lance"}
	d.merge(over, true)
	return d

func _select(m: Node, uid: String) -> void:
	m.selected_unit_index = m.units.find(m.units.filter(func(u): return u["punit_id"] == uid)[0])

func _key(n: Node, keycode: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.pressed = true
	n._unhandled_input(ev)

func _run() -> void:
	# ---- the Martyr: canon
	var cls: Dictionary = _canon.find_by("classes", "class_id", "cls_martyr")
	check(cls["tier"] == "personal" and cls["art_primary"] == "faith" and cls["map_actions"] == "provoke" and cls["signature_skill"] == "Miracle", "the Martyr: faith, Provoke, Miracle")
	check(_canon.find_by("units", "unit_id", "u_anselm")["base_class_id"] == "cls_martyr", "Anselm holds it")
	check(_p.param("miracle_per_map") == 1, "one Miracle a map")
	_gs.reset()
	_join(["u_anselm", "u_jost"])
	check(_p.can_provoke("u_anselm") and _p.has_miracle("u_anselm") and not _p.can_provoke("u_jost") and not _p.has_miracle("u_jost"), "only the Martyr has them")
	check(_p.pool("u_anselm").any(func(a): return a["ability_id"] == "ab_resolve"), "Resolve is in his pool")
	check(_eq.can_wield("u_anselm", "wpn_faith_basic"), "he still wields faith weapons")

	# ---- Provoke
	var foes := [{"arch": _arch("Hitter"), "pos": Vector2i(13, 8)}]
	var m: Node = await _map("map_d02", ["u_anselm", "u_jost"], [Vector2i(10, 10), Vector2i(10, 8)], foes, true)
	m.unit_hp["u_jost"] = 1
	m.unit_hp["u_anselm"] = 200
	_select(m, "u_jost")
	_key(m, KEY_V)
	check(m.provoked_by == "" and m.info_label.text.contains("no Provoke"), "Jost has no Provoke")
	_select(m, "u_anselm")
	_key(m, KEY_V)
	check(m.provoked_by == "u_anselm" and m.attacked_this_turn.has("u_anselm"), "V provokes and spends his action")
	_key(m, KEY_V)
	check(m.info_label.text.contains("already acted"), "one a turn")
	m._enemy_phase()
	check(int(m.unit_hp["u_jost"]) == 1 and int(m.unit_hp["u_anselm"]) < 200, "the enemy that could have killed Jost went for the Martyr instead (Jost %d, Anselm %d)" % [m.unit_hp["u_jost"], m.unit_hp["u_anselm"]])
	check(m.provoked_by == "" and m._active_provoker == "", "a Provoke lasts one phase")
	m.enemies[0].pos = Vector2i(13, 8)
	m._enemy_phase()
	check(not m.unit_positions.has("u_jost"), "the next phase it goes for the weak one, as it would have")
	m.queue_free()
	await process_frame
	# an enemy that cannot reach the Martyr acts as usual
	_gs.reset()
	_join(["u_anselm", "u_jost"])
	m = await _map("map_d02", ["u_anselm", "u_jost"], [Vector2i(0, 0), Vector2i(10, 8)], [{"arch": _arch("Hitter"), "pos": Vector2i(13, 8)}], true)
	m.unit_hp["u_jost"] = 200
	m.unit_hp["u_anselm"] = 200
	m.provoked_by = "u_anselm"
	m._enemy_phase()
	check(int(m.unit_hp["u_jost"]) < 200 and int(m.unit_hp["u_anselm"]) == 200, "a foe that cannot reach the Martyr hits whom it can")
	# the provoke survives a suspension
	m.provoked_by = "u_anselm"
	m.miracle_used["u_anselm"] = 1
	var snap: Dictionary = m.capture_state()
	var back: Variant = _gs.restore(JSON.parse_string(JSON.stringify(snap)))
	m.provoked_by = ""
	m.miracle_used.clear()
	m._restore_progress(back)
	check(m.provoked_by == "u_anselm" and m.miracle_used.has("u_anselm"), "a suspension keeps the Provoke and the spent Miracle")
	m.queue_free()
	await process_frame

	# ---- Miracle
	_gs.reset()
	_join(["u_anselm", "u_jost"])
	m = await _map("map_d02", ["u_anselm", "u_jost"], [Vector2i(10, 10), Vector2i(10, 8)], [{"arch": _arch("Hitter"), "pos": Vector2i(11, 10)}], true)
	m.unit_hp["u_anselm"] = 2
	m.unit_hp["u_jost"] = 200
	m._enemy_phase()
	check(m.unit_positions.has("u_anselm") and int(m.unit_hp["u_anselm"]) == 1 and m.miracle_used.has("u_anselm"), "a lethal blow leaves the Martyr at 1 HP (hp %d)" % int(m.unit_hp.get("u_anselm", -1)))
	check(m.enemy_log.any(func(l): return l.contains("A miracle")) and not _gs.epilogue.get("pending", {}).has("u_anselm"), "...with a line for it, and no death on record")
	m.provoked_by = "u_anselm"
	m._enemy_phase()
	check(not m.unit_positions.has("u_anselm") and _gs.epilogue["pending"].has("u_anselm"), "the second blow in a map kills: a Miracle is spent once")
	m.queue_free()
	await process_frame
	# the counter-kill site
	_gs.reset()
	_join(["u_anselm"])
	m = await _map("map_d02", ["u_anselm"], [Vector2i(10, 10)], [{"arch": _arch("Brute", {"hp": 500}), "pos": Vector2i(11, 10)}])
	_select(m, "u_anselm")
	m.unit_hp["u_anselm"] = 1
	m._attack_enemy()
	check(m.unit_positions.has("u_anselm") and int(m.unit_hp["u_anselm"]) == 1 and m.info_label.text.contains("A miracle"), "an answering blow that would kill leaves him at 1 HP too (%s)" % m.info_label.text.substr(0, 90))
	m.queue_free()
	await process_frame
	# the cold
	_gs.reset()
	_join(["u_anselm", "u_jost"])
	m = await _map("map_a03", ["u_anselm", "u_jost"], [Vector2i(0, 0), Vector2i(1, 0)])
	var cold := Vector2i(-1, -1)
	for y in m.grid.size():
		for x in m.grid[y].length():
			if cold.x < 0 and m._hazard_at(Vector2i(x, y)) > 0:
				cold = Vector2i(x, y)
	check(cold.x >= 0, "(a cold tile to stand on)")
	m.unit_positions["u_anselm"] = cold
	m.unit_hp["u_anselm"] = 1
	m._apply_hazard_damage()
	check(m.unit_positions.has("u_anselm") and int(m.unit_hp["u_anselm"]) == 1 and m.miracle_used.has("u_anselm"), "the cold cannot kill a Martyr either, the first time")
	m.unit_positions["u_jost"] = cold
	m.unit_hp["u_jost"] = 1
	m._apply_hazard_damage()
	check(not m.unit_positions.has("u_jost"), "...and kills anyone else")
	m.queue_free()
	await process_frame

	# ---- the Quartermasters: canon
	var wolf: Dictionary = _canon.find_by("guest_units", "guest_id", "gst_qm_a")
	var hild: Dictionary = _canon.find_by("guest_units", "guest_id", "gst_qm_b")
	check(wolf["name"] == "Wolfram" and wolf["column"] == "A" and hild["name"] == "Hildegund" and hild["column"] == "B" and wolf["base_class_id"] == "cls_quartermaster", "Wolfram keeps the main column's convoy and Hildegund Column B's")
	check(_canon.find_by("classes", "class_id", "cls_quartermaster")["map_actions"] == "supply", "the Quartermaster's action is Supply")
	_gs.reset()
	check(not _d.guest_active("gst_qm_a") and not _d.guest_active("gst_qm_b"), "neither is with the company before the first Act 1 map is won")
	_gs.won_maps["map_a01"] = true
	check(_d.guest_active("gst_qm_a") and _d.guest_active("gst_qm_b") and _d.guest_actions("gst_qm_a") == ["supply"], "either route's first map brings them")
	check(_d.guest_stats(wolf)["hp"] >= 15, "a quartermaster has a body (hp %d)" % _d.guest_stats(wolf)["hp"])
	check(_d.is_guest("gst_qm_a") and not _d.is_guest("u_jost"), "(a guest is a guest)")
	_join(["u_jost"])
	m = await _map("map_d02", ["u_jost"], [Vector2i(8, 8)])
	var names: Array = m.units.map(func(u): return u["name"])
	check(names.has("Wolfram") and not names.has("Hildegund"), "on the main column's map only Wolfram keeps the convoy (%s)" % str(names))
	m.queue_free()
	await process_frame
	m = await _map("map_tp19", ["u_jost"], [Vector2i(8, 8)])
	names = m.units.map(func(u): return u["name"])
	check(names.has("Hildegund") and not names.has("Wolfram"), "on a Column B map it is Hildegund (%s)" % str(names))
	m.queue_free()
	await process_frame

	# ---- Supply
	_gs.reset()
	_gs.won_maps["map_d01"] = true
	_join(["u_jost", "u_edda"])
	_eq.ensure_ready()
	_gs.convoy.append({"weapon_id": "wpn_axe_high", "uses": 20})
	var convoy_n: int = _eq.convoy().size()
	m = await _map("map_d02", ["u_jost", "u_edda"], [Vector2i(8, 8), Vector2i(12, 12)])
	var qm := "gst_qm_a"
	m.unit_positions[qm] = Vector2i(9, 8)
	_select(m, "u_jost")
	m._begin_supply()
	check(not m._supply_mode and m.info_label.text.contains("no Supply action"), "a fighter has no Supply")
	_select(m, qm)
	_key(m, KEY_Q)
	check(m._supply_mode, "Q offers Supply")
	_key(m, KEY_ESCAPE)
	check(not m._supply_mode and not m.attacked_this_turn.has(qm), "any other key cancels")
	m._begin_supply()
	m._supply_toward(Vector2i(0, 1))
	check(m.info_label.text.contains("no one beside") and not m.attacked_this_turn.has(qm), "an empty tile has no one to supply")
	m._begin_supply()
	m._supply_toward(Vector2i(-1, 0))
	check(_eq.equipped("u_jost")["weapon_id"] == "wpn_axe_mid" and m.attacked_this_turn.has(qm), "Jost is handed the Steel Axe (not the Silver one: he is not certified)")
	check(_eq.convoy().size() == convoy_n and _eq.convoy().any(func(e): return e["weapon_id"] == "wpn_axe_basic"), "...and the convoy takes the Iron Axe back (same size)")
	check(m.info_label.text.contains("hands Jost the Steel Axe") and m.info_label.text.contains("takes back the Iron Axe"), "the line says so: %s" % m.info_label.text)
	m.attacked_this_turn.clear()
	m._begin_supply()
	m._supply_toward(Vector2i(-1, 0))
	check(m.info_label.text.contains("Nothing in the convoy beats") and not m.attacked_this_turn.has(qm) and _eq.equipped("u_jost")["weapon_id"] == "wpn_axe_mid", "once he holds the best he may wield, there is nothing to hand over")
	_gs.progression["u_jost"]["promoted"] = true
	m._begin_supply()
	m._supply_toward(Vector2i(-1, 0))
	check(_eq.equipped("u_jost")["weapon_id"] == "wpn_axe_high" and m.attacked_this_turn.has(qm), "once certified he is handed the Silver Axe")
	m.unit_positions["u_edda"] = Vector2i(9, 9)
	m.attacked_this_turn.clear()
	m._begin_supply()
	m._supply_toward(Vector2i(0, 1))
	check(m.info_label.text.contains("Nothing in the convoy beats") or m.info_label.text.contains("no one"), "(Edda has no weapon art: nothing to hand her)")
	m.queue_free()
	await process_frame
