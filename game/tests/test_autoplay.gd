extends SceneTree
## The vertical slice must be winnable by a plain, sensible player (the auto-player in tools/autoplay.gd), and must
## not be trivial: each chapter takes several turns. These bounds are the slice's difficulty floor; tune the
## rosters, not the bounds.
## Run from the repo root:
##   godot --headless --path game --script res://tests/test_autoplay.gd
## Exits 0 if every check passes, 1 otherwise.

const Autoplay := preload("res://tools/autoplay.gd")

var _failures: int = 0
var _checks: int = 0

func check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: ", label)

func _initialize() -> void:
	await process_frame
	# map -> [minimum wins out of 3 seeds, minimum turns a win takes]
	var bounds := {"map_f00": [3, 7], "map_d01": [3, 3], "map_d02": [3, 3], "map_d03": [2, 5]}
	for map_id in bounds:
		var wins := 0
		var fastest := 999
		for s in 3:
			root.get_node("GameState").reset()
			var m: Node = load("res://scenes/%s.tscn" % map_id).instantiate()
			root.add_child(m)
			await process_frame
			var r: Dictionary = Autoplay.new().play(m, s + 1, 40)
			if r["won"]:
				wins += 1
				fastest = mini(fastest, int(r["turns"]))
			m.queue_free()
			await process_frame
		check(wins >= bounds[map_id][0], "%s: the auto-player wins %d of 3 (needs %d)" % [map_id, wins, bounds[map_id][0]])
		check(fastest >= bounds[map_id][1], "%s: no win faster than turn %d (fastest %d)" % [map_id, bounds[map_id][1], fastest])
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)
