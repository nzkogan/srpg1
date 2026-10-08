extends SceneTree
## Headless checks for the save screen (save_screen.gd) and the overworld's save
## hooks: rows, modes, saving with overwrite confirmation, loading, deleting,
## new game, damaged slots, the autosave slot's rules, keys and mouse.
## Run from the repo root:
##   godot --headless --path game --script res://tests/test_save_screen.gd
## Exits 0 if every check passes, 1 otherwise.

var _failures: int = 0
var _checks: int = 0
var _gs: Node
var _sg: Node
var _p: Node
var _dir := "user://test_saves_ui"

func check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: ", label)

func _key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e

func _wipe() -> void:
	var abs_dir := ProjectSettings.globalize_path(_dir)
	if DirAccess.dir_exists_absolute(abs_dir):
		for f in DirAccess.get_files_at(abs_dir):
			DirAccess.remove_absolute(abs_dir + "/" + f)

func _initialize() -> void:
	_gs = root.get_node("GameState")
	_sg = root.get_node("SaveGame")
	_p = root.get_node("Progression")
	await process_frame
	_sg.base_dir = _dir
	_sg.autosave_enabled = false
	_wipe(); _gs.reset()
	_gs.gold = 750
	_p.state("u_jost"); _gs.progression["u_jost"]["level"] = 18
	_gs.won_maps["map_d01"] = true
	_gs.deeds["u_jost"] = {"ep_nohit": 1}

	var s: Control = load("res://scenes/save_screen.tscn").instantiate()
	s.leave_after_load = false
	root.add_child(s)
	await process_frame

	# --- structure
	check(s._list.item_count == 4 and s.row_text(_sg.slot_info("auto")) == "Autosave   (empty)", "four rows, all empty to start (%s)" % s.row_text(_sg.slot_info("auto")))
	check(s._title.text.contains("[Load]"), "it opens in Load mode")
	check(s.detail_text(_sg.slot_info("1")).contains("Empty.") and s.detail_text(_sg.slot_info("1")).contains("The game in play"), "an empty slot says so, beside the game in play")
	check(s.detail_text(_sg.slot_info("1")).contains("Gold: 750") and s.detail_text(_sg.slot_info("1")).contains("highest level 18") and s.detail_text(_sg.slot_info("1")).contains("Maps won: 1") and s.detail_text(_sg.slot_info("1")).contains("Deeds earned: 1"), "...whose summary is current")
	# --- loading an empty slot
	s._index = 1
	s._refresh()
	s.activate()
	check(s._message == "Slot 1 is empty.", "loading an empty slot: '%s'" % s._message)
	# --- Tab to Save, save into slot 1
	s._unhandled_input(_key(KEY_TAB))
	check(s._mode == 0 and s._title.text.contains("[Save]"), "Tab switches to Save")
	s.activate()
	check(_sg.slot_info("1")["exists"] and s._message == "Saved to Slot 1.", "Enter saves into the empty slot immediately (%s)" % s._message)
	check(s.row_text(_sg.slot_info("1")).begins_with("Slot 1   20") and s.row_text(_sg.slot_info("1")).contains("Lv 18") and s.row_text(_sg.slot_info("1")).contains("750 gold") and s.row_text(_sg.slot_info("1")).ends_with("1 map"), "the row now describes the save: %s" % s.row_text(_sg.slot_info("1")))
	# --- overwriting asks first
	_gs.gold = 5
	s.activate()
	check(_sg.slot_info("1")["summary"]["gold"] == 750 and s.detail_text(_sg.slot_info("1")).contains("Overwrite Slot 1?"), "saving over an existing save asks first, and changes nothing yet")
	s._unhandled_input(_key(KEY_UP))
	check(s._confirm == "" and _sg.slot_info("1")["summary"]["gold"] == 750, "another key cancels the confirmation")
	s._index = 1; s._refresh()
	s.activate()
	check(s._confirm == "save:1", "(armed again)")
	s._unhandled_input(_key(KEY_A))
	check(s._confirm == "", "even a key the screen doesn't use cancels a pending confirmation")
	s._index = 1; s._refresh()
	s.activate(); s.activate()
	check(_sg.slot_info("1")["summary"]["gold"] == 5, "pressing Enter twice overwrites")
	# --- the autosave slot can't be saved over by hand
	s._index = 0; s._refresh()
	s.activate()
	check(s._message.contains("written for you") and not _sg.slot_info("auto")["exists"], "the autosave slot refuses a manual save")
	check(s.detail_text(_sg.slot_info("auto")).contains("Written automatically"), "...and explains itself")
	# --- load slot 1
	s.set_mode(1)
	s._index = 1; s._refresh()
	_gs.reset(); _gs.gold = 99
	s.activate()
	check(_gs.gold == 5 and s._message == "Loaded Slot 1.", "Load restores the saved game (%s)" % s._message)
	# --- delete asks first
	s.delete_selected()
	check(_sg.slot_info("1")["exists"] and s.detail_text(_sg.slot_info("1")).contains("Delete Slot 1?"), "X asks before deleting")
	s.delete_selected()
	check(not _sg.slot_info("1")["exists"] and s._message == "Deleted Slot 1.", "a second X deletes it")
	s.delete_selected()
	check(s._message == "Slot 1 is already empty.", "deleting an empty slot says so")
	# --- new game asks first
	_gs.gold = 40
	s.new_game()
	check(_gs.gold == 40 and s.detail_text(_sg.slot_info("1")).contains("Start a new game"), "N asks before wiping the game in play")
	s.new_game()
	check(_gs.gold == 0 and _gs.won_maps.is_empty() and _gs.progression.is_empty() and s._message.contains("saves are untouched"), "a second N starts a new game")
	# --- damaged slot
	var f := FileAccess.open(_sg.slot_path("2"), FileAccess.WRITE)
	f.store_string("not json at all")
	f.close()
	s._index = 2; s._refresh()
	check(s.row_text(_sg.slot_info("2")) == "Slot 2   (damaged)" and s.detail_text(_sg.slot_info("2")).contains("can't be read"), "a damaged slot is marked in the list and explained")
	s.activate()
	check(s._message.begins_with("Couldn't load:") and _gs.gold == 0, "loading it fails cleanly and leaves the game alone")
	# --- autosave slot loads
	_gs.gold = 616
	_sg.autosave_enabled = true
	_sg.autosave()
	_sg.autosave_enabled = false
	_gs.reset()
	s._index = 0; s._refresh()
	s.activate()
	check(_gs.gold == 616 and s._message == "Loaded Autosave.", "the autosave can be loaded")
	# --- backup note
	_gs.gold = 1; _sg.save("3"); _gs.gold = 2; _sg.save("3")
	f = FileAccess.open(_sg.slot_path("3"), FileAccess.WRITE)
	f.store_string("{broken")
	f.close()
	s._index = 3; s._refresh()
	s.activate()
	check(s._message.contains("from its backup") and _gs.gold == 1, "loading from the backup says so (%s)" % s._message)
	# --- keys and mouse
	s._unhandled_input(_key(KEY_DOWN))
	check(s._index == 0, "Down from the last slot wraps to the first")
	s._list.item_selected.emit(2)
	check(s._index == 2, "clicking a row selects it")
	s.queue_free()
	await process_frame

	# --- the overworld: won maps are green; the autosave hint; the L key target exists
	_wipe(); _gs.reset()
	var ow: Node2D = load("res://scenes/overworld.tscn").instantiate()
	root.add_child(ow)
	await process_frame
	check(not ow.info_label.text.contains("Autosave found"), "no hint when there is no autosave")
	ow.queue_free()
	await process_frame
	_gs.gold = 12
	_sg.autosave_enabled = true
	_sg.autosave()
	_sg.autosave_enabled = false
	ow = load("res://scenes/overworld.tscn").instantiate()
	root.add_child(ow)
	await process_frame
	check(ow.info_label.text.contains("Autosave found (") and ow.info_label.text.contains("press L to load it"), "a fresh game with an autosave waiting is told so")
	ow.queue_free()
	await process_frame
	_gs.won_maps["map_d01"] = true
	ow = load("res://scenes/overworld.tscn").instantiate()
	root.add_child(ow)
	await process_frame
	check(not ow.info_label.text.contains("Autosave found"), "once you've won a map the hint goes away")
	_gs.won_maps["map_f00"] = true
	ow._recolor_nodes()
	var d01_color: Color = ow._node_rects["loc_tally_house"].color
	var d02_color: Color = ow._node_rects["loc_weighbridge"].color
	check(d01_color == ow.WON_COLOR and d02_color == ow.AVAILABLE_COLOR and ow._node_rects["loc_grain_road"].color == ow.LOCKED_COLOR, "a won place is green, the next one blue, the one after grey")
	check(ow.info_label.text.contains("L to save or load") and ResourceLoader.exists(_sg.SCREEN_SCENE), "the overworld points at the save screen, which exists")
	ow.queue_free()
	await process_frame
	_wipe(); _gs.reset()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_dir))
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)
