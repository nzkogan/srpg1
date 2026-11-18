extends SceneTree
## Runs the auto-player over maps and prints how each went, over several seeds.
##   godot --headless --path game --script res://tools/autoplay_run.gd -- map_d01 map_d02 [--seeds=10] [--turns=40]
## Each map uses its scene's own deploy roster at base stats (a first-time player's party).

const Autoplay := preload("res://tools/autoplay.gd")

func _initialize() -> void:
	await process_frame
	var maps: Array = []
	var seeds := 10
	var max_turns := 40
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds = int(a.trim_prefix("--seeds="))
		elif a.begins_with("--turns="):
			max_turns = int(a.trim_prefix("--turns="))
		else:
			maps.append(a)
	for map_id in maps:
		var wins := 0
		var turns := 0
		var fallen := 0
		var notes: Dictionary = {}
		for s in seeds:
			root.get_node("GameState").reset()
			var m: Node = load("res://scenes/%s.tscn" % map_id).instantiate()
			root.add_child(m)
			await process_frame
			var r: Dictionary = Autoplay.new().play(m, s + 1, max_turns)
			if r["won"]:
				wins += 1
				turns += int(r["turns"])
			fallen += r["fallen"].size()
			for p in r["fallen"]:
				notes[p] = int(notes.get(p, 0)) + 1
			m.queue_free()
			await process_frame
		print("%s: won %d/%d, avg turns to win %s, units lost %d (%s)" % [map_id, wins, seeds,
			("%.1f" % (float(turns) / wins)) if wins > 0 else "-", fallen, ", ".join(notes.keys().map(func(k): return "%s x%d" % [k, notes[k]]))])
	quit()
