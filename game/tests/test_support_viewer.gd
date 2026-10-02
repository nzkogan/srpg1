extends SceneTree
## Headless checks for the support conversation viewer (support_viewer.gd).
## Run from the repo root:
##   godot --headless --path game --script res://tests/test_support_viewer.gd
## Exits 0 if every check passes, 1 otherwise.

var _failures: int = 0
var _checks: int = 0
var _gs: Node
var _sup: Node

func check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: ", label)

func _key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e

func _initialize() -> void:
	_gs = root.get_node("GameState")
	_sup = root.get_node("Supports")
	await process_frame
	await _run()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)

func _reset() -> void:
	_gs.support_recent.clear()
	_gs.support_focus = ""
	_gs.support_ranks.clear()
	_gs.support_points.clear()
	_gs.support_settled_maps.clear()

func _run() -> void:
	_reset()
	var v: Control = load("res://scenes/support_viewer.tscn").instantiate()
	root.add_child(v)
	await process_frame

	# --- structure
	check(v.unit_ids.size() == 18, "lists all 18 main units (got %d)" % v.unit_ids.size())
	check(v._units_list.item_count == 18, "unit list shows 18 rows")
	check(v._partners_list.item_count == 17, "a unit has 17 partners (got %d)" % v._partners_list.item_count)
	check(v.selected_unit() == v.unit_ids[0], "starts on the first unit")
	var first_chain: String = v.selected_chain()
	check(first_chain != "" and v._partner_chains.size() == 17, "a partner chain is selected on load")
	var each_partner_once := {}
	for c in v._partner_chains:
		each_partner_once[_sup.partner_of(c, v.selected_unit())] = true
	check(each_partner_once.size() == 17 and not each_partner_once.has(v.selected_unit()),
		"the 17 rows are 17 distinct other units")

	# --- default view hides text for ranks not reached
	var plat := "sup_dietmar_torvald"     # platonic: C/B/A
	var rom := "sup_ricberta_sigrun"       # romance-eligible: C/B/A/S
	var c_text: String = _sup.scene_text(plat, "C")
	var t0: String = v.view_text(plat)
	check(t0.contains("Dietmar & Torvald"), "header names both units")
	check(t0.contains("No rank yet") and t0.contains("3 to rank C"), "fresh chain reads as unranked, 3 points from C")
	check(t0.contains("Rank C -- locked (3 points)") and t0.contains("Rank A -- locked (15 points)"),
		"unreached ranks show as locked with their thresholds")
	check(not t0.contains(c_text.substr(0, 40)), "locked rank's text is not shown")
	check(not t0.contains("Rank S") and t0.contains("platonic"), "platonic chain never mentions S")
	check(v.view_text(rom).contains("Rank S -- locked (25 points)") and v.view_text(rom).contains("romance-eligible"),
		"romance chain lists S as locked")
	check(v.view_text("") == "", "no chain selected -> empty text")

	check(t0.contains("In battle now: no bonus yet"), "a fresh chain says it gives no bonus yet")
	check(t0.contains("Rank B -- locked (8 points) -- +5 hit/avoid, +1 crit/dodge"), "locked ranks preview their battle effect")

	# --- reached ranks show; later ones stay locked
	_sup.raise_rank(plat)
	_gs.support_points[plat] = 3
	var t1: String = v.view_text(plat)
	check(t1.contains(c_text.substr(0, 40)), "reached rank C shows its text")
	check(t1.contains("Rank B -- locked (8 points)"), "rank B still locked")
	check(t1.contains("In battle now: +3 hit/avoid within 2 tiles of each other"), "a ranked chain states its current battle effect")
	check(t1.contains("Effect: +3 hit/avoid within 2 tiles"), "a reached rank shows its effect under the header")
	check(t1.contains("5 to rank B"), "progress counts down to the next rank")
	_sup.raise_rank(plat); _sup.raise_rank(plat)
	var t2: String = v.view_text(plat)
	check(t2.contains("maximum reached") and not t2.contains("locked"), "platonic chain at A reads as maxed, nothing locked")

	# --- reveal-all
	_reset()
	check(not v.reveal_all, "reveal starts off")
	v.toggle_reveal()
	var tr: String = v.view_text(rom)
	check(v.reveal_all and tr.contains("Rank S") and tr.contains(_sup.scene_text(rom, "S").substr(0, 30)),
		"reveal shows the S text of a romance chain")
	check(tr.contains("(not reached yet)") and not tr.contains("locked ("), "revealed text is labelled as not reached")
	check(not v.view_text(plat).contains("Rank S"), "reveal still shows no S for a platonic chain")
	for id in _sup._by_id:
		var t: String = v.view_text(id)
		var want_s: bool = _sup.is_romance_eligible(id)
		if not (t.contains("Rank C") and t.contains("Rank B") and t.contains("Rank A") and t.contains("Rank S") == want_s):
			check(false, "reveal view of %s has C/B/A and S only if romance" % id)
			break
	check(true, "all 153 chains render C/B/A (+S only when romance) under reveal")
	v.toggle_reveal()

	# --- escaping
	check(v._esc("a [b] c") == "a [lb]b] c", "square brackets in scene text are escaped for BBCode")

	# --- keyboard
	v.select_unit(0)
	v._unhandled_input(_key(KEY_DOWN))
	check(v._unit_index == 1, "Down moves to the next unit")
	v._unhandled_input(_key(KEY_UP))
	v._unhandled_input(_key(KEY_UP))
	check(v._unit_index == 17, "Up from the first unit wraps to the last")
	v.select_unit(0)
	v._unhandled_input(_key(KEY_RIGHT))
	v._unhandled_input(_key(KEY_DOWN))
	check(v._unit_index == 0 and v._partner_index == 1, "after Right, Down moves through partners and leaves the unit")
	var second: String = v.selected_chain()
	check(second != first_chain and v._detail.text == v.view_text(second), "detail pane follows the selected partner")
	v._unhandled_input(_key(KEY_LEFT))
	v._unhandled_input(_key(KEY_DOWN))
	check(v._unit_index == 1 and v._partner_index == 0, "choosing a new unit resets the partner selection")
	v._unhandled_input(_key(KEY_R))
	check(v.reveal_all, "R toggles reveal-all")
	v._unhandled_input(_key(KEY_R))
	check(not v.reveal_all, "R again turns it off")

	# --- mouse
	v.select_unit(0)
	v._partners_list.item_selected.emit(3)
	check(v._partner_index == 3 and v._column == 1, "clicking a partner selects it and activates that column")
	v._units_list.item_selected.emit(5)
	check(v._unit_index == 5 and v._column == 0, "clicking a unit selects it and activates that column")

	# --- partner ordering follows progress
	_reset()
	v.select_unit(0)
	var me: String = v.selected_unit()
	var target: String = v._partner_chains[16]          # last row on a fresh playthrough
	_sup.raise_rank(target)
	v.select_unit(0)
	check(v._partner_chains[0] == target, "a chain that has ranked up moves to the top of the partner list")
	check(v._partners_list.get_item_text(0).contains(" C ") and v._partners_list.get_item_text(0).contains("pts"),
		"partner row shows rank and points")
	_reset()

	# --- every unit loads with 17 partners and a detail pane
	var all_ok := true
	for i in v.unit_ids.size():
		v.select_unit(i)
		if v._partner_chains.size() != 17 or v._detail.text == "":
			all_ok = false
	check(all_ok, "all 18 units show 17 partners and a non-empty detail pane")

	# --- NEW tags, N key, jump-to-chain
	_reset()
	_gs.support_recent.clear()
	check(not v._footer.text.contains("N next"), "no NEW hint when nothing was raised")
	var c1 := "sup_avatar_maren"
	var c2 := "sup_dietmar_torvald"
	_sup.raise_rank(c1); _sup.raise_rank(c2)
	_gs.support_recent = {c1: "C", c2: "C"}
	v.select_unit(0)
	check(v._partners_list.get_item_text(0).ends_with("NEW"), "a recently raised chain is tagged NEW in the partner list")
	check(v.view_text(c1).contains("Rank C[/b]  [color=%s]NEW" % v.NEW_COLOR), "its newest rank header is tagged NEW")
	check(v._footer.text.contains("N next new scene (2)"), "footer offers N with the count")
	check(v.focus_chain(c2) and v.selected_chain() == c2 and v.selected_unit() == "u_dietmar" and v._column == 1,
		"focus_chain selects the first unit, then the partner row")
	check(v._rank_paragraph.get("C", -1) >= 0, "the newest rank's paragraph is known for scrolling")
	check(not v.focus_chain("sup_nobody_nobody"), "focus_chain refuses an unknown chain")
	v._unhandled_input(_key(KEY_N))
	check(v.selected_chain() == c1, "N steps to the next recent chain (sorted order, wrapping)")
	v._unhandled_input(_key(KEY_N))
	check(v.selected_chain() == c2, "N wraps back round")
	_gs.support_recent.clear()
	v._unhandled_input(_key(KEY_N))
	check(v.selected_chain() == c2, "N does nothing when there is nothing new")
	_reset()

	# opening with a focus request lands on that chain, once
	v.queue_free()
	await process_frame
	_gs.support_focus = "sup_ricberta_sigrun"
	var v2: Control = load("res://scenes/support_viewer.tscn").instantiate()
	root.add_child(v2)
	await process_frame
	check(v2.selected_chain() == "sup_ricberta_sigrun" and _gs.support_focus == "",
		"the viewer opens on the requested chain and clears the request")
	v2.queue_free()
	v = load("res://scenes/support_viewer.tscn").instantiate()
	root.add_child(v)
	await process_frame
	check(v.selected_unit() == v.unit_ids[0], "with no request it opens on the first unit")

	# --- the overworld opens the viewer
	v.queue_free()
	var ow: Node = load("res://scenes/overworld.tscn").instantiate()
	root.add_child(ow)
	await process_frame
	check(ResourceLoader.exists(root.get_node("Supports").VIEWER_SCENE),
		"the viewer scene the overworld and win screen open exists")
	ow.queue_free()
