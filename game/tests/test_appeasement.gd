extends SceneTree
## Headless checks for appeasing a Named mount that could leave: the signposts, the offering and its cost, and one offering
## holding back one departure (a write-off, the writ, a literacy, a hand-off), in the barracks and the rules.
## Run from the repo root:
##   godot --headless --path game --script res://tests/test_appeasement.gd
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

func _fresh(ids: Array = [], gold := 1000) -> void:
	_gs.reset()
	_join(ids)
	_gs.gold = gold

func _run() -> void:
	# ---- canon
	check(_p.param("appease_cost") == 300, "parameter: an offering costs 300 gold")
	var ok := true
	for mid in ["mnt_simurgh", "mnt_karkadann", "mnt_anzu"]:
		var r: Dictionary = _m.row(mid)
		ok = ok and r["leaves_warning"] != null and r["appease_gift"] != null and r["appease_line"] != null
	check(ok, "the three that can leave each have a signpost, a gift and a line")
	check(_m.row("mnt_shadhavar")["leaves_warning"] == null and _m.row("mnt_warhorse")["appease_gift"] == null, "the Shadhavar and the Warhorse have none")
	check(_m.warning("mnt_karkadann").contains("doves") and _m.warning("mnt_shadhavar") == "", "the signpost says what it is watching for: %s" % _m.warning("mnt_karkadann"))

	# ---- who can be appeased
	_fresh(["u_jost"])
	check(not _m.can_appease("mnt_karkadann")["ok"] and _m.can_appease("mnt_karkadann")["reason"].contains("not with the company"), "not before it is with the company")
	_m.add_to_stable("mnt_karkadann")
	var ap: Dictionary = _m.can_appease("mnt_karkadann")
	check(ap["ok"] and ap["cost"] == 300, "once it is, for 300 gold")
	_m.add_to_stable("mnt_shadhavar"); _m.add_to_stable("mnt_warhorse")
	check(not _m.can_appease("mnt_shadhavar")["ok"] and not _m.can_appease("mnt_warhorse")["ok"] and _m.can_appease("mnt_shadhavar")["reason"].contains("never going to leave"), "what was never going to leave needs nothing")
	_gs.gold = 299
	check(not _m.can_appease("mnt_karkadann")["ok"] and _m.can_appease("mnt_karkadann")["reason"].contains("300 gold") and not _m.appease("mnt_karkadann")["ok"] and _gs.gold == 299 and not _m.pledged("mnt_karkadann"), "too poor: nothing is spent")
	_gs.gold = 300
	check(_m.appease("mnt_karkadann")["ok"] and _gs.gold == 0 and _m.pledged("mnt_karkadann"), "the offering is made: 300 gold, a pledge stands")
	check(_m.warning("mnt_karkadann").contains("An offering stands (grain for the doves") , "the signpost says an offering stands")
	_gs.gold = 1000
	check(not _m.can_appease("mnt_karkadann")["ok"] and _m.can_appease("mnt_karkadann")["reason"].contains("already stands") and not _m.appease("mnt_karkadann")["ok"] and _gs.gold == 1000, "one at a time, and no second charge")

	# ---- a pledge holds back one departure
	var kr: Dictionary = _m.row("mnt_karkadann")
	var lines: Array = _m.check_departures("map_b15", true)
	check(lines == [kr["appease_line"]], "the write-off comes: the Karkadann stays, and is told so: %s" % str(lines))
	check(_m.owned().has("mnt_karkadann") and not _m.pledged("mnt_karkadann"), "...and the offering is spent")
	_gs.deputy = {"unit": "u_jost", "contested": false}
	lines = _m.check_departures("map_x11", true)
	check(lines.size() == 1 and lines[0] == kr["leaves_line"] and not _m.owned().has("mnt_karkadann"), "the writ then takes it: a second departure needs a second offering")
	# the offering for both
	_fresh(["u_jost"])
	_m.add_to_stable("mnt_karkadann")
	_m.appease("mnt_karkadann")
	_m.check_departures("map_b15", true)
	_m.appease("mnt_karkadann")
	_gs.deputy = {"unit": "u_jost", "contested": false}
	check(_m.check_departures("map_x11", true) == [kr["appease_line"]] and _m.owned().has("mnt_karkadann"), "two offerings, two reprieves")
	# an offering made and no trigger: kept
	_fresh(["u_jost"])
	_m.add_to_stable("mnt_karkadann")
	_m.appease("mnt_karkadann")
	check(_m.check_departures("map_b14", true).is_empty() and _m.pledged("mnt_karkadann"), "if nothing happens the offering stands")

	# ---- the Anzu: the literate rider needs none; others do
	_fresh(["u_jost", "u_ricberta", "u_sigrun"])
	_m.add_to_stable("mnt_anzu")
	_m.assign("u_ricberta", "mnt_anzu")
	_m.appease("mnt_anzu")
	_gs.support_ranks["sup_ricberta_sigrun"] = "B"
	check(_m.check_departures("map_a02", true).is_empty() and _m.pledged("mnt_anzu"), "when it was never going to leave (Ricberta rides it) the offering is not spent")
	_fresh(["u_jost", "u_ricberta", "u_sigrun"])
	_m.add_to_stable("mnt_anzu")
	_m.assign("u_jost", "mnt_anzu")
	_m.appease("mnt_anzu")
	_gs.support_ranks["sup_ricberta_sigrun"] = "B"
	var anzu: Array = _m.check_departures("map_a02", true)
	check(anzu == [_m.row("mnt_anzu")["appease_line"]] and _m.mount_of("u_jost") == "mnt_anzu" and not _m.pledged("mnt_anzu"), "otherwise it stays with its rider, and the offering is spent")

	# ---- the Simurgh: the feather may change hands once
	_fresh(["u_jost", "u_brandt"])
	_m.add_to_stable("mnt_simurgh")
	_m.assign("u_jost", "mnt_simurgh")
	_m.unassign("u_jost")
	_m.appease("mnt_simurgh")
	var r: Dictionary = _m.assign("u_brandt", "mnt_simurgh")
	check(r["ok"] and not r.get("left", false) and r["stayed"] == _m.row("mnt_simurgh")["appease_line"] and _m.mount_of("u_brandt") == "mnt_simurgh" and not _m.pledged("mnt_simurgh"), "with an offering she is handed on and stays")
	check(_gs.mounts["holders"]["mnt_simurgh"] == "u_brandt", "...and the new hand now holds the feather")
	_m.unassign("u_brandt")
	r = _m.assign("u_jost", "mnt_simurgh")
	check(r.get("left", false), "the next hand-off needs another offering: she goes")
	_fresh(["u_jost", "u_brandt"])
	_m.add_to_stable("mnt_simurgh")
	_m.assign("u_jost", "mnt_simurgh")
	_m.unassign("u_jost")
	_m.appease("mnt_simurgh")
	_m.assign("u_jost", "mnt_simurgh")
	check(_m.pledged("mnt_simurgh"), "giving her back to the first hand is no change of hands: the offering is kept")

	# ---- a creature that is lost takes the offering with it
	_fresh(["u_jost"])
	_m.add_to_stable("mnt_karkadann")
	_m.assign("u_jost", "mnt_karkadann")
	_m.appease("mnt_karkadann")
	_m.on_rider_fell("u_jost", false)
	check(not _m.pledged("mnt_karkadann"), "a creature lost with its rider takes its offering")

	# ---- saving
	_fresh(["u_jost"])
	_m.add_to_stable("mnt_karkadann")
	_m.appease("mnt_karkadann")
	var back = JSON.parse_string(JSON.stringify(_gs.mounts))
	check(back["pledged"].get("mnt_karkadann", false) == true, "the pledge survives a save")

	# ---- the barracks
	_fresh(["u_jost", "u_brandt"])
	_m.add_to_stable("mnt_warhorse")
	_m.add_to_stable("mnt_karkadann")
	var bs: Node = load("res://scenes/barracks_screen.tscn").instantiate()
	root.add_child(bs)
	await process_frame
	var ev := InputEventKey.new()
	ev.keycode = KEY_5
	ev.pressed = true
	bs._unhandled_input(ev)
	bs._unit_index = bs.unit_ids.find("u_jost")
	bs._refresh()
	var opts: Array = bs.options()
	var idx := -1
	for i in opts.size():
		if opts[i]["kind"] == "appease":
			idx = i
	check(idx >= 0 and opts[idx]["id"] == "mnt_karkadann" and not opts[idx]["locked"] and opts[idx]["data"]["name"].contains("Appease the Karkadann") and opts[idx]["data"]["name"].contains("300 gold"), "the barracks offers the offering to the Karkadann only")
	var appeasements: int = opts.filter(func(o): return o["kind"] == "appease").size()
	check(appeasements == 1, "(one offer: the Warhorse never leaves)")
	bs._option_index = idx
	bs._refresh()
	check(bs.detail_text().contains("doves") and bs.detail_text().contains("Enter makes the offering"), "the detail text carries the signpost and the price")
	bs._option_index = opts.map(func(o): return o["id"]).find("mnt_karkadann")
	bs._refresh()
	check(bs.detail_text().contains("guards the doves"), "so does the mount's own entry")
	bs._option_index = idx
	bs._column = 1
	bs.activate()
	check(_m.pledged("mnt_karkadann") and _gs.gold == 700 and bs._message.contains("offering is made"), "Enter makes it: %s" % bs._message)
	check(bs.options().filter(func(o): return o["kind"] == "appease")[0]["locked"], "...and then it is locked")
	bs.activate()
	check(bs._message.contains("Can't") and _gs.gold == 700, "a second try is refused for free")
	bs.queue_free()
	await process_frame

	# ---- the barracks hands her on, with an offering
	_fresh(["u_jost", "u_brandt"])
	_m.add_to_stable("mnt_simurgh")
	_m.assign("u_jost", "mnt_simurgh")
	_m.unassign("u_jost")
	_m.appease("mnt_simurgh")
	bs = load("res://scenes/barracks_screen.tscn").instantiate()
	root.add_child(bs)
	await process_frame
	bs._mode = 4
	bs._unit_index = bs.unit_ids.find("u_brandt")
	bs._refresh()
	bs._option_index = bs.options().map(func(o): return o["id"]).find("mnt_simurgh")
	bs._column = 1
	bs.activate()
	check(_m.mount_of("u_brandt") == "mnt_simurgh" and bs._message.contains("takes the Simurgh") and bs._message.contains("second feather"), "the barracks tells you she stayed: %s" % bs._message)
	bs.queue_free()
	await process_frame

	# ---- the other offering: a vigil (a unit sits out the next chapter)
	check(_p.param("appease_vigil_company") == 4 and _m.row("mnt_karkadann")["appease_vigil"].contains("doves") and _m.row("mnt_simurgh")["appease_vigil"] != null and _m.row("mnt_anzu")["appease_vigil"] != null and _m.row("mnt_shadhavar")["appease_vigil"] == null, "canon: a vigil for each creature that can leave; four others must remain")
	_fresh(["u_jost", "u_brandt", "u_ricberta", "u_sigrun", "u_dietmar", "u_kheldar"], 0)
	_m.add_to_stable("mnt_karkadann")
	_m.add_to_stable("mnt_shadhavar")
	check(_m.available_company() == 6, "six fielded and free")
	check(_m.can_vigil("mnt_karkadann", "u_jost")["ok"], "no gold needed for a vigil")
	check(not _m.can_vigil("mnt_shadhavar", "u_jost")["ok"] and _m.can_vigil("mnt_shadhavar", "u_jost")["reason"].contains("never going to leave"), "the Shadhavar needs none")
	check(not _m.can_vigil("mnt_karkadann", "u_nobody")["ok"] and not _m.can_vigil("mnt_anzu", "u_jost")["ok"] and _m.can_vigil("mnt_anzu", "u_jost")["reason"].contains("not with the company"), "no stranger, and no creature that is not with the company")
	var vg: Dictionary = _m.keep_vigil("mnt_karkadann", "u_jost")
	check(vg["ok"] and _m.is_resting("u_jost") and _m.resting() == ["u_jost"] and _m.pledged("mnt_karkadann") and _gs.gold == 0 and _m.available_company() == 5, "Jost keeps the vigil: he rests, a pledge stands, no gold is spent")
	check(not _m.can_vigil("mnt_karkadann", "u_brandt")["ok"] and _m.can_vigil("mnt_karkadann", "u_brandt")["reason"].contains("already stands"), "one offering at a time, in gold or in vigil")
	_gs.gold = 1000
	check(not _m.can_appease("mnt_karkadann")["ok"], "...so gold is refused too")
	# the pledge works the same
	check(_m.check_departures("map_b15", true) == [_m.row("mnt_karkadann")["appease_line"]] and _m.owned().has("mnt_karkadann"), "the Karkadann stays when the write-off comes")
	# he is out of the next chapter
	var mp: Node = load("res://scenes/map_d02.tscn").instantiate()
	var ids: Array[String] = ["u_jost", "u_brandt", "u_ricberta"]
	mp.deploy_unit_ids = ids
	mp.enemy_phase_enabled = false
	root.add_child(mp)
	await process_frame
	var deployed: Array = mp.units.map(func(u): return u.get("punit_id"))
	check(not deployed.has("u_jost") and deployed.has("u_brandt") and deployed.has("u_ricberta"), "Jost is not on the field for the next chapter; the others are")
	check(_m.is_resting("u_jost"), "(the vigil lasts until the chapter is won, so a retry or a resume finds him still resting)")
	mp.queue_free()
	await process_frame
	# a memory does not count as a chapter
	var mf: Node = load("res://scenes/map_f01.tscn").instantiate()
	root.add_child(mf)
	await process_frame
	mf._on_map_won()
	check(_m.is_resting("u_jost"), "a flashback is not the next chapter, even when won")
	mf.queue_free()
	await process_frame
	# winning ends it
	mp = load("res://scenes/map_d02.tscn").instantiate()
	mp.deploy_unit_ids = ids
	mp.enemy_phase_enabled = false
	root.add_child(mp)
	await process_frame
	mp._on_map_won()
	check(not _m.is_resting("u_jost") and _m.resting().is_empty() and mp._reward_text.contains("The vigil is over: Jost is back"), "winning the chapter ends the vigil: %s" % mp._reward_text.substr(maxi(0, mp._reward_text.length() - 60)))
	mp.queue_free()
	await process_frame
	_gs.epilogue["deaths"] = {"u_ricberta": {}}
	check(not _m.can_vigil("mnt_karkadann", "u_ricberta")["ok"] and _m.can_vigil("mnt_karkadann", "u_ricberta")["reason"].contains("not with the company"), "the dead cannot keep a vigil")
	_gs.epilogue.erase("deaths")
	# the company must be able to spare them
	_fresh(["u_jost", "u_brandt", "u_ricberta", "u_sigrun"], 0)
	_m.add_to_stable("mnt_karkadann")
	check(not _m.can_vigil("mnt_karkadann", "u_jost")["ok"] and _m.can_vigil("mnt_karkadann", "u_jost")["reason"].contains("needs 4 others"), "with only four fielded, no one can be spared")
	_join(["u_dietmar"])
	check(_m.can_vigil("mnt_karkadann", "u_jost")["ok"], "with five, one can")
	_m.keep_vigil("mnt_karkadann", "u_jost")
	_m.unassign("u_jost")
	_m.add_to_stable("mnt_simurgh")
	check(not _m.can_vigil("mnt_simurgh", "u_jost")["ok"] and _m.can_vigil("mnt_simurgh", "u_jost")["reason"].contains("already resting"), "a resting unit cannot keep a second vigil")
	var back2 = JSON.parse_string(JSON.stringify(_gs.mounts))
	check(back2["resting"] == ["u_jost"], "the vigil survives a save")

	# ---- the barracks offers it
	_fresh(["u_jost", "u_brandt", "u_ricberta", "u_sigrun", "u_dietmar", "u_kheldar"], 0)
	_m.add_to_stable("mnt_karkadann")
	bs = load("res://scenes/barracks_screen.tscn").instantiate()
	root.add_child(bs)
	await process_frame
	bs._mode = 4
	bs._unit_index = bs.unit_ids.find("u_jost")
	bs._refresh()
	var vopts: Array = bs.options().filter(func(o): return o["kind"] == "vigil")
	check(vopts.size() == 1 and not vopts[0]["locked"] and vopts[0]["data"]["name"].contains("Vigil for the Karkadann: Jost") and vopts[0]["data"]["name"].contains("sitting out the next chapter"), "the barracks offers the vigil, naming who keeps it: %s" % (vopts[0]["data"]["name"] if not vopts.is_empty() else "-"))
	var vi: int = bs.options().map(func(o): return o["kind"]).find("vigil")
	bs._option_index = vi
	bs._refresh()
	check(bs.detail_text().contains("costs no gold") and bs.detail_text().contains("not available for the next chapter"), "its text says what it costs")
	bs._column = 1
	bs.activate()
	check(_m.is_resting("u_jost") and _m.pledged("mnt_karkadann") and _gs.gold == 0 and bs._message.contains("sit out the next chapter"), "Enter keeps it: %s" % bs._message)
	bs.activate()
	check(bs._message.contains("Can't"), "a second try is refused")
	bs.queue_free()
	await process_frame
