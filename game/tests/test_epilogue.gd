extends SceneTree
## Headless checks for the epilogue death text: permadeath (pending, final on a win, dropped on a
## retry), the death record, who gets credit for the blow, the weapon's fate, and every clause of
## the sentence canon's epilogue_generation asks for.
## Run from the repo root:
##   godot --headless --path game --script res://tests/test_epilogue.gd
## Exits 0 if every check passes, 1 otherwise.

var _failures: int = 0
var _checks: int = 0
var _p: Node
var _gs: Node
var _eq: Node
var _e: Node
var _d: Node
var _s: Node

func check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: ", label)

func _initialize() -> void:
	_p = root.get_node("Progression")
	_gs = root.get_node("GameState")
	_eq = root.get_node("Equipment")
	_e = root.get_node("Epilogue")
	_d = root.get_node("Defections")
	_s = root.get_node("Supports")
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

func _map(scene: String, deploy: Array, positions: Array, specs: Array = [], phase := false) -> Node:
	var m: Node = load("res://scenes/%s.tscn" % scene).instantiate()
	var ids: Array[String] = []
	ids.assign(deploy)
	m.deploy_unit_ids = ids
	m.enemy_phase_enabled = phase
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
		"level": 5, "hp": 40, "str": 30, "mag": 0, "dex": 30, "spd": 0, "lck": 0, "def": 0, "res": 0, "affiliation": "state", "death_noun": "lance"}
	d.merge(over, true)
	return d

func _rec(over := {}) -> Dictionary:
	var r := {"unit_id": "u_jost", "map_id": "map_d01", "chapter_id": "ch_d01", "killed_by_type": "polity", "killed_by_id": "pol_assembly",
		"noun": "lance", "who": "conscript levy", "own_action": false, "enemy_idx": -1, "epithets": [], "slain": [],
		"weapon_id": "wpn_axe_basic", "weapon_uses": 20, "weapon_fate": "lost_to_enemy", "pack": [], "partner": "", "tier": "", "romantic": false, "seq": 1}
	r.merge(over, true)
	return r

func _run() -> void:
	# ---- canon
	var phrases: Array = root.get_node("Canon").get_table("epilogue_text")
	check(phrases.size() >= 30, "the epilogue_text tab has its phrases (%d)" % phrases.size())
	check(_e.fill("epi_tail_unknown") == ", in the chaos, to no blade anyone could name", "the unknown tail is canon's own wording")
	check(_e.fill("epi_killer_polity", {"ADJ": "Assembly", "NOUN": "arrow"}) == "an Assembly arrow" and _e.fill("epi_killer_polity", {"ADJ": "Diadem", "NOUN": "lance"}) == "a Diadem lance", "{A} is a or an by the next word")
	check(_e.fill("epi_nonsense") == "", "an unknown phrase is empty, not an error")
	check(_e.place_name("ch_d01") == "the tally house" and _e.place_name("ch_f00") == "Ur-Nashet, the last night" and _e.place_name("ch_d10") == "Vashti Gate", "the place is the chapter's title, leading 'The' lowered")
	var nm: Dictionary = root.get_node("Canon").find_by("named", "named_id", "nmd_karkadann")
	check(nm["death_phrase"] == "the Karkadann's charge", "a Named has its signature verb")
	var ea: Dictionary = root.get_node("Canon").find_by("enemy_archetypes", "enemy_id", "ea_looter")
	check(ea["affiliation"] == "band" and ea["death_noun"] == "axe", "a looter is a band that swings an axe")
	var m_d02 = root.get_node("Canon").find_by("maps", "map_id", "map_d02")
	var m_k21 = root.get_node("Canon").find_by("maps", "map_id", "map_k21")
	check(m_d02["enemy_polity_id"] == "pol_assembly" and m_k21["enemy_polity_id"] == null, "a Diadem-route map fields Assembly soldiers; a both-route map names none")

	# ---- classify: who gets the credit
	var lev: Dictionary = {"archetype": _arch("Conscript levy"), "kind": "mook"}
	var k: Dictionary = _e.classify(lev, "map_d02")
	check(k["type"] == "polity" and k["id"] == "pol_assembly" and k["noun"] == "lance", "a state's soldier on a Diadem map is the Assembly's")
	k = _e.classify(lev, "map_k21")
	check(k["type"] == "band" and k["who"] == "conscript levy", "...and on a map that names no polity, a band")
	k = _e.classify({"archetype": _arch("Looter", {"affiliation": "band", "death_noun": "axe"}), "kind": "mook"}, "map_d02")
	check(k["type"] == "band" and k["noun"] == "axe", "a looter is a band even on a polity's map")
	k = _e.classify({"archetype": _arch("Warlord", {"enemy_id": "ea_warlord", "death_noun": "axe"}), "kind": "boss"}, "map_d02")
	check(k["type"] == "boss" and k["id"] == "ea_warlord" and k["who"] == "the warlord", "a chapter boss is named: the warlord")
	k = _e.classify({"archetype": _arch("Boyan, the preacher", {"affiliation": "individual", "death_noun": null}), "kind": "boss"}, "map_a02")
	check(k["type"] == "boss" and k["who"] == "Boyan", "an individual boss is named bare")
	k = _e.classify({"archetype": _arch("The Karkadann", {"affiliation": "named", "named_id": "nmd_karkadann"}), "kind": "boss"}, "map_p_karkadann")
	check(k["type"] == "named_creature" and k["id"] == "nmd_karkadann", "a Named beats being a boss")
	k = _e.classify({"archetype": _arch("Waldrada"), "kind": "mook", "defector": "def_waldrada"}, "map_v22")
	check(k["type"] == "defector" and k["id"] == "def_waldrada" and k["who"] == "Waldrada", "a defector is named directly")
	check(_e.quarry_name({"named_id": "nmd_karkadann", "name": "The Karkadann"}) == "the Karkadann" and _e.quarry_name(_arch("Warlord")) == "the warlord", "quarry names")

	# ---- the sentence, clause by clause
	_fresh()
	var rec := _rec({"epithets": ["ep_bosskill"], "slain": ["the Karkadann"], "tier": "B", "partner": "u_rinsa"})
	var txt: String = _e.sentence(rec)
	check(txt.begins_with("Jost, Slayer of the Karkadann, fell at the tally house to an Assembly lance."), "canon's first example opens as written: %s" % txt)
	check(txt.contains("The Iron Axe passed to no one."), "...a weapon lost to the enemy passes to no one")
	check(txt.contains("Rinsa kept Jost's watch that night."), "...a platonic B partner keeps the watch")
	check(_e.sentence(_rec({"epithets": []})).begins_with("Jost fell at the tally house to"), "no epithet: the name stands alone")
	check(_e.title_clause(_rec({"epithets": ["ep_nohit"]})) == "the Untouched", "a bare token: the Untouched")
	check(_e.title_clause(_rec({"epithets": ["ep_solohold"]})) == "of the Ford", "'of the Ford' stands as it is")
	check(_e.title_clause(_rec({"epithets": ["ep_bosskill"], "slain": []})) == "the Slayer", "a Slayer with no quarry on record")
	check(_e.title_clause(_rec({"epithets": ["ep_miasma", "ep_capture"]})) == "the Taker", "a paragon-gating deed beats one that does not")
	check(_e.title_clause(_rec({"epithets": ["ep_nohit", "ep_bosskill"], "slain": ["Boyan"]})) == "Slayer of Boyan", "...and canon order breaks a tie between gating deeds")
	check(_e.title_clause(_rec({"epithets": ["ep_miasma"]})) == "the Ash-walker", "a non-gating deed still titles someone")
	# killers
	var plain := _rec()
	check(_e.killer_tail(plain) == " to an Assembly lance", "polity: an Assembly lance")
	check(_e.killer_tail(_rec({"killed_by_id": "pol_diadem"})) == " to a Diadem lance", "polity: a Diadem lance")
	check(_e.killer_tail(_rec({"killed_by_type": "band", "killed_by_id": "ea_looter", "who": "looter", "noun": "axe"})) == " to a looter's axe", "band: a looter's axe")
	check(_e.killer_tail(_rec({"killed_by_type": "named_creature", "killed_by_id": "nmd_karkadann"})) == " to the Karkadann's charge", "named: the signature verb")
	check(_e.killer_tail(_rec({"killed_by_type": "defector", "killed_by_id": "def_waldrada", "who": "Waldrada"})) == " to Waldrada", "defector: named")
	check(_e.killer_tail(_rec({"killed_by_type": "boss", "who": "Boyan"})) == " to Boyan", "boss: named")
	check(_e.killer_tail(_rec({"killed_by_type": "unknown"})) == ", in the chaos, to no blade anyone could name", "unknown: bleak")
	check(_e.killer_tail(_rec({"killed_by_type": "hazard", "killed_by_id": "cold"})) == " to the cold", "hazard: the cold")
	check(_e.killer_tail(_rec({"killed_by_type": "hazard", "killed_by_id": "nothing_known"})) == " to the elements", "an unknown hazard is the elements")
	check(_e.sentence(_rec({"killed_by_type": "unknown", "epithets": []})).begins_with("Jost fell at the tally house, in the chaos, to no blade anyone could name."), "canon's second example")
	# weapons
	check(_e.weapon_clause(_rec({"weapon_fate": "retrieved"})).ends_with("came home in the convoy."), "retrieved")
	check(_e.weapon_clause(_rec({"weapon_fate": "thrown_and_lost"})).contains("was thrown, and not found again"), "thrown and lost")
	check(_e.weapon_clause(_rec({"weapon_fate": "with_the_body"})) == "Jost was buried still holding the Iron Axe.", "with the body: still holding it")
	check(_e.weapon_clause(_rec({"weapon_marks": [{"ep": "ep_capture", "object": ""}]})) == "The Taker's Iron Axe passed to no one.", "a marked weapon is named by its marks")
	check(_e.weapon_clause(_rec({"weapon_id": "", "weapon_fate": ""})) == "", "died unarmed: no weapon clause")
	check(not _e.sentence(_rec({"weapon_id": ""})).contains("passed to no one"), "...and none in the sentence")
	# supports: each tier and tone
	var tones := {}
	for kind in ["platonic", "romantic"]:
		for tier in ["C", "B", "A", "S"]:
			if kind == "platonic" and tier == "S":
				continue
			var line: String = _e.support_clause(_rec({"partner": "u_rinsa", "tier": tier, "romantic": kind == "romantic"}))
			check(line.contains("Rinsa") and line.ends_with("."), "%s %s names the partner: %s" % [kind, tier, line])
			tones[line] = true
	check(tones.size() == 7, "seven different lines across tier and tone")
	check(_e.support_clause(_rec({"partner": ""})) == "No one at the fire was close enough to grieve properly.", "unpaired: the quiet indictment")
	_gs.progression["u_rinsa"] = {}
	_gs.epilogue = {"deaths": {"u_rinsa": {"unit_id": "u_rinsa", "seq": 1}}}
	check(_e.support_clause(_rec({"partner": "u_rinsa", "tier": "A", "seq": 2})) == "Rinsa had fallen already, and there was no one left to grieve.", "a partner who fell earlier")
	check(_e.support_clause(_rec({"partner": "u_rinsa", "tier": "A", "seq": 0})) == "Rinsa did not outlive the war either.", "a partner who falls later")
	_fresh()
	_join(["u_waldrada"])
	_d.on_map_won("map_v21", true)
	check(_e.support_clause(_rec({"partner": "u_waldrada", "tier": "A"})) == "Waldrada was gone from the company by then.", "a partner who has left")
	# no pronouns anywhere in the canon text
	var gendered := 0
	for r in phrases:
		var low: String = " " + str(r["text"]).to_lower() + " "
		for w in [" he ", " she ", " his ", " her ", " him "]:
			if low.contains(w):
				gendered += 1
	check(gendered == 0, "no phrase guesses a pronoun")

	# ---- permadeath: pending, then final
	_fresh()
	_join(["u_jost", "u_rinsa", "u_ricberta"])
	check(not _e.eligible("u_avatar") and not _e.eligible("gst_anna") and not _e.eligible("cargo_wagon") and _e.eligible("u_jost"), "the avatar, Anna and cargo are never recorded")
	check(_e.note_fall("u_avatar", "map_d01", {"type": "unknown"}).is_empty(), "the avatar's fall is not recorded")
	check(_e.note_fall("u_jost", "map_f00", {"type": "unknown"}).is_empty(), "nor the prologue's")
	_gs.flags["casual"] = true
	check(_e.note_fall("u_jost", "map_d01", {"type": "unknown"}).is_empty(), "casual mode turns permadeath off")
	_gs.flags.erase("casual")
	_gs.inventories["u_jost"] = [{"weapon_id": "wpn_axe_basic", "uses": 12}, {"weapon_id": "wpn_sword_basic", "uses": 30}]
	var convoy_before: int = _gs.convoy.size()
	var r1: Dictionary = _e.note_fall("u_jost", "map_d01", {"type": "polity", "id": "pol_assembly", "noun": "lance", "who": "levy", "own_action": false, "enemy_idx": 4})
	check(not r1.is_empty() and _e.is_pending("u_jost") and not _e.is_dead("u_jost") and not _d.is_gone("u_jost"), "a fall is pending, not final")
	check(r1["chapter_id"] == "ch_d01" and r1["killed_by_type"] == "polity" and r1["enemy_idx"] == 4, "the record names the chapter and the killer")
	check(r1["pack"].size() <= 1 and (r1["weapon_id"] != "" or r1["pack"].size() == 0), "the carried weapon is set apart from the pack")
	_e.begin_map()
	check(not _e.is_pending("u_jost"), "a retried map forgets the falls")
	_e.note_fall("u_jost", "map_d01", {"type": "polity", "id": "pol_assembly", "noun": "lance", "who": "levy", "enemy_idx": 4})
	_e.note_fall("u_rinsa", "map_d01", {"type": "unknown"})
	var lines: Array[String] = _e.commit({"u_jost": "retrieved"})
	check(lines.size() == 2 and lines[0].begins_with("Jost ") and lines[1].begins_with("Rinsa "), "the sentences come back in the order they fell")
	check(_e.is_dead("u_jost") and _e.is_dead("u_rinsa") and _d.is_gone("u_jost") and _e.count() == 2, "winning makes it final; the dead have left the company")
	check(_e.death("u_jost")["seq"] == 1 and _e.death("u_rinsa")["seq"] == 2, "deaths are numbered")
	check(not _gs.inventories.has("u_jost"), "the dead carry nothing")
	check(_gs.convoy.size() > convoy_before, "the pack and a retrieved weapon go to the convoy")
	check(_e.death("u_jost")["weapon_fate"] == "retrieved", "the fate is recorded")
	check(_e.is_dead("u_jost") and _e.note_fall("u_jost", "map_d02", {"type": "unknown"}).is_empty(), "the dead cannot fall twice")
	check(not _e.is_pending("u_jost") and _gs.epilogue["pending"].is_empty(), "nothing is left pending")
	# fate rules
	check(_e.fate_for({"killed_by_type": "hazard"}, true) == "with_the_body", "a hazard leaves the weapon with the body")
	check(_e.fate_for({"killed_by_type": "unknown"}, false) == "lost_to_enemy", "unwitnessed: lost")
	check(_e.fate_for({"killed_by_type": "polity"}, false) == "retrieved", "the killer is gone: retrieved")
	check(_e.fate_for({"killed_by_type": "polity", "own_action": true}, true) == "thrown_and_lost", "died attacking, killer still there: thrown and lost")
	check(_e.fate_for({"killed_by_type": "polity"}, true) == "lost_to_enemy", "killer still holds it: lost to the enemy")
	# the roll
	var roll: Array = _e.roll()
	check(roll.size() == 2 and roll[0]["unit_id"] == "u_jost" and roll[1]["unit_id"] == "u_rinsa", "the roll is in order")
	check(_e.roll_text().begins_with("The Fallen") and _e.roll_text().contains("Rinsa fell at"), "the roll reads")
	_fresh()
	check(_e.roll_text() == "No one has fallen. Yet.", "an empty roll says so")
	# a dead unit does not defect; and persists
	_join(["u_anselm"])
	_e.note_fall("u_anselm", "map_c21", {"type": "unknown"})
	_e.commit()
	check(_d.on_map_won("map_c21", true).is_empty() and _d.state("def_anselm") == "", "a dead unit cannot defect")
	var saved: Dictionary = _gs.to_dict()
	var back: Variant = _gs.restore(JSON.parse_string(JSON.stringify(saved)))
	check(_gs.validate(back) == "", "the state with the fallen is a valid save")
	_gs.reset()
	_gs.from_dict(back)
	check(_e.is_dead("u_anselm") and _e.death("u_anselm")["seq"] == 1 and _e.sentence(_e.death("u_anselm")).begins_with("Anselm"), "the fallen survive a save and a load")

	# ---- on the map
	# an enemy kills a unit in the enemy phase; the win makes it final
	_fresh()
	_join(["u_gunnar", "u_ricberta"])
	var weak := {"hp": 1, "def": 0, "res": 0}
	var m: Node = await _map("map_d02", ["u_gunnar", "u_ricberta"], [Vector2i(5, 5), Vector2i(12, 12)],
		[{"arch": _arch("Conscript levy", {"enemy_id": "ea_conscript_levy", "str": 90, "dex": 90, "hp": 90}), "pos": Vector2i(6, 5)}], true)
	m.unit_hp["u_gunnar"] = 1
	m._enemy_phase()
	check(not m.unit_positions.has("u_gunnar") and _e.is_pending("u_gunnar") and not _e.is_dead("u_gunnar"), "an enemy phase kill is pending")
	var pr: Dictionary = _gs.epilogue["pending"]["u_gunnar"]
	check(pr["killed_by_type"] == "polity" and pr["killed_by_id"] == "pol_assembly" and pr["noun"] == "lance" and pr["enemy_idx"] == 0 and not pr["own_action"], "...credited to an Assembly lance, with the enemy's index")
	check(pr["weapon_id"] != "", "...with the weapon it carried")
	var cap: Dictionary = m.capture_state()
	check(cap["state"]["epilogue"]["pending"].has("u_gunnar"), "a mid-map suspension carries the pending fall")
	m.map_won = true        # the setter runs _on_map_won
	check(_e.is_dead("u_gunnar") and _d.is_gone("u_gunnar") and not _e.is_dead("u_ricberta"), "winning the map makes the fall final")
	check(m._reward_text.contains("Gunnar fell at the weighbridge to an Assembly lance."), "the win screen reads the sentence (%s)" % m._reward_text)
	check(_e.death("u_gunnar")["weapon_fate"] == "lost_to_enemy", "the levy still stood and holds the weapon: lost")
	m.queue_free()
	await process_frame
	# a retried map forgets; a dead unit isn't deployed
	var m2: Node = await _map("map_d02", ["u_gunnar", "u_ricberta"], [Vector2i(5, 5), Vector2i(6, 5)])
	check(m2.units.size() == 1 and m2.units[0]["punit_id"] == "u_ricberta", "a dead unit is not deployed")
	m2.queue_free()
	await process_frame
	# died attacking, and the killer is later defeated: retrieved
	_fresh()
	_join(["u_sigrun"])
	m = await _map("map_d02", ["u_sigrun"], [Vector2i(5, 5)],
		[{"arch": _arch("Conscript levy", {"enemy_id": "ea_conscript_levy", "str": 90, "dex": 90, "hp": 90}), "pos": Vector2i(6, 5)}])
	m.unit_hp["u_sigrun"] = 1
	m.selected_unit_index = 0
	m._attack_enemy()
	check(_e.is_pending("u_sigrun") and _gs.epilogue["pending"]["u_sigrun"]["own_action"], "a unit killed answering its own attack is marked as having died attacking")
	check(m._death_fates()["u_sigrun"] == "thrown_and_lost", "the killer lives: the weapon was thrown and lost")
	m.enemies[0].defeated = true
	check(m._death_fates()["u_sigrun"] == "retrieved", "the killer taken down: retrieved")
	m.enemies[0].routed = true
	check(m._death_fates()["u_sigrun"] == "thrown_and_lost", "the killer routed: it ran off with the weapon")
	# retry
	m.queue_free()
	await process_frame
	var m3: Node = await _map("map_d02", ["u_sigrun"], [Vector2i(5, 5)])
	check(not _e.is_pending("u_sigrun") and m3.units.size() == 1, "retrying the map wipes the pending fall and the unit is back")
	m3.queue_free()
	await process_frame
	# hazard
	_fresh()
	_join(["u_sigrun"])
	m = await _map("map_d02", ["u_sigrun"], [Vector2i(5, 5)])
	m._kill_unit("u_sigrun", {"type": "hazard", "id": "cold"})
	check(_gs.epilogue["pending"]["u_sigrun"]["killed_by_type"] == "hazard", "the cold is a killer")
	m._kill_unit("u_sigrun")
	check(_gs.epilogue["pending"]["u_sigrun"]["killed_by_type"] == "unknown", "a fall with no killer named is the chaos")
	m.queue_free()
	await process_frame
	# the boss-kill deed remembers its quarry
	_fresh()
	_join(["u_sigrun"])
	m = await _map("map_d02", ["u_sigrun"], [Vector2i(5, 5)],
		[{"arch": _arch("Warlord", {"enemy_id": "ea_warlord", "hp": 1, "affiliation": "state", "death_noun": "axe"}), "pos": Vector2i(6, 5), "kind": "boss"}])
	m.units[0]["str"] = 40
	m.selected_unit_index = 0
	m._attack_enemy()
	check(m.enemies[0].defeated and _p.has_deed("u_sigrun", "ep_bosskill") and _gs.epilogue["slain"]["u_sigrun"] == ["the warlord"], "slaying a boss alone remembers what was slain")
	m.queue_free()
	await process_frame

	# ---- the roll in the overworld
	_fresh()
	_join(["u_jost"])
	_e.note_fall("u_jost", "map_d01", {"type": "unknown"})
	_e.commit()
	var ow: Node = load("res://scenes/overworld.tscn").instantiate()
	root.add_child(ow)
	await process_frame
	check(ow.info_label.text.contains("The fallen: 1."), "the overworld panel counts the fallen")
	var ev := InputEventKey.new()
	ev.keycode = KEY_R
	ev.pressed = true
	ow._unhandled_input(ev)
	check(ow.info_label.text.begins_with("The Fallen") and ow.info_label.text.contains("Jost fell at the tally house"), "R opens the roll")
	ow._unhandled_input(ev)
	check(not ow.info_label.text.begins_with("The Fallen"), "R again returns")
	ow.queue_free()
	await process_frame
