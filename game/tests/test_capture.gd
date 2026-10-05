extends SceneTree
## Headless checks for the Capture action and its deed: who may capture, what
## makes an enemy capturable, what a capture does (and doesn't), the five-capture
## deed, the ransom, and how it shows in the forecast and the barracks.
## Run from the repo root:
##   godot --headless --path game --script res://tests/test_capture.gd
## Exits 0 if every check passes, 1 otherwise.

const ForecastView := preload("res://scripts/forecast_view.gd")
var _failures: int = 0
var _checks: int = 0
var _p: Node
var _gs: Node

func check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: ", label)

func _initialize() -> void:
	_p = root.get_node("Progression")
	_gs = root.get_node("GameState")
	await process_frame
	await _run()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)

func _reset() -> void:
	_gs.progression.clear(); _gs.gold = 0; _gs.unlocked_classes.clear(); _gs.income_claimed.clear()
	_gs.inventories.clear(); _gs.convoy.clear(); _gs.equipment_ready = false; _gs.drops_claimed.clear()
	_gs.deeds.clear(); _gs.won_maps.clear()
	_gs.support_ranks.clear(); _gs.support_points.clear(); _gs.support_settled_maps.clear(); _gs.support_recent.clear()

func _arch(name: String, over := {}) -> Dictionary:
	var d := {"enemy_id": "ea_t_" + name, "name": name, "weapon_art": "sword", "weapon_tier": "worn", "movement_type": "infantry",
		"level": 5, "hp": 20, "str": 0, "mag": 0, "dex": 0, "spd": 0, "lck": 0, "def": 0, "res": 0}
	d.merge(over, true)
	return d

func _setup(deploy: Array, positions: Array, enemy_specs: Array) -> Node:
	var map: Node = load("res://scenes/map_d05.tscn").instantiate()
	var ids: Array[String] = []
	ids.assign(deploy)
	map.deploy_unit_ids = ids
	map.enemy_phase_enabled = false
	root.add_child(map)
	await process_frame
	for e in map.enemies:
		map._remove_enemy_token(e)
	map.enemies.clear(); map.dens.clear()
	for i in deploy.size():
		map.unit_positions[deploy[i]] = positions[i]
	var next_id := 0
	for spec in enemy_specs:
		next_id = map._spawn_enemy_instance(spec["arch"], spec["pos"], spec.get("kind", "mook"), next_id)
	var r := RandomNumberGenerator.new()
	r.seed = 3
	map.rng_override = r
	return map

func _capture(m: Node, idx: int) -> void:
	m.selected_unit_index = idx
	m.attacked_this_turn.clear()
	m._capture_enemy()

func _key(m: Node, keycode: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.pressed = true
	m._unhandled_input(ev)

func _run() -> void:
	# ---- canon: who carries the action, what the deed needs
	_reset()
	check(_p.can_capture("u_gunnar"), "Gunnar (bounty hunter) has the Capture action")
	check(not _p.can_capture("u_jost") and not _p.can_capture("u_kheldar"), "Jost and Kheldar don't (Kheldar's trick is a bribe, not a capture)")
	_p.ensure("u_rinsa")
	_gs.progression["u_rinsa"]["class_id"] = "cls_pardoner"
	check(_p.can_capture("u_rinsa"), "the Pardoner hybrid ('seal not kill') has it too, whoever wears the class")
	_gs.progression["u_rinsa"]["class_id"] = "cls_tr_bow"
	check(not _p.can_capture("u_rinsa"), "and a unit leaves it behind when it changes class")
	check(not _p.can_capture("u_nobody"), "an unknown unit never has it")
	check(_p.is_tracked("ep_capture") and _p.count_needed("ep_capture") == 5, "ep_capture is tracked and needs 5 captures")
	check(_p.count_needed("ep_bosskill") == 1 and _p.count_needed("ep_nohit") == 1 and _p.count_needed("ep_nope") == 1, "every other deed needs 1 (and an unknown id defaults to 1)")

	# ---- what can be captured
	check(_p.capture_check(10, 20, false)["ok"], "half HP exactly is capturable (50% of 20 = 10)")
	check(not _p.capture_check(11, 20, false)["ok"] and _p.capture_check(11, 20, false)["reason"].contains("needs 10"), "one HP over the line is not, and says why")
	check(_p.capture_check(7, 15, false)["ok"] and not _p.capture_check(8, 15, false)["ok"], "odd max HP rounds the limit down (15 -> 7)")
	check(not _p.capture_check(1, 20, true)["ok"] and _p.capture_check(1, 20, true)["reason"].contains("boss"), "a boss can never be captured, however weak")
	check(not _p.capture_check(1, 1, false)["ok"], "a 1-HP enemy at full health is not weakened (the limit rounds down to 0)")

	# ---- the deed counts up to five, once
	_reset()
	var earned: Array[bool] = []
	for i in 6:
		earned.append(_p.record_deed("u_gunnar", "ep_capture"))
	check(earned == [false, false, false, false, true, false], "record_deed is true only on the 5th capture (%s)" % str(earned))
	_reset()
	for i in 4:
		_p.record_deed("u_gunnar", "ep_capture")
	check(not _p.has_deed("u_gunnar", "ep_capture") and _p.deed_count("u_gunnar", "ep_capture") == 4, "four captures is progress, not the deed")
	check(not _p.gating_deeds_earned("u_gunnar").has("ep_capture"), "and it doesn't gate paragon yet")
	check(_p.record_deed("u_gunnar", "ep_capture", 3), "a batch that crosses the line earns it")
	check(not _p.record_deed("u_gunnar", "ep_capture", 3), "...once")
	check(_p.has_deed("u_gunnar", "ep_capture") and _p.gating_deeds_earned("u_gunnar").has("ep_capture"), "and it then gates paragon")
	_reset()
	check(_p.record_deed("u_jost", "ep_bosskill") and not _p.record_deed("u_jost", "ep_bosskill"), "a one-count deed still earns on the first record only")

	# ---- ransom
	check(_p.map_income(2, false, 0) == 230 and _p.map_income(2, false, 3) == 305, "income: 200 + 15 per defeat + 25 per capture")
	check(_p.map_income(2, true, 3) == 458, "...and Kheldar's x1.5 applies to the ransom too")
	_reset()
	check(_p.award_income("map_x", 1, false, 2) == 265 and _gs.gold == 265, "award_income pays defeats and captures")

	# ---- on the map: a successful capture
	_reset()
	var drop_arch := _arch("Looter", {"hp": 20})
	var m: Node = await _setup(["u_gunnar"], [Vector2i(5, 5)], [{"arch": drop_arch, "pos": Vector2i(7, 5)}])
	m.enemies[0]["drop"] = "wpn_bow_basic"
	m.enemies[0]["spawn_id"] = "spn_test_capture"
	m.enemies[0].hp = 10
	var ghp: int = int(m.unit_hp["u_gunnar"])
	var convoy_before = _gs.convoy.duplicate(true)
	check(m.enemies[0].token.has("container"), "(the enemy has a token on the map before the capture)")
	var exp_before: int = _p.exp_of("u_gunnar") + 100 * _p.level("u_gunnar")
	_capture(m, 0)
	var e: Dictionary = m.enemies[0]
	check(e.defeated and e.get("captured", false), "a weakened enemy in bow range is captured")
	check(e.token.is_empty(), "its token leaves the map")
	check(m.info_label.text.contains("Gunnar takes the Looter alive"), "the map says so (%s)" % m.info_label.text.replace("\n", " / "))
	check(int(m.unit_hp["u_gunnar"]) == ghp, "no exchange: the captor takes no counter-damage")
	check(m.attacked_this_turn.has("u_gunnar") and m.fought_units.has("u_gunnar"), "it spends the unit's action and counts as having fought")
	check(_p.exp_of("u_gunnar") + 100 * _p.level("u_gunnar") > exp_before, "it earns EXP")
	check(_gs.convoy == convoy_before and not _gs.drops_claimed.has("spn_test_capture"), "but the captive drops nothing, and the spawn's drop stays unclaimed")
	check(_p.deed_count("u_gunnar", "ep_capture") == 1 and m.info_label.text.contains("Gunnar has taken 1 of 5 captives."), "the first capture reports progress toward the deed")
	check(not _p.has_deed("u_gunnar", "ep_capture"), "(not the deed yet)")
	_capture(m, 0)
	check(m.info_label.text.contains("No enemy in range"), "with nobody left, there is nothing to capture")
	m.queue_free()
	await process_frame

	# ---- refusals leave the action unspent
	_reset()
	m = await _setup(["u_gunnar", "u_jost"], [Vector2i(5, 5), Vector2i(5, 8)],
		[{"arch": _arch("Brute", {"hp": 20}), "pos": Vector2i(7, 5)}, {"arch": _arch("Captain", {"hp": 20}), "pos": Vector2i(5, 4), "kind": "boss"}])
	m.enemies[1].pos = Vector2i(5, 3)    # the boss is 2 tiles from Gunnar too
	_capture(m, 0)
	check(not m.enemies[0].defeated and m.info_label.text.contains("too strong to take") and not m.attacked_this_turn.has("u_gunnar"),
		"a healthy enemy is refused with the reason, and the action isn't spent (%s)" % m.info_label.text)
	m.enemies[0].pos = Vector2i(5, 9)     # out of Gunnar's range; the weak boss is the nearest
	m.enemies[1].hp = 1
	_capture(m, 0)
	check(not m.enemies[1].defeated and m.info_label.text.contains("boss will not surrender") and not m.attacked_this_turn.has("u_gunnar"),
		"a boss is refused even at 1 HP (%s)" % m.info_label.text)
	m.enemies[1].pos = Vector2i(6, 8)
	m.enemies[1].kind = "mook"
	m.enemies[0].pos = Vector2i(5, 3)
	m.enemies[0].hp = 3
	_capture(m, 1)                         # Jost has no Capture action
	check(not m.enemies[1].defeated and m.info_label.text.contains("Jost has no Capture action"), "a unit without the action can't capture")
	m.selected_unit_index = 0
	m.attacked_this_turn["u_gunnar"] = true
	m._capture_enemy()
	check(not m.enemies[0].defeated and m.info_label.text.contains("already acted"), "a unit that already acted can't capture")
	m.attacked_this_turn.clear()
	m.enemies[0].pos = Vector2i(5, 6)    # adjacent: a bow (range 2) can't reach
	m._capture_enemy()
	check(not m.enemies[0].defeated and m.info_label.text.contains("No enemy in range"), "capture uses the equipped weapon's reach (a bow can't take a neighbour)")
	m.enemies[0].pos = Vector2i(5, 7)
	m._capture_enemy()
	check(m.enemies[0].defeated and m.enemies[0].get("captured", false), "...but can at range 2")
	m.queue_free()
	await process_frame

	# ---- the fifth capture earns the deed and announces it
	_reset()
	m = await _setup(["u_gunnar"], [Vector2i(5, 5)], [])
	var spec := []
	for i in 5:
		spec.append({"arch": _arch("Looter%d" % i, {"hp": 20}), "pos": Vector2i(7, 5)})
	var next_id := 0
	for s in spec:
		next_id = m._spawn_enemy_instance(s["arch"], s["pos"], "mook", next_id)
	for e2 in m.enemies:
		e2.hp = 5
	for i in 4:
		_capture(m, 0)
	check(_p.deed_count("u_gunnar", "ep_capture") == 4 and not m.info_label.text.contains("earns a deed") and m.info_label.text.contains("4 of 5"), "four captures: progress only (%s)" % m.info_label.text.replace("\n", " / "))
	_capture(m, 0)
	check(_p.has_deed("u_gunnar", "ep_capture") and m.info_label.text.contains("Gunnar earns a deed: capture ('Taker')."), "the fifth earns the deed and the map announces it (%s)" % m.info_label.text.replace("\n", " / "))
	check(not m.info_label.text.contains("of 5 captives"), "(no progress line once it is earned)")
	check(_p.gating_deeds_earned("u_gunnar") == ["ep_capture"], "Gunnar now has a deed that gates paragon")
	# the deed survives a save round-trip, partial progress too
	var snap: Dictionary = _gs.to_dict()
	_gs.deeds.clear()
	_gs.from_dict(snap)
	check(_p.deed_count("u_gunnar", "ep_capture") == 5 and _p.has_deed("u_gunnar", "ep_capture"), "capture counts are saved with the deeds")
	m.queue_free()
	await process_frame

	# ---- captures aren't kills for the map's income, and count as fighting for no-hit
	_reset()
	m = await _setup(["u_gunnar", "u_kheldar"], [Vector2i(5, 5), Vector2i(1, 1)],
		[{"arch": _arch("A", {"hp": 20}), "pos": Vector2i(7, 5)}, {"arch": _arch("B", {"hp": 20}), "pos": Vector2i(1, 8)}, {"arch": _arch("C", {"hp": 20}), "pos": Vector2i(8, 8)}])
	m.enemies[0].hp = 4
	_capture(m, 0)
	m.enemies[1].defeated = true         # one killed
	var text: String = m._settle_rewards()
	check(_gs.gold == int(round((200 + 15 * 1 + 25 * 1) * 1.5)), "win income: 1 defeat + 1 capture, with Kheldar's cut (gold %d)" % _gs.gold)
	check(text.contains("Untouched") or text.contains("no hit map"), "a captor that was never struck earns the no-hit deed (capturing counts as fighting) (%s)" % text)
	m.queue_free()
	await process_frame

	# ---- forecast and keys
	_reset()
	m = await _setup(["u_gunnar", "u_jost"], [Vector2i(5, 5), Vector2i(5, 8)],
		[{"arch": _arch("Brute", {"hp": 20}), "pos": Vector2i(7, 5)}])
	var inst: Dictionary = m.enemies[0]
	check(str(m._capture_text("u_gunnar", inst)).contains("too strong to take"), "the forecast tells Gunnar a healthy enemy is too strong")
	inst.hp = 10
	var ct: String = m._capture_text("u_gunnar", inst)
	check(ct.begins_with("Capture ready") and ct.contains("+25"), "...and when it can be taken, says what it pays (%s)" % ct)
	check(m._capture_text("u_jost", inst) == "", "a unit without the action sees no Capture line at all")
	var info: Dictionary = m._forecast_info(m.units[0], inst)
	var html: String = ForecastView.bbcode(info)
	check(html.contains("Capture ready") and html.contains("(C)"), "the forecast panel shows the ready line with its key")
	inst.hp = 20
	html = ForecastView.bbcode(m._forecast_info(m.units[0], inst))
	check(html.contains("too strong to take") and not html.contains("(C)"), "and the refusal without the key hint")
	var plain := info.duplicate()
	plain["capture_text"] = ""
	html = ForecastView.bbcode(plain)
	check(not html.contains("Capture"), "no line when the text is empty")
	m._update_status_label()
	check(m.status_label.text.contains("[C] capture"), "the controls line lists [C] when a Capture unit is in the squad")
	inst.hp = 10
	m.selected_unit_index = 0
	m.attacked_this_turn.clear()
	_key(m, KEY_C)
	check(inst.defeated and inst.get("captured", false), "the C key captures")
	m.queue_free()
	await process_frame

	_reset()
	m = await _setup(["u_jost"], [Vector2i(5, 5)], [{"arch": _arch("Brute", {"hp": 20}), "pos": Vector2i(6, 5)}])
	m._update_status_label()
	check(not m.status_label.text.contains("[C] capture"), "a squad without a Capture unit doesn't see the key")
	m.queue_free()
	await process_frame

	# ---- the barracks
	_reset()
	var bar: Node = load("res://scripts/barracks_screen.gd").new()
	var lines: Array[String] = []
	bar._append_deeds(lines, "u_gunnar")
	var shown := "\n".join(lines)
	check(shown.contains("capture") and not shown.contains("capture (captures rather than kills 5+ times) -- not recordable yet"), "capture is no longer 'not recordable yet' (%s)" % shown.replace("\n", " / "))
	check(shown.contains("-- 0 of 5"), "an untouched capture deed shows 0 of 5")
	_p.record_deed("u_gunnar", "ep_capture", 3)
	lines.clear(); bar._append_deeds(lines, "u_gunnar")
	shown = "\n".join(lines)
	check(shown.contains("-- 3 of 5") and not shown.contains("[x] capture"), "partial progress reads 3 of 5, unticked")
	_p.record_deed("u_gunnar", "ep_capture", 2)
	lines.clear(); bar._append_deeds(lines, "u_gunnar")
	shown = "\n".join(lines)
	check(shown.contains("[x] capture") and shown.contains("x5"), "five ticks it, with the count")
	check(not shown.contains("not recordable yet"), "all four deeds that gate paragon are recordable now")
	bar.free()
