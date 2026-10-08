extends Node
## Autoload singleton: levels, EXP, stats, certification (promotion), abilities,
## gold and class unlocks for the 18 main units. Static data comes from Canon
## ("units", "classes", "unit_base_stats", "growths", "promotion_rules",
## "abilities"); per-playthrough state lives in GameState (progression, gold,
## unlocked_classes, income_claimed). Register after Canon, GameState and
## Equipment in project.godot.
##
## Rules (a design proposal -- see PROMOTION_DESIGN.md; every number is a row in
## canon's promotion_rules tab):
##   - Levels are one continuous scale. NO level cap, NO promotion gate: a unit
##     may stay unpromoted and keep levelling forever.
##   - Certification (promotion) is available from promote_min_level (15) and
##     costs gold: fee_base + fee_per_level for every level past 15, so the
##     earliest moment is the cheapest. It never resets a level. It gives a
##     flat stat jump, a growth bonus for every later level, an ability slot,
##     a movement type, and the high-tier weapons.
##   - Hybrid classes are only offered once their unlock map has been won.
##   - The paragon tier is a second certification at level 30 (paragon_min_level):
##     the unit must already be certified, have earned a deed that gates
##     paragon (epithets.gates_paragon -- boss kill, solo hold, no-hit map,
##     capture) and pay a bigger fee (same "earliest is cheapest" rise). It
##     gives another flat jump, more growth, a slot and a paragon class whose
##     primary art the unit already knows. Deeds are recorded during play and
##     never expire. Personal-class units take a milestone (no class change);
##     Kest's shadow line goes Thief -> Assassin / Trickster.
##   - Switching to another order class of the same art (recertifying) costs a
##     fraction of the promotion fee; level and earned stats are kept and only
##     the class's flat shape overlay changes.
##   - A unit first needed more than catchup_gap levels under the squad median
##     is raised to median - gap by its own expected growth, and units below the
##     median earn extra EXP.
##   - Abilities are chosen from the class's pool into a number of slots that
##     grows with level and promotion; until the player edits them a unit's kit
##     fills itself with sensible defaults.

const STATS: Array[String] = ["hp", "str", "mag", "dex", "spd", "lck", "def", "res"]
const ARTS: Array[String] = ["sword", "lance", "axe", "bow", "brawl", "reason", "faith"]
const PROMOTED_TIERS: Array[String] = ["order", "paragon", "hybrid"]

## The between-maps screen for all of this (opened with B on the overworld).
const SCREEN_SCENE := "res://scenes/barracks_screen.tscn"

var _params: Dictionary = {}     # param name -> number
var _shapes: Dictionary = {}     # movement type -> {stat: int}
var _abilities: Array = []       # ability rows, table order
var _indexed := false

func _ready() -> void:
	_index()

func _index() -> void:
	if _indexed:
		return
	_indexed = true
	for row in Canon.get_table("promotion_rules"):
		var key: String = String(row["param_id"]).trim_prefix("prm_")
		if key.begins_with("shape_"):
			var shape := {}
			for part in String(row.get("text") if row.get("text") != null else "").split("|", false):
				var kv := part.split(":")
				if kv.size() == 2:
					shape[kv[0]] = int(kv[1])
			_shapes[key.trim_prefix("shape_")] = shape
		elif row.get("value") != null:
			_params[key] = float(row["value"])
	_abilities = Canon.get_table("abilities")

func param(name: String) -> float:
	_index()
	return _params.get(name, 0.0)

# --------------------------------------------------------------- unit data

func _unit_row(unit_id: String) -> Dictionary:
	var row = Canon.find_by("units", "unit_id", unit_id)
	return row if row != null else {}

func _base_row(unit_id: String) -> Dictionary:
	var row = Canon.find_by("unit_base_stats", "unit_id", unit_id)
	return row if row != null else {}

func _profile(unit_id: String) -> Dictionary:
	var row = Canon.find_by("growths", "profile_id", _unit_row(unit_id).get("growth_profile_id", ""))
	return row if row != null else {}

func class_row(unit_id: String) -> Dictionary:
	var row = Canon.find_by("classes", "class_id", _peek(unit_id).get("class_id", ""))
	return row if row != null else {}

func is_known_unit(unit_id: String) -> bool:
	return not _unit_row(unit_id).is_empty() and not _base_row(unit_id).is_empty()

# ------------------------------------------------------------------ state

## A fresh state for a unit at its starting level and class (not stored).
func _default_state(unit_id: String) -> Dictionary:
	var base := _base_row(unit_id)
	var cls = Canon.find_by("classes", "class_id", _unit_row(unit_id)["base_class_id"])
	var gains := {}
	for s in STATS:
		gains[s] = 0
	return {
		"level": int(base["level"]), "exp": 0, "gains": gains,
		"class_id": _unit_row(unit_id)["base_class_id"],
		"promoted": cls != null and PROMOTED_TIERS.has(cls["tier"]),
		"shaped": false, "auto": true, "abilities": [], "paragon": false,
	}

## The unit's state WITHOUT creating it: the stored one, else a fresh default.
## Read-only accessors use this so merely looking at a unit (the convoy or
## barracks screens) never "joins" them to the squad early.
func _peek(unit_id: String) -> Dictionary:
	_index()
	if GameState.progression.has(unit_id):
		return GameState.progression[unit_id]
	return _default_state(unit_id) if is_known_unit(unit_id) else {}

## True once the unit has been fielded (its state exists).
func has_state(unit_id: String) -> bool:
	return GameState.progression.has(unit_id)

## The unit's progression state, created on first use. Creation is when
## late-joiner catch-up happens, so the battle map calls ensure() for everyone
## it deploys; anything that changes a unit (EXP, certification, abilities) goes
## through here too.
func state(unit_id: String) -> Dictionary:
	_index()
	if GameState.progression.has(unit_id):
		return GameState.progression[unit_id]
	if not is_known_unit(unit_id):
		return {}
	var st := _default_state(unit_id)
	var median := squad_median()
	GameState.progression[unit_id] = st      # registered before catch-up so growth bonuses read its state
	if median >= 0 and median - st["level"] > int(param("catchup_gap")):
		_apply_expected_levels(unit_id, median - int(param("catchup_gap")) - st["level"])
	return st

func ensure(unit_id: String) -> Dictionary:
	return state(unit_id)

func level(unit_id: String) -> int:
	return int(_peek(unit_id).get("level", 0))

func exp_of(unit_id: String) -> int:
	return int(_peek(unit_id).get("exp", 0))

func is_promoted(unit_id: String) -> bool:
	return bool(_peek(unit_id).get("promoted", false))

## True once the unit has taken the paragon tier (or is natively in a paragon class).
func is_paragon(unit_id: String) -> bool:
	var st := _peek(unit_id)
	return bool(st.get("paragon", false)) or class_tier(unit_id) == "paragon"

func class_id_of(unit_id: String) -> String:
	return String(_peek(unit_id).get("class_id", ""))

func class_name_of(unit_id: String) -> String:
	return String(class_row(unit_id).get("name", ""))

func class_tier(unit_id: String) -> String:
	return String(class_row(unit_id).get("tier", ""))

## Median level of every unit already in play, or -1 if there are none. The
## lower median for an even count, so a squad never "rounds up" onto a joiner.
func squad_median(exclude: String = "") -> int:
	var levels: Array = []
	for uid in GameState.progression:
		if uid != exclude:
			levels.append(int(GameState.progression[uid]["level"]))
	if levels.is_empty():
		return -1
	levels.sort()
	return levels[(levels.size() - 1) / 2]

# ------------------------------------------------------------------ stats

## Base stats (at the unit's starting level) + everything gained since + the
## flat shape of a certified class's movement type. HP never below 1.
func stats_for(unit_id: String) -> Dictionary:
	var st := _peek(unit_id)
	var base := _base_row(unit_id)
	if st.is_empty() or base.is_empty():
		return {}
	var out := {}
	var shape: Dictionary = _shapes.get(String(class_row(unit_id).get("movement", "")), {}) if st["shaped"] else {}
	for s in STATS:
		out[s] = int(base[s]) + int(st["gains"][s]) + int(shape.get(s, 0))
	out["hp"] = maxi(1, out["hp"])
	return out

## The growth rate (percent) the unit rolls for a stat on its next level-up.
func growth_rate(unit_id: String, stat: String) -> int:
	var rate := int(_profile(unit_id).get(stat, 0))
	if is_promoted(unit_id):
		rate += int(param("growth_bonus"))
	if is_paragon(unit_id):
		rate += int(param("paragon_growth_bonus"))
	return rate

## Raises a unit by `levels` levels using expected growth, not dice (late-joiner
## catch-up): each stat gains round(levels x rate / 100).
func _apply_expected_levels(unit_id: String, levels: int) -> void:
	if levels <= 0:
		return
	var st: Dictionary = GameState.progression[unit_id]
	for s in STATS:
		st["gains"][s] = int(st["gains"][s]) + int(round(levels * growth_rate(unit_id, s) / 100.0))
	st["level"] = int(st["level"]) + levels

# -------------------------------------------------------------------- EXP

## EXP for one fight: clamp(base + per_diff x (enemy level - unit level), min, max),
## plus, for a kill, clamp(kill_base + kill_per_diff x diff, 0, kill_max). Before
## multipliers.
func fight_exp(unit_level: int, enemy_level: int, killed: bool) -> int:
	var diff := enemy_level - unit_level
	var amount := clampi(int(param("exp_base")) + int(param("exp_per_diff")) * diff, int(param("exp_min")), int(param("exp_max")))
	if killed:
		amount += clampi(int(param("kill_base")) + int(param("kill_per_diff")) * diff, 0, int(param("kill_max")))
	return amount

## EXP multiplier: 1 + the unit's Quick Study-type abilities + underdog bonus
## (extra per level under the squad median, capped).
func exp_multiplier(unit_id: String) -> float:
	var pct := 0
	for ab in ability_effects(unit_id):
		pct += int(ab.get("exp_pct", 0))
	var median := squad_median(unit_id)
	var deficit := maxi(0, median - level(unit_id)) if median >= 0 else 0
	var underdog := minf(param("underdog_cap"), param("underdog_per_level") * deficit)
	return 1.0 + pct / 100.0 + underdog

## Grants EXP (already multiplied) and returns one entry per level gained:
## {"level": new level, "gains": {stat: 1}} -- the stats that rolled up.
func grant_exp(unit_id: String, amount: int, rng: RandomNumberGenerator) -> Array:
	var ups: Array = []
	var st := state(unit_id)
	if st.is_empty() or amount <= 0:
		return ups
	st["exp"] = int(st["exp"]) + amount
	var per := maxi(1, int(param("exp_per_level")))
	while int(st["exp"]) >= per:
		st["exp"] = int(st["exp"]) - per
		st["level"] = int(st["level"]) + 1
		var gained := {}
		for s in STATS:
			if rng.randi_range(1, 100) <= growth_rate(unit_id, s):
				st["gains"][s] = int(st["gains"][s]) + 1
				gained[s] = 1
		ups.append({"level": st["level"], "gains": gained})
	return ups

## One fight's EXP for a unit (multipliers applied). Returns
## {"exp": granted, "levelups": [...]}.
func award_fight(unit_id: String, enemy_level: int, killed: bool, rng: RandomNumberGenerator) -> Dictionary:
	var base := fight_exp(level(unit_id), enemy_level, killed)
	var amount := int(round(base * exp_multiplier(unit_id)))
	return {"exp": amount, "levelups": grant_exp(unit_id, amount, rng)}

## "Jost reaches level 6! (+HP +Str)" for a level-up entry; "" for none.
func describe_levelup(unit_name: String, up: Dictionary) -> String:
	var parts: Array[String] = []
	for s in STATS:
		if up["gains"].has(s):
			parts.append("+%s" % s.to_upper())
	return "%s reaches level %d! (%s)" % [unit_name, up["level"], " ".join(parts) if not parts.is_empty() else "no stat gains"]

# -------------------------------------------------------- gold and income

## Gold for winning a map: base + per enemy defeated, x(1 + factor bonus) if
## Kheldar's Factor class is still on the map ("end-map income").
func map_income(kills: int, factor_present: bool, captures: int = 0, routs: int = 0, talks: int = 0) -> int:
	var gold := param("income_base") + param("income_per_kill") * kills + param("income_per_capture") * captures \
		+ param("income_per_rout") * routs + param("income_per_talk") * talks
	if factor_present:
		gold *= 1.0 + param("income_factor_bonus")
	return int(round(gold))

## Pays a map's income once per playthrough. Returns the gold paid (0 if this
## map's income was already claimed).
func award_income(map_id: String, kills: int, factor_present: bool, captures: int = 0, routs: int = 0, talks: int = 0) -> int:
	if GameState.income_claimed.has(map_id):
		return 0
	GameState.income_claimed[map_id] = true
	var gold := map_income(kills, factor_present, captures, routs, talks)
	GameState.gold += gold
	return gold

## Unlocks every class whose unlock_map_id is this map; returns their names.
func on_map_won(map_id: String) -> Array:
	var names: Array = []
	for cls in Canon.get_table("classes"):
		var um = cls.get("unlock_map_id")
		if um != null and um == map_id and not GameState.unlocked_classes.has(cls["class_id"]):
			GameState.unlocked_classes[cls["class_id"]] = true
			names.append(cls["name"])
	return names

func is_class_unlocked(class_id: String) -> bool:
	var cls = Canon.find_by("classes", "class_id", class_id)
	if cls == null:
		return false
	var um = cls.get("unlock_map_id")
	return um == null or str(um) == "" or GameState.unlocked_classes.has(class_id)

# ------------------------------------------------------------ certification

## Gold to certify at a level: fee_base + fee_per_level for every level past
## the minimum. The earliest moment is the cheapest.
func promotion_fee(at_level: int) -> int:
	var over := maxi(0, at_level - int(param("promote_min_level")))
	return int(param("fee_base")) + int(param("fee_per_level")) * over

func recert_fee(at_level: int) -> int:
	return int(round(param("recert_fraction") * promotion_fee(at_level)))

## Classes a trained unit can certify into: its order classes (one per movement
## type) and any hybrids that grow from it. Each entry:
## {"class_id", "name", "tier", "movement", "locked": bool, "reason": String}.
## Personal-class units have a milestone instead (one entry: their own class);
## shadow units advance along their own line.
func promotion_options(unit_id: String) -> Array:
	var st := _peek(unit_id)
	var out: Array = []
	if st.is_empty() or st["promoted"]:
		return out
	var cur := class_row(unit_id)
	if cur.is_empty():
		return out
	if cur["tier"] == "personal":
		out.append(_option(cur))
		return out
	for cls in Canon.get_table("classes"):
		if cls.get("promotes_from") != cur["class_id"]:
			continue
		if not (PROMOTED_TIERS.has(cls["tier"]) or (cur["tier"] == "shadow" and cls["tier"] == "shadow")):
			continue
		out.append(_option(cls))
	return out

func _option(cls: Dictionary) -> Dictionary:
	var unlocked := is_class_unlocked(cls["class_id"])
	var um = cls.get("unlock_map_id")
	var reason := ""
	if not unlocked:
		var map_row = Canon.find_by("maps", "map_id", str(um))
		reason = "win %s to unlock" % (map_row["title"] if map_row != null else str(um))
	return {"class_id": cls["class_id"], "name": cls["name"], "tier": cls["tier"], "movement": cls["movement"],
		"locked": not unlocked, "reason": reason}

## {"ok": bool, "reason": String} for certifying into class_id now.
func can_promote(unit_id: String, class_id: String) -> Dictionary:
	var st := state(unit_id)
	if st.is_empty():
		return {"ok": false, "reason": "unknown unit"}
	if st["promoted"]:
		return {"ok": false, "reason": "already certified"}
	if int(st["level"]) < int(param("promote_min_level")):
		return {"ok": false, "reason": "needs level %d" % int(param("promote_min_level"))}
	var chosen := {}
	for o in promotion_options(unit_id):
		if o["class_id"] == class_id:
			chosen = o
	if chosen.is_empty():
		return {"ok": false, "reason": "not a class this unit can certify into"}
	if chosen["locked"]:
		return {"ok": false, "reason": chosen["reason"]}
	var fee := promotion_fee(int(st["level"]))
	if GameState.gold < fee:
		return {"ok": false, "reason": "needs %d gold (have %d)" % [fee, GameState.gold]}
	return {"ok": true, "reason": ""}

## Certifies: pays the fee, changes class, adds the flat jump, switches on the
## class shape and the growth bonus. Returns {"ok", "reason", "fee"}.
func promote(unit_id: String, class_id: String) -> Dictionary:
	var check := can_promote(unit_id, class_id)
	if not check["ok"]:
		check["fee"] = 0
		return check
	var st := state(unit_id)
	var fee := promotion_fee(int(st["level"]))
	GameState.gold -= fee
	st["class_id"] = class_id
	st["promoted"] = true
	st["shaped"] = true
	for s in STATS:
		st["gains"][s] = int(st["gains"][s]) + int(param("jump_%s" % s))
	_trim_abilities(unit_id)
	return {"ok": true, "reason": "", "fee": fee}

## The stats the unit would have right after certifying into class_id: now +
## the flat jump + that class's movement shape. Read-only; {} for an unknown
## unit or class.
func preview_promotion(unit_id: String, class_id: String) -> Dictionary:
	var cls = Canon.find_by("classes", "class_id", class_id)
	var now := stats_for(unit_id)
	if cls == null or now.is_empty():
		return {}
	var shape: Dictionary = _shapes.get(String(cls["movement"]), {})
	var cur_shape: Dictionary = _shapes.get(String(class_row(unit_id).get("movement", "")), {}) if _peek(unit_id)["shaped"] else {}
	var out := {}
	for s in STATS:
		out[s] = int(now[s]) - int(cur_shape.get(s, 0)) + int(param("jump_%s" % s)) * (0 if _peek(unit_id)["promoted"] else 1) + int(shape.get(s, 0))
	out["hp"] = maxi(1, out["hp"])
	return out

## Order classes of the same art the unit could switch to (not its current one).
func recertify_options(unit_id: String) -> Array:
	var st := _peek(unit_id)
	var cur := class_row(unit_id)
	var out: Array = []
	if st.is_empty() or not st["promoted"] or not st["shaped"] or cur.is_empty() or cur["tier"] != "order":
		return out
	for cls in Canon.get_table("classes"):
		if cls["tier"] == "order" and cls["art_primary"] == cur["art_primary"] and cls["class_id"] != cur["class_id"]:
			out.append(_option(cls))
	return out

func recertify(unit_id: String, class_id: String) -> Dictionary:
	var st := state(unit_id)
	var found := false
	for o in recertify_options(unit_id):
		if o["class_id"] == class_id:
			found = true
	if not found:
		return {"ok": false, "reason": "not an order class of the same art", "fee": 0}
	var fee := recert_fee(int(st["level"]))
	if GameState.gold < fee:
		return {"ok": false, "reason": "needs %d gold (have %d)" % [fee, GameState.gold], "fee": 0}
	GameState.gold -= fee
	st["class_id"] = class_id
	_trim_abilities(unit_id)
	return {"ok": true, "reason": "", "fee": fee}

# ---------------------------------------------------------------- abilities

## The tags a unit's current class answers to: any, each art, movement, tier, class.
func class_tags(unit_id: String) -> Array:
	var cls := class_row(unit_id)
	if cls.is_empty():
		return []
	var tags: Array = ["any", "move:%s" % cls["movement"], "tier:%s" % cls["tier"], "class:%s" % cls["class_id"]]
	for key in ["art_primary", "art_secondary"]:
		if ARTS.has(cls.get(key)):
			tags.append("art:%s" % cls[key])
	return tags

## Ability rows the unit may choose from, defaults first: class-specific, then
## tier, art, movement, then the generics (stable within each group).
func pool(unit_id: String) -> Array:
	_index()
	var tags := class_tags(unit_id)
	var scored: Array = []
	for i in _abilities.size():
		var best := 99
		for tag in String(_abilities[i]["pool"]).split("|", false):
			if tags.has(tag):
				best = mini(best, _tag_priority(tag))
		if best < 99:
			scored.append([best, i])
	scored.sort_custom(func(a, b): return a[0] < b[0] if a[0] != b[0] else a[1] < b[1])
	var out: Array = []
	for s in scored:
		out.append(_abilities[s[1]])
	return out

func _tag_priority(tag: String) -> int:
	if tag.begins_with("class:"):
		return 0
	if tag.begins_with("tier:"):
		return 1
	if tag.begins_with("art:"):
		return 2
	if tag.begins_with("move:"):
		return 3
	return 4

func slots(unit_id: String) -> int:
	var st := _peek(unit_id)
	if st.is_empty():
		return 0
	var every := maxi(1, int(param("slots_every")))
	var n := int(param("slots_base")) + int(st["level"]) / every
	if st["promoted"]:
		n += int(param("slots_promotion"))
	if st.get("paragon", false):
		n += int(param("paragon_slots"))
	return n

## The ability ids the unit has equipped: the player's picks if they have made
## any, otherwise the pool's defaults, never more than the slots.
func chosen(unit_id: String) -> Array:
	var st := _peek(unit_id)
	if st.is_empty():
		return []
	var ids: Array = []
	if st["auto"]:
		for row in pool(unit_id):
			ids.append(row["ability_id"])
	else:
		var allowed: Array = []
		for row in pool(unit_id):
			allowed.append(row["ability_id"])
		for id in st["abilities"]:
			if allowed.has(id):
				ids.append(id)
	return ids.slice(0, slots(unit_id))

## Replaces the unit's picks. False if more than the slots, duplicates, or any
## ability outside the class pool.
func set_abilities(unit_id: String, ids: Array) -> bool:
	var st := state(unit_id)
	if st.is_empty() or ids.size() > slots(unit_id):
		return false
	var allowed: Array = []
	for row in pool(unit_id):
		allowed.append(row["ability_id"])
	var seen := {}
	for id in ids:
		if not allowed.has(id) or seen.has(id):
			return false
		seen[id] = true
	st["auto"] = false
	st["abilities"] = ids.duplicate()
	return true

## Adds the ability if there is a free slot, removes it if already chosen.
## Returns the new chosen list, or null if the change was refused.
func toggle_ability(unit_id: String, ability_id: String):
	var cur := chosen(unit_id)
	if cur.has(ability_id):
		cur.erase(ability_id)
	else:
		cur.append(ability_id)
	return cur if set_abilities(unit_id, cur) else null

func _trim_abilities(unit_id: String) -> void:
	var st := state(unit_id)
	if not st["auto"]:
		st["abilities"] = chosen(unit_id)

func ability_row(ability_id: String) -> Dictionary:
	_index()
	for r in _abilities:
		if r["ability_id"] == ability_id:
			return r
	return {}

## The chosen abilities as plain effect dictionaries for Combat:
## {"ability_id", "cond", "hit", "avoid", "crit", "dodge", "dmg", "guard", "speed", "exp_pct"}.
func ability_effects(unit_id: String) -> Array:
	var out: Array = []
	for id in chosen(unit_id):
		var row := ability_row(id)
		if not row.is_empty():
			out.append(row)
	return out

## "+8 hit, +2 crit while wielding sword" -- one line describing an ability row.
func describe_ability(row: Dictionary) -> String:
	var parts: Array[String] = []
	for key in ["hit", "avoid", "crit", "dodge", "dmg", "guard", "speed", "exp_pct"]:
		var v := int(row.get(key, 0))
		if v != 0:
			parts.append("%+d %s" % [v, "EXP%" if key == "exp_pct" else key])
	var cond := String(row.get("cond", "always"))
	var when := ""
	match cond:
		"hp_full": when = " at full HP"
		"hp_low": when = " at half HP or less"
		_:
			if cond.begins_with("vs_"):
				when = " against %s units" % cond.trim_prefix("vs_")
			elif cond.begins_with("art:"):
				when = " with %s weapons" % cond.trim_prefix("art:")
	return ", ".join(parts) + when

# ------------------------------------------------------------ weapon tier

## High-tier weapons need a promoted class; basic, mid and worn are open.
func can_use_tier(unit_id: String, weapon_tier: String) -> bool:
	return weapon_tier != "high" or is_promoted(unit_id)

# ------------------------------------------------------------------- deeds

## Epithet rows that gate the paragon tier (epithets.gates_paragon == "yes").
func gating_epithets() -> Array:
	var out: Array = []
	for row in Canon.get_table("epithets"):
		if row.get("gates_paragon") == "yes":
			out.append(row)
	return out

func epithet_row(epithet_id: String) -> Dictionary:
	var row = Canon.find_by("epithets", "epithet_id", epithet_id)
	return row if row != null else {}

## Whether the game can currently record this deed (epithets.tracked).
func is_tracked(epithet_id: String) -> bool:
	return epithet_row(epithet_id).get("tracked") == "yes"

## unit_id -> {epithet_id: count} for one unit (a copy).
func deeds(unit_id: String) -> Dictionary:
	return GameState.deeds.get(unit_id, {}).duplicate()

## How many times a deed must be recorded before it counts as earned
## (epithets.count_needed: 1 for most, 5 for a capture deed).
func count_needed(epithet_id: String) -> int:
	var n = epithet_row(epithet_id).get("count_needed")
	return maxi(1, int(n)) if n != null else 1

## Times this deed has been recorded for the unit (progress, earned or not).
func deed_count(unit_id: String, epithet_id: String) -> int:
	return int(GameState.deeds.get(unit_id, {}).get(epithet_id, 0))

func has_deed(unit_id: String, epithet_id: String) -> bool:
	return deed_count(unit_id, epithet_id) >= count_needed(epithet_id)

## Records a deed for a unit. Returns true the moment they EARN it -- the record
## that takes the count up to epithets.count_needed -- so the caller can announce
## it once; false for repeats, earlier steps, unknown epithets and unknown units.
func record_deed(unit_id: String, epithet_id: String, count: int = 1) -> bool:
	if not is_known_unit(unit_id) or epithet_row(epithet_id).is_empty() or count <= 0:
		return false
	var mine: Dictionary = GameState.deeds.get(unit_id, {})
	var before := int(mine.get(epithet_id, 0))
	var need := count_needed(epithet_id)
	mine[epithet_id] = before + count
	GameState.deeds[unit_id] = mine
	return before < need and before + count >= need

## The terrain a terrain deed counts turn-ends on (epithets.deed_terrain), "" if it has none.
func deed_terrain(epithet_id: String) -> String:
	var t = epithet_row(epithet_id).get("deed_terrain")
	return str(t) if t != null else ""

## Deeds that don't gate paragon but can be recorded (epithets.tracked): forge vocabulary only.
func other_tracked_epithets() -> Array:
	var out: Array = []
	for row in Canon.get_table("epithets"):
		if row.get("gates_paragon") != "yes" and row.get("tracked") == "yes":
			out.append(row)
	return out

# ------------------------------------------------------- routing and talking

## Whether an enemy of this archetype breaks and flees at this HP: it has a flee
## threshold, isn't a boss, and is BELOW that percent of its max HP.
func is_routing(archetype: Dictionary, hp: int, max_hp: int, is_boss: bool) -> bool:
	var pct = archetype.get("flees_below_pct")
	return pct != null and not is_boss and max_hp > 0 and hp > 0 and hp * 100 < max_hp * int(pct)

## Whether this archetype can be talked to at all (it has a talk_mod).
func can_talk_to(archetype: Dictionary) -> bool:
	return archetype.get("talk_mod") != null

## Percent chance that a speaker with this Lck and level talks the enemy down:
## talk_base + talk_lck x Lck + talk_level x (speaker level - enemy level) + the
## archetype's talk_mod, kept between talk_min and talk_max. 0 if it can't be talked to.
func talk_chance(speaker_lck: int, speaker_level: int, archetype: Dictionary) -> int:
	if not can_talk_to(archetype):
		return 0
	var pct := param("talk_base") + param("talk_lck") * speaker_lck \
		+ param("talk_level") * (speaker_level - int(archetype.get("level", 1))) + int(archetype.get("talk_mod"))
	return clampi(int(round(pct)), int(param("talk_min")), int(param("talk_max")))

# ------------------------------------------------------------------- capture

## The map actions the unit's current class carries (classes.map_actions).
func map_actions(unit_id: String) -> Array:
	var acts = class_row(unit_id).get("map_actions")
	return [] if acts == null else Array(String(acts).split("|", false))

## Whether the unit's current class carries the Capture action: Gunnar's
## bounty hunter, and the Pardoner hybrid.
func can_capture(unit_id: String) -> bool:
	return "capture" in map_actions(unit_id)

## Tiles the unit's Shove/Smite pushes a target, before the target's weight is
## counted; 0 if the class has neither. A 'smite' class (the Housecarl) has the
## long push from the start; a 'shove' class (Gunnar) gets it on certification.
func shove_distance(unit_id: String) -> int:
	var acts := map_actions(unit_id)
	if "smite" in acts or ("shove" in acts and is_promoted(unit_id)):
		return int(param("smite_distance"))
	if "shove" in acts:
		return int(param("shove_distance"))
	return 0

## "Smite" for the long push, "Shove" for the short one ("" if the unit has neither).
func push_name(unit_id: String) -> String:
	var d := shove_distance(unit_id)
	if d <= 0:
		return ""
	return "Smite" if d >= int(param("smite_distance")) else "Shove"

## Whether the unit's current class carries the Bribe action (Kheldar's Factor).
func can_bribe(unit_id: String) -> bool:
	return "bribe" in map_actions(unit_id)

## Gold to turn an enemy of this level neutral: bribe_cost_base + bribe_cost_per_level x level.
func bribe_cost(enemy_level: int) -> int:
	return int(param("bribe_cost_base") + param("bribe_cost_per_level") * maxi(0, enemy_level))

## How many enemies a unit may bribe on one map.
func bribe_limit() -> int:
	return int(param("bribe_per_map"))

## Damage a Shove/Smite collision does to a unit with `hp` of `max_hp`:
## collision_pct of its max HP rounded down, never lethal (it stops at 1 HP).
func collision_damage(hp: int, max_hp: int) -> int:
	var dmg := int(floor(max_hp * param("collision_pct") / 100.0))
	return clampi(dmg, 0, maxi(0, hp - 1))

## How far a push of `distance` tiles actually moves a target of this movement
## type: armor resists shove_armor_resist tiles of it.
func push_distance_for(distance: int, target_movement: String) -> int:
	var resist := int(param("shove_armor_resist")) if target_movement == "armor" else 0
	return maxi(0, distance - resist)

## Whether an enemy can be captured right now. Bosses never can; anyone else
## must be at or below capture_hp_pct of their maximum HP. -> {"ok", "reason"}.
func capture_check(hp: int, max_hp: int, is_boss: bool) -> Dictionary:
	if is_boss:
		return {"ok": false, "reason": "a boss will not surrender"}
	var limit := int(floor(max_hp * param("capture_hp_pct") / 100.0))
	if hp > limit:
		return {"ok": false, "reason": "too strong to take (HP %d, needs %d or less)" % [hp, limit]}
	return {"ok": true, "reason": ""}

## The unit's earned deeds that gate paragon, as epithet ids in table order.
func gating_deeds_earned(unit_id: String) -> Array:
	var out: Array = []
	for row in gating_epithets():
		if has_deed(unit_id, row["epithet_id"]):
			out.append(row["epithet_id"])
	return out

# ------------------------------------------------------------ paragon tier

func paragon_fee(at_level: int) -> int:
	var over := maxi(0, at_level - int(param("paragon_min_level")))
	return int(param("paragon_fee_base")) + int(param("paragon_fee_per_level")) * over

## The classes a certified unit may take at the paragon tier, as option
## dictionaries like promotion_options. Rules: order and hybrid classes may take
## any paragon class whose primary art they know; a personal class takes a
## milestone (its own class); the shadow line continues to its children. Empty
## for uncertified units and for units already paragon.
func paragon_options(unit_id: String) -> Array:
	var st := _peek(unit_id)
	var out: Array = []
	if st.is_empty() or not st["promoted"] or is_paragon(unit_id):
		return out
	var cur := class_row(unit_id)
	if cur.is_empty():
		return out
	if cur["tier"] == "personal":
		out.append(_option(cur))
		return out
	if cur["tier"] == "shadow":
		for cls in Canon.get_table("classes"):
			if cls.get("promotes_from") == cur["class_id"] and cls["tier"] == "shadow":
				out.append(_option(cls))
		return out
	var arts: Array = []
	for key in ["art_primary", "art_secondary"]:
		if ARTS.has(cur.get(key)):
			arts.append(cur[key])
	for cls in Canon.get_table("classes"):
		if cls["tier"] == "paragon" and arts.has(cls["art_primary"]):
			out.append(_option(cls))
	return out

## The checklist for taking a paragon class: each item {"label", "ok", "detail"}.
func paragon_requirements(unit_id: String) -> Array:
	var st := _peek(unit_id)
	var need_level := int(param("paragon_min_level"))
	var need_deeds := int(param("paragon_deeds_required"))
	var earned := gating_deeds_earned(unit_id)
	var level_now := int(st.get("level", 0))
	var fee := paragon_fee(level_now)
	return [
		{"label": "Certified", "ok": bool(st.get("promoted", false)), "detail": "take the first tier at level %d" % int(param("promote_min_level"))},
		{"label": "Level %d" % need_level, "ok": level_now >= need_level, "detail": "level %d" % level_now},
		{"label": "%d deed%s that gate%s paragon" % [need_deeds, "" if need_deeds == 1 else "s", "s" if need_deeds == 1 else ""], "ok": earned.size() >= need_deeds,
			"detail": "%d earned" % earned.size()},
		{"label": "%d gold" % fee, "ok": GameState.gold >= fee, "detail": "you have %d" % GameState.gold},
	]

## {"ok": bool, "reason": String} for taking class_id at the paragon tier now.
func can_paragon(unit_id: String, class_id: String) -> Dictionary:
	var st := state(unit_id)
	if st.is_empty():
		return {"ok": false, "reason": "unknown unit"}
	if is_paragon(unit_id):
		return {"ok": false, "reason": "already paragon"}
	if not st["promoted"]:
		return {"ok": false, "reason": "certify first"}
	if int(st["level"]) < int(param("paragon_min_level")):
		return {"ok": false, "reason": "needs level %d" % int(param("paragon_min_level"))}
	if gating_deeds_earned(unit_id).size() < int(param("paragon_deeds_required")):
		return {"ok": false, "reason": "needs a deed that gates paragon"}
	var chosen := {}
	for o in paragon_options(unit_id):
		if o["class_id"] == class_id:
			chosen = o
	if chosen.is_empty():
		return {"ok": false, "reason": "not a paragon class this unit can take"}
	if chosen["locked"]:
		return {"ok": false, "reason": chosen["reason"]}
	var fee := paragon_fee(int(st["level"]))
	if GameState.gold < fee:
		return {"ok": false, "reason": "needs %d gold (have %d)" % [fee, GameState.gold]}
	return {"ok": true, "reason": ""}

## Takes the paragon tier: pays the fee, changes class (a personal milestone
## keeps its class), adds the paragon jump, switches on the class's shape, and
## raises growth and slots. Returns {"ok", "reason", "fee"}.
func take_paragon(unit_id: String, class_id: String) -> Dictionary:
	var check := can_paragon(unit_id, class_id)
	if not check["ok"]:
		check["fee"] = 0
		return check
	var st := state(unit_id)
	var fee := paragon_fee(int(st["level"]))
	GameState.gold -= fee
	st["class_id"] = class_id
	st["paragon"] = true
	st["shaped"] = true
	for s in STATS:
		st["gains"][s] = int(st["gains"][s]) + int(param("paragon_jump_%s" % s))
	_trim_abilities(unit_id)
	return {"ok": true, "reason": "", "fee": fee}

## The stats after taking class_id at the paragon tier. Read-only; {} if unknown.
func preview_paragon(unit_id: String, class_id: String) -> Dictionary:
	var cls = Canon.find_by("classes", "class_id", class_id)
	var now := stats_for(unit_id)
	if cls == null or now.is_empty():
		return {}
	var new_shape: Dictionary = _shapes.get(String(cls["movement"]), {})
	var cur_shape: Dictionary = _shapes.get(String(class_row(unit_id).get("movement", "")), {}) if _peek(unit_id)["shaped"] else {}
	var out := {}
	for s in STATS:
		out[s] = int(now[s]) - int(cur_shape.get(s, 0)) + int(param("paragon_jump_%s" % s)) + int(new_shape.get(s, 0))
	out["hp"] = maxi(1, out["hp"])
	return out
