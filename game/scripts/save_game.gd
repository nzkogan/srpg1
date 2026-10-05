extends Node
## Autoload singleton: saving and loading the playthrough (GameState) to JSON
## files in user://saves/. Register after GameState in project.godot.
##
## Slots: "auto" (written automatically after every won map and when you leave
## the barracks or convoy) and "1", "2", "3" (manual, from the save screen).
## A save is {"version", "saved_at", "summary", "state"}; `state` is exactly
## GameState.to_dict(). Writes are crash-safe: the new file is written and
## re-read before it replaces the old one, and the previous save is kept as
## <slot>.json.bak, which load falls back to if the main file is damaged.
##
## Versioning: SAVE_VERSION goes up when the format changes; _migrate() upgrades
## older saves in memory. A save from a NEWER build is refused, never guessed at.

const SAVE_VERSION := 1
const SLOTS: Array[String] = ["auto", "1", "2", "3"]
const MANUAL_SLOTS: Array[String] = ["1", "2", "3"]

## The screen for saving, loading and starting a new game (opened with L on the overworld).
const SCREEN_SCENE := "res://scenes/save_screen.tscn"

var base_dir := "user://saves"

## Autosave writes to the player's real save directory, so it is off in
## headless runs (the test suites win maps constantly).
var autosave_enabled := DisplayServer.get_name() != "headless"

func slot_path(slot: String) -> String:
	return "%s/slot_%s.json" % [base_dir, slot]

func is_valid_slot(slot: String) -> bool:
	return SLOTS.has(slot)

# ------------------------------------------------------------------ saving

## A short description of the playthrough, shown in the slot list.
func make_summary() -> Dictionary:
	var top_level := 0
	for uid in GameState.progression:
		top_level = maxi(top_level, int(GameState.progression[uid].get("level", 0)))
	var deeds := 0
	for uid in GameState.deeds:
		deeds += GameState.deeds[uid].size()
	var certified := 0
	for uid in GameState.progression:
		var st: Dictionary = GameState.progression[uid]
		var cls = Canon.find_by("classes", "class_id", st.get("class_id", ""))
		if st.get("promoted", false) and cls != null and cls["tier"] != "personal":
			certified += 1
	return {"gold": GameState.gold, "units": GameState.progression.size(), "top_level": top_level,
		"maps_won": GameState.won_maps.size(), "deeds": deeds, "certified": certified}

func _envelope() -> Dictionary:
	return {"version": SAVE_VERSION, "saved_at": int(Time.get_unix_time_from_system()),
		"summary": make_summary(), "state": GameState.to_dict()}

## Writes the playthrough to a slot. Returns {"ok": bool, "error": String}.
func save(slot: String) -> Dictionary:
	if not is_valid_slot(slot):
		return {"ok": false, "error": "unknown slot '%s'" % slot}
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base_dir)) != OK:
		return {"ok": false, "error": "can't create the save folder"}
	var path := slot_path(slot)
	var tmp := path + ".tmp"
	var text := JSON.stringify(_envelope(), "\t")
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return {"ok": false, "error": "can't write %s" % tmp}
	f.store_string(text)
	f.close()
	# verify what we just wrote before it replaces anything
	var check := _read(tmp)
	if not check["ok"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
		return {"ok": false, "error": "the written file didn't read back (%s)" % check["error"]}
	var abs_path := ProjectSettings.globalize_path(path)
	var abs_bak := abs_path + ".bak"
	if FileAccess.file_exists(path):
		DirAccess.rename_absolute(abs_path, abs_bak)
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), abs_path) != OK:
		if FileAccess.file_exists(abs_bak):
			DirAccess.rename_absolute(abs_bak, abs_path)     # put the old save back
		return {"ok": false, "error": "can't replace the old save"}
	return {"ok": true, "error": ""}

## The automatic save. A no-op when autosave is off. Returns the save result
## ({"ok": true} when skipped, so callers needn't care).
func autosave() -> Dictionary:
	if not autosave_enabled:
		return {"ok": true, "error": "", "skipped": true}
	return save("auto")

# ----------------------------------------------------------------- reading

## Parses and checks a file without touching GameState. {"ok", "error", "data"}.
func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "no save", "data": {}}
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {"ok": false, "error": "the save file is damaged", "data": {}}
	var data: Dictionary = json.data
	if not data.has("version") or typeof(data["version"]) not in [TYPE_INT, TYPE_FLOAT]:
		return {"ok": false, "error": "the save file has no version", "data": {}}
	var version := int(data["version"])
	if version > SAVE_VERSION:
		return {"ok": false, "error": "this save is from a newer version of the game (v%d)" % version, "data": {}}
	if version < 1:
		return {"ok": false, "error": "the save file has a bad version", "data": {}}
	data = _migrate(data, version)
	var problem := GameState.validate(data.get("state"))
	if problem != "":
		return {"ok": false, "error": "the save file is damaged (%s)" % problem, "data": {}}
	return {"ok": true, "error": "", "data": data}

## Upgrades an older save's envelope to SAVE_VERSION. Nothing to do at v1; this
## is where "if version < 2" steps go when the format changes.
func _migrate(data: Dictionary, _version: int) -> Dictionary:
	return data

## Loads a slot into GameState. Falls back to the slot's .bak if the main file
## is damaged. Returns {"ok", "error", "used_backup"}.
func load_slot(slot: String) -> Dictionary:
	if not is_valid_slot(slot):
		return {"ok": false, "error": "unknown slot '%s'" % slot, "used_backup": false}
	var main := _read(slot_path(slot))
	var used_backup := false
	if not main["ok"] and main["error"] != "no save":
		var bak := _read(slot_path(slot) + ".bak")
		if bak["ok"]:
			main = bak
			used_backup = true
	if not main["ok"]:
		return {"ok": false, "error": main["error"], "used_backup": false}
	GameState.from_dict(main["data"]["state"])
	Supports.begin_map()      # any unbanked points belonged to a map that is no longer being played
	return {"ok": true, "error": "", "used_backup": used_backup}

## What the slot list shows: {"slot", "exists", "damaged", "saved_at", "summary", "error"}.
func slot_info(slot: String) -> Dictionary:
	var info := {"slot": slot, "exists": false, "damaged": false, "saved_at": 0, "summary": {}, "error": ""}
	if not is_valid_slot(slot):
		info["error"] = "unknown slot"
		return info
	var main := _read(slot_path(slot))
	if not main["ok"] and main["error"] != "no save":
		var bak := _read(slot_path(slot) + ".bak")
		if bak["ok"]:
			main = bak
	if main["ok"]:
		info["exists"] = true
		info["saved_at"] = int(main["data"].get("saved_at", 0))
		info["summary"] = main["data"].get("summary", {})
	elif main["error"] != "no save":
		info["exists"] = true
		info["damaged"] = true
		info["error"] = main["error"]
	return info

func list_slots() -> Array:
	var out: Array = []
	for slot in SLOTS:
		out.append(slot_info(slot))
	return out

func delete_slot(slot: String) -> bool:
	if not is_valid_slot(slot):
		return false
	var removed := false
	for path in [slot_path(slot), slot_path(slot) + ".bak", slot_path(slot) + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			removed = true
	return removed

## "2026-10-06 14:03" for a unix time.
func format_time(unix: int) -> String:
	var dt := Time.get_datetime_dict_from_unix_time(unix)
	return "%04d-%02d-%02d %02d:%02d" % [dt["year"], dt["month"], dt["day"], dt["hour"], dt["minute"]]
