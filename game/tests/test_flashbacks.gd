extends SceneTree
## Headless checks for the flashbacks F1 and F2: the canon rows, the rules every memory shares (no permadeath,
## no income, a roster of its own), F1's copyists, clerk ledger and lost page, F2's free pact and falling court,
## and the party being taken into a memory when it falls due.
## Run from the repo root:
##   godot --headless --path game --script res://tests/test_flashbacks.gd
## Exits 0 if every check passes, 1 otherwise.

var _failures: int = 0
var _checks: int = 0
var _p: Node
var _gs: Node
var _canon: Node
var _fb: Node
var _e: Node

func check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: ", label)

func _initialize() -> void:
	_p = root.get_node("Progression")
	_gs = root.get_node("GameState")
	_canon = root.get_node("Canon")
	_fb = root.get_node("Flashback")
	_e = root.get_node("Epilogue")
	await process_frame
	await _run()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)

func _map(scene: String) -> Node:
	var m: Node = load("res://scenes/%s.tscn" % scene).instantiate()
	m.enemy_phase_enabled = false
	root.add_child(m)
	await process_frame
	var r := RandomNumberGenerator.new()
	r.seed = 5
	m.rng_override = r
	return m

func _ids(m: Node) -> Array:
	return m.units.map(func(u): return u["punit_id"])

func _run() -> void:
	# ---- canon
	var ch1: Dictionary = _canon.find_by("chapters", "chapter_id", "ch_f01")
	var ch2: Dictionary = _canon.find_by("chapters", "chapter_id", "ch_f02")
	check(ch1["act"] == "flashback" and ch1["unlock_after"] == "ch_d10|ch_a10" and ch2["act"] == "flashback" and ch2["unlock_after"] == "ch_rf20", "F1 opens after the Act 1 finale, F2 after the Reunion")
	check(_fb.rules("map_f01") == ["copyists", "clerk_ledger", "lost_page"] and _fb.rules("map_f02") == ["free_pact", "falls"] and _fb.rules("map_f00") == ["prologue"] and _fb.rules("map_d02").is_empty(), "each flashback names its mechanics")
	check(_fb.is_flashback("map_f00") and _fb.is_flashback("map_f01") and _fb.is_flashback("map_f02") and not _fb.is_flashback("map_d02") and not _fb.is_flashback("map_p_huma"), "the prologue and the two memories are flashbacks; no other map is")
	check(_fb.roster("map_f00").size() == 8 and _fb.roster("map_f01").size() == 5 and _fb.roster("map_f02").size() == 6 and _fb.roster("map_d02").is_empty(), "rosters of 8, 5 and 6, each its own")
	var pages := int(_p.param("flashback_register_pages"))
	check(pages == 12, "the copy has 12 pages")
	for id in ["map_f01", "map_f02"]:
		var mrow: Dictionary = _canon.find_by("maps", "map_id", id)
		var f := FileAccess.open("res://data/maps/%s.txt" % id, FileAccess.READ)
		var rows: Array = []
		while not f.eof_reached():
			var l := f.get_line()
			if l != "" and not l.begins_with("#"):
				rows.append(l)
		check(rows.size() == int(mrow["height"]) and rows[0].length() == int(mrow["width"]), "%s's grid is %dx%d" % [id, int(mrow["width"]), int(mrow["height"])])

	# ---- the shared laws
	_gs.reset()
	var m: Node = await _map("map_f01")
	check(m._is_flashback() and _ids(m).filter(func(i): return i.begins_with("pu_f1_")).size() == 5, "F1 deploys its own five")
	check(_ids(m).filter(func(i): return i.begins_with("cargo_f01_")).size() == 4 and m._cargo_needed() == 3, "...with four copyists, three of whom must live")
	check(m.enemies.size() == 8 and m.dens.is_empty(), "eight raiders, no dens")
	_p.state("u_jost")
	_gs.progression["u_jost"]["level"] = 10
	check(_e.note_fall("u_jost", "map_f01", {"type": "unknown"}).is_empty() and _e.note_fall("pu_f1_hadda", "map_f01", {"type": "unknown"}).is_empty() and _gs.epilogue.get("pending", {}).is_empty(), "nobody's fall is recorded: no permadeath in a memory")
	check(not _e.note_fall("u_jost", "map_d02", {"type": "unknown"}).is_empty(), "(on an ordinary map the same fall would be)")
	_gs.epilogue = {}
	check(not m._miracle_saves("pu_f1_hadda"), "F1 has no free pact")
	check(m.map_row["turn_limit"] == 8 and m.map_row["objective_verb"] == "defend", "defend for eight turns")

	# ---- F1: the clerk writes deeds down
	var inst: Dictionary = m.enemies[0]
	m._credit_kill("pu_f1_hadda", inst)
	m._credit_kill("pu_f1_hadda", inst)
	m._credit_kill("pu_f1_zimri", inst)
	check(m._clerk_lines.size() == 3 and m._clerk_lines[0].contains("under Hadda's name") and m._clerk_lines[0].contains("looter"), "each kill is written under the killer's name: %s" % m._clerk_lines[0])
	check(m._clerk_counts == {"Hadda": 2, "Zimri": 1}, "...and tallied")
	m._next_turn()
	check(m.info_label.text.contains("The clerk writes it under Hadda's name") and m.info_label.text.contains("tally: Hadda 2, Zimri 1") and m._clerk_lines.is_empty(), "the next turn shows the ledger, then clears it")
	# through a real fight
	m.enemies[1].pos = Vector2i(5, 8)
	m.enemies[1].hp = 1
	m.unit_positions["pu_f1_hadda"] = Vector2i(5, 9)
	m.selected_unit_index = _ids(m).find("pu_f1_hadda")
	m.attacked_this_turn.clear()
	var before: int = m._clerk_lines.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	m.rng_override = rng
	m.units[m.selected_unit_index]["dex"] = 80
	m._attack_enemy()
	check(m.enemies[1].defeated and m._clerk_lines.size() == before + 1, "a kill in a fight reaches the clerk")

	# ---- F1: the page is lost, silently
	var gold: int = _gs.gold
	check(not _gs.flags.has("flashback_f1_page_lost"), "nothing lost yet")
	m.turn = 7
	m._next_turn()
	check(m.map_won and m.turn == 8, "eight turns held: the copy is finished")
	var lost := int(_gs.flags.get("flashback_f1_page_lost", "0"))
	check(lost >= 1 and lost <= 12, "a page is lost (kept only as a hidden flag: %d)" % lost)
	var shown: String = (m.info_label.text + " " + m.status_label.text + " " + m._reward_text).to_lower()
	check(not shown.contains("page") and not shown.contains("lost") and m._reward_text.contains("satisfied"), "...and nothing says so: %s" % m._reward_text)
	check(not _gs.flags.has("flashback_f2_court") and m.status_label.text.contains("SURVIVED"), "(F1 is an ordinary hold: the court does not fall)")
	check(_gs.gold == gold and _e.count() == 0, "a memory pays nothing and costs nobody")
	m.queue_free()
	await process_frame
	# the page is lost once, and a replay does not lose another
	_fb.lose_a_page()
	check(int(_gs.flags["flashback_f1_page_lost"]) == lost, "(and only once)")
	var low := 99
	var high := 0
	for sd in 400:
		_gs.flags.erase("flashback_f1_page_lost")
		var rr := RandomNumberGenerator.new()
		rr.seed = sd
		_fb.lose_a_page(rr)
		low = mini(low, int(_gs.flags["flashback_f1_page_lost"]))
		high = maxi(high, int(_gs.flags["flashback_f1_page_lost"]))
	check(low == 1 and high == 12, "any of the twelve pages may be the one: %d..%d" % [low, high])

	# ---- F1: lose the copyists, lose the map
	_gs.reset()
	m = await _map("map_f01")
	m._kill_unit("cargo_f01_copyist1")
	check(not m.map_lost, "one copyist lost: three remain")
	m._kill_unit("cargo_f01_copyist2")
	check(m.map_lost and not _gs.won_maps.has("map_f01"), "two lost: too few left; the memory must be tried again")
	m.queue_free()
	await process_frame

	# ---- F2
	_gs.reset()
	m = await _map("map_f02")
	check(_ids(m).filter(func(i): return i.begins_with("pu_f2_")).size() == 6 and m.enemies.size() == 14 and m.dens.is_empty() and m._cargo_needed() == 0, "F2: six defenders, fourteen enemies on the field from the start, no reinforcements")
	check(m.map_row["reinforcement_source"] == "none" and m.map_row["turn_limit"] == 8, "nothing refills")
	var vid := "pu_f2_corvin"
	m.unit_hp[vid] = 0
	check(m._miracle_saves(vid) and m.unit_hp[vid] == 1 and m._take_miracle_notes()[0].contains("The pact answers: Corvin"), "every pact answers once, free")
	m.unit_hp[vid] = 0
	check(not m._miracle_saves(vid), "...only once")
	m.unit_hp["pu_f2_lucan"] = 0
	check(m._miracle_saves("pu_f2_lucan"), "(and for each of them)")
	check(m._is_flashback() and not _gs.flags.has("flashback_f2_court"), "no outcome yet")
	# dawn
	m.turn = 7
	m._next_turn()
	check(m.map_won and _gs.flags.get("flashback_f2_court") == "dawn" and m.info_label.text.contains("falls regardless"), "the court holds to dawn and falls anyway")
	check(_gs.won_maps.has("map_f02"), "...and the memory counts as played")
	m.queue_free()
	await process_frame
	_gs.reset()
	m = await _map("map_f02")
	for pid in m.unit_positions.keys():
		m._kill_unit(pid)
	m._check_defeat()
	check(m.map_lost and _gs.flags.get("flashback_f2_court") == "fell" and _gs.won_maps.has("map_f02") and m.status_label.text.contains("COURT FALLS"), "if the company is gone first, the court falls: losing is the ending, and it counts as played")
	m.queue_free()
	await process_frame
	# an ordinary map's free pact does not exist
	_gs.reset()
	m = await _map("map_d02")
	check(not m._miracle_saves("u_jost") and not m._is_flashback(), "other maps keep their own rules")
	m.queue_free()
	await process_frame

	# ---- the party is taken into the memory
	_gs.reset()
	var ow: Node2D = load("res://scenes/overworld.tscn").instantiate()
	ow.animate = false
	_gs.won_maps["map_f00"] = true
	root.add_child(ow)
	await process_frame
	check(ow.is_memory("loc_ur_nashet") and ow.is_memory("loc_scribes_quarter") and ow.is_memory("loc_last_court") and not ow.is_memory("loc_tally_house"), "three locations are memories")
	check(ow.due_memory_location() == "", "nothing is due at the start")
	ow.queue_free()
	await process_frame
	_gs.reset()
	_gs.won_maps["map_f00"] = true
	_gs.world_location = "loc_tally_house"
	_gs.won_maps["map_d10"] = true
	ow = load("res://scenes/overworld.tscn").instantiate()
	ow.animate = false
	root.add_child(ow)
	await process_frame
	check(ow.due_memory_location() == "loc_scribes_quarter" and ow.party_location == "loc_scribes_quarter", "after the Act 1 finale the party stands in the scribes' quarter")
	check(ow.chapter_to_play("loc_scribes_quarter").chapter.get("chapter_id") == "ch_f01" and ow.scene_for(ow.chapter_to_play("loc_scribes_quarter")) == "res://scenes/map_f01.tscn", "and Enter plays it")
	ow.queue_free()
	await process_frame
	_gs.won_maps["map_f01"] = true
	_gs.won_maps["map_rf20"] = true
	ow = load("res://scenes/overworld.tscn").instantiate()
	ow.animate = false
	root.add_child(ow)
	await process_frame
	check(ow.due_memory_location() == "loc_last_court" and ow.party_location == "loc_last_court", "once it is won, the Reunion takes the party to the last court")
	ow.queue_free()
	await process_frame
	_gs.won_maps["map_f02"] = true
	ow = load("res://scenes/overworld.tscn").instantiate()
	ow.animate = false
	root.add_child(ow)
	await process_frame
	check(ow.due_memory_location() == "" and ow.party_location == "loc_tally_house", "with both played, the party goes back to where it stood")
	ow.queue_free()
	await process_frame
