extends SceneTree
## Headless checks for the standard forges and the requisition tier: how many orders may be open (tier 1/2/3
## from the maps won), what the Diadem's and the Assembly's forges will make and for how much, the order
## and its one-chapter cycle, collecting it, and the requisitions screen (O on the overworld).
## Run from the repo root:
##   godot --headless --path game --script res://tests/test_standard_forge.gd
## Exits 0 if every check passes, 1 otherwise.

var _failures: int = 0
var _checks: int = 0
var _gs: Node
var _f: Node
var _eq: Node
var _canon: Node
var _p: Node

func check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: ", label)

func _initialize() -> void:
	_gs = root.get_node("GameState")
	_f = root.get_node("Forge")
	_eq = root.get_node("Equipment")
	_canon = root.get_node("Canon")
	_p = root.get_node("Progression")
	await process_frame
	await _run()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)

func _names(entries: Array) -> Array:
	return entries.map(func(e): return e["name"])

func _entry(entries: Array, id: String) -> Dictionary:
	for e in entries:
		if e["weapon_id"] == id:
			return e
	return {}

func _run() -> void:
	# ---- canon
	var a: Dictionary = _canon.find_by("forges", "forge_id", "frg_standard_a")
	var b: Dictionary = _canon.find_by("forges", "forge_id", "frg_standard_b")
	check(a["access_rule"] == "always" and a["cycle_n"] == 1 and a["house_arts"] == "sword|lance|reason|faith", "the Diadem's forge: always open, one chapter, its house arts")
	check(b["access_rule"] == "always" and b["cycle_n"] == 1 and b["house_arts"] == "axe|bow|brawl", "the Assembly's forge likewise")
	check(_f.standard_forges().size() == 2 and _f.is_standard("frg_standard_b") and not _f.is_standard("frg_kaisareia"), "two standard forges; the masters are not standard")
	check(_p.param("standard_cost_basic") == 150 and _p.param("standard_cost_mid") == 300 and _p.param("standard_cost_high") == 800 and _p.param("standard_house_discount_pct") == 20, "150 / 300 / 800 gold, 20% off house arts")

	# ---- the requisition tier
	_gs.reset()
	check(_f.requisition_tier() == 1 and _f.open_order_limit() == 1, "a new war: tier 1, one open order")
	_gs.won_maps["map_x11"] = true
	check(_f.requisition_tier() == 2 and _f.open_order_limit() == 2, "the Second Writ won: tier 2, two orders")
	_gs.won_maps["map_rf20"] = true
	check(_f.requisition_tier() == 3 and _f.open_order_limit() == 3, "the Reunion won: tier 3, three orders")
	_gs.reset()
	check(_f.standard_forge_for("loc_tally_house") == "frg_standard_a" and _f.standard_forge_for("loc_vetch_gate") == "frg_standard_b" and _f.standard_forge_for("loc_nowhere") == "frg_standard_a", "the Assembly's forge where the Assembly's chapters are, the Diadem's anywhere else")

	# ---- the catalogue
	var cat_a: Array = _f.catalogue("frg_standard_a")
	check(cat_a.size() == 15 and cat_a.all(func(e): return e["tier"] != "high") and _names(cat_a).has("Morningstar"), "tier 1: iron and steel for each of the seven arts, and the Morningstar (15), no silver")
	check(not _names(cat_a).has("Halberd") and not _names(cat_a).has("Censer") and not _names(cat_a).has("Feather Blade") and not _names(cat_a).has("Worn Sword"), "...and no overlap weapons, relics or scavenged gear")
	check(_entry(cat_a, "wpn_sword_basic")["cost"] == 120 and _entry(cat_a, "wpn_sword_mid")["cost"] == 240 and _entry(cat_a, "wpn_axe_basic")["cost"] == 150 and _entry(cat_a, "wpn_axe_mid")["cost"] == 300, "the Diadem's house arts are 20% cheaper (a sword 120/240, an axe full price)")
	var cat_b: Array = _f.catalogue("frg_standard_b")
	check(_entry(cat_b, "wpn_axe_basic")["cost"] == 120 and _entry(cat_b, "wpn_bow_mid")["cost"] == 240 and _entry(cat_b, "wpn_brawl_basic")["cost"] == 120 and _entry(cat_b, "wpn_sword_basic")["cost"] == 150, "the Assembly's: axe, bow and brawl cheaper")
	check(_entry(cat_a, "wpn_sword_basic")["tier"] == "basic" and cat_a[0]["tier"] == "basic" and cat_a[-1]["tier"] == "mid", "basic weapons are listed before steel")
	_gs.won_maps["map_x11"] = true
	check(_f.catalogue("frg_standard_a").size() == 15, "tier 2 adds no silver")
	_gs.won_maps["map_rf20"] = true
	var cat3: Array = _f.catalogue("frg_standard_a")
	check(cat3.size() == 22 and _entry(cat3, "wpn_sword_high")["cost"] == 640 and _entry(cat3, "wpn_bow_high")["cost"] == 800, "tier 3 adds the seven silver weapons (800, or 640 in house)")

	# ---- ordering
	_gs.reset()
	_gs.gold = 100
	var r: Dictionary = _f.can_order("frg_standard_a", "wpn_sword_basic")
	check(not r["ok"] and r["reason"].contains("costs 120 gold (you have 100)"), "not enough gold: %s" % r["reason"])
	check(not _f.can_order("frg_kaisareia", "wpn_sword_basic")["ok"] and not _f.can_order("frg_standard_a", "wpn_feather_blade")["ok"] and not _f.can_order("frg_standard_a", "wpn_halberd")["ok"], "a master is not a standard forge; a relic or an overlap weapon is not on the list")
	check(_f.can_order("frg_standard_a", "wpn_sword_high")["reason"].contains("requisition tier 3"), "silver is for tier 3 (and says so)")
	_gs.gold = 1000
	var works_before: int = _gs.works_started
	var o: Dictionary = _f.order("frg_standard_a", "wpn_sword_basic")
	check(o["ok"] and _gs.gold == 880 and _gs.forge_orders.size() == 1 and _gs.works_started == works_before, "an order pays 120 and is not a master work")
	check(_gs.forge_orders[0]["chapters_left"] == 1 and not _gs.forge_orders[0]["ready"] and _gs.forge_orders[0]["quality"] == "standard", "one chapter to go")
	check(_f.open_standard_orders() == 1 and not _f.can_order("frg_standard_b", "wpn_axe_basic")["ok"] and _f.can_order("frg_standard_b", "wpn_axe_basic")["reason"].contains("allows 1 open order"), "tier 1 allows one open order, across both forges")
	_gs.won_maps["map_x11"] = true
	check(_f.can_order("frg_standard_b", "wpn_axe_basic")["ok"], "tier 2 allows a second")
	check(not _f.order("frg_standard_a", "wpn_sword_basic")["ok"] or _f.open_standard_orders() == 2, "(it is placed)")
	check(not _f.can_order("frg_standard_a", "wpn_lance_basic")["ok"], "...and no third")

	# ---- the cycle
	_gs.reset()
	_gs.gold = 1000
	_gs.won_maps["map_x11"] = true
	_f.order("frg_standard_a", "wpn_sword_basic")
	check(_f.on_map_won(false).is_empty() and not _gs.forge_orders[0]["ready"], "a replayed map does not move the order on")
	var lines: Array[String] = _f.on_map_won(true)
	check(_gs.forge_orders[0]["ready"] and lines.size() == 1 and lines[0].contains("Iron Sword") and lines[0].contains("press O"), "one newly won chapter: it is ready (%s)" % str(lines))
	check(_f.open_standard_orders() == 1, "a finished order is open until it is collected")
	var convoy_before: int = _eq.convoy().size()
	var c: Dictionary = _f.collect(0)
	check(c["ok"] and _eq.convoy().size() == convoy_before + 1 and _eq.convoy()[-1]["weapon_id"] == "wpn_sword_basic" and _eq.convoy()[-1]["uses"] == 45, "collected into the convoy at full uses")
	check(_f.open_standard_orders() == 0 and _gs.forge_orders.is_empty(), "...which frees the slot")
	# a master work and a standard order tick together
	_gs.reset()
	_gs.gold = 1000
	_gs.forge_orders.append({"forge_id": "frg_kaisareia", "material_id": "mat_simurgh", "weapon_id": "wpn_feather_blade", "quality": "prime", "chapters_left": 2, "ready": false})
	_f.order("frg_standard_a", "wpn_lance_basic")
	var l2: Array[String] = _f.on_map_won(true)
	check(l2.size() == 1 and _gs.forge_orders[0]["chapters_left"] == 1 and _gs.forge_orders[1]["ready"], "the master's two-chapter work and the one-chapter order each keep their own clock")
	var json: Variant = _gs.restore(JSON.parse_string(JSON.stringify(_gs.to_dict())))
	check(_gs.validate(json) == "", "orders are valid save data")

	# ---- the screen
	_gs.reset()
	_gs.gold = 1000
	_gs.won_maps["map_d01"] = true
	_f.orders_mode = true
	_gs.world_location = "loc_vetch_gate"
	var sc: Node = load("res://scenes/forge_screen.tscn").instantiate()
	root.add_child(sc)
	await process_frame
	check(not _f.orders_mode and sc.standard, "the screen reads the flag once and clears it")
	var rows: Array = sc.rows()
	check(rows.all(func(r): return r["kind"] == "order" and r["forge_id"] == "frg_standard_b") and rows.size() == 16, "at an Assembly place it offers the Assembly's fifteen weapons and a Warhorse")
	var ix := -1
	for i in rows.size():
		if rows[i]["weapon_id"] == "wpn_axe_basic":
			ix = i
	check(sc.row_label(rows[ix]) == "Order: Iron Axe (120 gold)", "labelled with the house price: %s" % sc.row_label(rows[ix]))
	check(sc.detail_text(rows[ix]).contains("Enter orders it for 120 gold") and sc.detail_text(rows[ix]).contains("Requisition tier 1: 0 of 1"), "the detail says what Enter does and where the tier stands")
	sc._index = ix
	check(sc.activate() and _gs.gold == 880 and _gs.forge_orders.size() == 1, "Enter orders it")
	check(sc.rows()[0]["kind"] == "waiting" and sc.row_label(sc.rows()[0]).contains("In the forge: Iron Axe"), "it now shows as in the forge, ahead of the catalogue")
	sc._index = 3
	check(not sc.activate() and sc._message.contains("allows 1 open order"), "a second is refused with the reason (%s)" % sc._message)
	_f.on_map_won(true)
	check(sc.rows()[0]["kind"] == "collect", "once ready it is the first thing to collect")
	sc._index = 0
	check(sc.activate() and _gs.forge_orders.is_empty() and _eq.convoy().any(func(e): return e["weapon_id"] == "wpn_axe_basic"), "Enter collects it")
	sc.queue_free()
	await process_frame
	# the overworld key
	_gs.reset()
	var ow: Node2D = load("res://scenes/overworld.tscn").instantiate()
	ow.launch_enabled = false
	root.add_child(ow)
	await process_frame
	ow.party_location = "loc_tally_house"
	var ev := InputEventKey.new()
	ev.keycode = KEY_O
	ev.pressed = true
	ow._unhandled_input(ev)
	check(_f.orders_mode and _gs.world_location == "loc_tally_house", "O on the overworld opens the requisitions where the party stands")
	_f.orders_mode = false
	ow._show_location("loc_tally_house", true)
	check(ow.info_label.text.contains("O requisitions"), "the panel lists the key")
	ow.queue_free()
	await process_frame
