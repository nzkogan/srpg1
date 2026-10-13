extends SceneTree
## Headless checks for the mythic weapon tier: the might ladder (worn < basic < mid < high < legendary < mythic),
## paragon-only wielding, one mythic weapon for every art that a paragon class can use, and
## bosses that drop more than one weapon.
## Run from the repo root:
##   godot --headless --path game --script res://tests/test_mythic.gd
## Exits 0 if every check passes, 1 otherwise.

var _failures: int = 0
var _checks: int = 0
var _p: Node
var _gs: Node
var _eq: Node
var _canon: Node
var _forge: Node

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
	await process_frame
	_run()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)

func _run() -> void:
	# ---- the ladder
	var band := {}
	for w in _canon.get_table("weapons"):
		if not str(w.get("weapon_id", "")).begins_with("wpn_"):
			continue
		var lo_hi: Array = band.get(w["tier"], [999, -1])
		band[w["tier"]] = [mini(lo_hi[0], int(w["might"])), maxi(lo_hi[1], int(w["might"]))]
	var order := ["worn", "basic", "mid", "high", "legendary", "mythic"]
	for i in range(1, order.size()):
		check(band[order[i]][0] > band[order[i - 1]][1], "every %s weapon out-hits every %s one (%s vs %s)" % [order[i], order[i - 1], str(band[order[i]]), str(band[order[i - 1]])])
	check(band["high"][1] == 13 and band["legendary"][0] >= 15 and band["legendary"][1] <= 17, "Silver is 13; the legendary band is 15-17")
	check(band["mythic"][0] >= 18 and band["mythic"][1] <= 21 and band["mythic"][1] == 21, "the mythic band is 18-21")

	# ---- one mythic weapon per art
	var myth: Dictionary = {}
	for w in _canon.get_table("weapons"):
		if w.get("tier") == "mythic":
			myth[w["art"]] = w
	check(myth.keys().size() == 7 and ["sword", "lance", "axe", "bow", "brawl", "reason", "faith"].all(func(a): return myth.has(a)), "a mythic weapon for every art")
	check(myth["sword"]["name"] == "Marko's Claymore" and myth["sword"]["might"] == 19 and myth["sword"]["weight"] == 16, "the claymore: might 19, weight 16")
	check(myth["axe"]["might"] == 21 and myth["axe"]["weight"] == 18, "the heaviest hitter is the Svarog's Cleaver")
	check(myth["bow"]["range_min"] == 2 and myth["bow"]["range_max"] == 3 and myth["lance"]["effective_vs"] == "flying", "Rostam's bow reaches 3; Saint George's Spear brings down fliers")
	check(myth["faith"]["effect"] == "heal_allies" and myth["reason"]["effect"] == "recoil", "the Enoch heals allies; the Lemegeton takes blood")
	for art in myth:
		var w: Dictionary = myth[art]
		var wielders := 0
		for c in _canon.get_table("classes"):
			if c.get("tier") == "paragon" and (c["art_primary"] == art or c["art_secondary"] == art):
				wielders += 1
		check(wielders > 0, "%s has a paragon class that can wield it" % w["name"])

	# ---- paragon-only
	_gs.reset()
	_p.state("u_sigrun")
	_gs.progression["u_sigrun"]["level"] = 30
	var claymore := "wpn_marko_claymore"
	check(not _p.can_use_tier("u_sigrun", "mythic") and not _eq.can_wield("u_sigrun", claymore), "an uncertified swordsman can't lift the claymore")
	_gs.progression["u_sigrun"]["promoted"] = true
	_gs.progression["u_sigrun"]["class_id"] = "cls_swordmaster"
	check(_p.can_use_tier("u_sigrun", "legendary") and not _p.can_use_tier("u_sigrun", "mythic") and not _eq.can_wield("u_sigrun", claymore), "a certified one can use a legendary weapon, not a mythic one")
	_gs.progression["u_sigrun"]["paragon"] = true
	_gs.progression["u_sigrun"]["class_id"] = "cls_fianna"
	check(_p.can_use_tier("u_sigrun", "mythic") and _eq.can_wield("u_sigrun", claymore), "a paragon swordsman can")
	check(_eq.can_wield("u_sigrun", "wpn_rostam_bow") and not _eq.can_wield("u_sigrun", "wpn_svarog_cleaver"), "(the Fianna has the bow too, but not the axe)")
	check(_p.can_use_tier("u_sigrun", "high") and _p.can_use_tier("u_sigrun", "basic"), "(and the lower tiers stay open)")
	_p.state("u_jost")
	_gs.progression["u_jost"]["promoted"] = true
	_gs.progression["u_jost"]["class_id"] = "cls_jaguar_knight"
	check(_p.is_paragon("u_jost") and _p.can_use_tier("u_jost", "mythic") and _eq.can_wield("u_jost", "wpn_svarog_cleaver"), "a unit whose class is itself a paragon class (the Jaguar knight) needs no flag")

	# ---- where they are found
	var drops := {"spn_rf20_boss": "wpn_sword_high|wpn_marko_claymore", "spn_hw3_boss": "wpn_axe_high|wpn_stgeorge_spear", "spn_k21_boss": "wpn_axe_high|wpn_svarog_cleaver",
		"spn_pmacuil_boss": "wpn_axe_high|wpn_rostam_bow", "spn_pindech_boss": "wpn_axe_high|wpn_svyatogor_grip", "spn_tp19_boss": "wpn_lance_high|wpn_slavonic_enoch", "spn_k22_boss": "wpn_lemegeton"}
	for sid in drops:
		var row = _canon.find_by("encounter_spawns", "spawn_id", sid)
		check(row != null and row["drop_weapon_id"] == drops[sid], "%s drops %s" % [sid, drops[sid]])
	_gs.reset()
	var before: int = _eq.convoy().size()
	var got: String = _eq.claim_drop("spn_k21_boss", "wpn_axe_high|wpn_svarog_cleaver")
	check(got == "Silver Axe, Svarog's Cleaver" and _eq.convoy().size() == before + 2, "a boss that carries two weapons drops both (%s)" % got)
	check(_eq.claim_drop("spn_k21_boss", "wpn_axe_high|wpn_svarog_cleaver") == "" and _eq.convoy().size() == before + 2, "(once)")
	check(_eq.claim_drop("spn_x", "wpn_nonsense|wpn_axe_high") == "Silver Axe", "an unknown id in the list is skipped, the rest still drop")
	check(_eq.claim_drop("spn_y", "wpn_nonsense") == "" and not _gs.drops_claimed.has("spn_y"), "a drop of nothing real is not counted as claimed")
	check(_forge.hits_to_unmake("mythic") == 6, "(the unmaking scale knows the new tier)")
