extends SceneTree
## Headless checks for the second batch of weapons: Perun's Brand (a sword that reaches two tiles and
## strikes at RES), the Morningstar (an axe that reaches only two), the two legendary bows, the
## sacred texts (Miroslav Gospel renews, Zographos Codex is plain) and the grimoires (Astaroth drains,
## the Lemegeton takes blood), and where each is first found.
## Run from the repo root:
##   godot --headless --path game --script res://tests/test_new_weapons.gd
## Exits 0 if every check passes, 1 otherwise.

var _failures: int = 0
var _checks: int = 0
var _p: Node
var _gs: Node
var _eq: Node
var _canon: Node
var _forge: Node
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
	_forge = root.get_node("Forge")
	_combat = load("res://scripts/combat.gd")
	await process_frame
	await _run()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)

func _w(id: String) -> Dictionary:
	var r = _canon.find_by("weapons", "weapon_id", id)
	return r if r != null else {}

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
		"level": 5, "hp": 200, "str": 0, "mag": 0, "dex": 0, "spd": 0, "lck": 0, "def": 0, "res": 0, "affiliation": "state", "death_noun": "lance"}
	d.merge(over, true)
	return d

## Gives `uid` exactly this weapon, certified, and strong enough that every blow lands.
func _arm(uid: String, weapon_id: String) -> void:
	_p.state(uid)
	_gs.progression[uid]["level"] = 20
	_gs.progression[uid]["promoted"] = true
	_gs.inventories[uid] = [{"weapon_id": weapon_id, "uses": 30}]

func _unit_row(m: Node, uid: String) -> Dictionary:
	return m.units.filter(func(u): return u["punit_id"] == uid)[0]

func _run() -> void:
	# ---- canon: numbers, ranges, effects
	var pb := _w("wpn_perun_brand")
	check(pb["art"] == "sword" and pb["tier"] == "legendary" and pb["range_min"] == 1 and pb["range_max"] == 2 and pb["effect"] == "res_strike", "Perun's Brand: a legendary sword, range 1-2, res_strike")
	var ms := _w("wpn_morningstar")
	check(ms["art"] == "axe" and ms["tier"] == "mid" and ms["range_min"] == 2 and ms["range_max"] == 2, "the Morningstar is a mid axe weapon that reaches only two tiles")
	var vb := _w("wpn_vila_moonbow")
	check(vb["art"] == "bow" and vb["tier"] == "legendary" and vb["range_min"] == 2 and vb["range_max"] == 3 and vb["effective_vs"] == "flying", "Vila's Moonbow reaches three tiles and is effective against fliers")
	var nb := _w("wpn_neith_bow")
	check(nb["art"] == "bow" and nb["weight"] == 3 and nb["crit"] == 20 and nb["range_max"] == 2, "Neith's Bow is nearly weightless and crits often")
	check(_w("wpn_miroslav_gospel")["art"] == "faith" and _w("wpn_miroslav_gospel")["effect"] == "renew", "the Miroslav Gospel is a sacred text that renews")
	check(_w("wpn_zographos_codex")["art"] == "faith" and _w("wpn_zographos_codex")["effect"] == null and _w("wpn_zographos_codex")["might"] > _w("wpn_faith_high")["might"], "the Zographos Codex is plain and hits harder than a Silver Rite")
	check(_w("wpn_astaroth_goetia")["art"] == "reason" and _w("wpn_astaroth_goetia")["effect"] == "drain", "the Goetia of Astaroth is a grimoire that drains")
	check(_w("wpn_lemegeton")["art"] == "reason" and _w("wpn_lemegeton")["effect"] == "recoil" and _w("wpn_lemegeton")["might"] == 18, "the Lemegeton is the strongest book, with a price")
	check(_p.param("renew_heal") == 5 and _p.param("drain_pct") == 50 and _p.param("recoil_damage") == 3, "parameters: renew 5, drain 50%, recoil 3")
	# the forecast reads each special
	for id in ["wpn_perun_brand", "wpn_miroslav_gospel", "wpn_astaroth_goetia", "wpn_lemegeton"]:
		check(_forge.effect_text(_w(id)) != "", "%s has a line in the forecast" % id)
	check(_forge.effect_text(_w("wpn_astaroth_goetia")).contains("50%") and _forge.effect_text(_w("wpn_lemegeton")).contains("3 HP"), "...with its numbers")

	# ---- Perun's Brand strikes at RES
	var atk := {"str": 10, "mag": 0, "dex": 30, "spd": 10, "lck": 0}
	var armored := {"def": 20, "res": 0, "lck": 0, "spd": 0, "movement_type": "armor", "weapon_art": ""}
	var warded := {"def": 0, "res": 20, "lck": 0, "spd": 0, "movement_type": "infantry", "weapon_art": ""}
	var iron := _w("wpn_sword_basic")
	check(_combat.damage(atk, armored, pb, false) == 10 + 11 and _combat.damage(atk, warded, pb, false) == 10 + 11 - 20, "Perun's Brand ignores armor and meets RES (%d vs armor, %d vs ward)" % [_combat.damage(atk, armored, pb, false), _combat.damage(atk, warded, pb, false)])
	check(_combat.damage(atk, armored, iron, false) == 0 and _combat.damage(atk, warded, iron, false) == 10 + 5, "an Iron Sword is the opposite: DEF turns it, RES doesn't")
	check(_combat.damage({"str": 3, "mag": 20}, warded, _w("wpn_reason_basic"), false) == 5, "(magic arts are unchanged: mag 20 + might 5 against res 20)")

	# ---- ranges on the map
	_gs.reset()
	_arm("u_jost", "wpn_morningstar")
	var m: Node = await _map("map_d02", ["u_jost"], [Vector2i(8, 8)], [{"arch": _arch("Near"), "pos": Vector2i(9, 8)}])
	m.selected_unit_index = 0
	check(not _eq.equipped("u_jost").is_empty() and _eq.equipped("u_jost")["weapon_id"] == "wpn_morningstar", "Jost, an axe unit, can wield the Morningstar")
	m._attack_enemy()
	check(m.enemies[0].hp == 200 and m.info_label.text.contains("No enemy in range"), "an adjacent foe is out of reach for a two-tile weapon")
	m.enemies[0].pos = Vector2i(10, 8)
	m._attack_enemy()
	check(m.enemies[0].hp < 200, "...and one two tiles away is hit (hp %d)" % m.enemies[0].hp)
	check(not _combat.can_counter(ms, 1) and _combat.can_counter(ms, 2), "a Morningstar cannot answer a blow from next to it, and can at two")
	m.queue_free()
	await process_frame
	_gs.reset()
	_arm("u_tancred", "wpn_vila_moonbow")
	m = await _map("map_d02", ["u_tancred"], [Vector2i(5, 8)], [{"arch": _arch("Far"), "pos": Vector2i(8, 8)}])
	m.selected_unit_index = 0
	m._attack_enemy()
	check(m.enemies[0].hp < 200, "the Moonbow hits at three tiles (hp %d)" % m.enemies[0].hp)
	m.enemies[0].pos = Vector2i(6, 8)
	var hp_before: int = m.enemies[0].hp
	m._attack_enemy()
	check(m.enemies[0].hp == hp_before, "...and not adjacent")
	m.queue_free()
	await process_frame

	# ---- the three effects
	_gs.reset()
	_arm("u_maren", "wpn_miroslav_gospel")
	m = await _map("map_d02", ["u_maren"], [Vector2i(8, 8)], [{"arch": _arch("Dummy", {"def": 0, "res": 0}), "pos": Vector2i(9, 8)}])
	m.selected_unit_index = 0
	var maxhp: int = int(_unit_row(m, "u_maren")["hp"])
	m.unit_hp["u_maren"] = maxhp - 8
	m._attack_enemy()
	check(m.unit_hp["u_maren"] == maxhp - 3, "the Gospel's reader recovers 5 HP on a blow (hp %d of %d)" % [m.unit_hp["u_maren"], maxhp])
	check(m.info_label.text.contains("restores 5 HP"), "...and the line says so: %s" % m.info_label.text)
	m.unit_hp["u_maren"] = maxhp
	m.attacked_this_turn.clear()
	m._attack_enemy()
	check(m.unit_hp["u_maren"] == maxhp, "(a reader at full health gains nothing, and never goes over)")
	m.queue_free()
	await process_frame
	_gs.reset()
	_arm("u_emmerich", "wpn_astaroth_goetia")
	m = await _map("map_d02", ["u_emmerich"], [Vector2i(8, 8)], [{"arch": _arch("Dummy", {"def": 0, "res": 0}), "pos": Vector2i(9, 8)}])
	m.selected_unit_index = 0
	maxhp = int(_unit_row(m, "u_emmerich")["hp"])
	m.unit_hp["u_emmerich"] = 4
	var foe_before: int = m.enemies[0].hp
	m._attack_enemy()
	var dealt: int = foe_before - m.enemies[0].hp
	check(dealt > 0 and m.unit_hp["u_emmerich"] == mini(maxhp, 4 + int(floor(dealt * 0.5))), "the Goetia returns half of what it deals (dealt %d, hp 4 -> %d)" % [dealt, m.unit_hp["u_emmerich"]])
	check(m.info_label.text.contains("restores"), "...and says so")
	m.queue_free()
	await process_frame
	_gs.reset()
	_arm("u_emmerich", "wpn_lemegeton")
	m = await _map("map_d02", ["u_emmerich"], [Vector2i(8, 8)], [{"arch": _arch("Dummy", {"def": 0, "res": 0}), "pos": Vector2i(9, 8)}])
	m.selected_unit_index = 0
	maxhp = int(_unit_row(m, "u_emmerich")["hp"])
	m.unit_hp["u_emmerich"] = maxhp
	m._attack_enemy()
	check(m.unit_hp["u_emmerich"] == maxhp - 3 and m.info_label.text.contains("takes 3 HP"), "the Lemegeton takes 3 HP each time it is opened (hp %d)" % m.unit_hp["u_emmerich"])
	m.unit_hp["u_emmerich"] = 2
	m.attacked_this_turn.clear()
	m._attack_enemy()
	check(m.unit_hp["u_emmerich"] == 1, "...but never the last of it (hp %d)" % m.unit_hp["u_emmerich"])
	m.queue_free()
	await process_frame

	# ---- where each is found
	var drops := {"spn_d04_boss": "wpn_morningstar", "spn_a04_boss": "wpn_morningstar", "spn_x11_captain_east": "wpn_perun_brand", "spn_a08_boss": "wpn_vila_moonbow",
		"spn_d07_boss": "wpn_neith_bow", "spn_a09_boss": "wpn_miroslav_gospel", "spn_a02_boyan": "wpn_zographos_codex", "spn_k22_boss": "wpn_astaroth_goetia", "spn_pburiedworks_boss": "wpn_lemegeton"}
	for sid in drops:
		var row = _canon.find_by("encounter_spawns", "spawn_id", sid)
		check(row != null and row["drop_weapon_id"] == drops[sid], "%s drops %s" % [sid, drops[sid]])
	_gs.reset()
	var convoy_before: int = _eq.convoy().size()
	check(_eq.claim_drop("spn_a09_boss", "wpn_miroslav_gospel") == "Miroslav Gospel" and _eq.convoy().size() == convoy_before + 1, "taking the drop puts it in the convoy")
	check(_eq.claim_drop("spn_a09_boss", "wpn_miroslav_gospel") == "", "(once)")
	# certification still gates the legendary ones
	_p.state("u_maren")
	_gs.inventories["u_maren"] = []
	check(not _eq.can_wield("u_maren", "wpn_miroslav_gospel"), "an uncertified faith unit can't take a legendary text")
	_gs.progression["u_maren"]["promoted"] = true
	check(_eq.can_wield("u_maren", "wpn_miroslav_gospel") and _eq.can_wield("u_maren", "wpn_zographos_codex"), "a certified faith unit can take either")
	check(not _eq.can_wield("u_maren", "wpn_lemegeton") and not _eq.can_wield("u_maren", "wpn_morningstar"), "a faith unit can't read a grimoire or swing a flail")
