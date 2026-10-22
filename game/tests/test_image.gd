extends SceneTree
## Headless checks for THE IMAGE: the canon columns that place it, the silhouette's four stages (the halo holding 1, 12, 36 and 72
## patrons), that every part stays inside its box, the broken statue, and the maps that draw it.
## Run from the repo root:
##   godot --headless --path game --script res://tests/test_image.gd
## Exits 0 if every check passes, 1 otherwise.

var _failures: int = 0
var _checks: int = 0
var _canon: Node
var _gs: Node
var _fig: GDScript

func check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: ", label)

func _initialize() -> void:
	_canon = root.get_node("Canon")
	_gs = root.get_node("GameState")
	_fig = load("res://scripts/image_figure.gd")
	await process_frame
	await _run()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)

func _map(scene: String) -> Node:
	var m: Node = load("res://scenes/%s.tscn" % scene).instantiate()
	m.enemy_phase_enabled = false
	root.add_child(m)
	await process_frame
	return m

func _inside(b: Dictionary, w: float, h: float) -> bool:
	for key in ["polys", "lines"]:
		for l in b[key]:
			for p in l:
				if p.x < -0.01 or p.x > w + 0.01 or p.y < -0.01 or p.y > h + 0.01:
					return false
	for d in b["dots"]:
		if d.x < -0.01 or d.x > w + 0.01 or d.y < -0.01 or d.y > h + 0.01:
			return false
	return true

func _run() -> void:
	# ---- canon
	var placed: Array = _canon.get_table("maps").filter(func(m): return m.get("image_stage") != null)
	var stages := {}
	for m in placed:
		stages[m["map_id"]] = m["image_stage"]
	var want := {"map_f00": 1, "map_f02": 1, "map_k22": 2, "map_h33_mercy": 3, "map_h34_war3": 3, "map_e32_perverse": 4}
	var same: bool = stages.size() == want.size()
	for k in want:
		same = same and stages.get(k) == want[k]
	check(same, "the image stands on six maps, growing: the statue and the church's image, the colossus, the Hierophant's two, the Idol (%s)" % str(stages))
	var inside := true
	for m in placed:
		inside = inside and m["image_col"] + m["image_w"] <= m["width"] and m["image_row"] + m["image_h"] <= m["height"]
	check(inside, "each is placed inside its map")

	# ---- the silhouette
	check(_fig.HALO_DOTS == {1: 1, 2: 12, 3: 36, 4: 72} and _fig.ARMS == {1: 2, 2: 2, 3: 4, 4: 6}, "the halo holds one patron, then 12, 36 and all 72; the arms 2, 2, 4 and 6")
	for st in [1, 2, 3, 4]:
		var b: Dictionary = _fig.build(st, 128.0, 128.0, false)
		var halo: int = _fig.HALO_DOTS[st]
		var extra := 6 if st == 4 else 0          # the Idol's coins
		check(b["dots"].size() == halo + extra, "stage %d draws %d dots (%d)" % [st, halo + extra, b["dots"].size()])
		check(_inside(b, 128.0, 128.0), "stage %d stays inside its box" % st)
		check(_inside(_fig.build(st, 128.0, 128.0, true), 128.0, 128.0), "...and so does it fallen")
	var s1: Dictionary = _fig.build(1, 100.0, 100.0, false)
	var s2: Dictionary = _fig.build(2, 100.0, 100.0, false)
	var s4: Dictionary = _fig.build(4, 100.0, 100.0, false)
	check(s1["lines"].size() == 2 and s2["lines"].size() == 4 and s4["lines"].size() == 9, "arms and conduits: two folded arms; two raised and two conduits; six arms, two conduits and the chain")
	check(s1["lines"][0].size() == 3 and s2["lines"][0].size() == 2, "stage 1's arms are folded in front; later ones are raised")
	var robe1: PackedVector2Array = s1["polys"][1]
	var robe4: PackedVector2Array = s4["polys"][1]
	check(robe4[1].x - robe4[0].x > robe1[1].x - robe1[0].x, "the body widens as the image grows")
	var sigs := {}
	for st in [1, 2, 3, 4]:
		sigs[_fig.signature(st, false)] = true
		sigs[_fig.signature(st, true)] = true
	check(sigs.size() == 8, "four stages, each whole and broken, eight different shapes")
	check(_fig.signature(3, false) == _fig.signature(3, false), "a figure is always the same")
	var whole: Dictionary = _fig.build(2, 100.0, 100.0, false)
	var broke: Dictionary = _fig.build(2, 100.0, 100.0, true)
	check(whole["polys"].size() == broke["polys"].size() and whole["polys"][1] != broke["polys"][1], "broken is the same pieces, fallen")

	# ---- on the map
	_gs.reset()
	var m: Node = await _map("map_f00")
	check(m.image_figure != null and m.image_figure.stage == 1 and m.image_figure.position == Vector2(8 * 32, 0) and m.image_figure.size == Vector2(96, 96) and not m.image_figure.broken, "the prologue's image stands over the terrace")
	check(not m.image_figure.broken, "(whole until the statue falls)")
	m.statue_hp = 1
	m.selected_unit_index = 0
	m._attack_statue()
	check(m.statue_destroyed and m.image_figure.broken, "when the statue is rubble the image falls with it")
	m.queue_free()
	await process_frame
	for pair in [["map_k22", 2, Vector2(15 * 32, 5 * 32), Vector2(128, 192)], ["map_e32_perverse", 4, Vector2(10 * 32, 7 * 32), Vector2(128, 128)], ["map_f02", 1, Vector2(8 * 32, 32), Vector2(96, 96)]]:
		m = await _map(pair[0])
		check(m.image_figure != null and m.image_figure.stage == pair[1] and m.image_figure.position == pair[2] and m.image_figure.size == pair[3], "%s: stage %d at the place canon gives" % [pair[0], pair[1]])
		m.queue_free()
		await process_frame
	m = await _map("map_d02")
	check(m.image_figure == null, "an ordinary map has none")
	m.queue_free()
	await process_frame
