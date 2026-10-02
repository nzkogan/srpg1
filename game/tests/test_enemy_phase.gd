extends SceneTree
## Headless checks for the enemy phase: who moves, who attacks whom, counters,
## deaths and defeat, driven on map_d05 with a hand-built roster and enemies so
## the outcome never depends on the production scene's contents.
## Run from the repo root:
##   godot --headless --path game --script res://tests/test_enemy_phase.gd
## Exits 0 if every check passes, 1 otherwise.

var _failures: int = 0
var _checks: int = 0
var _w: Dictionary = {}

func check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: ", label)

func _initialize() -> void:
	await process_frame
	await _run()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)

func _unit(pid: String, art, over := {}) -> Dictionary:
	var arts: Array = [art] if art != null else []
	var d := {"punit_id": pid, "name": pid.capitalize(), "hp": 30, "str": 8, "mag": 4, "dex": 60, "spd": 8, "lck": 4,
		"def": 4, "res": 3, "weapon_art": art, "arts": arts, "movement_type": "infantry", "move": 5, "what_they_do": "unarmed"}
	d.merge(over, true)
	return d

func _arch(name: String, art: String, over := {}) -> Dictionary:
	var d := {"enemy_id": "ea_t_" + name, "name": name, "weapon_art": art, "weapon_tier": "basic", "movement_type": "infantry",
		"hp": 30, "str": 8, "mag": 0, "dex": 60, "spd": 8, "lck": 4, "def": 4, "res": 3}
	d.merge(over, true)
	return d

## A fresh d05 with the roster and enemies replaced by exactly what's given.
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
	map.unit_tokens.clear()
	map.unit_positions.clear()
	map.unit_hp.clear()
	map.units = unit_rows
	for i in unit_rows.size():
		map.unit_positions[unit_rows[i]["punit_id"]] = positions[i]
		map.unit_hp[unit_rows[i]["punit_id"]] = int(unit_rows[i]["hp"])
	var next_id := 0
	for spec in enemy_specs:
		next_id = map._spawn_enemy_instance(spec["arch"], spec["pos"], spec.get("kind", "mook"), next_id)
	map.rng_override = _rng(1)
	return map

func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r

func _run() -> void:
	for row in root.get_node("Canon").get_table("weapons"):
		_w[row["weapon_id"]] = row

	# ---- an enemy beside a unit attacks it and gets countered
	var m: Node = await _setup([_unit("t_a", "sword")], [Vector2i(5, 5)],
		[{"arch": _arch("Looter", "axe"), "pos": Vector2i(6, 5)}])
	var enemy: Dictionary = m.enemies[0]
	m._enemy_phase()
	check(m.unit_hp["t_a"] < 30, "an adjacent enemy hurts the unit it attacks (hp %d)" % m.unit_hp["t_a"])
	check(enemy.hp < 30, "...and the unit counters (enemy hp %d)" % enemy.hp)
	check(enemy.pos == Vector2i(6, 5), "an enemy already in reach doesn't move")
	check(m.enemy_log.size() >= 1 and " ".join(m.enemy_log).contains("counters"), "the log records the counter: %s" % str(m.enemy_log))
	check(m.info_label != null, "(labels exist)")
	m.queue_free()
	await process_frame

	# ---- the phase can be switched off, and does nothing before turn 1 ends
	m = await _setup([_unit("t_a", "sword")], [Vector2i(5, 5)], [{"arch": _arch("Looter", "axe"), "pos": Vector2i(6, 5)}])
	m.enemy_phase_enabled = false
	m._enemy_phase()
	check(m.unit_hp["t_a"] == 30, "enemy_phase_enabled = false: nobody attacks")
	m.enemy_phase_enabled = true
	check(m.turn == 0, "(turn 0 is the deploy screen)")
	m._next_turn()    # begins turn 1: no enemy phase yet
	check(m.unit_hp["t_a"] == 30 and m.enemy_log.is_empty(), "starting turn 1 does not trigger an enemy phase")
	m._next_turn()    # ends turn 1: enemies act
	check(m.unit_hp["t_a"] < 30 and not m.enemy_log.is_empty(), "ending a played turn triggers it")
	check(m.info_label.text.contains("Enemy phase:"), "the info label shows what the enemies did")
	m.queue_free()
	await process_frame

	# ---- a far enemy walks toward the nearest unit, within its move, onto a free tile
	m = await _setup([_unit("t_a", "sword"), _unit("t_b", "sword")], [Vector2i(2, 5), Vector2i(2, 7)],
		[{"arch": _arch("Looter", "axe"), "pos": Vector2i(18, 5)}])
	enemy = m.enemies[0]
	var before: int = m._distance(enemy.pos, Vector2i(2, 5))
	m._enemy_phase()
	var moved: int = m._distance(Vector2i(18, 5), enemy.pos)
	check(moved > 0 and moved <= 5, "it advances, no further than its infantry move of 5 (moved %d)" % moved)
	check(m._distance(enemy.pos, Vector2i(2, 5)) < before, "...closer to the nearest unit")
	check(m.unit_hp["t_a"] == 30 and m.unit_hp["t_b"] == 30, "nothing in reach, so no attack")
	check(enemy.token["container"].position == Vector2(enemy.pos.x * 32, enemy.pos.y * 32), "its token moved with it")
	m.queue_free()
	await process_frame

	# ---- a boss holds its tile
	m = await _setup([_unit("t_a", "sword")], [Vector2i(2, 5)], [{"arch": _arch("Warden", "axe"), "pos": Vector2i(15, 5), "kind": "boss"}])
	m._enemy_phase()
	check(m.enemies[0].pos == Vector2i(15, 5), "a boss out of reach stays put")
	m.queue_free()
	await process_frame
	m = await _setup([_unit("t_a", "sword")], [Vector2i(14, 5)], [{"arch": _arch("Warden", "axe"), "pos": Vector2i(15, 5), "kind": "boss"}])
	m._enemy_phase()
	check(m.unit_hp["t_a"] < 30 and m.enemies[0].pos == Vector2i(15, 5), "...but strikes what is in reach from where it stands")
	m.queue_free()
	await process_frame

	# ---- an enemy picks the matchup the triangle favours (axe beats lance)
	m = await _setup([_unit("t_sword", "sword"), _unit("t_lance", "lance")], [Vector2i(5, 4), Vector2i(5, 6)],
		[{"arch": _arch("Looter", "axe"), "pos": Vector2i(6, 5)}])
	m._enemy_phase()
	check(m.unit_hp["t_lance"] < 30 and m.unit_hp["t_sword"] == 30, "the axe goes for the lance, not the sword (lance %d, sword %d)" % [m.unit_hp["t_lance"], m.unit_hp["t_sword"]])
	m.queue_free()
	await process_frame
	# and a sword enemy goes for the axe
	m = await _setup([_unit("t_lance", "lance"), _unit("t_axe", "axe")], [Vector2i(5, 4), Vector2i(5, 6)],
		[{"arch": _arch("Privateer", "sword"), "pos": Vector2i(6, 5)}])
	m._enemy_phase()
	check(m.unit_hp["t_axe"] < 30 and m.unit_hp["t_lance"] == 30, "the sword goes for the axe, not the lance")
	m.queue_free()
	await process_frame

	# ---- it prefers a kill
	m = await _setup([_unit("t_a", "sword", {"hp": 90}), _unit("t_b", "sword", {"hp": 90})], [Vector2i(5, 4), Vector2i(5, 6)],
		[{"arch": _arch("Looter", "axe", {"str": 30}), "pos": Vector2i(6, 5)}])
	m.unit_hp["t_b"] = 2
	m._enemy_phase()
	check(not m.unit_positions.has("t_b") and m.unit_positions.has("t_a"), "it finishes the wounded unit")
	check(" ".join(m.enemy_log).contains("falls"), "and the log says so")
	m.queue_free()
	await process_frame

	# ---- losing the last unit is a defeat; _next_turn stops there
	m = await _setup([_unit("t_a", "sword", {"hp": 1})], [Vector2i(5, 5)], [{"arch": _arch("Looter", "axe", {"str": 30}), "pos": Vector2i(6, 5)}])
	m._next_turn(); m._next_turn()
	check(m.map_lost and m.status_label.text.contains("DEFEAT"), "the last unit falling is a defeat")
	check(m.turn == 1, "and the turn counter stops (turn %d)" % m.turn)
	m.queue_free()
	await process_frame

	# ---- the counter can kill the enemy
	m = await _setup([_unit("t_a", "sword", {"str": 30})], [Vector2i(5, 5)], [{"arch": _arch("Looter", "axe"), "pos": Vector2i(6, 5)}])
	enemy = m.enemies[0]
	enemy.hp = 1
	m._enemy_phase()
	check(enemy.defeated and enemy.token.is_empty(), "an enemy that dies to the counter is removed")
	check(" ".join(m.enemy_log).contains("The Looter falls"), "...and the log says so")
	m.queue_free()
	await process_frame

	# ---- an unarmed unit can't counter; a defended boss death wins a 'defend' map
	m = await _setup([_unit("t_a", null)], [Vector2i(5, 5)], [{"arch": _arch("Looter", "axe"), "pos": Vector2i(6, 5)}])
	m._enemy_phase()
	check(m.unit_hp["t_a"] < 30 and m.enemies[0].hp == 30, "an unarmed unit takes the hit and can't answer")
	m.queue_free()
	await process_frame

	# ---- a range-2 archer doesn't wade in: it shoots from two tiles and isn't countered by a sword
	m = await _setup([_unit("t_a", "sword")], [Vector2i(5, 5)], [{"arch": _arch("Archer", "bow"), "pos": Vector2i(9, 5)}])
	enemy = m.enemies[0]
	m._enemy_phase()
	check(m._distance(enemy.pos, Vector2i(5, 5)) == 2, "an archer stops at its range of 2 (at %s)" % str(enemy.pos))
	check(m.unit_hp["t_a"] < 30 and enemy.hp == 30, "it shoots and the sword can't reach back")
	m.queue_free()
	await process_frame

	# ---- enemies never end on an occupied tile
	m = await _setup([_unit("t_a", "sword")], [Vector2i(2, 5)],
		[{"arch": _arch("Looter", "axe"), "pos": Vector2i(8, 5)}, {"arch": _arch("Looter2", "axe"), "pos": Vector2i(9, 5)}])
	m._enemy_phase()
	var tiles := {}
	for e in m.enemies:
		tiles[e.pos] = true
	check(tiles.size() == 2 and not tiles.has(m.unit_positions["t_a"]), "no two enemies (or an enemy and a unit) share a tile")
	m.queue_free()
	await process_frame

	# ---- two enemies that want the same tile don't stack
	m = await _setup([_unit("t_a", "sword", {"hp": 200, "str": 1})], [Vector2i(5, 5)],   # weak counters: the first enemy survives
		[{"arch": _arch("Looter", "axe", {"hp": 200}), "pos": Vector2i(6, 5)}, {"arch": _arch("Looter2", "axe", {"hp": 200}), "pos": Vector2i(7, 5)}])
	m._enemy_phase()
	check(m.enemies[0].pos != m.enemies[1].pos, "the second enemy doesn't pile onto the first's tile (%s vs %s)" % [m.enemies[0].pos, m.enemies[1].pos])
	check(m._distance(m.enemies[1].pos, Vector2i(5, 5)) == 1, "it finds another tile beside the unit")
	m.queue_free()
	await process_frame

	# ---- with equal damage on offer, it picks the target that can't hit back
	m = await _setup([_unit("t_armed", "sword"), _unit("t_unarmed", null)], [Vector2i(5, 4), Vector2i(5, 6)],
		[{"arch": _arch("Brawler", "brawl"), "pos": Vector2i(6, 5)}])
	m._enemy_phase()
	check(m.unit_hp["t_unarmed"] < 30 and m.unit_hp["t_armed"] == 30, "it picks the unit that can't counter (armed %d, unarmed %d)" % [m.unit_hp["t_armed"], m.unit_hp["t_unarmed"]])
	m.queue_free()
	await process_frame

	# ---- support makes the defender harder to hit (avoid) in the enemy's own forecast
	var gs: Node = root.get_node("GameState")
	gs.support_ranks.clear()
	m = await _setup([_unit("u_jost", "axe"), _unit("u_ricberta", "lance")], [Vector2i(5, 5), Vector2i(5, 6)],
		[{"arch": _arch("Looter", "axe", {"dex": 8}), "pos": Vector2i(6, 5)}])   # axe vs axe: neutral, hit well under 100
	var plain_hit: int = Combat_forecast(m, "u_jost")
	gs.support_ranks["sup_jost_ricberta"] = "A"
	var backed_hit: int = Combat_forecast(m, "u_jost")
	check(backed_hit == plain_hit - 7, "an A-rank partner nearby lowers the enemy's hit by 7 (%d -> %d)" % [plain_hit, backed_hit])
	gs.support_ranks.clear()
	m.queue_free()
	await process_frame

func Combat_forecast(m: Node, pid: String) -> int:
	var combat: GDScript = load("res://scripts/combat.gd")
	var enemy: Dictionary = m.enemies[0]
	var defender: Dictionary = m._combatant_for_unit(pid)
	var fc: Dictionary = combat.forecast(enemy.archetype.duplicate(), defender, m._enemy_weapon(enemy), m._weapon_for_unit(defender), 1)
	return int(fc["atk"]["hit"])
