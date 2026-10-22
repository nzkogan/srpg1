extends SceneTree
## Headless checks for the Morph gamble: who may take a patron's form, the chance the patron answers, what a form does, the form's
## clock, the permadeath when it lapses before the battle's end, the pull toward its side when it is held to the end, and the
## words before and after the reveal.
## Run from the repo root:
##   godot --headless --path game --script res://tests/test_morph.gd
## Exits 0 if every check passes, 1 otherwise.

var _failures: int = 0
var _checks: int = 0
var _p: Node
var _gs: Node
var _pa: Node
var _d: Node
var _e: Node

func check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: ", label)

func _initialize() -> void:
	_p = root.get_node("Progression")
	_gs = root.get_node("GameState")
	_pa = root.get_node("Patrons")
	_d = root.get_node("Deputy")
	_e = root.get_node("Epilogue")
	await process_frame
	await _run()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)

# a unit who may take the angel's form (Jost: born leaning angel, with twelve mercies)
func _angel(uid := "u_jost", level := 10, mercies := 12) -> void:
	_p.state(uid)
	_gs.progression[uid]["level"] = level
	_p.record_deed(uid, "ep_capture", mercies)

# a unit who may take the demon's (Brandt: born on a demon day?) -- push whoever it is to the demon with kills
func _demon(uid := "u_brandt", level := 10) -> void:
	_p.state(uid)
	_gs.progression[uid]["level"] = level
	_d.record(uid, "raw_kill", 60)

# a generator whose first percentile roll is low (the patron answers at any odds) or high (it never does, odds capped at 95)
func _rng(answers: bool) -> RandomNumberGenerator:
	for sd in 5000:
		var r := RandomNumberGenerator.new()
		r.seed = sd
		var roll := r.randi_range(1, 100)
		if (answers and roll <= 5) or (not answers and roll >= 96):
			var fresh := RandomNumberGenerator.new()
			fresh.seed = sd
			return fresh
	return null

func _map(scene: String, deploy: Array, positions: Array = [], answers := true) -> Node:
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
	for i in positions.size():
		m.unit_positions[deploy[i]] = positions[i]
	m.rng_override = _rng(answers)
	return m

func _sel(m: Node, uid: String) -> void:
	m.selected_unit_index = m.units.find(m.units.filter(func(u): return u["punit_id"] == uid)[0])

func _key(k: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.pressed = true
	return ev

func _run() -> void:
	# ---- canon
	check(_p.param("morph_unlock_level") == 10 and _p.param("morph_turns") == 3 and _p.param("morph_base_chance") == 60 and _p.param("morph_fail_damage") == 6, "parameters: level 10, three turns, 60% to answer, 6 HP if it does not")
	check(_p.param("morph_stat_angel") == 3 and _p.param("morph_stat_demon") == 5 and _p.param("morph_curse_angel_pct") == 0 and _p.param("morph_curse_demon_pct") == 200, "the angel's form is milder and clean; the demon's stronger and costlier")

	# ---- who may
	_gs.reset()
	_p.state("u_jost")
	_gs.progression["u_jost"]["level"] = 10
	check(not _pa.can_morph("u_jost")["ok"] and _pa.can_morph("u_jost")["reason"].contains("clearly enough"), "level 10 is not enough: they must lean clearly (|lean| 2): Jost leans 1")
	_p.record_deed("u_jost", "ep_capture", 12)
	var ok: Dictionary = _pa.can_morph("u_jost")
	check(ok["ok"] and ok["side"] == "angel", "twelve mercies make Jost's lean clear: the angel's form")
	_gs.progression["u_jost"]["level"] = 9
	check(not _pa.can_morph("u_jost")["ok"] and _pa.can_morph("u_jost")["reason"].contains("level 10"), "...and below level 10 it is closed")
	check(not _pa.can_morph("u_nobody")["ok"] and not _pa.can_morph("pu_sargath")["ok"], "a stranger or a memory's person has no patron")
	_gs.reset()
	_demon()
	var dm: Dictionary = _pa.can_morph("u_brandt")
	check(dm["ok"] and dm["side"] == "demon", "a unit pushed by kills toward the demon is offered the demon's form")
	check(_pa.morph_chance("u_brandt") == clampi(60 + 5 * absi(_pa.lean_of_unit("u_brandt")), 5, 95), "the chance is 60% plus 5% for every point of lean")
	check(_pa.form_stat("angel") == 3 and _pa.form_stat("demon") == 5 and _pa.form_boost({"str": 5, "mag": 1, "def": 2, "res": 2, "spd": 4, "dex": 6}, "demon") == {"str": 10, "mag": 6, "def": 7, "res": 7, "spd": 9, "dex": 6}, "a form adds to str, mag, def, res and spd and nothing else")

	# ---- the form's procs
	_gs.reset()
	_angel()
	var plain: Array = _pa.procs_for_unit("u_jost")
	var angelic: Array = _pa.procs_for_unit("u_jost", "angel")
	check(angelic.size() == 1 and angelic[0]["side"] == "blessing" and angelic[0]["chance"] == plain[0]["chance"] * 2, "the angel's form doubles the blessing and drops the curse altogether")
	var demonic: Array = _pa.procs_for_unit("u_jost", "demon")
	check(demonic.size() == 2 and demonic[0]["chance"] == int(round(plain[0]["chance"] * 1.5)) and demonic[1]["chance"] == plain[1]["chance"] * 2, "the demon's form is 1.5x the blessing and 2x the curse")

	# ---- on the map: the gamble
	_gs.reset()
	_angel()
	var m: Node = await _map("map_d02", ["u_jost"], [Vector2i(8, 8)])
	_sel(m, "u_jost")
	var hp0: int = m.unit_hp["u_jost"]
	m._morph()
	check(m.morphs.has("u_jost") and m.morphs["u_jost"]["side"] == "angel" and m.morphs["u_jost"]["left"] == 3 and m.info_label.text.contains("is answered: the patron's answer"), "the patron answers: the form is taken for three turns (%s)" % m.info_label.text.substr(0, 90))
	check(m.unit_hp["u_jost"] == hp0 and m.morph_tried.has("u_jost"), "(no price when it answers; one asking a battle)")
	var c: Dictionary = m._combatant_for_unit("u_jost")
	var base: int = int(m._row_for_test("u_jost")["str"]) if false else int(m.defender_row_for("u_jost")["str"])
	check(int(c["str"]) == base + 3 and c["procs"].size() == 1, "in the form: +3 to every stat and the curse is gone")
	check(m.units.size() == 1, "(one unit)")
	m._morph()
	check(m.info_label.text.contains("already holds the form"), "they cannot ask twice")
	# a second battle's gamble: tried
	m.morphs.clear()
	m._morph()
	check(m.info_label.text.contains("gambled once this battle"), "...and a spent gamble is spent")
	m.queue_free()
	await process_frame

	# the patron may refuse
	_gs.reset()
	_angel()
	m = await _map("map_d02", ["u_jost"], [Vector2i(8, 8)], false)
	_sel(m, "u_jost")
	var hp1: int = m.unit_hp["u_jost"]
	m._morph()
	check(not m.morphs.has("u_jost") and m.unit_hp["u_jost"] == hp1 - 6 and m.info_label.text.contains("does not answer") and m.morph_tried.has("u_jost"), "the patron does not answer: six HP is the price and no second asking (%s)" % m.info_label.text.substr(0, 80))
	m._morph()
	check(m.info_label.text.contains("gambled once"), "(and it will not be asked again)")
	m.queue_free()
	await process_frame

	# the refusal cannot kill: it leaves them at 1
	_gs.reset()
	_angel()
	m = await _map("map_d02", ["u_jost"], [Vector2i(8, 8)], false)
	_sel(m, "u_jost")
	m.unit_hp["u_jost"] = 3
	m._morph()
	check(m.unit_hp["u_jost"] == 1, "a refusal never kills: it leaves them standing on 1")
	m.queue_free()
	await process_frame

	# ---- the form's clock and the price
	_gs.reset()
	_angel()
	m = await _map("map_d02", ["u_jost"], [Vector2i(8, 8)])
	_sel(m, "u_jost")
	m._morph()
	m._next_turn()
	check(m.morphs["u_jost"]["left"] == 2 and m.info_label.text.contains("holds 2 more turns"), "each turn the form holds one fewer (%s)" % m.info_label.text.substr(m.info_label.text.length() - 60))
	m._next_turn()
	check(m.morphs["u_jost"]["left"] == 1 and m.unit_positions.has("u_jost"), "...")
	m._next_turn()
	check(not m.morphs.has("u_jost") and not m.unit_positions.has("u_jost"), "a form that runs out before the battle is over takes its bearer: permadeath")
	var rec: Dictionary = _gs.epilogue.get("pending", {}).get("u_jost", {})
	check(rec.get("killed_by_type") == "hazard" and rec.get("killed_by_id") == "patron" and _e.killer_tail(rec).contains("the price of a patron's form"), "the epilogue records it: %s" % _e.killer_tail(rec))
	check(m.map_lost, "(and with no one left, the map is lost)")
	m.queue_free()
	await process_frame

	# ---- holding it to the end
	_gs.reset()
	_angel("u_jost", 10, 4)
	m = await _map("map_d02", ["u_jost"], [Vector2i(8, 8)])
	_sel(m, "u_jost")
	m._morph()
	m._next_turn()
	var lean0: int = _pa.lean_of_unit("u_jost")
	m.map_won = true
	await process_frame
	check(m.unit_positions.has("u_jost") and _gs.patron_pull.get("u_jost", 0) == 1 and m._reward_text.contains("ended the battle in the patron's answer"), "still in the form when the battle is won: they live, and the patron lets go (%s)" % m._reward_text.substr(0, 120))
	check(_pa.lean_of_unit("u_jost") == mini(4, lean0 + 1) and m.morphs.is_empty(), "...and they are pulled one step further toward the angel")
	m.queue_free()
	await process_frame

	# the demon's pull goes the other way
	_gs.reset()
	_demon()
	m = await _map("map_d02", ["u_brandt"], [Vector2i(8, 8)])
	_sel(m, "u_brandt")
	m._morph()
	check(m.morphs.has("u_brandt") and m.morphs["u_brandt"]["side"] == "demon", "(the demon's form)")
	m.map_won = true
	await process_frame
	check(_gs.patron_pull.get("u_brandt", 0) == -1, "...pulls toward the demon")
	m.queue_free()
	await process_frame

	# a unit who falls in the form simply falls
	_gs.reset()
	_angel()
	m = await _map("map_d02", ["u_jost"], [Vector2i(8, 8)])
	_sel(m, "u_jost")
	m._morph()
	m._kill_unit("u_jost", {"type": "unknown"})
	check(m.morphs.is_empty() and _gs.epilogue.get("pending", {}).get("u_jost", {}).get("killed_by_type") == "unknown", "killed in the form they are killed by the foe, not the patron")
	m.queue_free()
	await process_frame

	# a defend map's last turn: a form that runs out then has held to the end
	_gs.reset()
	_angel()
	m = await _map("map_a02", ["u_jost"], [Vector2i(8, 8)])
	_sel(m, "u_jost")
	m._morph()
	m.turn = m.map_row["turn_limit"] - 1
	m.morphs["u_jost"]["left"] = 1
	m._next_turn()
	check(m.map_won and m.unit_positions.has("u_jost") and _gs.patron_pull.get("u_jost", 0) == 1, "on the last turn of a defend map the form's end is the battle's: it held")
	m.queue_free()
	await process_frame

	# the token wears the form's colour (when it is not the selected one)
	_gs.reset()
	_angel()
	_p.state("u_brandt")
	m = await _map("map_d02", ["u_jost", "u_brandt"], [Vector2i(8, 8), Vector2i(8, 9)])
	_sel(m, "u_jost")
	m._morph()
	_sel(m, "u_brandt")
	m._refresh_token_color(m.units.find(m.units.filter(func(u): return u["punit_id"] == "u_jost")[0]))
	check(m.unit_tokens["u_jost"].bg.color == m.FORM_ANGEL_COLOR, "the token takes the angel's colour")
	m.queue_free()
	await process_frame

	# ---- the controls, a memory, and saving
	_gs.reset()
	_angel()
	m = await _map("map_d02", ["u_jost"], [Vector2i(8, 8)])
	m._update_status_label()
	check(m.status_label.text.contains("[G] gamble"), "the gamble shows in the controls for a unit who may")
	_sel(m, "u_jost")
	m._unhandled_input(_key(KEY_G))
	check(m.morphs.has("u_jost"), "G asks the patron")
	var snap: Dictionary = m.capture_state()
	check(snap["morphs"]["u_jost"]["left"] == 3 and snap["morph_tried"].has("u_jost"), "a suspended battle keeps the form and its clock")
	m.morphs.clear(); m.morph_tried.clear()
	m._restore_progress(snap)
	check(m.morphs["u_jost"]["left"] == 3 and m.morph_tried.has("u_jost"), "...and gets them back")
	m.queue_free()
	await process_frame
	_gs.reset()
	_p.state("u_jost")
	_p.record_deed("u_jost", "ep_capture", 12)
	_gs.progression["u_jost"]["level"] = 10
	m = await _map("map_f01", [])
	m._morph()
	check(m.morphs.is_empty() and not m.morph_tried.has("pu_f1_hadda"), "a memory has no patrons to ask")
	m.queue_free()
	await process_frame

	# ---- words, and the saved pull
	_gs.reset()
	check(_pa.form_word("angel") == "the patron's answer" and _pa.form_word("demon") == "the patron's answer", "before the reveal it is only the patron's answer")
	_gs.won_maps["map_f02"] = true
	check(_pa.form_word("angel") == "the angel's form" and _pa.form_word("demon") == "the demon's form", "after it the angel's form and the demon's")
	_gs.reset()
	_pa.add_pull("u_jost", "angel")
	_pa.add_pull("u_jost", "angel")
	_pa.add_pull("u_jost", "demon")
	var dd: Dictionary = _gs.to_dict()
	check(dd["patron_pull"] == {"u_jost": 1} and _gs.validate(dd) == "", "the pull is saved with the run")
