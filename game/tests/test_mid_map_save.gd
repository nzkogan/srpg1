extends SceneTree
## Headless checks for mid-map saves: a battle suspended (P) or quick-saved (F5) comes
## back exactly as it was -- through memory, through a JSON save file, and through the
## overworld -- rolls the rest of the playthrough back with it, and is cleared on a win.
## Run from the repo root:
##   godot --headless --path game --script res://tests/test_mid_map_save.gd
## Exits 0 if every check passes, 1 otherwise.

var _failures: int = 0
var _checks: int = 0
var _p: Node
var _gs: Node
var _sg: Node
var _sup: Node
var _dir := "user://test_saves_midmap"

func check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: ", label)

func _initialize() -> void:
	_p = root.get_node("Progression")
	_gs = root.get_node("GameState")
	_sg = root.get_node("SaveGame")
	_sup = root.get_node("Supports")
	_sg.base_dir = _dir
	await process_frame
	_wipe()
	await _run()
	_wipe()
	_sg.base_dir = "user://saves"
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)

func _wipe() -> void:
	var abs_dir := ProjectSettings.globalize_path(_dir)
	if DirAccess.dir_exists_absolute(abs_dir):
		for f in DirAccess.get_files_at(abs_dir):
			DirAccess.remove_absolute(abs_dir + "/" + f)

func _fresh() -> void:
	_gs.reset()
	_sup.begin_map()

func _map(scene: String) -> Node:
	var m: Node = load("res://scenes/%s.tscn" % scene).instantiate()
	m.enemy_phase_enabled = true
	m.suspend_leaves = false
	var r := RandomNumberGenerator.new()
	r.seed = 11
	m.rng_override = r
	root.add_child(m)
	await process_frame
	return m

func _key(m: Node, keycode: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.pressed = true
	m._unhandled_input(ev)

## What of a battle should survive: compared as plain data.
func _digest(m: Node) -> Dictionary:
	var en: Array = []
	for e in m.enemies:
		en.append({"id": e.inst_id, "pos": e.pos, "hp": e.hp, "max": e.max_hp, "dead": e.defeated, "kind": e.kind, "spawn": e.get("spawn_id", ""),
			"flags": [e.get("neutral", false), e.get("captured", false), e.get("routed", false), e.get("talked", false), e.get("talk_failed", false), str(e.get("rout_blow", ""))],
			"hit_by": e.get("hit_by", {}).keys(), "token": not e.token.is_empty()})
	var den: Array = []
	for d in m.dens:
		den.append([d.spawn_row["spawn_id"], d.waves_spawned])
	return {"turn": m.turn, "pos": m.unit_positions.duplicate(), "hp": _live_hp(m), "enemies": en, "dens": den,
		"moved": m.moved_this_turn.keys(), "attacked": m.attacked_this_turn.keys(), "struck": m.struck_units.keys(), "fought": m.fought_units.keys(),
		"bribed": m.bribed_count, "escaped": m.escaped_count, "delivered": m.delivered.duplicate(), "sel": m.selected_unit_index,
		"tokens": m.unit_tokens.keys(), "log": m.enemy_log.duplicate()}

func _live_hp(m: Node) -> Dictionary:
	var out := {}
	for pid in m.unit_positions:
		out[pid] = m.unit_hp.get(pid, -1)
	return out

## Through JSON, the way a save file does it.
func _via_json(d: Dictionary) -> Dictionary:
	var parsed = JSON.parse_string(JSON.stringify(d))
	return _gs.restore(parsed)

func _run() -> void:
	# ---- a lived-in battle: d02 with its dens, mooks and the full roster
	_fresh()
	var m: Node = await _map("map_d02")
	check(_gs.battle.is_empty() and m.turn == 0, "(a fresh map starts at turn 0 with nothing suspended)")
	m._update_status_label()
	check(m.status_label.text.contains("[P] suspend") and m.status_label.text.contains("[F5] quick save"), "the controls line lists P and F5")
	m._next_turn()
	var lootr: Dictionary = m.enemy_archetypes_by_id["ea_looter"]
	for k in 3:
		m._spawn_enemy_instance(lootr, Vector2i(14, 2 + k), "mook", m.enemies.size())
	# move, fight, bribe-flag, capture-flag, a routed one, a few turns of den waves
	var u0: String = m.units[0].get("punit_id")
	m.unit_positions[u0] = Vector2i(5, 9)
	m.moved_this_turn[u0] = true
	m.enemies[0]["neutral"] = true
	m.enemies[0].token.bg.color = m.NEUTRAL_TOKEN_COLOR
	m.enemies[1]["captured"] = true
	m._remove_enemy_token(m.enemies[1]); m.enemies[1].defeated = true
	m.enemies[2]["hit_by"] = {u0: true}
	m.enemies[2].hp = 5
	m.enemies[2]["rout_blow"] = u0
	m.struck_units[u0] = true
	m.fought_units[u0] = true
	m.bribed_count = 1
	for i in 3:
		m._next_turn()
	m.hold_streak[u0] = {"tile": Vector2i(5, 9), "phases": 2}
	m.unit_positions[u0] = Vector2i(5, 9)
	var killed: String = m.units[1].get("punit_id")
	m._kill_unit(killed)
	m.selected_unit_index = 2
	m.attacked_this_turn[m.units[2].get("punit_id")] = true
	m.enemy_log.append("a line the player saw")
	_sup.restore_map_points({"chain_x": 2})
	check(m.enemies.size() > 4 and m.dens.size() == 1 and m.dens[0].waves_spawned >= 1, "(the den has sent a wave: %d enemies, %d waves)" % [m.enemies.size(), m.dens[0].waves_spawned])
	var before := _digest(m)
	_key(m, KEY_F5)
	check(not _gs.battle.is_empty() and m.info_label.text.contains("Battle saved at turn %d" % m.turn), "F5 quick-saves and stays in the battle (%s)" % m.info_label.text)
	check(_gs.battle["map_id"] == "map_d02" and int(_gs.battle["turn"]) == m.turn and _gs.battle["title"] == "The weighbridge", "the snapshot names the map, the turn and the title")
	check(_gs.battle["location_id"] == "loc_weighbridge" and _gs.world_location == "loc_weighbridge", "and the place the party stands")
	# through JSON
	var snap := _via_json(_gs.battle)
	m.queue_free()
	await process_frame
	_sup.begin_map()
	_gs.battle = snap
	var m2: Node = await _map("map_d02")
	var after := _digest(m2)
	check(after["turn"] == before["turn"], "resumed on the same turn (%d)" % after["turn"])
	check(after["pos"] == before["pos"], "every unit on the same tile")
	check(after["hp"] == before["hp"], "with the same hit points")
	check(not after["pos"].has(killed) and not after["tokens"].has(killed), "the unit who fell stays fallen (no token either)")
	check(after["enemies"] == before["enemies"], "every enemy as it was: place, HP, kind, spawn, flags, who hit it, and whether it still has a token")
	check(after["dens"] == before["dens"] and after["dens"][0][1] >= 1, "the den's wave count carries over (%s)" % str(after["dens"]))
	check(after["moved"] == before["moved"] and after["attacked"] == before["attacked"], "who has moved and acted this turn")
	check(after["struck"] == before["struck"] and after["fought"] == before["fought"] and after["bribed"] == 1, "the deed bookkeeping and the bribe")
	check(m2.hold_streak.has(u0) and m2.hold_streak[u0]["tile"] == Vector2i(5, 9) and m2.hold_streak[u0]["phases"] == 2, "a solo-hold streak in progress")
	check(after["sel"] == before["sel"], "the selected unit")
	check(after["log"] == before["log"], "the last enemy phase's log")
	check(_sup.snapshot_map_points() == {"chain_x": 2}, "support points earned so far this map")
	check(m2.enemies[0].token.bg.color == m2.NEUTRAL_TOKEN_COLOR, "the bribed enemy's token is still gold")
	check(m2.info_label.text.contains("Resumed at turn %d." % before["turn"]), "the map says it was resumed (%s)" % m2.info_label.text.get_slice("\n", 0))
	# and it plays on
	m2._next_turn()
	check(m2.turn == before["turn"] + 1, "the resumed battle carries on")
	var tokens_ok := true
	for e in m2.enemies:
		if e.defeated and not e.token.is_empty():
			tokens_ok = false
	check(tokens_ok, "(no ghost tokens)")
	m2.queue_free()
	await process_frame

	# ---- the rest of the playthrough rolls back with it
	_fresh()
	m = await _map("map_d02")
	m._next_turn()
	_gs.gold = 100
	_p.state("u_jost")
	_gs.progression["u_jost"]["exp"] = 10
	_key(m, KEY_F5)
	_gs.gold = 900                                  # fight on after the save...
	_gs.progression["u_jost"]["exp"] = 70
	_gs.progression["u_jost"]["level"] = 9
	_gs.deeds["u_jost"] = {"ep_nohit": 1}
	_gs.drops_claimed["spn_x"] = true
	_gs.won_maps["map_x"] = true
	m.queue_free()
	await process_frame
	m2 = await _map("map_d02")                      # ...then take the save back
	check(_gs.gold == 100 and int(_gs.progression["u_jost"]["exp"]) == 10 and int(_gs.progression["u_jost"]["level"]) != 9, "gold and EXP are back where the save left them")
	check(not _gs.deeds.has("u_jost") and not _gs.drops_claimed.has("spn_x") and not _gs.won_maps.has("map_x"), "so are deeds, drops and won maps -- no keeping the EXP from a lost attempt")
	check(not _gs.battle.is_empty(), "and the battle is still suspended until it is won")
	m2.queue_free()
	await process_frame

	# ---- P suspends and (in a test) stays; the prologue refuses
	_fresh()
	m = await _map("map_d02")
	m._next_turn()
	m.suspend(true)
	check(not _gs.battle.is_empty(), "P writes the suspend save")
	m.queue_free()
	await process_frame
	_fresh()
	m = await _map("map_f00")
	m.suspend(false)
	check(_gs.battle.is_empty() and m.info_label.text.contains("can't be paused"), "the prologue can't be suspended")
	_key(m, KEY_P)
	check(_gs.battle.is_empty(), "(P included)")
	m.queue_free()
	await process_frame

	# ---- winning clears it; losing keeps it; another map ignores it
	_fresh()
	m = await _map("map_d02")
	m._next_turn()
	m.suspend(false)
	m.map_lost = true
	check(not _gs.battle.is_empty(), "a lost battle keeps its suspend save (so you can go back)")
	m.queue_free()
	await process_frame
	_gs.battle = _gs.battle.duplicate(true)
	m = await _map("map_d02")
	check(m.turn == int(_gs.battle["turn"]) and not m.map_lost, "...and it resumes cleanly after the loss")
	m.map_won = true
	check(_gs.battle.is_empty() and _gs.won_maps.has("map_d02"), "winning the map clears the suspension")
	m.queue_free()
	await process_frame
	_fresh()
	m = await _map("map_d02")
	m._next_turn()
	m.suspend(false)
	var held: Dictionary = _gs.battle.duplicate(true)
	m.queue_free()
	await process_frame
	var other: Node = await _map("map_d03")
	check(other.turn == 0 and _gs.battle == held, "a different map starts fresh and leaves the suspended battle alone")
	other.map_won = true
	check(_gs.battle == held, "...even if it is won")
	other.queue_free()
	await process_frame

	# ---- damaged snapshots are dropped, not half-loaded
	for bad in [{"map_id": "map_d02", "version": 1}, {"map_id": "map_d02", "version": 99, "state": {}, "positions": {}, "hp": {}, "enemies": [], "dens": [], "turn": 3},
			{"map_id": "map_d02", "version": 1, "state": 5, "positions": {}, "hp": {}, "enemies": [], "dens": [], "turn": 3},
			{"map_id": "map_d02", "version": 1, "state": {"gold": "lots"}, "positions": {}, "hp": {}, "enemies": [], "dens": [], "turn": 3}]:
		_fresh()
		_gs.gold = 7
		_gs.battle = bad
		m = await _map("map_d02")
		check(m.turn == 0 and _gs.battle.is_empty() and _gs.gold == 7 and not m.enemies.is_empty(), "a bad snapshot is dropped and the map starts fresh (%s)" % str(bad.keys()))
		m.queue_free()
		await process_frame

	# ---- cargo: deliveries and losses survive
	_fresh()
	m = await _map("map_d03")
	m._next_turn()
	m.unit_positions["cargo_d03_wagon1"] = Vector2i(10, 3)
	m._select_unit(m.units.size() - 3)
	m._try_move_to(Vector2i(10, 2))
	m._kill_unit("cargo_d03_wagon3")
	check(m.delivered == ["cargo_d03_wagon1"] and not m.map_lost, "(one wagon delivered, one lost, one to go)")
	m.suspend(false)
	var snap2 := _via_json(_gs.battle)
	m.queue_free()
	await process_frame
	_gs.battle = snap2
	m2 = await _map("map_d03")
	check(m2.delivered == ["cargo_d03_wagon1"] and m2.unit_positions.has("cargo_d03_wagon2") and not m2.unit_positions.has("cargo_d03_wagon1") and not m2.unit_positions.has("cargo_d03_wagon3"), "the delivered and lost wagons stay gone; the last is still on the road")
	check(m2.status_label.text.contains("Cargo: 1/2 delivered"), "the cargo tally reads right (%s)" % m2.status_label.text.get_slice("\n", 0))
	m2.queue_free()
	await process_frame

	# ---- the outcome counts survive: captured / routed / talked still pay at the win
	_fresh()
	m = await _map("map_d02")
	m._next_turn()
	for k in 2:
		m._spawn_enemy_instance(m.enemy_archetypes_by_id["ea_looter"], Vector2i(14, 2 + k), "mook", m.enemies.size())
	m.enemies[0].defeated = true
	m.enemies[1].defeated = true; m.enemies[1]["captured"] = true
	m.enemies[2].defeated = true; m.enemies[2]["routed"] = true
	m.enemies[3].defeated = true; m.enemies[3]["talked"] = true
	m.suspend(false)
	snap = _via_json(_gs.battle)
	m.queue_free()
	await process_frame
	_gs.battle = snap
	_gs.gold = 0
	m2 = await _map("map_d02")
	_gs.gold = 0
	m2._settle_rewards()
	check(_gs.gold == int(round((200 + 15 + 25 + 10 + 20) * 1.5)), "(with Kheldar's cut) a kill, a capture, a rout and a talk still pay their own rates after a resume (gold %d)" % _gs.gold)
	m2.queue_free()
	await process_frame

	# ---- the save file
	_fresh()
	_gs.gold = 321
	m = await _map("map_d02")
	m._next_turn(); m._next_turn()
	m.suspend(false)
	var title: String = _gs.battle["title"]
	var res: Dictionary = _sg.save("2")
	check(res["ok"], "a save with a suspended battle writes (%s)" % res["error"])
	var summary: Dictionary = _sg.make_summary()
	check(summary["battle"] == title and summary["battle_turn"] == 2, "the slot summary names the battle and its turn (%s, %d)" % [summary["battle"], summary["battle_turn"]])
	m.queue_free()
	await process_frame
	_fresh()
	check(_gs.battle.is_empty(), "(a new game has none)")
	var loaded: Dictionary = _sg.load_slot("2")
	check(loaded["ok"] and not _gs.battle.is_empty() and _gs.battle["map_id"] == "map_d02" and int(_gs.battle["turn"]) == 2, "loading the slot brings the suspended battle back")
	m2 = await _map("map_d02")
	check(m2.turn == 2 and _gs.gold == 321, "and the map resumes from the file at turn 2")
	m2.queue_free()
	await process_frame
	var info: Dictionary = _sg.slot_info("2")
	check(info["summary"]["battle"] == title, "slot_info carries the summary for the screen")
	var screen: Node = load("res://scenes/save_screen.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	check("\n".join(screen._summary_lines(info["summary"])).contains("In battle: The weighbridge, turn 2"), "the save screen lists the battle (%s)" % "\n".join(screen._summary_lines(info["summary"])).get_slice("\n", 4))
	screen.queue_free()
	await process_frame

	# ---- the overworld
	_fresh()
	_gs.won_maps["map_f00"] = true; _gs.won_maps["map_d01"] = true
	m = await _map("map_d02")
	m._next_turn()
	m.suspend(false)
	m.queue_free()
	await process_frame
	_gs.world_location = "loc_anthe"                  # as if the party had wandered since
	var ow: Node2D = load("res://scenes/overworld.tscn").instantiate()
	ow.animate = false
	ow.launch_enabled = false
	root.add_child(ow)
	await process_frame
	check(ow.party_location == "loc_weighbridge" and ow.suspended_location() == "loc_weighbridge", "the party is where the battle waits")
	check(ow.info_label.text.contains("SUSPENDED: The weighbridge, turn 1. Enter resumes it."), "the panel says so (%s)" % ow.info_label.text.replace("\n", " / "))
	var launched: Array = []
	ow.chapter_launched.connect(func(id): launched.append(id))
	ow.enter_location()
	check(launched == ["ch_d02"], "Enter resumes it (it launches the chapter, whose map then loads the snapshot)")
	ow.travel_to("loc_tally_house")
	check(ow.info_label.text.contains("It waits at The weighbridge") and ow.chapter_to_play("loc_tally_house").is_empty(), "elsewhere, nothing can start while it waits")
	ow.enter_location()
	check(launched.size() == 1 and ow.info_label.text.contains("A battle is suspended at The weighbridge"), "Enter elsewhere refuses and says where it is (%s)" % ow.info_label.text.get_slice("\n", 1))
	ow.travel_to("loc_weighbridge")
	_key(ow, KEY_X)
	check(not _gs.battle.is_empty() and ow.info_label.text.contains("Press X again"), "X once only asks")
	_key(ow, KEY_U)
	_key(ow, KEY_X)
	check(not _gs.battle.is_empty(), "any other key in between cancels it")
	_key(ow, KEY_X)
	_key(ow, KEY_X)
	check(_gs.battle.is_empty() and ow.info_label.text.contains("abandoned"), "X twice abandons the battle")
	ow.enter_location()
	check(launched.size() == 2 and launched[1] == "ch_d02", "and the chapter then starts fresh (d02 is still the next open one here)")
	_key(ow, KEY_X)
	check(_gs.battle.is_empty(), "X with nothing suspended does nothing")
	ow.queue_free()
	await process_frame
	_fresh()
