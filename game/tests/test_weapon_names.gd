extends SceneTree
## Headless checks for weapon names: marks written on the blade by a deed, the name each mark
## gives, the cap, persistence, reforging at a master smith, and the epilogue reading the name.
## Run from the repo root:
##   godot --headless --path game --script res://tests/test_weapon_names.gd
## Exits 0 if every check passes, 1 otherwise.

var _failures: int = 0
var _checks: int = 0
var _p: Node
var _gs: Node
var _eq: Node
var _pv: Node
var _e: Node

func check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: ", label)

func _initialize() -> void:
	_p = root.get_node("Progression")
	_gs = root.get_node("GameState")
	_eq = root.get_node("Equipment")
	_pv = root.get_node("Provenance")
	_e = root.get_node("Epilogue")
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
		"level": 5, "hp": 1, "str": 0, "mag": 0, "dex": 0, "spd": 0, "lck": 0, "def": 0, "res": 0, "affiliation": "state", "death_noun": "lance"}
	d.merge(over, true)
	return d

func _run() -> void:
	# ---- canon
	var forms := {}
	for ep in root.get_node("Canon").get_table("epithets"):
		if str(ep.get("epithet_id", "")).begins_with("ep_"):
			forms[ep["epithet_id"]] = ep
	check(forms.size() == 8, "every deed has a row")
	for id in forms:
		check("{BASE}" in str(forms[id].get("weapon_form")), "%s has a weapon form" % id)
	check(_p.param("weapon_marks_max") == 3 and _p.param("reforge_fee") == 150, "three marks; reforging costs 150")

	# ---- names
	_fresh()
	var plain := {"weapon_id": "wpn_axe_basic", "uses": 45}
	check(_pv.name_of(plain) == "Iron Axe" and not _pv.is_marked(plain) and _pv.history(plain).is_empty(), "an unmarked weapon keeps its plain name")
	var expect := {"ep_solohold": "Iron Axe of the Ford", "ep_nohit": "Untouched Iron Axe", "ep_miasma": "Ash-walker's Iron Axe", "ep_delivery": "Carter's Iron Axe",
		"ep_dispersal": "Merciful Iron Axe", "ep_talk": "Peacemaker's Iron Axe", "ep_capture": "Taker's Iron Axe"}
	for id in expect:
		var e := {"weapon_id": "wpn_axe_basic", "uses": 45}
		check(_pv.add_mark(e, id) and _pv.name_of(e) == expect[id], "%s -> %s" % [id, expect[id]])
	var slay := {"weapon_id": "wpn_axe_basic", "uses": 45}
	_pv.add_mark(slay, "ep_bosskill", "the Karkadann")
	check(_pv.name_of(slay) == "Iron Axe, Slayer of the Karkadann", "a Slayer carries what it slew: %s" % _pv.name_of(slay))
	var bare := {"weapon_id": "wpn_axe_basic", "uses": 45}
	_pv.add_mark(bare, "ep_bosskill")
	check(_pv.name_of(bare) == "Slayer's Iron Axe", "a Slayer with no quarry on record")
	check(not _pv.add_mark(plain, "ep_nonsense") and not _pv.add_mark({}, "ep_talk") and not _pv.is_marked(plain), "unknown deeds and empty entries leave no mark")
	check(_pv.history(slay) == ["Slayer of the Karkadann"] and _pv.history(expect_entry("ep_talk")) == ["Peacemaker"], "history reads each mark")
	# strongest mark
	var multi := {"weapon_id": "wpn_sword_mid", "uses": 30}
	_pv.add_mark(multi, "ep_capture")      # gating
	_pv.add_mark(multi, "ep_talk")         # later, not gating
	check(_pv.name_of(multi) == "Taker's Steel Sword", "a paragon-gating mark beats a later one that does not")
	_pv.add_mark(multi, "ep_nohit")        # gating, later
	check(_pv.name_of(multi) == "Untouched Steel Sword", "...and of two gating marks the newer names it")
	check(_pv.history(multi) == ["Taker", "Peacemaker", "Untouched"], "the history keeps all three, oldest first")
	_pv.add_mark(multi, "ep_miasma")
	check(_pv.marks(multi).size() == 3 and _pv.history(multi) == ["Peacemaker", "Untouched", "Ash-walker"], "a fourth mark drops the oldest")
	_pv.add_mark(multi, "ep_talk")
	check(_pv.marks(multi).size() == 3 and _pv.history(multi) == ["Untouched", "Ash-walker", "Peacemaker"], "a repeated mark moves to the newest place instead of doubling")

	var twice := {"weapon_id": "wpn_axe_basic", "uses": 45}
	_pv.add_mark(twice, "ep_talk", "first")
	_pv.add_mark(twice, "ep_talk", "second")
	check(_pv.marks(twice).size() == 1 and _pv.marks(twice)[0]["object"] == "second", "the same deed twice is one mark, newest object")
	var soft := {"weapon_id": "wpn_axe_basic", "uses": 45}
	_pv.add_mark(soft, "ep_miasma")
	_pv.add_mark(soft, "ep_talk")
	check(_pv.name_of(soft) == "Peacemaker's Iron Axe", "of two marks that gate nothing, the newer names it")

	# ---- display
	_fresh()
	_join(["u_jost"])
	var inv: Array = _eq.inventory("u_jost")
	var held: Dictionary = _eq.equipped("u_jost")
	check(_eq.describe(held).begins_with("Iron Axe ("), "plain description")
	check(_pv.mark_equipped("u_jost", "ep_capture") and _eq.describe(_eq.equipped("u_jost")).begins_with("Taker's Iron Axe ("), "the equipped weapon takes the mark and shows it")
	check(not _pv.mark_equipped("u_nobody", "ep_capture"), "nobody's weapon takes no mark")
	var json: Variant = _gs.restore(JSON.parse_string(JSON.stringify(_gs.to_dict())))
	check(_gs.validate(json) == "", "marks are valid save data")
	_gs.reset()
	_gs.from_dict(json)
	check(_pv.name_of(_eq.equipped("u_jost")) == "Taker's Iron Axe", "marks survive a save and a load")
	# they travel: store, take
	var invn: int = _eq.inventory("u_jost").size()
	_eq.store("u_jost", 0)
	check(_pv.name_of(_gs.convoy[-1]) == "Taker's Iron Axe", "stored in the convoy it is still the Taker's")
	_eq.take("u_jost", _gs.convoy.size() - 1)
	check(_pv.name_of(_eq.inventory("u_jost")[-1]) == "Taker's Iron Axe" and _eq.inventory("u_jost").size() == invn, "...and taken back")
	# a broken weapon is mourned by name
	_fresh()
	_join(["u_jost"])
	_pv.mark_equipped("u_jost", "ep_nohit")
	var inv2: Array = _eq.inventory("u_jost")
	var e0: Dictionary = _eq.equipped("u_jost")
	e0["uses"] = 1
	var broke: Dictionary = _eq.spend_use("u_jost", 1)
	check(broke.get("broke", false) and broke["name"] == "Untouched Iron Axe", "'Untouched Iron Axe breaks'")

	# ---- on the map: a deed marks the blade in hand
	_fresh()
	_join(["u_sigrun"])
	var m: Node = await _map("map_d02", ["u_sigrun"], [Vector2i(5, 5)],
		[{"arch": _arch("Warlord", {"enemy_id": "ea_warlord", "affiliation": "state", "death_noun": "axe"}), "pos": Vector2i(6, 5), "kind": "boss"}])
	m.units[0]["str"] = 40
	m.selected_unit_index = 0
	var wid_before: String = _eq.equipped("u_sigrun")["weapon_id"]
	m._attack_enemy()
	var held2: Dictionary = _eq.equipped("u_sigrun")
	check(m.enemies[0].defeated and _p.has_deed("u_sigrun", "ep_bosskill"), "(the boss fell to a lone killer)")
	check(_pv.name_of(held2) == "Iron Sword, Slayer of the warlord", "the deed is written on the blade, with its quarry: %s" % _pv.name_of(held2))
	m._earn_deed("u_sigrun", "ep_bosskill", "Sigrun")
	check(_pv.marks(held2).size() == 1, "a deed already earned marks nothing twice")
	# no weapon: no mark, no error
	m._earn_deed("u_sigrun", "ep_talk", "Sigrun")
	check(_pv.history(_eq.equipped("u_sigrun")) == ["Slayer of the warlord", "Peacemaker"], "the next deed is the next mark")
	m.queue_free()
	await process_frame

	# ---- the epilogue reads the name; a retrieved weapon comes home marked
	_fresh()
	_join(["u_jost"])
	_pv.mark_equipped("u_jost", "ep_capture")
	_e.note_fall("u_jost", "map_d01", {"type": "polity", "id": "pol_assembly", "noun": "lance", "who": "levy", "enemy_idx": -1})
	var rec: Dictionary = _gs.epilogue["pending"]["u_jost"]
	check(rec["weapon_marks"].size() == 1, "the record keeps the weapon's marks")
	var out: Array[String] = _e.commit({"u_jost": "retrieved"})
	check(out[0].contains("The Taker's Iron Axe came home in the convoy."), "the epilogue names the blade: %s" % out[0])
	check(_pv.name_of(_gs.convoy[-1]) == "Taker's Iron Axe", "...and it is in the convoy still marked")

	# ---- reforging
	_fresh()
	_join(["u_jost"])
	_eq.ensure_ready()
	var axe := {"weapon_id": "wpn_axe_basic", "uses": 20}
	_pv.add_mark(axe, "ep_capture")
	_gs.convoy.append(axe)
	var ai: int = _gs.convoy.size() - 1
	var sw := {"weapon_id": "wpn_sword_basic", "uses": 20}
	_pv.add_mark(sw, "ep_talk")
	_gs.convoy.append(sw)
	var si: int = _gs.convoy.size() - 1
	var bow := {"weapon_id": "wpn_bow_basic", "uses": 20}
	_pv.add_mark(bow, "ep_talk")
	_gs.convoy.append(bow)
	var bi: int = _gs.convoy.size() - 1
	var leg := {"weapon_id": "wpn_feather_blade", "uses": 30}
	_pv.add_mark(leg, "ep_talk")
	_gs.convoy.append(leg)
	var li: int = _gs.convoy.size() - 1
	var clean_idx: int = 0
	_gs.gold = 1000
	check(not _pv.can_reforge(clean_idx, "frg_kaisareia")["ok"] and _pv.can_reforge(clean_idx, "frg_kaisareia")["reason"].contains("no marks"), "nothing to clear on a plain weapon")
	check(_pv.can_reforge(si, "frg_kaisareia")["ok"], "the edged master reforges a sword")
	check(not _pv.can_reforge(ai, "frg_kaisareia")["ok"] and _pv.can_reforge(ai, "frg_kaisareia")["reason"].contains("does not work axe"), "...but not an axe")
	check(not _pv.can_reforge(ai, "frg_vashti")["ok"] and _pv.can_reforge(ai, "frg_vashti")["reason"].contains("needs The Cinder Track won first"), "the hafted master is closed until the road is held")
	_gs.won_maps["map_ct19"] = true
	check(_pv.can_reforge(ai, "frg_vashti")["ok"], "...then reforges an axe")
	check(not _pv.can_reforge(bi, "frg_herd")["ok"], "the missile master is closed until the Herd grant passage")
	_gs.won_maps["map_x11"] = true
	check(_pv.can_reforge(bi, "frg_herd")["ok"], "...then reforges a bow")
	check(not _pv.can_reforge(li, "frg_kaisareia")["ok"] and _pv.can_reforge(li, "frg_kaisareia")["reason"].contains("legendary"), "a legendary weapon's history is not the smith's to clear")
	check(not _pv.can_reforge(si, "frg_standard_a")["ok"], "a standard forge cannot reforge")
	check(not _pv.can_reforge(999, "frg_kaisareia")["ok"], "a bad index is refused")
	_gs.gold = 149
	check(not _pv.can_reforge(si, "frg_kaisareia")["ok"] and _pv.can_reforge(si, "frg_kaisareia")["reason"].contains("150 gold"), "149 gold is not enough")
	_gs.gold = 400
	var res: Dictionary = _pv.reforge(si, "frg_kaisareia")
	check(res["ok"] and res["was"] == "Peacemaker's Iron Sword" and _gs.gold == 250, "reforging pays the fee and says what it was")
	check(not _pv.is_marked(_gs.convoy[si]) and _pv.name_of(_gs.convoy[si]) == "Iron Sword" and int(_gs.convoy[si]["uses"]) == 20, "...the marks are gone and the uses are untouched")
	check(not _pv.reforge(si, "frg_kaisareia")["ok"] and _gs.gold == 250, "a second go costs nothing and does nothing")

	# ---- the forge screen
	_gs.world_location = "loc_vashti_gate"
	var fs: Node = load("res://scenes/forge_screen.tscn").instantiate()
	root.add_child(fs)
	await process_frame
	var rows: Array = fs.rows()
	var kinds: Array = rows.map(func(r): return r["kind"])
	check(kinds.has("reforge"), "the hafted master offers to reforge the marked axe")
	var rr: Dictionary = rows[kinds.find("reforge")]
	check(fs.row_label(rr) == "Reforge: Taker's Iron Axe" and fs.detail_text(rr).contains("Marks: Taker"), "...by its marked name, with its marks")
	check(not rows.any(func(r): return r["kind"] == "reforge" and _gs.convoy[r["convoy_index"]]["weapon_id"] == "wpn_sword_basic"), "(and not the sword, which is plain now and the wrong craft)")
	fs._index = kinds.find("reforge")
	check(fs.activate() and not _pv.is_marked(_gs.convoy[ai]) and _gs.gold == 100, "Enter reforges it")
	check(not fs.rows().any(func(r): return r["kind"] == "reforge"), "nothing left to reforge")
	fs.queue_free()
	await process_frame

func expect_entry(ep: String) -> Dictionary:
	var e := {"weapon_id": "wpn_axe_basic", "uses": 45}
	_pv.add_mark(e, ep)
	return e
