extends SceneTree
## Headless checks for the Skald (Edda): Refresh (an ally who has acted acts again), Steal (an enemy's
## weapon, never a boss's), and the Epithet Aura (hit and avoid for every deed an ally near her has earned).
## Run from the repo root:
##   godot --headless --path game --script res://tests/test_skald.gd
## Exits 0 if every check passes, 1 otherwise.

var _failures: int = 0
var _checks: int = 0
var _p: Node
var _gs: Node
var _eq: Node
var _canon: Node
var _combat: GDScript

func check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: ", label)

func _initialize() -> void:
	_p = root.get_node("Progression")
	_gs = root.get_node("GameState")
	_eq = root.get_node("Equipment")
	_canon = root.get_node("Canon")
	_combat = load("res://scripts/combat.gd")
	await process_frame
	await _run()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)

func _join(ids: Array, level := 10) -> void:
	for u in ids:
		_p.state(u)
		_gs.progression[u]["level"] = level

func _map(scene: String, deploy: Array, positions: Array, specs: Array = []) -> Node:
	var m: Node = load("res://scenes/%s.tscn" % scene).instantiate()
	var ids: Array[String] = []
	ids.assign(deploy)
	m.deploy_unit_ids = ids
	m.enemy_phase_enabled = false
	root.add_child(m)
	await process_frame
	for e in m.enemies:
		m._remove_enemy_token(e)
	m.enemies.clear(); m.dens.clear()
	for i in deploy.size():
		m.unit_positions[deploy[i]] = positions[i]
	var nid := 0
	for spec in specs:
		nid = m._spawn_enemy_instance(spec["arch"], spec["pos"], spec.get("kind", "mook"), nid)
	var r := RandomNumberGenerator.new()
	r.seed = 3
	m.rng_override = r
	return m

func _arch(name: String, over := {}) -> Dictionary:
	var d := {"enemy_id": "ea_t_" + name, "name": name, "weapon_art": "sword", "weapon_tier": "basic", "movement_type": "infantry",
		"level": 5, "hp": 40, "str": 0, "mag": 0, "dex": 0, "spd": 0, "lck": 0, "def": 0, "res": 0, "affiliation": "state", "death_noun": "lance"}
	d.merge(over, true)
	return d

func _select(m: Node, uid: String) -> void:
	m.selected_unit_index = m.units.find(m.units.filter(func(u): return u["punit_id"] == uid)[0])

func _key(n: Node, keycode: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.pressed = true
	n._unhandled_input(ev)

## A seed whose first d100 roll is <= `at_most` (success) or > `at_least` (failure).
func _seed_for(low: bool, bound: int) -> int:
	var r := RandomNumberGenerator.new()
	for sd in range(1, 5000):
		r.seed = sd
		var roll := r.randi_range(1, 100)
		if (low and roll <= bound) or (not low and roll > bound):
			return sd
	return 1

func _run() -> void:
	# ---- canon
	var cls: Dictionary = _canon.find_by("classes", "class_id", "cls_skald")
	check(cls["map_actions"] == "refresh|steal" and cls["signature_skill"] == "Epithet Aura" and cls["tier"] == "personal", "the Skald: Refresh, Steal, the Epithet Aura")
	check(_canon.find_by("units", "unit_id", "u_edda")["base_class_id"] == "cls_skald", "Edda holds it")
	check(_p.param("steal_base") == 50 and _p.param("steal_per_spd") == 5 and _p.param("aura_radius") == 2 and _p.param("aura_per_deed") == 3 and _p.param("aura_cap") == 9, "parameters: steal 50 + 5 a speed point; aura radius 2, 3 a deed, cap 9")
	_gs.reset()
	_join(["u_edda", "u_jost"])
	check(_p.can_refresh("u_edda") and _p.can_steal("u_edda") and _p.has_epithet_aura("u_edda"), "Edda has all three")
	check(not _p.can_refresh("u_jost") and not _p.can_steal("u_jost") and not _p.has_epithet_aura("u_jost"), "no one else does")
	check(_p.steal_chance(6, 6) == 50 and _p.steal_chance(10, 6) == 70 and _p.steal_chance(6, 10) == 30 and _p.steal_chance(40, 0) == 95 and _p.steal_chance(0, 40) == 5, "the steal chance rises with her speed over theirs, and is never certain or hopeless")
	check(_p.aura_bonus(0) == 0 and _p.aura_bonus(1) == 3 and _p.aura_bonus(2) == 6 and _p.aura_bonus(3) == 9 and _p.aura_bonus(8) == 9, "the aura: 3 a deed, capped at 9")
	check(_p.earned_deed_count("u_jost") == 0, "(no deeds yet)")
	_p.record_deed("u_jost", "ep_bosskill")
	_p.record_deed("u_jost", "ep_miasma")                    # 1 of 5: not earned
	check(_p.earned_deed_count("u_jost") == 1, "a deed part-way does not count")

	# ---- the aura on the map
	_gs.reset()
	_join(["u_edda", "u_jost", "u_sigrun", "u_tancred"])
	_p.record_deed("u_jost", "ep_bosskill")
	_p.record_deed("u_jost", "ep_talk")
	var m: Node = await _map("map_d02", ["u_edda", "u_jost", "u_sigrun", "u_tancred"],
		[Vector2i(8, 8), Vector2i(10, 8), Vector2i(11, 8), Vector2i(0, 0)])
	check(m._aura_for("u_jost") == 6, "an ally two tiles from Edda with two deeds gets +6 (%d)" % m._aura_for("u_jost"))
	var c: Dictionary = m._combatant_for_unit("u_jost")
	check(int(c.get("sup_hit", 0)) == 6 and int(c.get("sup_avoid", 0)) == 6, "...in hit and avoid, where the forecast reads them")
	check(m._aura_for("u_sigrun") == 0, "...an ally three tiles away gets nothing, and one with no deeds would get nothing")
	_p.record_deed("u_sigrun", "ep_nohit")
	check(m._aura_for("u_sigrun") == 0, "(three tiles is out of reach)")
	m.unit_positions["u_sigrun"] = Vector2i(8, 9)
	check(m._aura_for("u_sigrun") == 3, "(a tile away, one deed: +3)")
	_p.record_deed("u_edda", "ep_talk")
	check(m._aura_for("u_edda") == 3, "Edda's own deeds lift her too")
	for ep in ["ep_nohit", "ep_solohold", "ep_delivery"]:
		_p.record_deed("u_jost", ep)
	check(m._aura_for("u_jost") == 9, "the aura stops at 9 however many deeds (%d)" % m._aura_for("u_jost"))
	var plain := {"dex": 0, "lck": 0, "spd": 5, "str": 5}
	var weapon: Dictionary = _canon.find_by("weapons", "weapon_id", "wpn_sword_worn")
	var def := {"spd": 0, "lck": 0, "def": 0, "movement_type": "infantry", "weapon_art": ""}
	var base_hit: int = _combat.hit_chance(plain, def, weapon)
	var aura_hit: int = _combat.hit_chance(plain.merged({"sup_hit": 9}), def, weapon)
	check(aura_hit == base_hit + 9, "the forecast's hit chance really moves by the aura (%d -> %d)" % [base_hit, aura_hit])
	m.unit_positions.erase("u_edda")
	check(m._aura_for("u_jost") == 0, "no Edda on the map (fallen or left behind), no aura")
	m.unit_positions["u_edda"] = Vector2i(8, 8)
	m.queue_free()
	await process_frame

	# ---- Refresh
	_gs.reset()
	_join(["u_edda", "u_jost", "u_sigrun"])
	m = await _map("map_d02", ["u_edda", "u_jost", "u_sigrun"], [Vector2i(8, 8), Vector2i(9, 8), Vector2i(8, 9)])
	_select(m, "u_sigrun")
	m._begin_skald("refresh")
	check(m._skald_mode == "" and m.info_label.text.contains("no Refresh action"), "Sigrun has no Refresh")
	_select(m, "u_edda")
	_key(m, KEY_R)
	check(m._skald_mode == "refresh", "R offers Refresh")
	_key(m, KEY_ESCAPE)
	check(m._skald_mode == "" and not m.attacked_this_turn.has("u_edda"), "any other key cancels")
	m._begin_skald("refresh")
	m._skald_toward(Vector2i(1, 0))
	check(m.info_label.text.contains("nothing to refresh") and not m.attacked_this_turn.has("u_edda"), "an ally who has not acted needs nothing (and she keeps her action)")
	m.moved_this_turn["u_jost"] = true
	m.attacked_this_turn["u_jost"] = true
	m._begin_skald("refresh")
	m._skald_toward(Vector2i(1, 0))
	check(not m.moved_this_turn.has("u_jost") and not m.attacked_this_turn.has("u_jost") and m.attacked_this_turn.has("u_edda"), "Jost can move and act again; Edda's own action is spent")
	m._begin_skald("refresh")
	check(m._skald_mode == "" and m.info_label.text.contains("already acted"), "one Refresh a turn")
	m.attacked_this_turn.clear()
	m._begin_skald("refresh")
	m._skald_toward(Vector2i(-1, 0))
	check(m.info_label.text.contains("no one beside"), "an empty tile has no one to refresh")
	m.queue_free()
	await process_frame

	# ---- Steal
	_gs.reset()
	_join(["u_edda"])
	var foes := [{"arch": _arch("Slow", {"spd": 0}), "pos": Vector2i(9, 8)}, {"arch": _arch("Warlord", {"spd": 0, "weapon_tier": "mid"}), "pos": Vector2i(8, 9), "kind": "boss"}]
	m = await _map("map_d02", ["u_edda"], [Vector2i(8, 8)], foes)
	_select(m, "u_edda")
	var spd: int = int(m.units[0]["spd"])
	var chance: int = _p.steal_chance(spd, 0)
	check(chance >= 50, "(Edda is quicker than a slow levy: %d%%)" % chance)
	m.rng_override.seed = _seed_for(false, chance)
	var convoy_before: int = _eq.convoy().size()
	_key(m, KEY_X)
	check(m._skald_mode == "steal", "X offers Steal")
	m._skald_toward(Vector2i(1, 0))
	check(not m.enemies[0].get("unarmed", false) and m.enemies[0].get("wary", false) and m.attacked_this_turn.has("u_edda") and _eq.convoy().size() == convoy_before and m.info_label.text.contains("is seen"), "a failed try puts the enemy on guard and spends her action")
	m.attacked_this_turn.clear()
	m._begin_skald("steal")
	m._skald_toward(Vector2i(1, 0))
	check(m.info_label.text.contains("not be robbed twice") and not m.attacked_this_turn.has("u_edda"), "no second go (and no action spent on it)")
	m.enemies[0]["wary"] = false
	m.rng_override.seed = _seed_for(true, chance)
	m._begin_skald("steal")
	m._skald_toward(Vector2i(1, 0))
	check(m.enemies[0].get("unarmed", false) and _eq.convoy().size() == convoy_before + 1 and m.info_label.text.contains("Iron Sword"), "a good try lifts the Iron Sword into the convoy and leaves it unarmed")
	check(m._enemy_weapon(m.enemies[0]).is_empty(), "an unarmed enemy has no weapon to fight with")
	m.attacked_this_turn.clear()
	m._begin_skald("steal")
	m._skald_toward(Vector2i(1, 0))
	check(m.info_label.text.contains("nothing left to steal") and _eq.convoy().size() == convoy_before + 1, "nothing left to take")
	m.attacked_this_turn.clear()
	m._begin_skald("steal")
	m._skald_toward(Vector2i(0, 1))
	check(m.info_label.text.contains("holds its weapon fast") and not m.enemies[1].get("unarmed", false) and not m.attacked_this_turn.has("u_edda"), "a boss will not be robbed")
	m._begin_skald("steal")
	m._skald_toward(Vector2i(-1, 0))
	check(m.info_label.text.contains("no enemy there"), "an empty tile has no one to rob")
	m.queue_free()
	await process_frame
