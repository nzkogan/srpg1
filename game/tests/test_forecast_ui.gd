extends SceneTree
## Headless checks for the combat forecast: ForecastView's text and colour
## codes, and map_grid's target selection and attack-through-exchange wiring.
## Run from the repo root:
##   godot --headless --path game --script res://tests/test_forecast_ui.gd
## Exits 0 if every check passes, 1 otherwise.

const ForecastView := preload("res://scripts/forecast_view.gd")

var _failures: int = 0
var _checks: int = 0
var _combat: GDScript
var _w: Dictionary = {}

func check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: ", label)

func _initialize() -> void:
	_combat = load("res://scripts/combat.gd")
	await process_frame
	for row in root.get_node("Canon").get_table("weapons"):
		_w[row["weapon_id"]] = row
	_view_tests()
	await _map_tests()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)

func _fighter(over := {}) -> Dictionary:
	var d := {"str": 8, "mag": 6, "dex": 8, "spd": 8, "lck": 4, "def": 4, "res": 3, "movement_type": "infantry"}
	d.merge(over, true)
	return d

func _info(a: Dictionary, d: Dictionary, wa: Dictionary, wd: Dictionary, dist: int) -> Dictionary:
	return {
		"atk": {"name": "Sigrun", "weapon": wa.get("name", "none"), "hp": 22, "max_hp": 22},
		"def": {"name": "Looter", "weapon": wd.get("name", "none"), "hp": 16, "max_hp": 16},
		"forecast": _combat.forecast(a, d, wa, wd, dist),
	}

func _view_tests() -> void:
	var G: String = ForecastView.GREEN
	var R: String = ForecastView.RED
	var sword: Dictionary = _w["wpn_sword_basic"]
	var axe: Dictionary = _w["wpn_axe_basic"]
	var lance: Dictionary = _w["wpn_lance_basic"]
	# sword vs axe: attacker advantaged (green), defender disadvantaged (red)
	var t: String = ForecastView.bbcode(_info(_fighter(), _fighter(), sword, axe, 1))
	var fc: Dictionary = _combat.forecast(_fighter(), _fighter(), sword, axe, 1)
	check(t.contains("[color=%s]%d%%[/color]" % [G, fc["atk"]["hit"]]), "the advantaged attacker's hit is green")
	check(t.contains("[color=%s]%d%%[/color]" % [R, fc["def"]["hit"]]), "the disadvantaged counter's hit is red")
	check(t.contains("[color=%s]Iron Sword[/color]" % G) and t.contains("[color=%s]Iron Axe[/color]" % R), "weapon names carry the colours")
	check(t.contains("advantage") and t.contains("disadvantage"), "the triangle is also written out, never colour alone")
	check(t.contains("Sigrun") and t.contains("Looter"), "names appear")
	# the reverse: sword vs lance puts the sword in the red
	t = ForecastView.bbcode(_info(_fighter(), _fighter(), sword, lance, 1))
	check(t.contains("[color=%s]Iron Sword[/color]" % R) and t.contains("[color=%s]Iron Lance[/color]" % G), "sword vs lance: sword red, lance green")
	# neutral: no colour on the numbers
	t = ForecastView.bbcode(_info(_fighter(), _fighter(), sword, sword, 1))
	var fn: Dictionary = _combat.forecast(_fighter(), _fighter(), sword, sword, 1)
	check(not t.contains("[color=%s]%d%%" % [G, fn["atk"]["hit"]]) and not t.contains("[color=%s]%d%%" % [R, fn["atk"]["hit"]]), "neutral matchup: numbers uncoloured")
	check(t.contains("neutral"), "neutral is written out")
	# the four numbers the user asked for, all present
	for label in ["Damage", "Hit", "Crit", "Speed"]:
		check(t.contains(label), "forecast shows %s" % label)
	# doubling
	t = ForecastView.bbcode(_info(_fighter({"spd": 14}), _fighter(), sword, sword, 1))
	check(t.contains(" x2") and t.contains("Sigrun strikes twice (speed 14 vs 8)"), "a doubling attacker shows x2 and a sentence")
	t = ForecastView.bbcode(_info(_fighter(), _fighter({"spd": 14}), sword, sword, 1))
	check(t.contains("Looter strikes twice") and t.contains(R), "a doubling defender is called out (in red)")
	t = ForecastView.bbcode(_info(_fighter(), _fighter(), sword, sword, 1))
	check(not t.contains(" x2") and not t.contains("strikes twice"), "no doubling: no x2")
	# no counter
	t = ForecastView.bbcode(_info(_fighter(), _fighter(), sword, _w["wpn_bow_basic"], 1))
	check(t.contains("cannot counter from here"), "an out-of-range defender is marked as unable to counter")
	t = ForecastView.bbcode(_info(_fighter({"spd": 14}), _fighter(), sword, _w["wpn_bow_basic"], 1))
	check(t.contains("strikes twice (speed 14 vs 8)"), "doubling is still reported when the defender can't counter")
	# effectiveness
	var rider := _fighter({"movement_type": "riding"})
	t = ForecastView.bbcode(_info(_fighter(), rider, _w["wpn_halberd"], lance, 1))
	check(t.contains("EFF") and t.contains("effective here"), "an effective attack is tagged EFF")
	check(ForecastView.bbcode(_info(_fighter(), _fighter(), _w["wpn_halberd"], lance, 1)).contains("EFF") == false, "and only against the right movement type")
	# hybrid: neutral and says so
	t = ForecastView.bbcode(_info(_fighter(), _fighter(), sword, _w["wpn_halberd"], 1))
	check(not t.contains("[color=%s]Iron Sword" % G) and not t.contains("[color=%s]Iron Sword" % R), "a halberd is triangle-neutral on screen")
	# support line
	var info := _info(_fighter(), _fighter(), sword, sword, 1)
	info["support_text"] = "Support with Maren, rank B: +5 hit/avoid, +1 crit/dodge"
	check(ForecastView.bbcode(info).contains("Support with Maren"), "the support line shows when present")
	# a legend
	check(ForecastView.bbcode(info).contains("Green") and ForecastView.bbcode(info).contains("Red"), "the colour legend is on the panel")

# --------------------------------------------------------------- map_grid

func _map_tests() -> void:
	var gs: Node = root.get_node("GameState")
	gs.support_ranks.clear(); gs.support_points.clear(); gs.support_settled_maps.clear(); gs.support_recent.clear()
	var map: Node = load("res://scenes/map_d05.tscn").instantiate()
	root.add_child(map)
	await process_frame
	check(map.forecast_label != null and not map.forecast_label.visible, "the forecast panel exists and starts hidden (nothing in range)")
	var enemy: Dictionary = map.enemies[0]
	var idx := -1
	for i in map.units.size():
		if not map._weapon_for_unit(map.units[i]).is_empty():
			var w: Dictionary = map._weapon_for_unit(map.units[i])
			if int(w.get("range_min", 1)) <= 1 and int(w.get("range_max", 1)) >= 1:
				idx = i
				break
	var unit: Dictionary = map.units[idx]
	var pid: String = unit["punit_id"]
	check(unit["arts"].size() >= 1, "units carry their proficient arts (%s)" % str(unit["arts"]))
	map.unit_positions[pid] = enemy.pos + Vector2i(1, 0)
	map._select_unit(idx)
	check(map.forecast_label.visible, "selecting a unit with an enemy in range shows the forecast")
	check(map.forecast_label.text.contains(unit["name"]) and map.forecast_label.text.contains(enemy.archetype["name"]), "it names both fighters")
	# move out of range: hidden again
	map.unit_positions[pid] = enemy.pos + Vector2i(9, 9)
	map._update_forecast()
	check(not map.forecast_label.visible, "out of range: no forecast")
	map.unit_positions[pid] = enemy.pos + Vector2i(1, 0)
	map._update_forecast()
	check(map.forecast_label.visible, "back in range: forecast returns")

	# two enemies in range: Tab and click choose the target
	var second: Dictionary = map.enemies[1]
	second.pos = enemy.pos + Vector2i(0, 1)       # distance 2 from the unit (diagonal), enemy is distance 1
	map.unit_positions[pid] = enemy.pos + Vector2i(1, 0)
	var w: Dictionary = map._weapon_for_unit(unit)
	w = w.duplicate(); w["range_max"] = 2          # (local copy only, to give the unit reach 1-2 for this check)
	map.weapons_by_id[w["weapon_id"]] = w
	map._update_forecast()
	check(map._targets.size() == 2 and map._targets[0] == enemy, "two enemies in reach, nearest first")
	var first_text: String = map.forecast_label.text
	map._unhandled_input(_key(KEY_TAB))
	check(map._targets[map._target_idx] == second and map.forecast_label.text != first_text, "Tab moves the forecast to the next enemy")
	map._unhandled_input(_key(KEY_TAB))
	check(map._targets[map._target_idx] == enemy, "Tab wraps")
	check(map._try_target_click(second.pos) and map._targets[map._target_idx] == second, "clicking an enemy in range targets it")
	check(not map._try_target_click(Vector2i(0, 0)), "clicking elsewhere doesn't")

	# F attacks the TARGETED enemy, not the nearest
	var hp_second: int = second.hp
	var hp_first: int = enemy.hp
	var hit_chance: int = map._forecast_info(unit, second)["forecast"]["atk"]["hit"]
	var seed_hit := -1
	for s in 400:
		var probe := RandomNumberGenerator.new()
		probe.seed = s
		if probe.randi_range(1, 100) <= hit_chance:
			seed_hit = s
			break
	check(seed_hit >= 0 and hit_chance > 0, "found a seed that hits the second enemy (hit chance %d%%)" % hit_chance)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_hit
	map.rng_override = rng
	map.attacked_this_turn.clear()
	map._unhandled_input(_key(KEY_F))
	check(second.hp < hp_second, "F strikes the targeted enemy (hp %d -> %d)" % [hp_second, second.hp])
	check(enemy.hp == hp_first, "...and not the nearer one")
	check(map.attacked_this_turn.has(pid), "the unit has acted")

	# counters: the player is hurt by an enemy that can reach back
	map.attacked_this_turn.clear()
	map._targets.clear()
	var before: int = map.unit_hp[pid]
	var saw_counter := false
	for s in 60:
		var r2 := RandomNumberGenerator.new(); r2.seed = s
		map.rng_override = r2
		map.attacked_this_turn.clear()
		map.unit_hp[pid] = before
		enemy.hp = enemy.max_hp
		map._targets.clear(); map._target_idx = 0
		map._attack_enemy()
		if map.info_label.text.contains("counter"):
			saw_counter = true
			break
	check(saw_counter, "an enemy in reach counterattacks (text mentions the counter)")
	check(map.unit_hp[pid] <= before, "the exchange never heals the attacker")

	# unarmed units (weapon_art null) just have no weapon, and selecting them never errors
	var unarmed := {"punit_id": "u_x", "weapon_art": null, "arts": []}
	check(map._weapon_for_unit(unarmed).is_empty(), "an unarmed unit has no weapon (and no error)")
	for i in map.units.size():
		map._select_unit(i)
	check(true, "selecting every unit on the roster works")

	# a unit with no proficiency in its weapon can't attack
	var no_pro: Dictionary = unit.duplicate()
	no_pro["weapon_id"] = "wpn_halberd"
	no_pro["arts"] = ["axe"]
	check(map._weapon_for_unit(no_pro).is_empty(), "axe alone can't wield the halberd")
	no_pro["arts"] = ["axe", "lance"]
	check(map._weapon_for_unit(no_pro).get("weapon_id") == "wpn_halberd", "axe+lance can")

	# a player unit felled by a counter leaves the map; the last one gone is a defeat
	map.rng_override = null
	var victim: String = pid
	map.unit_hp[victim] = 0
	map._kill_unit(victim)
	check(not map.unit_positions.has(victim) and not map.unit_tokens.has(victim), "a dead unit's position and token are gone")
	for other in map.unit_positions.keys():
		map._kill_unit(other)
	map._check_defeat()
	check(map.map_lost and map.status_label.text.contains("DEFEAT"), "no units left on the map is a defeat")
	check(not map.forecast_label.visible, "no forecast after defeat")
	map.queue_free()
	await process_frame

func _key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e
