extends SceneTree
## Headless checks for Kheldar's Bribe: who has it, what it costs, what a neutral
## enemy does and doesn't do, and what refuses it.
## Run from the repo root:
##   godot --headless --path game --script res://tests/test_bribe.gd
## Exits 0 if every check passes, 1 otherwise.

var _failures: int = 0
var _checks: int = 0
var _p: Node
var _gs: Node

func check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: ", label)

func _initialize() -> void:
	_p = root.get_node("Progression")
	_gs = root.get_node("GameState")
	await process_frame
	await _run()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)

func _reset() -> void:
	_gs.progression.clear(); _gs.gold = 0; _gs.unlocked_classes.clear(); _gs.income_claimed.clear()
	_gs.inventories.clear(); _gs.convoy.clear(); _gs.equipment_ready = false; _gs.drops_claimed.clear()
	_gs.deeds.clear(); _gs.won_maps.clear()
	_gs.support_ranks.clear(); _gs.support_points.clear(); _gs.support_settled_maps.clear(); _gs.support_recent.clear()

func _arch(name: String, over := {}) -> Dictionary:
	var d := {"enemy_id": "ea_t_" + name, "name": name, "weapon_art": "sword", "weapon_tier": "worn", "movement_type": "infantry",
		"level": 5, "hp": 20, "str": 0, "mag": 0, "dex": 0, "spd": 0, "lck": 0, "def": 0, "res": 0}
	d.merge(over, true)
	return d

func _setup(deploy: Array, positions: Array, enemy_specs: Array) -> Node:
	var map: Node = load("res://scenes/map_d05.tscn").instantiate()
	var ids: Array[String] = []
	ids.assign(deploy)
	map.deploy_unit_ids = ids
	map.enemy_phase_enabled = false
	root.add_child(map)
	await process_frame
	for e in map.enemies:
		map._remove_enemy_token(e)
	map.enemies.clear(); map.dens.clear()
	for i in deploy.size():
		map.unit_positions[deploy[i]] = positions[i]
	var next_id := 0
	for spec in enemy_specs:
		next_id = map._spawn_enemy_instance(spec["arch"], spec["pos"], spec.get("kind", "mook"), next_id)
	var r := RandomNumberGenerator.new()
	r.seed = 3
	map.rng_override = r
	return map

func _bribe(m: Node, idx: int, dir: Vector2i) -> void:
	m.selected_unit_index = idx
	m.attacked_this_turn.clear()
	m._bribe_toward(dir)

func _key(m: Node, keycode: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.pressed = true
	m._unhandled_input(ev)

func _run() -> void:
	var R := Vector2i(1, 0)
	# ---- canon
	_reset()
	check(_p.can_bribe("u_kheldar") and not _p.can_bribe("u_gunnar") and not _p.can_bribe("u_jost") and not _p.can_bribe("u_nobody"), "only Kheldar's Factor class can bribe")
	check(_p.bribe_cost(5) == 90 and _p.bribe_cost(10) == 140 and _p.bribe_cost(0) == 40 and _p.bribe_cost(-3) == 40, "cost is 40 + 10 a level (Lv5 90, Lv10 140, never below 40)")
	check(_p.bribe_limit() == 1, "one bribe a map (canon: 'bribe one enemy')")
	check(_p.can_capture("u_gunnar") and _p.shove_distance("u_gunnar") == 1, "(the other kits are untouched)")

	# ---- a successful bribe
	_reset()
	_gs.gold = 200
	var m: Node = await _setup(["u_kheldar", "u_jost"], [Vector2i(5, 5), Vector2i(2, 8)],
		[{"arch": _arch("Looter"), "pos": Vector2i(6, 5)}, {"arch": _arch("Bandit"), "pos": Vector2i(12, 5)}])
	m.selected_unit_index = 0
	_key(m, KEY_B)
	check(m._bribe_mode and m.info_label.text.contains("Looter: Lv 5, 90 gold") and m.info_label.text.contains("You have 200 gold"), "B lists what each adjacent enemy would cost (%s)" % m.info_label.text)
	check(not m.info_label.text.contains("Bandit"), "(and only the adjacent ones)")
	_key(m, KEY_RIGHT)
	var e: Dictionary = m.enemies[0]
	check(not m._bribe_mode and e.get("neutral", false), "an arrow key then pays the enemy off")
	check(_gs.gold == 110 and m.bribed_count == 1, "it costs 90 gold (200 -> %d)" % _gs.gold)
	check(m.attacked_this_turn.has("u_kheldar"), "and Kheldar's action")
	check(e.token.bg.color == m.NEUTRAL_TOKEN_COLOR, "the token changes colour")
	check(m.info_label.text.contains("Kheldar presses a purse into the hand of the Looter (90 gold)") and m.info_label.text.contains("110 gold left"), "(%s)" % m.info_label.text)
	check(not e.defeated and e.pos == Vector2i(6, 5) and e.hp == 20, "it is neither defeated nor moved nor hurt")
	m._update_status_label()
	check(m.status_label.text.contains("Enemies alive: 1 (+1 neutral)"), "the status line counts hostiles apart from the neutral one (%s)" % m.status_label.text.split("\n")[0])
	check(m.status_label.text.contains("[B] bribe"), "the controls line lists [B] with Kheldar in the squad")
	m.queue_free()
	await process_frame

	# ---- what neutral means
	_reset()
	_gs.gold = 200
	m = await _setup(["u_gunnar", "u_jost"], [Vector2i(5, 5), Vector2i(2, 8)], [{"arch": _arch("Brute", {"str": 30, "dex": 90, "hp": 500}), "pos": Vector2i(6, 5)}])
	m.unit_hp["u_gunnar"] = 500
	m.enemy_phase_enabled = true
	m._enemy_phase()
	check(m.unit_hp["u_gunnar"] < 500, "(control: a hostile Brute hurts the unit beside it)")
	m.unit_hp["u_gunnar"] = 500
	m.enemies[0]["neutral"] = true
	m._enemy_phase()
	check(m.unit_hp["u_gunnar"] == 500 and m.enemy_log.is_empty() and m.enemies[0].pos == Vector2i(6, 5), "a neutral enemy neither attacks nor moves in the enemy phase")
	m.selected_unit_index = 0
	m.unit_positions["u_gunnar"] = Vector2i(4, 5)       # bow range 2: the enemy is in reach
	m.enemies[0]["neutral"] = false
	m._update_forecast()
	check(m.forecast_label.visible, "(control: a hostile enemy two tiles off is in the bow's reach and in the forecast)")
	m.enemies[0]["neutral"] = true
	m.attacked_this_turn.clear()
	m._attack_enemy()
	check(m.enemies[0].hp == 500 and m.info_label.text.contains("No enemy in range"), "a neutral enemy in reach can't be attacked")
	m.attacked_this_turn.clear()
	m._capture_enemy()
	check(not m.enemies[0].defeated and m.info_label.text.contains("No enemy in range"), "or captured")
	m._update_forecast()
	check(not m.forecast_label.visible, "or even shown in the forecast")
	m.unit_positions["u_gunnar"] = Vector2i(5, 5)
	check(m._occupant(Vector2i(6, 5)).has("enemy"), "but it still stands where it is (it blocks, and can still be shoved)")
	m.attacked_this_turn.clear()
	m._shove_toward(Vector2i(1, 0))
	check(m.enemies[0].pos == Vector2i(7, 5), "...Gunnar can shove it")
	m._update_status_label()
	check(not m.status_label.text.contains("[B] bribe"), "no [B] on the controls line without Kheldar")
	m.queue_free()
	await process_frame

	# a neutral enemy pays no income, and isn't a kill
	_reset()
	_gs.gold = 200
	m = await _setup(["u_kheldar"], [Vector2i(5, 5)], [{"arch": _arch("Looter"), "pos": Vector2i(6, 5)}, {"arch": _arch("Bandit"), "pos": Vector2i(12, 5)}])
	_bribe(m, 0, R)
	m.enemies[1].defeated = true
	m._settle_rewards()
	check(_gs.gold == 110 + int(round((200 + 15) * 1.5)), "income counts the defeated enemy, not the bribed one (gold %d)" % _gs.gold)
	m.queue_free()
	await process_frame

	# ---- refusals
	_reset()
	_gs.gold = 50
	m = await _setup(["u_kheldar", "u_jost"], [Vector2i(5, 5), Vector2i(5, 6)],
		[{"arch": _arch("Looter"), "pos": Vector2i(6, 5)}, {"arch": _arch("Captain"), "pos": Vector2i(4, 5), "kind": "boss"}])
	_bribe(m, 0, R)
	check(not m.enemies[0].get("neutral", false) and _gs.gold == 50 and m.info_label.text.contains("wants 90 gold and you have 50") and not m.attacked_this_turn.has("u_kheldar"),
		"too little gold: refused, free (%s)" % m.info_label.text)
	_gs.gold = 500
	_bribe(m, 0, Vector2i(-1, 0))
	check(not m.enemies[1].get("neutral", false) and _gs.gold == 500 and m.info_label.text.contains("cannot be bought") and not m.attacked_this_turn.has("u_kheldar"),
		"a boss can't be bought (%s)" % m.info_label.text)
	_bribe(m, 0, Vector2i(0, 1))
	check(m.info_label.text.contains("nobody there to bribe") and _gs.gold == 500, "an ally isn't an enemy to bribe")
	_bribe(m, 0, Vector2i(0, -1))
	check(m.info_label.text.contains("nobody there to bribe"), "nor an empty tile")
	_bribe(m, 1, R)
	check(m.info_label.text.contains("Jost has no Bribe action"), "a unit without the action can't")
	m.selected_unit_index = 0
	m.attacked_this_turn["u_kheldar"] = true
	m._bribe_toward(R)
	check(not m.enemies[0].get("neutral", false) and m.info_label.text.contains("already acted"), "not after acting")
	m.attacked_this_turn.clear()
	_bribe(m, 0, R)
	check(m.enemies[0].get("neutral", false) and _gs.gold == 410, "(with the gold, it works)")
	m.enemies.append({"inst_id": 9, "kind": "mook", "archetype": _arch("Second"), "pos": Vector2i(5, 4), "hp": 20, "max_hp": 20, "defeated": false, "token": {}})
	_bribe(m, 0, Vector2i(0, -1))
	check(not m.enemies[2].get("neutral", false) and _gs.gold == 410 and m.info_label.text.contains("already bought off all he can"), "a second bribe on the same map is refused (%s)" % m.info_label.text)
	m.selected_unit_index = 0
	m.attacked_this_turn.clear()
	_key(m, KEY_B)
	check(not m._bribe_mode and m.info_label.text.contains("already bought off"), "and B says so up front")
	m.bribed_count = 0
	m.enemies[0]["neutral"] = true
	m.enemies[1].defeated = true
	m.enemies[2].defeated = true
	_key(m, KEY_B)
	check(not m._bribe_mode and m.info_label.text.contains("no enemy beside Kheldar"), "B with nobody hostile adjacent doesn't start (a neutral isn't offered again)")
	m.queue_free()
	await process_frame

	# ---- cancelling and clicking
	_reset()
	_gs.gold = 500
	m = await _setup(["u_kheldar", "u_jost"], [Vector2i(5, 5), Vector2i(2, 8)], [{"arch": _arch("Looter"), "pos": Vector2i(6, 5)}])
	m.selected_unit_index = 0
	_key(m, KEY_B)
	_key(m, KEY_F)
	check(not m._bribe_mode and m.info_label.text.contains("cancelled") and not m.enemies[0].get("neutral", false) and _gs.gold == 500, "any other key cancels")
	_key(m, KEY_B)
	m._bribe_click(Vector2i(10, 10))
	check(not m._bribe_mode and _gs.gold == 500, "clicking away cancels")
	_key(m, KEY_B)
	m._bribe_click(Vector2i(6, 5))
	check(m.enemies[0].get("neutral", false) and _gs.gold == 410, "clicking the adjacent enemy bribes it")
	m.selected_unit_index = 1
	_key(m, KEY_B)
	check(not m._bribe_mode and m.info_label.text.contains("Jost has no Bribe action"), "B on a unit without it starts nothing")
	m.queue_free()
	await process_frame

	# the bribe resets per map: a fresh map has a fresh allowance
	_reset()
	_gs.gold = 500
	m = await _setup(["u_kheldar"], [Vector2i(5, 5)], [{"arch": _arch("Looter"), "pos": Vector2i(6, 5)}])
	check(m.bribed_count == 0, "a new map starts with nobody bribed")
	m.queue_free()
	await process_frame
