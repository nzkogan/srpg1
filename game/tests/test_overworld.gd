extends SceneTree
## Headless checks for the overworld map: the location/path graph, walking the
## party along it, which chapters are open, and that where you stand is saved.
## Run from the repo root:
##   godot --headless --path game --script res://tests/test_overworld.gd
## Exits 0 if every check passes, 1 otherwise.

var _failures: int = 0
var _checks: int = 0
var _gs: Node

func check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: ", label)

func _initialize() -> void:
	_gs = root.get_node("GameState")
	await process_frame
	await _run()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)

func _fresh() -> Node2D:
	_gs.reset()
	var ow: Node2D = load("res://scenes/overworld.tscn").instantiate()
	ow.animate = false
	root.add_child(ow)
	return ow

func _free(ow: Node) -> void:
	ow.queue_free()

func _win(ids: Array) -> void:
	for m in ids:
		_gs.won_maps[m] = true

func _status(ow: Node2D, chapter_id: String) -> String:
	for lid in ow.locations:
		for e in ow.locations[lid]["chapters"]:
			if e.chapter["chapter_id"] == chapter_id:
				return ow.chapter_state(e)["status"]
	return "?"

func _reason(ow: Node2D, chapter_id: String) -> String:
	for lid in ow.locations:
		for e in ow.locations[lid]["chapters"]:
			if e.chapter["chapter_id"] == chapter_id:
				return ow.chapter_state(e)["reason"]
	return "?"

func _key(ow: Node, keycode: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.pressed = true
	ow._unhandled_input(ev)

func _run() -> void:
	# ---- the graph, as canon lays it out
	var ow := _fresh()
	await process_frame
	check(ow.locations.size() == 36 and ow.edges.size() == 38, "36 locations and 38 paths load (%d, %d)" % [ow.locations.size(), ow.edges.size()])
	var on_canvas := true
	for lid in ow.locations:
		var p: Vector2 = ow.locations[lid]["pos"]
		if p.x < 0 or p.x > ow.WORLD_W or p.y < 0 or p.y > ow.WORLD_H:
			on_canvas = false
	check(on_canvas, "every location sits on the canvas")
	var distinct := {}
	for lid in ow.locations:
		distinct[ow.locations[lid]["pos"]] = true
	check(distinct.size() == ow.locations.size(), "and no two share a spot")
	var unreachable: Array[String] = []
	for lid in ow.locations:
		if lid != ow.FLASHBACK_LOCATION and ow.path_between("loc_tally_house", lid).is_empty():
			unreachable.append(lid)
	check(unreachable.is_empty(), "every place but the memory can be walked to from the tally house (%s)" % str(unreachable))
	check(ow.path_between("loc_tally_house", ow.FLASHBACK_LOCATION).is_empty() and ow.path_between(ow.FLASHBACK_LOCATION, "loc_tally_house").is_empty(), "the memory has no road in or out")
	check(ow.path_between("loc_tally_house", "loc_tally_house") == ["loc_tally_house"], "a trip to where you are is just there")
	check(ow.path_between("loc_tally_house", "loc_weighbridge") == ["loc_tally_house", "loc_weighbridge"], "neighbours are one step")
	var fwd: Array[String] = ow.path_between("loc_tally_house", "loc_thessala")
	var back: Array[String] = ow.path_between("loc_thessala", "loc_tally_house")
	var rev := fwd.duplicate()
	rev.reverse()
	check(fwd == ["loc_tally_house", "loc_weighbridge", "loc_grain_road", "loc_thessala"] and back == rev, "paths are two-way (%s)" % str(fwd))
	check(ow.path_between("loc_vetch_gate", "loc_vetch_chapel") == ["loc_vetch_gate", "loc_vetch_chapel"], "the shortest chain wins (Vetch's two halves are joined directly, not round the whole assembly route)")
	var pts: Array = ow.walk_points(["loc_dry_country", "loc_vashti_road"])
	check(pts.size() == 4 and pts[0] == ow.locations["loc_dry_country"]["pos"] and pts[3] == ow.locations["loc_vashti_road"]["pos"], "a walk follows a path's bends (waypoints) from end to end")
	var pts_back: Array = ow.walk_points(["loc_vashti_road", "loc_dry_country"])
	var pts_rev := pts.duplicate()
	pts_rev.reverse()
	check(pts_back == pts_rev, "and the same bends in reverse coming back")
	var two: Array = ow.walk_points(["loc_tally_house", "loc_weighbridge", "loc_grain_road"])
	check(two.size() == 3, "two hops share their middle point instead of repeating it")
	check(ow.path_between("loc_weighbridge", "loc_cinder_track") == ["loc_weighbridge", "loc_grain_road", "loc_reunion_field", "loc_glass_edge", "loc_cinder_track"],
		"a route found first isn't kept if a shorter one turns up later (%s)" % str(ow.path_between("loc_weighbridge", "loc_cinder_track")))
	_free(ow)
	await process_frame

	# ---- where the party starts
	ow = _fresh()
	await process_frame
	check(ow.party_location == "loc_ur_nashet" and ow._marker.position == ow.locations["loc_ur_nashet"]["pos"], "a new game starts in the memory, marker and all")
	_free(ow)
	await process_frame
	_gs.reset()
	_win(["map_f00"])
	ow = load("res://scenes/overworld.tscn").instantiate()
	root.add_child(ow)
	await process_frame
	check(ow.party_location == "loc_tally_house", "once the prologue is won, the party is at the tally house")
	_free(ow)
	await process_frame
	_gs.reset()
	_gs.world_location = "loc_anthe"
	ow = load("res://scenes/overworld.tscn").instantiate()
	root.add_child(ow)
	await process_frame
	check(ow.party_location == "loc_anthe" and ow._marker.position == ow.locations["loc_anthe"]["pos"], "a saved location is where the party stands")
	_free(ow)
	await process_frame
	_gs.reset()
	_gs.world_location = "loc_nowhere"
	ow = load("res://scenes/overworld.tscn").instantiate()
	root.add_child(ow)
	await process_frame
	check(ow.party_location == "loc_ur_nashet", "an unknown saved location is ignored")
	_free(ow)
	await process_frame

	# ---- unlocking
	ow = _fresh()
	await process_frame
	check(_status(ow, "ch_f00") == "open", "the prologue is open from the start")
	check(_status(ow, "ch_d01") == "locked" and _reason(ow, "ch_d01").contains("opens after Ur-Nashet, the last night"), "the first chapters wait for it (%s)" % _reason(ow, "ch_d01"))
	check(_status(ow, "ch_a01") == "locked" and _status(ow, "ch_x11") == "locked", "as does everything after")
	_win(["map_f00"])
	check(_status(ow, "ch_f00") == "won" and _status(ow, "ch_d01") == "open" and _status(ow, "ch_a01") == "open", "winning it opens both routes' first chapter")
	check(_status(ow, "ch_d02") == "locked" and _status(ow, "ch_a02") == "locked", "but only the first")
	_win(["map_d01"])
	check(_status(ow, "ch_d02") == "open" and _status(ow, "ch_a02") == "locked", "a route advances on its own chapters")
	check(_status(ow, "ch_x11") == "locked", "the muster waits for the end of a route")
	_win(["map_a10"])
	check(_status(ow, "ch_x11") == "open", "ANY route's last chapter opens it (the assembly alone is enough)")
	check(_status(ow, "ch_v21") == "locked" and _status(ow, "ch_m21") == "locked", "the Act 2 chapters wait for it")
	_win(["map_x11"])
	check(_status(ow, "ch_v21") == "open" and _status(ow, "ch_m21") == "open", "and open once it is won")
	check(_status(ow, "ch_c21") == "locked", "the reunion at Vetch needs the end of either Act 2 route")
	_win(["map_m21", "map_m22"])
	check(_status(ow, "ch_c21") == "open", "(the assembly's Act 2 is enough)")
	check(_status(ow, "ch_rf20") == "locked" and _status(ow, "ch_tp19") == "locked" and _status(ow, "ch_ct19") == "locked", "the columns wait for it")
	_win(["map_c21"])
	check(_status(ow, "ch_b15") == "open" and _status(ow, "ch_ct19") == "open" and _status(ow, "ch_tp19") == "locked", "column A opens, column B's second half waits for its first")
	_win(["map_ct19"])
	check(_status(ow, "ch_rf20") == "open", "either column opens the reunion field")
	check(_status(ow, "ch_p_anzu") == "open" and _status(ow, "ch_p_huma") == "open", "the paralogues set to open after the muster do")
	check(_status(ow, "ch_p_karkadann") == "open", "and the one set to open at the end of Act 1 does")
	_free(ow)
	await process_frame

	# the Hierophant's gate still holds
	ow = _fresh()
	await process_frame
	_win(["map_k22", "map_h31"])
	check(_status(ow, "ch_h32") == "open", "the trial opens after the capture")
	check(_status(ow, "ch_h33_mercy") == "locked" and _reason(ow, "ch_h33_mercy").contains("Kaisareia Trial"), "mercy and war wait for a verdict (%s)" % _reason(ow, "ch_h33_mercy"))
	_gs.set_flag(ow.HIEROPHANT_FLAG, "mercy")
	check(_status(ow, "ch_h32") == "won", "giving a verdict wins the trial")
	check(_status(ow, "ch_h33_mercy") == "open", "mercy opens on a mercy verdict")
	check(_status(ow, "ch_h34_war1") == "locked" and _reason(ow, "ch_h34_war1").contains("shut for good"), "and the war is shut for good this run (%s)" % _reason(ow, "ch_h34_war1"))
	_gs.set_flag(ow.HIEROPHANT_FLAG, "execution")
	check(_status(ow, "ch_h34_war1") == "open" and _status(ow, "ch_h33_mercy") == "locked", "an execution verdict flips it")
	check(_status(ow, "ch_h34_war2") == "locked", "the war's later fronts wait for the first")
	# free roam
	ow = ow
	var before := _status(ow, "ch_x11")
	_key(ow, KEY_U)
	check(ow.free_roam and before == "locked" and _status(ow, "ch_x11") == "open", "U (free roam) opens what is only locked by progress")
	check(_status(ow, "ch_h33_mercy") == "locked", "...but not what the verdict has ruled out")
	check(ow.info_label.text.contains("free roam (ON)"), "and the panel says it is on")
	_key(ow, KEY_U)
	check(not ow.free_roam and _status(ow, "ch_x11") == "locked", "U again turns it off")
	_free(ow)
	await process_frame

	# ---- what a location offers
	ow = _fresh()
	await process_frame
	check(ow.location_status("loc_tally_house") == "locked" and ow.next_chapter("loc_tally_house").is_empty(), "a place with nothing open is locked, with no next chapter")
	_win(["map_f00"])
	check(ow.location_status("loc_tally_house") == "open" and ow.next_chapter("loc_tally_house").chapter["chapter_id"] == "ch_d01", "the tally house is open, offering the first chapter")
	_win(["map_d01"])
	check(ow.location_status("loc_tally_house") == "won" and ow.next_chapter("loc_tally_house").is_empty(), "all won: status won")
	check(ow.chapter_to_play("loc_tally_house").chapter["chapter_id"] == "ch_d01", "Enter then replays it")
	check(ow.chapter_to_play("loc_vashti_road").is_empty(), "a place with nothing open or won has nothing to play")
	_win(["map_d09", "map_d10", "map_x11"])
	check(ow.next_chapter("loc_vashti_gate").chapter["chapter_id"] == "ch_v21", "Vashti gate: the Act 1 chapter was won, so Act 2's first is next")
	check(ow.location_status("loc_vashti_gate") == "open", "(with v22 still locked behind it, the place is open)")
	_win(["map_v21"])
	check(ow.next_chapter("loc_vashti_gate").chapter["chapter_id"] == "ch_v22", "then the second in order")
	_win(["map_b15", "map_c21", "map_v22"])
	var order: Array[String] = []
	for e in ow.locations["loc_caravanserai"]["chapters"]:
		order.append(e.chapter["chapter_id"])
	check(order.size() == 5 and order.slice(0, 3) == ["ch_b15", "ch_r16", "ch_e31"], "a place's chapters are in story order, acts first (%s)" % str(order))
	_free(ow)
	await process_frame

	# ---- node colours
	ow = _fresh()
	await process_frame
	_win(["map_f00", "map_d01"])
	ow._recolor_nodes()
	check(ow._node_rects["loc_ur_nashet"].color == ow.WON_COLOR, "a won place is green")
	check(ow._node_rects["loc_tally_house"].color == ow.WON_COLOR and ow._node_rects["loc_weighbridge"].color == ow.AVAILABLE_COLOR, "an open place is blue")
	check(ow._node_rects["loc_grain_road"].color == ow.LOCKED_COLOR, "a locked one is grey")
	_free(ow)
	await process_frame

	# ---- travel
	ow = _fresh()
	await process_frame
	_win(["map_f00"])
	check(ow.travel_to("loc_weighbridge") and ow.party_location == "loc_weighbridge", "with animation off, travel is instant")
	check(_gs.world_location == "loc_weighbridge", "and where the party stands is recorded in the playthrough")
	check(ow._marker.position == ow.locations["loc_weighbridge"]["pos"], "the marker is on the place")
	check(ow.info_label.text.contains("The weighbridge"), "the panel describes it (%s)" % ow.info_label.text.get_slice("\n", 0))
	check(not ow.travel_to("loc_nowhere"), "an unknown place is refused")
	ow.travel_to("loc_ur_nashet")
	check(ow.party_location == "loc_ur_nashet", "the memory is reached by memory (no road needed)")
	ow.travel_to("loc_tally_house")
	check(ow.party_location == "loc_tally_house", "and left the same way")
	_free(ow)
	await process_frame

	# a real walk
	ow = _fresh()
	ow.animate = true
	await process_frame
	_win(["map_f00"])
	ow.travel_to("loc_tally_house")
	check(ow.party_location == "loc_tally_house" and not ow.is_walking(), "(a jump from the memory is instant even with animation on)")
	ow.party_location = "loc_tally_house"
	ow._marker.position = ow.locations["loc_tally_house"]["pos"]
	check(ow.travel_to("loc_grain_road") and ow.is_walking() and ow.party_location == "loc_tally_house", "with animation on, the party sets off and hasn't arrived")
	check(ow.info_label.text.contains("Walking to The grain road"), "the panel says where it is going")
	check(not ow.travel_to("loc_thessala"), "it can't be redirected mid-walk")
	ow.enter_location()
	check(ow.is_walking() and ow.party_location == "loc_tally_house", "Enter does nothing mid-walk")
	ow._process(0.2)
	var mid: Vector2 = ow._marker.position
	var a: Vector2 = ow.locations["loc_tally_house"]["pos"]
	var b: Vector2 = ow.locations["loc_grain_road"]["pos"]
	check(ow.is_walking() and mid != a and mid.distance_to(b) > 5.0 and mid.y >= minf(a.y, b.y) - 1.0, "after a moment the marker is partway along the road (%s)" % str(mid))
	var steps := 0
	while ow.is_walking() and steps < 200:
		ow._process(0.1)
		steps += 1
	check(not ow.is_walking() and ow.party_location == "loc_grain_road" and ow._marker.position == b, "and it arrives exactly (%d steps)" % steps)
	check(_gs.world_location == "loc_grain_road", "recorded on arrival, not on setting off")
	check(ow.travel_to("loc_grain_road") and not ow.is_walking(), "travelling to where you stand doesn't walk")
	_free(ow)
	await process_frame

	# ---- clicks
	ow = _fresh()
	await process_frame
	_win(["map_f00"])
	ow.party_location = "loc_tally_house"
	ow.click_at(ow.locations["loc_weighbridge"]["pos"] + Vector2(5, 5))
	check(ow.party_location == "loc_weighbridge", "clicking a place walks there")
	ow.click_at(Vector2(5, 530))
	check(ow.party_location == "loc_weighbridge", "clicking empty ground does nothing")
	ow.launch_enabled = false
	var launched: Array = []
	ow.chapter_launched.connect(func(id): launched.append(id))
	ow.click_at(ow.locations["loc_weighbridge"]["pos"])
	check(launched.is_empty(), "weighbridge is still locked: clicking it again plays nothing")
	_win(["map_d01"])
	ow.click_at(ow.locations["loc_weighbridge"]["pos"] + Vector2(3, 3))
	check(launched == ["ch_d02"], "clicking the place you stand on plays its next chapter (%s)" % str(launched))
	ow.enter_location()
	check(launched == ["ch_d02", "ch_d02"], "as does Enter")
	_key(ow, KEY_ENTER)
	check(launched.size() == 3, "(and the Enter key)")
	_win(["map_d02"])
	ow.enter_location()
	check(launched.size() == 4 and launched[3] == "ch_d02", "once won, Enter replays it")
	ow.travel_to("loc_thessala")
	ow.enter_location()
	check(launched.size() == 4, "a place with nothing to play does nothing but say so")
	check(ow.info_label.text.contains("opens after") or ow.info_label.text.contains("Nothing here"), "(%s)" % ow.info_label.text.replace("\n", " / "))
	_free(ow)
	await process_frame

	# ---- saving
	_gs.reset()
	_gs.world_location = "loc_anthe"
	var snap: Dictionary = _gs.to_dict()
	check(snap.has("world_location") and snap["world_location"] == "loc_anthe", "the party's place is in the saved state")
	_gs.reset()
	check(_gs.world_location == "", "a new game clears it")
	check(_gs.validate({"world_location": 5}) != "" and _gs.validate({"world_location": "loc_anthe"}) == "", "a wrong-typed place is refused, a string accepted")
	_gs.from_dict(snap)
	check(_gs.world_location == "loc_anthe", "and a loaded save puts it back")
	_gs.from_dict({"gold": 3})
	check(_gs.world_location == "", "an older save with no place starts the party at the default")
	_gs.reset()
