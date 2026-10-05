extends SceneTree
## Headless checks for deed telemetry on the battle map: the boss kill, the solo
## hold and the no-hit map, and what resets or denies them.
## Run from the repo root:
##   godot --headless --path game --script res://tests/test_deeds.gd
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

func _arch(name: String, art: String, over := {}) -> Dictionary:
	var d := {"enemy_id": "ea_t_" + name, "name": name, "weapon_art": art, "weapon_tier": "basic", "movement_type": "infantry",
		"level": 5, "hp": 500, "str": 1, "mag": 0, "dex": 1, "spd": 1, "lck": 0, "def": 0, "res": 0}
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

func _attack(m: Node, idx: int) -> void:
	m.selected_unit_index = idx
	m.attacked_this_turn.clear()
	m._attack_enemy()

func _run() -> void:
	# ---- boss kill: the killing blow on a boss only this unit damaged
	_reset()
	var m: Node = await _setup(["u_jost"], [Vector2i(5, 5)], [{"arch": _arch("Captain", "sword", {"hp": 1}), "pos": Vector2i(6, 5), "kind": "boss"}])
	m.enemies[0].hp = 1
	_attack(m, 0)
	check(m.enemies[0].defeated and _p.has_deed("u_jost", "ep_bosskill"), "a lone unit felling a boss earns the boss-kill deed")
	check(m.info_label.text.contains("Jost earns a deed: boss kill ('Slayer of')."), "and the map announces it (%s)" % m.info_label.text.replace("\n", " / "))
	m.queue_free()
	await process_frame

	_reset()
	m = await _setup(["u_jost", "u_ricberta"], [Vector2i(5, 5), Vector2i(7, 5)], [{"arch": _arch("Captain", "sword", {"hp": 500}), "pos": Vector2i(6, 5), "kind": "boss"}])
	_attack(m, 1)                       # Ricberta (lance, reach 1) hits first...
	m.enemies[0].hp = 1                  # ...then Jost finishes it
	_attack(m, 0)
	check(m.enemies[0].defeated and not _p.has_deed("u_jost", "ep_bosskill"), "no deed if someone else damaged the boss first (not single combat)")
	check(not _p.has_deed("u_ricberta", "ep_bosskill"), "...and the first attacker didn't land the killing blow either")
	m.queue_free()
	await process_frame

	_reset()
	m = await _setup(["u_jost"], [Vector2i(5, 5)], [{"arch": _arch("Looter", "sword", {"hp": 1}), "pos": Vector2i(6, 5), "kind": "mook"}])
	m.enemies[0].hp = 1
	_attack(m, 0)
	check(m.enemies[0].defeated and not _p.has_deed("u_jost", "ep_bosskill"), "killing a mook isn't a boss kill")
	m.queue_free()
	await process_frame

	# a boss that dies to the counter in the enemy phase still counts for the lone defender
	_reset()
	m = await _setup(["u_jost"], [Vector2i(5, 5)], [{"arch": _arch("Captain", "sword", {"hp": 1, "str": 2}), "pos": Vector2i(6, 5), "kind": "boss"}])
	m.enemies[0].hp = 1
	m.enemy_phase_enabled = true
	m._enemy_phase()
	check(m.enemies[0].defeated and _p.has_deed("u_jost", "ep_bosskill"), "a boss felled by one unit's counter is a boss kill")
	check(" ".join(m.enemy_log).contains("Jost earns a deed: boss kill"), "(announced in the enemy log)")
	m.queue_free()
	await process_frame

	# repeats aren't re-announced
	_reset()
	_p.record_deed("u_jost", "ep_bosskill")
	m = await _setup(["u_jost"], [Vector2i(5, 5)], [{"arch": _arch("Captain", "sword", {"hp": 1}), "pos": Vector2i(6, 5), "kind": "boss"}])
	m.enemies[0].hp = 1
	_attack(m, 0)
	check(not m.info_label.text.contains("earns a deed") and _p.deeds("u_jost")["ep_bosskill"] == 2, "a repeat is counted but not announced")
	m.queue_free()
	await process_frame

	# ---- no-hit map
	_reset()
	m = await _setup(["u_jost", "u_ricberta", "u_sigrun"], [Vector2i(5, 5), Vector2i(5, 8), Vector2i(2, 2)],
		[{"arch": _arch("Dummy", "sword", {"weapon_tier": "worn", "dex": 0, "spd": 0, "str": 0, "hp": 500}), "pos": Vector2i(6, 5)}])
	_attack(m, 0)                        # Jost fights; the dummy's counter might hit -- force it not to
	m.struck_units.clear()
	check(m.fought_units.has("u_jost") and not m.fought_units.has("u_ricberta"), "fighting is tracked per unit")
	m.struck_units["u_ricberta"] = true
	m.fought_units["u_ricberta"] = true  # Ricberta fought but was struck
	m.map_won = true
	await process_frame
	check(_p.has_deed("u_jost", "ep_nohit"), "a unit that fought and was never struck earns the no-hit deed on a win")
	check(not _p.has_deed("u_ricberta", "ep_nohit"), "a unit that was struck doesn't")
	check(not _p.has_deed("u_sigrun", "ep_nohit"), "a unit that never fought doesn't (no hiding in a corner)")
	check(m.status_label.text.contains("Jost earns a deed: no hit map ('Untouched')."), "the win line announces it (%s)" % m.status_label.text.replace("\n", " / "))
	m.queue_free()
	await process_frame

	# being hit by an enemy marks the unit struck
	_reset()
	m = await _setup(["u_jost"], [Vector2i(5, 5)], [{"arch": _arch("Brute", "sword", {"str": 30, "dex": 90, "hp": 500}), "pos": Vector2i(6, 5)}])
	m.unit_hp["u_jost"] = 500          # survives the blow, so he counters
	m.enemy_phase_enabled = true
	m._enemy_phase()
	check(m.struck_units.has("u_jost") and m.fought_units.has("u_jost"), "an enemy strike that lands marks the unit struck (and its counter marks it as having fought)")
	m.queue_free()
	await process_frame
	# a miss doesn't
	_reset()
	m = await _setup(["u_jost"], [Vector2i(5, 5)], [{"arch": _arch("Whiffer", "sword", {"dex": 0, "hp": 500}), "pos": Vector2i(6, 5)}])
	m.units[0]["spd"] = 200      # untouchable
	m.enemy_phase_enabled = true
	m._enemy_phase()
	check(not m.struck_units.has("u_jost"), "a miss doesn't count as being struck")
	m.queue_free()
	await process_frame
	# a replayed win can't re-earn: counts but doesn't announce twice
	_reset()
	_p.record_deed("u_jost", "ep_nohit")
	m = await _setup(["u_jost"], [Vector2i(5, 5)], [])
	m.fought_units["u_jost"] = true
	m.map_won = true
	await process_frame
	check(_p.deeds("u_jost")["ep_nohit"] == 2 and not m.status_label.text.contains("earns a deed"), "a repeat no-hit isn't announced again")
	m.queue_free()
	await process_frame

	# ---- solo hold
	_reset()
	var tile := Vector2i(5, 5)
	m = await _setup(["u_jost"], [tile], [{"arch": _arch("Looter", "sword", {"hp": 5000, "dex": 0}), "pos": Vector2i(6, 5)}])
	m.enemy_phase_enabled = true
	m._enemy_phase()
	check(m.hold_streak["u_jost"]["phases"] == 1 and not _p.has_deed("u_jost", "ep_solohold"), "one phase held alone and attacked: streak 1, no deed yet")
	m._enemy_phase()
	check(m.hold_streak["u_jost"]["phases"] == 2 and not _p.has_deed("u_jost", "ep_solohold"), "two phases: streak 2")
	m._enemy_phase()
	check(_p.has_deed("u_jost", "ep_solohold") and " ".join(m.enemy_log).contains("Jost earns a deed: solo hold ('of the Ford')."), "the third phase earns the solo-hold deed, announced in the log (%s)" % str(m.enemy_log))
	# an ally within 2 tiles resets it
	_reset()
	m.queue_free()
	await process_frame
	m = await _setup(["u_jost", "u_ricberta"], [tile, Vector2i(5, 7)], [{"arch": _arch("Looter", "sword", {"hp": 5000, "dex": 0}), "pos": Vector2i(6, 5)}])
	m.enemy_phase_enabled = true
	m._enemy_phase(); m._enemy_phase()
	check(not m.hold_streak.has("u_jost"), "an ally two tiles away means he isn't alone: no streak")
	m.unit_positions["u_ricberta"] = Vector2i(5, 8)      # three tiles away
	m._enemy_phase()
	check(m.hold_streak.has("u_jost") and m.hold_streak["u_jost"]["phases"] == 1, "once the ally is 3+ tiles off the run starts at 1")
	m.queue_free()
	await process_frame
	# moving resets it
	_reset()
	m = await _setup(["u_jost"], [tile], [{"arch": _arch("Looter", "sword", {"hp": 5000, "dex": 0}), "pos": Vector2i(6, 5)}])
	m.enemy_phase_enabled = true
	m._enemy_phase(); m._enemy_phase()
	m.unit_positions["u_jost"] = Vector2i(5, 4)          # steps aside, still adjacent to the enemy's reach
	m._enemy_phase()
	check(m.hold_streak["u_jost"]["tile"] == Vector2i(5, 4) and m.hold_streak["u_jost"]["phases"] == 1 and not _p.has_deed("u_jost", "ep_solohold"), "changing tile restarts the run")
	m.queue_free()
	await process_frame
	# not attacked resets it
	_reset()
	m = await _setup(["u_jost"], [tile], [{"arch": _arch("Looter", "sword", {"hp": 5000, "dex": 0}), "pos": Vector2i(6, 5)}])
	m.enemy_phase_enabled = true
	m._enemy_phase(); m._enemy_phase()
	m.enemies[0].pos = Vector2i(15, 9)                   # the enemy is far away and won't reach him
	m._enemy_phase()
	check(not m.hold_streak.has("u_jost") and not _p.has_deed("u_jost", "ep_solohold"), "a phase with no attack on him breaks the run")
	m.queue_free()
	await process_frame
	# the prologue records nothing
	_reset()
	var f00: Node = load("res://scenes/map_f00.tscn").instantiate()
	root.add_child(f00)
	await process_frame
	check(f00._earn_deed("pu_sargath", "ep_nohit", "Sargath").is_empty() and _gs.deeds.is_empty(), "the prologue roster earns no deeds")
	f00.queue_free()
	await process_frame
