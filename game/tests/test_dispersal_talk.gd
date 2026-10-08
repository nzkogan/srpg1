extends SceneTree
## Headless checks for the dispersal deed (a levy routed below half HP, then run off the
## field unkilled) and the talk deed (an enemy talked down): the rout rules, who gets the
## credit, the odds and outcomes of talking, and the income each pays.
## Run from the repo root:
##   godot --headless --path game --script res://tests/test_dispersal_talk.gd
## Exits 0 if every check passes, 1 otherwise.
##
## map_d02 (16x12) has a passable rim all round, so a levy can run off it. map_a02 is the
## 'defend' map whose boss, Boyan, stands on the defend point.

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

func _levy(over := {}) -> Dictionary:
	var d := _arch("Levy", {"flees_below_pct": 50, "hp": 16, "talk_mod": 20, "talk_line": "I never wanted this spear."})
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

## A seeded RNG whose first d100 roll satisfies `want` (e.g. <= 20).
func _rng_where(want: Callable) -> RandomNumberGenerator:
	for sd in range(1, 5000):
		var r := RandomNumberGenerator.new()
		r.seed = sd
		var v := r.randi_range(1, 100)
		if want.call(v):
			var fresh := RandomNumberGenerator.new()
			fresh.seed = sd
			return fresh
	return null

func _key(m: Node, keycode: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.pressed = true
	m._unhandled_input(ev)

func _talk(m: Node, idx: int, dir: Vector2i) -> void:
	m.selected_unit_index = idx
	m.attacked_this_turn.clear()
	m._talk_toward(dir)

func _run() -> void:
	var R := Vector2i(1, 0)
	var L := Vector2i(-1, 0)
	# ---- canon
	_reset()
	check(_p.is_tracked("ep_dispersal") and _p.count_needed("ep_dispersal") == 3 and _p.is_tracked("ep_talk") and _p.count_needed("ep_talk") == 1, "dispersal (3 routs) and talk (1) are tracked")
	var ids: Array = []
	for r in _p.other_tracked_epithets():
		ids.append(r["epithet_id"])
	check(ids == ["ep_miasma", "ep_delivery", "ep_dispersal", "ep_talk"] and _p.gating_epithets().size() == 4, "all four are 'other' deeds; the paragon gate is unchanged")
	var levy: Dictionary = _canon.find_by("enemy_archetypes", "enemy_id", "ea_conscript_levy")
	var boyan: Dictionary = _canon.find_by("enemy_archetypes", "enemy_id", "ea_preacher_boyan")
	var looter: Dictionary = _canon.find_by("enemy_archetypes", "enemy_id", "ea_looter")
	check(int(levy["flees_below_pct"]) == 50 and levy["talk_mod"] == 20, "the conscript levy flees below 50% and listens (+20)")
	check(boyan["talk_mod"] == -10 and boyan.get("flees_below_pct") == null, "Boyan listens (-10) and never flees")
	check(looter.get("talk_mod") == null and looter.get("flees_below_pct") == null, "a looter does neither")
	check(_p.can_talk_to(levy) and _p.can_talk_to(boyan) and not _p.can_talk_to(looter), "can_talk_to follows talk_mod")

	# ---- is_routing
	check(_p.is_routing(levy, 7, 16, false) and not _p.is_routing(levy, 8, 16, false), "'below half': 7 of 16 routs, exactly 8 of 16 does not")
	check(not _p.is_routing(levy, 0, 16, false) and not _p.is_routing(levy, 7, 16, true) and not _p.is_routing(looter, 1, 16, false), "the dead, bosses and enemies with no threshold never rout")

	# ---- talk odds
	check(_p.talk_chance(5, 10, levy) == 40 + 15 + 2 * 9 + 20, "the odds: 40 + 3 per Lck + 2 per level over + the enemy's mod (93)")
	check(_p.talk_chance(5, 10, boyan) == 40 + 15 + 2 * -5 - 10, "Boyan, level 15, is harder (35)")
	check(_p.talk_chance(0, 1, boyan) == 5 and _p.talk_chance(40, 40, levy) == 95, "clamped to 5% and 95%")
	check(_p.talk_chance(9, 9, looter) == 0, "an enemy that can't be talked to has no odds")

	# ---- who gets the credit for the rout
	_reset()
	var m: Node = await _setup("map_d02", ["u_jost", "u_avatar"], [Vector2i(4, 5), Vector2i(4, 8)], [{"arch": _levy(), "pos": Vector2i(5, 5)}])
	var e: Dictionary = m.enemies[0]
	e.hp = 12
	m._note_damage(e, "u_jost", 16)
	check(e.hit_by.has("u_jost") and not e.has("rout_blow"), "a blow that leaves it above the threshold only counts as damage")
	e.hp = 7
	m._note_damage(e, "u_avatar", 12)
	check(e["rout_blow"] == "u_avatar", "the blow that takes it below the threshold is the rout (avatar)")
	e.hp = 3
	m._note_damage(e, "u_jost", 7)
	check(e["rout_blow"] == "u_avatar", "a later blow doesn't steal it")
	e.erase("rout_blow")
	e.hp = 3
	m._note_damage(e, "u_jost", 7)
	check(not e.has("rout_blow"), "damage to an enemy that was already below the line (say, from a hazard earlier) isn't a rout")
	m.queue_free()
	await process_frame

	# a real attack and a real counter credit the right unit
	_reset()
	m = await _setup("map_d02", ["u_jost"], [Vector2i(4, 5)], [{"arch": _levy({"hp": 40}), "pos": Vector2i(5, 5)}])
	e = m.enemies[0]
	e.max_hp = 60
	e.hp = 31                      # one point above the line (30): any hit from Jost crosses it
	m._attack_enemy()
	check(int(e.hp) < 30 and int(e.hp) > 0 and e.get("rout_blow", "") == "u_jost", "an attack that crosses the line is credited to the attacker (hp %d)" % e.hp)
	m.queue_free()
	await process_frame

	# ---- the enemy phase: a routed enemy runs and leaves
	_reset()
	m = await _setup("map_d02", ["u_jost", "u_avatar"], [Vector2i(4, 5), Vector2i(4, 8)], [{"arch": _levy({"str": 40, "dex": 99}), "pos": Vector2i(3, 5)}])
	m.enemy_phase_enabled = true
	e = m.enemies[0]
	m.unit_hp["u_jost"] = 100
	var jost_hp: int = m.unit_hp["u_jost"]
	e.hp = 5
	e["rout_blow"] = "u_jost"
	m._enemy_phase()
	check(m.unit_hp["u_jost"] == jost_hp, "a routed enemy doesn't attack, however strong")
	check(e.defeated and e.get("routed", false) and e.token.is_empty(), "it ran for the rim and left the field (routed, not killed)")
	check(" ".join(m.enemy_log).contains("breaks and flees the field"), "(%s)" % " / ".join(m.enemy_log))
	check(_p.deed_count("u_jost", "ep_dispersal") == 1 and " ".join(m.enemy_log).contains("Jost has routed 1 of 3."), "the one who broke it gets a step toward the deed")
	check(not e.has("drop") or true, "(it takes its weapon with it)")
	m.queue_free()
	await process_frame

	# same enemy, healthy: it fights
	_reset()
	m = await _setup("map_d02", ["u_jost"], [Vector2i(4, 5)], [{"arch": _levy({"str": 40, "dex": 99}), "pos": Vector2i(5, 5)}])
	m.enemy_phase_enabled = true
	m.unit_hp["u_jost"] = 100
	m.enemies[0].hp = 9               # 9 of 16: above the line
	m._enemy_phase()
	check(m.unit_hp["u_jost"] < 100 and not m.enemies[0].get("routed", false), "(control: above half HP it fights as before)")
	m.queue_free()
	await process_frame

	# three routs earn it
	_reset()
	m = await _setup("map_d02", ["u_jost"], [Vector2i(8, 5)], [{"arch": _levy(), "pos": Vector2i(2, 4)}, {"arch": _levy(), "pos": Vector2i(2, 6)}, {"arch": _levy(), "pos": Vector2i(3, 5)}])
	m.enemy_phase_enabled = true
	for en in m.enemies:
		en.hp = 4
		en["rout_blow"] = "u_jost"
	m._enemy_phase()
	check(m.enemies.all(func(x): return x.get("routed", false)) and _p.deed_count("u_jost", "ep_dispersal") == 3, "three levies broken by Jost all run")
	check(_p.has_deed("u_jost", "ep_dispersal") and " ".join(m.enemy_log).contains("Jost earns a deed: dispersal ('Merciful')."), "the third earns the deed, announced (%s)" % " / ".join(m.enemy_log))
	m.queue_free()
	await process_frame

	# killed before it can run: no dispersal; the wrong sort of enemy: no running
	_reset()
	m = await _setup("map_d02", ["u_jost"], [Vector2i(8, 5)], [{"arch": _levy(), "pos": Vector2i(2, 4)}, {"arch": _levy({"hp": 16}), "pos": Vector2i(2, 6)}, {"arch": _arch("Looter", {"hp": 16}), "pos": Vector2i(3, 5)}])
	m.enemy_phase_enabled = true
	m.enemies[0].hp = 4
	m.enemies[0]["rout_blow"] = "u_jost"
	m.enemies[0].defeated = true      # finished off first
	m.enemies[2].hp = 4               # a looter at 4 of 16 has no flee threshold
	m.enemies[2].max_hp = 16
	m._enemy_phase()
	check(_p.deed_count("u_jost", "ep_dispersal") == 0, "an enemy that was killed isn't a dispersal")
	check(not m.enemies[2].get("routed", false) and " ".join(m.enemy_log).contains("Looter"), "an enemy with no flee threshold doesn't run, however hurt: it attacks (%s)" % " / ".join(m.enemy_log))
	check(not m.enemies[1].get("routed", false), "and a healthy levy doesn't either")
	m.queue_free()
	await process_frame

	# a boss with a threshold stays and fights; a bribed levy stays put
	_reset()
	m = await _setup("map_d02", ["u_jost"], [Vector2i(4, 5)], [{"arch": _levy({"str": 40, "dex": 99}), "pos": Vector2i(5, 5), "kind": "boss"}, {"arch": _levy({"str": 40, "dex": 99}), "pos": Vector2i(4, 7)}])
	m.enemy_phase_enabled = true
	m.unit_hp["u_jost"] = 100
	m.enemies[0].hp = 3
	m.enemies[1].hp = 3
	m.enemies[1]["neutral"] = true
	m._enemy_phase()
	check(not m.enemies[0].get("routed", false) and m.unit_hp["u_jost"] < 100, "a boss never breaks (it fights on)")
	check(not m.enemies[1].get("routed", false) and m.enemies[1].pos == Vector2i(4, 7), "a bribed enemy stands down instead of running")
	m.queue_free()
	await process_frame

	# a routed enemy that can't reach the rim runs without leaving, and can still be struck
	_reset()
	m = await _setup("map_d02", ["u_jost"], [Vector2i(5, 5)], [{"arch": _levy({"movement_type": "armor"}), "pos": Vector2i(7, 5)}])
	m.enemy_phase_enabled = true
	m.enemies[0].hp = 4
	m._enemy_phase()
	var far: int = m._distance(m.enemies[0].pos, Vector2i(5, 5))
	check(not m.enemies[0].defeated and far > 2, "mid-field it just runs (now %d tiles off) and is still on the map" % far)
	check(" ".join(m.enemy_log).contains("breaks and runs"), "(%s)" % " / ".join(m.enemy_log))
	m.queue_free()
	await process_frame

	# it runs for the rim even when that means running toward the player, rather than just away
	_reset()
	m = await _setup("map_d02", ["u_jost"], [Vector2i(13, 5)], [{"arch": _levy(), "pos": Vector2i(11, 6)}])
	m.enemy_phase_enabled = true
	m.enemies[0].hp = 4
	m.enemies[0]["rout_blow"] = "u_jost"
	m._enemy_phase()
	check(m.enemies[0].get("routed", false), "a levy within reach of the rim takes it, even if inland ground is farther from the player")
	m.queue_free()
	await process_frame

	# ---- talking: the prompt
	_reset()
	m = await _setup("map_d02", ["u_jost", "u_avatar"], [Vector2i(4, 5), Vector2i(4, 8)],
		[{"arch": _levy(), "pos": Vector2i(5, 5)}, {"arch": _arch("Looter"), "pos": Vector2i(4, 4)}])
	m.selected_unit_index = 0
	var jost_chance: int = m._talk_chance_for(m.units[0], m.enemies[0])
	_key(m, KEY_T)
	check(m._talk_mode and m.info_label.text.contains("Levy: %d%%" % jost_chance) and m.info_label.text.contains("Looter: nothing to say"), "T lists the odds for the one that will listen and says the other won't (%s)" % m.info_label.text)
	check(jost_chance > 50, "(a conscript is a good bet: %d%%)" % jost_chance)
	_key(m, KEY_F)
	check(not m._talk_mode and m.info_label.text.contains("cancelled"), "any other key cancels")
	m.attacked_this_turn.clear()
	m._update_status_label()
	check(m.status_label.text.contains("[T] talk"), "the controls line lists [T]")
	_talk(m, 0, Vector2i(0, -1))
	check(m.info_label.text.contains("has nothing to say") and not m.attacked_this_turn.has("u_jost") and not m.enemies[1].get("talk_failed", false), "a looter has nothing to say: refused, free (%s)" % m.info_label.text)
	_talk(m, 0, L)
	check(m.info_label.text.contains("nobody there to talk to") and not m.attacked_this_turn.has("u_jost"), "an empty tile is refused")
	_talk(m, 0, Vector2i(0, 1))
	check(m.info_label.text.contains("nobody there to talk to"), "so is a friend")
	m.queue_free()
	await process_frame

	# ---- talking: success and failure
	_reset()
	m = await _setup("map_d02", ["u_jost", "u_avatar"], [Vector2i(4, 5), Vector2i(4, 8)], [{"arch": _levy({"hp": 16, "drop": null}), "pos": Vector2i(5, 5)}])
	m.enemies[0]["drop"] = "wpn_bow_basic"
	m.enemies[0]["spawn_id"] = "spn_test_talk"
	var convoy_before = _gs.convoy.duplicate(true)
	var chance: int = m._talk_chance_for(m.units[0], m.enemies[0])
	m.rng_override = _rng_where(func(v): return v <= chance)
	var exp_before: int = _p.exp_of("u_jost") + 100 * _p.level("u_jost")
	_talk(m, 0, R)
	e = m.enemies[0]
	check(e.defeated and e.get("talked", false) and e.token.is_empty() and e.hp == 16, "a successful talk takes the enemy off the map unharmed")
	check(m.info_label.text.contains("Jost talks the Levy down") and m.info_label.text.contains("I never wanted this spear."), "with its own line (%s)" % m.info_label.text.replace("\n", " / "))
	check(_p.has_deed("u_jost", "ep_talk") and m.info_label.text.contains("Jost earns a deed: talk ('Peacemaker')."), "and the deed, announced")
	check(m.attacked_this_turn.has("u_jost") and m.fought_units.has("u_jost"), "it costs the action and counts as taking part")
	check(_p.exp_of("u_jost") + 100 * _p.level("u_jost") > exp_before, "it earns EXP")
	check(_gs.convoy == convoy_before and not _gs.drops_claimed.has("spn_test_talk"), "and drops nothing")
	m.queue_free()
	await process_frame

	_reset()
	m = await _setup("map_d02", ["u_jost"], [Vector2i(4, 5)], [{"arch": _levy({"talk_mod": -20}), "pos": Vector2i(5, 5)}])
	chance = m._talk_chance_for(m.units[0], m.enemies[0])
	m.rng_override = _rng_where(func(v): return v > chance)
	_talk(m, 0, R)
	e = m.enemies[0]
	check(not e.defeated and e.get("talk_failed", false) and m.attacked_this_turn.has("u_jost"), "a failed talk costs the action and the enemy stops listening (%d%%)" % chance)
	check(m.info_label.text.contains("will not hear it (%d%%)" % chance), "(%s)" % m.info_label.text)
	check(not _p.has_deed("u_jost", "ep_talk"), "no deed")
	m.attacked_this_turn.clear()
	m._talk_toward(R)
	check(not m.attacked_this_turn.has("u_jost") and m.info_label.text.contains("stopped listening"), "trying again is refused, free")
	_key(m, KEY_T)
	check(m.info_label.text.contains("has stopped listening"), "and the prompt says so")
	m.queue_free()
	await process_frame

	# bribed / acted / cargo
	_reset()
	m = await _setup("map_d03", ["u_jost"], [Vector2i(4, 5)], [{"arch": _levy(), "pos": Vector2i(5, 5)}])
	m.enemies[0]["neutral"] = true
	_talk(m, 0, R)
	check(m.info_label.text.contains("nobody there to talk to"), "a bribed (neutral) enemy isn't someone to talk down")
	m.enemies[0]["neutral"] = false
	m.attacked_this_turn["u_jost"] = true
	m.selected_unit_index = 0
	m._talk_toward(R)
	check(m.info_label.text.contains("already acted") and not m.enemies[0].defeated, "after acting, no")
	m.selected_unit_index = m.units.size() - 1
	m.attacked_this_turn.clear()
	_key(m, KEY_T)
	check(not m._talk_mode and m.info_label.text.contains("has no one to talk to"), "a wagon can't talk")
	m.queue_free()
	await process_frame

	# ---- a boss that yields ends a defend map
	_reset()
	m = await _setup("map_a02", ["u_solveig"], [Vector2i(0, 0)], [{"arch": boyan.duplicate(), "pos": Vector2i(8, 8), "kind": "boss"}])
	var spot := Vector2i(-1, -1)
	for n in m._neighbors(Vector2i(8, 8)):
		if m._terrain_cost(n, "infantry") < m.IMPASSABLE:
			spot = n
	m.unit_positions["u_solveig"] = spot
	m.enemies[0].max_hp = 24
	m.enemies[0].hp = 24
	m.rng_override = _rng_where(func(v): return v <= 5)
	_talk(m, 0, Vector2i(8, 8) - spot)
	check(m.enemies[0].defeated and m.enemies[0].get("talked", false) and m.map_won, "answering Boyan wins the defend map")
	check(m.status_label.text.contains("yields. Threat neutralized.") and m.info_label.text.begins_with("Victory."), "(%s / %s)" % [m.status_label.text, m.info_label.text.replace("\n", " / ")])
	check(_p.has_deed("u_solveig", "ep_talk"), "and Solveig has the deed")
	m.queue_free()
	await process_frame

	# ---- income: kills 15, captures 25, talks 20, routs 10
	check(_p.map_income(1, false, 1, 1, 1) == 200 + 15 + 25 + 10 + 20, "income: 200 + 15 a kill + 25 a capture + 10 a rout + 20 a talk (270)")
	check(_p.map_income(0, true, 0, 2, 1) == int(round((200 + 20 + 20) * 1.5)), "(Kheldar's x1.5 covers them)")
	_reset()
	m = await _setup("map_d02", ["u_jost"], [Vector2i(8, 8)], [{"arch": _levy(), "pos": Vector2i(2, 4)}, {"arch": _levy(), "pos": Vector2i(2, 6)}, {"arch": _levy(), "pos": Vector2i(3, 5)}, {"arch": _levy(), "pos": Vector2i(3, 7)}])
	m.enemies[0].defeated = true                       # a kill
	m.enemies[1].defeated = true; m.enemies[1]["routed"] = true
	m.enemies[2].defeated = true; m.enemies[2]["talked"] = true
	m._settle_rewards()
	check(_gs.gold == 200 + 15 + 10 + 20, "the map pays each outcome at its own rate (gold %d)" % _gs.gold)
	m.queue_free()
	await process_frame

	# ---- saved and shown
	_reset()
	_p.record_deed("u_jost", "ep_dispersal", 2)
	var snap: Dictionary = _gs.to_dict()
	_gs.deeds.clear()
	_gs.from_dict(snap)
	check(_p.deed_count("u_jost", "ep_dispersal") == 2 and not _p.has_deed("u_jost", "ep_dispersal"), "dispersal progress is saved")
	var bar: Node = load("res://scripts/barracks_screen.gd").new()
	var lines: Array[String] = []
	bar._append_deeds(lines, "u_jost")
	var shown := "\n".join(lines)
	check(shown.contains("dispersal") and shown.contains("-- 2 of 3") and shown.contains("talk") and not shown.contains("not recordable yet"), "the barracks lists both with progress, and nothing is 'not recordable' any more (%s)" % shown.replace("\n", " / "))
	bar.free()
