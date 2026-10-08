extends SceneTree
## Headless checks for the forge system: beast materials from the Named, the master
## smiths and their access rules, commissions and the chapter cycle, the three-work cap,
## the four legendary weapons and their on-hit specials, and the forge screen.
## Run from the repo root:
##   godot --headless --path game --script res://tests/test_forge.gd
## Exits 0 if every check passes, 1 otherwise.

var _failures: int = 0
var _checks: int = 0
var _p: Node
var _gs: Node
var _eq: Node
var _f: Node
var _canon: Node

func check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: ", label)

func _initialize() -> void:
	_p = root.get_node("Progression")
	_gs = root.get_node("GameState")
	_eq = root.get_node("Equipment")
	_f = root.get_node("Forge")
	_canon = root.get_node("Canon")
	await process_frame
	await _run()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)

func _fresh() -> void:
	_gs.reset()

func _arch(name: String, over := {}) -> Dictionary:
	var d := {"enemy_id": "ea_t_" + name, "name": name, "weapon_art": "sword", "weapon_tier": "worn", "movement_type": "infantry",
		"level": 5, "hp": 40, "str": 0, "mag": 0, "dex": 0, "spd": 0, "lck": 0, "def": 0, "res": 0}
	d.merge(over, true)
	return d

func _map(deploy: Array, positions: Array, specs: Array, scene := "map_d05") -> Node:
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

func _rng_hit(m: Node) -> void:
	for sd in range(1, 5000):
		var r := RandomNumberGenerator.new()
		r.seed = sd
		if r.randi_range(1, 100) <= 15:
			var fresh := RandomNumberGenerator.new()
			fresh.seed = sd
			m.rng_override = fresh
			return

## Gives a unit a legendary weapon in hand (promoting them so they may wield it).
func _arm(uid: String, weapon_id: String, class_id: String) -> void:
	_p.state(uid)
	_gs.progression[uid]["level"] = 15
	_gs.gold = 100000
	_p.promote(uid, class_id)
	_gs.gold = 0
	_eq.ensure_ready()
	_gs.inventories[uid] = [{"weapon_id": weapon_id, "uses": 30}]

func _run() -> void:
	# ---- canon
	_fresh()
	var legend: Array = []
	for w in _canon.get_table("weapons"):
		if w["tier"] == "legendary":
			legend.append(w["weapon_id"])
	check(legend == ["wpn_feather_blade", "wpn_karkadann_lance", "wpn_anzu_edge", "wpn_shadhavar_bow"], "four legendary weapons, one per usable Named (%s)" % str(legend))
	var effects := {}
	for id in legend:
		effects[id] = _eq.weapon_row(id).get("effect")
	check(effects == {"wpn_feather_blade": "heal_allies", "wpn_karkadann_lance": null, "wpn_anzu_edge": "unmake", "wpn_shadhavar_bow": "pull"}, "their specials (the lance's is its x2 against riding)")
	check(_eq.weapon_row("wpn_karkadann_lance")["effective_vs"] == "riding" and _eq.weapon_row("wpn_shadhavar_bow")["range_min"] == 2, "the lance is effective vs riding; the bow shoots at range 2")
	check(_f.master_forges().size() == 3 and _f.forges_at("loc_kaisareia_walls").size() == 1 and _f.forges_at("loc_vashti_gate")[0]["forge_id"] == "frg_vashti" and _f.forges_at("loc_ostrova")[0]["forge_id"] == "frg_herd", "three masters, each at a place on the overworld")
	check(_f.forges_at("loc_tally_house").is_empty(), "and nowhere else")
	check(_f.material_for_enemy("ea_simurgh")["material_id"] == "mat_simurgh" and _f.material_for_enemy("ea_garrison").is_empty(), "the Named stand-ins map to materials; ordinary enemies don't")
	var huma: Dictionary = _canon.find_by("materials", "material_id", "mat_huma")
	check(huma.get("weapon_id") == null and huma.get("enemy_id") == null, "the Huma yields nothing, on purpose")
	check(_f.works_cap() == 3 and _f.works_left() == 3, "three master works a run")
	check(_f.hits_to_unmake("worn") == 1 and _f.hits_to_unmake("basic") == 2 and _f.hits_to_unmake("mid") == 3 and _f.hits_to_unmake("high") == 4, "an Anzu Edge unmakes a worn weapon in 1 hit, a silver one in 4")

	# ---- legendary weapons need a certified class
	_p.state("u_jost")
	_gs.progression["u_jost"]["level"] = 15
	_eq.ensure_ready()
	check(not _p.can_use_tier("u_jost", "legendary") and not _eq.can_wield("u_jost", "wpn_anzu_edge") and not _p.can_use_tier("u_jost", "high"), "an uncertified unit can't wield a legendary weapon (or a silver one)")
	_p.can_use_tier("u_jost", "legendary")
	check(_p.can_use_tier("u_jost", "basic"), "(basic ones are open)")

	# ---- materials come from Named stand-ins
	_fresh()
	var msg: String = _f.on_named_defeated("ea_simurgh", "killed")
	check(msg == "The Simurgh yields the feather (a prime material)." and _gs.materials == {"mat_simurgh": "prime"}, "killing the Simurgh yields a prime feather (%s)" % msg)
	check(_f.on_named_defeated("ea_simurgh", "killed") == "" and _gs.materials.size() == 1, "once only: a replay yields nothing")
	msg = _f.on_named_defeated("ea_karkadann", "captured")
	check(msg == "The Karkadann yields the horn (a diminished material, harvested)." and _gs.materials["mat_karkadann"] == "diminished", "capturing the Karkadann yields a diminished horn (%s)" % msg)
	check(_f.on_named_defeated("ea_garrison", "killed") == "" and _f.on_named_defeated("ea_huma", "killed") == "", "ordinary enemies and the Huma yield nothing")
	_gs.materials.erase("mat_simurgh")
	check(_f.on_named_defeated("ea_simurgh", "killed") == "", "spending a material doesn't let the Named yield another (it stays claimed)")
	check(_f.held().size() == 1 and _f.held()[0]["quality"] == "diminished", "held() lists what is in hand")

	# ---- access rules
	_fresh()
	check(_f.access("frg_kaisareia")["ok"], "the edged master is always open (the crown permits)")
	var v: Dictionary = _f.access("frg_vashti")
	check(not v["ok"] and v["reason"].contains("The Cinder Track"), "the hafted master waits for the Cinder Track (%s)" % v["reason"])
	_gs.won_maps["map_ct19"] = true
	check(_f.access("frg_vashti")["ok"], "...and opens when it is won (the road is held)")
	var h: Dictionary = _f.access("frg_herd")
	check(not h["ok"] and h["reason"].contains("The Second Writ"), "the missile master waits for the Second Writ (%s)" % h["reason"])
	_gs.won_maps["map_x11"] = true
	check(_f.access("frg_herd")["ok"], "...and opens with it (passage granted)")
	check(not _f.access("frg_nonesuch")["ok"], "an unknown smith can't be reached")

	# ---- commissioning
	_fresh()
	check(not _f.can_commission("mat_simurgh")["ok"] and _f.can_commission("mat_simurgh")["reason"] == "you hold no such material", "no material, no commission")
	_gs.materials["mat_karkadann"] = "prime"
	var cc: Dictionary = _f.can_commission("mat_karkadann")
	check(not cc["ok"] and cc["reason"].contains("the hafted master"), "the Vashti smith is closed: refused, naming her (%s)" % cc["reason"])
	check(_gs.materials.has("mat_karkadann") and _gs.works_started == 0, "a refusal costs nothing")
	_gs.won_maps["map_ct19"] = true
	var r: Dictionary = _f.commission("mat_karkadann")
	check(r["ok"] and r["order"]["weapon_id"] == "wpn_karkadann_lance" and r["order"]["chapters_left"] == 2 and not r["order"]["ready"] and r["order"]["quality"] == "prime", "commissioning starts a two-chapter work")
	check(not _gs.materials.has("mat_karkadann") and _gs.works_started == 1 and _f.works_left() == 2 and _f.orders_for("frg_vashti") == [0], "the material is spent, a work counted")
	# the cap
	_gs.works_started = 3
	_gs.materials["mat_simurgh"] = "prime"
	check(_f.can_commission("mat_simurgh")["reason"].contains("all 3 master works"), "after three works, no more (the cap)")
	_gs.works_started = 1
	# cycle
	check(_f.on_map_won(false).is_empty() and _gs.forge_orders[0]["chapters_left"] == 2, "a map won before doesn't count toward a commission")
	check(_f.on_map_won(true).is_empty() and _gs.forge_orders[0]["chapters_left"] == 1, "a newly won chapter takes one off")
	check(not _f.collect(0)["ok"] and _f.collect(0)["reason"].contains("1 chapter to go"), "not collectable yet (%s)" % _f.collect(0)["reason"])
	var done: Array[String] = _f.on_map_won(true)
	check(done.size() == 1 and done[0].contains("finished the Karkadann Lance") and _gs.forge_orders[0]["ready"], "the second finishes it, with a line (%s)" % str(done))
	check(_f.on_map_won(true).is_empty() and _gs.forge_orders[0]["chapters_left"] <= 0, "(a finished one isn't counted again)")
	# collect
	_eq.ensure_ready()
	var convoy_n: int = _gs.convoy.size()
	var col: Dictionary = _f.collect(0)
	check(col["ok"] and _gs.convoy.size() == convoy_n + 1 and _gs.convoy[-1]["weapon_id"] == "wpn_karkadann_lance" and _gs.convoy[-1]["uses"] == 30, "collecting puts the lance in the convoy with full uses")
	check(_gs.forge_orders.is_empty() and _gs.works_started == 1, "the order is gone; the work still counts toward the cap")
	check(not _f.collect(0)["ok"] and not _f.collect(-1)["ok"], "nothing left to collect")
	# a diminished material: half the uses
	_gs.materials["mat_simurgh"] = "diminished"
	_f.commission("mat_simurgh")
	_f.on_map_won(true); _f.on_map_won(true)
	_f.collect(0)
	check(_gs.convoy[-1]["weapon_id"] == "wpn_feather_blade" and _gs.convoy[-1]["uses"] == 15, "a harvested material makes a weapon with half the uses (%d)" % _gs.convoy[-1]["uses"])
	check(_f.uses_for("wpn_feather_blade", "diminished") == 15 and _f.uses_for("wpn_feather_blade", "prime") == 30, "uses_for agrees")

	# ---- saving
	_fresh()
	_gs.materials["mat_anzu"] = "prime"; _gs.materials_claimed["mat_anzu"] = true
	_gs.forge_orders.append({"forge_id": "frg_kaisareia", "material_id": "mat_simurgh", "weapon_id": "wpn_feather_blade", "quality": "prime", "chapters_left": 1, "ready": false})
	_gs.works_started = 2
	var snap: Dictionary = JSON.parse_string(JSON.stringify(_gs.to_dict()))
	_gs.reset()
	check(_gs.validate(snap) == "", "the forge state is a valid save")
	_gs.from_dict(snap)
	check(_gs.materials == {"mat_anzu": "prime"} and _gs.materials_claimed.has("mat_anzu") and _gs.forge_orders.size() == 1 and _gs.forge_orders[0]["chapters_left"] == 1 and _gs.works_started == 2, "materials, claims, orders and the cap count come back")
	check(typeof(_gs.works_started) == TYPE_INT and typeof(_gs.forge_orders[0]["chapters_left"]) == TYPE_INT, "(as integers)")

	# ---- on the map: a Named falls
	_fresh()
	var sim: Dictionary = _canon.find_by("enemy_archetypes", "enemy_id", "ea_simurgh").duplicate()
	sim["hp"] = 5; sim["def"] = 0; sim["res"] = 0
	var m: Node = await _map(["u_jost"], [Vector2i(5, 5)], [{"arch": sim, "pos": Vector2i(6, 5), "kind": "boss"}])
	m.enemies[0].hp = 1
	m.enemies[0].max_hp = 5
	m.units[0]["str"] = 30
	_rng_hit(m)
	m._attack_enemy()
	check(m.enemies[0].defeated and _gs.materials.get("mat_simurgh") == "prime", "killing the Simurgh stand-in gives the prime feather")
	check(m.info_label.text.contains("The Simurgh yields the feather (a prime material)."), "and the map says so (%s)" % m.info_label.text)
	m.queue_free()
	await process_frame
	# capturing a Named is a harvest -- and capture refuses other bosses
	_fresh()
	var kark: Dictionary = _canon.find_by("enemy_archetypes", "enemy_id", "ea_karkadann").duplicate()
	var m2: Node = await _map(["u_gunnar"], [Vector2i(4, 5)], [{"arch": kark, "pos": Vector2i(6, 5), "kind": "boss"}, {"arch": _arch("Captain"), "pos": Vector2i(4, 7), "kind": "boss"}])
	m2.enemies[0].hp = int(m2.enemies[0].max_hp / 2)
	m2.enemies[1].hp = 2
	m2.selected_unit_index = 0
	m2._capture_enemy()
	check(m2.enemies[0].defeated and m2.enemies[0].get("captured", false) and _gs.materials.get("mat_karkadann") == "diminished", "capturing the Karkadann at half HP harvests a diminished horn")
	check(m2.info_label.text.contains("The Karkadann yields the horn (a diminished material, harvested)."), "(%s)" % m2.info_label.text)
	m2.attacked_this_turn.clear()
	m2.unit_positions["u_gunnar"] = Vector2i(4, 5)
	m2.enemies[1].pos = Vector2i(4, 7)
	m2._capture_enemy()
	check(not m2.enemies[1].defeated and m2.info_label.text.contains("boss will not surrender"), "an ordinary boss still can't be captured")
	m2.queue_free()
	await process_frame
	# the capture preview agrees
	_fresh()
	m2 = await _map(["u_gunnar"], [Vector2i(4, 5)], [{"arch": _canon.find_by("enemy_archetypes", "enemy_id", "ea_anzu").duplicate(), "pos": Vector2i(6, 5), "kind": "boss"}])
	m2.enemies[0].hp = int(m2.enemies[0].max_hp / 2)
	check(m2._capture_text("u_gunnar", m2.enemies[0]).begins_with("Capture ready"), "the forecast offers to harvest a weakened Named")
	m2.queue_free()
	await process_frame

	# ---- on the map: Feather Blade heals allies beside the wielder
	_fresh()
	m = await _map(["u_sigrun", "u_avatar", "u_dietmar"], [Vector2i(5, 5), Vector2i(4, 5), Vector2i(5, 8)], [{"arch": _arch("Dummy", {"hp": 200}), "pos": Vector2i(6, 5)}])
	_arm("u_sigrun", "wpn_feather_blade", "cls_swordmaster")
	m.units[0]["arts"] = _eq.unit_arts("u_sigrun")
	_rng_hit(m)
	var av: int = int(m.units[1]["hp"])
	var di: int = int(m.units[2]["hp"])
	var jo: int = int(m.units[0]["hp"])
	m.unit_hp["u_avatar"] = av - 8
	m.unit_hp["u_dietmar"] = di - 8
	m.unit_hp["u_sigrun"] = jo - 3
	m._attack_enemy()
	check(_eq.equipped("u_sigrun").get("weapon_id") == "wpn_feather_blade", "(Sigrun has the blade in hand)")
	check(m.unit_hp["u_avatar"] == av - 3 and m.unit_hp["u_dietmar"] == di - 8, "a hit heals the ally beside him for 5, not the one across the field (avatar %d, dietmar %d)" % [m.unit_hp["u_avatar"] - av, m.unit_hp["u_dietmar"] - di])
	check(m.unit_hp["u_sigrun"] <= jo - 3 and m.info_label.text.contains("heals 1 ally"), "and not the wielder himself (%s)" % m.info_label.text)
	# caps at max HP
	m.attacked_this_turn.clear()
	m.unit_hp["u_avatar"] = av - 2
	_rng_hit(m)
	m._attack_enemy()
	check(m.unit_hp["u_avatar"] == av, "healing stops at full HP")
	m.queue_free()
	await process_frame

	# ---- Anzu Edge: unmake
	_fresh()
	m = await _map(["u_sigrun"], [Vector2i(5, 5)], [{"arch": _arch("Worn", {"hp": 200, "weapon_tier": "worn"}), "pos": Vector2i(6, 5)},
		{"arch": _arch("Silver", {"hp": 200, "weapon_tier": "high", "weapon_art": "sword"}), "pos": Vector2i(12, 9)}])
	m.unit_hp["u_sigrun"] = 1000
	_arm("u_sigrun", "wpn_anzu_edge", "cls_swordmaster")
	m.units[0]["arts"] = _eq.unit_arts("u_sigrun")
	_rng_hit(m)
	m.selected_unit_index = 0
	m._attack_enemy()
	check(m.enemies[0].get("unarmed", false) and m._enemy_weapon(m.enemies[0]).is_empty(), "one hit unmakes a worn weapon: the foe is unarmed")
	check(m.info_label.text.contains("unmakes the Worn's weapon"), "(%s)" % m.info_label.text)
	m.enemy_phase_enabled = true
	m.unit_hp["u_sigrun"] = 1000
	m.enemies[0].archetype["str"] = 30
	m.enemies[0].archetype["dex"] = 90
	m.enemies[1].hp = 200
	m.enemies[1].pos = Vector2i(40, 40)
	m._enemy_phase()
	check(m.unit_hp["u_sigrun"] == 1000 and m.enemies[0].pos == Vector2i(6, 5), "an unarmed enemy neither attacks nor moves in the enemy phase")
	m.enemy_phase_enabled = false
	m.enemies[1].pos = Vector2i(5, 6)
	m.attacked_this_turn.clear()
	# the silver one takes four hits
	m.unit_positions["u_sigrun"] = Vector2i(5, 5)
	var worn_steps: Array = []
	for i in 4:
		m.attacked_this_turn.clear()
		m._target_idx = 0
		m._targets = [m.enemies[1]]
		m.enemies[0].defeated = true
		m.unit_hp["u_sigrun"] = 1000
		_rng_hit(m)
		m._attack_enemy()
		worn_steps.append(int(m.enemies[1].get("wear", 0)))
	check(worn_steps == [1, 2, 3, 4] and m.enemies[1].get("unarmed", false), "a silver weapon is worn down hit by hit and gone at the fourth (%s)" % str(worn_steps))
	m.queue_free()
	await process_frame

	# ---- Shadhavar Bow: pull
	_fresh()
	m = await _map(["u_tancred", "u_jost"], [Vector2i(5, 5), Vector2i(2, 8)], [{"arch": _arch("Far", {"hp": 200, "weapon_art": "bow"}), "pos": Vector2i(7, 5)}])
	_arm("u_tancred", "wpn_shadhavar_bow", "cls_sniper")
	m.units[0]["arts"] = _eq.unit_arts("u_tancred")
	_rng_hit(m)
	m.selected_unit_index = 0
	m._attack_enemy()
	check(m.enemies[0].pos == Vector2i(6, 5) and m.info_label.text.contains("drags the Far a tile closer"), "a hit drags the foe a tile toward the archer (%s)" % str(m.enemies[0].pos))
	m.attacked_this_turn.clear()
	_rng_hit(m)
	m._attack_enemy()
	check(m.enemies[0].pos == Vector2i(6, 5), "an adjacent foe isn't pulled further (the bow can't shoot at range 1 anyway)")
	m.enemies[0].pos = Vector2i(7, 5)
	m.enemies[0].kind = "boss"
	m.attacked_this_turn.clear()
	_rng_hit(m)
	m._attack_enemy()
	check(m.enemies[0].pos == Vector2i(7, 5), "a boss is never dragged")
	m.enemies[0].kind = "mook"
	m.unit_positions["u_jost"] = Vector2i(6, 5)
	m.attacked_this_turn.clear()
	_rng_hit(m)
	m._attack_enemy()
	check(m.enemies[0].pos == Vector2i(7, 5), "and a foe is not dragged into a tile someone stands on")
	m.queue_free()
	await process_frame

	# ---- Karkadann Lance: effective vs riding, nothing special on foot
	_fresh()
	m = await _map(["u_dietmar"], [Vector2i(5, 5)], [{"arch": _arch("Rider", {"movement_type": "riding", "weapon_art": "sword"}), "pos": Vector2i(6, 5)}, {"arch": _arch("Walker"), "pos": Vector2i(4, 5)}])
	_arm("u_dietmar", "wpn_karkadann_lance", "cls_general")
	m.units[0]["arts"] = _eq.unit_arts("u_dietmar")
	var fi: Dictionary = m._forecast_info(m.units[0], m.enemies[0])
	var fj: Dictionary = m._forecast_info(m.units[0], m.enemies[1])
	check(fi["forecast"]["atk"]["effective"] and not fj["forecast"]["atk"]["effective"], "the lance is effective against the rider and not against the walker")
	check(fi["effect_text"] == "" and _f.effect_text(_eq.weapon_row("wpn_anzu_edge")).contains("wears the foe's weapon down"), "(a plain lance has no special line; the Anzu Edge's reads right)")
	m.queue_free()
	await process_frame

	# ---- the forecast shows a special
	_fresh()
	m = await _map(["u_sigrun"], [Vector2i(5, 5)], [{"arch": _arch("Dummy"), "pos": Vector2i(6, 5)}])
	_arm("u_sigrun", "wpn_feather_blade", "cls_swordmaster")
	m.units[0]["arts"] = _eq.unit_arts("u_sigrun")
	var info: Dictionary = m._forecast_info(m.units[0], m.enemies[0])
	check(info["effect_text"] == "Heals each ally beside the wielder for 5 on a hit.", "the forecast info carries the special")
	var ForecastView = load("res://scripts/forecast_view.gd")
	check(ForecastView.bbcode(info).contains("Heals each ally beside the wielder for 5 on a hit."), "and the panel prints it")
	check(not ForecastView.bbcode(m._forecast_info(m.units[0], m.enemies[0]).merged({"effect_text": ""}, true)).contains("Heals each ally"), "(nothing for an ordinary weapon)")
	m.queue_free()
	await process_frame

	# ---- mid-map saves carry the wear
	_fresh()
	m = await _map(["u_jost"], [Vector2i(5, 5)], [{"arch": _arch("Worn"), "pos": Vector2i(6, 5)}])
	m.enemies[0]["unarmed"] = true
	m.enemies[0]["wear"] = 2
	var st: Dictionary = JSON.parse_string(JSON.stringify(m.capture_state()))
	check(st["enemies"][0]["unarmed"] == true and int(st["enemies"][0]["wear"]) == 2, "a suspended battle remembers an unmade weapon")
	m.queue_free()
	await process_frame

	# ---- a win moves the cycle on (newly won only)
	_fresh()
	_gs.materials["mat_simurgh"] = "prime"
	_f.commission("mat_simurgh")
	m = await _map(["u_jost"], [Vector2i(5, 5)], [])
	m.map_won = true
	check(_gs.forge_orders[0]["chapters_left"] == 1, "winning a new map takes a chapter off the commission")
	m.queue_free()
	await process_frame
	m = await _map(["u_jost"], [Vector2i(5, 5)], [])
	m.map_won = true
	check(_gs.forge_orders[0]["chapters_left"] == 1, "winning the same map again does not")
	m.queue_free()
	await process_frame
	var m3: Node = await _map(["u_jost"], [Vector2i(5, 5)], [], "map_d02")
	m3.map_won = true
	check(_gs.forge_orders[0]["ready"] and m3._reward_text.contains("finished the Feather Blade"), "the next new map finishes it, and the win says so (%s)" % m3._reward_text)
	m3.queue_free()
	await process_frame

	# ---- the forge screen
	_fresh()
	_gs.world_location = "loc_kaisareia_walls"
	_gs.materials["mat_simurgh"] = "prime"
	_gs.materials["mat_karkadann"] = "diminished"
	var sc: Node = load("res://scenes/forge_screen.tscn").instantiate()
	root.add_child(sc)
	await process_frame
	var rows: Array = sc.rows()
	check(rows.size() == 1 and rows[0]["kind"] == "commission" and rows[0]["material_id"] == "mat_simurgh", "at Kaisareia only the edged master's material is offered (the horn is for Vashti)")
	check(sc.row_label(rows[0]) == "Commission from the feather (prime)", "(%s)" % sc.row_label(rows[0]))
	var dt: String = sc.detail_text(rows[0])
	check(dt.contains("the edged master") and dt.contains("Open to you.") and dt.contains("Feather Blade") and dt.contains("Heals each ally") and dt.contains("Enter commissions it. It takes 2 chapters."), "the detail shows the smith, the weapon, its special and the terms")
	check(dt.contains("Master works commissioned: 0 of 3") and dt.contains("Materials held: the feather (prime), the horn (diminished)"), "and the standing: works and materials")
	check(sc.activate() and _gs.works_started == 1 and sc._message.contains("Feather Blade in 2 chapters"), "Enter commissions (%s)" % sc._message)
	check(sc.rows().size() == 1 and sc.rows()[0]["kind"] == "waiting" and sc.row_label(sc.rows()[0]).contains("2 chapters to go"), "the work then shows as in progress")
	check(not sc.activate(), "Enter on a work in progress does nothing")
	_gs.forge_orders[0]["ready"] = true
	_gs.forge_orders[0]["chapters_left"] = 0
	sc._refresh()
	check(sc.rows()[0]["kind"] == "collect" and sc.row_label(sc.rows()[0]).begins_with("Collect: Feather Blade"), "finished: it offers to collect")
	_eq.ensure_ready()
	var cv: int = _gs.convoy.size()
	check(sc.activate() and _gs.convoy.size() == cv + 1 and sc._message.contains("is yours"), "Enter collects it into the convoy (%s)" % sc._message)
	check(sc.rows()[0]["kind"] == "none" and sc.detail_text(sc.rows()[0]).contains("You have nothing for this smith yet"), "then there is nothing to do here")
	sc.queue_free()
	await process_frame
	# a closed smith explains itself and refuses
	_gs.world_location = "loc_vashti_gate"
	sc = load("res://scenes/forge_screen.tscn").instantiate()
	root.add_child(sc)
	await process_frame
	check(sc.rows()[0]["kind"] == "commission", "at Vashti the horn is offered")
	check(sc.detail_text(sc.rows()[0]).contains("Closed: needs The Cinder Track won first."), "...but the smith is closed until the Cinder Track is won")
	check(not sc.activate() and sc._message.contains("Can't") and _gs.materials.has("mat_karkadann"), "and Enter refuses without spending it (%s)" % sc._message)
	sc.queue_free()
	await process_frame
	# no smith here
	_gs.world_location = "loc_tally_house"
	sc = load("res://scenes/forge_screen.tscn").instantiate()
	root.add_child(sc)
	await process_frame
	check(sc.rows()[0]["kind"] == "none" and sc.detail_text(sc.rows()[0]).contains("No master smith works here"), "away from a forge the screen says so")
	sc.queue_free()
	await process_frame

	# ---- the overworld
	_fresh()
	_gs.won_maps["map_f00"] = true
	var ow: Node2D = load("res://scenes/overworld.tscn").instantiate()
	ow.animate = false
	ow.launch_enabled = false
	root.add_child(ow)
	await process_frame
	check(not ow.open_forge() and ow.info_label.text.contains("No master smith works here"), "F at the tally house: no smith")
	ow.travel_to("loc_kaisareia_walls")
	check(ow.info_label.text.contains("A master smith works here: the edged master. Press F."), "at Kaisareia the panel points at the forge (%s)" % ow.info_label.text.replace("\n", " / "))
	check(ow.open_forge() and _gs.world_location == "loc_kaisareia_walls", "F opens it")
	ow.queue_free()
	await process_frame
	_fresh()
