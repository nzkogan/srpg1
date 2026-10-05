extends SceneTree
## Headless checks for the Progression autoload: state and late-joiner catch-up,
## EXP and levelling (no cap, no gate), income, hybrid unlocks, certification and
## recertification, abilities, and the high-tier weapon gate.
## Run from the repo root:
##   godot --headless --path game --script res://tests/test_progression.gd
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

func _initialize() -> void:
	_p = root.get_node("Progression")
	_gs = root.get_node("GameState")
	_eq = root.get_node("Equipment")
	await process_frame
	_reset(); _params_and_state()
	_reset(); _catchup()
	_reset(); _exp_and_levels()
	_reset(); _income_and_unlocks()
	_reset(); _certification()
	_reset(); _recertification()
	_reset(); _abilities()
	_reset(); _tier_gate()
	_reset()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)

func _reset() -> void:
	_gs.progression.clear(); _gs.gold = 0; _gs.unlocked_classes.clear(); _gs.income_claimed.clear()
	_gs.inventories.clear(); _gs.convoy.clear(); _gs.equipment_ready = false; _gs.drops_claimed.clear()

func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r

## Fake squad members: only a level matters to the median.
func _squad(levels: Array) -> void:
	for i in levels.size():
		_gs.progression["u_fake_%d" % i] = {"level": levels[i]}

func _total(d: Dictionary) -> int:
	var n := 0
	for k in d:
		n += int(d[k])
	return n

func _params_and_state() -> void:
	check(_p.param("promote_min_level") == 15 and _p.param("fee_base") == 300 and _p.param("fee_per_level") == 100, "promotion parameters load from canon")
	check(_p._shapes.keys().size() == 4 and _p._shapes["armor"]["def"] == 3 and _p._shapes["infantry"].is_empty(), "movement shapes load (infantry has none)")
	for mv in _p._shapes:
		var sum := 0
		for k in _p._shapes[mv]:
			sum += _p._shapes[mv][k]
		check(sum == 0, "shape %s is zero-sum (%d)" % [mv, sum])
	var jump := 0
	for s in _p.STATS:
		jump += int(_p.param("jump_" + s))
	check(jump == 25, "the flat jump totals +25 (got %d)" % jump)
	var st: Dictionary = _p.state("u_jost")
	check(st["level"] == 5 and st["exp"] == 0 and st["class_id"] == "cls_tr_axe" and not st["promoted"], "Jost starts at level 5, trained, unpromoted")
	check(_p.stats_for("u_jost") == {"hp": 23, "str": 8, "mag": 3, "dex": 8, "spd": 8, "lck": 7, "def": 6, "res": 4}, "his stats are his canon base row")
	check(_p.state("u_dietmar")["promoted"] and _p.level("u_dietmar") == 15 and _p.class_tier("u_dietmar") == "order", "Dietmar is native order tier: promoted at 15")
	check(_p.state("u_avatar")["level"] == 1 or _p.level("u_avatar") > 1, "the avatar exists (level may be caught up)")
	check(_p.state("u_nobody").is_empty() and not _p.is_known_unit("u_nobody"), "unknown units have no state")
	check(_gs.progression.has("u_jost"), "state lives in GameState")
	check(_p.growth_rate("u_jost", "str") == 55 and _p.growth_rate("u_dietmar", "str") == 25, "growth rate = the unit's profile, +5 once promoted (Dietmar 20 + 5)")

func _catchup() -> void:
	# a squad at 15: a new level-5 unit arrives at 12
	_squad([15, 15, 15])
	var st: Dictionary = _p.state("u_jost")
	check(st["level"] == 12, "a level-5 joiner into a level-15 squad is raised to 12 (median - 3), got %d" % st["level"])
	var expected_str := int(round(7 * 55 / 100.0))
	check(st["gains"]["str"] == expected_str, "by expected growth: 7 levels x 55%% = %d Str" % expected_str)
	check(_p.stats_for("u_jost")["str"] == 8 + expected_str and st["exp"] == 0, "stats follow, EXP starts at 0")
	# within the gap: untouched
	_reset()
	_squad([8, 8, 8])
	check(_p.state("u_jost")["level"] == 5, "exactly 3 under the median is within the gap: no catch-up")
	_reset()
	_squad([9])
	check(_p.state("u_jost")["level"] == 6, "4 under: raised to median - 3 = 6")
	# an above-median joiner is never lowered
	_reset()
	_squad([3, 3])
	check(_p.state("u_dietmar")["level"] == 15, "a joiner above the median keeps their level")
	# the first unit of a playthrough has no squad to catch up to
	_reset()
	check(_p.state("u_rinsa")["level"] == 5, "no squad yet: no catch-up")
	# median: lower middle for an even count, excludes the asker
	_reset()
	_squad([4, 10, 12, 20])
	check(_p.squad_median() == 10, "even-sized squad: the lower median (10)")
	check(_p.squad_median("u_fake_1") == 12, "excluding a member shifts the median (4, 12, 20 -> 12)")
	_reset()
	check(_p.squad_median() == -1, "no squad: -1")
	# catch-up rolls no dice: two identical setups agree
	_reset(); _squad([20]); var a: Dictionary = _p.state("u_ricberta").duplicate(true)
	_reset(); _squad([20]); var b: Dictionary = _p.state("u_ricberta").duplicate(true)
	check(a == b and a["level"] == 17, "catch-up is deterministic (Ricberta 5 -> 17)")

func _exp_and_levels() -> void:
	check(_p.fight_exp(5, 5, false) == 10, "an even fight: 10 EXP")
	check(_p.fight_exp(5, 10, false) == 25, "a tougher foe: 10 + 3 x 5 = 25")
	check(_p.fight_exp(5, 30, false) == 30, "capped at 30")
	check(_p.fight_exp(20, 1, false) == 1, "a trivial foe: floor of 1")
	check(_p.fight_exp(5, 5, true) == 10 + 30, "a kill adds 30 on an even fight")
	check(_p.fight_exp(5, 10, true) == 25 + 55, "kill bonus 30 + 5 x 5 = 55")
	check(_p.fight_exp(5, 40, true) == 30 + 60, "kill bonus capped at 60")
	# multipliers
	_squad([15])
	check(is_equal_approx(_p.exp_multiplier("u_dietmar"), 1.0), "at the median: x1")
	_reset(); _squad([15]); _p.state("u_jost")                # Jost is caught up to 12
	_gs.progression["u_jost"]["level"] = 8
	check(is_equal_approx(_p.exp_multiplier("u_jost"), 2.0), "7 under the median: underdog bonus capped at +100% (x2)")
	_gs.progression["u_jost"]["level"] = 13
	check(is_equal_approx(_p.exp_multiplier("u_jost"), 1.5), "2 under the median: +50% (x1.5)")
	_p.set_abilities("u_jost", ["ab_quick_study"])
	check(is_equal_approx(_p.exp_multiplier("u_jost"), 1.65), "Quick Study adds 15% on top (x1.65)")
	# award_fight uses the multiplier and levels up
	_reset()
	var r: Dictionary = _p.award_fight("u_jost", 5, false, _rng(1))
	check(r["exp"] == 10 and r["levelups"].is_empty() and _p.exp_of("u_jost") == 10, "10 EXP, no level yet")
	# levelling: 100 EXP a level, carry-over, several levels at once
	_reset()
	var ups: Array = _p.grant_exp("u_jost", 250, _rng(2))
	check(ups.size() == 2 and _p.level("u_jost") == 7 and _p.exp_of("u_jost") == 50, "250 EXP = two levels and 50 over")
	check(ups[0]["level"] == 6 and ups[1]["level"] == 7, "level-ups are numbered in order")
	var gained := 0
	for u in ups:
		gained += _total(u["gains"])
	check(gained == _total(_gs.progression["u_jost"]["gains"]), "the stats gained equal the stats rolled")
	check(_p.grant_exp("u_jost", 0, _rng(3)).is_empty() and _p.grant_exp("u_nobody", 500, _rng(3)).is_empty(), "nothing for 0 EXP or an unknown unit")
	# growth rates are honoured: mean gains over many level-ups track the profile
	_reset()
	var rng := _rng(4)
	var n := 3000
	_p.grant_exp("u_jost", n * 100, rng)
	var mean_str: float = float(_gs.progression["u_jost"]["gains"]["str"]) / n
	var mean_lck: float = float(_gs.progression["u_jost"]["gains"]["lck"]) / n
	check(absf(mean_str - 0.55) < 0.03 and absf(mean_lck - 0.40) < 0.03, "Jost's growth tracks his profile (Str %.3f vs .55, Lck %.3f vs .40)" % [mean_str, mean_lck])
	# NO LEVEL CAP and NO GATE: an unpromoted unit kept levelling far past 15
	check(_p.level("u_jost") == 3005 and not _p.is_promoted("u_jost"), "no gate and no cap: unpromoted Jost is level 3005")
	# promoted growth is higher by growth_bonus
	_reset()
	_p.state("u_jost"); _gs.progression["u_jost"]["promoted"] = true
	_p.grant_exp("u_jost", n * 100, _rng(5))
	var promoted_mean: float = float(_gs.progression["u_jost"]["gains"]["str"]) / n
	check(absf(promoted_mean - 0.60) < 0.03, "a promoted Jost rolls Str at 60%% (got %.3f)" % promoted_mean)
	# describe
	check(_p.describe_levelup("Jost", {"level": 6, "gains": {"str": 1, "hp": 1}}) == "Jost reaches level 6! (+HP +STR)", "level-up text reads well")
	check(_p.describe_levelup("Jost", {"level": 6, "gains": {}}).contains("no stat gains"), "a blank level-up says so")

func _income_and_unlocks() -> void:
	check(_p.map_income(0, false) == 200 and _p.map_income(6, false) == 290, "income: 200 + 15 per kill")
	check(_p.map_income(6, true) == 435, "Kheldar on the map: x1.5 (435)")
	check(_p.award_income("map_x", 6, false) == 290 and _gs.gold == 290, "income is paid into gold")
	check(_p.award_income("map_x", 6, false) == 0 and _gs.gold == 290, "once per map per playthrough")
	check(_p.award_income("map_y", 0, true) == 300 and _gs.gold == 590, "another map pays again")
	# hybrid unlocks
	check(not _p.is_class_unlocked("cls_billman") and _p.is_class_unlocked("cls_warrior"), "hybrids start locked, ordinary classes are open")
	check(_p.on_map_won("map_d01").is_empty(), "winning an unrelated map unlocks nothing")
	check(_p.on_map_won("map_tp19") == ["Billman"] and _p.is_class_unlocked("cls_billman"), "winning the Throat Pass unlocks the Billman")
	check(_p.on_map_won("map_tp19").is_empty(), "...once")
	var all_unlocks := {}
	for cls in root.get_node("Canon").get_table("classes"):
		if cls.get("unlock_map_id") != null:
			all_unlocks[cls["class_id"]] = cls["unlock_map_id"]
	check(all_unlocks.size() == 5, "five hybrid classes carry an unlock map")

func _certification() -> void:
	check(_p.promotion_fee(15) == 300 and _p.promotion_fee(16) == 400 and _p.promotion_fee(20) == 800, "fee: 300 at 15, +100 a level after")
	check(_p.promotion_fee(10) == 300, "never below the base")
	var opts: Array = _p.promotion_options("u_jost")
	var names: Array = []
	for o in opts:
		names.append(o["name"])
	check(names.has("Warrior") and names.has("Housecarl") and names.has("Axe knight") and names.has("Wyvern lord"), "an axe user may certify into all four order classes")
	check(names.has("Billman") and names.has("Ferryman"), "...and sees the hybrids")
	var locked := {}
	for o in opts:
		locked[o["name"]] = o["locked"]
	check(locked["Billman"] and locked["Ferryman"] and not locked["Warrior"], "hybrids are locked, order classes aren't")
	var billman: Dictionary = {}
	for o in opts:
		if o["name"] == "Billman": billman = o
	check(billman["reason"].begins_with("win ") and billman["reason"].contains("Throat Pass"), "the lock says what to win (%s)" % billman["reason"])
	# can't yet
	_gs.gold = 5000
	var r: Dictionary = _p.promote("u_jost", "cls_warrior")
	check(not r["ok"] and r["reason"] == "needs level 15" and _gs.gold == 5000, "level 5 can't certify, and nothing is charged")
	_gs.progression["u_jost"]["level"] = 15
	_gs.gold = 299
	r = _p.promote("u_jost", "cls_warrior")
	check(not r["ok"] and r["reason"].contains("needs 300 gold (have 299)") and not _p.is_promoted("u_jost"), "299 gold is not enough")
	_gs.gold = 5000
	check(not _p.promote("u_jost", "cls_billman")["ok"] and _p.promote("u_jost", "cls_billman")["reason"].contains("Throat Pass"), "a locked hybrid is refused")
	check(not _p.promote("u_jost", "cls_swordmaster")["ok"], "a class from another art is refused")
	check(_gs.gold == 5000, "refusals charge nothing")
	# the real thing: Axe knight (riding)
	var before: Dictionary = _p.stats_for("u_jost")
	var exp_before: int = _p.exp_of("u_jost")
	var slots_before: int = _p.slots("u_jost")
	r = _p.promote("u_jost", "cls_axe_knight")
	check(r["ok"] and r["fee"] == 300 and _gs.gold == 4700, "certifies for 300 gold")
	check(_p.is_promoted("u_jost") and _p.class_id_of("u_jost") == "cls_axe_knight" and _p.class_tier("u_jost") == "order", "class and promotion flag change")
	check(_p.level("u_jost") == 15 and _p.exp_of("u_jost") == exp_before, "NO level reset, EXP untouched")
	var after: Dictionary = _p.stats_for("u_jost")
	var riding: Dictionary = _p._shapes["riding"]
	var ok := true
	for s in _p.STATS:
		if after[s] != before[s] + int(_p.param("jump_" + s)) + int(riding.get(s, 0)):
			ok = false
	check(ok, "stats = before + the flat jump + the riding shape")
	check(_total(after) - _total(before) == 25, "total change is exactly +25 (the shape is zero-sum)")
	check(_p.slots("u_jost") == slots_before + 1, "promotion adds an ability slot")
	check(_p.growth_rate("u_jost", "str") == 60, "growth now has the +5 bonus")
	check(not _p.promote("u_jost", "cls_warrior")["ok"] and _p.promote("u_jost", "cls_warrior")["reason"] == "already certified", "no second certification")
	check(_p.promotion_options("u_jost").is_empty(), "no options once promoted")
	# later is dearer: same unit at level 20 pays 800
	_reset(); _gs.gold = 5000
	_p.state("u_ricberta"); _gs.progression["u_ricberta"]["level"] = 20
	r = _p.promote("u_ricberta", "cls_general")
	check(r["ok"] and r["fee"] == 800 and _gs.gold == 4200, "at level 20 the fee is 800 (later costs more)")
	# the unlocked hybrid becomes available
	_reset(); _gs.gold = 5000
	_p.state("u_jost"); _gs.progression["u_jost"]["level"] = 15
	_p.on_map_won("map_tp19")
	var bill_opt := {}
	for o in _p.promotion_options("u_jost"):
		if o["class_id"] == "cls_billman": bill_opt = o
	check(not bill_opt.is_empty() and not bill_opt["locked"], "after the Throat Pass the Billman is offered")
	r = _p.promote("u_jost", "cls_billman")
	check(r["ok"] and _eq.unit_arts("u_jost") == ["axe", "lance"], "Jost certifies as a Billman and now knows axe AND lance")
	check(_eq.can_wield("u_jost", "wpn_halberd"), "...so he can wield the halberd")
	check(_p.stats_for("u_jost")["spd"] == 8 + int(_p.param("jump_spd")), "hybrids (infantry) carry no shape overlay")
	# the personal milestone and the shadow line
	_reset(); _gs.gold = 5000
	_p.state("u_avatar"); _gs.progression["u_avatar"]["level"] = 15
	var avatar_opts: Array = _p.promotion_options("u_avatar")
	check(avatar_opts.size() == 1 and avatar_opts[0]["class_id"] == "cls_strategist", "a personal class has one milestone option: itself")
	check(_p.promote("u_avatar", "cls_strategist")["ok"] and _p.is_promoted("u_avatar") and _p.class_id_of("u_avatar") == "cls_strategist", "the milestone promotes without changing class")
	_p.state("u_kest"); _gs.progression["u_kest"]["level"] = 15
	var kest_opts: Array = _p.promotion_options("u_kest")
	check(kest_opts.size() == 1 and kest_opts[0]["class_id"] == "cls_thief", "Kest's line: Footpad -> Thief")
	# natives are already promoted
	check(_p.promotion_options("u_dietmar").is_empty() and not _p.promote("u_dietmar", "cls_paladin")["ok"], "Dietmar has nothing to certify")

func _recertification() -> void:
	_gs.gold = 5000
	_p.state("u_jost"); _gs.progression["u_jost"]["level"] = 15
	_p.promote("u_jost", "cls_axe_knight")                        # riding
	_gs.gold = 5000
	var names: Array = []
	for o in _p.recertify_options("u_jost"):
		names.append(o["name"])
	check(names.size() == 3 and names.has("Warrior") and names.has("Housecarl") and names.has("Wyvern lord") and not names.has("Axe knight") and not names.has("Billman"),
		"recertify: the other three order classes of the same art (%s)" % str(names))
	check(_p.recert_fee(15) == 150 and _p.recert_fee(20) == 400, "recertifying costs half the promotion fee (150 at 15)")
	var gains_before: Dictionary = _gs.progression["u_jost"]["gains"].duplicate()
	var level_before: int = _p.level("u_jost")
	var r: Dictionary = _p.recertify("u_jost", "cls_housecarl")   # armor
	check(r["ok"] and r["fee"] == 150 and _gs.gold == 4850 and _p.class_id_of("u_jost") == "cls_housecarl", "switches to Housecarl for 150")
	check(_gs.progression["u_jost"]["gains"] == gains_before and _p.level("u_jost") == level_before, "level and every earned stat are kept")
	var st: Dictionary = _p.stats_for("u_jost")
	var base: Dictionary = {"hp": 23, "str": 8, "mag": 3, "dex": 8, "spd": 8, "lck": 7, "def": 6, "res": 4}
	var armor: Dictionary = _p._shapes["armor"]
	var ok := true
	for s in _p.STATS:
		if st[s] != base[s] + gains_before[s] + int(armor.get(s, 0)):
			ok = false
	check(ok, "only the shape overlay changed: riding out, armor in")
	check(not _p.recertify("u_jost", "cls_swordmaster")["ok"], "another art's class is refused")
	check(not _p.recertify("u_jost", "cls_billman")["ok"], "hybrids aren't a recertification target")
	_gs.gold = 10
	r = _p.recertify("u_jost", "cls_warrior")
	check(not r["ok"] and r["reason"].contains("needs 150 gold") and _p.class_id_of("u_jost") == "cls_housecarl", "too poor: refused and unchanged")
	check(_p.recertify_options("u_dietmar").is_empty(), "a native order unit (no certification) has nothing to switch")
	_p.state("u_ricberta")
	check(_p.recertify_options("u_ricberta").is_empty(), "an unpromoted unit can't recertify")

func _abilities() -> void:
	var pool_ids: Array = []
	for row in _p.pool("u_jost"):
		pool_ids.append(row["ability_id"])
	check(pool_ids.has("ab_steady_hand") and pool_ids.has("ab_focus_axe") and pool_ids.has("ab_skirmisher") and pool_ids.has("ab_quick_study"), "a trained axe unit's pool: generics, axe focus, infantry")
	check(not pool_ids.has("ab_focus_sword") and not pool_ids.has("ab_smite") and not pool_ids.has("ab_charge"), "...and nothing from other arts, classes or movements")
	check(pool_ids[0] == "ab_focus_axe", "the pool lists the most specific first (art focus before generics)")
	check(_p.slots("u_jost") == 1 and _p.chosen("u_jost") == ["ab_focus_axe"], "level 5, unpromoted: 1 slot, defaulting to the art focus")
	_gs.progression["u_jost"]["level"] = 10
	check(_p.slots("u_jost") == 2 and _p.chosen("u_jost").size() == 2, "level 10: a second slot, filled by default")
	_gs.progression["u_jost"]["level"] = 100
	check(_p.slots("u_jost") == 11 and _p.chosen("u_jost").size() == pool_ids.size(), "slots grow without a cap, but you can't choose more than the pool")
	_gs.progression["u_jost"]["level"] = 10
	# choosing
	check(_p.set_abilities("u_jost", ["ab_quick_study", "ab_steady_hand"]) and _p.chosen("u_jost") == ["ab_quick_study", "ab_steady_hand"], "the player's picks replace the defaults")
	check(not _p.set_abilities("u_jost", ["ab_quick_study", "ab_steady_hand", "ab_last_stand"]), "more than the slots is refused")
	check(not _p.set_abilities("u_jost", ["ab_smite"]), "an ability outside the pool is refused")
	check(not _p.set_abilities("u_jost", ["ab_steady_hand", "ab_steady_hand"]), "duplicates are refused")
	check(_p.chosen("u_jost") == ["ab_quick_study", "ab_steady_hand"], "refusals change nothing")
	var t = _p.toggle_ability("u_jost", "ab_steady_hand")
	check(t == ["ab_quick_study"], "toggling a chosen ability removes it")
	t = _p.toggle_ability("u_jost", "ab_focus_axe")
	check(t == ["ab_quick_study", "ab_focus_axe"], "toggling an unchosen one adds it")
	check(_p.toggle_ability("u_jost", "ab_last_stand") == null, "toggling past the slots is refused")
	# effects for combat
	var fx: Array = _p.ability_effects("u_jost")
	check(fx.size() == 2 and fx[1]["hit"] == 8 and fx[1]["cond"] == "art:axe", "ability_effects hands Combat the rows")
	# class-specific and movement pools
	var dpool: Array = []
	for row in _p.pool("u_dietmar"): dpool.append(row["ability_id"])
	check(dpool.has("ab_charge") and dpool.has("ab_focus_lance") and not dpool.has("ab_skirmisher"), "Dietmar (Paladin): lance focus and Charge (riding), no infantry skill")
	var apool: Array = []
	for row in _p.pool("u_avatar"): apool.append(row["ability_id"])
	check(apool[0] == "ab_orders" and apool.has("ab_improvise"), "the avatar's own skills come first")
	var gpool: Array = []
	for row in _p.pool("u_gunnar"): gpool.append(row["ability_id"])
	check(gpool.has("ab_deadshot"), "Gunnar has Deadshot")
	# promotion adds a slot and the new class's pool; recertifying drops what no longer fits
	_reset(); _gs.gold = 10000
	_p.state("u_jost"); _gs.progression["u_jost"]["level"] = 15
	check(_p.slots("u_jost") == 2, "level 15 unpromoted: 2 slots")
	_p.promote("u_jost", "cls_housecarl")
	check(_p.slots("u_jost") == 3, "...3 once certified")
	var hp: Array = []
	for row in _p.pool("u_jost"): hp.append(row["ability_id"])
	check(hp.has("ab_smite") and hp.has("ab_bulwark") and not hp.has("ab_skirmisher"), "a Housecarl gains Smite and Bulwark (armor), loses the infantry skill")
	check(_p.chosen("u_jost")[0] == "ab_smite", "and Smite becomes the default")
	_p.set_abilities("u_jost", ["ab_smite", "ab_bulwark", "ab_focus_axe"])
	_p.recertify("u_jost", "cls_axe_knight")   # armor -> riding
	check(not _p.chosen("u_jost").has("ab_smite") and not _p.chosen("u_jost").has("ab_bulwark") and _p.chosen("u_jost").has("ab_focus_axe"), "switching class drops picks the new pool can't offer")
	# late joiners arrive with a built kit
	_reset(); _squad([20])
	_p.state("u_rinsa")
	check(_p.level("u_rinsa") == 17 and _p.chosen("u_rinsa").size() == _p.slots("u_rinsa") and _p.slots("u_rinsa") == 2, "a caught-up late joiner arrives with every slot filled (level 17 -> 2 slots)")
	check(_p.describe_ability(_p.ability_row("ab_focus_axe")) == "+8 hit, +2 crit with axe weapons", "ability text: '%s'" % _p.describe_ability(_p.ability_row("ab_focus_axe")))
	check(_p.describe_ability(_p.ability_row("ab_stake")) == "+10 hit, +4 dmg against riding units", "...and conditions read in words")
	check(_p.describe_ability(_p.ability_row("ab_last_stand")).ends_with("at half HP or less"), "...including HP conditions")

func _tier_gate() -> void:
	check(_p.can_use_tier("u_jost", "basic") and _p.can_use_tier("u_jost", "mid") and _p.can_use_tier("u_jost", "worn"), "basic, mid and worn are open to everyone")
	check(not _p.can_use_tier("u_jost", "high") and _p.can_use_tier("u_dietmar", "high"), "high needs a promoted class (Dietmar has one, Jost not yet)")
	check(not _eq.can_wield("u_jost", "wpn_axe_high") and _eq.can_wield("u_jost", "wpn_axe_mid"), "Equipment refuses a silver axe to an unpromoted Jost")
	check(_eq.can_wield("u_torvald", "wpn_axe_high"), "...but Torvald (Axe knight) may")
	_gs.gold = 5000
	_p.state("u_jost"); _gs.progression["u_jost"]["level"] = 15
	_p.promote("u_jost", "cls_warrior")
	check(_eq.can_wield("u_jost", "wpn_axe_high"), "certifying opens the silver axe")
