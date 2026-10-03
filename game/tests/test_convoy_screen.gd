extends SceneTree
## Headless checks for the convoy screen (convoy_screen.gd): lists, selection,
## equipping, taking and storing, wield checks in the detail pane, keys and mouse.
## Run from the repo root:
##   godot --headless --path game --script res://tests/test_convoy_screen.gd
## Exits 0 if every check passes, 1 otherwise.

var _failures: int = 0
var _checks: int = 0
var _eq: Node
var _gs: Node

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

func _reset() -> void:
	_gs.inventories.clear(); _gs.convoy.clear(); _gs.equipment_ready = false; _gs.drops_claimed.clear()

func _initialize() -> void:
	_eq = root.get_node("Equipment")
	_gs = root.get_node("GameState")
	await process_frame
	_reset()
	var s: Control = load("res://scenes/convoy_screen.tscn").instantiate()
	root.add_child(s)
	await process_frame

	# --- structure
	check(s.unit_ids.size() == 18 and s._units_list.item_count == 18, "18 units listed")
	check(s._convoy_list.item_count == 7, "the convoy shows its 7 starting weapons")
	check(s.selected_unit() == s.unit_ids[0] and s._inv_list.item_count == 1, "the first unit and their starting weapon show")
	check(s._inv_list.get_item_text(0) == "* Iron Sword (45)", "the equipped weapon is starred: '%s'" % s._inv_list.get_item_text(0))
	check(s._units_list.get_item_text(0).contains("Iron Sword (45)"), "roster rows show what each unit has equipped")
	var edda_i: int = s.unit_ids.find("u_edda")
	check(s._units_list.get_item_text(edda_i).ends_with("--"), "an unarmed unit shows '--'")

	# --- keys: Down moves units; Right switches columns
	s._unhandled_input(_key(KEY_DOWN))
	check(s._unit_index == 1 and s.selected_unit() == s.unit_ids[1], "Down moves to the next unit")
	s._unhandled_input(_key(KEY_UP)); s._unhandled_input(_key(KEY_UP))
	check(s._unit_index == 17, "Up from the first unit wraps")
	s._unit_index = s.unit_ids.find("u_jost")
	s._refresh_all()
	s._unhandled_input(_key(KEY_RIGHT))
	check(s._column == 1 and s.highlighted_entry()["weapon_id"] == "wpn_axe_basic", "Right moves to the inventory, highlighting Jost's axe")
	s._unhandled_input(_key(KEY_RIGHT))
	check(s._column == 2 and not s.highlighted_entry().is_empty(), "Right again: the convoy")
	s._unhandled_input(_key(KEY_RIGHT))
	check(s._column == 2, "can't go past the last column")

	# --- take: Enter on a convoy weapon puts it in the selected unit's inventory
	var steel_axe := -1
	for i in _eq.convoy().size():
		if _eq.convoy()[i]["weapon_id"] == "wpn_axe_mid": steel_axe = i
	s._convoy_index = steel_axe
	s._refresh_all()
	s._unhandled_input(_key(KEY_ENTER))
	check(_eq.inventory("u_jost").size() == 2 and s._convoy_list.item_count == 6, "Enter in the convoy takes the weapon")
	check(s._footer.text.contains("Jost takes the Steel Axe (30)"), "the footer says what happened: %s" % s._footer.text.split("\n")[0])
	# --- equip: Enter on the inventory entry
	s.switch_column(1)
	s._inv_index = 1
	s._refresh_all()
	s._unhandled_input(_key(KEY_ENTER))
	check(_eq.equipped("u_jost")["weapon_id"] == "wpn_axe_mid" and s._inv_list.get_item_text(0).begins_with("* Steel Axe"), "Enter in the inventory equips it (it moves to the front, starred)")
	# --- a weapon the unit can't wield
	var sword_i := -1
	for i in _eq.convoy().size():
		if _eq.convoy()[i]["weapon_id"] == "wpn_sword_mid": sword_i = i
	s.switch_column(2)
	s._convoy_index = sword_i
	s._refresh_all()
	check(s.detail_text().contains("can't wield this -- missing sword"), "the detail pane says Jost can't wield a sword and why")
	s._unhandled_input(_key(KEY_T))
	check(_eq.inventory("u_jost").size() == 3, "T takes it anyway: anyone may carry a weapon they can't use")
	s.switch_column(1)
	var last: int = _eq.inventory("u_jost").size() - 1
	s._inv_index = last
	s._refresh_all()
	check(s._inv_list.get_item_text(last).contains("can't use"), "an unwieldable carried weapon is tagged")
	s._unhandled_input(_key(KEY_ENTER))
	check(_eq.equipped("u_jost")["weapon_id"] == "wpn_axe_mid" and s._footer.text.contains("can't equip"), "equipping it is refused, with a message")
	# --- store
	var convoy_n: int = _eq.convoy().size()
	s._unhandled_input(_key(KEY_T))
	check(_eq.convoy().size() == convoy_n + 1 and _eq.inventory("u_jost").size() == 2, "T in the inventory stores the weapon back")
	# --- full inventory
	while _eq.inventory("u_jost").size() < 5:
		_eq.convoy_add("wpn_axe_basic")
		_eq.take("u_jost", _eq.convoy().size() - 1)
	s.switch_column(2)
	s._convoy_index = 0
	s._refresh_all()
	s._unhandled_input(_key(KEY_ENTER))
	check(s._footer.text.contains("already carrying 5 weapons") and _eq.inventory("u_jost").size() == 5, "a full inventory refuses with a message")
	check(s._footer.text.contains("carrying 5/5"), "the footer shows the carry count")

	# --- the halberd: nobody can use it yet
	_eq.convoy_add("wpn_halberd")
	s.switch_column(2)
	s._convoy_index = _eq.convoy().size() - 1
	s._refresh_all()
	var d: String = s.detail_text()
	check(d.contains("Halberd") and d.contains("requires axe + lance"), "the detail pane names the halberd's two arts")
	check(d.contains("Effective vs riding (x2 might)") and d.contains("neutral on the weapon triangle"), "...its effectiveness and triangle neutrality")
	check(d.contains("No one on the roster can wield this yet."), "...and that no one can wield it yet")
	check(d.contains("Might 9") and d.contains("Weight 12"), "...and its numbers")
	# attack speed for a wielder
	s.switch_column(0)
	s._unit_index = s.unit_ids.find("u_jost")
	s.switch_column(2)
	s._convoy_index = 0                      # whichever weapon is first
	s._refresh_all()
	var first_wid: String = _eq.convoy()[0]["weapon_id"]
	if _eq.can_wield("u_jost", first_wid):
		check(s.detail_text().contains("Attack speed with it"), "a wieldable weapon shows the attack speed it gives")
	# axe_mid for Jost: weight 8 vs str 8 -> no burden
	var steel_axe_i := -1
	for i in _eq.convoy().size():
		if _eq.convoy()[i]["weapon_id"] == "wpn_axe_mid": steel_axe_i = i
	if steel_axe_i < 0:
		_eq.convoy_add("wpn_axe_mid"); steel_axe_i = _eq.convoy().size() - 1
	s._convoy_index = steel_axe_i
	s._refresh_all()
	check(s.detail_text().contains("Attack speed with it: 8 (spd 8)"), "Jost (str 8, spd 8) with a steel axe (weight 8): speed 8 (%s)" % s.detail_text().split("\n")[-3])

	# --- mouse
	s._units_list.item_selected.emit(3)
	check(s._unit_index == 3 and s._column == 0, "clicking a unit selects it and activates that column")
	s._convoy_list.item_selected.emit(1)
	check(s._convoy_index == 1 and s._column == 2, "clicking a convoy weapon highlights it")

	# --- every unit renders
	var ok := true
	for i in s.unit_ids.size():
		s._on_clicked(0, i)
		if s._detail.text == "" or s._title.text == "":
			ok = false
	check(ok, "all 18 units render")
	s.queue_free()
	await process_frame
	_reset()
	check(ResourceLoader.exists(_eq.SCREEN_SCENE), "the overworld's convoy scene exists")
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)
