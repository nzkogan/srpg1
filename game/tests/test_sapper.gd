extends SceneTree
## Headless checks for the Sapper (Rinsa): the class, Breach (a wall becomes a way through, for
## everyone), Mine (a charge for the first enemy to step on it), the shared charges, the snapshot.
## Run from the repo root:
##   godot --headless --path game --script res://tests/test_sapper.gd
## Exits 0 if every check passes, 1 otherwise.

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

func _join(ids: Array, level := 10) -> void:
	for u in ids:
		_p.state(u)
		_gs.progression[u]["level"] = level

func _map(scene: String, deploy: Array, specs: Array = [], phase := false) -> Node:
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
	var nid := 0
	for spec in specs:
		nid = m._spawn_enemy_instance(spec["arch"], spec["pos"], spec.get("kind", "mook"), nid)
	var r := RandomNumberGenerator.new()
	r.seed = 3
	m.rng_override = r
	return m

func _arch(name: String, over := {}) -> Dictionary:
	var d := {"enemy_id": "ea_t_" + name, "name": name, "weapon_art": "sword", "weapon_tier": "worn", "movement_type": "infantry",
		"level": 5, "hp": 30, "str": 3, "mag": 0, "dex": 0, "spd": 0, "lck": 0, "def": 0, "res": 0, "affiliation": "state", "death_noun": "lance"}
	d.merge(over, true)
	return d

## A tile whose symbol is in `symbols` and that has a free (passable) orthogonal neighbour:
## [wall tile, neighbour].
func _wall_beside_floor(m: Node, symbols: String) -> Array:
	for y in m.grid.size():
		for x in m.grid[y].length():
			if m.grid[y][x] in symbols.split("", false):
				for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
					var n: Vector2i = Vector2i(x, y) + d
					if m._in_bounds(n) and m._terrain_cost(n, "infantry") < 99 and m._occupant(n).is_empty():
						return [Vector2i(x, y), n]
	return []

func _key(n: Node, keycode: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.pressed = true
	n._unhandled_input(ev)

func _run() -> void:
	# ---- canon
	var cls: Dictionary = _canon.find_by("classes", "class_id", "cls_sapper")
	check(cls["tier"] == "personal" and cls["art_primary"] == "brawl" and cls["map_actions"] == "breach|mine" and cls["movement"] == "infantry", "the Sapper is a personal brawl class with Breach and Mine")
	check(_canon.find_by("units", "unit_id", "u_rinsa")["base_class_id"] == "cls_sapper", "Rinsa holds it")
	check(_canon.find_by("terrain_costs", "terrain_id", "ter_breach")["symbol"] == "v", "the breach is a terrain")
	var d01 = _canon.find_by("maps", "map_id", "map_d01")
	var d03 = _canon.find_by("maps", "map_id", "map_d03")
	check(d01["breach_symbols"] == "b" and d03["breach_symbols"] == null and _canon.find_by("maps", "map_id", "map_d10")["breach_symbols"] == "x", "maps say which symbols can be breached (d01 its warehouses, d10 its wall, d03 nothing)")
	check(_p.sapper_limit() == 3 and _p.mine_damage() == 12, "three charges a map; a mine does 12")
	_gs.reset()
	_join(["u_rinsa", "u_sigrun"])
	check(_p.can_breach("u_rinsa") and _p.can_mine("u_rinsa") and not _p.can_breach("u_sigrun") and not _p.can_mine("u_sigrun"), "only the Sapper has the actions")
	check(_p.class_name_of("u_rinsa") == "Sapper" and _p.promotion_options("u_rinsa").size() == 1, "she takes a personal milestone, not a trained class's options")
	check(root.get_node("Equipment").can_wield("u_rinsa", "wpn_brawl_basic"), "and still fights with a gauntlet")

	# ---- Breach
	var m: Node = await _map("map_d01", ["u_rinsa", "u_sigrun"])
	var spot: Array = _wall_beside_floor(m, "b")
	var wall: Vector2i = spot[0]
	var floor_tile: Vector2i = spot[1]
	m.unit_positions["u_rinsa"] = floor_tile
	m.unit_positions["u_sigrun"] = Vector2i(0, 0)
	m.selected_unit_index = 0
	check(m._terrain_cost(wall, "infantry") >= 99 and m._terrain_cost(wall, "flying") >= 99, "(a warehouse blocks everyone, fliers too)")
	var reach_before: Dictionary = m._compute_reachable(floor_tile, 9, "infantry")
	check(not reach_before.has(wall), "(and no one can walk into it)")
	m.selected_unit_index = m.units.find(m.units.filter(func(u): return u["punit_id"] == "u_sigrun")[0])
	m._begin_sapper("breach")
	check(not m._sapper_mode == "breach" and m.info_label.text.contains("no Breach action"), "Sigrun has no Breach")
	m.selected_unit_index = m.units.find(m.units.filter(func(u): return u["punit_id"] == "u_rinsa")[0])
	_key(m, KEY_D)
	check(m._sapper_mode == "breach" and m.info_label.text.contains("3 charges left"), "D offers Breach and counts the charges")
	_key(m, KEY_ESCAPE)
	check(m._sapper_mode == "" and not m.breached.has(wall), "any other key cancels")
	# a tile that is not breachable
	m._begin_sapper("breach")
	var open_dir := Vector2i(0, 0)
	for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		if m._in_bounds(floor_tile + d) and m._terrain_cost(floor_tile + d, "infantry") < 99 and m._occupant(floor_tile + d).is_empty():
			open_dir = d
	m._sapper_toward(open_dir)
	check(m.info_label.text.contains("Nothing there can be brought down") and m.sapper_used == 0 and not m.attacked_this_turn.has("u_rinsa"), "open ground can't be breached, and nothing is spent")
	m._begin_sapper("mine")
	m._sapper_toward(wall - floor_tile)
	check(m.sapper_used == 0 and m.mines.is_empty() and m.info_label.text.contains("can't be laid"), "a charge can't be laid in a wall")
	m.unit_positions["u_sigrun"] = floor_tile + open_dir
	m._begin_sapper("mine")
	m._sapper_toward(open_dir)
	check(m.sapper_used == 0 and m.mines.is_empty(), "...or under a friend")
	m.unit_positions["u_sigrun"] = Vector2i(0, 0)
	m._begin_sapper("breach")
	m._sapper_toward(wall - floor_tile)
	check(m.breached.has(wall) and m.sapper_used == 1 and m.attacked_this_turn.has("u_rinsa"), "the wall comes down; a charge and the action are spent")
	check(m._effective_symbol(wall) == "v" and m._terrain_cost(wall, "infantry") == 2 and m._terrain_cost(wall, "armor") == 3 and m._terrain_cost(wall, "riding") == 3 and m._terrain_cost(wall, "flying") == 1, "a breach costs 2 on foot, 3 for armor and riders, 1 in the air")
	check(m._compute_reachable(floor_tile, 9, "infantry").has(wall), "...and now people can cross it")
	check(m.tile_rects[wall].color == m.LEGEND["v"], "the tile is redrawn")
	m._begin_sapper("breach")
	check(m._sapper_mode == "" and m.info_label.text.contains("already acted"), "one action a turn")
	m.attacked_this_turn.clear()
	m._begin_sapper("breach")
	m._sapper_toward(wall - floor_tile)
	check(m.sapper_used == 1 and m.info_label.text.contains("Nothing there"), "a breach can't be breached twice")

	# ---- Mine
	var free_dir := Vector2i(0, 0)
	for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		var t: Vector2i = floor_tile + d
		if m._in_bounds(t) and m._terrain_cost(t, "infantry") < 99 and t != wall and m._occupant(t).is_empty():
			free_dir = d
	check(free_dir != Vector2i(0, 0), "(a free tile for a mine)")
	var mt: Vector2i = floor_tile + free_dir
	_key(m, KEY_M)
	m._sapper_toward(free_dir)
	check(m.mines.has(mt) and m.sapper_used == 2 and m.mine_markers.has(mt) and m.attacked_this_turn.has("u_rinsa"), "a charge is laid and marked")
	m.attacked_this_turn.clear()
	m._begin_sapper("mine")
	m._sapper_toward(free_dir)
	check(m.sapper_used == 2 and m.info_label.text.contains("can't be laid"), "no second charge on the same tile")
	m._begin_sapper("mine")
	m._sapper_toward(wall - floor_tile)
	check(m.sapper_used == 3 and m.mines.has(wall) and not m.mines.is_empty(), "a breach can hold a charge too (the last one)")
	m.attacked_this_turn.clear()
	_key(m, KEY_M)
	check(m._sapper_mode == "" and m.info_label.text.contains("no charges left"), "the charges are shared and run out at three")
	# a player stepping on a mine sets it off for no one
	m.unit_positions["u_sigrun"] = mt
	check(m.mines.has(mt), "a friend on a mine does nothing")
	m.unit_positions["u_sigrun"] = Vector2i(0, 0)
	# the enemy trips it
	m._spawn_enemy_instance(_arch("Levy", {"hp": 30}), Vector2i(15, 7), "mook", 9)
	var inst: Dictionary = m.enemies[-1]
	inst.pos = Vector2i(15, 7)
	m._enemy_move(inst, mt)
	check(not m.mines.has(mt) and not m.mine_markers.has(mt) and inst.hp == 18 and m.enemy_log.any(func(l): return l.contains("A mine goes off under the Levy (12 damage)")), "an enemy that ends a move on it takes 12 and the charge is gone (hp %d)" % inst.hp)
	check(inst.has("hit_by") and inst["hit_by"].has("u_rinsa"), "the damage is the Sapper's (a boss it touches is no longer single combat)")
	# a kill
	m._spawn_enemy_instance(_arch("Frail", {"hp": 10}), Vector2i(15, 6), "mook", 10)
	var inst2: Dictionary = m.enemies[-1]
	m.mines[wall] = {"by": "u_rinsa"}
	inst2["spawn_id"] = "spn_test_mine"
	inst2["drop"] = "wpn_axe_mid"
	var convoy_before: int = _gs.convoy.size()
	m._enemy_move(inst2, wall)
	check(inst2.defeated and inst2.hp == 0 and m.enemy_log.any(func(l): return l.contains("It falls")), "a mine can kill")
	check(_gs.convoy.size() == convoy_before + 1, "...and a kill by mine is a real defeat: it drops what it carried")
	m.queue_free()
	await process_frame

	# ---- in the enemy phase, an enemy walks into the charge
	_gs.reset()
	_join(["u_rinsa"])
	var m2: Node = await _map("map_d02", ["u_rinsa"], [{"arch": _arch("Walker", {"hp": 30, "str": 3, "dex": 30}), "pos": Vector2i(13, 9)}], true)
	m2.unit_positions["u_rinsa"] = Vector2i(8, 9)
	m2.mines[Vector2i(9, 9)] = {"by": "u_rinsa"}
	m2._draw_mine(Vector2i(9, 9))
	m2._enemy_phase()
	check(not m2.mines.has(Vector2i(9, 9)) and m2.enemies[0].hp < 30 and m2.enemy_log.any(func(l): return l.contains("mine goes off")), "an enemy closing in steps on the charge in front of its target (log: %s)" % str(m2.enemy_log))

	# ---- the snapshot carries it all
	m2.sapper_used = 2
	var wall_tile := Vector2i(2, 2)
	m2.breached[wall_tile] = true
	m2.mines[Vector2i(3, 3)] = {"by": "u_rinsa"}
	var snap: Dictionary = m2.capture_state()
	check(int(snap["sapper_used"]) == 2 and snap["breached"].size() == 1 and snap["mines"].size() >= 1, "a suspension remembers the charges, breaches and mines")
	var json: Variant = JSON.parse_string(JSON.stringify(snap))
	m2.queue_free()
	await process_frame
	var m3: Node = await _map("map_d03", ["u_rinsa"])
	m3._restore_progress(_gs.restore(json))
	check(m3.sapper_used == 2 and m3.breached.has(wall_tile) and m3.mines.has(Vector2i(3, 3)) and m3.mine_markers.has(Vector2i(3, 3)) and m3._effective_symbol(wall_tile) == "v", "...and gives them back after a JSON round trip")
	m3.queue_free()
	await process_frame
