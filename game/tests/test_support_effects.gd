extends SceneTree
## Headless checks for support rank effects: the Supports.RANK_EFFECTS table,
## best_partner selection, the optional sup_* keys in Combat, and the wiring
## in map_grid's _attack_enemy.
## Run from the repo root:
##   godot --headless --path game --script res://tests/test_support_effects.gd
## Exits 0 if every check passes, 1 otherwise.

var _failures: int = 0
var _checks: int = 0
var _gs: Node
var _sup: Node
var _combat: GDScript

func check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: ", label)

func _initialize() -> void:
	_gs = root.get_node("GameState")
	_sup = root.get_node("Supports")
	_combat = load("res://scripts/combat.gd")
	await process_frame
	_reset()
	_table_tests()
	_partner_tests()
	_combat_tests()
	await _map_tests()
	_reset()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)

func _reset() -> void:
	_gs.support_recent.clear()
	_gs.support_focus = ""
	_gs.support_ranks.clear()
	_gs.support_points.clear()
	_gs.support_settled_maps.clear()
	_sup.begin_map()

func _rank(chain_id: String, rank: String) -> void:
	_gs.support_ranks[chain_id] = rank

# ------------------------------------------------------------------ table

func _table_tests() -> void:
	var order := ["C", "B", "A", "S"]
	check(_sup.RANK_EFFECTS.keys() == order, "an effect for every rank, C to S")
	var monotone := true
	for stat in ["hit", "avoid", "crit", "dodge"]:
		for i in range(1, order.size()):
			if _sup.RANK_EFFECTS[order[i]][stat] < _sup.RANK_EFFECTS[order[i - 1]][stat]:
				monotone = false
	check(monotone, "no stat ever goes down as rank rises")
	check(_sup.RANK_EFFECTS["S"]["hit"] > _sup.RANK_EFFECTS["A"]["hit"] and _sup.RANK_EFFECTS["S"]["crit"] > _sup.RANK_EFFECTS["A"]["crit"],
		"S (romance only) is a real step up from A, the platonic cap")
	var mirrored := true
	for r in order:
		if _sup.RANK_EFFECTS[r]["hit"] != _sup.RANK_EFFECTS[r]["avoid"] or _sup.RANK_EFFECTS[r]["crit"] != _sup.RANK_EFFECTS[r]["dodge"]:
			mirrored = false
	check(mirrored, "attacking and defending bonuses mirror each other")
	check(_sup.rank_effect("") == _sup.NO_EFFECT and _sup.rank_effect("Z") == _sup.NO_EFFECT, "no rank / unknown rank -> no effect")
	check(_sup.effect_text(_sup.rank_effect("C")) == "+3 hit/avoid", "C reads '+3 hit/avoid' (no crit clause at 0)")
	check(_sup.effect_text(_sup.rank_effect("B")) == "+5 hit/avoid, +1 crit/dodge", "B reads both clauses")
	check(_sup.effect_text(_sup.NO_EFFECT) == "", "no effect -> empty text")
	check(_sup.EFFECT_RANGE == _sup.PROXIMITY_RANGE, "combat reach matches earning reach")
	var keys: Dictionary = _sup.combat_keys(_sup.rank_effect("A"))
	check(keys == {"sup_hit": 7, "sup_crit": 2, "sup_avoid": 7, "sup_dodge": 2}, "combat_keys maps hit/crit/avoid/dodge to the sup_* keys")
	check(_sup.combat_keys({}) == {"sup_hit": 0, "sup_crit": 0, "sup_avoid": 0, "sup_dodge": 0}, "combat_keys of nothing is all zero")

# --------------------------------------------------------- best_partner

func _partner_tests() -> void:
	var jr := "sup_jost_ricberta"
	var je := "sup_jost_emmerich"
	_reset()
	_rank(jr, "C")
	var pos := {"u_jost": Vector2i(0, 0), "u_ricberta": Vector2i(0, 2)}
	var bp: Dictionary = _sup.best_partner("u_jost", pos, "diadem")
	check(bp.get("partner") == "u_ricberta" and bp.get("rank") == "C" and bp.get("chain_id") == jr and bp.get("effect") == _sup.rank_effect("C"),
		"a ranked partner two tiles away applies")
	check(_sup.best_partner("u_ricberta", pos, "diadem").get("partner") == "u_jost", "and it works from the partner's side too")
	check(_sup.best_partner("u_jost", {"u_jost": Vector2i(0, 0), "u_ricberta": Vector2i(0, 3)}, "diadem").is_empty(), "three tiles away: no effect")
	check(_sup.best_partner("u_jost", {"u_jost": Vector2i(0, 0), "u_ricberta": Vector2i(1, 1)}, "diadem").get("partner") == "u_ricberta", "diagonal (distance 2) counts")
	_reset()
	check(_sup.best_partner("u_jost", pos, "diadem").is_empty(), "no rank yet: no effect")
	check(_sup.best_partner("u_nobody", pos, "diadem").is_empty(), "a unit not on the map has no partner")
	check(_sup.best_partner("u_jost", {"u_jost": Vector2i(0, 0)}, "diadem").is_empty(), "alone: no effect (and never its own partner)")

	# highest rank wins, never stacks
	_rank(jr, "C"); _rank(je, "B")
	var three := {"u_jost": Vector2i(0, 0), "u_ricberta": Vector2i(0, 1), "u_emmerich": Vector2i(1, 0)}
	bp = _sup.best_partner("u_jost", three, "diadem")
	check(bp.get("partner") == "u_emmerich" and bp.get("rank") == "B", "the highest-ranked partner in range is the one that counts")
	check(bp["effect"] == _sup.rank_effect("B"), "and only that partner's effect applies -- no stacking")
	# the answer can't depend on the order units happen to be listed in
	var three_rev := {"u_jost": Vector2i(0, 0), "u_emmerich": Vector2i(1, 0), "u_ricberta": Vector2i(0, 1)}
	check(_sup.best_partner("u_jost", three_rev, "diadem").get("partner") == "u_emmerich", "highest rank wins whichever way round the units are listed")
	# a closer, lower-ranked partner doesn't beat a farther, higher-ranked one
	var far := {"u_jost": Vector2i(0, 0), "u_ricberta": Vector2i(0, 1), "u_emmerich": Vector2i(2, 0)}
	check(_sup.best_partner("u_jost", far, "diadem").get("partner") == "u_emmerich", "rank decides, not distance (within range)")
	# tie -> lowest chain_id (sup_jost_emmerich < sup_jost_ricberta)
	_rank(je, "C")
	check(_sup.best_partner("u_jost", three, "diadem").get("chain_id") == je, "equal ranks break by chain_id, deterministically")
	var tie_rev := {"u_jost": Vector2i(0, 0), "u_emmerich": Vector2i(1, 0), "u_ricberta": Vector2i(0, 1)}
	check(_sup.best_partner("u_jost", tie_rev, "diadem").get("chain_id") == je and _sup.best_partner("u_jost", three, "diadem").get("chain_id") == je,
		"the tie-break gives the same chain in either listing order")
	# an out-of-range higher rank doesn't count
	_rank(je, "A")
	var out_of_range := {"u_jost": Vector2i(0, 0), "u_ricberta": Vector2i(0, 1), "u_emmerich": Vector2i(5, 5)}
	check(_sup.best_partner("u_jost", out_of_range, "diadem").get("partner") == "u_ricberta", "a higher rank out of range is ignored")

	# route gate: diadem x assembly only on 'both' chapters
	_reset()
	var jm := "sup_jost_maren"
	_rank(jm, "B")
	var cross := {"u_jost": Vector2i(0, 0), "u_maren": Vector2i(0, 1)}
	check(_sup.best_partner("u_jost", cross, "diadem").is_empty(), "diadem x assembly: no effect on a diadem chapter")
	check(_sup.best_partner("u_jost", cross, "both").get("partner") == "u_maren", "...but it applies once the routes converge")
	_reset()

# ----------------------------------------------------------------- Combat

func _combat_tests() -> void:
	var atk := {"dex": 6, "lck": 4, "spd": 5, "str": 6}
	var dfn := {"spd": 4, "lck": 3, "def": 2, "res": 1, "weapon_art": "bow"}
	var wpn := {"art": "sword", "hit": 70, "crit": 0, "might": 5}
	var h0: int = _combat.hit_chance(atk, dfn, wpn)
	var c0: int = _combat.crit_chance(atk, dfn, wpn)
	check(h0 > 5 and h0 < 90, "test fixture sits clear of the 0/100 clamps (hit %d)" % h0)
	check(_combat.hit_chance({"dex": 6, "lck": 4, "sup_hit": 5}, dfn, wpn) == h0 + 5, "sup_hit adds to the attacker's hit")
	check(_combat.hit_chance(atk, {"spd": 4, "lck": 3, "weapon_art": "bow", "sup_avoid": 5}, wpn) == h0 - 5, "sup_avoid subtracts from the attacker's hit")
	check(_combat.hit_chance({"dex": 6, "lck": 4, "sup_avoid": 50}, dfn, wpn) == h0, "sup_avoid on the ATTACKER does nothing (it only defends)")
	check(_combat.crit_chance({"dex": 6, "sup_crit": 3}, dfn, wpn) == c0 + 3, "sup_crit adds to crit")
	check(_combat.crit_chance(atk, {"lck": 3, "sup_dodge": 2}, wpn) == maxi(0, c0 - 2), "sup_dodge subtracts from crit")
	check(_combat.hit_chance({"dex": 6, "lck": 4, "sup_hit": 500}, dfn, wpn) == 100, "hit still clamps at 100")
	check(_combat.hit_chance(atk, {"spd": 4, "lck": 3, "sup_avoid": 500}, wpn) == 0, "and at 0")
	check(_combat.crit_chance({"dex": 6, "sup_crit": 500}, dfn, wpn) == 100, "crit still clamps at 100")
	# an effect from a real rank flows through unchanged
	var s_keys: Dictionary = _sup.combat_keys(_sup.rank_effect("S"))
	var boosted := atk.merged(s_keys)
	check(_combat.hit_chance(boosted, dfn, wpn) == mini(100, h0 + 10), "an S-rank effect adds its +10 hit")
	# deterministic through resolve_attack: a roll that misses at base hits with support
	var found := -1
	for seed_value in 500:
		var r := RandomNumberGenerator.new()
		r.seed = seed_value
		var roll := r.randi_range(1, 100)
		if roll > h0 and roll <= h0 + 10:
			found = seed_value
			break
	check(found >= 0, "found a seed whose roll falls in the support window")
	var r1 := RandomNumberGenerator.new(); r1.seed = found
	var r2 := RandomNumberGenerator.new(); r2.seed = found
	check(not _combat.resolve_attack(atk, dfn, wpn, r1)["hit"], "that roll misses without support")
	check(_combat.resolve_attack(boosted, dfn, wpn, r2)["hit"], "and hits with S-rank support")

# ---------------------------------------------------------------- map_grid

func _melee_unit(map: Node) -> int:
	for i in map.units.size():
		var art = map.units[i].get("weapon_art")
		if art == null or art == "":
			continue
		var w: Dictionary = map._weapon_for_art(art)
		if not w.is_empty() and int(w.get("range_min", 1)) <= 1 and int(w.get("range_max", 1)) >= 1:
			return i
	return -1

func _map_tests() -> void:
	_reset()
	var map: Node = load("res://scenes/map_d05.tscn").instantiate()
	root.add_child(map)
	await process_frame
	check(not map.enemies.is_empty(), "map_d05 has an enemy to attack")
	var idx := _melee_unit(map)
	check(idx >= 0, "found a melee-capable unit")
	if idx < 0 or map.enemies.is_empty():
		map.queue_free()
		return
	var unit: Dictionary = map.units[idx]
	var pid: String = unit["punit_id"]
	var partner := ""
	for other in map.unit_positions:
		if other != pid and not _sup.get_chain(pid, other).is_empty() and _sup.pair_allowed(pid, other, map.chapter_route):
			partner = other
			break
	check(partner != "", "found a partner on the roster who may pair with %s" % pid)
	var chain: String = _sup.get_chain(pid, partner)["chain_id"]
	var enemy: Dictionary = map.enemies[0]
	var weapon: Dictionary = map._weapon_for_art(unit["weapon_art"])
	# stand the attacker next to the enemy and the partner beside the attacker
	map.unit_positions[pid] = enemy.pos + Vector2i(1, 0)
	map.unit_positions[partner] = enemy.pos + Vector2i(2, 0)
	map.selected_unit_index = idx
	var target: Dictionary = map._nearest_enemy_in_range(map.unit_positions[pid], weapon)
	check(not target.is_empty(), "the enemy is in the attacker's range")

	# base hit chance vs. this enemy, and the support the partner's top rank would add to it
	var top_rank: String = _sup.max_rank(chain)
	var bonus: int = _sup.rank_effect(top_rank)["hit"]
	var base_hit: int = _combat.hit_chance(unit, enemy.archetype, weapon)
	check(base_hit + bonus < 100, "fixture: base hit %d leaves room for the +%d bonus" % [base_hit, bonus])
	var found := -1
	for seed_value in 2000:
		var r := RandomNumberGenerator.new()
		r.seed = seed_value
		var roll := r.randi_range(1, 100)
		if roll > base_hit and roll <= base_hit + bonus:
			found = seed_value
			break
	check(found >= 0, "found a seed whose roll falls in the support window (+%d hit)" % bonus)

	# no rank: that roll misses, and no support note
	var rng := RandomNumberGenerator.new(); rng.seed = found
	map.rng_override = rng
	map.attacked_this_turn.clear()
	map._attack_enemy()
	check(map.info_label.text.contains("misses") and not map.info_label.text.contains("Support with"),
		"without a rank the roll misses and no support is mentioned (got '%s')" % map.info_label.text)

	# top rank: the same roll hits, and the note names the partner, rank and effect
	_rank(chain, top_rank)
	var rng2 := RandomNumberGenerator.new(); rng2.seed = found
	map.rng_override = rng2
	map.attacked_this_turn.clear()
	enemy.hp = enemy.max_hp
	map._attack_enemy()
	var shown: bool = map.info_label.text.contains("Support with") and map.info_label.text.contains("rank %s" % _sup.current_rank(chain))
	check(shown, "with a rank the attack mentions the support (got '%s')" % map.info_label.text)
	check(map.info_label.text.contains("hits"), "and the +%d hit turns the pinned roll into a hit" % bonus)

	# too far away: no support
	map.unit_positions[partner] = enemy.pos + Vector2i(8, 8)
	var rng3 := RandomNumberGenerator.new(); rng3.seed = found
	map.rng_override = rng3
	map.attacked_this_turn.clear()
	enemy.hp = enemy.max_hp
	map._attack_enemy()
	check(not map.info_label.text.contains("Support with"), "a partner out of range gives no bonus")
	map.queue_free()
	await process_frame
