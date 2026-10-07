extends SceneTree
## Headless checks for the Shove / Smite map action: who has it, how far it
## pushes, what stops a push, and what a push costs and doesn't.
## Run from the repo root:
##   godot --headless --path game --script res://tests/test_shove.gd
## Exits 0 if every check passes, 1 otherwise.
##
## Map d05: walls on the rim (col 0 / col 21, rows 0-1, 10-11) and pillars at
## col 7 and col 14 (open only on row 5), so a push along row 3 meets a wall.

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

func _shove(m: Node, idx: int, dir: Vector2i) -> void:
	m.selected_unit_index = idx
	m.attacked_this_turn.clear()
	m._shove_toward(dir)

func _key(m: Node, keycode: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.pressed = true
	m._unhandled_input(ev)

func _make_smiter(unit: String) -> void:
	_p.ensure(unit)
	_gs.progression[unit]["promoted"] = true

func _run() -> void:
	var R := Vector2i(1, 0)
	var L := Vector2i(-1, 0)
	# ---- who has it, and how far
	_reset()
	check(_p.shove_distance("u_gunnar") == 1 and _p.push_name("u_gunnar") == "Shove", "Gunnar starts with Shove: 1 tile")
	check(_p.shove_distance("u_jost") == 0 and _p.push_name("u_jost") == "", "most units have no push at all")
	check(_p.shove_distance("u_nobody") == 0, "an unknown unit has none")
	_p.ensure("u_gunnar")
	_gs.progression["u_gunnar"]["level"] = 15
	_gs.gold = 1000
	var res: Dictionary = _p.promote("u_gunnar", "cls_bounty_hunter")
	check(res["ok"] and _p.is_promoted("u_gunnar"), "Gunnar certifies at 15 (his milestone keeps his class)")
	check(_p.shove_distance("u_gunnar") == 2 and _p.push_name("u_gunnar") == "Smite", "...and his Shove upgrades to Smite: 2 tiles")
	check(_p.can_capture("u_gunnar"), "(he keeps Capture too)")
	_reset()
	_p.ensure("u_jost")
	_gs.progression["u_jost"]["class_id"] = "cls_housecarl"
	check(_p.shove_distance("u_jost") == 2 and _p.push_name("u_jost") == "Smite" and not _p.is_promoted("u_jost"), "a Housecarl has Smite natively, certified or not")
	check(_p.push_distance_for(2, "armor") == 1 and _p.push_distance_for(1, "armor") == 0, "armor resists one tile: Smite moves it 1, Shove 0")
	check(_p.push_distance_for(2, "infantry") == 2 and _p.push_distance_for(2, "riding") == 2 and _p.push_distance_for(2, "flying") == 2, "everyone else takes the full push")

	# ---- the barracks tells Gunnar what certifying buys
	_reset()
	_p.ensure("u_gunnar")
	_gs.progression["u_gunnar"]["level"] = 15
	var bar: Node = load("res://scripts/barracks_screen.gd").new()
	check(not _p.promotion_options("u_gunnar").is_empty(), "(Gunnar has a milestone to take)")
	var txt := "\n".join(bar._certify_text("u_gunnar", _p.state("u_gunnar"), {"data": _p.promotion_options("u_gunnar")[0]}))
	check(txt.contains("Your Shove becomes Smite: it pushes 2 tiles, not 1."), "the certify screen says Shove becomes Smite (%s)" % txt.replace("\n", " / "))
	_reset()
	_p.ensure("u_jost")
	var jo: Array = _p.promotion_options("u_jost")
	if not jo.is_empty():
		var jt := "\n".join(bar._certify_text("u_jost", _p.state("u_jost"), {"data": jo[0]}))
		check(not jt.contains("Smite"), "and says nothing about it to a unit without a Shove")
	bar.free()

	# ---- a plain shove
	_reset()
	var m: Node = await _setup(["u_gunnar", "u_jost"], [Vector2i(5, 5), Vector2i(2, 8)],
		[{"arch": _arch("Looter"), "pos": Vector2i(6, 5)}])
	var e: Dictionary = m.enemies[0]
	var exp_before: int = _p.exp_of("u_gunnar")
	_shove(m, 0, R)
	check(e.pos == Vector2i(7, 5), "Shove pushes an adjacent enemy one tile straight away (now %s)" % str(e.pos))
	check(e.token.container.position == Vector2(7 * m.CELL_SIZE, 5 * m.CELL_SIZE), "and its token moves with it")
	check(e.hp == 20 and not m.fought_units.has("u_gunnar") and _p.exp_of("u_gunnar") == exp_before, "no damage, no fight, no EXP")
	check(m.attacked_this_turn.has("u_gunnar"), "it spends the unit's action")
	check(m.info_label.text.contains("Gunnar shoves the Looter back 1 tile."), "the map says so (%s)" % m.info_label.text)
	m._shove_toward(R)
	check(e.pos == Vector2i(7, 5) and m.info_label.text.contains("already acted"), "a second push the same turn is refused")
	m.attacked_this_turn.clear()
	m._shove_toward(L)
	check(m.info_label.text.contains("nobody to push") and not m.attacked_this_turn.has("u_gunnar"), "an empty tile is refused and costs nothing")
	_shove(m, 1, R)
	check(m.info_label.text.contains("Jost has no Shove action") and not m.attacked_this_turn.has("u_jost"), "a unit without the action can't push")
	# the push uses no weapon
	m.unit_positions["u_gunnar"] = Vector2i(5, 5)
	e.pos = Vector2i(6, 5)
	_gs.inventories.clear()
	_shove(m, 0, R)
	check(e.pos == Vector2i(7, 5), "it needs no weapon in hand")
	m.queue_free()
	await process_frame

	# ---- Smite goes one further
	_reset()
	_make_smiter("u_gunnar")
	m = await _setup(["u_gunnar"], [Vector2i(5, 5)], [{"arch": _arch("Looter"), "pos": Vector2i(6, 5)}])
	_shove(m, 0, R)
	check(m.enemies[0].pos == Vector2i(8, 5), "a certified Gunnar's push moves the target two tiles (now %s)" % str(m.enemies[0].pos))
	check(m.info_label.text.contains("Gunnar smites the Looter back 2 tiles."), "and is written as a smite (%s)" % m.info_label.text)
	m._update_status_label()
	check(m.status_label.text.contains("[S] smite"), "the controls line names it")
	m.queue_free()
	await process_frame

	_reset()
	m = await _setup(["u_gunnar"], [Vector2i(5, 5)], [{"arch": _arch("Looter"), "pos": Vector2i(6, 5)}])
	m._update_status_label()
	check(m.status_label.text.contains("[S] shove") and not m.status_label.text.contains("smite"), "and the uncertified Gunnar's line says shove")
	m.queue_free()
	await process_frame

	# ---- what stops a push, and what that does (collision: 10% of the pushed unit's max HP, never lethal)
	_reset()
	_make_smiter("u_gunnar")
	check(_p.collision_damage(20, 20) == 2 and _p.collision_damage(25, 25) == 2 and _p.collision_damage(9, 9) == 0 and _p.collision_damage(100, 100) == 10,
		"collision damage is a tenth of max HP, rounded down (20 -> 2, 25 -> 2, 9 -> 0)")
	check(_p.collision_damage(3, 20) == 2, "(a unit with 3 HP of 20 still takes 2)")
	check(_p.collision_damage(2, 20) == 1 and _p.collision_damage(1, 20) == 0 and _p.collision_damage(0, 20) == 0, "but never lethal: it stops at 1 HP")
	m = await _setup(["u_gunnar", "u_jost"], [Vector2i(4, 3), Vector2i(2, 8)],
		[{"arch": _arch("Looter"), "pos": Vector2i(5, 3)}])
	_shove(m, 0, R)           # (6,3) is open, (7,3) is a pillar: it moves one, then hits the wall
	check(m.enemies[0].pos == Vector2i(6, 3) and m.enemies[0].hp == 18, "a wall behind cuts a Smite short and hurts: moved 1, took 2 (hp %d)" % m.enemies[0].hp)
	check(m.info_label.text.contains("back 1 tile; the Looter slams into the wall. The Looter takes 2 damage."), "and the map says so (%s)" % m.info_label.text)
	check(m.attacked_this_turn.has("u_gunnar") and not m.fought_units.has("u_gunnar"), "it spends the action, and still isn't a 'fight'")
	m.unit_positions["u_gunnar"] = Vector2i(5, 3)
	_shove(m, 0, R)           # now (7,3) is directly behind: nothing moves, but it still slams
	check(m.enemies[0].pos == Vector2i(6, 3) and m.enemies[0].hp == 16 and m.attacked_this_turn.has("u_gunnar"),
		"a wall right behind: no movement, but the slam still hurts and the action is spent (hp %d)" % m.enemies[0].hp)
	check(m.info_label.text.contains("but it cannot move; the Looter slams into the wall. The Looter takes 2 damage."), "(%s)" % m.info_label.text)
	# the map's edge, and a plain wall, are distinguished
	var path: Dictionary = m._push_path(Vector2i(21, 5), R, 2, "flying")
	check(path["dest"] == Vector2i(21, 5) and path["stopped_by"]["kind"] == "edge", "pushing off the grid is the edge")
	path = m._push_path(Vector2i(6, 3), R, 2, "infantry")
	check(path["stopped_by"]["kind"] == "wall" and path["dest"] == Vector2i(6, 3), "a pillar is a wall")
	path = m._push_path(Vector2i(8, 3), R, 2, "infantry")
	check(path["stopped_by"].is_empty() and path["dest"] == Vector2i(10, 3), "a clear run reports no obstacle")
	m.queue_free()
	await process_frame

	# a unit behind: both take their own tenth
	_reset()
	_make_smiter("u_gunnar")
	m = await _setup(["u_gunnar", "u_jost"], [Vector2i(4, 5), Vector2i(7, 5)], [{"arch": _arch("Looter"), "pos": Vector2i(5, 5)}])
	var jost_max: int = int(m.units[1].hp)
	var jost_expect: int = int(floor(jost_max / 10.0))
	m.unit_hp["u_jost"] = jost_max
	_shove(m, 0, R)
	check(m.enemies[0].pos == Vector2i(6, 5) and m.enemies[0].hp == 18, "a unit behind the target stops it; the target takes 2")
	check(int(m.unit_hp["u_jost"]) == jost_max - jost_expect, "and the unit it hits takes a tenth of ITS own max HP (%d of %d)" % [jost_expect, jost_max])
	check(m.info_label.text.contains("slams into Jost") and m.info_label.text.contains("The Looter takes 2 damage"), "(%s)" % m.info_label.text)
	check(m.unit_positions["u_jost"] == Vector2i(7, 5), "the blocker isn't moved")
	m.unit_positions["u_jost"] = Vector2i(6, 5)
	m.enemies[0].pos = Vector2i(5, 5)
	m.unit_hp["u_jost"] = jost_max
	_shove(m, 0, R)
	check(m.enemies[0].pos == Vector2i(5, 5) and m.enemies[0].hp == 16 and int(m.unit_hp["u_jost"]) == jost_max - jost_expect,
		"one directly behind: nobody moves, both are hurt")
	check(not m.struck_units.has("u_jost"), "a friend's slam isn't an enemy strike: Jost can still earn a no-hit map")
	# a defeated enemy no longer blocks
	m.unit_positions["u_jost"] = Vector2i(2, 8)
	m.enemies.append({"inst_id": 99, "kind": "mook", "archetype": _arch("Corpse"), "pos": Vector2i(6, 5), "hp": 0, "max_hp": 20, "defeated": true, "token": {}})
	m.enemies[0].hp = 20
	m.enemies[0].pos = Vector2i(5, 5)
	_shove(m, 0, R)
	check(m.enemies[0].pos == Vector2i(7, 5) and m.enemies[0].hp == 20, "a defeated enemy's tile doesn't block (and nothing is hurt)")
	m.queue_free()
	await process_frame

	# never lethal, rounding, and small targets
	_reset()
	_make_smiter("u_gunnar")
	m = await _setup(["u_gunnar"], [Vector2i(5, 3)], [
		{"arch": _arch("A", {"hp": 20}), "pos": Vector2i(6, 3)},
		{"arch": _arch("B", {"hp": 9}), "pos": Vector2i(6, 4)},
		{"arch": _arch("C", {"hp": 25}), "pos": Vector2i(6, 2)}])
	m.enemies[0].hp = 2
	_shove(m, 0, R)
	check(m.enemies[0].hp == 1 and not m.enemies[0].defeated and m.info_label.text.contains("takes 1 damage"), "a slam never kills: 2 HP of 20 leaves 1 (%s)" % m.info_label.text)
	m.unit_positions["u_gunnar"] = Vector2i(5, 4)
	m.attacked_this_turn.clear()
	_shove(m, 0, R)
	check(m.enemies[1].hp == 9 and not m.info_label.text.contains("takes") and m.info_label.text.contains("slams into the wall"), "9 max HP: a tenth rounds down to nothing (%s)" % m.info_label.text)
	m.unit_positions["u_gunnar"] = Vector2i(5, 2)
	m.attacked_this_turn.clear()
	_shove(m, 0, R)
	check(m.enemies[2].hp == 23, "25 max HP: 2, not 2.5 (hp %d)" % m.enemies[2].hp)
	m.enemies[0].hp = 1
	m.unit_positions["u_gunnar"] = Vector2i(5, 3)
	m.attacked_this_turn.clear()
	_shove(m, 0, R)
	check(m.enemies[0].hp == 1 and not m.enemies[0].defeated, "a unit already at 1 HP takes nothing")
	m.queue_free()
	await process_frame

	# two enemies of the same name are reported separately
	_reset()
	_make_smiter("u_gunnar")
	m = await _setup(["u_gunnar"], [Vector2i(4, 5)], [{"arch": _arch("Looter"), "pos": Vector2i(5, 5)}, {"arch": _arch("Looter"), "pos": Vector2i(7, 5)}])
	_shove(m, 0, R)
	check(m.enemies[1].hp == 18 and m.enemies[0].hp == 18 and m.enemies[0].pos == Vector2i(6, 5), "pushed into a second enemy: both are hurt")
	check(m.info_label.text.count("takes 2 damage") == 2, "and both are reported (%s)" % m.info_label.text)
	m.queue_free()
	await process_frame

	# pushing an enemy into a boss hurts the boss, and the boss is then no longer single combat
	_reset()
	_make_smiter("u_gunnar")
	m = await _setup(["u_gunnar", "u_jost"], [Vector2i(4, 5), Vector2i(2, 8)], [{"arch": _arch("Looter"), "pos": Vector2i(5, 5)}, {"arch": _arch("Captain", {"hp": 30}), "pos": Vector2i(7, 5), "kind": "boss"}])
	_shove(m, 0, R)
	check(m.enemies[1].hp == 27 and m.enemies[1].pos == Vector2i(7, 5), "a boss that is hit by a slam takes a tenth and holds its tile")
	check(m.enemies[1].get("hit_by", {}).has("u_gunnar"), "and counts as damaged by the pusher")
	m.enemies[1].hp = 1
	m._note_exchange("u_jost", m.enemies[1], {"strikes": [], "atk_strikes": 1, "def_strikes": 0}, 2)
	check(m.enemies[1].hit_by.size() == 2, "so a later killer doesn't get a lone boss kill from it")
	m.queue_free()
	await process_frame

	# an ally pushed into a wall
	_reset()
	m = await _setup(["u_gunnar", "u_jost"], [Vector2i(5, 3), Vector2i(6, 3)], [{"arch": _arch("Looter"), "pos": Vector2i(15, 5)}])
	var jmax: int = int(m.units[1].hp)
	m.unit_hp["u_jost"] = jmax
	_shove(m, 0, R)
	check(m.unit_positions["u_jost"] == Vector2i(6, 3) and int(m.unit_hp["u_jost"]) == jmax - int(floor(jmax / 10.0)), "a friend shoved into a pillar is slammed too (hp %d of %d)" % [int(m.unit_hp["u_jost"]), jmax])
	m.unit_hp["u_jost"] = 1
	m.attacked_this_turn.clear()
	_shove(m, 0, R)
	check(int(m.unit_hp["u_jost"]) == 1 and m.unit_positions.has("u_jost"), "and a friend at 1 HP is not killed")
	m.queue_free()
	await process_frame

	# ---- bosses and armor
	_reset()
	_make_smiter("u_gunnar")
	m = await _setup(["u_gunnar"], [Vector2i(5, 5)], [{"arch": _arch("Captain"), "pos": Vector2i(6, 5), "kind": "boss"}])
	_shove(m, 0, R)
	check(m.enemies[0].pos == Vector2i(6, 5) and m.info_label.text.contains("holds its ground") and not m.attacked_this_turn.has("u_gunnar"), "a boss is never pushed (%s)" % m.info_label.text)
	check(m.info_label.text.begins_with("The Captain"), "(and the message is capitalised sensibly)")
	m.queue_free()
	await process_frame

	_reset()
	m = await _setup(["u_gunnar"], [Vector2i(5, 5)], [{"arch": _arch("Knight", {"movement_type": "armor"}), "pos": Vector2i(6, 5)}])
	_shove(m, 0, R)
	check(m.enemies[0].pos == Vector2i(6, 5) and m.info_label.text.contains("too heavy") and not m.attacked_this_turn.has("u_gunnar"), "a plain Shove can't move armor (%s)" % m.info_label.text)
	m.queue_free()
	await process_frame
	_reset()
	_make_smiter("u_gunnar")
	m = await _setup(["u_gunnar"], [Vector2i(5, 5)], [{"arch": _arch("Knight", {"movement_type": "armor"}), "pos": Vector2i(6, 5)}])
	_shove(m, 0, R)
	check(m.enemies[0].pos == Vector2i(7, 5) and m.info_label.text.contains("too heavy to go further") and m.enemies[0].hp == 20, "Smite moves armor one tile, and resisting isn't a collision (%s)" % m.info_label.text)
	m.enemies[0].pos = Vector2i(6, 3)
	m.unit_positions["u_gunnar"] = Vector2i(5, 3)
	m.attacked_this_turn.clear()
	_shove(m, 0, R)
	check(m.enemies[0].pos == Vector2i(6, 3) and m.enemies[0].hp == 18, "but armor against a wall still slams (it moves 0 and takes 2)")
	m.queue_free()
	await process_frame

	# ---- pushing a friend
	_reset()
	m = await _setup(["u_gunnar", "u_jost"], [Vector2i(5, 5), Vector2i(6, 5)], [{"arch": _arch("Looter"), "pos": Vector2i(15, 5)}])
	m.moved_this_turn["u_jost"] = false
	_shove(m, 0, R)
	check(m.unit_positions["u_jost"] == Vector2i(7, 5) and m.info_label.text.contains("Gunnar shoves Jost back 1 tile."), "an ally can be pushed too (%s)" % m.info_label.text)
	check(m.unit_tokens["u_jost"].container.position == Vector2(7 * m.CELL_SIZE, 5 * m.CELL_SIZE), "its token follows")
	check(not m.moved_this_turn.get("u_jost", false), "a pushed ally keeps its own move")
	m.queue_free()
	await process_frame

	# ---- input: [S], then an arrow key or a click
	_reset()
	m = await _setup(["u_gunnar", "u_jost"], [Vector2i(5, 5), Vector2i(2, 8)], [{"arch": _arch("Looter"), "pos": Vector2i(6, 5)}])
	m.selected_unit_index = 0
	_key(m, KEY_S)
	check(m._shove_mode and m.info_label.text.contains("push which way"), "S asks which way")
	_key(m, KEY_RIGHT)
	check(not m._shove_mode and m.enemies[0].pos == Vector2i(7, 5), "an arrow key then pushes")
	m.attacked_this_turn.clear()
	m.enemies[0].pos = Vector2i(6, 5)
	_key(m, KEY_S)
	_key(m, KEY_F)
	check(not m._shove_mode and m.enemies[0].pos == Vector2i(6, 5) and m.info_label.text.contains("cancelled") and not m.attacked_this_turn.has("u_gunnar"), "any other key cancels")
	_key(m, KEY_S)
	_key(m, KEY_S)
	check(not m._shove_mode, "S twice cancels too")
	_key(m, KEY_S)
	m._shove_click(Vector2i(6, 5))
	check(not m._shove_mode and m.enemies[0].pos == Vector2i(7, 5), "clicking the adjacent unit pushes it")
	m.attacked_this_turn.clear()
	m.enemies[0].pos = Vector2i(6, 5)
	_key(m, KEY_S)
	m._shove_click(Vector2i(10, 10))
	check(not m._shove_mode and m.enemies[0].pos == Vector2i(6, 5), "clicking elsewhere cancels")
	m.selected_unit_index = 1
	_key(m, KEY_S)
	check(not m._shove_mode and m.info_label.text.contains("Jost has no Shove action"), "S on a unit without the action says so, and starts nothing")
	m.selected_unit_index = 0
	m.attacked_this_turn["u_gunnar"] = true
	_key(m, KEY_S)
	check(not m._shove_mode and m.info_label.text.contains("already acted"), "S after acting says so")
	m._update_status_label()
	m.queue_free()
	await process_frame

	# ---- after a win only the way out works, S is the support link (unchanged)
	_reset()
	m = await _setup(["u_gunnar"], [Vector2i(5, 5)], [])
	m.map_won = true
	_key(m, KEY_S)
	check(not m._shove_mode, "after a win, S never starts a shove")
	m.queue_free()
	await process_frame

	# ---- a Housecarl smites from the start
	_reset()
	_p.ensure("u_jost")
	_gs.progression["u_jost"]["class_id"] = "cls_housecarl"
	m = await _setup(["u_jost"], [Vector2i(5, 5)], [{"arch": _arch("Looter"), "pos": Vector2i(6, 5)}])
	_shove(m, 0, R)
	check(m.enemies[0].pos == Vector2i(8, 5) and m.info_label.text.contains("Jost smites the Looter"), "a Housecarl smites without certifying (%s)" % m.info_label.text)
	m.queue_free()
	await process_frame
