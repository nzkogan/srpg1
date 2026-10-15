extends SceneTree
## Headless checks for mounts and Named riding: who may ride, the stable, a mount's movement, the four
## Named mounts' mechanics (Simurgh heals, Shadhavar pulls, Karkadann charges, Anzu unmakes), taking a
## Named intact, capturing a mounted enemy, ordering a Warhorse, the fate of a fallen rider's mount.
## Run from the repo root:
##   godot --headless --path game --script res://tests/test_mounts.gd
## Exits 0 if every check passes, 1 otherwise.

var _failures: int = 0
var _checks: int = 0
var _p: Node
var _gs: Node
var _eq: Node
var _canon: Node
var _m: Node
var _f: Node
var _e: Node
var _combat: GDScript

func check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: ", label)

func _initialize() -> void:
	_p = root.get_node("Progression")
	_gs = root.get_node("GameState")
	_eq = root.get_node("Equipment")
	_canon = root.get_node("Canon")
	_m = root.get_node("Mounts")
	_f = root.get_node("Forge")
	_e = root.get_node("Epilogue")
	_combat = load("res://scripts/combat.gd")
	await process_frame
	await _run()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)

func _join(ids: Array, level := 10) -> void:
	for u in ids:
		_p.state(u)
		_gs.progression[u]["level"] = level

func _ride(uid: String, mount: String) -> void:
	_m.add_to_stable(mount)
	_m.assign(uid, mount)

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
	var d := {"enemy_id": "ea_t_" + name, "name": name, "weapon_art": "sword", "weapon_tier": "basic", "movement_type": "infantry",
		"level": 5, "hp": 200, "str": 0, "mag": 0, "dex": 0, "spd": 0, "lck": 0, "def": 0, "res": 0, "affiliation": "state", "death_noun": "lance"}
	d.merge(over, true)
	return d

func _select(m: Node, uid: String) -> void:
	m.selected_unit_index = m.units.find(m.units.filter(func(u): return u["punit_id"] == uid)[0])

func _row(m: Node, uid: String) -> Dictionary:
	return m.units.filter(func(u): return u["punit_id"] == uid)[0]

func _run() -> void:
	# ---- canon
	var ids: Array = _m.rows().map(func(r): return r["mount_id"])
	check(ids == ["mnt_warhorse", "mnt_simurgh", "mnt_shadhavar", "mnt_karkadann", "mnt_anzu"], "a Warhorse and four Named mounts (the Huma is none)")
	check(_m.row("mnt_warhorse")["requisition_cost"] == 400 and _m.row("mnt_simurgh")["movement"] == "flying" and _m.row("mnt_karkadann")["movement"] == "riding", "the warhorse costs 400; the Simurgh flies, the Karkadann rides")
	check(_p.param("capture_intact_hp_pct") == 25 and _p.param("mount_heal") == 5 and _p.param("charge_distance") == 3 and _p.param("charge_bonus") == 4, "parameters: intact at 25%, heal 5, charge 3 tiles for +4")

	# ---- who may ride
	_gs.reset()
	_join(["u_jost", "u_rinsa", "u_emmerich", "u_dietmar", "u_kheldar", "u_brandt"])
	check(_m.can_mount("u_jost", "mnt_warhorse")["ok"] and _m.can_mount("u_jost", "mnt_simurgh")["ok"], "an axe-wielding infantryman may take either kind")
	check(not _m.can_mount("u_rinsa", "mnt_warhorse")["ok"] and _m.can_mount("u_rinsa", "mnt_warhorse")["reason"].contains("brawling"), "no mounted brawler (a declared gap)")
	check(_m.can_mount("u_emmerich", "mnt_warhorse")["ok"] and not _m.can_mount("u_emmerich", "mnt_simurgh")["ok"] and _m.can_mount("u_emmerich", "mnt_simurgh")["reason"].contains("no reader has flown"), "a reader may ride but not fly (a declared gap)")
	check(not _m.can_mount("u_dietmar", "mnt_warhorse")["ok"], "a Paladin already rides")
	check(_m.can_mount("u_kheldar", "mnt_warhorse")["ok"], "a non-combatant may ride")
	check(not _m.can_mount("u_edda_not_joined", "mnt_warhorse")["ok"] and not _m.can_mount("u_jost", "mnt_nonsense")["ok"], "an unknown unit or mount is refused")

	# ---- the stable
	check(_m.stable().is_empty() and _m.mount_of("u_jost") == "", "an empty stable")
	check(not _m.assign("u_jost", "mnt_warhorse")["ok"] and _m.assign("u_jost", "mnt_warhorse")["reason"].contains("not in the stable"), "you cannot ride what you do not have")
	check(_m.add_to_stable("mnt_warhorse") and not _m.add_to_stable("mnt_nonsense") and _m.stable() == ["mnt_warhorse"], "a mount joins the stable")
	check(_m.assign("u_jost", "mnt_warhorse")["ok"] and _m.mount_of("u_jost") == "mnt_warhorse" and _m.stable().is_empty(), "Jost takes it; the stable is empty")
	check(_m.movement_for("u_jost", "infantry") == "riding" and _m.movement_for("u_brandt", "infantry") == "infantry" and _m.summary("u_jost") == "Warhorse (riding)", "he moves as riding; someone else does not")
	_m.add_to_stable("mnt_simurgh")
	check(_m.assign("u_jost", "mnt_simurgh")["ok"] and _m.mount_of("u_jost") == "mnt_simurgh" and _m.stable() == ["mnt_warhorse"], "taking another gives the old one back")
	check(_m.unassign("u_jost") and _m.stable().size() == 2 and not _m.unassign("u_jost"), "giving a mount up returns it (and a second time does nothing)")
	var json: Variant = _gs.restore(JSON.parse_string(JSON.stringify(_gs.to_dict())))
	check(_gs.validate(json) == "", "the stable is valid save data")

	# ---- a Named taken intact
	_gs.reset()
	check(_m.is_intact_capture(5, 20) and not _m.is_intact_capture(6, 20) and _m.is_intact_capture(1, 1000), "intact is at or below 25% of its HP")
	var line: String = _m.bond_named("nmd_simurgh")
	check(line.contains("joins the stable intact") and _m.stable() == ["mnt_simurgh"] and _m.bond_named("nmd_simurgh") == "", "the Simurgh bonds once, with a line")
	check(_m.bond_named("nmd_huma") == "" and _m.bond_named("nmd_nobody") == "", "the Huma cannot be bonded")

	# ---- a fallen rider's mount
	_gs.reset()
	_join(["u_jost"])
	_ride("u_jost", "mnt_warhorse")
	check(_m.on_rider_fell("u_jost", true).contains("goes back to the stable") and _m.stable() == ["mnt_warhorse"] and _m.mount_of("u_jost") == "", "a recovered mount comes home")
	_gs.reset()
	_join(["u_jost"])
	_ride("u_jost", "mnt_warhorse")
	check(_m.on_rider_fell("u_jost", false).contains("lost") and _m.stable().is_empty(), "an unrecovered one is lost")
	_m.bond_named("nmd_anzu")
	_join(["u_sigrun"])
	_m.assign("u_sigrun", "mnt_anzu")
	_m.on_rider_fell("u_sigrun", false)
	check(_m.bond_named("nmd_anzu") != "", "a lost Named goes back to the wild and can be won again")
	_gs.reset()
	_join(["u_jost"])
	_ride("u_jost", "mnt_warhorse")
	_e.note_fall("u_jost", "map_d01", {"type": "polity", "id": "pol_assembly", "noun": "lance", "who": "levy", "enemy_idx": 0})
	var out: Array[String] = _e.commit({"u_jost": "retrieved"})
	check(out.size() == 2 and out[1].contains("goes back to the stable") and _m.stable() == ["mnt_warhorse"], "the epilogue commit applies the weapon's fate to the mount: recovered")
	_ride("u_sigrun", "mnt_warhorse") if false else null
	_join(["u_sigrun"])
	_ride("u_sigrun", "mnt_warhorse")
	_e.note_fall("u_sigrun", "map_d01", {"type": "polity", "id": "pol_assembly", "noun": "lance", "who": "levy", "enemy_idx": 0})
	out = _e.commit({"u_sigrun": "lost_to_enemy"})
	check(out.size() == 2 and out[1].contains("lost") and _m.stable().size() == 1, "...or lost with the weapon")

	# ---- movement on the map
	_gs.reset()
	_join(["u_jost", "u_brandt"])
	_ride("u_jost", "mnt_warhorse")
	var m: Node = await _map("map_d02", ["u_jost", "u_brandt"], [Vector2i(8, 8), Vector2i(8, 10)])
	check(_row(m, "u_jost")["movement_type"] == "riding" and _row(m, "u_jost")["move"] == 9 and _row(m, "u_brandt")["movement_type"] == "infantry", "a rider moves as riding, nine tiles; a walker is unchanged")
	m.queue_free()
	await process_frame
	_gs.reset()
	_join(["u_jost"])
	_ride("u_jost", "mnt_simurgh")
	m = await _map("map_d02", ["u_jost"], [Vector2i(8, 8)])
	check(_row(m, "u_jost")["movement_type"] == "flying", "the Simurgh's rider flies")
	m.queue_free()
	await process_frame

	# ---- the Simurgh heals
	_gs.reset()
	_join(["u_jost", "u_brandt", "u_sigrun"])
	_ride("u_jost", "mnt_simurgh")
	m = await _map("map_d02", ["u_jost", "u_brandt", "u_sigrun"], [Vector2i(8, 8), Vector2i(8, 9), Vector2i(8, 11)])
	var jmax: int = int(_row(m, "u_jost")["hp"])
	var bmax: int = int(_row(m, "u_brandt")["hp"])
	m.unit_hp["u_jost"] = jmax - 8
	m.unit_hp["u_brandt"] = bmax - 3
	m.unit_hp["u_sigrun"] = 1
	m._next_turn()
	check(m.unit_hp["u_jost"] == jmax - 3 and m.unit_hp["u_brandt"] == bmax and m.unit_hp["u_sigrun"] == 1, "the rider recovers 5, the ally beside them is healed to full (not past it), a far ally is not")
	check(m.info_label.text.contains("The Simurgh restores 5 HP to Jost"), "...and the line says so: %s" % m.info_label.text.substr(0, 120))
	m.queue_free()
	await process_frame

	# ---- the Shadhavar pulls
	_gs.reset()
	_join(["u_jost"])
	_ride("u_jost", "mnt_shadhavar")
	m = await _map("map_d02", ["u_jost"], [Vector2i(8, 8)], [{"arch": _arch("Far", {"weapon_art": "none", "weapon_tier": "none"}), "pos": Vector2i(13, 8)},
		{"arch": _arch("Warden", {"weapon_art": "none", "weapon_tier": "none"}), "pos": Vector2i(8, 11), "kind": "boss"}])
	m.enemy_phase_enabled = true
	m._enemy_phase()
	check(m.enemies[0].pos == Vector2i(12, 8) and m.enemies[1].pos == Vector2i(8, 11), "each enemy phase the nearest foe is dragged a tile closer; a boss is not")
	check(m.enemy_log.any(func(l): return l.contains("Shadhavar's song drags the Far")), "...with a line")
	m.enemies[0].pos = Vector2i(9, 8)
	m._enemy_phase()
	check(m.enemies[0].pos == Vector2i(9, 8), "an enemy already adjacent is left alone")
	m.queue_free()
	await process_frame

	# ---- the Karkadann
	var iron: Dictionary = _canon.find_by("weapons", "weapon_id", "wpn_sword_basic")
	var horseman := {"movement_type": "riding", "def": 0, "res": 0, "lck": 0, "spd": 0, "weapon_art": ""}
	check(_combat.is_effective(iron, horseman, {"mount_effective_vs": ["riding"]}) and not _combat.is_effective(iron, horseman, {}), "a Karkadann rider's blows are effective against the mounted")
	check(_combat.damage({"str": 5, "charge_dmg": 4}, {"def": 0, "res": 0, "weapon_art": ""}, iron, false) == 5 + 5 + 4, "charge damage adds to a blow")
	_gs.reset()
	_join(["u_jost"])
	_ride("u_jost", "mnt_karkadann")
	m = await _map("map_d02", ["u_jost"], [Vector2i(8, 8)], [{"arch": _arch("Rider", {"movement_type": "riding", "hp": 400}), "pos": Vector2i(9, 8)}])
	_select(m, "u_jost")
	var c: Dictionary = m._combatant_for_unit("u_jost")
	check(c.get("mount_effective_vs", []) == ["riding"] and not c.has("charge_dmg"), "a Karkadann rider who has not moved gets effectiveness but no charge")
	m.move_cost["u_jost"] = 2
	check(not m._combatant_for_unit("u_jost").has("charge_dmg"), "two tiles is no charge")
	m.move_cost["u_jost"] = 3
	check(m._combatant_for_unit("u_jost")["charge_dmg"] == 4, "three tiles is a charge: +4")
	var hp_before: int = m.enemies[0].hp
	m.turn = 5
	m._attack_enemy()
	check(m.enemies[0].hp < hp_before and int(m.charge_stuck.get("u_jost", 0)) == 6 and m.info_label.text.contains("stuck next turn"), "attacking on the charge leaves the rider stuck next turn")
	m.turn = 6
	m.moved_this_turn.clear()
	m._try_move_to(Vector2i(8, 9))
	check(not m.moved_this_turn.has("u_jost") and m.info_label.text.contains("stuck"), "...and he cannot move then")
	var snap: Dictionary = m.capture_state()
	var back: Variant = _gs.restore(JSON.parse_string(JSON.stringify(snap)))
	m.charge_stuck.clear()
	m._restore_progress(back)
	check(int(m.charge_stuck.get("u_jost", 0)) == 6, "a suspension keeps the stuck rider")
	m.queue_free()
	await process_frame

	# ---- the Anzu
	_gs.reset()
	_join(["u_jost"])
	_ride("u_jost", "mnt_anzu")
	m = await _map("map_d02", ["u_jost"], [Vector2i(8, 8)], [{"arch": _arch("Worn", {"weapon_tier": "worn", "hp": 400}), "pos": Vector2i(9, 8)}])
	_select(m, "u_jost")
	m.units[0]["dex"] = 90
	m._attack_enemy()
	check(m.enemies[0].get("unarmed", false) and m.info_label.text.contains("unmakes"), "the Anzu's rider unmakes a worn weapon with an ordinary sword (%s)" % m.info_label.text.substr(0, 140))
	var convoy_before: int = _eq.convoy().size()
	m.enemies[0]["spawn_id"] = "spn_test_anzu"
	m.enemies[0]["drop"] = "wpn_axe_mid"
	m._defeat_enemy(m.enemies[0])
	check(_eq.convoy().size() == convoy_before, "an enemy it left unarmed drops nothing (the cost: your supply line)")
	m.queue_free()
	await process_frame
	_gs.reset()
	_join(["u_jost"])
	m = await _map("map_d02", ["u_jost"], [Vector2i(8, 8)], [{"arch": _arch("Worn", {"weapon_tier": "worn", "hp": 400}), "pos": Vector2i(9, 8)}])
	_select(m, "u_jost")
	m.units[0]["dex"] = 90
	m._attack_enemy()
	check(not m.enemies[0].get("unarmed", false), "(without the Anzu an ordinary sword does not unmake)")
	m.queue_free()
	await process_frame

	# ---- capturing: killed, harvested, intact
	var named_arch := _arch("The Karkadann", {"enemy_id": "ea_karkadann", "named_id": "nmd_karkadann", "hp": 100, "movement_type": "riding", "affiliation": "named"})
	for case in [[40, "harvest"], [25, "intact"]]:
		_gs.reset()
		_join(["u_gunnar"])
		m = await _map("map_d02", ["u_gunnar"], [Vector2i(8, 8)], [{"arch": named_arch, "pos": Vector2i(10, 8), "kind": "boss"}])
		_select(m, "u_gunnar")
		m.enemies[0].hp = case[0]
		m._capture_enemy()
		if case[1] == "harvest":
			check(m.enemies[0].defeated and _m.stable().is_empty() and _gs.materials.get("mat_karkadann") == "diminished", "a Named at 40% of its HP is harvested: a diminished material, no mount")
		else:
			check(m.enemies[0].defeated and _m.stable() == ["mnt_karkadann"] and not _gs.materials.has("mat_karkadann") and m.info_label.text.contains("joins the stable intact"), "a Named at 25% is taken INTACT: a mount, and no material")
		m.queue_free()
		await process_frame
	_gs.reset()
	_join(["u_gunnar"])
	m = await _map("map_d02", ["u_gunnar"], [Vector2i(8, 8)], [{"arch": named_arch, "pos": Vector2i(10, 8), "kind": "boss"}])
	_select(m, "u_gunnar")
	m.enemies[0].hp = 20
	_m.bond_named("nmd_karkadann")
	m._capture_enemy()
	check(_m.stable() == ["mnt_karkadann"] and _gs.materials.get("mat_karkadann") == "diminished", "(already bonded, the same capture falls back to a harvest)")
	m.queue_free()
	await process_frame
	# an ordinary cavalryman's horse
	_gs.reset()
	_join(["u_gunnar"])
	var rider := _arch("Lancer", {"movement_type": "riding", "hp": 10})
	m = await _map("map_d02", ["u_gunnar"], [Vector2i(8, 8)], [{"arch": rider, "pos": Vector2i(10, 8)}, {"arch": rider, "pos": Vector2i(8, 10)}])
	_select(m, "u_gunnar")
	m.enemies[0].hp = 5
	m._capture_enemy()
	check(m.enemies[0].defeated and _m.stable() == ["mnt_warhorse"] and m.info_label.text.contains("Warhorse joins the stable"), "capturing a mounted enemy brings its horse in")
	m.attacked_this_turn.clear()
	m.enemies[1].hp = 5
	m.unit_positions["u_gunnar"] = Vector2i(8, 8)
	m._capture_enemy()
	check(_m.stable() == ["mnt_warhorse"], "...but only one a map")
	m.queue_free()
	await process_frame
	_gs.reset()
	_join(["u_gunnar"])
	m = await _map("map_d02", ["u_gunnar"], [Vector2i(8, 8)], [{"arch": _arch("Footman", {"hp": 10}), "pos": Vector2i(10, 8)}])
	_select(m, "u_gunnar")
	m.enemies[0].hp = 5
	m._capture_enemy()
	check(m.enemies[0].defeated and _m.stable().is_empty(), "a man on foot has no horse")
	m.queue_free()
	await process_frame

	# ---- requisition: a Warhorse
	_gs.reset()
	_gs.gold = 1000
	_join(["u_jost"])
	check(_f.mount_offer()["mount_id"] == "mnt_warhorse" and _f.mount_offer()["cost"] == 400, "the standard forge breeds one kind of mount, at 400")
	var o: Dictionary = _f.order_mount("frg_standard_a")
	check(o["ok"] and _gs.gold == 600 and _gs.forge_orders.size() == 1 and _gs.forge_orders[0]["mount_id"] == "mnt_warhorse" and _f.order_name(_gs.forge_orders[0]) == "Warhorse", "it is ordered like a weapon, for 400")
	check(not _f.order_mount("frg_standard_a")["ok"] and _f.can_order_mount("frg_standard_a")["reason"].contains("allows 1 open order"), "it takes an order slot")
	check(not _f.can_order_mount("frg_kaisareia")["ok"], "a master has no mounts")
	var lines: Array[String] = _f.on_map_won(true)
	check(lines.size() == 1 and lines[0].contains("Warhorse") and _gs.forge_orders[0]["ready"], "one chapter later it is ready (%s)" % str(lines))
	var convoy_n: int = _eq.convoy().size()
	var c2: Dictionary = _f.collect(0)
	check(c2["ok"] and c2["mount_id"] == "mnt_warhorse" and _m.stable() == ["mnt_warhorse"] and _eq.convoy().size() == convoy_n and _gs.forge_orders.is_empty(), "collected into the stable, not the convoy")
	_gs.gold = 1000
	_f.orders_mode = true
	_gs.world_location = "loc_tally_house"
	var sc: Node = load("res://scenes/forge_screen.tscn").instantiate()
	root.add_child(sc)
	await process_frame
	var mrow := -1
	var rows: Array = sc.rows()
	for i in rows.size():
		if rows[i].get("mount_id", "") == "mnt_warhorse":
			mrow = i
	check(mrow >= 0 and sc.row_label(rows[mrow]) == "Order: Warhorse, a mount (400 gold)" and sc.detail_text(rows[mrow]).contains("Moves as riding"), "the requisitions screen lists it, with what it does")
	sc._index = mrow
	check(sc.activate() and _gs.gold == 600 and sc.rows()[0]["kind"] == "waiting" and sc.row_label(sc.rows()[0]).contains("In the forge: Warhorse"), "Enter orders it; it shows as in the forge")
	sc.queue_free()
	await process_frame

	# ---- the barracks
	_gs.reset()
	_join(["u_jost", "u_rinsa"])
	_m.add_to_stable("mnt_warhorse")
	var bs: Node = load("res://scenes/barracks_screen.tscn").instantiate()
	root.add_child(bs)
	await process_frame
	var ev := InputEventKey.new()
	ev.keycode = KEY_5
	ev.pressed = true
	bs._unhandled_input(ev)
	check(bs._mode == 4 and bs._title.text.contains("[Mount]"), "5 selects the Mount mode")
	bs._unit_index = bs.unit_ids.find("u_jost")
	bs._refresh()
	var opts: Array = bs.options()
	check(opts.size() == 1 and opts[0]["id"] == "mnt_warhorse" and not opts[0]["locked"] and bs.detail_text().contains("Enter gives it to Jost"), "Jost is offered the stabled Warhorse")
	bs._column = 1
	bs.activate()
	check(_m.mount_of("u_jost") == "mnt_warhorse" and bs._message.contains("takes") and bs._message.contains("Warhorse"), "Enter gives it to him")
	check(bs.options()[0]["id"] == "" and bs.options()[0]["data"]["name"].contains("give up"), "he is then offered the chance to give it up")
	bs.activate()
	check(_m.mount_of("u_jost") == "" and _m.stable() == ["mnt_warhorse"], "which he does")
	bs._unit_index = bs.unit_ids.find("u_rinsa")
	bs._column = 0
	bs._refresh()
	check(bs.options()[0]["locked"] and bs.detail_text().contains("no mounted brawling"), "Rinsa is shown the mount, locked, with the reason")
	bs._column = 1
	bs.activate()
	check(_m.mount_of("u_rinsa") == "" and bs._message.contains("Can't"), "and cannot take it")
	bs.queue_free()
	await process_frame
