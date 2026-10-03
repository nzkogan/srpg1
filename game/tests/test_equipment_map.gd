extends SceneTree
## Headless checks for equipment on the battle map: the equipped weapon is what
## fights, strikes spend uses, weapons break, [E] swaps, drops reach the convoy.
## Run from the repo root:
##   godot --headless --path game --script res://tests/test_equipment_map.gd
## Exits 0 if every check passes, 1 otherwise.

const ForecastView := preload("res://scripts/forecast_view.gd")

var _failures: int = 0
var _checks: int = 0
var _eq: Node
var _gs: Node

func check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: ", label)

func _initialize() -> void:
	_eq = root.get_node("Equipment")
	_gs = root.get_node("GameState")
	await process_frame
	await _run()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)

func _reset() -> void:
	_gs.inventories.clear(); _gs.convoy.clear(); _gs.equipment_ready = false; _gs.drops_claimed.clear()
	_gs.support_ranks.clear(); _gs.support_points.clear(); _gs.support_settled_maps.clear(); _gs.support_recent.clear()

func _key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e

func _unit(pid: String, art, over := {}) -> Dictionary:
	var arts: Array = [art] if art != null else []
	var d := {"punit_id": pid, "name": pid.substr(2).capitalize(), "hp": 40, "str": 8, "mag": 4, "dex": 60, "spd": 8, "lck": 4,
		"def": 4, "res": 3, "weapon_art": art, "arts": arts, "movement_type": "infantry", "move": 5, "what_they_do": "unarmed"}
	d.merge(over, true)
	return d

func _arch(name: String, art: String, over := {}) -> Dictionary:
	var d := {"enemy_id": "ea_t_" + name, "name": name, "weapon_art": art, "weapon_tier": "basic", "movement_type": "infantry",
		"hp": 60, "str": 8, "mag": 0, "dex": 60, "spd": 8, "lck": 4, "def": 4, "res": 3}
	d.merge(over, true)
	return d

func _setup(unit_rows: Array, positions: Array, enemy_specs: Array) -> Node:
	var map: Node = load("res://scenes/map_d05.tscn").instantiate()
	root.add_child(map)
	await process_frame
	for e in map.enemies:
		map._remove_enemy_token(e)
	map.enemies.clear()
	map.dens.clear()
	for pid in map.unit_tokens:
		map.unit_tokens[pid].container.queue_free()
	map.unit_tokens.clear(); map.unit_positions.clear(); map.unit_hp.clear()
	map.units = unit_rows
	for i in unit_rows.size():
		map.unit_positions[unit_rows[i]["punit_id"]] = positions[i]
		map.unit_hp[unit_rows[i]["punit_id"]] = int(unit_rows[i]["hp"])
	var next_id := 0
	for spec in enemy_specs:
		next_id = map._spawn_enemy_instance(spec["arch"], spec["pos"], spec.get("kind", "mook"), next_id, spec.get("row", {}))
	var r := RandomNumberGenerator.new()
	r.seed = 3
	map.rng_override = r
	return map

func _run() -> void:
	# ---- a roster unit fights with its equipped weapon, and strikes spend uses
	_reset()
	var m: Node = await _setup([_unit("u_jost", "axe")], [Vector2i(5, 5)], [{"arch": _arch("Looter", "sword"), "pos": Vector2i(6, 5)}])
	var jost: Dictionary = m.units[0]
	check(m._weapon_for_unit(jost)["weapon_id"] == "wpn_axe_basic" and m._uses_of(jost) == 45, "Jost fights with his basic axe (45 uses)")
	m.selected_unit_index = 0
	m._update_forecast()
	check(m.forecast_label.text.contains("Iron Axe (45)"), "the forecast shows the weapon with its uses")
	m._attack_enemy()
	var left: int = m._uses_of(jost)
	check(left == 44 or left == 43, "an attack spends one use per strike (45 -> %d)" % left)
	m.queue_free()
	await process_frame

	# ---- the last use breaks the weapon; with a spare, the spare is equipped
	_reset()
	m = await _setup([_unit("u_jost", "axe")], [Vector2i(5, 5)], [{"arch": _arch("Looter", "sword"), "pos": Vector2i(6, 5)}])
	jost = m.units[0]
	_eq.convoy_add("wpn_axe_mid"); _eq.take("u_jost", _eq.convoy().size() - 1)
	_eq.inventory("u_jost")[0]["uses"] = 1
	m.selected_unit_index = 0
	m._update_forecast()
	check(m.forecast_label.text.contains("will break (1 use left)"), "the forecast warns when a weapon is about to break")
	m._attack_enemy()
	check(m.info_label.text.contains("Iron Axe breaks!") and m.info_label.text.contains("They switch to the Steel Axe."), "the break is announced, with the spare taking over (%s)" % m.info_label.text)
	check(_eq.equipped("u_jost")["weapon_id"] == "wpn_axe_mid" and _eq.inventory("u_jost").size() == 1, "the broken axe is gone; the steel axe is equipped")
	m.queue_free()
	await process_frame

	# ---- with no spare the unit is left unarmed and can't fight on
	_reset()
	m = await _setup([_unit("u_jost", "axe")], [Vector2i(5, 5)], [{"arch": _arch("Looter", "sword"), "pos": Vector2i(6, 5)}])
	jost = m.units[0]
	_eq.inventory("u_jost")[0]["uses"] = 1
	m.selected_unit_index = 0
	m._attack_enemy()
	check(m.info_label.text.contains("nothing left to fight with"), "no spare: they have nothing left to fight with")
	check(m._weapon_for_unit(jost).is_empty(), "...and no weapon resolves for them")
	m.attacked_this_turn.clear()
	m._attack_enemy()
	check(m.info_label.text.contains("no weapon"), "an unarmed unit can't attack (%s)" % m.info_label.text)
	m.queue_free()
	await process_frame

	# ---- the enemy phase wears the defender's weapon (counters spend uses)
	_reset()
	m = await _setup([_unit("u_jost", "axe", {"hp": 200})], [Vector2i(5, 5)], [{"arch": _arch("Looter", "sword", {"hp": 200}), "pos": Vector2i(6, 5)}])
	jost = m.units[0]
	var before: int = m._uses_of(jost)
	m._enemy_phase()
	check(m._uses_of(jost) < before, "a counter spends the defender's uses (%d -> %d)" % [before, m._uses_of(jost)])
	_eq.inventory("u_jost")[0]["uses"] = 1
	m._enemy_phase()
	check(" ".join(m.enemy_log).contains("breaks"), "a weapon broken by a counter shows in the enemy log: %s" % str(m.enemy_log))
	m.queue_free()
	await process_frame

	# ---- [E] swaps weapons; refused after attacking; nothing to swap to
	_reset()
	m = await _setup([_unit("u_jost", "axe")], [Vector2i(5, 5)], [{"arch": _arch("Looter", "sword"), "pos": Vector2i(6, 5)}])
	m.selected_unit_index = 0
	m._unhandled_input(_key(KEY_E))
	check(m.info_label.text.contains("no other weapon"), "[E] with one weapon says so")
	_eq.convoy_add("wpn_axe_mid"); _eq.take("u_jost", _eq.convoy().size() - 1)
	m._update_forecast()
	check(m.forecast_label.text.contains("Iron Axe"), "(starts on the iron axe)")
	m._unhandled_input(_key(KEY_E))
	check(m.info_label.text.contains("equips the Steel Axe (30)"), "[E] equips the next weapon (%s)" % m.info_label.text)
	check(m.forecast_label.text.contains("Steel Axe (30)") and not m.forecast_label.text.contains("Iron Axe"), "the forecast follows the swap")
	check(m.units[0]["punit_id"] == "u_jost" and m._weapon_for_unit(m.units[0])["weapon_id"] == "wpn_axe_mid", "and so does the weapon that will strike")
	m._attack_enemy()
	m._unhandled_input(_key(KEY_E))
	check(m.info_label.text.contains("already attacked"), "no swapping after attacking this turn")
	m.queue_free()
	await process_frame

	# ---- drops: a defeated enemy adds its weapon to the convoy, once
	_reset()
	var row := {"spawn_id": "spn_test_drop", "drop_weapon_id": "wpn_halberd"}
	m = await _setup([_unit("u_jost", "axe")], [Vector2i(5, 5)], [{"arch": _arch("Captain", "sword"), "pos": Vector2i(6, 5), "kind": "boss", "row": row}])
	m.enemies[0].hp = 1
	m.selected_unit_index = 0
	var convoy_before: int = _eq.convoy().size()
	m._attack_enemy()
	check(m.enemies[0].defeated and m.info_label.text.contains("It drops a Halberd (added to the convoy)."), "defeating a drop-carrier says what it dropped (%s)" % m.info_label.text)
	check(_eq.convoy().size() == convoy_before + 1 and _eq.convoy()[-1]["weapon_id"] == "wpn_halberd", "the halberd is in the convoy")
	# the same spawn again (a replay) drops nothing
	m.queue_free()
	await process_frame
	m = await _setup([_unit("u_jost", "axe")], [Vector2i(5, 5)], [{"arch": _arch("Captain", "sword"), "pos": Vector2i(6, 5), "kind": "boss", "row": row}])
	m.enemies[0].hp = 1
	m.selected_unit_index = 0
	m._attack_enemy()
	check(not m.info_label.text.contains("drops") and _eq.convoy().size() == convoy_before + 1, "a replayed kill doesn't drop again")
	m.queue_free()
	await process_frame
	# a den wave never drops
	_reset()
	m = await _setup([_unit("u_jost", "axe")], [Vector2i(5, 5)], [{"arch": _arch("Wave", "sword"), "pos": Vector2i(6, 5)}])
	check(m.enemies[0]["drop"] == null and m.enemies[0]["spawn_id"] == "", "enemies spawned without a spawn row carry no drop")
	m.queue_free()
	await process_frame
	# a drop earned through a counter in the enemy phase
	_reset()
	m = await _setup([_unit("u_jost", "axe", {"str": 40, "hp": 100})], [Vector2i(5, 5)],
		[{"arch": _arch("Captain", "sword"), "pos": Vector2i(6, 5), "kind": "boss", "row": {"spawn_id": "spn_counter_drop", "drop_weapon_id": "wpn_lance_high"}}])
	m.enemies[0].hp = 1
	m._enemy_phase()
	check(" ".join(m.enemy_log).contains("drops a Silver Lance"), "a counter kill's drop shows in the log: %s" % str(m.enemy_log))
	m.queue_free()
	await process_frame

	# ---- real data: the Act 1 captain on map_a06 carries a steel lance
	_reset()
	var a06: Node = load("res://scenes/map_a06.tscn").instantiate()
	root.add_child(a06)
	await process_frame
	var boss: Dictionary = {}
	for e in a06.enemies:
		if e.kind == "boss":
			boss = e
	check(not boss.is_empty() and boss["spawn_id"] == "spn_a06_boss" and boss["drop"] == "wpn_lance_mid", "map_a06's boss drops a Steel Lance (from canon)")
	a06.queue_free()
	await process_frame
