extends SceneTree
## Headless checks for the patrons: the 72 pairs and their five-day quinaries, who is born under which, the angel/demon lean,
## the percent-chance blessings and curses and how Combat rolls them, the sigils, the places' patrons, the words before and after
## the reveal, and the pieces of the map that show it.
## Run from the repo root:
##   godot --headless --path game --script res://tests/test_patrons.gd
## Exits 0 if every check passes, 1 otherwise.

var _failures: int = 0
var _checks: int = 0
var _p: Node
var _gs: Node
var _canon: Node
var _pa: Node
var _d: Node
var _combat: GDScript
var _sigil: GDScript

func check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: ", label)

func _initialize() -> void:
	_p = root.get_node("Progression")
	_gs = root.get_node("GameState")
	_canon = root.get_node("Canon")
	_pa = root.get_node("Patrons")
	_d = root.get_node("Deputy")
	_combat = load("res://scripts/combat.gd")
	_sigil = load("res://scripts/sigil.gd")
	await process_frame
	await _run()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)

func _join(ids: Array, level := 10) -> void:
	for u in ids:
		_p.state(u)
		_gs.progression[u]["level"] = level

func _map(scene: String, deploy: Array) -> Node:
	var m: Node = load("res://scenes/%s.tscn" % scene).instantiate()
	var ids: Array[String] = []
	ids.assign(deploy)
	m.deploy_unit_ids = ids
	m.enemy_phase_enabled = false
	root.add_child(m)
	await process_frame
	return m

# a fighter for Combat: stats that always hit and a fixed weapon
func _f(procs: Array, over := {}) -> Dictionary:
	var d := {"str": 5, "mag": 0, "dex": 0, "spd": 0, "lck": 0, "def": 0, "res": 0, "weapon_art": "sword", "procs": procs, "max_hp": 100}
	d.merge(over, true)
	return d

func _proc(kind: String, trigger: String, amount := 0, chance := 100, side := "blessing") -> Dictionary:
	return {"side": side, "trigger": trigger, "kind": kind, "amount": amount, "chance": chance, "label": kind.capitalize(), "patron": "pat_01"}

func _ex(atk: Dictionary, dfn: Dictionary, seed_ := 7, ahp := 40, dhp := 40, dist := 1) -> Dictionary:
	var w := {"art": "sword", "might": 5, "hit": 100, "crit": 0, "range_min": 1, "range_max": 1, "weight": 0}
	var r := RandomNumberGenerator.new()
	r.seed = seed_
	return _combat.resolve_exchange(atk, dfn, w, w, dist, r, ahp, dhp)

func _run() -> void:
	# ---- the 72 pairs
	var rows: Array = _pa.rows()
	var names := {}
	var angels := {}
	for r in rows:
		names[r["demon_name"]] = true
		angels[r["angel_name"]] = true
	check(rows.size() == 72 and names.size() == 72 and angels.size() == 72, "72 patrons, 72 demons and 72 angels, none repeated")
	check(rows[0]["demon_name"] == "Bael" and rows[0]["angel_name"] == "Vehuiah" and rows[0]["demon_rank"] == "King" and rows[0]["sign_id"] == "sgn_ram" and rows[0]["first_day"] == 1 and rows[0]["last_day"] == 5, "the first pair: Bael and Vehuiah, the Ram's first five days")
	check(rows[71]["demon_name"] == "Andromalius" and rows[71]["angel_name"] == "Mumiah" and rows[71]["sign_id"] == "sgn_fishes" and rows[71]["first_day"] == 26 and rows[71]["last_day"] == 30, "the last: Andromalius and Mumiah, the Fishes' last five")
	check(_pa.patron_for("sgn_ram", 5)["patron_id"] == "pat_01" and _pa.patron_for("sgn_ram", 6)["patron_id"] == "pat_02" and _pa.patron_for("sgn_ram", 6)["demon_name"] == "Agares", "five days each: day 5 is Bael's, day 6 Agares'")
	var every := true
	for sg in _pa._sign_ids():
		for day in range(1, 31):
			if _pa.patron_for(sg, day).is_empty():
				every = false
	check(every and _pa._sign_ids().size() == 12, "every day of all twelve signs has a patron")
	var blessings: int = _canon.get_table("patron_effects").filter(func(e): return e.get("side") == "blessing").size()
	var curses: int = _canon.get_table("patron_effects").filter(func(e): return e.get("side") == "curse").size()
	check(blessings == 6 and curses == 6, "six blessings and six curses")
	check(_pa.row("pat_01")["blessing_effect"] == "eff_echo" and _pa.row("pat_01")["curse_effect"] == "eff_recoil", "the Ram's first decan: its virtue and its failure (Echo and Recoil)")
	check(_pa.row("pat_03")["blessing_effect"] == "eff_surge" and _pa.row("pat_03")["curse_effect"] == "eff_exposed", "its second decan is ruled by the Lion, the next fire sign (Surge, Exposed)")
	check(_pa.row("pat_05")["blessing_effect"] == "eff_clarity", "its third by the Archer (Clarity)")

	# ---- births and lean
	for u in ["u_avatar", "u_jost", "u_ricberta", "u_emmerich", "u_sigrun", "u_waldrada", "u_tancred", "u_maren", "u_brandt", "u_solveig", "u_gunnar", "u_edda", "u_anselm", "u_kheldar", "u_dietmar", "u_torvald", "u_rinsa", "u_kest"]:
		var b: Dictionary = _pa.birth_of_unit(u)
		if b["sign"] == "" or b["day"] < 1 or b["day"] > 30 or b["sign"] != root.get_node("Almanac").sign_of(u):
			check(false, "%s has a birth under their own sign (%s)" % [u, str(b)])
	check(true, "all eighteen are born under the sign their supports give them")
	check(_pa.birth_lean(1) == 1 and _pa.birth_lean(2) == 1 and _pa.birth_lean(3) == 0 and _pa.birth_lean(4) == -1 and _pa.birth_lean(5) == -1 and _pa.birth_lean(6) == 1 and _pa.birth_lean(10) == -1, "the first two days of five lean angel, the last two demon")
	check(_pa.side_of(2) == "angel" and _pa.side_of(-1) == "demon" and _pa.side_of(0) == "balanced", "the sides")
	_gs.reset()
	_join(["u_jost"])
	check(_pa.lean_of_unit("u_jost") == 1, "Jost, born on the Ram's 6th, leans angel by birth")
	_p.record_deed("u_jost", "ep_capture", 12)
	check(_pa.lean_of_unit("u_jost") == 4, "twelve mercies (x3 = 36 net, six to a step) push him to the cap of 4")
	_gs.reset()
	_join(["u_jost"])
	_d.record("u_jost", "raw_kill", 20)
	check(_pa.lean_of_unit("u_jost") == -2, "twenty kills push him toward the demon: 1 - 3 = -2")
	_gs.reset()
	_join(["u_jost"])
	_d.record("u_jost", "raw_kill", 500)
	check(_pa.lean_of_unit("u_jost") == -2, "five hundred do no more: conduct moves a unit three steps at most, so an angel-born unit stops at -2")

	# ---- the odds
	var king: Dictionary = _pa.row("pat_01")
	var knight: Dictionary = _pa.rows().filter(func(r): return r["demon_rank"] == "Knight")[0]
	check(_pa.chance(king, "blessing", 0) == 18 and _pa.chance(king, "curse", 0) == 18, "a king's procs are 18% with no lean")
	check(_pa.chance(king, "blessing", 2) == 23 and _pa.chance(king, "curse", 2) == 13, "toward the angel blessings rise (23) and curses fall (13)")
	check(_pa.chance(king, "blessing", -4) == 7 and _pa.chance(king, "curse", -4) == 29, "toward the demon the reverse")
	check(_pa.chance(knight, "curse", 4) == 2, "a knight's is 6%; at the far angel the curse is held at the 2% floor")
	_p._params["patron_chance_max"] = 20.0
	check(_pa.chance(king, "curse", -4) == 20, "(and the ceiling holds)")
	_p._params["patron_chance_max"] = 40.0
	_gs.reset()
	_join(["u_jost"])
	var pr: Array = _pa.procs_for_unit("u_jost")
	check(pr.size() == 2 and pr[0]["side"] == "blessing" and pr[0]["kind"] == "echo" and pr[0]["chance"] == 16 and pr[1]["side"] == "curse" and pr[1]["kind"] == "recoil" and pr[1]["chance"] == 12 and pr[0]["patron"] == "pat_02", "Jost carries Agares' favour (Echo 16%) and burden (Recoil 12%)")
	_pa.enabled = false
	check(_pa.procs_for_unit("u_jost").is_empty(), "(switched off, nothing)")
	_pa.enabled = true
	var arch := {"enemy_id": "ea_looter", "name": "Looter"}
	var e1: Dictionary = _pa.birth_of_enemy(arch, "spn#1")
	check(e1 == _pa.birth_of_enemy(arch, "spn#1") and e1["sign"] != "" and e1["day"] >= 1 and e1["day"] <= 30, "an enemy is always born under the same sign")
	var differ := false
	for i in 20:
		if _pa.birth_of_enemy(arch, "spn#%d" % i) != e1:
			differ = true
	check(differ, "...and two of one archetype are not all born alike")
	check(_pa.birth_of_enemy({"enemy_id": "ea_karkadann", "named_id": "nmd_karkadann"}, "x") == {"sign": "sgn_bull", "day": 9}, "a Named is born under its own sign and day")
	check(_pa.patron_for("sgn_bull", 9)["demon_name"] == "Barbatos", "...the Karkadann's day is Barbatos'")

	# ---- the words
	_gs.reset()
	check(not _pa.revealed() and _pa.gift_word("blessing") == "favour" and _pa.gift_word("curse") == "burden" and _pa.holder_word("angel") == "patron" and _pa.holder_word("demon") == "patron", "before the reveal: patron, favour, burden")
	check(_pa.name_for(king, "angel") == "Bael" and _pa.describe({"sign": "sgn_ram", "day": 6}, 1) == "Agares (patron): favour Echo 16%, burden Recoil 12%", "...and the one name the old city knew: %s" % _pa.describe({"sign": "sgn_ram", "day": 6}, 1))
	_gs.won_maps["map_f02"] = true
	check(_pa.revealed() and _pa.gift_word("blessing") == "blessing" and _pa.gift_word("curse") == "curse" and _pa.holder_word("angel") == "angel" and _pa.holder_word("demon") == "demon", "once the last court is won: angel, demon, blessing, curse")
	check(_pa.name_for(king, "angel") == "Vehuiah" and _pa.name_for(king, "demon") == "Bael" and _pa.describe({"sign": "sgn_ram", "day": 6}, 1) == "Jeliel (angel): blessing Echo 16%, curse Recoil 12%", "...and the name is the side the bearer leans to")
	_gs.reset()
	check(_pa.born_text({"sign": "sgn_ram", "day": 6}) == "the Ram, day 6", "born_text")

	# ---- the places
	var L: Array = _canon.get_table("locations").filter(func(l): return str(l.get("location_id", "")).begins_with("loc_"))
	var covered: bool = L.all(func(l): return not _pa.row(str(l.get("patron_id", ""))).is_empty() and ["angel", "demon", "balanced"].has(l.get("patron_side")))
	check(L.size() == 38 and covered, "all 38 places have a patron pair and a side")
	var kais = _canon.find_by("locations", "location_id", "loc_kaisareia_walls")
	var lake = _canon.find_by("locations", "location_id", "loc_lake_shore")
	check(kais["patron_id"] == "pat_01" and kais["patron_side"] == "demon" and lake["patron_id"] == "pat_41" and _pa.row("pat_41")["demon_name"] == "Focalor", "the capital is Bael's, the drowned lake Focalor's")
	check(_pa.ground_text(kais).begins_with("The old city's patron here was Bael"), "before the reveal a place has an old patron: %s" % _pa.ground_text(kais))
	_gs.won_maps["map_f02"] = true
	check(_pa.ground_text(kais).begins_with("Ground of the angel Vehuiah, held now by the demon Bael"), "after it, whose ground it was and who holds it: %s" % _pa.ground_text(kais))
	var vetch = _canon.find_by("locations", "location_id", "loc_vetch_gate")
	check(_pa.ground_text(vetch).begins_with("Ground of the demon Buer, held now by the angel Aladiah"), "an angel-held place says so")
	check(_pa.ground_text(_canon.find_by("locations", "location_id", "loc_tally_house")).begins_with("The demon Andromalius and the angel Mumiah share"), "a balanced one is shared")
	_gs.reset()

	# ---- sigils
	var sigs := {}
	for n in range(1, 73):
		for side in ["angel", "demon", "balanced"]:
			sigs[_sigil.signature(n, side)] = true
	check(sigs.size() == 216, "216 distinct seals: every pair in each of its three hands (%d)" % sigs.size())
	check(_sigil.signature(5, "demon") == _sigil.signature(5, "demon"), "a seal is always the same")
	var ang: Dictionary = _sigil.build(5, "angel", 10.0)
	var dem: Dictionary = _sigil.build(5, "demon", 10.0)
	check(ang["lines"][0].size() == 9 and dem["lines"][0].size() == 2 and not ang["circles"].is_empty() and dem["circles"].is_empty(), "the angel's is curved and ringed, the demon's straight and open to the ring")
	check(dem["lines"].size() > ang["lines"].size(), "...and barbed")

	# ---- Combat: each kind of proc
	var plain := _ex(_f([]), _f([]))
	check(plain["strikes"].size() == 2 and plain["strikes"][0]["damage"] == 10 and plain["strikes"][0]["procs"].is_empty(), "(without procs: two strikes of 10, nothing fired)")
	var r1 := _ex(_f([_proc("power", "on_attack", 3)]), _f([]))
	check(r1["strikes"][0]["damage"] == 13 and r1["strikes"][0]["procs"].size() == 1 and r1["strikes"][0]["procs"][0]["by"] == "atk", "Surge: +3 damage on the blow")
	var r2 := _ex(_f([_proc("weak", "on_attack", 4, 100, "curse")]), _f([]))
	check(r2["strikes"][0]["damage"] == 6, "Faltering: -4")
	var r3 := _ex(_f([_proc("echo", "on_attack")]), _f([]))
	check(r3["strikes"].size() == 3 and r3["strikes"][1]["by"] == "atk", "Echo: a second blow follows at once, once an exchange (%d strikes)" % r3["strikes"].size())
	var r4 := _ex(_f([]), _f([_proc("ward", "on_defend", 4)]))
	check(r4["strikes"][0]["damage"] == 6, "Aegis on the defender: -4 to the blow")
	var r5 := _ex(_f([]), _f([_proc("expose", "on_defend", 3, 100, "curse")]))
	check(r5["strikes"][0]["damage"] == 13, "Exposed: +3")
	var r6 := _ex(_f([]), _f([_proc("evade", "on_defend")]))
	check(not r6["strikes"][0]["hit"] and r6["strikes"][0]["damage"] == 0, "Veil: the blow misses outright")
	var r7 := _ex(_f([_proc("miss", "on_attack", 0, 100, "curse")]), _f([]))
	check(not r7["strikes"][0]["hit"], "Stumble: the blow goes wide")
	var r8 := _ex(_f([_proc("evade", "on_defend"), _proc("focus", "on_attack")]), _f([]))
	check(r8["strikes"][0]["hit"], "(the attacker's own Clarity beats nothing it did not face)")
	var r9 := _ex(_f([_proc("focus", "on_attack")]), _f([], {"spd": 60}))
	check(r9["strikes"][0]["hit"] and r9["strikes"][0]["damage"] > 0, "Clarity: the blow lands though the odds were nothing")
	var r10 := _ex(_f([]), _f([_proc("jinx", "on_defend", 0, 100, "curse")], {"spd": 60}))
	check(r10["strikes"][0]["hit"], "Marked: the blow cannot miss")
	var r11 := _ex(_f([]), _f([_proc("evade", "on_defend"), _proc("jinx", "on_defend", 0, 100, "curse")], {"spd": 60}))
	check(not r11["strikes"][0]["hit"], "(a veil and a mark together: the miss wins)")
	var r12 := _ex(_f([_proc("recoil", "on_attack", 3, 100, "curse")]), _f([]))
	check(r12["atk_hp"] == 40 - 3 - 10 and r12["strikes"][0]["procs"][0]["kind"] == "recoil", "Recoil: three to the striker (and the foe's counter takes ten)")
	var r13 := _ex(_f([_proc("mend", "on_hit", 3)]), _f([]), 7, 20, 40)
	check(r13["atk_hp"] == 20 + 3 - 10, "Mending: three back on a landed blow, then the counter")
	var r14 := _ex(_f([_proc("mend", "on_hit", 50)], {"max_hp": 25}), _f([]), 7, 20, 40)
	check(r14["atk_hp"] == 25 - 10, "...never past the bearer's own maximum")
	var r15 := _ex(_f([]), _f([_proc("sap", "on_hurt", 2, 100, "curse")]))
	check(r15["strikes"][0]["damage"] == 12, "Bleeding: two more HP when hurt")
	var r16 := _ex(_f([_proc("power", "on_attack", 3, 0)]), _f([_proc("ward", "on_defend", 4, 0)]))
	check(r16["strikes"][0]["damage"] == 10 and r16["strikes"][0]["procs"].is_empty(), "a 0% proc never fires")
	# the main stream is untouched by the procs
	var ra := RandomNumberGenerator.new()
	ra.seed = 11
	var rb := RandomNumberGenerator.new()
	rb.seed = 11
	var w := {"art": "sword", "might": 5, "hit": 75, "crit": 0, "range_min": 1, "range_max": 1, "weight": 0}
	var o1: Dictionary = _combat.resolve_exchange(_f([]), _f([]), w, w, 1, ra, 40, 40)
	var o2: Dictionary = _combat.resolve_exchange(_f([_proc("power", "on_attack", 3, 0)]), _f([_proc("ward", "on_defend", 4, 0)]), w, w, 1, rb, 40, 40)
	var same: bool = o1["strikes"].size() == o2["strikes"].size()
	for i in mini(o1["strikes"].size(), o2["strikes"].size()):
		same = same and o1["strikes"][i]["hit"] == o2["strikes"][i]["hit"] and o1["strikes"][i]["damage"] == o2["strikes"][i]["damage"]
	check(same and ra.state == rb.state, "procs roll on a stream of their own: the same seed gives the same fight and leaves the main generator where it was")
	var r17 := _ex(_f([]), _f([_proc("ward", "on_defend", 50), _proc("sap", "on_hurt", 2, 100, "curse")]))
	check(r17["strikes"][0]["damage"] == 0 and r17["strikes"][0]["procs"].filter(func(x): return x["kind"] == "sap").is_empty(), "a blow that does no damage does not 'hurt': Bleeding waits")
	# a rate really is a rate
	var fired := 0
	for sd in 400:
		var rr := _ex(_f([_proc("power", "on_attack", 3, 25)]), _f([]), sd)
		if not rr["strikes"][0]["procs"].is_empty():
			fired += 1
	check(fired > 60 and fired < 140, "a 25%% proc fires about a quarter of the time (%d of 400)" % fired)

	# ---- on the map
	_gs.reset()
	_join(["u_jost", "u_brandt"])
	var m: Node = await _map("map_d02", ["u_jost", "u_brandt"])
	var c: Dictionary = m._combatant_for_unit("u_jost")
	check(c["procs"].size() == 2 and c["procs"][0]["patron"] == "pat_02", "a unit enters a fight carrying its two procs")
	check(m.unit_tokens["u_jost"].container.get_child_count() == 3, "its token carries its patron's seal")
	var boss_arch := {"enemy_id": "ea_t_boss", "name": "Boss", "weapon_art": "sword", "weapon_tier": "basic", "movement_type": "infantry", "level": 5, "hp": 40, "str": 3, "mag": 0, "dex": 0, "spd": 0, "lck": 0, "def": 0, "res": 0, "affiliation": "state", "death_noun": "lance"}
	for e in m.enemies:
		m._remove_enemy_token(e)
	m.enemies.clear(); m.dens.clear()
	m._spawn_enemy_instance(boss_arch, Vector2i(10, 8), "boss", 0)
	m._spawn_enemy_instance(boss_arch, Vector2i(11, 8), "mook", 1)
	check(m.enemies[0].token.container.get_child_count() == 3 and m.enemies[1].token.container.get_child_count() == 2, "a boss carries a seal; a common soldier does not")
	var ec: Dictionary = m._enemy_combatant(m.enemies[0])
	check(ec["procs"].size() == 2 and ec["max_hp"] == 40, "...but every enemy has its own birth and procs")
	m.unit_positions["u_jost"] = Vector2i(9, 8)
	var jrow: Dictionary = m.units.filter(func(u): return u["punit_id"] == "u_jost")[0]
	var finfo: Dictionary = m._forecast_info(jrow, m.enemies[0])
	check(finfo["patron_text"].begins_with("Yours: favour Echo 16%, burden Recoil 12%.  Theirs: ") and m.ForecastView.bbcode(finfo).contains("Yours: favour Echo 16%"), "the forecast shows both sides' odds: %s" % finfo["patron_text"])
	check(m._patron_forecast({}, {}) == "" and m._patron_forecast({"procs": []}, ec).begins_with("Yours: none.  Theirs: favour"), "(and says 'none' for a side with no gifts)")
	var text: String = m._describe_exchange({"strikes": [{"by": "atk", "hit": true, "crit": false, "damage": 9, "procs": [{"by": "atk", "side": "blessing", "kind": "echo", "label": "Echo", "amount": 0, "patron": "pat_02"}, {"by": "def", "side": "curse", "kind": "expose", "label": "Exposed", "amount": 3, "patron": "pat_02"}]}]}, "Jost", "the looter")
	check(text.contains("Jost's favour answers: a second blow follows.") and text.contains("The looter's burden weighs: +3 damage taken."), "the log names what fired: %s" % text)
	_gs.won_maps["map_f02"] = true
	check(m._describe_exchange({"strikes": [{"by": "atk", "hit": true, "crit": false, "damage": 9, "procs": [{"by": "atk", "side": "blessing", "kind": "power", "label": "Surge", "amount": 3, "patron": "pat_02"}]}]}, "Jost", "x").contains("Jost's blessing answers: +3 damage."), "...and after the reveal it is a blessing")
	m.queue_free()
	await process_frame
	m = await _map("map_f01", [])
	check(m._combatant_for_unit(m.units[0]["punit_id"]).get("procs", []).is_empty(), "a memory has none: nobody there was born under these days")
	m.queue_free()
	await process_frame

	# ---- the barracks and the world map
	_gs.reset()
	_join(["u_jost"])
	var bs: Node = load("res://scenes/barracks_screen.tscn").instantiate()
	root.add_child(bs)
	await process_frame
	bs._unit_index = bs.unit_ids.find("u_jost")
	bs._refresh()
	check(bs.detail_text().contains("Born the Ram, day 6. Agares (patron): favour Echo 16%, burden Recoil 12%"), "the barracks says whose gifts a unit carries")
	bs.queue_free()
	await process_frame
	var ow: Node2D = load("res://scenes/overworld.tscn").instantiate()
	ow.animate = false
	_gs.won_maps["map_f00"] = true
	root.add_child(ow)
	await process_frame
	var seals: Array = ow.get_children().filter(func(n): return n.get_script() == _sigil)
	check(seals.size() == 38, "every place on the world map wears its patron's seal (%d)" % seals.size())
	check(ow.info_label.text.contains("The old city's patron here was"), "the world map names a place's old patron: %s" % ow.info_label.text.substr(0, 160))
	ow.queue_free()
	await process_frame
