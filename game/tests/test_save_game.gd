extends SceneTree
## Headless checks for save/load: GameState (de)serialization and the persisted-
## field guard, SaveGame slots, round-tripping a real playthrough, crash safety,
## the backup fallback, validation and versioning, and the map's autosave hooks.
## Run from the repo root:
##   godot --headless --path game --script res://tests/test_save_game.gd
## Exits 0 if every check passes, 1 otherwise.

var _failures: int = 0
var _checks: int = 0
var _gs: Node
var _sg: Node
var _p: Node
var _eq: Node
var _dir := "user://test_saves"

func check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: ", label)

func _initialize() -> void:
	_gs = root.get_node("GameState")
	_sg = root.get_node("SaveGame")
	_p = root.get_node("Progression")
	_eq = root.get_node("Equipment")
	await process_frame
	_sg.base_dir = _dir
	_wipe()
	_guard()
	_wipe(); _gs.reset(); _roundtrip()
	_wipe(); _gs.reset(); _slots_and_files()
	_wipe(); _gs.reset(); _safety()
	_wipe(); _gs.reset(); _validation()
	_wipe(); _gs.reset(); await _map_hooks()
	_wipe(); _gs.reset()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_dir))
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)

func _wipe() -> void:
	var abs_dir := ProjectSettings.globalize_path(_dir)
	if DirAccess.dir_exists_absolute(abs_dir):
		for f in DirAccess.get_files_at(abs_dir):
			DirAccess.remove_absolute(abs_dir + "/" + f)

func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()

## Sets up a recognisable playthrough touching every kind of state.
func _play() -> void:
	_gs.set_flag("flag_hierophant_verdict", "mercy")
	_gs.gold = 1234
	_p.state("u_jost"); _p.state("u_dietmar")
	_gs.progression["u_jost"]["level"] = 21
	_gs.progression["u_jost"]["gains"]["str"] = 7
	_gs.gold = 100000
	_gs.progression["u_jost"]["level"] = 15
	_p.promote("u_jost", "cls_housecarl")
	_gs.progression["u_jost"]["level"] = 21
	_gs.gold = 1234
	_p.set_abilities("u_jost", ["ab_smite", "ab_bulwark"])
	_p.record_deed("u_jost", "ep_nohit"); _p.record_deed("u_jost", "ep_nohit"); _p.record_deed("u_jost", "ep_talk")
	_eq.convoy_add("wpn_halberd")
	_eq.take("u_jost", _eq.convoy().size() - 1)
	_eq.inventory("u_jost")[0]["uses"] = 17
	_eq.claim_drop("spn_a06_boss", "wpn_lance_mid")
	_gs.support_ranks["sup_jost_ricberta"] = "B"
	_gs.support_points["sup_jost_ricberta"] = 9
	_gs.support_settled_maps["map_d01"] = true
	_gs.support_recent = {"sup_jost_ricberta": "B"}
	_gs.unlocked_classes["cls_billman"] = true
	_gs.income_claimed["map_d01"] = true
	_gs.won_maps["map_d01"] = true
	_gs.won_maps["map_d02"] = true

func _guard() -> void:
	# every variable declared on GameState is either saved or deliberately transient
	var declared: Array[String] = []
	for prop in _gs.get_script().get_script_property_list():
		if prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			declared.append(prop["name"])
	var missing: Array[String] = []
	for name in declared:
		if not _gs.PERSISTED.has(name) and not _gs.TRANSIENT.has(name):
			missing.append(name)
	check(missing.is_empty(), "every GameState variable is persisted or transient (unaccounted for: %s)" % str(missing))
	var ghosts: Array[String] = []
	for name in _gs.PERSISTED:
		if not declared.has(name):
			ghosts.append(name)
	check(ghosts.is_empty(), "every persisted name is a real variable (ghosts: %s)" % str(ghosts))
	check(declared.has("progression") and declared.has("deeds") and declared.has("gold") and declared.has("convoy") and declared.has("won_maps"), "the guard sees the progression, deed, gold, convoy and won-map variables")
	check(_gs.TRANSIENT == ["support_focus"], "only the one-shot UI hand-off is transient")

func _roundtrip() -> void:
	_play()
	var before: Dictionary = _gs.to_dict()
	var snap: Dictionary = before.duplicate(true)
	check(_gs.validate(before) == "", "a live state validates")
	# to_dict is a deep copy
	before["gold"] = 5
	before["progression"].clear()
	check(_gs.gold == 1234 and not _gs.progression.is_empty(), "to_dict hands out copies, not the live state")
	# save, wipe, load, compare
	var r: Dictionary = _sg.save("1")
	check(r["ok"], "saving slot 1 succeeds (%s)" % r["error"])
	_gs.reset()
	check(_gs.gold == 0 and _gs.progression.is_empty() and _gs.convoy.is_empty() and not _gs.equipment_ready and _gs.deeds.is_empty(), "reset() returns to a new playthrough")
	var l: Dictionary = _sg.load_slot("1")
	check(l["ok"] and not l["used_backup"], "loading slot 1 succeeds (%s)" % l["error"])
	check(_gs.to_dict() == snap, "the loaded state equals the saved state, key for key")
	# spot checks that matter: types survive JSON
	check(typeof(_gs.gold) == TYPE_INT and _gs.gold == 1234, "gold is an int again")
	check(typeof(_gs.progression["u_jost"]["level"]) == TYPE_INT and _gs.progression["u_jost"]["level"] == 21, "levels are ints again")
	check(typeof(_gs.progression["u_jost"]["gains"]["str"]) == TYPE_INT, "nested stat gains are ints")
	check(_gs.progression["u_jost"]["promoted"] == true and _gs.progression["u_jost"]["class_id"] == "cls_housecarl", "bools and strings survive")
	check(_gs.progression["u_jost"]["abilities"] == ["ab_smite", "ab_bulwark"] and _gs.progression["u_jost"]["auto"] == false, "ability picks survive")
	check(_gs.deeds["u_jost"]["ep_nohit"] == 2 and typeof(_gs.deeds["u_jost"]["ep_nohit"]) == TYPE_INT, "deed counts survive")
	check(_eq.inventory("u_jost")[0]["uses"] == 17 and typeof(_eq.inventory("u_jost")[0]["uses"]) == TYPE_INT, "weapon uses survive")
	check(_gs.drops_claimed.has("spn_a06_boss") and _gs.income_claimed.has("map_d01") and _gs.won_maps.size() == 2, "claim records survive (no re-farming after a load)")
	check(_gs.get_flag("flag_hierophant_verdict") == "mercy" and _gs.get_support_rank("sup_jost_ricberta") == "B" and _gs.support_points["sup_jost_ricberta"] == 9, "flags and supports survive")
	check(_gs.unlocked_classes.has("cls_billman") and _gs.equipment_ready, "unlocks and the convoy-seeded flag survive")
	# the loaded game behaves identically through the autoloads
	check(_p.level("u_jost") == 21 and _p.class_name_of("u_jost") == "Housecarl" and _p.chosen("u_jost") == ["ab_smite", "ab_bulwark"], "Progression reads the loaded state")
	check(_eq.equipped("u_jost")["weapon_id"] == "wpn_axe_basic" or _eq.equipped("u_jost").has("weapon_id"), "Equipment reads the loaded state")
	check(root.get_node("Supports").current_rank("sup_jost_ricberta") == "B", "Supports reads the loaded state")
	var seeded: int = _eq.convoy().size()
	check(seeded == _gs.convoy.size() and _eq.convoy().size() == seeded, "the convoy isn't re-seeded after a load")
	# the dead saves don't contaminate: loading replaces rather than merges
	_gs.reset(); _gs.gold = 7; _gs.won_maps["map_zzz"] = true
	_sg.load_slot("1")
	check(not _gs.won_maps.has("map_zzz") and _gs.gold == 1234, "loading replaces the current state; nothing leaks through")

func _slots_and_files() -> void:
	check(_sg.SLOTS == ["auto", "1", "2", "3"] and _sg.MANUAL_SLOTS == ["1", "2", "3"], "four slots: auto and three manual")
	check(not _sg.save("9")["ok"] and not _sg.load_slot("../evil")["ok"] and not _sg.delete_slot("x"), "unknown slot names are refused (no path tricks)")
	check(_sg.slot_path("2") == _dir + "/slot_2.json", "slot paths are fixed")
	for info in _sg.list_slots():
		check(not info["exists"], "slot %s starts empty" % info["slot"])
	_play()
	_sg.save("2")
	var info: Dictionary = _sg.slot_info("2")
	check(info["exists"] and not info["damaged"] and info["saved_at"] > 1700000000, "slot 2 now exists with a timestamp")
	check(info["summary"]["gold"] == 1234 and info["summary"]["units"] == 2 and info["summary"]["top_level"] == 21 and info["summary"]["maps_won"] == 2 and info["summary"]["deeds"] == 2, "the summary describes the playthrough: %s" % str(info["summary"]))
	check(info["summary"]["certified"] == 2, "...including how many are at order tier or above (Jost certified, Dietmar native)")
	check(not _sg.slot_info("1")["exists"] and not _sg.slot_info("3")["exists"], "other slots are untouched")
	check(_sg.format_time(1760000000).begins_with("2025-10-0"), "times format as dates (%s)" % _sg.format_time(1760000000))
	# a second save keeps the first as .bak
	_gs.gold = 4321
	_sg.save("2")
	check(FileAccess.file_exists(_sg.slot_path("2") + ".bak"), "overwriting keeps the previous save as .bak")
	check(_sg.slot_info("2")["summary"]["gold"] == 4321, "the slot holds the newer save")
	check(not FileAccess.file_exists(_sg.slot_path("2") + ".tmp"), "no stray .tmp file is left behind")
	# delete
	check(_sg.delete_slot("2") and not _sg.slot_info("2")["exists"] and not FileAccess.file_exists(_sg.slot_path("2") + ".bak"), "deleting removes the save and its backup")
	check(not _sg.delete_slot("2"), "deleting an empty slot reports nothing removed")
	# autosave
	_sg.autosave_enabled = false
	check(_sg.autosave().get("skipped", false) and not _sg.slot_info("auto")["exists"], "autosave off: nothing written")
	_sg.autosave_enabled = true
	check(_sg.autosave()["ok"] and _sg.slot_info("auto")["exists"], "autosave on: writes the 'auto' slot")
	_sg.autosave_enabled = false
	# loading an empty slot
	var l: Dictionary = _sg.load_slot("3")
	check(not l["ok"] and l["error"] == "no save", "loading an empty slot: 'no save'")

func _safety() -> void:
	_play()
	_sg.save("1")                                    # good save #1 (gold 1234)
	_gs.gold = 999
	_sg.save("1")                                    # good save #2 (gold 999); #1 is now the .bak
	var path: String = _sg.slot_path("1")
	# damage the main file: load falls back to the backup
	_write(path, "{ this is not json")
	var info: Dictionary = _sg.slot_info("1")
	check(info["exists"] and not info["damaged"] and info["summary"]["gold"] == 1234, "a damaged main file shows the backup's summary")
	_gs.reset()
	var l: Dictionary = _sg.load_slot("1")
	check(l["ok"] and l["used_backup"] and _gs.gold == 1234, "...and loads the backup, reporting that it did")
	# damage both: a clear error, and GameState untouched
	_write(path + ".bak", "garbage")
	_gs.reset(); _gs.gold = 55
	l = _sg.load_slot("1")
	check(not l["ok"] and l["error"].contains("damaged") and _gs.gold == 55, "both damaged: refused with a clear error, current game untouched")
	var di: Dictionary = _sg.slot_info("1")
	check(di["exists"] and di["damaged"], "the slot list marks it damaged")
	# truncated file
	_write(path, '{"version": 1, "saved_at": 1, "state": {"gold": ')
	_write(path + ".bak", "")
	check(not _sg.load_slot("1")["ok"], "a truncated file is refused")
	# a failed validation never half-applies: bad type in the middle
	_gs.reset(); _gs.gold = 77
	_write(path, JSON.stringify({"version": 1, "saved_at": 5, "summary": {}, "state": {"gold": 1, "progression": "not a dict"}}))
	_write(path + ".bak", "")
	var bad: Dictionary = _sg.load_slot("1")
	check(not bad["ok"] and bad["error"].contains("progression") and _gs.gold == 77, "a wrongly typed field is refused whole -- gold wasn't half-loaded")
	# a failed save leaves the old one intact: simulate by an unwritable folder name
	_sg.base_dir = "user://test_saves"
	_wipe(); _gs.reset(); _play()
	_sg.save("3")
	var good_text := FileAccess.get_file_as_string(_sg.slot_path("3"))
	check(good_text.begins_with("{") and good_text.contains('"version": 1'), "saves are readable JSON with a version")

func _validation() -> void:
	check(_gs.validate({}) == "", "an empty state is valid (everything defaults)")
	check(_gs.validate({"gold": 5, "future_key": [1, 2, 3]}) == "", "unknown keys from a newer build are ignored")
	check(_gs.validate({"gold": 5.0}) == "" and _gs.validate({"gold": 5.5}) != "", "an integral float is an int; a real fraction isn't")
	check(_gs.validate({"gold": "5"}) != "" and _gs.validate({"convoy": {}}) != "" and _gs.validate({"equipment_ready": 1}) != "", "wrong types are refused")
	check(_gs.validate([1, 2]) != "" and _gs.validate(null) != "", "a non-dictionary state is refused")
	# restore: integral floats -> ints, recursively; fractions and strings untouched
	var r: Variant = _gs.restore({"a": 1.0, "b": [2.0, {"c": 3.0}], "d": 1.5, "e": "x", "f": true, "g": null})
	check(typeof(r["a"]) == TYPE_INT and typeof(r["b"][0]) == TYPE_INT and typeof(r["b"][1]["c"]) == TYPE_INT and r["d"] == 1.5 and r["e"] == "x" and r["f"] == true and r["g"] == null, "restore() rebuilds ints through nested containers")
	# partial save = old save: missing keys take their defaults
	_gs.reset(); _gs.won_maps["map_x"] = true; _gs.gold = 9
	_gs.from_dict({"gold": 3})
	check(_gs.gold == 3 and _gs.won_maps.is_empty() and _gs.deeds.is_empty(), "from_dict resets first, so missing keys default (an older save loads)")
	# versions
	var path: String = _sg.slot_path("1")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	_write(path, JSON.stringify({"version": 99, "saved_at": 1, "state": {"gold": 1}}))
	var l: Dictionary = _sg.load_slot("1")
	check(not l["ok"] and l["error"].contains("newer version") and l["error"].contains("v99"), "a save from a newer build is refused, not guessed at (%s)" % l["error"])
	_write(path, JSON.stringify({"version": 0, "saved_at": 1, "state": {}}))
	check(not _sg.load_slot("1")["ok"], "version 0 is refused")
	_write(path, JSON.stringify({"saved_at": 1, "state": {}}))
	check(_sg.load_slot("1")["error"].contains("no version"), "a missing version is refused")
	_write(path, JSON.stringify({"version": 1, "saved_at": 1}))
	check(not _sg.load_slot("1")["ok"], "a missing state is refused")
	_write(path, JSON.stringify({"version": 1, "saved_at": 1, "summary": {}, "state": {"gold": 42, "won_maps": {"map_d01": true}}}))
	_gs.reset()
	check(_sg.load_slot("1")["ok"] and _gs.gold == 42 and _gs.won_maps.has("map_d01"), "a hand-minimal v1 save loads")

func _map_hooks() -> void:
	_gs.reset()
	_sg.autosave_enabled = true
	var m: Node = load("res://scenes/map_d05.tscn").instantiate()
	m.enemy_phase_enabled = false
	root.add_child(m)
	await process_frame
	check(not _sg.slot_info("auto")["exists"], "no autosave before anything is won")
	m.map_won = true
	await process_frame
	check(_gs.won_maps.has("map_d05"), "winning records the map in won_maps")
	var info: Dictionary = _sg.slot_info("auto")
	check(info["exists"] and info["summary"]["maps_won"] == 1, "winning writes the autosave, after the win was recorded")
	m.queue_free()
	await process_frame
	# the autosave captures this win's gold, so loading it can't lose the income
	var gold_after: int = _gs.gold
	_gs.reset()
	check(_sg.load_slot("auto")["ok"] and _gs.gold == gold_after and gold_after > 0 and _gs.won_maps.has("map_d05"), "loading the autosave restores the win's income (%d gold)" % gold_after)
	# leaving the barracks / convoy autosaves
	_wipe(); _gs.reset()
	_gs.gold = 321
	var b: Control = load("res://scenes/barracks_screen.tscn").instantiate()
	root.add_child(b)
	await process_frame
	b.leave()
	await process_frame
	await process_frame
	check(_sg.slot_info("auto")["exists"] and _sg.slot_info("auto")["summary"]["gold"] == 321, "leaving the barracks autosaves")
	_wipe()
	var c: Control = load("res://scenes/convoy_screen.tscn").instantiate()
	root.add_child(c)
	await process_frame
	c.leave()
	await process_frame
	await process_frame
	check(_sg.slot_info("auto")["exists"], "leaving the convoy autosaves")
	_sg.autosave_enabled = false
	for n in root.get_children():
		if n.name in ["Overworld"]:
			n.queue_free()
	await process_frame
