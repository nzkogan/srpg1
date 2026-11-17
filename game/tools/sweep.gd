extends SceneTree
## Loads every map scene once with its default roster and runs a few frames, so a broken map, a bad tile or a script error
## anywhere in setup shows up. Run: godot --headless --path game --script res://tools/sweep.gd

func _initialize() -> void:
	await process_frame
	var dir := DirAccess.open("res://scenes")
	var names: Array = []
	for f in dir.get_files():
		if f.begins_with("map_") and f.ends_with(".tscn"):
			names.append(f)
	names.sort()
	var bad := 0
	for f in names:
		var packed = load("res://scenes/" + f)
		if packed == null:
			print("FAIL could not load ", f)
			bad += 1
			continue
		var m: Node = packed.instantiate()
		if "enemy_phase_enabled" in m:
			m.enemy_phase_enabled = false
		root.add_child(m)
		await process_frame
		await process_frame
		m.queue_free()
		await process_frame
	print("swept %d" % names.size())
	quit(1 if bad > 0 else 0)
