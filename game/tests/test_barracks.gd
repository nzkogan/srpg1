extends SceneTree
## Headless checks for the barracks screen (barracks_screen.gd) and
## Progression.preview_promotion: lists, modes, certifying, recertifying,
## choosing abilities, the cost messaging, keys and mouse.
## Run from the repo root:
##   godot --headless --path game --script res://tests/test_barracks.gd
## Exits 0 if every check passes, 1 otherwise.

var _failures: int = 0
var _checks: int = 0
var _p: Node
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
	_gs.progression.clear(); _gs.gold = 0; _gs.unlocked_classes.clear(); _gs.income_claimed.clear()
	_gs.inventories.clear(); _gs.convoy.clear(); _gs.equipment_ready = false; _gs.drops_claimed.clear()

func _initialize() -> void:
	_p = root.get_node("Progression")
	_gs = root.get_node("GameState")
	await process_frame
	_reset()

	# --- preview_promotion is read-only and matches what promote() does
	_p.state("u_jost"); _gs.progression["u_jost"]["level"] = 15
	var now: Dictionary = _p.stats_for("u_jost")
	var preview: Dictionary = _p.preview_promotion("u_jost", "cls_axe_knight")
	check(_p.stats_for("u_jost") == now and not _p.is_promoted("u_jost"), "previewing changes nothing")
	_gs.gold = 5000
	_p.promote("u_jost", "cls_axe_knight")
	check(_p.stats_for("u_jost") == preview, "the preview equals the real post-certification stats")
	check(_p.preview_promotion("u_jost", "cls_nonesuch").is_empty() and _p.preview_promotion("u_nobody", "cls_warrior").is_empty(), "unknown class/unit: empty")
	_reset()

	# the barracks lists only units that have been fielded (have a state)
	for uid in ["u_jost", "u_ricberta", "u_dietmar", "u_torvald", "u_avatar", "u_kest", "u_edda"]:
		_p.ensure(uid)
	var s: Control = load("res://scenes/barracks_screen.tscn").instantiate()
	root.add_child(s)
	await process_frame

	# --- structure
	check(s.unit_ids.size() == 7 and s._units_list.item_count == 7, "only the 7 fielded units are listed")
	check(not s.unit_ids.has("u_rinsa") and not _p.has_state("u_rinsa"), "unfielded units aren't listed -- and opening the screen didn't join them")
	check(s._units_list.get_item_text(s.unit_ids.find("u_jost")).contains("Lv 5") and s._units_list.get_item_text(s.unit_ids.find("u_jost")).contains("Trained (axe)"), "rows show level and class")
	check(s._title.text.contains("Gold: 0") and s._title.text.contains("[Certify]"), "the title shows gold and the mode")
	check(s._units_list.get_item_text(s.unit_ids.find("u_dietmar")).contains("Paladin") and not s._units_list.get_item_text(s.unit_ids.find("u_dietmar")).ends_with("*"), "Dietmar is already certified: no ready marker")

	# --- keys: modes
	s._unhandled_input(_key(KEY_TAB))
	check(s._mode == 1 and s._title.text.contains("[Recertify]"), "Tab cycles the mode")
	s._unhandled_input(_key(KEY_3))
	check(s._mode == 2 and s._title.text.contains("[Abilities]"), "3 selects Abilities")
	s._unhandled_input(_key(KEY_1))
	check(s._mode == 0, "1 selects Certify")

	# --- Jost, level 5: cannot certify yet; the screen says why and what it will cost
	s._unit_index = s.unit_ids.find("u_jost")
	s._refresh()
	var d: String = s.detail_text()
	check(d.contains("Certification opens at level 15 (10 to go)"), "level 5: 'opens at level 15 (10 to go)'")
	check(d.contains("300 gold at level 15, and 100 more for every level after"), "...and states the fee and what waiting costs")
	var names: Array = []
	for o in s.options():
		names.append(o["data"]["name"])
	check(names.has("Warrior") and names.has("Billman"), "options list the order classes and the (locked) hybrids")
	s.switch_column(1)
	s._unhandled_input(_key(KEY_ENTER))
	check(s._message.contains("needs level 15") and not _p.is_promoted("u_jost"), "Enter too early: refused with the reason (%s)" % s._message)

	# --- level 15, no gold
	_gs.progression["u_jost"]["level"] = 15
	s._refresh()
	d = s.detail_text()
	check(d.contains("costs 300 gold now") and d.contains("Every level you wait adds 100") and d.contains("Short by 300 gold"), "level 15, broke: the fee, the waiting cost, and the shortfall")
	check(s._units_list.get_item_text(s._unit_index).ends_with("*"), "the roster marks him ready to certify")
	_gs.progression["u_jost"]["level"] = 18
	s._refresh()
	check(s.detail_text().contains("costs 600 gold now"), "level 18: the fee has risen to 600")
	_gs.progression["u_jost"]["level"] = 15
	s._refresh()
	# preview of the highlighted class
	var warrior_i := -1
	for i in s.options().size():
		if s.options()[i]["id"] == "cls_warrior": warrior_i = i
	s._option_index = warrior_i
	s._refresh()
	d = s.detail_text()
	check(d.contains("Warrior") and d.contains("HP 23 -> 27 (+4)") and d.contains("STR 8 -> 11 (+3)"), "the detail previews the stats: HP 23 -> 27, STR 8 -> 11")
	check(d.contains("+5 to every growth rate"), "...and the growth bonus")
	# locked hybrid shows why
	var bill_i := -1
	for i in s.options().size():
		if s.options()[i]["id"] == "cls_billman": bill_i = i
	s._option_index = bill_i
	s._refresh()
	check(s._options_list.get_item_text(bill_i).contains("(locked)") and s.detail_text().contains("Locked: win"), "a locked hybrid is marked and explained")
	s.activate()
	check(s._message.contains("Can't certify") and not _p.is_promoted("u_jost"), "certifying a locked hybrid is refused")

	# --- certify for real
	_gs.gold = 1000
	s._option_index = warrior_i
	s._refresh()
	s.activate()
	check(_p.is_promoted("u_jost") and _p.class_id_of("u_jost") == "cls_warrior" and _gs.gold == 700, "Enter certifies him as a Warrior for 300 gold")
	check(s._message.contains("certifies as a Warrior for 300 gold") and s._title.text.contains("Gold: 700"), "the message and the gold readout update")
	check(s._units_list.get_item_text(s._unit_index).contains("Warrior") and not s._units_list.get_item_text(s._unit_index).ends_with("*"), "the roster row now reads Warrior")
	check(s.detail_text().contains("Already certified") and s.detail_text().contains("(certified)"), "the detail reflects it")

	# --- recertify (Warrior is infantry -> Housecarl armor)
	s.set_mode(1)
	s.switch_column(1)
	check(s.options().size() == 3 and s.detail_text().contains("Switching costs 150 gold"), "Recertify lists 3 classes and the half fee (150)")
	var hc := -1
	for i in s.options().size():
		if s.options()[i]["id"] == "cls_housecarl": hc = i
	s._option_index = hc
	s._refresh()
	check(s.detail_text().contains("Housecarl") and s.detail_text().contains("DEF "), "the detail previews the shape change")
	s.activate()
	check(_p.class_id_of("u_jost") == "cls_housecarl" and _gs.gold == 550, "Enter switches class for 150")
	check(not _p.is_promoted("u_ricberta") and s.options().size() == 3, "(options follow the unit)")
	s._unit_index = s.unit_ids.find("u_ricberta")
	s._refresh()
	check(s.options().is_empty() and s.detail_text().contains("Only a certified unit"), "an unpromoted unit has nothing to recertify, and the screen says so")

	# --- abilities
	s.set_mode(2)
	s._unit_index = s.unit_ids.find("u_jost")
	s._option_index = 0
	s.switch_column(1)
	var slots: int = _p.slots("u_jost")
	check(s._options_caption.text == "Abilities (%d / %d slots)" % [_p.chosen("u_jost").size(), slots], "the caption shows slots used (%s)" % s._options_caption.text)
	var smite_i := -1
	for i in s.options().size():
		if s.options()[i]["id"] == "ab_smite": smite_i = i
	check(smite_i == 0 and s._options_list.get_item_text(0).begins_with("[x]"), "Smite (Housecarl) leads the pool and is chosen by default")
	check(s.detail_text().contains("+3 dmg") and s.detail_text().contains("Canon signature skill"), "the detail describes the ability")
	s._option_index = 0
	s.activate()
	check(not _p.chosen("u_jost").has("ab_smite") and s._options_list.get_item_text(0).begins_with("[ ]"), "Enter on a chosen ability removes it")
	s.activate()
	check(_p.chosen("u_jost").has("ab_smite"), "...and again puts it back")
	# fill every slot then try one more
	var chosen_n: int = _p.chosen("u_jost").size()
	for i in s.options().size():
		if not s.options()[i]["chosen"]:
			s._option_index = i
			s.activate()
			break
	var after_n: int = _p.chosen("u_jost").size()
	if after_n >= slots:
		for i in s.options().size():
			if not s.options()[i]["chosen"]:
				s._option_index = i
				s.activate()
				check(s._message.contains("No free slot") and _p.chosen("u_jost").size() == slots, "a full set refuses another, with a message")
				break
	check(chosen_n <= slots, "never more chosen than slots")

	# --- moving between units resets the option cursor; mouse works
	s.set_mode(0)
	s.switch_column(0)
	s._unhandled_input(_key(KEY_DOWN))
	check(s._option_index == 0, "choosing another unit resets the option cursor")
	var ric: int = s.unit_ids.find("u_ricberta")
	s._units_list.item_selected.emit(ric)
	check(s._unit_index == ric and s._column == 0, "clicking a unit selects it")
	s._options_list.item_selected.emit(1)
	check(s._option_index == 1 and s._column == 1, "clicking an option highlights it")

	# --- personal milestone and the shadow line render
	for uid in ["u_avatar", "u_kest", "u_dietmar", "u_edda"]:
		s._unit_index = s.unit_ids.find(uid)
		s._on_clicked(0, s._unit_index)
		check(s.detail_text() != "", "%s renders" % uid)
	s._unit_index = s.unit_ids.find("u_avatar")
	_gs.progression["u_avatar"]["level"] = 15
	s._on_clicked(0, s._unit_index)
	check(s.options().size() == 1 and s.options()[0]["id"] == "cls_strategist", "the avatar's milestone shows as a single option")
	var ok := true
	for i in s.unit_ids.size():
		s._on_clicked(0, i)
		for m in 3:
			s.set_mode(m)
			if s._detail.text == "": ok = false
	check(ok, "every unit renders in every mode")

	s.queue_free()
	await process_frame
	# nobody fielded: an empty, explained screen
	_reset()
	var e: Control = load("res://scenes/barracks_screen.tscn").instantiate()
	root.add_child(e)
	await process_frame
	check(e.unit_ids.is_empty() and e.detail_text().contains("No one has been fielded yet"), "an empty barracks says so")
	e._unhandled_input(_key(KEY_DOWN)); e._unhandled_input(_key(KEY_ENTER)); e._unhandled_input(_key(KEY_TAB))
	check(true, "keys on an empty barracks don't crash")
	e.queue_free()
	await process_frame
	check(ResourceLoader.exists(_p.SCREEN_SCENE), "the overworld's barracks scene exists")
	_reset()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)
