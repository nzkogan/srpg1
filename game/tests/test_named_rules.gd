extends SceneTree
## Headless checks for "the Named know each other" (canon named.notes): killing a Named stand-in is
## remembered for the run, and once enough have been killed no Named will be captured -- no intact
## mount, no harvest -- while ordinary enemies still can be.
## Run from the repo root:
##   godot --headless --path game --script res://tests/test_named_rules.gd
## Exits 0 if every check passes, 1 otherwise.

var _failures: int = 0
var _checks: int = 0
var _p: Node
var _gs: Node
var _f: Node
var _m: Node

func check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: ", label)

func _initialize() -> void:
	_p = root.get_node("Progression")
	_gs = root.get_node("GameState")
	_f = root.get_node("Forge")
	_m = root.get_node("Mounts")
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
		"level": 5, "hp": 200, "str": 0, "mag": 0, "dex": 0, "spd": 0, "lck": 0, "def": 0, "res": 0, "affiliation": "state", "death_noun": "lance"}
	d.merge(over, true)
	return d

func _select(m: Node, uid: String) -> void:
	m.selected_unit_index = m.units.find(m.units.filter(func(u): return u["punit_id"] == uid)[0])

func _run() -> void:
	# ---- the record
	check(_p.param("named_wary_kills") == 1, "parameter: one kill is enough")
	_gs.reset()
	check(not _f.named_wary() and _f.wary_reason() == "" and _gs.named_slain.is_empty(), "a fresh run: the Named have heard nothing")
	check(_f.note_named_slain("ea_looter") == "" and _f.note_named_slain("ea_nobody") == "" and _gs.named_slain.is_empty(), "an ordinary enemy, or a stranger, is not a Named kill")
	var warn: String = _f.note_named_slain("ea_karkadann")
	check(warn.contains("The Named know each other") and _gs.named_slain == ["nmd_karkadann"], "killing the Karkadann's stand-in is remembered, and the line warns: %s" % warn)
	check(_f.note_named_slain("ea_karkadann") == "" and _gs.named_slain.size() == 1, "...once per creature")
	check(_f.named_wary() and _f.wary_reason().contains("the death of the Karkadann"), "now the rest are wary, and the reason names the dead: %s" % _f.wary_reason())
	var line: String = _f.on_named_defeated("ea_anzu", "killed")
	check(line.contains("yields") and not line.contains("know each other") and _gs.named_slain.size() == 2, "a second kill yields its material but does not repeat the warning")
	check(_f.wary_reason().contains("Karkadann") and not _f.wary_reason().contains("Anzu"), "(the reason names the first to fall)")
	_gs.reset()
	check(_f.on_named_defeated("ea_shadhavar", "captured").contains("diminished") and _gs.named_slain.is_empty() and not _f.named_wary(), "a capture is not a kill: nothing is remembered")
	var first: String = _f.on_named_defeated("ea_simurgh", "killed")
	check(first.contains("prime material") and first.contains("know each other"), "a first kill gives the material and the warning together: %s" % first)
	_gs.reset()
	_p._params["named_wary_kills"] = 2.0
	_f.note_named_slain("ea_simurgh")
	check(not _f.named_wary(), "(with the threshold at 2, one kill is not enough)")
	_f.note_named_slain("ea_anzu")
	check(_f.named_wary(), "...two are")
	_p._params["named_wary_kills"] = 1.0

	# ---- saved with the run
	_gs.reset()
	_f.note_named_slain("ea_karkadann")
	var d: Dictionary = _gs.to_dict()
	check(d["named_slain"] == ["nmd_karkadann"] and _gs.validate(d) == "", "it is part of the saved state")
	_gs.reset()
	check(_gs.named_slain.is_empty(), "a new run starts clean")

	# ---- on the map
	var named_arch := _arch("The Karkadann", {"enemy_id": "ea_karkadann", "named_id": "nmd_karkadann", "hp": 100, "movement_type": "riding", "affiliation": "named"})
	_gs.reset()
	_join(["u_gunnar"])
	var m: Node = await _map("map_d02", ["u_gunnar"], [Vector2i(8, 8)], [{"arch": named_arch, "pos": Vector2i(10, 8), "kind": "boss"}])
	_select(m, "u_gunnar")
	m.enemies[0].hp = 40
	check(m._capture_text("u_gunnar", m.enemies[0]).contains("Capture ready"), "before any killing the Named can be taken")
	m.queue_free()
	await process_frame

	_gs.reset()
	_join(["u_gunnar"])
	_f.note_named_slain("ea_simurgh")
	m = await _map("map_d02", ["u_gunnar"], [Vector2i(8, 8)], [{"arch": named_arch, "pos": Vector2i(10, 8), "kind": "boss"}, {"arch": _arch("Hand", {"hp": 100}), "pos": Vector2i(8, 10)}])
	_select(m, "u_gunnar")
	m.enemies[0].hp = 20                      # well inside the intact threshold
	check(m._capture_text("u_gunnar", m.enemies[0]).contains("the Named know each other") and m._capture_text("u_gunnar", m.enemies[0]).contains("Simurgh"), "after a kill the forecast says it will not be taken, and why: %s" % m._capture_text("u_gunnar", m.enemies[0]))
	m._capture_enemy()
	check(not m.enemies[0].defeated and m.info_label.text.contains("cannot be captured") and _m.stable().is_empty() and _gs.materials.is_empty(), "...and the capture is refused: no mount, no material")
	m.enemies[1].hp = 10
	check(m._capture_text("u_gunnar", m.enemies[1]).contains("Capture ready"), "an ordinary enemy can still be taken")
	# killing it is still open to them: the kill yields its material and counts
	m._defeat_enemy(m.enemies[0])
	check(_gs.materials.get("mat_karkadann") == "prime" and _gs.named_slain.has("nmd_karkadann") and _gs.named_slain.size() == 2, "killing it is open as ever: a prime material")
	m.queue_free()
	await process_frame

	# a kill on the map carries the warning into the map's lines
	_gs.reset()
	_join(["u_gunnar"])
	m = await _map("map_d02", ["u_gunnar"], [Vector2i(8, 8)], [{"arch": named_arch, "pos": Vector2i(10, 8), "kind": "boss"}])
	m._defeat_enemy(m.enemies[0])
	var notes: Array = m._take_material_notes()
	check(notes.size() == 1 and notes[0].contains("prime material") and notes[0].contains("know each other"), "the first kill's lines reach the map: %s" % str(notes))
	m.queue_free()
	await process_frame
