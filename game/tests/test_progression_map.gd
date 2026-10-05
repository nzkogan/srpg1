extends SceneTree
## Headless checks for progression on the battle map: current stats and abilities
## in the roster rows, EXP and level-ups from fights (attacks and counters), HP
## gained, income and class unlocks on a win, and the forecast's level row.
## Run from the repo root:
##   godot --headless --path game --script res://tests/test_progression_map.gd
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
	_gs.support_ranks.clear(); _gs.support_points.clear(); _gs.support_settled_maps.clear(); _gs.support_recent.clear()

func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r

func _arch(name: String, art: String, over := {}) -> Dictionary:
	var d := {"enemy_id": "ea_t_" + name, "name": name, "weapon_art": art, "weapon_tier": "basic", "movement_type": "infantry",
		"level": 5, "hp": 400, "str": 1, "mag": 0, "dex": 1, "spd": 1, "lck": 0, "def": 0, "res": 0}
	d.merge(over, true)
	return d

## d05 with the roster rebuilt from real units (so stats/levels come from Progression) and chosen enemies.
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
	map.rng_override = _rng(1)
	return map

func _run() -> void:
	# ---- roster rows carry Progression's CURRENT stats, level and abilities
	_reset()
	_p.state("u_jost")
	_gs.progression["u_jost"]["gains"]["str"] = 4
	_gs.progression["u_jost"]["level"] = 9
	var m: Node = await _setup(["u_jost"], [Vector2i(5, 5)], [])
	var jost: Dictionary = m.units[0]
	check(jost["str"] == 8 + 4 and jost["level"] == 9, "the map builds Jost from his progression (Str 12, level 9)")
	check(jost["abilities"].size() == _p.slots("u_jost") and jost["abilities"][0]["ability_id"] == "ab_focus_axe", "his abilities ride on the row")
	check(m.unit_hp["u_jost"] == jost["hp"], "starting HP is his current max HP")
	var combatant: Dictionary = m._combatant_for_unit("u_jost")
	check(combatant["cur_hp"] == jost["hp"] and combatant["max_hp"] == jost["hp"], "the combatant carries cur/max HP for the HP conditions")
	m.unit_hp["u_jost"] = 3
	check(m._combatant_for_unit("u_jost")["cur_hp"] == 3, "...kept live")
	m.queue_free()
	await process_frame

	# ---- late joiner on a map: Rinsa arrives into a strong squad already caught up
	_reset()
	_p.state("u_dietmar"); _p.state("u_torvald")        # a level-15 squad
	m = await _setup(["u_rinsa"], [Vector2i(5, 5)], [])
	check(m.units[0]["level"] == 12, "a level-5 Rinsa is deployed at 12 (squad median 15 - 3)")
	m.queue_free()
	await process_frame

	# ---- an attack earns EXP; enough EXP levels the unit and raises HP
	_reset()
	m = await _setup(["u_jost"], [Vector2i(5, 5)], [{"arch": _arch("Dummy", "sword", {"weapon_tier": "worn"}), "pos": Vector2i(6, 5)}])   # worn: its counters can't hurt
	m.selected_unit_index = 0
	var level_before: int = _p.level("u_jost")
	var exp_before: int = _p.exp_of("u_jost")
	m._attack_enemy()
	check(m.info_label.text.contains("Jost gains") and m.info_label.text.contains("EXP."), "an attack reports the EXP gained (%s)" % m.info_label.text.replace("\n", " / "))
	check(_p.exp_of("u_jost") > exp_before, "EXP is banked in Progression")
	# a level-up
	_gs.progression["u_jost"]["exp"] = 95
	m.attacked_this_turn.clear()
	var hp_before: int = m.unit_hp["u_jost"]
	var max_before: int = m.units[0]["hp"]
	m._attack_enemy()
	check(_p.level("u_jost") == level_before + 1 and m.info_label.text.contains("Jost reaches level %d!" % (level_before + 1)), "crossing 100 EXP levels him up and says so (%s)" % m.info_label.text.replace("\n", " / "))
	check(m.units[0]["level"] == level_before + 1, "the roster row follows")
	var hp_gain: int = m.units[0]["hp"] - max_before
	check(m.unit_hp["u_jost"] == hp_before + hp_gain, "an HP gain also raises current HP (+%d: %d -> %d)" % [hp_gain, hp_before, m.unit_hp["u_jost"]])
	m.queue_free()
	await process_frame

	# ---- a kill earns the kill bonus
	_reset()
	m = await _setup(["u_jost"], [Vector2i(5, 5)], [{"arch": _arch("Dummy", "sword", {"hp": 1}), "pos": Vector2i(6, 5)}])
	m.selected_unit_index = 0
	m.enemies[0].hp = 1
	m._attack_enemy()
	var exp_kill: int = _p.exp_of("u_jost") + (_p.level("u_jost") - 5) * 100
	check(m.enemies[0].defeated and exp_kill >= _p.fight_exp(5, 5, true), "defeating the enemy earns the kill bonus (%d EXP)" % exp_kill)
	m.queue_free()
	await process_frame

	# ---- a counter earns EXP too (and level-ups show in the enemy log)
	_reset()
	m = await _setup(["u_jost"], [Vector2i(5, 5)], [{"arch": _arch("Dummy", "sword", {"str": 3}), "pos": Vector2i(6, 5)}])
	_gs.progression["u_jost"] = _p.state("u_jost")
	_gs.progression["u_jost"]["exp"] = 99
	m.enemy_phase_enabled = true
	var lv: int = _p.level("u_jost")
	m._enemy_phase()
	check(_p.level("u_jost") == lv + 1, "countering earns EXP (99 + any fight EXP = a level)")
	check(" ".join(m.enemy_log).contains("Jost reaches level %d!" % (lv + 1)), "a level reached on a counter shows in the enemy log: %s" % str(m.enemy_log))
	check(not " ".join(m.enemy_log).contains("gains"), "...but plain EXP lines stay out of the log")
	m.queue_free()
	await process_frame

	# ---- the dead earn nothing
	_reset()
	m = await _setup(["u_jost"], [Vector2i(5, 5)], [{"arch": _arch("Brute", "sword", {"str": 90, "dex": 90}), "pos": Vector2i(6, 5)}])
	m.enemy_phase_enabled = true
	_gs.progression["u_jost"] = _p.state("u_jost")
	var exp0: int = _p.exp_of("u_jost")
	m._enemy_phase()
	check(not m.unit_positions.has("u_jost") and _p.exp_of("u_jost") == exp0, "a unit killed by the enemy earns no EXP")
	m.queue_free()
	await process_frame

	# ---- abilities change the fight: Smite-type damage shows in the forecast
	_reset()
	m = await _setup(["u_jost"], [Vector2i(5, 5)], [{"arch": _arch("Dummy", "sword"), "pos": Vector2i(6, 5)}])
	var plain: int = m._forecast_info(m.units[0], m.enemies[0])["forecast"]["atk"]["damage"]
	m.units[0]["abilities"] = [{"cond": "always", "hit": 0, "avoid": 0, "crit": 0, "dodge": 0, "dmg": 5, "guard": 0, "speed": 0, "exp_pct": 0}]
	var boosted: int = m._forecast_info(m.units[0], m.enemies[0])["forecast"]["atk"]["damage"]
	check(boosted == plain + 5, "an ability's damage reaches the forecast (%d -> %d)" % [plain, boosted])
	m.selected_unit_index = 0
	m._update_forecast()
	check(m.forecast_label.text.contains("Level"), "the forecast panel shows a Level row")
	check(m.info_label.text.contains("(Lv 5)"), "the selected-unit line shows the level (%s)" % m.info_label.text.split("\n")[1])
	m.queue_free()
	await process_frame

	# ---- income and unlocks on a win
	_reset()
	m = await _setup(["u_jost", "u_kheldar"], [Vector2i(5, 5), Vector2i(5, 7)], [{"arch": _arch("A", "sword"), "pos": Vector2i(8, 5)}, {"arch": _arch("B", "sword"), "pos": Vector2i(9, 5)}])
	m.enemies[0].defeated = true
	m.enemies[1].defeated = true
	m.map_won = true
	await process_frame
	var expect: int = _p.map_income(2, true)
	check(_gs.gold == expect and expect == 345, "winning pays 200 + 15 x 2 kills, x1.5 with Kheldar alive = %d (got %d)" % [345, _gs.gold])
	check(m.status_label.text.contains("Income: +345 gold (Kheldar's cut)."), "the status line reports it (%s)" % m.status_label.text.replace("\n", " / "))
	check(_gs.income_claimed.has("map_d05"), "claimed for this map")
	m.queue_free()
	await process_frame
	# replay: nothing again
	m = await _setup(["u_jost"], [Vector2i(5, 5)], [])
	var gold: int = _gs.gold
	m.map_won = true
	await process_frame
	check(_gs.gold == gold and not m.status_label.text.contains("Income"), "a replayed win pays nothing")
	m.queue_free()
	await process_frame
	# unlock: win the Throat Pass
	_reset()
	var tp: Node = load("res://scenes/map_tp19.tscn").instantiate()
	tp.enemy_phase_enabled = false
	root.add_child(tp)
	await process_frame
	tp.map_won = true
	await process_frame
	check(_gs.unlocked_classes.has("cls_billman") and tp.status_label.text.contains("Class unlocked: Billman."), "winning map_tp19 unlocks the Billman and says so (%s)" % tp.status_label.text.replace("\n", " / "))
	tp.queue_free()
	await process_frame
