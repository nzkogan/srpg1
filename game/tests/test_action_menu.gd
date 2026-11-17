extends SceneTree
## Headless checks for the battle map's action menu: what it lists for a unit, that choosing an entry runs the same
## action as its hotkey, and that the menu (not the map) owns the keys while it is open.
## Run from the repo root:
##   godot --headless --path game --script res://tests/test_action_menu.gd
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

func _key(k: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.pressed = true
	return ev

func _labels(m: Node) -> Array:
	return m.action_entries().map(func(e): return e["label"])

func _run() -> void:
	_gs.reset()
	for u in ["u_gunnar", "u_edda", "u_solveig"]:
		_p.state(u)
	var m: Node = load("res://scenes/map_a02.tscn").instantiate()
	var ids: Array[String] = ["u_gunnar", "u_edda", "u_solveig"]
	m.deploy_unit_ids = ids
	m.enemy_phase_enabled = false
	root.add_child(m)
	await process_frame

	m.selected_unit_index = m.units.find(m.units.filter(func(u): return u["punit_id"] == "u_gunnar")[0])
	var g: Array = _labels(m)
	check(g.has("Attack") and g.has("Capture") and g.has("Shove") and g.has("Talk") and g.has("End turn") and g.has("Switch weapon"), "Gunnar (a bounty hunter) is offered attack, capture, shove, talk: %s" % str(g))
	check(not g.has("Bribe") and not g.has("Breach") and not g.has("Strike the statue"), "...and nothing his class does not carry")
	m.selected_unit_index = m.units.find(m.units.filter(func(u): return u["punit_id"] == "u_solveig")[0])
	var s: Array = _labels(m)
	check(not s.has("Capture") and s.has("Attack") and s.has("End turn"), "Solveig is not offered Capture: %s" % str(s))
	for e in m.action_entries():
		check(e["key"] is int and e["key"] > 0, "every entry carries a hotkey (%s)" % e["label"])

	# ---- Space opens it; the menu owns the keys while open
	check(not m.action_menu.is_open(), "closed to start")
	m._unhandled_input(_key(KEY_SPACE))
	check(m.action_menu.is_open() and m.action_menu.entries.size() == m.action_entries().size(), "Space opens it with the unit's entries")
	m._unhandled_input(_key(KEY_ESCAPE))
	check(not m.action_menu.is_open() and m.is_inside_tree(), "Escape closes the menu and does not leave the battle")
	var turn_before: int = m.turn
	m._unhandled_input(_key(KEY_SPACE))
	m._unhandled_input(_key(KEY_N))
	check(m.turn == turn_before and m.action_menu.is_open(), "a hotkey pressed while the menu is open does nothing")

	# ---- choosing an entry runs that action
	var end_at: int = m.action_menu.entries.map(func(e): return e["label"]).find("End turn")
	m.action_menu.index = 0
	for i in end_at:
		m._unhandled_input(_key(KEY_DOWN))
	check(m.action_menu.index == end_at, "Down moves to End turn")
	m._unhandled_input(_key(KEY_ENTER))
	check(not m.action_menu.is_open() and m.turn == turn_before + 1, "Enter on End turn ends the turn (turn %d -> %d)" % [turn_before, m.turn])
	m._unhandled_input(_key(KEY_SPACE))
	m._unhandled_input(_key(KEY_UP))
	check(m.action_menu.index == m.action_menu.entries.size() - 1, "Up from the top wraps to the bottom")
	m.action_menu.close()

	# ---- the hotkeys still work on their own
	turn_before = m.turn
	m._unhandled_input(_key(KEY_N))
	check(m.turn == turn_before + 1, "N still ends the turn without the menu")
	check(m.status_label.text.contains("[Space] / right-click: actions"), "the controls line says how to open it")
	m.queue_free()
	await process_frame

	# ---- the prologue offers the statue
	_gs.reset()
	var f: Node = load("res://scenes/map_f00.tscn").instantiate()
	f.enemy_phase_enabled = false
	root.add_child(f)
	await process_frame
	check(_labels(f).has("Strike the statue") and not _labels(f).has("Suspend") and not _labels(f).has("Talk"), "the prologue offers the statue, and no talk or suspend (a memory): %s" % str(_labels(f)))
	f.queue_free()
	await process_frame
