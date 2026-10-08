extends SceneTree
## Headless checks for the barracks' Paragon mode: the requirements checklist,
## deed list, class menu, previews, taking the tier, and the ready markers.
## Run from the repo root:
##   godot --headless --path game --script res://tests/test_barracks_paragon.gd
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
	_gs.deeds.clear(); _gs.won_maps.clear()

func _initialize() -> void:
	_p = root.get_node("Progression")
	_gs = root.get_node("GameState")
	await process_frame
	_reset()
	# a certified level-30 Jost and a level-12 Ricberta
	_p.state("u_jost"); _gs.progression["u_jost"]["level"] = 15
	_gs.gold = 100000
	_p.promote("u_jost", "cls_warrior")
	_gs.progression["u_jost"]["level"] = 30
	_gs.gold = 1200
	_p.ensure("u_ricberta"); _gs.progression["u_ricberta"]["level"] = 12
	var s: Control = load("res://scenes/barracks_screen.tscn").instantiate()
	root.add_child(s)
	await process_frame
	s._unit_index = s.unit_ids.find("u_jost")
	s.set_mode(3)
	s.switch_column(1)

	var d: String = s.detail_text()
	check(s._options_caption.text == "Paragon classes", "the middle column is captioned Paragon classes")
	check(d.contains("[x] Certified") and d.contains("[x] Level 30") and d.contains("[ ] 1 deed that gates paragon") and d.contains("[x] 1000 gold"), "the checklist ticks what's met and leaves the deed open")
	check(d.contains("Waiting adds 150 gold per level past 30") and d.contains("Deeds never expire"), "it states the cost of waiting and that deeds never expire")
	check(d.contains("Deeds that gate paragon") and d.contains("[ ] boss kill") and d.contains("[ ] solo hold") and d.contains("[ ] no hit map"), "the first three recordable deeds are listed with their triggers")
	check(d.contains("[ ] capture") and d.contains("-- 0 of 5") and not d.contains("not recordable yet"), "capture is recordable too, with its count (0 of 5)")
	check(d.contains("kills a named boss in single combat"), "each deed shows canon's trigger text")
	var names: Array = []
	for o in s.options():
		names.append(o["data"]["name"])
	check(names == ["Jaguar knight", "Eagle knight"], "an axe Warrior sees both axe paragons")
	check(not s._units_list.get_item_text(s._unit_index).ends_with("^"), "no ^ marker without a deed")
	# earn a deed -> ready
	_p.record_deed("u_jost", "ep_solohold")
	s._refresh()
	d = s.detail_text()
	check(d.contains("[x] 1 deed that gates paragon") and d.contains("[x] solo hold") and d.contains("holds a choke alone") and d.contains("x1"), "the earned deed is ticked, with its count")
	check(s._units_list.get_item_text(s._unit_index).ends_with("^"), "the roster marks him ^ (ready for paragon)")
	# preview and refusal
	s._option_index = 1
	s._refresh()
	d = s.detail_text()
	check(d.contains("Eagle knight") and d.contains("flying movement") and d.contains("HP ") and d.contains("+5 more to every growth rate"), "the Eagle knight preview shows the stats and the growth bonus")
	_gs.gold = 999
	s.activate()
	check(s._message.contains("needs 1000 gold (have 999)") and not _p.is_paragon("u_jost"), "too poor: refused with the reason")
	check(s.detail_text().contains("[ ] 1000 gold"), "...and the checklist shows the gold item open")
	_gs.gold = 3000
	var hp_before: int = _p.stats_for("u_jost")["hp"]
	s.activate()
	check(_p.is_paragon("u_jost") and _p.class_id_of("u_jost") == "cls_eagle_knight" and _gs.gold == 2000, "Enter takes the Eagle knight for 1000")
	check(s._message.contains("becomes an Eagle knight for 1000 gold"), "the message says so (%s)" % s._message)
	check(s._units_list.get_item_text(s._unit_index).contains("Eagle knight") and not s._units_list.get_item_text(s._unit_index).ends_with("^"), "the roster row updates and loses the marker")
	check(s.detail_text().contains("Paragon (Eagle knight)") and s.detail_text().contains("Nothing further to take"), "the mode now says he is paragon")
	check(_p.stats_for("u_jost")["hp"] != hp_before, "stats changed")
	# a level-12 unit: a clear explanation
	s._unit_index = s.unit_ids.find("u_ricberta")
	s._option_index = 0
	s._refresh()
	d = s.detail_text()
	check(d.contains("[ ] Certified") and d.contains("[ ] Level 30") and d.contains("Certify first."), "an uncertified unit is told to certify first")
	# faith: no paragon class
	_p.ensure("u_maren"); _gs.progression["u_maren"]["level"] = 15
	_gs.gold = 100000; _p.promote("u_maren", "cls_bishop")
	s.unit_ids.append("u_maren")                         # the screen lists the fielded at open time; add her as if fielded earlier
	s._units_list.add_item("Maren")
	s._on_clicked(0, s.unit_ids.find("u_maren"))
	check(s.detail_text().contains("Krivis") and not s.detail_text().contains("No paragon class fits"), "faith: the Krivis is offered (the canon gap, filled)")
	check(s._options_caption.text == "Paragon classes" and s.options().size() == 1 and s.options()[0]["data"]["name"] == "Krivis", "and it is the one option in the middle column")
	s._mode = s.MODE_PARAGON
	s._refresh()
	check(s.detail_text().contains("Krivis") and s.detail_text().contains("infantry movement"), "its preview reads like the others (%s)" % s.detail_text().get_slice("\n", 8))
	# every unit in paragon mode renders
	var ok := true
	for i in s.unit_ids.size():
		s._on_clicked(0, i)
		if s._detail.text == "":
			ok = false
	check(ok, "every fielded unit renders in Paragon mode")
	s.queue_free()
	await process_frame
	_reset()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)
