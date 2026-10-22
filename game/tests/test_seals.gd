extends SceneTree
## Headless checks for bound ground: the canon seal tiles, how a seal scales the gifts of whoever stands on it by the side that holds
## it (and for a bearer at home), the briefing, the Pardoner breaking a seal, and saving.
## Run from the repo root:
##   godot --headless --path game --script res://tests/test_seals.gd
## Exits 0 if every check passes, 1 otherwise.

var _failures: int = 0
var _checks: int = 0
var _p: Node
var _gs: Node
var _canon: Node
var _pa: Node

func check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: ", label)

func _initialize() -> void:
	_p = root.get_node("Progression")
	_gs = root.get_node("GameState")
	_canon = root.get_node("Canon")
	_pa = root.get_node("Patrons")
	await process_frame
	await _run()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)

func _join(ids: Array, level := 10) -> void:
	for u in ids:
		_p.state(u)
		_gs.progression[u]["level"] = level

func _map(scene: String, deploy: Array, positions: Array = []) -> Node:
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
	for i in positions.size():
		m.unit_positions[deploy[i]] = positions[i]
	return m

func _key(k: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.pressed = true
	return ev

func _pr(side: String, chance: int, patron := "pat_99") -> Dictionary:
	return {"side": side, "trigger": "on_attack", "kind": "power", "amount": 3, "chance": chance, "label": "X", "patron": patron}

func _run() -> void:
	# ---- canon
	check(_p.param("seal_angel_blessing_pct") == 150 and _p.param("seal_angel_curse_pct") == 50 and _p.param("seal_demon_blessing_pct") == 150 and _p.param("seal_demon_curse_pct") == 150 and _p.param("seal_balanced_pct") == 125 and _p.param("seal_home_pct") == 150, "parameters: the angel's ground 150/50, the demon's 150/150, shared 125, at home x1.5")
	var cls = _canon.find_by("classes", "class_id", "cls_pardoner")
	check(str(cls["map_actions"]) == "capture|unseal", "the Pardoner captures and breaks seals")
	var sealed: Array = _canon.get_table("maps").filter(func(m): return m.get("seal_tiles") != null)
	check(sealed.size() >= 40 and _canon.find_by("maps", "map_id", "map_d02")["seal_tiles"] == "6:6|10:6", "bound ground is on the campaign's maps (%d), two seals each: d02's are at 6:6 and 10:6" % sealed.size())
	var bad: Array = sealed.filter(func(m): return ["prologue", "flashback"].has(_canon.find_by("chapters", "chapter_id", m["chapter_id"])["act"]))
	check(bad.is_empty(), "...and no memory has any")
	check(_pa.ground_of_chapter("ch_d02")["patron"]["demon_name"] == "Ronove" and _pa.ground_of_chapter("ch_d02")["side"] == "demon" and _pa.ground_of_chapter("ch_nope").is_empty(), "a chapter's ground is its location's pair: the weighbridge is Ronove's, held by the demon")

	# ---- the scaling
	var a: Array = _pa.seal_scale([_pr("blessing", 20), _pr("curse", 20)], "angel", "pat_00")
	check(a.size() == 2 and a[0]["chance"] == 30 and a[1]["chance"] == 10, "the angel's ground: blessings 150% (20 to 30), curses 50% (20 to 10)")
	var d: Array = _pa.seal_scale([_pr("blessing", 20), _pr("curse", 20)], "demon", "pat_00")
	check(d[0]["chance"] == 30 and d[1]["chance"] == 30, "the demon's ground raises both: 30 and 30")
	var b: Array = _pa.seal_scale([_pr("blessing", 20), _pr("curse", 20)], "balanced", "pat_00")
	check(b[0]["chance"] == 25 and b[1]["chance"] == 25, "shared ground: 25 and 25")
	var h: Array = _pa.seal_scale([_pr("blessing", 20, "pat_07"), _pr("curse", 20, "pat_07")], "angel", "pat_07")
	check(h[0]["chance"] == 45 and h[1]["chance"] == 10, "at home (born under the seal's pair) the blessing is louder still: 20 x 1.5 x 1.5 = 45; the curse is not")
	var cap: Array = _pa.seal_scale([_pr("blessing", 60)], "demon", "pat_00")
	check(cap[0]["chance"] == 80, "(and capped at twice the ceiling)")
	_p._params["seal_angel_curse_pct"] = 0.0
	check(_pa.seal_scale([_pr("curse", 20)], "angel", "x").is_empty(), "a curse scaled to nothing is gone")
	_p._params["seal_angel_curse_pct"] = 50.0
	check(_pa.ground_word("angel") == "bound ground", "before the reveal it is bound ground")
	_gs.won_maps["map_f02"] = true
	check(_pa.ground_word("angel") == "the angel's ground" and _pa.ground_word("demon") == "the demon's ground" and _pa.ground_word("balanced") == "shared ground", "after it, whose ground")
	_gs.reset()

	# ---- on the map
	_join(["u_jost"])
	var m: Node = await _map("map_d02", ["u_jost"], [Vector2i(8, 8)])
	check(m.seals.size() == 2 and m.seals.has(Vector2i(6, 6)) and m.seals.has(Vector2i(10, 6)) and m.seal_ground["side"] == "demon", "the map draws its two seals, held by the demon")
	check(m.info_label.text.contains("Bound ground of Ronove marks this field (2 seals)"), "the briefing says so: %s" % m.info_label.text.substr(0, 110))
	var off: Array = m._combatant_for_unit("u_jost")["procs"]
	m.unit_positions["u_jost"] = Vector2i(6, 6)
	var on: Array = m._combatant_for_unit("u_jost")["procs"]
	check(off[0]["chance"] == 16 and off[1]["chance"] == 12 and on[0]["chance"] == 24 and on[1]["chance"] == 18, "Jost on a demon's seal: Echo 16 to 24, Recoil 12 to 18")
	var real_patron: Dictionary = m.seal_ground["patron"]
	m.seal_ground["patron"] = _pa.row("pat_02")          # Jost is Agares' (pat_02): at home
	var home: Array = m._combatant_for_unit("u_jost")["procs"]
	check(home[0]["chance"] == 36, "...and at home on his own patron's ground: 16 x 1.5 x 1.5 = 36")
	m.seal_ground["patron"] = real_patron
	var arch := {"enemy_id": "ea_t", "name": "Foe", "weapon_art": "sword", "weapon_tier": "basic", "movement_type": "infantry", "level": 5, "hp": 40, "str": 3, "mag": 0, "dex": 0, "spd": 0, "lck": 0, "def": 0, "res": 0, "affiliation": "state", "death_noun": "lance"}
	m._spawn_enemy_instance(arch, Vector2i(10, 6), "mook", 0)
	m._spawn_enemy_instance(arch, Vector2i(11, 9), "mook", 1)
	var e_on: Array = m._enemy_combatant(m.enemies[0])["procs"]
	var e_off: Array = _pa.procs_for_enemy(arch, m._enemy_key(m.enemies[0]))
	check(e_on[0]["chance"] == int(round(e_off[0]["chance"] * 1.5)), "an enemy standing on a seal is scaled just the same")
	check(m._enemy_combatant(m.enemies[1])["procs"] == _pa.procs_for_enemy(arch, m._enemy_key(m.enemies[1])), "...and one beside it is not")
	m.queue_free()
	await process_frame

	var syn: Array = _pa.seal_scale([_pr("blessing", 100), _pr("curse", 3)], "balanced", "pat_00")
	check(syn.size() == 2 and syn[0]["chance"] == 80 and syn[1]["chance"] == 4, "shared ground: 125% with the ceiling at twice the max (100 to 80), rounded (3 to 4)")
	check(_pa.seal_scale([_pr("blessing", 0)], "demon", "pat_00").is_empty(), "a gift scaled to nothing is dropped")

	# ---- the Pardoner breaks a seal
	_gs.reset()
	_join(["u_rinsa", "u_jost"])
	_gs.progression["u_rinsa"]["class_id"] = "cls_pardoner"
	m = await _map("map_d02", ["u_rinsa", "u_jost"], [Vector2i(6, 7), Vector2i(10, 9)])
	check(_p.can_unseal("u_rinsa") and not _p.can_unseal("u_jost"), "only the Pardoner can")
	check(not m._break_seal(Vector2i(0, 0)) and m.seals.size() == 2, "breaking a tile with no seal does nothing")
	m._update_status_label()
	check(m.status_label.text.contains("[U] unseal"), "the control shows for a map with a Pardoner and seals")
	m.selected_unit_index = m.units.find(m.units.filter(func(u): return u["punit_id"] == "u_jost")[0])
	m._unhandled_input(_key(KEY_U))
	check(m.info_label.text.contains("has no way to break a seal") and m.seals.size() == 2, "anyone else cannot")
	m.selected_unit_index = m.units.find(m.units.filter(func(u): return u["punit_id"] == "u_rinsa")[0])
	m.unit_positions["u_rinsa"] = Vector2i(2, 9)
	m._unseal()
	check(m.info_label.text.contains("No seal on or beside") and m.seals.size() == 2, "a Pardoner far from any seal breaks none")
	m.unit_positions["u_rinsa"] = Vector2i(6, 7)
	m._unhandled_input(_key(KEY_U))
	check(m.seals.size() == 1 and not m.seals.has(Vector2i(6, 6)) and m.info_label.text.contains("breaks the seal of Ronove") and m.attacked_this_turn.has("u_rinsa"), "U breaks the seal beside them, and it takes their action")
	m._unseal()
	check(m.info_label.text.contains("already acted") and m.seals.size() == 1, "once a turn")
	m.attacked_this_turn.erase("u_rinsa")
	m.unit_positions["u_rinsa"] = Vector2i(10, 7)
	m.map_won = true
	m._unseal()
	check(m.seals.size() == 1, "nothing is broken once the field is won")
	m.map_won = false
	m.unit_positions["u_rinsa"] = Vector2i(6, 7)
	m.unit_positions["u_jost"] = Vector2i(6, 6)
	check(m._combatant_for_unit("u_jost")["procs"][0]["chance"] == 16, "a broken seal scales no one")
	var snap: Dictionary = m.capture_state()
	check(snap["seals_left"].size() == 1, "a suspended battle remembers which seals are left")
	m.queue_free()
	await process_frame
	m = await _map("map_d02", ["u_rinsa", "u_jost"])
	m._restore_progress(snap)
	check(m.seals.size() == 1 and m.seals.has(Vector2i(10, 6)), "...and breaks the same ones on resuming")
	m.queue_free()
	await process_frame

	# ---- a memory has none
	_gs.reset()
	m = await _map("map_f01", [])
	check(m.seals.is_empty() and m.seal_ground.is_empty(), "a memory has no bound ground")
	m.queue_free()
	await process_frame
