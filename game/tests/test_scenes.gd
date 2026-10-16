extends SceneTree
## Headless checks for the scene pipeline (canon scenes tab): which scenes are available, shown once, how a
## card reads, the scene screen, and the two places scenes are staged -- before a chapter's map and on the way
## out of a won one.
## Run from the repo root:
##   godot --headless --path game --script res://tests/test_scenes.gd
## Exits 0 if every check passes, 1 otherwise.

var _failures: int = 0
var _checks: int = 0
var _p: Node
var _gs: Node
var _s: Node

func check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: ", label)

func _initialize() -> void:
	_p = root.get_node("Progression")
	_gs = root.get_node("GameState")
	_s = root.get_node("Scenes")
	await process_frame
	await _run()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)

func _key(k: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.pressed = true
	return ev

func _run() -> void:
	# ---- canon
	var types := {}
	for r in _s.rows():
		types[r["type"]] = int(types.get(r["type"], 0)) + 1
	check(_s.rows().size() == 37 and types == {"post-battle": 31, "pre-battle": 5, "narrative": 1}, "37 scenes: 31 after the battle, 5 before (Anna's among them), 1 narrative (%s)" % str(types))

	# ---- conditions
	_gs.reset()
	check(not _s.available(_s.row("sc_h33_mercy_subterfuge")) and _s.pending("ch_h33_mercy", "pre-battle").is_empty(), "a scene that reads the verdict waits for one")
	_gs.set_flag("flag_hierophant_verdict", "mercy")
	check(_s.available(_s.row("sc_h33_mercy_subterfuge")) and _s.pending("ch_h33_mercy", "pre-battle") == ["sc_h33_mercy_subterfuge"], "...and shows once there is one")
	check(not _s.available(_s.row("sc_x11_writ")), "a scene that features Ricberta or Emmerich waits until one has joined")
	_p.state("u_emmerich")
	check(_s.available(_s.row("sc_x11_writ")), "...either will do")
	check(not _s.available(_s.row("sc_e31_ledger")), "the Ledger scene needs Maren or Kest")
	_p.state("u_kest")
	check(_s.available(_s.row("sc_e31_ledger")), "...flag_deaths is the epilogue record, always there")
	check(_s.available(_s.rows().filter(func(r): return r["chapter_id"] == "ch_d04")[0]), "a plain scene has no conditions")

	# ---- Anna's one fixed scene
	_gs.reset()
	var anna: Dictionary = _s.row("sc_anna_fixed")
	check(anna["chapter_id"] == "ch_rf20" and anna["type"] == "pre-battle" and _s.speakers(anna) == "Avatar, Anna", "Anna's scene: the eve of the Reunion, the avatar and Anna (%s)" % _s.speakers(anna))
	check(not _s.available(anna) and _s.pending("ch_rf20", "pre-battle").is_empty(), "it waits until she has been with the company")
	_gs.defections["def_anselm"] = {"state": "gone"}
	_gs.defections["def_maren"] = {"state": "gone"}
	check(_s.available(anna) and _s.pending("ch_rf20", "pre-battle") == ["sc_anna_fixed"], "...with both defections resolved she is with it, and the scene is waiting")
	_gs.guests["gst_anna"] = "departed"
	check(_s.available(anna), "(and a guest who has gone still counts as met)")
	_gs.reset()
	_gs.defections["def_anselm"] = {"state": "gone"}
	check(not _s.available(anna), "one defection alone does not bring her")
	_gs.reset()

	# ---- shown once
	_gs.reset()
	var d04: Array = _s.pending("ch_d04", "post-battle")
	check(d04.size() == 1 and _s.pending("ch_d04", "pre-battle").is_empty() and _s.pending("ch_nope", "post-battle").is_empty(), "a chapter's scene is waiting after its battle, not before, and no other chapter has it")
	_s.mark_seen(d04[0])
	check(_s.pending("ch_d04", "post-battle").is_empty() and _s.seen(d04[0]), "once shown it is not shown again")
	var d: Dictionary = _gs.to_dict()
	check(d["scenes_seen"] == {d04[0]: true} and _gs.validate(d) == "", "what has been seen is saved")
	_gs.reset()
	check(_gs.scenes_seen.is_empty(), "a new run sees them all again")

	# ---- the card
	check(_s.speakers(_s.row("sc_h31_capture")) == "Avatar, Methodios" and _s.speakers(_s.row("sc_x11_writ")) == "Avatar, the church surveyor", "speakers by name, units and npcs alike")
	var c: Dictionary = _s.card(_s.rows().filter(func(r): return r["chapter_id"] == "ch_k22")[0]["scene_id"])
	check(c["title"] == "What Feeds the Colossus -- after the battle" and c["note"].contains("no script yet") and c["text"] != "", "a card: chapter and when, the summary, and that it has no script yet (%s)" % c["title"])
	check(_s.card("sc_e31_ledger")["title"].ends_with("before the battle"), "a pre-battle card says so")
	check(not _s.has_script({"word_count": "0"}) and _s.has_script({"word_count": "340"}), "a scene with words has a script")

	# ---- the screen
	var ids: Array = ["sc_h31_capture", "sc_x11_writ"]
	var path: String = _s.stage(ids, "res://scenes/map_d04.tscn")
	check(path == "res://scenes/scene_screen.tscn" and _s.queue == ids and _s.next_path == "res://scenes/map_d04.tscn", "staging sets the queue and where to go next")
	var sc: Node = load(path).instantiate()
	root.add_child(sc)
	await process_frame
	check(_s.seen("sc_h31_capture") and not _s.seen("sc_x11_writ") and sc._title.text.contains("after the battle") and sc._speakers.text.contains("Methodios"), "the first card is shown, and counted as seen")
	check(not sc.advance() and _s.seen("sc_x11_writ") and sc._footer.text.contains("Scene 2 of 2"), "Enter shows the next")
	check(sc.advance() and _s.queue.is_empty() and _s.next_path == "res://scenes/overworld.tscn", "...and then the screen is done, and the hand-off is cleared")
	sc.queue_free()
	await process_frame
	_gs.reset()
	_s.stage(["sc_h31_capture", "sc_x11_writ", "sc_e32_perverse"], "res://scenes/overworld.tscn")
	sc = load("res://scenes/scene_screen.tscn").instantiate()
	root.add_child(sc)
	await process_frame
	sc._unhandled_input(_key(KEY_ESCAPE))
	check(_s.seen("sc_h31_capture") and _s.seen("sc_x11_writ") and _s.seen("sc_e32_perverse"), "Escape skips the rest, which still count as seen")
	sc.queue_free()
	await process_frame

	# ---- before a chapter's map
	_gs.reset()
	_gs.set_flag("flag_hierophant_verdict", "execution")
	var ow: Node2D = load("res://scenes/overworld.tscn").instantiate()
	ow.animate = false
	root.add_child(ow)
	await process_frame
	var war1: Dictionary = {}
	for lid in ow.locations:
		for e in ow.locations[lid]["chapters"]:
			if e.chapter["chapter_id"] == "ch_h34_war1":
				war1 = e
	var map_path: String = ow.scene_for(war1)
	var staged: String = ow.launch_path(war1)
	check(staged == "res://scenes/scene_screen.tscn" and _s.queue == ["sc_h34_war1"] and _s.next_path == map_path, "a chapter with a scene before its battle goes to the scene first, then the map")
	_s.mark_seen("sc_h34_war1")
	check(ow.launch_path(war1) == map_path, "...once")
	var plain: Dictionary = {}
	for lid in ow.locations:
		for e in ow.locations[lid]["chapters"]:
			if e.chapter["chapter_id"] == "ch_d04":
				plain = e
	check(ow.launch_path(plain) == ow.scene_for(plain) and ow.launch_path(plain) != "res://scenes/scene_screen.tscn", "a chapter whose scene comes after goes straight to its map")
	ow.queue_free()
	await process_frame

	# ---- on the way out of a won map
	_gs.reset()
	var m: Node = load("res://scenes/map_d04.tscn").instantiate()
	m.enemy_phase_enabled = false
	root.add_child(m)
	await process_frame
	check(m._way_out() == "res://scenes/overworld.tscn", "before the win, out is the overworld")
	m.map_won = true
	await process_frame
	check(m._way_out() == "res://scenes/scene_screen.tscn" and _s.queue.size() == 1 and _s.next_path == "res://scenes/overworld.tscn", "a won map leads out through its post-battle scene")
	_s.mark_seen(_s.queue[0])
	check(m._way_out() == "res://scenes/overworld.tscn", "...and plainly once it has been seen")
	m.queue_free()
	await process_frame
	_gs.reset()
	var f: Node = load("res://scenes/map_f01.tscn").instantiate()
	f.enemy_phase_enabled = false
	root.add_child(f)
	await process_frame
	f.map_won = true
	await process_frame
	check(f._way_out() == "res://scenes/overworld.tscn", "a memory has no scenes")
	f.queue_free()
	await process_frame
