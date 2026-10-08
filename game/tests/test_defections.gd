extends SceneTree
## Headless checks for defections: when each of Waldrada, Anselm and Maren leaves, what they
## take, the lieutenants they become, Maren's way back, and the guest Anna.
## Run from the repo root:
##   godot --headless --path game --script res://tests/test_defections.gd
## Exits 0 if every check passes, 1 otherwise.

var _failures: int = 0
var _checks: int = 0
var _p: Node
var _gs: Node
var _eq: Node
var _d: Node
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
	_d = root.get_node("Defections")
	_canon = root.get_node("Canon")
	await process_frame
	await _run()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)

func _fresh() -> void:
	_gs.reset()

func _join(ids: Array, level := 12) -> void:
	for u in ids:
		_p.state(u)
		_gs.progression[u]["level"] = level

func _map(scene: String, deploy: Array, positions: Array = []) -> Node:
	var m: Node = load("res://scenes/%s.tscn" % scene).instantiate()
	var ids: Array[String] = []
	ids.assign(deploy)
	m.deploy_unit_ids = ids
	m.enemy_phase_enabled = false
	root.add_child(m)
	await process_frame
	for i in positions.size():
		m.unit_positions[deploy[i]] = positions[i]
	var r := RandomNumberGenerator.new()
	r.seed = 3
	m.rng_override = r
	return m

func _run() -> void:
	# ---- canon
	var rows: Array = _d.rows()
	check(rows.size() == 3 and rows.map(func(r): return r["defection_id"]) == ["def_waldrada", "def_anselm", "def_maren"], "three defections")
	var mar: Dictionary = _d.row("def_maren")
	check(mar["trigger_map_id"] == "map_b15" and mar["trigger_unless_map_id"] == "map_ct19" and mar["return_map_id"] == "map_ct19" and mar["appears_map_id"] == "map_tp19", "Maren leaves at the going rate unless the Cinder Track was worked, and returns through it")
	check(_d.row("def_waldrada")["return_map_id"] == null and _d.row("def_anselm")["return_map_id"] == null, "the scripted two have no way back")
	check(_d.row_for_unit("u_anselm")["defection_id"] == "def_anselm" and _d.row_for_unit("u_jost").is_empty(), "lookup by unit")

	# ---- scripted: Waldrada
	_fresh()
	check(_d.on_map_won("map_v21", true).is_empty() and not _d.is_gone("u_waldrada"), "she can't leave before she has joined")
	_join(["u_waldrada", "u_jost"], 12)
	_eq.ensure_ready()
	var carried: Array = _gs.inventories.get("u_waldrada", _eq.inventory("u_waldrada")).duplicate(true)
	check(not carried.is_empty(), "(she carries a weapon)")
	_p.record_deed("u_waldrada", "ep_nohit")
	_p.record_deed("u_waldrada", "ep_capture", 5)
	_gs.support_ranks["some_chain"] = "B"
	var stats_before: Dictionary = _p.stats_for("u_waldrada")
	check(_d.on_map_won("map_v21", false).is_empty() and not _d.is_gone("u_waldrada"), "a replay of the trigger map doesn't count")
	var lines: Array[String] = _d.on_map_won("map_v21", true)
	check(lines.size() == 1 and lines[0].begins_with("Waldrada leaves the company: the Vashti campaign becomes an occupation"), "winning the Vashti seat makes her leave (%s)" % str(lines))
	check(not lines[0].contains("won back"), "(and it says nothing of a way back: there is none)")
	check(_d.is_gone("u_waldrada") and _d.state("def_waldrada") == "gone", "she is gone")
	var rec: Dictionary = _gs.defections["def_waldrada"]
	check(rec["level"] == 12 and rec["stats"] == stats_before and rec["titles"] == ["Untouched", "Taker"] and rec["carried"] == carried and not rec["fallen"], "what she left with: level, stats, titles, weapons")
	check(not _gs.inventories.has("u_waldrada"), "the weapons went with her")
	check(_gs.support_ranks["some_chain"] == "B" and _gs.progression.has("u_waldrada"), "her supports and her record stay")
	check(_d.on_map_won("map_v21", true).is_empty(), "she can't leave twice")
	# off the roster
	_join(["u_ricberta", "u_avatar"], 10)
	_join(["u_dietmar", "u_avatar"], 30)
	_gs.progression["u_jost"]["level"] = 10
	_gs.progression["u_ricberta"]["level"] = 10
	_gs.progression["u_waldrada"]["level"] = 50
	check(_p.squad_median() == 10, "the squad median ignores her, even at level 50 (%d)" % _p.squad_median())
	_gs.progression["u_waldrada"]["level"] = 12
	var m: Node = await _map("map_d02", ["u_waldrada", "u_jost"], [])
	check(m.units.size() == 1 and m.units[0]["punit_id"] == "u_jost", "she isn't deployed any more")
	m.queue_free()
	await process_frame
	var cs: Node = load("res://scenes/convoy_screen.tscn").instantiate()
	root.add_child(cs)
	await process_frame
	check(not cs.unit_ids.has("u_waldrada") and cs.unit_ids.has("u_jost"), "nor listed in the convoy screen")
	cs.queue_free()
	var bs: Node = load("res://scenes/barracks_screen.tscn").instantiate()
	root.add_child(bs)
	await process_frame
	check(not bs.unit_ids.has("u_waldrada"), "nor the barracks")
	bs.queue_free()
	await process_frame

	# ---- her lieutenant at the Vashti seat
	m = await _map("map_v22", ["u_jost"], [Vector2i(2, 10)])
	var lts: Array = m.enemies.filter(func(e): return e.has("defector"))
	check(lts.size() == 1 and lts[0].archetype["name"] == "Waldrada" and lts[0].kind == "mook" and lts[0]["defector"] == "def_waldrada", "she stands on the Vashti map as a lieutenant -- never the boss")
	var a: Dictionary = lts[0].archetype
	check(a["level"] == 12 and a["hp"] == stats_before["hp"] and a["str"] == stats_before["str"] and lts[0].hp == stats_before["hp"], "with the stats she left with")
	check(m.info_label.text.contains("Waldrada stands near the seal as a lieutenant: Untouched, Taker."), "and the pre-battle line lists her titles (%s)" % m.info_label.text.get_slice("\n", 0))
	check(m._enemy_weapon(lts[0]).get("weapon_id", "x") != "x" and not m._enemy_weapon(lts[0]).is_empty(), "she has a weapon to fight with")
	# captured / spared doesn't end it; killed does
	m._defeat_enemy(lts[0])
	check(_d.is_fallen("def_waldrada") and m._take_material_notes().size() == 1, "killing her is permanent")
	m.queue_free()
	await process_frame
	m = await _map("map_v22", ["u_jost"], [Vector2i(2, 10)])
	check(not m.enemies.any(func(e): return e.has("defector")), "and she never appears again")
	m.queue_free()
	await process_frame
	m = await _map("map_d02", ["u_jost"], [Vector2i(2, 10)])
	check(not m.enemies.any(func(e): return e.has("defector")), "(nor on any other map)")
	m.queue_free()
	await process_frame

	# ---- Anselm: the court's answer, then a lieutenant beside the boss at the granary
	_fresh()
	_join(["u_anselm", "u_jost"], 10)
	check(_d.on_map_won("map_c21", true).size() == 1 and _d.is_gone("u_anselm") and not _d.is_gone("u_jost"), "winning the Vetch reunion makes Anselm leave")
	m = await _map("map_k21", ["u_jost"], [Vector2i(2, 14)])
	var boss: Dictionary = m.enemies.filter(func(e): return e.kind == "boss")[0]
	var an: Dictionary = m.enemies.filter(func(e): return e.has("defector"))[0]
	check(an.archetype["name"] == "Anselm" and m._distance(an.pos, boss.pos) <= 2 and an.pos != boss.pos, "Anselm stands right beside the boss's seal (%s vs %s)" % [str(an.pos), str(boss.pos)])
	check(m.info_label.text.contains("Anselm stands near the seal as a lieutenant, with no titles earned."), "no titles earned, none listed (%s)" % m.info_label.text.get_slice("\n", 0))
	m.queue_free()
	await process_frame

	# ---- Maren: conditional, recoverable
	_fresh()
	_join(["u_maren"], 10)
	check(_d.on_map_won("map_b15", true).size() == 1 and _d.is_gone("u_maren"), "going Column B first writes the Ashland off: Maren leaves")
	_fresh()
	_join(["u_maren"], 10)
	_gs.won_maps["map_ct19"] = true
	check(_d.on_map_won("map_b15", true).is_empty() and not _d.is_gone("u_maren"), "but if the Ashland column was worked first, she stays")
	_fresh()
	_join(["u_maren"], 10)
	_eq.ensure_ready()
	var mc: Array = _eq.inventory("u_maren").duplicate(true)
	var line: String = _d.on_map_won("map_b15", true)[0]
	check(line.contains("Maren leaves the company") and line.contains("Maren can be won back by working The Cinder Track."), "and the line says how to win her back (%s)" % line)
	check(_d.lieutenants_for("map_tp19").size() == 1 and _d.lieutenants_for("map_r16").is_empty(), "she waits at the Throat pass")
	_gs.won_maps["map_ct19"] = true
	var back: Array[String] = _d.on_map_won("map_ct19", true)
	check(back.size() == 1 and back[0].begins_with("Maren comes back") and not _d.is_gone("u_maren") and _d.state("def_maren") == "returned", "working the Cinder Track brings her home")
	check(_gs.inventories["u_maren"] == mc, "with the weapons she took")
	check(_d.lieutenants_for("map_tp19").is_empty(), "and she is no longer a lieutenant")
	check(_d.on_map_won("map_ct19", true).is_empty(), "(only once)")
	# killed: no way back
	_fresh()
	_join(["u_maren"], 10)
	_d.on_map_won("map_b15", true)
	var kl: String = _d.on_lieutenant_down("def_maren", "killed")
	check(kl.contains("no way back") and _d.is_fallen("def_maren"), "if she is killed as a lieutenant there is no way back (%s)" % kl)
	_gs.won_maps["map_ct19"] = true
	check(_d.on_map_won("map_ct19", true).is_empty() and _d.is_gone("u_maren") and _d.lieutenants_for("map_tp19").is_empty(), "winning the return map does nothing for a dead lieutenant")
	check(_d.on_lieutenant_down("def_waldrada", "killed") == "" and _d.on_lieutenant_down("def_maren", "captured") == "", "(and a capture, or a defection that never happened, changes nothing)")

	# ---- Anna
	_fresh()
	_join(["u_anselm", "u_maren", "u_jost", "u_ricberta", "u_dietmar"], 12)
	check(not _d.guest_active("gst_anna") and _d.active_guests().is_empty(), "no guest at the start")
	_d.on_map_won("map_c21", true)
	check(not _d.guest_active("gst_anna"), "Anselm's departure alone doesn't bring her")
	_fresh()
	_join(["u_anselm", "u_maren", "u_jost", "u_ricberta", "u_dietmar"], 12)
	_d.on_map_won("map_b15", true)
	check(not _d.guest_active("gst_anna"), "nor does Maren's alone")
	_d.on_map_won("map_c21", true)
	check(_d.guest_active("gst_anna") and _d.active_guests().size() == 1, "both gone: Anna joins")
	var g: Dictionary = _canon.find_by("guest_units", "guest_id", "gst_anna")
	check(_d.guest_level(g) == 10, "at the squad's median less 2 (%d)" % _d.guest_level(g))
	var gs: Dictionary = _d.guest_stats(g)
	var base: Dictionary = _canon.find_by("unit_base_stats", "unit_id", "u_maren")
	check(int(gs["mag"]) > int(base["mag"]) and int(gs["hp"]) > int(base["hp"]), "grown from the trained baseline (mag %d vs %d)" % [gs["mag"], base["mag"]])
	m = await _map("map_d02", ["u_jost", "u_ricberta"], [])
	var ann: Dictionary = m.units[m.units.size() - 1]
	check(m.units.size() == 3 and ann["punit_id"] == "gst_anna" and ann["name"] == "Anna" and ann["guest"] and ann["level"] == 10, "she is deployed after the squad")
	check(ann["weapon_art"] == "faith" and m._weapon_for_unit(ann).get("art", "") == "faith" and not m._is_roster_unit(ann), "with a faith weapon, and she is not a roster unit (no EXP, no uses)")
	check(m.unit_positions.has("gst_anna") and m.unit_hp["gst_anna"] == ann["hp"] and m.unit_tokens.has("gst_anna"), "on the map with a token and her hit points")
	m._next_turn()
	check(m.turn == 1 and m.unit_positions.has("gst_anna"), "(a turn passes with her aboard)")
	m.queue_free()
	await process_frame
	# Maren returns: Anna stays (she departs by the reunion regardless)
	_gs.won_maps["map_ct19"] = true
	_d.on_map_won("map_ct19", true)
	check(_d.guest_active("gst_anna") and not _d.is_gone("u_maren"), "if Maren is won back, Anna stays until the reunion")
	var dep: Array[String] = _d.on_map_won("map_rf20", true)
	check(dep.size() == 1 and dep[0].begins_with("Anna leaves the company for good") and _gs.guests["gst_anna"] == "departed" and not _d.guest_active("gst_anna"), "the reunion sends her away (%s)" % str(dep))
	m = await _map("map_d02", ["u_jost"], [])
	check(m.units.size() == 1, "she isn't deployed after that")
	m.queue_free()
	await process_frame
	check(_d.on_map_won("map_rf20", true).is_empty() and not _d.guest_active("gst_anna"), "and never comes back")

	# ---- through a won map, and saved
	_fresh()
	_join(["u_anselm", "u_jost"], 10)
	m = await _map("map_c21", ["u_jost"], [Vector2i(2, 10)])
	m.map_won = true
	check(_d.is_gone("u_anselm") and m._reward_text.contains("Anselm leaves the company: the crown answers with the court sect"), "winning the map applies it and says so (%s)" % m._reward_text)
	m.queue_free()
	await process_frame
	var snap: Dictionary = JSON.parse_string(JSON.stringify(_gs.to_dict()))
	_gs.reset()
	check(_gs.validate(snap) == "", "a save with a defection validates")
	_gs.from_dict(snap)
	check(_d.is_gone("u_anselm") and _gs.defections["def_anselm"]["level"] == 10 and typeof(_gs.defections["def_anselm"]["level"]) == TYPE_INT, "and Anselm is still gone after a load, with integer levels")
	# suspended battles keep the lieutenant
	m = await _map("map_k21", ["u_jost"], [Vector2i(2, 14)])
	var st: Dictionary = JSON.parse_string(JSON.stringify(m.capture_state()))
	check(st["enemies"].any(func(e): return e.has("defector") and e["defector"] == "def_anselm"), "a suspended battle keeps the lieutenant flagged")
	m.queue_free()
	await process_frame
	_fresh()
