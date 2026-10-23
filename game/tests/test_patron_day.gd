extends SceneTree
## Headless checks for the patron of the day: which pair's five days a chapter falls on, the bonus its own bearers' blessings get,
## the briefing line, and that memories and dayless chapters have none.
## Run from the repo root:
##   godot --headless --path game --script res://tests/test_patron_day.gd
## Exits 0 if every check passes, 1 otherwise.

var _failures: int = 0
var _checks: int = 0
var _p: Node
var _gs: Node
var _canon: Node
var _pa: Node

func check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: ", label)

func _initialize() -> void:
	_p = root.get_node("Progression")
	_gs = root.get_node("GameState")
	_canon = root.get_node("Canon")
	_pa = root.get_node("Patrons")
	await process_frame
	await _run()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)

func _join(ids: Array, level := 10) -> void:
	for u in ids:
		_p.state(u)
		_gs.progression[u]["level"] = level

func _map(scene: String, deploy: Array) -> Node:
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
	return m

func _pr(side: String, chance: int, patron: String) -> Dictionary:
	return {"side": side, "trigger": "on_attack", "kind": "power", "amount": 3, "chance": chance, "label": "X", "patron": patron}

func _run() -> void:
	check(_p.param("patron_day_bonus") == 5, "parameter: +5 points on the day's own blessings")

	# ---- which pair holds a chapter's day
	check(_pa.day_patron("ch_d01")["patron_id"] == "pat_01" and _pa.day_patron("ch_d02")["patron_id"] == "pat_07", "the court's calendar: chapter 1 is the Ram's first band (Bael), chapter 2 the Bull's (Amon)")
	check(_pa.day_patron("ch_c21")["patron_id"] == "pat_08", "chapter 14 comes round to the Bull again, and takes its second band (Barbatos)")
	check(_pa.day_patron("ch_k22")["patron_id"] == "pat_56" and _pa.day_patron("ch_h31")["patron_id"] == "pat_27", "...a later chapter under another sect's calendar")
	check(_pa.day_patron("ch_v21").is_empty() and _pa.day_patron("ch_nope").is_empty(), "a sect that keeps no calendar, and a chapter that is not one, have no day (a memory is cut off at the map)")
	var seen := {}
	var chap_ok := true
	for ch in _canon.get_table("chapters"):
		var g: String = root.get_node("Almanac").governing(ch["chapter_id"])
		var d: Dictionary = _pa.day_patron(ch["chapter_id"])
		if g == "":
			chap_ok = chap_ok and d.is_empty()
		else:
			chap_ok = chap_ok and not d.is_empty() and d["sign_id"] == g
			seen[d["patron_id"]] = true
	check(chap_ok and seen.size() >= 20, "every chapter with a sign has a pair of that sign (%d pairs hold a day)" % seen.size())

	# ---- the scaling
	var s: Array = _pa.day_scale([_pr("blessing", 20, "pat_07"), _pr("curse", 20, "pat_07"), _pr("blessing", 20, "pat_08")], "pat_07")
	check(s[0]["chance"] == 25 and s[1]["chance"] == 20 and s[2]["chance"] == 20, "only the day's own blessings rise: 20 to 25; its curse and another pair's blessing stay")
	check(_pa.day_scale([_pr("blessing", 79, "pat_07")], "pat_07")[0]["chance"] == 80 and _pa.day_scale([_pr("blessing", 80, "pat_07")], "pat_07")[0]["chance"] == 80, "...and no higher than twice the ceiling (80)")
	check(_pa.day_scale([_pr("blessing", 20, "pat_07")], "")[0]["chance"] == 20, "no day, no change")

	# ---- the briefing
	_gs.reset()
	_join(["u_brandt", "u_jost"])
	var b: String = _pa.day_briefing("ch_d02")
	check(b.begins_with("The day falls to Amon (days 1 to 5 of the Bull)") and b.contains("Brandt") and not b.contains("Jost") and b.contains("favours run +5"), "the briefing names the pair and who is born under it: %s" % b)
	check(_pa.day_briefing("ch_v21") == "", "...and no briefing on a dayless chapter")
	check(_pa.day_patron("ch_p_huma")["first_day"] == 6, "a later paralogue (96) is on its second band of the sign, not the first")
	_gs.reset()
	check(not _pa.day_briefing("ch_d02").contains("Brandt"), "someone who has not joined is not named")
	_join(["u_brandt", "u_jost"])
	_gs.won_maps["map_f02"] = true
	check(_pa.day_briefing("ch_d02").contains("Amon and ") and _pa.day_briefing("ch_d02").contains("blessings run"), "after the reveal it is a demon and an angel, and a blessing")
	_gs.won_maps.erase("map_f02")

	# ---- on the map
	var m: Node = await _map("map_d02", ["u_brandt", "u_jost"])
	check(m.info_label.text.contains("The day falls to Amon"), "the map's briefing carries it: %s" % m.info_label.text.substr(0, 160))
	var base: Array = _pa.procs_for_unit("u_brandt")
	var got: Array = m._combatant_for_unit("u_brandt")["procs"]
	var blessing_base := 0
	var blessing_got := 0
	var curse_same := true
	for i in base.size():
		if base[i]["side"] == "blessing":
			blessing_base = int(base[i]["chance"]); blessing_got = int(got[i]["chance"])
		else:
			curse_same = curse_same and base[i]["chance"] == got[i]["chance"]
	check(blessing_got == blessing_base + 5 and curse_same, "Brandt, born under the day's pair, has blessing %d (was %d) and the same curse" % [blessing_got, blessing_base])
	var other: Array = m._combatant_for_unit("u_jost")["procs"]
	check(other == _pa.procs_for_unit("u_jost"), "Jost, born under another, is as he was")
	m.queue_free()
	await process_frame

	# ---- an enemy born under the day's pair is louder too
	m = load("res://scenes/map_d02.tscn").instantiate()
	m.enemy_phase_enabled = false
	root.add_child(m)
	await process_frame
	var hit := false
	for ch in _canon.get_table("chapters"):
		var dp: Dictionary = _pa.day_patron(ch["chapter_id"])
		if dp.is_empty() or hit:
			continue
		m.map_row["chapter_id"] = ch["chapter_id"]
		for e in m.enemies:
			var raw: Array = _pa.procs_for_enemy(e.archetype, m._enemy_key(e))
			var bl: Array = raw.filter(func(pr): return pr["side"] == "blessing" and pr["patron"] == dp["patron_id"])
			if bl.is_empty():
				continue
			var got_e: Array = m._enemy_combatant(e)["procs"]
			var gb: Array = got_e.filter(func(pr): return pr["side"] == "blessing")
			hit = true
			check(not gb.is_empty() and gb[0]["chance"] == mini(int(bl[0]["chance"]) + 5, 80), "an enemy born under the day's pair: blessing %d (was %d)" % [gb[0]["chance"] if not gb.is_empty() else -1, bl[0]["chance"]])
			break
	check(hit, "(some enemy on the field shares a day's pair, so the check ran)")
	m.queue_free()
	await process_frame

	# ---- a memory has none
	m = await _map("map_f01", [])
	check(m._day_patron_id() == "", "a memory keeps no day")
	m.queue_free()
	await process_frame
