extends SceneTree
## Headless checks for the Huma's shadow: the canon parameters, where the shadow lies each turn, the stat
## bonus of a marked unit (yours and theirs), every enemy preferring a marked unit of yours, a fall in the
## shadow being credited to the Huma, the shadow drawn on the map, and the taboo (the Huma is never a unit).
## Run from the repo root:
##   godot --headless --path game --script res://tests/test_huma.gd
## Exits 0 if every check passes, 1 otherwise.

var _failures: int = 0
var _checks: int = 0
var _p: Node
var _gs: Node
var _canon: Node
var _h: Node
var _e: Node

func check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: ", label)

func _initialize() -> void:
	_p = root.get_node("Progression")
	_gs = root.get_node("GameState")
	_canon = root.get_node("Canon")
	_h = root.get_node("Huma")
	_e = root.get_node("Epilogue")
	await process_frame
	await _run()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)

func _join(ids: Array, level := 10) -> void:
	for u in ids:
		_p.state(u)
		_gs.progression[u]["level"] = level

func _map(scene: String, deploy: Array, positions: Array, specs: Array = []) -> Node:
	var m: Node = load("res://scenes/%s.tscn" % scene).instantiate()
	var ids: Array[String] = []
	ids.assign(deploy)
	m.deploy_unit_ids = ids
	m.enemy_phase_enabled = false
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
		"level": 5, "hp": 200, "str": 0, "mag": 0, "dex": 0, "spd": 0, "lck": 0, "def": 0, "res": 0, "affiliation": "state", "death_noun": "lance"}
	d.merge(over, true)
	return d

func _row(m: Node, uid: String) -> Dictionary:
	return m.units.filter(func(u): return u["punit_id"] == uid)[0]

func _run() -> void:
	# ---- canon
	check(_p.param("huma_radius") == 2 and _p.param("huma_drift") == 2 and _p.param("huma_start_col") == 8 and _p.param("huma_bonus") == 2, "parameters: radius 2, drift 2, starts over column 8, +2")
	check(_h.maps() == ["map_p_huma"] and _h.active_on("map_p_huma") and not _h.active_on("map_d02"), "the shadow drifts over the open road only")
	var enemy_named: Array = _canon.get_table("enemy_archetypes").filter(func(e): return e.get("named_id") == "nmd_huma")
	var mount_named: Array = _canon.get_table("mounts").filter(func(r): return r.get("named_id") == "nmd_huma")
	check(enemy_named.is_empty() and mount_named.is_empty(), "the taboo: the Huma is no enemy to strike and no mount to ride")

	# ---- where the shadow lies
	check(_h.center(1, 20, 8) == Vector2i(8, 4) and _h.center(0, 20, 8) == Vector2i(8, 4) and _h.center(2, 20, 8) == Vector2i(10, 4), "it starts over column 8 and drifts 2 columns a turn (the deploy screen shows turn 1)")
	check(_h.center(7, 20, 8) == Vector2i(0, 4) and _h.center(8, 20, 8) == Vector2i(2, 4), "...wrapping to the west edge at the far end")
	check(_h.covers(Vector2i(8, 4), "map_p_huma", 1, 20, 8) and _h.covers(Vector2i(10, 6), "map_p_huma", 1, 20, 8) and _h.covers(Vector2i(6, 2), "map_p_huma", 1, 20, 8), "everything within 2 tiles of the centre is covered")
	check(not _h.covers(Vector2i(11, 4), "map_p_huma", 1, 20, 8) and not _h.covers(Vector2i(8, 7), "map_p_huma", 1, 20, 8) and not _h.covers(Vector2i(5, 4), "map_p_huma", 1, 20, 8), "...and nothing farther")
	check(not _h.covers(Vector2i(8, 4), "map_d02", 1, 20, 8), "no shadow on any other map")
	check(_h.tiles("map_p_huma", 1, 20, 8).size() == 25 and _h.tiles("map_p_huma", 7, 20, 8).size() == 15 and _h.tiles("map_d02", 1, 16, 12).is_empty(), "25 tiles at full size, 15 when half of it is off the west edge, none elsewhere")
	var base := {"str": 5, "mag": 1, "def": 3, "res": 2, "spd": 4, "dex": 6, "hp": 20}
	var boosted: Dictionary = _h.boost(base)
	check(boosted["str"] == 7 and boosted["mag"] == 3 and boosted["def"] == 5 and boosted["res"] == 4 and boosted["spd"] == 6 and boosted["dex"] == 6 and boosted["hp"] == 20 and base["str"] == 5, "a mark adds 2 to str, mag, def, res and spd, nothing else, and leaves the original alone")

	# ---- the stat bonus on the map
	_gs.reset()
	_join(["u_jost", "u_brandt"])
	var m: Node = await _map("map_p_huma", ["u_jost", "u_brandt"], [Vector2i(8, 4), Vector2i(1, 1)],
		[{"arch": _arch("Raider", {"str": 5}), "pos": Vector2i(9, 3)}, {"arch": _arch("Far", {"str": 5}), "pos": Vector2i(16, 4)}])
	m.turn = 1
	var in_c: Dictionary = m._combatant_for_unit("u_jost")
	var out_c: Dictionary = m._combatant_for_unit("u_brandt")
	var jr: Dictionary = _row(m, "u_jost")
	check(int(in_c["str"]) == int(jr["str"]) + 2 and int(in_c["def"]) == int(jr["def"]) + 2 and int(in_c["spd"]) == int(jr["spd"]) + 2, "a unit of yours in the shadow is boosted")
	check(int(out_c["str"]) == int(_row(m, "u_brandt")["str"]), "one outside it is not")
	check(m._marked(Vector2i(9, 3)) and not m._marked(Vector2i(16, 4)), "the marked tiles are what the map reads")
	check(int(m._enemy_combatant(m.enemies[0])["str"]) == 7 and int(m._enemy_combatant(m.enemies[1])["str"]) == 5, "an enemy in the shadow is boosted too; one outside is not")
	m.turn = 7
	check(int(m._combatant_for_unit("u_jost")["str"]) == int(jr["str"]) and not m._marked(Vector2i(8, 4)), "the shadow drifts on: a turn later Jost is no longer marked")
	m.turn = 1
	# forecast: the same blow lands harder from inside the shadow
	m.unit_positions["u_jost"] = Vector2i(6, 4)
	m.enemies[0].pos = Vector2i(5, 4)
	m.selected_unit_index = m.units.find(jr)
	var fc_in: int = int(m._forecast_info(jr, m.enemies[0])["forecast"]["atk"]["damage"])
	m.turn = 7
	var fc_out: int = int(m._forecast_info(jr, m.enemies[0])["forecast"]["atk"]["damage"])
	check(fc_in == fc_out + 2, "the forecast shows it: %d damage in the shadow, %d out" % [fc_in, fc_out])
	m.queue_free()
	await process_frame

	# ---- the shadow draws every enemy
	_gs.reset()
	_join(["u_jost", "u_brandt"])
	m = await _map("map_p_huma", ["u_jost", "u_brandt"], [Vector2i(13, 4), Vector2i(9, 4)],
		[{"arch": _arch("Raider", {"str": 20}), "pos": Vector2i(15, 4)}])
	m.enemy_phase_enabled = true
	m.unit_hp["u_jost"] = 1                     # the easy kill
	m.turn = 7                                  # the shadow is far to the west: nobody is marked
	m._enemy_phase()
	check(m.unit_hp["u_jost"] < 1 or not m.unit_positions.has("u_jost"), "with no shadow on them the enemy takes the easy kill")
	m.queue_free()
	await process_frame
	_gs.reset()
	_join(["u_jost", "u_brandt"])
	m = await _map("map_p_huma", ["u_jost", "u_brandt"], [Vector2i(13, 4), Vector2i(9, 4)],
		[{"arch": _arch("Raider", {"str": 20}), "pos": Vector2i(15, 4)}])
	m.enemy_phase_enabled = true
	m.unit_hp["u_jost"] = 1
	var bmax: int = int(m.unit_hp["u_brandt"])
	m.turn = 1                                  # the shadow covers Brandt (column 9) but not Jost (13)
	m._enemy_phase()
	check(m.unit_hp["u_jost"] == 1 and int(m.unit_hp["u_brandt"]) < bmax, "...with Brandt marked the same enemy passes the easy kill and goes for him")
	m.queue_free()
	await process_frame
	# a Provoke still beats the mark
	_gs.reset()
	_join(["u_jost", "u_brandt"])
	m = await _map("map_p_huma", ["u_jost", "u_brandt"], [Vector2i(13, 4), Vector2i(9, 4)],
		[{"arch": _arch("Raider", {"str": 20}), "pos": Vector2i(15, 4)}])
	m.enemy_phase_enabled = true
	m.turn = 1
	m.provoked_by = "u_jost"
	var bmax2: int = int(m.unit_hp["u_brandt"])
	m._enemy_phase()
	check(int(m.unit_hp["u_jost"]) < int(_row(m, "u_jost")["hp"]) and int(m.unit_hp["u_brandt"]) == bmax2, "a Martyr's Provoke outranks the mark")
	m.queue_free()
	await process_frame

	# ---- a fall in the shadow is the Huma's
	_gs.reset()
	_join(["u_jost", "u_brandt"])
	m = await _map("map_p_huma", ["u_jost", "u_brandt"], [Vector2i(9, 4), Vector2i(2, 1)],
		[{"arch": _arch("Raider", {"str": 30}), "pos": Vector2i(11, 4)}])
	m.enemy_phase_enabled = true
	m.turn = 1
	m.unit_hp["u_jost"] = 1
	m._enemy_phase()
	var rec: Dictionary = _gs.epilogue.get("pending", {}).get("u_jost", {})
	check(rec.get("killed_by_type") == "named_creature" and rec.get("killed_by_id") == "nmd_huma", "Jost, felled while marked, is recorded as the Huma's")
	check(_e.killer_tail(rec).contains("the Huma's shadow"), "...and the epilogue says so: %s" % _e.killer_tail(rec))
	m.queue_free()
	await process_frame
	_gs.reset()
	_join(["u_jost", "u_brandt"])
	m = await _map("map_p_huma", ["u_jost", "u_brandt"], [Vector2i(14, 4), Vector2i(2, 1)],
		[{"arch": _arch("Raider", {"str": 30}), "pos": Vector2i(15, 3)}])
	m.enemy_phase_enabled = true
	m.turn = 1
	m.unit_hp["u_jost"] = 1
	m._enemy_phase()
	rec = _gs.epilogue.get("pending", {}).get("u_jost", {})
	check(rec.has("killed_by_type") and rec["killed_by_id"] != "nmd_huma", "...but out of the shadow the same blow is just a soldier's")
	m.queue_free()
	await process_frame

	# ---- the map shows it
	_gs.reset()
	_join(["u_jost"])
	m = await _map("map_p_huma", ["u_jost"], [Vector2i(8, 4)])
	await process_frame
	check(m.shadow_layer.get_child_count() == 25, "25 tiles are shaded on turn 1 (%d)" % m.shadow_layer.get_child_count())
	m.origin = Vector2i(8, 4)
	m._update_info_label(0)
	check(m.info_label.text.contains("The Huma's shadow lies over columns 6-10") and m.info_label.text.contains("You are in it"), "the panel says where it lies, and that the selected unit is in it")
	m.turn = 6                                   # next turn's shadow centres on column 0
	m._next_turn()
	await process_frame
	check(m.turn == 7 and m.shadow_layer.get_child_count() == 15, "each new turn the shadow is redrawn where it has drifted (%d tiles)" % m.shadow_layer.get_child_count())
	m.origin = Vector2i(8, 4)
	m._update_info_label(0)
	check(m.info_label.text.contains("columns 0-2") and not m.info_label.text.contains("You are in it"), "...and the panel follows")
	m.queue_free()
	await process_frame
	m = await _map("map_d02", ["u_jost"], [Vector2i(8, 8)])
	await process_frame
	check(m.shadow_layer.get_child_count() == 0 and not m._marked(Vector2i(8, 4)) and not m.info_label.text.contains("Huma"), "elsewhere there is no shadow")
	m.queue_free()
	await process_frame
