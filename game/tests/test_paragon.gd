extends SceneTree
## Headless checks for the paragon tier in Progression: deeds, requirements,
## class options by art, fees, the jump/growth/slots, personal milestones, the
## shadow line, and the Tzitzimitl unlock.
## Run from the repo root:
##   godot --headless --path game --script res://tests/test_paragon.gd
## Exits 0 if every check passes, 1 otherwise.

var _failures: int = 0
var _checks: int = 0
var _p: Node
var _gs: Node
var _eq: Node

func check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: ", label)

func _reset() -> void:
	_gs.progression.clear(); _gs.gold = 0; _gs.unlocked_classes.clear(); _gs.income_claimed.clear()
	_gs.inventories.clear(); _gs.convoy.clear(); _gs.equipment_ready = false; _gs.drops_claimed.clear()
	_gs.deeds.clear(); _gs.won_maps.clear()

func _total(d: Dictionary) -> int:
	var n := 0
	for k in d:
		n += int(d[k])
	return n

## A certified unit at the given level (bypassing the first-tier fee).
func _certified(uid: String, class_id: String, level: int) -> void:
	_p.state(uid)
	var st: Dictionary = _gs.progression[uid]
	st["level"] = level
	_gs.gold = 100000
	if not st["promoted"]:
		_p.promote(uid, class_id)
	_gs.gold = 0
	st["level"] = level

func _names(opts: Array) -> Array:
	var out: Array = []
	for o in opts:
		out.append(o["name"])
	return out

func _initialize() -> void:
	_p = root.get_node("Progression")
	_gs = root.get_node("GameState")
	_eq = root.get_node("Equipment")
	await process_frame
	_reset(); _deeds()
	_reset(); _requirements()
	_reset(); _options()
	_reset(); _taking_it()
	_reset(); _special_lines()
	_reset()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)

func _deeds() -> void:
	var gating: Array = []
	for row in _p.gating_epithets():
		gating.append(row["epithet_id"])
	check(gating == ["ep_bosskill", "ep_solohold", "ep_nohit", "ep_capture"], "canon: four deeds gate paragon (%s)" % str(gating))
	check(_p.is_tracked("ep_bosskill") and _p.is_tracked("ep_solohold") and _p.is_tracked("ep_nohit"), "boss kill, solo hold and no-hit are recorded")
	check(_p.is_tracked("ep_capture") and not _p.is_tracked("ep_talk") and not _p.is_tracked("ep_nonesuch"), "capture is recordable now; talk isn't (and unknown ones aren't)")
	check(_p.deeds("u_jost").is_empty() and not _p.has_deed("u_jost", "ep_nohit"), "no deeds to start")
	check(_p.record_deed("u_jost", "ep_nohit") == true, "the first time a deed is earned it says so")
	check(_p.record_deed("u_jost", "ep_nohit") == false and _p.deeds("u_jost")["ep_nohit"] == 2, "repeats count but aren't 'new'")
	check(not _p.record_deed("u_nobody", "ep_nohit") and not _p.record_deed("u_jost", "ep_nonesuch") and not _p.record_deed("u_jost", "ep_nohit", 0), "unknown unit, epithet or count: refused")
	check(_p.gating_deeds_earned("u_jost") == ["ep_nohit"], "gating deeds earned: just the one")
	_p.record_deed("u_jost", "ep_talk")
	check(_p.gating_deeds_earned("u_jost") == ["ep_nohit"] and _p.has_deed("u_jost", "ep_talk"), "a non-gating deed is kept but doesn't count toward paragon")
	_p.deeds("u_jost")["ep_nohit"] = 99
	check(_p.deeds("u_jost")["ep_nohit"] == 2, "deeds() returns a copy")
	check(_gs.deeds.has("u_jost"), "deeds live in GameState")

func _requirements() -> void:
	_p.state("u_jost")
	var req: Array = _p.paragon_requirements("u_jost")
	check(req.size() == 4 and not req[0]["ok"] and not req[1]["ok"] and not req[2]["ok"] and not req[3]["ok"], "a fresh trained unit meets none of the four requirements")
	check(req[1]["label"] == "Level 30" and req[2]["label"] == "1 deed that gates paragon", "requirement labels read well (%s / %s)" % [req[1]["label"], req[2]["label"]])
	check(_p.paragon_fee(30) == 1000 and _p.paragon_fee(31) == 1150 and _p.paragon_fee(40) == 2500 and _p.paragon_fee(5) == 1000, "paragon fee: 1000 at 30, +150 a level after, never below base")
	check(_p.paragon_options("u_jost").is_empty(), "an uncertified unit has no paragon options")
	var r: Dictionary = _p.take_paragon("u_jost", "cls_jaguar_knight")
	check(not r["ok"] and r["reason"] == "certify first", "uncertified: 'certify first'")
	# build up the requirements one at a time on a certified Jost
	_certified("u_jost", "cls_warrior", 20)
	r = _p.take_paragon("u_jost", "cls_jaguar_knight")
	check(not r["ok"] and r["reason"] == "needs level 30", "level 20: 'needs level 30'")
	_gs.progression["u_jost"]["level"] = 30
	r = _p.take_paragon("u_jost", "cls_jaguar_knight")
	check(not r["ok"] and r["reason"] == "needs a deed that gates paragon", "level 30 without a deed: refused")
	_p.record_deed("u_jost", "ep_talk")
	check(not _p.take_paragon("u_jost", "cls_jaguar_knight")["ok"], "a non-gating deed doesn't unlock it")
	_p.record_deed("u_jost", "ep_solohold")
	r = _p.take_paragon("u_jost", "cls_jaguar_knight")
	check(not r["ok"] and r["reason"] == "needs 1000 gold (have 0)", "deed earned, no gold: 'needs 1000 gold'")
	var req2: Array = _p.paragon_requirements("u_jost")
	check(req2[0]["ok"] and req2[1]["ok"] and req2[2]["ok"] and not req2[3]["ok"], "the checklist shows exactly what is left (only gold)")
	_gs.gold = 999
	check(not _p.take_paragon("u_jost", "cls_jaguar_knight")["ok"], "999 gold is not enough")
	check(_gs.gold == 999 and _p.class_id_of("u_jost") == "cls_warrior" and not _p.is_paragon("u_jost"), "refusals charge and change nothing")
	check(not _p.take_paragon("u_jost", "cls_swordmaster")["ok"], "an order class isn't a paragon option")

func _options() -> void:
	_certified("u_jost", "cls_warrior", 30)
	check(_names(_p.paragon_options("u_jost")) == ["Jaguar knight", "Eagle knight"], "an axe unit sees both axe paragons (%s)" % str(_names(_p.paragon_options("u_jost"))))
	_certified("u_ricberta", "cls_general", 30)
	check(_names(_p.paragon_options("u_ricberta")) == ["Bogatyr"], "a lance unit sees the Bogatyr")
	_certified("u_sigrun", "cls_swordmaster", 30)
	check(_names(_p.paragon_options("u_sigrun")) == ["Fianna"], "a sword unit sees the Fianna (sword+bow)")
	_certified("u_tancred", "cls_sniper", 30)
	check(_names(_p.paragon_options("u_tancred")) == ["Donso"], "a bow unit sees the Donso, not the Fianna (its primary art is sword)")
	_certified("u_rinsa", "cls_grappler", 30)
	check(_names(_p.paragon_options("u_rinsa")) == ["Toa"], "a brawl unit sees the Toa")
	_certified("u_emmerich", "cls_warlock", 30)
	var tz: Array = _p.paragon_options("u_emmerich")
	check(_names(tz) == ["Tzitzimitl"] and tz[0]["locked"] and tz[0]["reason"].contains("Mountain Above the Lake"), "a reason unit sees the Tzitzimitl, locked behind the Simurgh paralogue (%s)" % str(tz))
	_certified("u_maren", "cls_bishop", 30)
	check(_p.paragon_options("u_maren").is_empty(), "faith has no paragon class (a canon gap, not invented)")
	_gs.gold = 5000
	_p.record_deed("u_maren", "ep_nohit")
	check(not _p.take_paragon("u_maren", "cls_bishop")["ok"] and _p.take_paragon("u_maren", "cls_bishop")["reason"] == "not a paragon class this unit can take", "...so a faith unit is refused cleanly")
	# hybrids count both arts: a Billman (axe+lance) sees axe AND lance paragons
	_reset(); _gs.gold = 100000
	_p.state("u_jost"); _gs.progression["u_jost"]["level"] = 15
	_p.on_map_won("map_tp19")
	_p.promote("u_jost", "cls_billman")
	_gs.progression["u_jost"]["level"] = 30
	check(_names(_p.paragon_options("u_jost")) == ["Bogatyr", "Jaguar knight", "Eagle knight"], "a Billman sees paragons for both its arts (%s)" % str(_names(_p.paragon_options("u_jost"))))
	# natives: Dietmar and Torvald are already certified
	_reset()
	_p.state("u_dietmar"); _gs.progression["u_dietmar"]["level"] = 30
	check(_names(_p.paragon_options("u_dietmar")) == ["Bogatyr"], "Dietmar (a Paladin, lance) is eligible without any first-tier step")
	_p.state("u_torvald")
	check(_names(_p.paragon_options("u_torvald")) == ["Jaguar knight", "Eagle knight"], "Torvald (axe knight) sees the axe paragons")

func _taking_it() -> void:
	_certified("u_jost", "cls_warrior", 30)
	_p.record_deed("u_jost", "ep_bosskill")
	_gs.gold = 5000
	var before: Dictionary = _p.stats_for("u_jost")
	var slots_before: int = _p.slots("u_jost")
	var rate_before: int = _p.growth_rate("u_jost", "str")
	var level_before: int = _p.level("u_jost")
	var preview: Dictionary = _p.preview_paragon("u_jost", "cls_eagle_knight")
	check(_p.stats_for("u_jost") == before, "previewing changes nothing")
	var r: Dictionary = _p.take_paragon("u_jost", "cls_eagle_knight")
	check(r["ok"] and r["fee"] == 1000 and _gs.gold == 4000, "taking it at level 30 costs 1000")
	check(_p.is_paragon("u_jost") and _p.class_id_of("u_jost") == "cls_eagle_knight" and _p.class_tier("u_jost") == "paragon", "he is an Eagle knight, paragon tier")
	check(_p.level("u_jost") == level_before, "no level reset")
	check(_p.stats_for("u_jost") == preview, "the preview equals the real result")
	var after: Dictionary = _p.stats_for("u_jost")
	check(_total(after) - _total(before) == 30, "total change = the +30 jump (the flying shape is zero-sum)")
	check(_p.growth_rate("u_jost", "str") == rate_before + 5, "growth +5 more")
	check(_p.slots("u_jost") == slots_before + 1, "+1 ability slot")
	check(_p.chosen("u_jost")[0] == "ab_stun", "Stun, the Eagle knight's signature, leads his kit")
	check(not _p.take_paragon("u_jost", "cls_jaguar_knight")["ok"] and _p.take_paragon("u_jost", "cls_jaguar_knight")["reason"] == "already paragon", "no second paragon")
	check(_p.paragon_options("u_jost").is_empty() and _p.recertify_options("u_jost").is_empty() and _p.promotion_options("u_jost").is_empty(), "nothing further to take or switch to")
	check(_eq.unit_arts("u_jost") == ["axe"], "an Eagle knight's arts: axe (the class has no second art)")
	# later is dearer: level 34 pays 1600
	_reset(); _gs.gold = 5000
	_certified("u_jost", "cls_warrior", 34)
	_p.record_deed("u_jost", "ep_nohit"); _gs.gold = 5000
	r = _p.take_paragon("u_jost", "cls_jaguar_knight")
	check(r["ok"] and r["fee"] == 1600, "at level 34 the fee is 1600 (later costs more)")
	# the Jaguar knight is axe+brawl: now he can wield a maul
	check(_eq.unit_arts("u_jost") == ["axe", "brawl"] and _eq.can_wield("u_jost", "wpn_maul"), "a Jaguar knight knows axe AND brawl: the maul is his")
	# Tzitzimitl once the paralogue is won
	_reset(); _gs.gold = 5000
	_certified("u_emmerich", "cls_warlock", 30)
	_p.record_deed("u_emmerich", "ep_nohit"); _gs.gold = 5000
	check(not _p.take_paragon("u_emmerich", "cls_tzitzimitl")["ok"], "Tzitzimitl is locked until the paralogue is won")
	_p.on_map_won("map_p_simurgh")
	r = _p.take_paragon("u_emmerich", "cls_tzitzimitl")
	check(r["ok"] and _p.class_name_of("u_emmerich") == "Tzitzimitl" and _p.chosen("u_emmerich")[0] == "ab_corrosion", "...and opens after it (Corrosion first)")
	# growth shows up in real level-ups: mean over many levels
	var rng := RandomNumberGenerator.new(); rng.seed = 5
	var g0: int = _gs.progression["u_emmerich"]["gains"]["mag"]
	_p.grant_exp("u_emmerich", 3000 * 100, rng)
	var mean: float = float(_gs.progression["u_emmerich"]["gains"]["mag"] - g0) / 3000.0
	check(absf(mean - (0.55 + 0.10)) < 0.03, "Emmerich's Mag grows at 55%% + 10 = 65%% (got %.3f)" % mean)

func _special_lines() -> void:
	# personal-class milestone: Avatar at 30 keeps the class, gains the jump
	_p.state("u_avatar"); _gs.progression["u_avatar"]["level"] = 15
	_gs.gold = 100000
	_p.promote("u_avatar", "cls_strategist")
	_gs.progression["u_avatar"]["level"] = 30
	var opts: Array = _p.paragon_options("u_avatar")
	check(opts.size() == 1 and opts[0]["class_id"] == "cls_strategist", "the avatar's second milestone is a single option: itself")
	_p.record_deed("u_avatar", "ep_nohit")
	var before: Dictionary = _p.stats_for("u_avatar")
	var r: Dictionary = _p.take_paragon("u_avatar", "cls_strategist")
	check(r["ok"] and _p.is_paragon("u_avatar") and _p.class_id_of("u_avatar") == "cls_strategist", "the milestone keeps the class and marks paragon")
	check(_total(_p.stats_for("u_avatar")) - _total(before) == 30, "+30 stats for the avatar (infantry: no shape)")
	# the shadow line: Kest Footpad -> Thief (15) -> Assassin / Trickster (30)
	_reset(); _gs.gold = 100000
	_p.state("u_kest"); _gs.progression["u_kest"]["level"] = 15
	_p.promote("u_kest", "cls_thief")
	_gs.progression["u_kest"]["level"] = 30
	check(_names(_p.paragon_options("u_kest")) == ["Assassin", "Trickster"], "Kest's second tier: Assassin or Trickster (%s)" % str(_names(_p.paragon_options("u_kest"))))
	_p.record_deed("u_kest", "ep_solohold")
	check(_p.take_paragon("u_kest", "cls_assassin")["ok"] and _p.class_id_of("u_kest") == "cls_assassin", "he can take the Assassin")
	# a native paragon-tier class never needs the step
	check(_p.is_paragon("u_kest"), "(flagged paragon)")
	# Dietmar: Charge is the Bogatyr's signature
	_reset(); _gs.gold = 100000
	_p.state("u_dietmar"); _gs.progression["u_dietmar"]["level"] = 30
	_p.record_deed("u_dietmar", "ep_bosskill")
	check(_p.take_paragon("u_dietmar", "cls_bogatyr")["ok"] and _p.chosen("u_dietmar")[0] == "ab_charge", "Dietmar becomes a Bogatyr; Charge leads his kit")
	var by_class := {}
	for row in _p.pool("u_dietmar"):
		by_class[row["ability_id"]] = true
	check(by_class.has("ab_charge") and by_class.has("ab_focus_lance"), "his pool keeps the lance focus")
	# every paragon class has a signature ability that leads its pool
	var sigs := {"cls_fianna": "ab_astra", "cls_donso": "ab_deadeye", "cls_toa": "ab_fierce_iron_fist", "cls_jaguar_knight": "ab_colossus", "cls_eagle_knight": "ab_stun", "cls_tzitzimitl": "ab_corrosion", "cls_bogatyr": "ab_charge"}
	var all_ok := true
	for cid in sigs:
		_reset()
		_p.state("u_jost")
		_gs.progression["u_jost"]["class_id"] = cid
		if _p.pool("u_jost")[0]["ability_id"] != sigs[cid]:
			all_ok = false
			print("  pool for ", cid, " starts with ", _p.pool("u_jost")[0]["ability_id"])
	check(all_ok, "each paragon class's signature skill leads its pool")
