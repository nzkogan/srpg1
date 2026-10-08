extends SceneTree
## Headless checks for the miasma deed and the delivery deed (and the cargo units the
## second one needs): what counts, what doesn't, and how a cargo map is won and lost.
## Run from the repo root:
##   godot --headless --path game --script res://tests/test_cargo_miasma.gd
## Exits 0 if every check passes, 1 otherwise.
##
## map_a01 (16x12): miasma on cols 1-4 and rows 3-8, ice on cols 11-14; goal E at (8,1);
## the cart starts at (8,11). map_d03 (20x14): goal E at (10,2); wagons start on row 13;
## the ford F at (16,6) is foot-only.

var _failures: int = 0
var _checks: int = 0
var _p: Node
var _gs: Node
var _canon: Node

func check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: ", label)

func _initialize() -> void:
	_p = root.get_node("Progression")
	_gs = root.get_node("GameState")
	_canon = root.get_node("Canon")
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

func _setup(scene: String, deploy: Array, positions: Array, enemy_specs: Array = []) -> Node:
	var map: Node = load("res://scenes/%s.tscn" % scene).instantiate()
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

func _idx(m: Node, pid: String) -> int:
	for i in m.units.size():
		if m.units[i].get("punit_id", "") == pid:
			return i
	return -1

## Walks a unit onto `to` the way a click would (select it, then move).
func _move(m: Node, pid: String, from: Vector2i, to: Vector2i) -> void:
	m.unit_positions[pid] = from
	m.moved_this_turn.erase(pid)
	m._select_unit(_idx(m, pid))
	m._try_move_to(to)

func _end_turn(m: Node) -> void:
	m.turn = maxi(m.turn, 1)
	m._next_turn()

func _key(m: Node, keycode: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.pressed = true
	m._unhandled_input(ev)

func _run() -> void:
	# ---- canon
	_reset()
	check(_p.is_tracked("ep_miasma") and _p.count_needed("ep_miasma") == 5 and _p.deed_terrain("ep_miasma") == "ter_miasma", "ep_miasma is tracked: 5 turn-ends on ter_miasma")
	check(_p.is_tracked("ep_delivery") and _p.count_needed("ep_delivery") == 1 and _p.deed_terrain("ep_delivery") == "", "ep_delivery is tracked: one delivery, no terrain")
	var other_ids: Array = []
	for r in _p.other_tracked_epithets():
		other_ids.append(r["epithet_id"])
	check(other_ids == ["ep_miasma", "ep_delivery", "ep_dispersal", "ep_talk"], "they are among the 'other' tracked deeds (%s)" % str(other_ids))
	check(_p.gating_epithets().size() == 4 and not _p.gating_deeds_earned("u_jost").has("ep_miasma"), "and neither gates paragon")
	_p.record_deed("u_jost", "ep_miasma", 5); _p.record_deed("u_jost", "ep_delivery")
	check(_p.has_deed("u_jost", "ep_miasma") and _p.has_deed("u_jost", "ep_delivery") and _p.gating_deeds_earned("u_jost").is_empty(), "earning them doesn't count toward the paragon gate")
	_reset()
	var cargo: Array = _canon.get_table("cargo_units")
	var by_map := {}
	for c in cargo:
		by_map[c["map_id"]] = int(by_map.get(c["map_id"], 0)) + 1
	check(by_map == {"map_d03": 3, "map_a01": 1}, "canon has three wagons on d03 and the cart on a01 (%s)" % str(by_map))
	var needs := {}
	for mrow in _canon.get_table("maps"):
		if mrow.get("cargo_needed") != null:
			needs[mrow["map_id"]] = int(mrow["cargo_needed"])
	check(needs == {"map_d03": 2, "map_a01": 1}, "d03 needs 2 of its 3 delivered, a01 needs its 1 (%s)" % str(needs))

	# ---- miasma
	_reset()
	var m: Node = await _setup("map_a01", ["u_avatar", "u_torvald", "u_brandt"], [Vector2i(2, 4), Vector2i(8, 6), Vector2i(12, 4)])
	check(m._cargo_needed() == 1 and m.units.size() == 4 and m._is_cargo("cargo_a01_cart") and not m._is_cargo("u_avatar"), "a01 gets the cart as a fourth, cargo, unit")
	_end_turn(m)
	check(_p.deed_count("u_avatar", "ep_miasma") == 1, "ending a turn on miasma counts once (avatar at (2,4))")
	check(_p.deed_count("u_torvald", "ep_miasma") == 0, "on plain road doesn't")
	check(_p.deed_count("u_brandt", "ep_miasma") == 0, "nor on ice, which is a different hazard")
	check(" ".join(m.enemy_log).contains("Avatar has ended 1 of 5 turns in the miasma.") or " ".join(m.enemy_log).contains("has ended 1 of 5 turns in the miasma."), "the map says how far along (%s)" % " / ".join(m.enemy_log))
	check(m.info_label.text.contains("of 5 turns in the miasma"), "and the info panel shows it (%s)" % m.info_label.text.replace("\n", " / "))
	check(_p.deed_count("cargo_a01_cart", "ep_miasma") == 0, "the cart is never counted")
	for i in 3:
		_end_turn(m)
	check(_p.deed_count("u_avatar", "ep_miasma") == 4 and not _p.has_deed("u_avatar", "ep_miasma"), "four turns is progress, not the deed")
	_end_turn(m)
	check(_p.has_deed("u_avatar", "ep_miasma") and " ".join(m.enemy_log).contains("earns a deed: miasma walked ('Ash-walker')."), "the fifth earns it, announced (%s)" % " / ".join(m.enemy_log))
	_end_turn(m)
	check(_p.deed_count("u_avatar", "ep_miasma") == 6 and not " ".join(m.enemy_log).contains("earns a deed"), "later turns keep counting without re-announcing")
	check(m.unit_hp["u_avatar"] < 1000, "(and the hazard really did hurt him)")
	m.queue_free()
	await process_frame

	# counted before the hazard, so a unit that dies on the tile still counts; moving off stops it
	_reset()
	m = await _setup("map_a01", ["u_avatar", "u_torvald"], [Vector2i(2, 4), Vector2i(3, 4)])
	m.unit_hp["u_avatar"] = 1
	_end_turn(m)
	check(_p.deed_count("u_avatar", "ep_miasma") == 1 and not m.unit_positions.has("u_avatar"), "the turn that finishes a unit on miasma still counts it")
	m.unit_positions["u_torvald"] = Vector2i(6, 4)
	_end_turn(m)
	check(_p.deed_count("u_torvald", "ep_miasma") == 1, "stepping out stops the count (torvald: 1 turn)")
	check(_p.deed_count("u_avatar", "ep_miasma") == 1, "and the dead don't accrue")
	m.queue_free()
	await process_frame

	# it is where the turn ENDED that counts, even if the enemy phase then kills the unit
	_reset()
	m = await _setup("map_a01", ["u_avatar"], [Vector2i(2, 4)], [{"arch": _arch("Brute", {"str": 40, "dex": 99, "hp": 500}), "pos": Vector2i(2, 5)}])
	m.enemy_phase_enabled = true
	m.unit_hp["u_avatar"] = 1
	_end_turn(m)
	check(not m.unit_positions.has("u_avatar") and _p.deed_count("u_avatar", "ep_miasma") == 1, "a unit that ended its turn on miasma and was then cut down still counted")
	m.queue_free()
	await process_frame

	# turn 0 (the deploy screen) isn't a played turn
	_reset()
	m = await _setup("map_a01", ["u_avatar"], [Vector2i(2, 4)])
	m._next_turn()
	check(m.turn == 1 and _p.deed_count("u_avatar", "ep_miasma") == 0, "the first _next_turn only starts turn 1")
	m.queue_free()
	await process_frame

	# ---- cargo: the setup
	_reset()
	m = await _setup("map_d03", ["u_dietmar", "u_kheldar", "u_avatar"], [Vector2i(10, 4), Vector2i(10, 8), Vector2i(2, 12)], [{"arch": _arch("Far"), "pos": Vector2i(19, 0)}])
	check(m._cargo_needed() == 2 and m.units.size() == 6, "d03 has its three wagons on top of the roster")
	var spots: Dictionary = {}
	for u in m.units:
		if u.get("cargo", false):
			spots[u["punit_id"]] = Vector2i(int(u["deploy_col"]), int(u["deploy_row"]))
	check(spots.size() == 3 and spots["cargo_d03_wagon1"] == Vector2i(3, 13), "the wagons start on row 13 (%s)" % str(spots))
	var open_ground := true
	for pid in spots:
		if m._terrain_cost(spots[pid], "armor") >= m.IMPASSABLE:
			open_ground = false
	check(open_ground and m.unit_positions.has("cargo_d03_wagon2") and m.unit_hp["cargo_d03_wagon2"] == 30, "on open ground, placed, with their hit points")
	check(m._terrain_cost(Vector2i(16, 6), "armor") >= m.IMPASSABLE and m._terrain_cost(Vector2i(4, 6), "armor") >= 0 and m._terrain_cost(Vector2i(16, 6), "infantry") < m.IMPASSABLE,
		"the ford is foot-only, so a wagon (armor) must use the bridge")
	m._update_status_label()
	check(m.status_label.text.contains("Cargo: 0/2 delivered") and m.status_label.text.contains("[W] cargo"), "the status line tracks deliveries and lists [W] (%s)" % m.status_label.text.get_slice("\n", 0))
	m.selected_unit_index = _idx(m, "cargo_d03_wagon1")
	m._attack_enemy()
	check(m.info_label.text.contains("cannot fight"), "a wagon can't attack")
	# [W] cycles through cargo
	m.selected_unit_index = 0
	_key(m, KEY_W)
	check(m.selected_unit_index == _idx(m, "cargo_d03_wagon1"), "W selects the first cargo unit")
	_key(m, KEY_W)
	check(m.selected_unit_index == _idx(m, "cargo_d03_wagon2"), "and then the next")
	m.unit_positions.erase("cargo_d03_wagon3")
	_key(m, KEY_W)
	check(m.selected_unit_index == _idx(m, "cargo_d03_wagon1"), "wraps, skipping cargo no longer on the map")
	m.queue_free()
	await process_frame

	# ---- delivery
	_reset()
	m = await _setup("map_d03", ["u_dietmar", "u_kheldar", "u_avatar"], [Vector2i(10, 4), Vector2i(10, 8), Vector2i(10, 1)])
	_move(m, "cargo_d03_wagon1", Vector2i(10, 3), Vector2i(10, 2))
	check(not m.unit_positions.has("cargo_d03_wagon1") and m.delivered == ["cargo_d03_wagon1"], "a wagon on the goal leaves the map, delivered")
	check(not m.unit_tokens.has("cargo_d03_wagon1"), "its token goes too")
	check(m.info_label.text.contains("Grain wagon (north) is delivered (1 of 2)."), "the map says so (%s)" % m.info_label.text)
	check(_p.has_deed("u_dietmar", "ep_delivery") and m.info_label.text.contains("Dietmar earns a deed: delivery ('Carter')."), "a unit two tiles from the goal escorted it, and is told (%s)" % m.info_label.text)
	check(_p.has_deed("u_avatar", "ep_delivery"), "so did one standing on the goal itself, one tile away")
	check(not _p.has_deed("u_kheldar", "ep_delivery"), "a unit six tiles off didn't")
	check(not m.map_won and m.escaped_count == 0, "one of two isn't a win")
	m._update_status_label()
	check(m.status_label.text.contains("Cargo: 1/2 delivered"), "the status line updates")
	_move(m, "cargo_d03_wagon2", Vector2i(9, 2), Vector2i(10, 2))
	check(m.map_won and m.status_label.text.contains("DELIVERED. 2 of 2 reached the goal."), "the second wins the map (%s)" % m.status_label.text)
	check(m.info_label.text.begins_with("Victory."), "(%s)" % m.info_label.text)
	m.queue_free()
	await process_frame

	# a unit that already earned it isn't re-announced; a far escort is not enough
	_reset()
	_p.record_deed("u_dietmar", "ep_delivery")
	m = await _setup("map_d03", ["u_dietmar", "u_kheldar"], [Vector2i(10, 4), Vector2i(10, 5)])
	_move(m, "cargo_d03_wagon1", Vector2i(10, 3), Vector2i(10, 2))
	check(not m.info_label.text.contains("earns a deed") and _p.deed_count("u_dietmar", "ep_delivery") == 2, "a repeat escort is counted but not announced")
	check(not _p.has_deed("u_kheldar", "ep_delivery"), "three tiles away is outside the escort radius (2)")
	m.queue_free()
	await process_frame

	# only cargo delivers; a person on the goal escapes nowhere
	_reset()
	m = await _setup("map_d03", ["u_dietmar"], [Vector2i(10, 3)])
	_move(m, "u_dietmar", Vector2i(10, 3), Vector2i(10, 2))
	check(m.unit_positions.has("u_dietmar") and m.escaped_count == 0 and not m.map_won, "on a cargo map, a unit on the goal doesn't escape and doesn't count")
	check(m.delivered.is_empty(), "or deliver anything")
	m.queue_free()
	await process_frame

	# ---- losing the cargo
	_reset()
	m = await _setup("map_d03", ["u_dietmar"], [Vector2i(10, 4)])
	m._kill_unit("cargo_d03_wagon1")
	check(not m.map_lost, "one wagon lost of three: two left, still winnable")
	m._kill_unit("cargo_d03_wagon2")
	check(m.map_lost and m.status_label.text.contains("cargo is lost"), "two lost: only one can ever arrive, so the map is lost (%s)" % m.status_label.text)
	m.queue_free()
	await process_frame
	_reset()
	m = await _setup("map_d03", ["u_dietmar"], [Vector2i(10, 4)])
	_move(m, "cargo_d03_wagon1", Vector2i(10, 3), Vector2i(10, 2))
	m._kill_unit("cargo_d03_wagon2")
	check(not m.map_lost, "one delivered and one lost: the third can still make two")
	m._kill_unit("cargo_d03_wagon3")
	check(m.map_lost, "...but not once it goes too")
	m.queue_free()
	await process_frame

	# enemies attack cargo like any unit
	_reset()
	m = await _setup("map_d03", ["u_dietmar"], [Vector2i(2, 4)], [{"arch": _arch("Brute", {"str": 12, "dex": 90, "hp": 500}), "pos": Vector2i(10, 12)}])
	m.enemy_phase_enabled = true
	m.unit_positions["cargo_d03_wagon2"] = Vector2i(9, 13)
	m.unit_positions["cargo_d03_wagon1"] = Vector2i(0, 0)
	m.unit_positions["cargo_d03_wagon3"] = Vector2i(19, 0)
	var hp_before: int = m.unit_hp["cargo_d03_wagon2"]
	m._enemy_phase()
	check(m.unit_hp["cargo_d03_wagon2"] < hp_before, "an enemy beside a wagon hits it (%d -> %d)" % [hp_before, m.unit_hp["cargo_d03_wagon2"]])
	m.queue_free()
	await process_frame

	# ---- a01: the cart, and hazards hurting it
	_reset()
	m = await _setup("map_a01", ["u_avatar"], [Vector2i(12, 8)])
	var cart_hp: int = m.unit_hp["cargo_a01_cart"]
	m.unit_positions["cargo_a01_cart"] = Vector2i(2, 4)
	_end_turn(m)
	check(m.unit_hp["cargo_a01_cart"] == cart_hp - 2, "the cart takes the miasma's damage (%d -> %d)" % [cart_hp, m.unit_hp["cargo_a01_cart"]])
	_move(m, "cargo_a01_cart", Vector2i(8, 2), Vector2i(8, 1))
	check(m.map_won and m.delivered == ["cargo_a01_cart"], "delivering the cart wins a01 (it needs just the one)")
	m.queue_free()
	await process_frame

	# other escort maps keep the old rule
	_reset()
	m = await _setup("map_x11", ["u_dietmar"], [Vector2i(5, 5)])
	check(m._cargo_needed() == 0 and m.units.size() == 1, "an escort map with no cargo is unchanged (x11)")
	m.queue_free()
	await process_frame

	# ---- the deeds are saved, and the barracks lists them
	_reset()
	_p.record_deed("u_jost", "ep_miasma", 3)
	var snap: Dictionary = _gs.to_dict()
	_gs.deeds.clear()
	_gs.from_dict(snap)
	check(_p.deed_count("u_jost", "ep_miasma") == 3 and not _p.has_deed("u_jost", "ep_miasma"), "miasma progress survives a save")
	var bar: Node = load("res://scripts/barracks_screen.gd").new()
	var lines: Array[String] = []
	bar._append_deeds(lines, "u_jost")
	var shown := "\n".join(lines)
	check(shown.contains("Other deeds") and shown.contains("miasma walked") and shown.contains("-- 3 of 5") and shown.contains("delivery"), "the barracks lists them under 'Other deeds' with progress (%s)" % shown.replace("\n", " / "))
	check(shown.find("Other deeds") > shown.find("capture"), "after the four that gate paragon")
	_p.record_deed("u_jost", "ep_miasma", 2)
	_p.record_deed("u_jost", "ep_delivery")
	lines.clear(); bar._append_deeds(lines, "u_jost")
	shown = "\n".join(lines)
	check(shown.contains("[x] miasma walked") and shown.contains("[x] delivery"), "earned ones are ticked")
	check(not shown.contains("not recordable yet") or not shown.contains("dispersal"), "(the untracked ones aren't listed)")
	bar.free()
