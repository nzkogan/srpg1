extends SceneTree
## Runs the auto-player over maps and prints how each went, over several seeds.
##   godot --headless --path game --script res://tools/autoplay_run.gd -- map_d01 map_d02 [--seeds=10] [--turns=40] [--without=u_dietmar]
## Each map uses its scene's own deploy roster at base stats (a first-time player's party).

const Autoplay := preload("res://tools/autoplay.gd")

func _initialize() -> void:
	await process_frame
	var maps: Array = []
	var seeds := 10
	var max_turns := 40
	var without: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds = int(a.trim_prefix("--seeds="))
		elif a.begins_with("--without="):
			without = a.trim_prefix("--without=").split(",")
		elif a.begins_with("--turns="):
			max_turns = int(a.trim_prefix("--turns="))
		else:
			maps.append(a)
	for map_id in maps:
		var wins := 0
		var turns := 0
		var fallen := 0
		var hp_lost := 0
		var notes: Dictionary = {}
		for s in seeds:
			root.get_node("GameState").reset()
			var m: Node = load("res://scenes/%s.tscn" % map_id).instantiate()
			if not without.is_empty():
				var ids: Array[String] = []
				ids.assign(Array(m.deploy_unit_ids).filter(func(u): return not without.has(u)))
				m.deploy_unit_ids = ids
			root.add_child(m)
			await process_frame
			var r: Dictionary = Autoplay.new().play(m, s + 1, max_turns)
			if r["won"]:
				wins += 1
				turns += int(r["turns"])
			fallen += r["fallen"].size()
			hp_lost += int(r["hp_lost_pct"])
			for p in r["fallen"]:
				notes[p] = int(notes.get(p, 0)) + 1
			m.queue_free()
			await process_frame
		print("%s: won %d/%d, avg turns to win %s, avg HP lost %d%%, units lost %d (%s)" % [map_id, wins, seeds,
			("%.1f" % (float(turns) / wins)) if wins > 0 else "-", hp_lost / seeds, fallen, ", ".join(notes.keys().map(func(k): return "%s x%d" % [k, notes[k]]))])
	quit()
