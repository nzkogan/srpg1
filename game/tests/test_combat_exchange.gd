extends SceneTree
## Headless checks for combat.gd's overlap-weapon rules, attack speed and
## doubling, effectiveness, forecast and resolve_exchange.
## Run from the repo root:
##   godot --headless --path game --script res://tests/test_combat_exchange.gd
## Exits 0 if every check passes, 1 otherwise.

var _failures: int = 0
var _checks: int = 0
var _combat: GDScript
var _w: Dictionary = {}   # weapon_id -> real weapons row

func check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: ", label)

func _initialize() -> void:
	_combat = load("res://scripts/combat.gd")
	await process_frame
	for row in root.get_node("Canon").get_table("weapons"):
		_w[row["weapon_id"]] = row
	_proficiency()
	_triangle_and_effective()
	_speed()
	_forecast()
	_exchange()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)

func _fighter(over := {}) -> Dictionary:
	var d := {"str": 8, "mag": 6, "dex": 8, "spd": 8, "lck": 4, "def": 4, "res": 3, "movement_type": "infantry"}
	d.merge(over, true)
	return d

func _proficiency() -> void:
	var halberd: Dictionary = _w["wpn_halberd"]
	check(_combat.required_arts(halberd) == ["axe", "lance"], "halberd requires axe and lance")
	check(_combat.required_arts(_w["wpn_sword_basic"]) == ["sword"], "a plain sword requires just its own art")
	check(_combat.is_hybrid(halberd) and not _combat.is_hybrid(_w["wpn_axe_basic"]), "halberd is an overlap weapon, an axe is not")
	check(_combat.can_wield(["axe", "lance"], halberd), "axe+lance can wield a halberd")
	check(_combat.can_wield(["lance", "axe", "faith"], halberd), "order and extra arts don't matter")
	check(not _combat.can_wield(["axe"], halberd), "axe alone cannot")
	check(not _combat.can_wield(["lance"], halberd), "lance alone cannot")
	check(not _combat.can_wield([], halberd), "no arts cannot")
	check(_combat.can_wield(["reason", "faith"], _w["wpn_censer"]) and not _combat.can_wield(["reason"], _w["wpn_censer"]), "censer needs reason AND faith")
	check(_combat.can_wield(["sword"], _w["wpn_sword_basic"]) and not _combat.can_wield(["axe"], _w["wpn_sword_basic"]), "single-art weapons unchanged")
	# the real classes: only the drafted billman has the halberd's pair
	var canon: Node = root.get_node("Canon")
	var wielders: Array = []
	for c in canon.get_table("classes"):
		var arts: Array = []
		for k in ["art_primary", "art_secondary"]:
			if ["sword", "lance", "axe", "bow", "brawl", "reason", "faith"].has(c[k]):
				arts.append(c[k])
		if _combat.can_wield(arts, halberd):
			wielders.append(c["class_id"])
	check(wielders == ["cls_billman"], "exactly one class can wield the halberd: %s" % str(wielders))

func _triangle_and_effective() -> void:
	var halberd: Dictionary = _w["wpn_halberd"]
	var sword: Dictionary = _w["wpn_sword_basic"]
	var axe: Dictionary = _w["wpn_axe_basic"]
	check(_combat.triangle_art(halberd) == "hybrid" and _combat.triangle_art(axe) == "axe", "hybrid reads as 'hybrid' to the triangle")
	var a := _fighter()
	var fa: Dictionary = _combat.forecast(a, _fighter(), sword, halberd, 1)
	check(fa["atk"]["triangle"] == 0 and fa["def"]["triangle"] == 0, "sword vs halberd: neutral both ways")
	var fb: Dictionary = _combat.forecast(a, _fighter(), axe, halberd, 1)
	check(fb["atk"]["triangle"] == 0 and fb["def"]["triangle"] == 0, "axe vs halberd: neutral both ways")
	var fc: Dictionary = _combat.forecast(a, _fighter(), halberd, _w["wpn_lance_basic"], 1)
	check(fc["atk"]["triangle"] == 0 and fc["def"]["triangle"] == 0, "halberd vs lance: neutral both ways")
	var fd: Dictionary = _combat.forecast(a, _fighter(), sword, _w["wpn_axe_basic"], 1)
	check(fd["atk"]["triangle"] == 1 and fd["def"]["triangle"] == -1, "sword vs axe still favours the sword (green/red source)")
	# effectiveness: exact numbers
	var rider := _fighter({"movement_type": "riding", "def": 4})
	var foot := _fighter({"def": 4})
	var user := _fighter({"str": 10})
	var vs_rider: int = _combat.damage(user, rider.merged({"weapon_art": "hybrid"}), halberd, false)
	var vs_foot: int = _combat.damage(user, foot.merged({"weapon_art": "hybrid"}), halberd, false)
	check(vs_foot == 10 + 9 - 4, "halberd vs infantry: str 10 + might 9 - def 4 = 15 (got %d)" % vs_foot)
	check(vs_rider == 10 + 9 * 2 - 4, "halberd vs riding: might doubles -> 24 (got %d)" % vs_rider)
	check(_combat.is_effective(halberd, rider) and not _combat.is_effective(halberd, foot), "is_effective keys off movement_type")
	check(_combat.is_effective(_w["wpn_maul"], _fighter({"movement_type": "armor"})) and not _combat.is_effective(_w["wpn_maul"], rider), "maul is effective vs armor, not riding")
	check(not _combat.is_effective(_w["wpn_censer"], rider), "censer has no effectiveness")
	check(_combat.forecast(user, rider, halberd, sword, 1)["atk"]["effective"], "forecast flags the effective attack")
	check(not _combat.forecast(user, foot, halberd, sword, 1)["atk"]["effective"], "and not the ordinary one")
	# magic damage reads mag/res
	var caster := _fighter({"mag": 9, "res": 5})
	check(_combat.damage(caster, _fighter({"res": 2}), _w["wpn_censer"], false) == 9 + 9 - 2, "censer is magic: mag + might - res")

func _speed() -> void:
	var halberd: Dictionary = _w["wpn_halberd"]     # weight 12
	var sword: Dictionary = _w["wpn_sword_basic"]   # weight 5
	var steel: Dictionary = _w["wpn_sword_mid"]     # weight 8
	check(_combat.attack_speed(_fighter({"str": 8, "spd": 8}), sword) == 8, "a weapon lighter than str costs no speed")
	check(_combat.attack_speed(_fighter({"str": 5, "spd": 8}), sword) == 8, "weight equal to str costs nothing")
	check(_combat.attack_speed(_fighter({"str": 5, "spd": 8}), steel) == 5, "weight 8 vs str 5 costs 3")
	check(_combat.attack_speed(_fighter({"str": 7, "spd": 8}), halberd) == 3, "halberd (12) vs str 7 costs 5: speed 8 -> 3")
	check(_combat.attack_speed(_fighter({"str": 13, "spd": 14}), halberd) == 14, "a strong wielder shrugs the weight off")
	check(_combat.attack_speed(_fighter({"str": 2, "mag": 9, "spd": 8}), _w["wpn_censer"]) == 8, "magic weapons burden against mag, not str")
	check(_combat.attack_speed(_fighter({"str": 12, "mag": 3, "spd": 8}), _w["wpn_censer"]) == 4, "...so a low-mag caster is slowed (weight 7 vs mag 3)")

func _forecast() -> void:
	var sword: Dictionary = _w["wpn_sword_basic"]
	var bow: Dictionary = _w["wpn_bow_basic"]
	var fast := _fighter({"spd": 12})
	var slow := _fighter({"spd": 8})
	var f: Dictionary = _combat.forecast(fast, slow, sword, sword, 1)
	check(f["atk"]["hits"] == 2 and f["def"]["hits"] == 1, "+4 speed doubles the attacker")
	f = _combat.forecast(_fighter({"spd": 11}), slow, sword, sword, 1)
	check(f["atk"]["hits"] == 1, "+3 speed does not")
	f = _combat.forecast(slow, fast, sword, sword, 1)
	check(f["def"]["hits"] == 2 and f["atk"]["hits"] == 1, "a faster defender doubles on the counter")
	check(f["atk"]["speed"] == 8 and f["def"]["speed"] == 12, "both speeds are reported")
	# counters and range
	f = _combat.forecast(fast, slow, sword, bow, 1)
	check(f["def"].is_empty(), "a bow can't counter at range 1 (range 2 only)")
	check(f["atk"]["hits"] == 2, "...but the attacker still doubles on speed alone")
	f = _combat.forecast(fast, slow, bow, sword, 2)
	check(f["def"].is_empty(), "a sword can't counter an archer at range 2")
	f = _combat.forecast(fast, slow, bow, bow, 2)
	check(not f["def"].is_empty(), "two archers at range 2 trade blows")
	check(_combat.forecast(fast, slow, sword, {}, 1)["def"].is_empty(), "an unarmed defender never counters")
	check(_combat.forecast(fast, _fighter({"spd": 8}), sword, {}, 1)["atk"]["hits"] == 2, "...and gets doubled by a fast attacker (unarmed uses spd)")
	check(_combat.can_counter(_w["wpn_censer"], 1) and _combat.can_counter(_w["wpn_censer"], 2) and not _combat.can_counter(_w["wpn_censer"], 3), "censer answers at 1-2 only")
	# numbers match the single-purpose functions
	var a := _fighter({"sup_hit": 5})
	var d := _fighter()
	f = _combat.forecast(a, d, sword, sword, 1)
	check(f["atk"]["hit"] == _combat.hit_chance(a.merged({}), d.merged({"weapon_art": "sword"}), sword), "forecast hit == hit_chance (incl. support keys)")
	check(f["atk"]["crit"] == _combat.crit_chance(a, d, sword), "forecast crit == crit_chance")
	check(f["atk"]["crit_damage"] > f["atk"]["damage"], "a crit hurts more")

func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r

func _exchange() -> void:
	var sword: Dictionary = _w["wpn_sword_basic"]
	# a sure thing both ways: huge hit, no crits (def 0 lck to keep crit near 0 is not needed, damage fixed by hp)
	var a := _fighter({"sup_hit": 500, "spd": 8, "str": 8})
	var d := _fighter({"sup_hit": 500, "spd": 8, "str": 8})
	var r: Dictionary = _combat.resolve_exchange(a, d, sword, sword, 1, _rng(1), 30, 30)
	check(r["strikes"].size() == 2 and r["strikes"][0]["by"] == "atk" and r["strikes"][1]["by"] == "def", "even speed: attack, then counter")
	check(r["def_hp"] < 30 and r["atk_hp"] < 30, "both fighters took damage")
	check(r["strikes"][0]["target_hp"] == r["def_hp"] and r["strikes"][1]["target_hp"] == r["atk_hp"], "each strike records the target's hp after it")
	# attacker doubles: A D A
	var fast := _fighter({"sup_hit": 500, "spd": 14})
	r = _combat.resolve_exchange(fast, d, sword, sword, 1, _rng(2), 40, 40)
	check(r["strikes"].map(func(s): return s["by"]) == ["atk", "def", "atk"], "attacker doubling: A, D, A")
	# defender doubles: A D D
	r = _combat.resolve_exchange(d, fast.merged({"sup_hit": 500}), sword, sword, 1, _rng(3), 40, 40)
	check(r["strikes"].map(func(s): return s["by"]) == ["atk", "def", "def"], "defender doubling: A, D, D")
	# a kill stops everything: the dead don't counter
	r = _combat.resolve_exchange(a, d, sword, sword, 1, _rng(4), 30, 1)
	check(r["strikes"].size() == 1 and r["def_hp"] == 0 and r["atk_hp"] == 30, "killing blow: no counter, hp never below 0")
	# a counter can kill the attacker, ending the doubling
	r = _combat.resolve_exchange(fast, d, sword, sword, 1, _rng(5), 1, 40)
	check(r["strikes"].map(func(s): return s["by"]) == ["atk", "def"] and r["atk_hp"] == 0, "the counter kills the attacker before the follow-up")
	# out-of-range defender never strikes
	r = _combat.resolve_exchange(a, d, sword, _w["wpn_bow_basic"], 1, _rng(6), 30, 30)
	check(r["strikes"].size() == 1, "an archer too close doesn't counter")
	# misses do no damage and keep going
	var blind := _fighter({"sup_hit": -500})
	r = _combat.resolve_exchange(blind, d, sword, sword, 1, _rng(7), 30, 30)
	check(not r["strikes"][0]["hit"] and r["def_hp"] == 30, "a miss does no damage")
	# deterministic for a seed
	var r1: Dictionary = _combat.resolve_exchange(a, d, sword, sword, 1, _rng(99), 30, 30)
	var r2: Dictionary = _combat.resolve_exchange(a, d, sword, sword, 1, _rng(99), 30, 30)
	check(r1 == r2, "same seed, same exchange")
