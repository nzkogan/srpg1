extends SceneTree
## Headless checks for deputy scoring: the ledger's weights and events, the surveyor's
## radius, who the crown picks and how a contest works, Column B's supply attachment, and
## the writ screen.
## Run from the repo root:
##   godot --headless --path game --script res://tests/test_deputy.gd
## Exits 0 if every check passes, 1 otherwise.

var _failures: int = 0
var _checks: int = 0
var _p: Node
var _gs: Node
var _d: Node
var _df: Node
var _canon: Node

func check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: ", label)

func _initialize() -> void:
	_p = root.get_node("Progression")
	_gs = root.get_node("GameState")
	_d = root.get_node("Deputy")
	_df = root.get_node("Defections")
	_canon = root.get_node("Canon")
	await process_frame
	await _run()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)

func _fresh() -> void:
	_gs.reset()

func _join(ids: Array, level := 10) -> void:
	for u in ids:
		_p.state(u)
		_gs.progression[u]["level"] = level

func _map(scene: String, deploy: Array, positions: Array, specs: Array = []) -> Node:
	var m: Node = load("res://scenes/%s.tscn" % scene).instantiate()
	var ids: Array[String] = []
	ids.assign(deploy)
	m.deploy_unit_ids = ids
	m.enemy_phase_enabled = false
	root.add_child(m)
	await process_frame
	for e in m.enemies:
		m._remove_enemy_token(e)
	m.enemies.clear(); m.dens.clear()
	for i in deploy.size():
		m.unit_positions[deploy[i]] = positions[i]
	var nid := 0
	for spec in specs:
		nid = m._spawn_enemy_instance(spec["arch"], spec["pos"], spec.get("kind", "mook"), nid)
	var r := RandomNumberGenerator.new()
	r.seed = 3
	m.rng_override = r
	return m

func _arch(name: String, over := {}) -> Dictionary:
	var d := {"enemy_id": "ea_t_" + name, "name": name, "weapon_art": "sword", "weapon_tier": "worn", "movement_type": "infantry",
		"level": 5, "hp": 1, "str": 0, "mag": 0, "dex": 0, "spd": 0, "lck": 0, "def": 0, "res": 0}
	d.merge(over, true)
	return d

func _key(n: Node, keycode: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.pressed = true
	n._unhandled_input(ev)

func _run() -> void:
	# ---- canon
	_fresh()
	check(_d.weight("writ_deed") == 2.0 and _d.weight("legible") == 1.5 and _d.weight("on_objective") == 1.0 and _d.weight("witnessed") == 1.0, "canon's weights: deed 2, delivery/hold/dispersal 1.5, objective 1, witnessed 1")
	check(_d.weight("raw_kill") == 0.5 and _d.weight("unwitnessed_kill") == 0.0 and _d.weight("paralogue_deed") == 0.0 and _d.weight("literacy") == 0.25, "kill 0.5, unwitnessed kill 0, paralogue deed 0, literacy 0.25")
	check(_p.param("surveyor_radius") == 4 and _p.param("column_b_supply_gold") == 100, "radius 4; Column B's attachment is 100 gold")
	check(_d.map_kind("map_d03") == "writ" and _d.map_kind("map_x11") == "writ" and _d.map_kind("map_k21") == "writ", "main-story maps are writ chapters")
	check(_d.map_kind("map_p_macuil") == "paralogue" and _d.map_kind("map_f00") == "" and _d.map_kind("map_nonesuch") == "", "paralogues are marked, the prologue and unknowns are neither")
	check(_d.candidates().is_empty(), "nobody has joined: no candidates")
	_join(["u_ricberta", "u_sigrun", "u_gunnar", "u_jost", "u_waldrada"])
	check(_d.candidates().size() == 4 and _d.candidates().has("u_ricberta") and _d.candidates().has("u_waldrada"), "candidates are the joined deputy_candidate units (%s)" % str(_d.candidates()))
	check(not _d.candidates().has("u_jost") and not _d.candidates().has("u_avatar"), "(Jost isn't one)")
	_df.on_map_won("map_v21", true)
	check(not _d.candidates().has("u_waldrada"), "a defector is no longer a candidate")

	# ---- events
	_fresh()
	_join(["u_ricberta", "u_sigrun", "u_gunnar"])
	_d.on_deed("u_sigrun", "ep_nohit", "map_d03", false)
	check(_d.count("u_sigrun", "writ_deed") == 1 and _d.count("u_sigrun", "witnessed") == 0 and _d.count("u_sigrun", "legible") == 0 and _d.score("u_sigrun") == 2.0, "a deed on a main-story chapter: 2")
	_d.on_deed("u_sigrun", "ep_solohold", "map_d03", true)
	check(_d.count("u_sigrun", "writ_deed") == 2 and _d.count("u_sigrun", "legible") == 1 and _d.count("u_sigrun", "witnessed") == 1 and _d.score("u_sigrun") == 2.0 + 2.0 + 1.5 + 1.0, "a witnessed solo hold: 2 + 1.5 + 1 more (total 7.5)")
	_d.on_deed("u_gunnar", "ep_talk", "map_p_macuil", true)
	check(_d.count("u_gunnar", "paralogue_deed") == 1 and _d.score("u_gunnar") == 0.0 and _d.count("u_gunnar", "writ_deed") == 0, "a deed on a paralogue is written down and worth nothing")
	_d.on_deed("u_gunnar", "ep_talk", "map_f00", true)
	check(_d.count("u_gunnar", "writ_deed") == 0 and _d.count("u_gunnar", "paralogue_deed") == 1, "(the prologue isn't in the ledger)")
	_d.on_kill("u_ricberta", "map_d03", true)
	_d.on_kill("u_ricberta", "map_d03", false)
	check(_d.count("u_ricberta", "raw_kill") == 1 and _d.count("u_ricberta", "unwitnessed_kill") == 1 and _d.count("u_ricberta", "witnessed") == 1 and _d.score("u_ricberta") == 1.5, "a witnessed kill 0.5 + 1; an unwitnessed one 0")
	_d.on_kill("u_ricberta", "map_p_macuil", true)
	check(_d.count("u_ricberta", "raw_kill") == 1, "kills on a paralogue aren't counted")
	_d.on_objective("u_gunnar", "map_d03", true)
	_d.on_objective("u_gunnar", "map_d03", false)
	check(_d.count("u_gunnar", "on_objective") == 2 and _d.count("u_gunnar", "witnessed") == 1 and _d.score("u_gunnar") == 3.0, "the stated objective: 1 each, +1 if witnessed")
	var bd: Array = _d.breakdown("u_sigrun")
	check(bd.size() == 3 and bd[0]["factor"] == "writ_deed" and bd[0]["points"] == 4.0, "the breakdown lists each counted factor with its points (%s)" % str(bd.map(func(b): return b["factor"])))

	# ---- literacy: Ricberta only, only once a support has revealed it
	_fresh()
	_join(["u_ricberta", "u_sigrun"])
	check(not _d.literacy_revealed("u_ricberta") and _d.score("u_ricberta") == 0.0, "nothing revealed yet")
	_gs.support_ranks["sup_ricberta_sigrun"] = "C"
	check(not _d.literacy_revealed("u_ricberta"), "rank C isn't enough")
	_gs.support_ranks["sup_ricberta_sigrun"] = "B"
	check(_d.literacy_revealed("u_ricberta") and _d.score("u_ricberta") == 0.25, "Sigrun noticing at B reveals it: +0.25")
	check(not _d.literacy_revealed("u_sigrun") and _d.score("u_sigrun") == 0.0, "but it is Ricberta's, not Sigrun's")
	_gs.support_ranks["sup_ricberta_sigrun"] = "A"
	check(_d.score("u_ricberta") == 0.25, "a higher rank doesn't count it twice")
	_fresh()
	_join(["u_ricberta"])
	_gs.support_ranks["sup_ricberta_waldrada"] = "B"
	check(not _d.literacy_revealed("u_ricberta"), "Waldrada's chain reveals it only at A")
	_gs.support_ranks["sup_ricberta_waldrada"] = "A"
	check(_d.literacy_revealed("u_ricberta"), "...which it does at A")

	# ---- ranking and the crown's pick
	_fresh()
	_join(["u_ricberta", "u_sigrun", "u_gunnar", "u_brandt"])
	check(_d.ranking().map(func(r): return r["unit_id"]) == _d.candidates() and _d.crown_pick() == _d.candidates()[0], "with an empty ledger the order is canon's (first candidate wins the tie)")
	_d.on_objective("u_gunnar", "map_d03", false)
	_d.on_kill("u_sigrun", "map_d03", true)
	var rk: Array = _d.ranking()
	check(rk[0]["unit_id"] == "u_sigrun" and rk[0]["score"] == 1.5 and rk[1]["unit_id"] == "u_gunnar" and rk[1]["score"] == 1.0, "the highest score ranks first (%s)" % str(rk.map(func(r): return r["unit_id"] + ":" + str(r["score"]))))
	_d.record("u_ricberta", "on_objective")
	_d.record("u_ricberta", "on_objective")
	_gs.support_ranks["sup_ricberta_sigrun"] = "B"
	check(_d.score("u_ricberta") == 2.25 and _d.crown_pick() == "u_ricberta", "Ricberta's 2 + the literacy 0.25 beats Sigrun's 1.5")
	_fresh()
	_join(["u_ricberta", "u_sigrun"])
	_d.record("u_ricberta", "on_objective")
	_d.record("u_sigrun", "on_objective")
	check(_d.crown_pick() == "u_ricberta", "an exact tie falls to canon's order")
	_gs.support_ranks["sup_ricberta_sigrun"] = "B"
	_d.record("u_sigrun", "on_objective")
	_d.record("u_ricberta", "on_objective")
	check(_d.crown_pick() == "u_ricberta", "(and literacy is only a tiebreak: it breaks a tie in Ricberta's favour)")
	_fresh()
	_join(["u_ricberta", "u_sigrun"])
	_d.record("u_ricberta", "on_objective")
	_d.record("u_sigrun", "on_objective")
	_d.record("u_sigrun", "raw_kill")
	_gs.support_ranks["sup_ricberta_sigrun"] = "B"
	check(_d.crown_pick() == "u_sigrun", "literacy can't overturn a real lead (1.5 vs 1.25)")

	# ---- the writ scene's decision
	_fresh()
	check(_d.crown_pick() == "" and not _d.decide("u_ricberta")["ok"] and not _d.writ_due("ch_x11"), "with no candidates there is nothing to decide")
	_join(["u_ricberta", "u_sigrun", "u_gunnar"])
	_d.on_kill("u_sigrun", "map_d03", true)
	check(_d.writ_due("ch_x11") and not _d.writ_due("ch_d03") and not _d.decided(), "the writ is due before the Second Writ and no other chapter")
	var bad: Dictionary = _d.decide("u_jost")
	check(not bad["ok"] and bad["reason"] == "not a candidate" and not _d.decided(), "a non-candidate is refused")
	var ok: Dictionary = _d.decide("u_sigrun")
	check(ok["ok"] and not ok["contested"] and _d.deputy() == "u_sigrun" and not _d.contested() and _d.decided(), "accepting the crown's pick")
	check(not _d.decide("u_gunnar")["ok"] and _d.deputy() == "u_sigrun" and not _d.writ_due("ch_x11"), "once only; the writ is no longer due")
	_fresh()
	_join(["u_ricberta", "u_sigrun", "u_gunnar"])
	_d.on_kill("u_sigrun", "map_d03", true)
	var c: Dictionary = _d.decide("u_gunnar")
	check(c["ok"] and c["contested"] and _d.deputy() == "u_gunnar" and _d.contested() and _d.supply_withheld(), "naming someone else is a contest, granted")
	_fresh()
	_join(["u_ricberta"])
	_d.ensure_decided()
	check(_d.deputy() == "u_ricberta" and not _d.contested(), "the safety net names the crown's pick")

	# ---- Column B's supply attachment
	_fresh()
	_join(["u_ricberta", "u_sigrun"])
	check(_d.supply_attachment_gold("map_b15") == 0, "before the writ there is no attachment")
	_d.decide(_d.crown_pick())
	check(_d.supply_attachment_gold("map_b15") == 100 and _d.supply_attachment_gold("map_tp19") == 100, "accepted: both Column B chapters carry 100 gold")
	check(_d.supply_attachment_gold("map_ct19") == 0 and _d.supply_attachment_gold("map_r16") == 0 and _d.supply_attachment_gold("map_d03") == 0, "Column A and the unified chapters don't")
	_fresh()
	_join(["u_ricberta", "u_sigrun"])
	_d.decide("u_sigrun")
	check(_d.supply_attachment_gold("map_b15") == 0 and _d.supply_withheld(), "contested: withheld")

	# ---- on the map: surveyor, witnesses, events
	_fresh()
	_join(["u_ricberta", "u_sigrun", "u_gunnar"])
	var m: Node = await _map("map_d03", ["u_ricberta", "u_sigrun", "u_gunnar"], [Vector2i(5, 12), Vector2i(5, 12), Vector2i(15, 3)], [{"arch": _arch("Near"), "pos": Vector2i(6, 12)}, {"arch": _arch("Far"), "pos": Vector2i(16, 3)}])
	check(m.surveyor_pos.y == 12 and m.surveyor_pos.x >= 1 and m.surveyor_pos.x <= 7, "the surveyor stands at the camp, on the deploy row (%s)" % str(m.surveyor_pos))
	var sp: Vector2i = m.surveyor_pos
	m.unit_positions["u_ricberta"] = sp + Vector2i(4, 0)
	m.unit_positions["u_sigrun"] = sp + Vector2i(5, 0)
	check(m._witnessed("u_ricberta") and not m._witnessed("u_sigrun") and not m._witnessed("u_nobody"), "four tiles is witnessed, five is not")
	# a kill by a unit at the camp, and one far away
	m.unit_positions["u_ricberta"] = sp + Vector2i(0, -1)
	m.unit_positions["u_gunnar"] = Vector2i(19, 0)
	m.enemies[0].pos = m.unit_positions["u_ricberta"] + Vector2i(1, 0)
	m.selected_unit_index = m.units.find(m.units.filter(func(u): return u["punit_id"] == "u_ricberta")[0])
	m.units[m.selected_unit_index]["str"] = 30
	var r := RandomNumberGenerator.new()
	for sd in range(1, 3000):
		r.seed = sd
		if r.randi_range(1, 100) <= 15:
			break
	r.seed = r.seed
	m.rng_override = RandomNumberGenerator.new()
	m.rng_override.seed = r.seed
	m._attack_enemy()
	check(m.enemies[0].defeated and _d.count("u_ricberta", "raw_kill") == 1 and _d.count("u_ricberta", "witnessed") == 1, "a kill at the camp is written down and witnessed")
	m._earn_deed("u_sigrun", "ep_nohit", "Sigrun")
	check(_d.count("u_sigrun", "writ_deed") == 1 and _d.count("u_sigrun", "witnessed") == 0, "a deed earned far from the camp: 2, unwitnessed")
	m._earn_deed("u_ricberta", "ep_solohold", "Ricberta")
	check(_d.count("u_ricberta", "legible") == 1 and _d.count("u_ricberta", "writ_deed") == 1, "a solo hold on the map is legible")
	# objective: seize on a seize map
	m.queue_free()
	await process_frame
	m = await _map("map_d02", ["u_gunnar"], [Vector2i(8, 6)])
	m.selected_unit_index = 0
	m.unit_positions["u_gunnar"] = Vector2i(8, 6)
	m._select_unit(0)
	m._try_move_to(m.seize_pos)
	check(m.map_won and _d.count("u_gunnar", "on_objective") == 1, "seizing the objective is the seizer's")
	m.queue_free()
	await process_frame
	# objective: a defend map's boss falls
	_fresh()
	_join(["u_gunnar"])
	m = await _map("map_v22", ["u_gunnar"], [Vector2i(2, 10)], [{"arch": _arch("Warden"), "pos": Vector2i(5, 5), "kind": "boss"}])
	m._last_actor = "u_gunnar"
	m._boss_resolved(m.enemies[0], "falls")
	check(m.map_won and _d.count("u_gunnar", "on_objective") == 1, "felling a defend map's boss is the felling unit's objective")
	m.queue_free()
	await process_frame
	# paralogues and the prologue write nothing
	_fresh()
	_join(["u_gunnar"])
	m = await _map("map_p_macuil", ["u_gunnar"], [Vector2i(5, 5)], [{"arch": _arch("Foe"), "pos": Vector2i(6, 5)}])
	m._credit_kill("u_gunnar")
	m._credit_objective("u_gunnar")
	check(_d.score("u_gunnar") == 0.0 and _d.count("u_gunnar", "raw_kill") == 0 and _d.count("u_gunnar", "on_objective") == 0, "kills and objectives on a paralogue aren't entered")
	m.queue_free()
	await process_frame

	# ---- cargo escorts count toward the objective
	_fresh()
	_join(["u_ricberta"])
	m = await _map("map_d03", ["u_ricberta"], [Vector2i(10, 4)])
	m.unit_positions["cargo_d03_wagon1"] = Vector2i(10, 3)
	m._select_unit(m.units.size() - 3)
	m._try_move_to(Vector2i(10, 2))
	check(_d.count("u_ricberta", "on_objective") == 1 and _d.count("u_ricberta", "legible") == 1 and _d.count("u_ricberta", "writ_deed") == 1, "an escort of a delivered wagon: objective, plus the delivery deed (legible)")
	m.queue_free()
	await process_frame

	# ---- the supply attachment through a won Column B map
	_fresh()
	_join(["u_ricberta", "u_sigrun"])
	_d.decide(_d.crown_pick())
	_gs.gold = 0
	m = await _map("map_b15", ["u_ricberta"], [Vector2i(5, 5)])
	m.map_won = true
	check(_gs.gold == 200 + 100 and m._reward_text.contains("Column B's supply attachment: +100 gold."), "winning a Column B chapter pays 200 + the 100 attachment (gold %d: %s)" % [_gs.gold, m._reward_text])
	m.queue_free()
	await process_frame
	m = await _map("map_b15", ["u_ricberta"], [Vector2i(5, 5)])
	var g0: int = _gs.gold
	m.map_won = true
	check(_gs.gold == g0, "a replay pays nothing more")
	m.queue_free()
	await process_frame
	_fresh()
	_join(["u_ricberta", "u_sigrun"])
	_d.decide("u_sigrun")
	_gs.gold = 0
	m = await _map("map_b15", ["u_ricberta"], [Vector2i(5, 5)])
	m.map_won = true
	check(_gs.gold == 200 and m._reward_text.contains("withheld"), "contested: just the 200, and the win says the attachment is withheld (%s)" % m._reward_text)
	m.queue_free()
	await process_frame
	# winning the Second Writ settles an undecided deputy
	_fresh()
	_join(["u_ricberta"])
	m = await _map("map_x11", ["u_ricberta"], [Vector2i(5, 5)])
	m.map_won = true
	check(_d.decided() and _d.deputy() == "u_ricberta", "the Second Writ won with no scene: the crown's pick stands")
	m.queue_free()
	await process_frame

	# ---- the writ screen
	_fresh()
	_join(["u_ricberta", "u_sigrun", "u_gunnar"])
	_d.on_kill("u_sigrun", "map_d03", true)
	_d.on_deed("u_gunnar", "ep_nohit", "map_d03", false)
	var sc: Node = load("res://scenes/writ_screen.tscn").instantiate()
	root.add_child(sc)
	await process_frame
	check(sc._ranking.size() == 3 and sc._ranking[0]["unit_id"] == "u_gunnar" and sc.row_label(0).contains("Gunnar") and sc.row_label(0).contains("the crown's choice") and sc.row_label(1).contains("1.5"), "the screen ranks them, naming the crown's choice (%s | %s)" % [sc.row_label(0), sc.row_label(1)])
	check(sc.detail_text().contains("Gunnar") and sc.detail_text().contains("deeds on main-story chapters: 1 x 2 = 2") and sc.detail_text().contains("Enter accepts"), "the detail shows the breakdown and the invitation (%s)" % sc.detail_text().replace("\n", " / "))
	sc._index = 1
	sc._refresh()
	check(sc.detail_text().contains("is a contest") and not sc.activate() and sc._confirming and not _d.decided(), "choosing someone else: the first Enter only asks")
	check(sc.detail_text().contains("Press Enter again to name Sigrun"), "(%s)" % sc.detail_text().get_slice("\n", 3))
	_key(sc, KEY_DOWN)
	check(not sc._confirming and sc._index == 2, "moving away cancels the confirmation")
	sc._index = 1
	sc._refresh()
	sc.activate()
	check(sc.activate() and _d.deputy() == "u_sigrun" and _d.contested() and sc._message.contains("Column B's supply attachment is withheld"), "the second Enter names her, contested (%s)" % sc._message)
	check(sc.detail_text().contains("The deputy is Sigrun.") and sc.detail_text().contains("withheld"), "and the screen then just says so")
	check(not sc.activate(), "no second decision")
	sc.queue_free()
	await process_frame
	_fresh()
	_join(["u_ricberta", "u_sigrun"])
	sc = load("res://scenes/writ_screen.tscn").instantiate()
	root.add_child(sc)
	await process_frame
	check(sc.activate() and _d.deputy() == _d.candidates()[0] and not _d.contested() and sc._message.contains("is the crown's deputy.") and not sc._message.contains("withheld"), "Enter on the crown's pick accepts it, no contest (%s)" % sc._message)
	sc.queue_free()
	await process_frame
	_fresh()
	sc = load("res://scenes/writ_screen.tscn").instantiate()
	root.add_child(sc)
	await process_frame
	check(sc.detail_text().contains("No one in the company is a candidate") and not sc.activate(), "with no candidate the screen says so")
	sc.queue_free()
	await process_frame

	# ---- the overworld and the barracks
	_fresh()
	_gs.won_maps["map_f00"] = true
	_join(["u_ricberta", "u_sigrun"])
	var ow: Node2D = load("res://scenes/overworld.tscn").instantiate()
	ow.animate = false
	ow.launch_enabled = false
	root.add_child(ow)
	await process_frame
	check(not ow.info_label.text.contains("The crown's deputy"), "no deputy line before the writ")
	var x11_entry: Dictionary = ow.locations["loc_muster_field"]["chapters"][0]
	check(x11_entry.chapter["chapter_id"] == "ch_x11" and ow.scene_for(x11_entry) == _d.SCREEN_SCENE, "the Second Writ opens on the writ scene while no deputy is named")
	check(ow.scene_for(ow.locations["loc_tally_house"]["chapters"][0]) == "res://scenes/map_d01.tscn", "(other chapters load their maps)")
	_d.decide("u_sigrun")
	check(ow.scene_for(x11_entry) == "res://scenes/map_x11.tscn", "once the deputy is named it loads the map")
	ow.travel_to("loc_tally_house")
	check(ow.info_label.text.contains("The crown's deputy: Sigrun (contested: Column B's supply is withheld)."), "the panel names the deputy (%s)" % ow.info_label.text.replace("\n", " / "))
	ow.queue_free()
	await process_frame
	var bar: Node = load("res://scenes/barracks_screen.tscn").instantiate()
	root.add_child(bar)
	await process_frame
	bar._unit_index = bar.unit_ids.find("u_sigrun")
	bar._refresh()
	check(bar.detail_text().contains("The crown's deputy."), "the barracks marks the deputy")
	bar._unit_index = bar.unit_ids.find("u_ricberta")
	bar._refresh()
	check(not bar.detail_text().contains("The crown's deputy."), "and only the deputy")
	bar.queue_free()
	await process_frame

	# ---- saving
	_fresh()
	_join(["u_ricberta"])
	_d.record("u_ricberta", "on_objective", 3)
	_d.decide("u_ricberta")
	var snap: Dictionary = JSON.parse_string(JSON.stringify(_gs.to_dict()))
	_gs.reset()
	check(_gs.validate(snap) == "", "the ledger is a valid save")
	_gs.from_dict(snap)
	check(_d.count("u_ricberta", "on_objective") == 3 and typeof(_d.count("u_ricberta", "on_objective")) == TYPE_INT and _d.deputy() == "u_ricberta" and _d.decided(), "ledger and deputy come back")
	_fresh()
