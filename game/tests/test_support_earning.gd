extends SceneTree
## Headless checks for the support-earning rule (Supports.record_turn_end /
## settle_map / pair_allowed) and its wiring into map_grid.gd.
## Run from the repo root:
##   godot --headless --path game --script res://tests/test_support_earning.gd
## Exits 0 if every check passes, 1 otherwise.

var _failures: int = 0
var _checks: int = 0

# Autoload names aren't resolvable at compile time in a --script test.
var _gs: Node
var _sup: Node

func check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: ", label)

func _initialize() -> void:
	_gs = root.get_node("GameState")
	_sup = root.get_node("Supports")
	await process_frame   # let autoload _ready() finish
	_reset()
	_rule_tests()
	_reset()
	_settle_tests()
	_reset()
	await _map_integration_test()
	_reset()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)

func _reset() -> void:
	_gs.support_recent.clear()
	_gs.support_focus = ""
	_gs.support_ranks.clear()
	_gs.support_points.clear()
	_gs.support_settled_maps.clear()
	_sup.begin_map()

func _rule_tests() -> void:
	# --- route gate (real units: jost diadem, maren assembly, rinsa both)
	check(not _sup.pair_allowed("u_jost", "u_maren", "diadem"), "diadem x assembly blocked on a diadem chapter")
	check(not _sup.pair_allowed("u_jost", "u_maren", "assembly"), "diadem x assembly blocked on an assembly chapter")
	check(_sup.pair_allowed("u_jost", "u_maren", "both"), "diadem x assembly allowed once routes converge")
	check(_sup.pair_allowed("u_jost", "u_rinsa", "diadem"), "a route-'both' unit pairs with anyone, anywhere")
	check(_sup.pair_allowed("u_jost", "u_ricberta", "diadem"), "same-route pair allowed")
	check(_sup.pair_allowed("u_maren", "u_brandt", "diadem"), "same-route pair allowed even on the other route's chapter")
	check(not _sup.pair_allowed("u_jost", "u_nobody", "both"), "unknown unit never earns")

	# --- proximity
	var jr := "sup_jost_ricberta"
	check(_sup.record_turn_end({"u_jost": Vector2i(0, 0), "u_ricberta": Vector2i(0, 2)}, "diadem") == 1,
		"two tiles apart earns a point")
	check(_sup.map_points(jr) == 1, "the point lands on the right chain")
	_reset()
	check(_sup.record_turn_end({"u_jost": Vector2i(0, 0), "u_ricberta": Vector2i(1, 1)}, "diadem") == 1,
		"diagonal neighbours (distance 2) earn")
	_reset()
	check(_sup.record_turn_end({"u_jost": Vector2i(0, 0), "u_ricberta": Vector2i(0, 3)}, "diadem") == 0,
		"three tiles apart earns nothing")
	check(_sup.record_turn_end({"u_jost": Vector2i(0, 0), "u_maren": Vector2i(0, 1)}, "diadem") == 0,
		"adjacent but route-blocked earns nothing")
	check(_sup.record_turn_end({"pu_kadar": Vector2i(0, 0), "pu_nashar": Vector2i(0, 1)}, "both") == 0,
		"prologue-roster units have no chain and are ignored")
	check(_sup.record_turn_end({"u_jost": Vector2i(0, 0)}, "diadem") == 0, "a lone unit earns nothing")

	# --- per-map cap
	_reset()
	var total := 0
	for i in 6:
		total += _sup.record_turn_end({"u_jost": Vector2i(0, 0), "u_ricberta": Vector2i(0, 1)}, "diadem")
	check(total == 3 and _sup.map_points(jr) == 3, "a chain earns at most MAP_POINT_CAP (3) per map (got %d)" % total)

	# --- maxed chains stop earning
	_reset()
	_gs.support_ranks["sup_jost_ricberta"] = "A"   # platonic chain tops out at A
	check(_sup.record_turn_end({"u_jost": Vector2i(0, 0), "u_ricberta": Vector2i(0, 1)}, "diadem") == 0,
		"a chain at its maximum rank earns nothing")
	_reset()
	_gs.support_ranks["sup_ricberta_sigrun"] = "A"  # romance chain still has S to go
	check(_sup.record_turn_end({"u_ricberta": Vector2i(0, 0), "u_sigrun": Vector2i(0, 1)}, "diadem") == 1,
		"a romance chain at A can still earn toward S")

	# --- begin_map discards unbanked points
	_reset()
	_sup.record_turn_end({"u_jost": Vector2i(0, 0), "u_ricberta": Vector2i(0, 1)}, "diadem")
	_sup.begin_map()
	check(_sup.map_points(jr) == 0, "begin_map discards points from an unfinished map")

func _s_key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e

func _earn_full_map(chain_a: String, chain_b: String, chapter_route: String) -> void:
	for i in 3:
		_sup.record_turn_end({chain_a: Vector2i(0, 0), chain_b: Vector2i(0, 1)}, chapter_route)

func _settle_tests() -> void:
	var jr := "sup_jost_ricberta"
	# Pacing: 3 points a map -> C at 3, B at 8, A at 15, and never past A.
	var expected := [
		["C", 3], ["C", 6], ["B", 9], ["B", 12], ["A", 15], ["A", 15],
	]
	for n in expected.size():
		_earn_full_map("u_jost", "u_ricberta", "diadem")
		_sup.settle_map("map_test_%d" % n)
		check(_sup.current_rank(jr) == expected[n][0],
			"after map %d: rank %s (got %s)" % [n + 1, expected[n][0], _sup.current_rank(jr)])
		check(_sup.points(jr) == expected[n][1],
			"after map %d: %d banked points (got %d)" % [n + 1, expected[n][1], _sup.points(jr)])
	check(_sup.points_to_next(jr) == -1, "a maxed chain reports no next rank")

	# one rank per chain per map, however many points are banked
	_reset()
	_gs.support_points[jr] = 100
	var r1: Array = _sup.settle_map("map_a")
	check(r1.size() == 1 and r1[0]["rank"] == "C", "100 banked points still only ranks up once (C)")
	var r2: Array = _sup.settle_map("map_b")
	check(r2.size() == 1 and r2[0]["rank"] == "B", "the next map ranks up again (B)")

	# each map banks once per playthrough
	_reset()
	_earn_full_map("u_jost", "u_ricberta", "diadem")
	_sup.settle_map("map_once")
	check(_sup.points(jr) == 3, "first settle banks the points")
	_earn_full_map("u_jost", "u_ricberta", "diadem")
	var again: Array = _sup.settle_map("map_once")
	check(again.is_empty() and _sup.points(jr) == 3, "settling the same map again banks nothing")
	check(_sup.map_points(jr) == 0, "and discards that replay's points")

	# recent = this map's rank-ups only; a win that raises nothing clears it
	_reset()
	_gs.support_points[jr] = 3
	_sup.settle_map("map_recent_1")
	check(_gs.support_recent == {jr: "C"}, "settle_map records what it raised as recent")
	_sup.settle_map("map_recent_2")
	check(_gs.support_recent.is_empty(), "a new win that raises nothing clears the recent list")
	_sup.settle_map("map_recent_1")
	check(_gs.support_recent.is_empty(), "settling an already-settled map leaves recent alone")

	# an unfinished map banks nothing
	_reset()
	_earn_full_map("u_jost", "u_ricberta", "diadem")
	_sup.begin_map()
	_sup.settle_map("map_abandoned")
	check(_sup.points(jr) == 0 and _sup.current_rank(jr) == "", "an abandoned map banks nothing")

	# romance chains reach S; platonic chains never do
	_reset()
	_gs.support_ranks["sup_ricberta_sigrun"] = "A"
	_gs.support_points["sup_ricberta_sigrun"] = 25
	var rs: Array = _sup.settle_map("map_s")
	check(rs.size() == 1 and rs[0]["rank"] == "S", "romance chain reaches S at 25 points")
	_reset()
	_gs.support_ranks["sup_dietmar_torvald"] = "A"
	_gs.support_points["sup_dietmar_torvald"] = 100
	check(_sup.settle_map("map_p").is_empty(), "platonic chain never ranks past A")

	# player-facing line
	_reset()
	_gs.support_points[jr] = 3
	var line: String = _sup.describe_raise(_sup.settle_map("map_line")[0])
	check(line == "Support: Jost and Ricberta reach rank C.", "describe_raise reads well (got '%s')" % line)

## The roster this test pins onto map_d05, so it doesn't depend on whatever
## the production scene currently deploys: ten units in a row two columns
## apart, in this order, with the diadem/assembly boundary between Tancred
## and Maren.
const TEST_ROSTER: Array[String] = [
	"u_jost", "u_ricberta", "u_emmerich", "u_sigrun", "u_waldrada",
	"u_tancred", "u_maren", "u_brandt", "u_torvald", "u_rinsa",
]

## End to end: load the real map_d05 scene (survive, 10 turns; mixed routes on
## a diadem chapter) with TEST_ROSTER deployed, play its turns, and check the
## rule fired through the real turn/win hooks.
func _map_integration_test() -> void:
	var packed: PackedScene = load("res://scenes/map_d05.tscn")
	var map: Node = packed.instantiate()
	map.deploy_unit_ids = TEST_ROSTER.duplicate()
	root.add_child(map)
	await process_frame

	check(map.chapter_route == "diadem", "map_d05 resolves its chapter route from data (got '%s')" % map.chapter_route)
	var guard := 0
	while not map.map_won and guard < 30:
		map._next_turn()
		guard += 1
	check(map.map_won, "map_d05 is won by surviving its turn limit")
	await process_frame   # the deferred support message

	check(_gs.support_settled_maps.has("map_d05"), "winning banked the map's support points")
	# row order: jost ricberta emmerich sigrun waldrada tancred maren brandt torvald rinsa
	var earned := [
		"sup_jost_ricberta", "sup_ricberta_emmerich", "sup_emmerich_sigrun", "sup_sigrun_waldrada",
		"sup_waldrada_tancred", "sup_maren_brandt", "sup_brandt_torvald", "sup_torvald_rinsa",
	]
	var all_c := true
	for id in earned:
		if _sup.points(id) != 3 or _sup.current_rank(id) != "C":
			all_c = false
			print("  ", id, " points=", _sup.points(id), " rank=", _sup.current_rank(id))
	check(all_c, "all 8 allowed neighbouring pairs banked the capped 3 points and reached C")
	check(_sup.points("sup_tancred_maren") == 0 and _sup.current_rank("sup_tancred_maren") == "",
		"Tancred (diadem) next to Maren (assembly) earned nothing on a diadem chapter")
	check(_sup.points("sup_jost_emmerich") == 0, "units four tiles apart earned nothing")
	check(map._support_lines.size() == 8 and map.info_label.text.contains(map._support_lines[0]),
		"the win screen lists the first rank-up (of %d)" % map._support_lines.size())
	check(map.info_label.text.contains("Press S to read the new support scenes (8)"),
		"the win screen offers the viewer when ranks were raised")
	var win_lines: PackedStringArray = map.info_label.text.split("\n")
	check(win_lines.size() <= 6 and map.info_label.text.contains("...and 6 more."),
		"the win text stays short: hint, two raises, a count of the rest (got %d lines)" % win_lines.size())
	check(map.info_label.text.find("Press S") < map.info_label.text.find("Support: "),
		"the viewer hint comes before the list, where a tall list can't push it off screen")
	check(_gs.support_recent.size() == 8 and _gs.support_recent["sup_jost_ricberta"] == "C",
		"the map's rank-ups are recorded as recent (got %d)" % _gs.support_recent.size())

	# S on the win screen opens the viewer on the first raised chain
	var first_raised: String = _gs.support_recent.keys().min()
	map._unhandled_input(_s_key(KEY_S))
	await process_frame
	await process_frame
	var viewer: Node = root.get_node_or_null("SupportViewer")
	check(viewer != null, "S on the win screen opens the support viewer")
	if viewer != null:
		check(viewer.selected_chain() == first_raised and _gs.support_focus == "",
			"the viewer opens on the first raised chain (%s) and the focus request is consumed" % first_raised)
		viewer.queue_free()

	# replaying the same map can't farm
	map.queue_free()
	await process_frame
	var again: Node = packed.instantiate()
	again.deploy_unit_ids = TEST_ROSTER.duplicate()
	root.add_child(again)
	await process_frame
	guard = 0
	while not again.map_won and guard < 30:
		again._next_turn()
		guard += 1
	await process_frame
	check(_sup.points("sup_jost_ricberta") == 3 and _sup.current_rank("sup_jost_ricberta") == "C",
		"replaying a won map banks nothing more")
	check(again.info_label.text.contains("Victory") and not again.info_label.text.contains("Press S"),
		"a replayed win raises nothing, so no viewer link")
	check(_gs.support_recent.size() == 8, "a replay leaves the recent list alone")

	# Escape still works once the battle is won (it used to be swallowed)
	again._unhandled_input(_s_key(KEY_ESCAPE))
	await process_frame
	await process_frame
	var ow: Node = root.get_node_or_null("Overworld")
	check(ow != null, "Escape on the win screen returns to the overworld")
	if ow != null:
		ow.queue_free()
	if is_instance_valid(again):
		again.queue_free()
	await process_frame
