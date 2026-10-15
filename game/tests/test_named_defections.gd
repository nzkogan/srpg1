extends SceneTree
## Headless checks for a Named mount leaving on its creature's own defection trigger: the Simurgh when the
## feather changes hands, the Karkadann when the Ashland is written off or the crown's orders are taken, the
## Anzu when a literacy its rider lacks is shown; never the Shadhavar or the Warhorse.
## Run from the repo root:
##   godot --headless --path game --script res://tests/test_named_defections.gd
## Exits 0 if every check passes, 1 otherwise.

var _failures: int = 0
var _checks: int = 0
var _p: Node
var _gs: Node
var _m: Node

func check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: ", label)

func _initialize() -> void:
	_p = root.get_node("Progression")
	_gs = root.get_node("GameState")
	_m = root.get_node("Mounts")
	await process_frame
	await _run()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)

func _join(ids: Array, level := 10) -> void:
	for u in ids:
		_p.state(u)
		_gs.progression[u]["level"] = level

func _fresh(ids: Array = []) -> void:
	_gs.reset()
	_join(ids)

func _run() -> void:
	# ---- canon
	check(_m.leaves("mnt_simurgh") == ["handed_on"] and _m.leaves("mnt_karkadann") == ["map_won", "writ"] and _m.leaves("mnt_anzu") == ["literacy"], "canon: the Simurgh, the Karkadann and the Anzu each have a trigger")
	check(_m.leaves("mnt_shadhavar").is_empty() and _m.leaves("mnt_warhorse").is_empty(), "...the Shadhavar ('uncontrolled by design') and the Warhorse have none")
	var kr: Dictionary = _m.row("mnt_karkadann")
	check(kr["leaves_map_id"] == "map_b15" and kr["leaves_unless_map_id"] == "map_ct19", "the Karkadann's map is the Ashland write-off Maren's defection reads")
	check(_m.row("mnt_simurgh")["leaves_line"].contains("green") and _m.row("mnt_karkadann")["leaves_line"].contains("doves") and _m.row("mnt_anzu")["leaves_line"].contains("literacy"), "each has its line")

	# ---- the Simurgh: the feather changes hands
	_fresh(["u_jost", "u_brandt"])
	_m.bond_named("nmd_simurgh")
	var r: Dictionary = _m.assign("u_jost", "mnt_simurgh")
	check(r["ok"] and not r.get("left", false) and _m.mount_of("u_jost") == "mnt_simurgh" and _m.owned() == ["mnt_simurgh"], "the first rider takes her")
	_m.unassign("u_jost")
	check(_m.assign("u_jost", "mnt_simurgh")["ok"] and _m.mount_of("u_jost") == "mnt_simurgh", "the same hand may give her up and take her again")
	_m.unassign("u_jost")
	r = _m.assign("u_brandt", "mnt_simurgh")
	check(r["ok"] and r["left"] and r["reason"].contains("stops being green"), "give her to anyone else and she is gone: %s" % r["reason"])
	check(_m.owned().is_empty() and _m.mount_of("u_brandt") == "" and _m.stable().is_empty(), "gone from the stable, not in anyone's hands")
	check(_m.bond_named("nmd_simurgh").contains("joins the stable intact"), "...back in the wild, to be won again")
	# the first holder is dead: an heir may take her
	_fresh(["u_jost", "u_brandt"])
	_m.add_to_stable("mnt_simurgh")
	_m.assign("u_jost", "mnt_simurgh")
	_m.unassign("u_jost")
	_gs.epilogue["deaths"] = {"u_jost": {}}
	r = _m.assign("u_brandt", "mnt_simurgh")
	check(r["ok"] and not r.get("left", false) and _m.mount_of("u_brandt") == "mnt_simurgh", "if the first holder is dead the feather passes to an heir")
	# a rider falls and she is recovered: the heir is free to take her
	_fresh(["u_jost", "u_brandt"])
	_m.add_to_stable("mnt_simurgh")
	_m.assign("u_jost", "mnt_simurgh")
	_m.on_rider_fell("u_jost", true)
	r = _m.assign("u_brandt", "mnt_simurgh")
	check(r["ok"] and not r.get("left", false), "a recovered mount has no living holder: the next rider is no change of hands")
	# an ordinary mount does not care
	_fresh(["u_jost", "u_brandt"])
	_m.add_to_stable("mnt_warhorse")
	_m.assign("u_jost", "mnt_warhorse")
	_m.unassign("u_jost")
	check(_m.assign("u_brandt", "mnt_warhorse")["ok"] and _m.mount_of("u_brandt") == "mnt_warhorse", "a Warhorse goes from hand to hand")

	# ---- the Karkadann: the Ashland written off
	_fresh(["u_jost"])
	_m.bond_named("nmd_karkadann")
	check(_m.check_departures("map_b15", true) == ["%s" % kr["leaves_line"]] and _m.owned().is_empty(), "winning the going-rate map with the Ashland never worked: the Karkadann turns")
	check(_m.bond_named("nmd_karkadann") != "", "...and can be won again")
	_fresh(["u_jost"])
	_m.add_to_stable("mnt_karkadann")
	_gs.won_maps["map_ct19"] = true
	check(_m.check_departures("map_b15", true).is_empty() and _m.owned() == ["mnt_karkadann"], "if the Cinder Track was worked, it stays")
	_gs.won_maps.erase("map_ct19")
	check(_m.check_departures("map_b14", true).is_empty() and _m.check_departures("map_b15", false).is_empty() and _m.owned() == ["mnt_karkadann"], "another map, or a replay of that one, changes nothing")
	_m.assign("u_jost", "mnt_karkadann")
	check(not _m.check_departures("map_b15", true).is_empty() and _m.mount_of("u_jost") == "" and _m.owned().is_empty(), "a Karkadann under a rider leaves them too")

	# ---- the Karkadann: state orders
	_fresh(["u_jost"])
	_m.add_to_stable("mnt_karkadann")
	check(_m.check_departures("map_x10", true).is_empty() and _m.owned() == ["mnt_karkadann"], "before the writ, nothing")
	_gs.deputy = {"unit": "u_jost", "contested": false}
	var lines: Array = _m.check_departures("map_x11", true)
	check(lines.size() == 1 and lines[0].contains("crown's orders") and _m.owned().is_empty(), "the writ is decided: 'state orders and its terms are simply incompatible'")
	_m.add_to_stable("mnt_karkadann")
	check(_m.check_departures("map_x12", true).is_empty() and _m.owned() == ["mnt_karkadann"], "a Karkadann won after the writ is not hit by an old event")

	# ---- the Anzu: a literacy it lacks
	_fresh(["u_jost", "u_ricberta", "u_sigrun"])
	_m.add_to_stable("mnt_anzu")
	check(_m.check_departures("map_a01", true).is_empty() and _m.owned() == ["mnt_anzu"], "nothing revealed, nothing happens")
	_gs.support_ranks["sup_ricberta_sigrun"] = "B"
	lines = _m.check_departures("map_a02", true)
	check(lines.size() == 1 and lines[0].contains("literacy") and _m.owned().is_empty(), "Ricberta's literacy comes out: the Anzu turns to the one who can read")
	_m.add_to_stable("mnt_anzu")
	check(_m.check_departures("map_a03", true).is_empty() and _m.owned() == ["mnt_anzu"], "an Anzu won after the reveal is not hit by an old event")
	_fresh(["u_jost", "u_ricberta", "u_sigrun"])
	_m.add_to_stable("mnt_anzu")
	var ride: Dictionary = _m.assign("u_ricberta", "mnt_anzu")
	if ride["ok"]:
		_gs.support_ranks["sup_ricberta_sigrun"] = "B"
		check(_m.check_departures("map_a02", true).is_empty() and _m.mount_of("u_ricberta") == "mnt_anzu", "if Ricberta herself rides it, there is no literacy it lacks")
	else:
		check(false, "Ricberta could not ride the Anzu: %s" % ride["reason"])
	_fresh(["u_jost", "u_ricberta", "u_sigrun"])
	_m.add_to_stable("mnt_anzu")
	_m.assign("u_jost", "mnt_anzu")
	_gs.support_ranks["sup_ricberta_sigrun"] = "B"
	check(not _m.check_departures("map_a02", true).is_empty() and _m.mount_of("u_jost") == "", "...but with anyone else on its back it goes")

	# ---- the Shadhavar never leaves
	_fresh(["u_jost", "u_brandt", "u_ricberta", "u_sigrun"])
	_m.add_to_stable("mnt_shadhavar")
	_m.assign("u_jost", "mnt_shadhavar")
	_m.unassign("u_jost")
	_gs.deputy = {"unit": "u_jost", "contested": false}
	_gs.support_ranks["sup_ricberta_sigrun"] = "A"
	check(_m.assign("u_brandt", "mnt_shadhavar")["ok"] and _m.check_departures("map_b15", true).is_empty() and _m.mount_of("u_brandt") == "mnt_shadhavar", "no hand-off, write-off, writ or literacy drives the Shadhavar away")

	# ---- on the map
	_fresh(["u_jost"])
	_m.add_to_stable("mnt_karkadann")
	var m: Node = load("res://scenes/map_b15.tscn").instantiate()
	var ids: Array[String] = ["u_jost"]
	m.deploy_unit_ids = ids
	m.enemy_phase_enabled = false
	root.add_child(m)
	await process_frame
	m.map_won = true
	await process_frame
	check(_m.owned().is_empty() and m._reward_text.contains("The Karkadann turns"), "winning the going-rate map takes the Karkadann away and the win screen says so")
	m.queue_free()
	await process_frame
	_fresh(["u_jost"])
	_m.add_to_stable("mnt_karkadann")
	_gs.won_maps["map_ct19"] = true
	m = load("res://scenes/map_b15.tscn").instantiate()
	m.deploy_unit_ids = ids
	m.enemy_phase_enabled = false
	root.add_child(m)
	await process_frame
	m.map_won = true
	await process_frame
	check(_m.owned() == ["mnt_karkadann"], "...unless the Ashland was worked")
	m.queue_free()
	await process_frame

	# ---- the barracks
	_fresh(["u_jost", "u_brandt"])
	_m.add_to_stable("mnt_simurgh")
	_m.assign("u_jost", "mnt_simurgh")
	_m.unassign("u_jost")
	var bs: Node = load("res://scenes/barracks_screen.tscn").instantiate()
	root.add_child(bs)
	await process_frame
	bs.set_mode(4)
	bs._unit_index = bs.unit_ids.find("u_brandt")
	bs._refresh()
	bs._column = 1
	bs.activate()
	check(bs._message.contains("stops being green") and _m.owned().is_empty(), "the barracks tells you she would not be handed on")
	bs.queue_free()
	await process_frame
