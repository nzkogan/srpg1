class_name Combat
## Pure combat-math functions: weapon triangle, hit/crit/damage. No autoload,
## no dependency on canon.db -- there's no base-stat table for the 18 main
## units yet (growths.gd's source table holds per-level-up GROWTH RATES, not
## usable current stats) and no weapons table at all, so this takes stat and
## weapon data as plain Dictionaries rather than reading Canon directly.
## Wire it up once real per-unit stats and a weapons table exist.
##
## Every number below is a placeholder in the sense that nothing in
## canon.xlsx specifies it -- "weapon triangle" is only ever mentioned
## descriptively there ("teaches: movement, terrain cost, the weapon
## triangle -- nothing else"), never as actual relationships or a formula.
## These are standard Fire-Emblem-genre conventions (this design's own
## stated lineage, "mechanically descended from Fire Emblem," per
## PROJECT_HANDOFF.md), not sourced numbers. Revisit freely.
##
## TRIANGLE_HIT_BONUS/TRIANGLE_DAMAGE_BONUS calibrated 2026-09-25:
## simulated triangle_modifier against every real weapon (game/data/
## weapons.json) x unit_base_stats.json x enemy_archetypes.json matchup
## across all four tiers (commoner/trained/order/paragon), then confirmed
## the headline figures by actually calling this script's own functions
## in a headless Godot run (a first Python replica was off by 1 on a .5
## case -- GDScript's round() rounds half away from zero, Python's rounds
## half to even -- so these numbers are the verified in-engine output,
## not the Python estimate). 15 hit moves a near-certain hit (81 vs 96%,
## disadvantage) or a real-but-clear favorite (77 vs 62%, advantage)
## without ever forcing a hard 0/100 by itself; 1 damage is a real but
## modest swing against typical mid-game hit damage (5-9 in these same
## matchups). Left both values unchanged -- they already produce
## sensible, non-degenerate outcomes against the actual content, not
## just in the abstract. Adjacent finding from this same pass, addressed
## separately below (crit_chance's own comment): crit was close to
## nonfunctional game-wide under its original dex/2 weighting -- fixed
## there, not here, since it's a different formula/constant than the
## triangle.
##
## Stat dicts use growths.gd's own column names (str, mag, dex, spd, lck,
## def, res) so they'll drop in directly once real current-stat generation
## exists, plus a weapon_art key (the DEFENDER's own equipped weapon's art,
## needed to resolve the triangle from their side). Weapon dicts (the
## attacker's weapon, passed separately): {art: String, might: int,
## hit: int, crit: int}.
##
## Abilities (Progression) arrive as an optional "abilities" array of effect
## dictionaries on a stat dict (hit/avoid/crit/dodge/dmg/guard/speed, each with a
## "cond"), plus "cur_hp"/"max_hp" for the HP conditions. No key = no effect.
##
## Support effects (Supports.RANK_EFFECTS) arrive as optional keys on the
## stat dicts, all default 0 when absent: sup_hit / sup_crit on the attacker,
## sup_avoid / sup_dodge on the defender. Supports.combat_keys() builds them.

## sword > axe > lance > sword. Bow/brawl/reason/faith sit outside the
## triangle entirely (including against each other) -- with only two magic
## arts (reason, faith) there's no third point to form a real triangle from,
## so no magic-side rivalry is invented here.
const TRIANGLE_BEATS := {
	"sword": "axe",
	"axe": "lance",
	"lance": "sword",
}

const TRIANGLE_HIT_BONUS := 15
const TRIANGLE_DAMAGE_BONUS := 1

const MAGIC_ARTS := ["reason", "faith"]

## Overlap (hybrid) weapons -- weapons.req_arts lists 2+ arts a wielder must
## ALL be proficient in. The weapon's own `art` still decides physical vs
## magic damage; for the triangle it counts as HYBRID_ART, which beats and
## loses to nothing: a weapon that hedges two faces gets neither the edge nor
## the penalty of either. Drafted 2026-10-02, not canon.
const HYBRID_ART := "hybrid"

## A unit whose attack speed is at least this much higher than its opponent's
## strikes twice (the classic follow-up attack).
const DOUBLE_SPEED_GAP := 4

## weapons.effective_vs: might is multiplied by this against the listed
## movement types ("riding" for the halberd, "armor" for the maul).
const EFFECTIVE_MULT := 2

static func is_magic_art(art: String) -> bool:
	return MAGIC_ARTS.has(art)

## Sum of one effect (hit, avoid, crit, dodge, dmg, guard, speed) over a unit's
## abilities whose condition holds against `foe` while wielding `weapon`.
static func ability_bonus(unit: Dictionary, foe: Dictionary, weapon: Dictionary, key: String) -> int:
	var total := 0
	for ab in unit.get("abilities", []):
		var v := int(ab.get(key, 0))
		if v != 0 and _cond_ok(String(ab.get("cond", "always")), unit, foe, weapon):
			total += v
	return total

static func _cond_ok(cond: String, unit: Dictionary, foe: Dictionary, weapon: Dictionary) -> bool:
	match cond:
		"always":
			return true
		"hp_full":
			return unit.has("max_hp") and int(unit.get("cur_hp", 0)) >= int(unit["max_hp"])
		"hp_low":
			return unit.has("max_hp") and int(unit.get("cur_hp", 0)) * 2 <= int(unit["max_hp"])
	if cond.begins_with("vs_"):
		return foe.get("movement_type", "") == cond.trim_prefix("vs_")
	if cond.begins_with("art:"):
		return weapon.get("art", "") == cond.trim_prefix("art:")
	return false

static func _pipe(value) -> Array:
	if value == null or str(value) == "":
		return []
	var out: Array = []
	for part in str(value).split("|"):
		out.append(part.strip_edges())
	return out

## The arts a wielder needs: req_arts when set, otherwise just the weapon's own.
static func required_arts(weapon: Dictionary) -> Array:
	var req := _pipe(weapon.get("req_arts"))
	return req if not req.is_empty() else [weapon.get("art", "")]

static func is_hybrid(weapon: Dictionary) -> bool:
	return required_arts(weapon).size() > 1

## True if every art the weapon requires is among the unit's proficient arts.
static func can_wield(unit_arts: Array, weapon: Dictionary) -> bool:
	for art in required_arts(weapon):
		if not unit_arts.has(art):
			return false
	return true

## What the triangle sees: the weapon's art, or HYBRID_ART for overlap weapons.
static func triangle_art(weapon: Dictionary) -> String:
	return HYBRID_ART if is_hybrid(weapon) else String(weapon.get("art", ""))

## True if the weapon is effective against this defender's movement type.
static func is_effective(weapon: Dictionary, defender: Dictionary) -> bool:
	return _pipe(weapon.get("effective_vs")).has(defender.get("movement_type", ""))

## Attack speed = spd, less whatever the weapon's weight exceeds the wielder's
## strength by (magic weapons burden against mag instead). The weights in
## weapons.json (5 / 8 / 10, 12-13 for the overlap melee weapons) against
## typical str 5-8 mean basic weapons cost nothing and heavy ones bite.
static func attack_speed(unit: Dictionary, weapon: Dictionary) -> int:
	var stat := "mag" if is_magic_art(String(weapon.get("art", ""))) else "str"
	var burden := maxi(0, int(weapon.get("weight", 0)) - int(unit.get(stat, 0)))
	return int(unit.get("spd", 0)) - burden + ability_bonus(unit, {}, weapon, "speed")

## Returns {hit: int, damage: int} modifiers for attacker_art vs defender_art
## -- positive for advantage, negative for disadvantage, zero otherwise.
static func triangle_modifier(attacker_art: String, defender_art: String) -> Dictionary:
	if TRIANGLE_BEATS.get(attacker_art) == defender_art:
		return {"hit": TRIANGLE_HIT_BONUS, "damage": TRIANGLE_DAMAGE_BONUS}
	if TRIANGLE_BEATS.get(defender_art) == attacker_art:
		return {"hit": -TRIANGLE_HIT_BONUS, "damage": -TRIANGLE_DAMAGE_BONUS}
	return {"hit": 0, "damage": 0}

## Classic FE-style: hit = weapon_hit + dex*2 + lck/2, avoid = spd*2 + lck,
## plus the triangle's hit modifier. Clamped to [0, 100].
static func hit_chance(attacker: Dictionary, defender: Dictionary, weapon: Dictionary) -> int:
	var mod := triangle_modifier(triangle_art(weapon), defender.get("weapon_art", ""))
	var atk_hit: float = weapon.get("hit", 0) + attacker.get("dex", 0) * 2 + attacker.get("lck", 0) / 2.0 \
		+ attacker.get("sup_hit", 0) + ability_bonus(attacker, defender, weapon, "hit")
	var def_avoid: float = defender.get("spd", 0) * 2 + defender.get("lck", 0) + defender.get("sup_avoid", 0) \
		+ ability_bonus(defender, attacker, {}, "avoid")
	return clampi(int(round(atk_hit - def_avoid + mod.hit)), 0, 100)

## crit = weapon_crit + dex, minus defender's lck as crit avoid. Clamped
## to [0, 100]. Triangle does not affect crit in this design.
##
## Calibrated 2026-09-25: the original dex/2 halving, combined with every
## one of the 28 weapons in game/data/weapons.json having crit=0, made
## this near-nonfunctional -- simulated against every real unit_base_
## stats.json x enemy_archetypes.json attacker/defender pair (1,056
## ordered combos, both directions): only 18.8% had ANY nonzero chance,
## averaging 0.56% and topping out at 10%. Tested three alternatives
## (full dex, half-both dex/lck, dex*0.75) against the same 1,056 combos;
## full dex -- simply removing the halving, no new constants introduced
## -- gave the healthiest spread (57.5% nonzero, mean 3.4%, max 21%,
## never runaway) without inventing an arbitrary weighting. weapon crit
## staying at 0 everywhere is a separate, not-yet-addressed calibration
## question (weapons.json data, not this formula).
static func crit_chance(attacker: Dictionary, defender: Dictionary, weapon: Dictionary) -> int:
	var atk_crit: float = weapon.get("crit", 0) + attacker.get("dex", 0) + attacker.get("sup_crit", 0) \
		+ ability_bonus(attacker, defender, weapon, "crit")
	var def_crit_avoid: float = defender.get("lck", 0) + defender.get("sup_dodge", 0) + ability_bonus(defender, attacker, {}, "dodge")
	return clampi(int(round(atk_crit - def_crit_avoid)), 0, 100)

## Physical arts use str/def; reason/faith use mag/res. Triangle adds a flat
## damage bonus/penalty. A crit triples the pre-mitigation attack power
## (classic FE convention) before defense is subtracted. Floored at 0.
static func damage(attacker: Dictionary, defender: Dictionary, weapon: Dictionary, is_crit: bool) -> int:
	var art: String = weapon.get("art", "")
	var mod := triangle_modifier(triangle_art(weapon), defender.get("weapon_art", ""))
	var atk_power: float = attacker.get("mag", 0) if is_magic_art(art) else attacker.get("str", 0)
	var mitigation: float = (defender.get("res", 0) if is_magic_art(art) else defender.get("def", 0)) \
		+ ability_bonus(defender, attacker, {}, "guard")
	var base_might: float = weapon.get("might", 0) * (EFFECTIVE_MULT if is_effective(weapon, defender) else 1)
	var might: float = base_might + mod.damage + ability_bonus(attacker, defender, weapon, "dmg")
	var power := atk_power + might
	if is_crit:
		power *= 3
	return maxi(0, int(round(power - mitigation)))

## Combines the three above into one outcome, using the given RNG so results
## are reproducible in tests (pass a seeded RandomNumberGenerator).
## Returns {hit: bool, crit: bool, damage: int}.
static func resolve_attack(attacker: Dictionary, defender: Dictionary, weapon: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var hit_roll := rng.randi_range(1, 100)
	var did_hit := hit_roll <= hit_chance(attacker, defender, weapon)
	if not did_hit:
		return {"hit": false, "crit": false, "damage": 0}
	var crit_roll := rng.randi_range(1, 100)
	var did_crit := crit_roll <= crit_chance(attacker, defender, weapon)
	var dmg := damage(attacker, defender, weapon, did_crit)
	return {"hit": true, "crit": did_crit, "damage": dmg}

# --------------------------------------------------------- forecast & exchange

## Whether a defender's weapon can answer an attack from `distance` tiles.
static func can_counter(def_weapon: Dictionary, distance: int) -> bool:
	if def_weapon.is_empty():
		return false
	return distance >= int(def_weapon.get("range_min", 1)) and distance <= int(def_weapon.get("range_max", 1))

## One fighter's side of an exchange: what each of their strikes does, how
## often it lands, how many strikes they get, and how the triangle and
## effectiveness treat them. `me`/`foe` are stat dicts (movement_type and the
## sup_* keys optional); the weapon_art key is overridden here from the
## weapons themselves so overlap weapons read as triangle-neutral.
static func _side(me: Dictionary, foe: Dictionary, my_weapon: Dictionary, foe_weapon: Dictionary) -> Dictionary:
	var me_view := me.duplicate()
	me_view["weapon_art"] = triangle_art(my_weapon)
	var foe_view := foe.duplicate()
	foe_view["weapon_art"] = triangle_art(foe_weapon) if not foe_weapon.is_empty() else ""
	var tri := triangle_modifier(triangle_art(my_weapon), foe_view["weapon_art"])
	return {
		"damage": damage(me_view, foe_view, my_weapon, false),
		"crit_damage": damage(me_view, foe_view, my_weapon, true),
		"hit": hit_chance(me_view, foe_view, my_weapon),
		"crit": crit_chance(me_view, foe_view, my_weapon),
		"speed": attack_speed(me, my_weapon),
		"triangle": signi(int(tri.hit)),
		"effective": is_effective(my_weapon, foe),
		"hits": 1,
	}

## Everything a forecast panel needs, for `attacker` striking `defender` from
## `distance` tiles: {"distance", "atk": side, "def": side or {} if the defender
## can't answer, "def_speed": the defender's attack speed either way}. A side's "hits" is 2 when its speed beats the other's by
## DOUBLE_SPEED_GAP or more (only a side that can actually strike can double).
static func forecast(attacker: Dictionary, defender: Dictionary, atk_weapon: Dictionary,
		def_weapon: Dictionary, distance: int) -> Dictionary:
	var atk := _side(attacker, defender, atk_weapon, def_weapon)
	var counters := can_counter(def_weapon, distance)
	var def := _side(defender, attacker, def_weapon, atk_weapon) if counters else {}
	# A defender who can't answer still has a speed (unarmed ones just use spd),
	# so the attacker can follow up on speed alone.
	var def_speed: int = def["speed"] if counters else \
		(attack_speed(defender, def_weapon) if not def_weapon.is_empty() else int(defender.get("spd", 0)))
	if atk["speed"] - def_speed >= DOUBLE_SPEED_GAP:
		atk["hits"] = 2
	elif counters and def_speed - atk["speed"] >= DOUBLE_SPEED_GAP:
		def["hits"] = 2
	return {"distance": distance, "atk": atk, "def": def, "def_speed": def_speed}

static func _strike(side: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var hit_roll := rng.randi_range(1, 100)
	if hit_roll > int(side["hit"]):
		return {"hit": false, "crit": false, "damage": 0}
	var crit_roll := rng.randi_range(1, 100)
	var did_crit := crit_roll <= int(side["crit"])
	return {"hit": true, "crit": did_crit, "damage": int(side["crit_damage"] if did_crit else side["damage"])}

## Plays a forecast out with real rolls. Order: attacker, defender's counter,
## then the follow-up for whichever side doubles. A fighter at 0 HP stops the
## exchange. atk_uses / def_uses are the weapons' remaining uses (-1 =
## unlimited, e.g. enemies): each strike spends one, and a side whose weapon is
## at 0 can't strike -- the strike that spends the last use is flagged
## "broke". Returns {"strikes": [{by: "atk"|"def", hit, crit, damage,
## target_hp, broke}], "atk_hp", "def_hp", "atk_strikes", "def_strikes",
## "atk_uses", "def_uses"}.
static func resolve_exchange(attacker: Dictionary, defender: Dictionary, atk_weapon: Dictionary,
		def_weapon: Dictionary, distance: int, rng: RandomNumberGenerator,
		atk_hp: int, def_hp: int, atk_uses: int = -1, def_uses: int = -1) -> Dictionary:
	var fc := forecast(attacker, defender, atk_weapon, def_weapon, distance)
	var order: Array[String] = ["atk"]
	if not fc["def"].is_empty():
		order.append("def")
	if fc["atk"]["hits"] > 1:
		order.append("atk")
	elif not fc["def"].is_empty() and fc["def"]["hits"] > 1:
		order.append("def")
	var strikes: Array = []
	var made := {"atk": 0, "def": 0}
	for who in order:
		if atk_hp <= 0 or def_hp <= 0:
			break
		var uses: int = atk_uses if who == "atk" else def_uses
		if uses == 0:
			continue   # a broken weapon strikes no more
		var res := _strike(fc[who], rng)
		if who == "atk":
			def_hp = maxi(0, def_hp - int(res["damage"]))
			res["target_hp"] = def_hp
			if atk_uses > 0:
				atk_uses -= 1
		else:
			atk_hp = maxi(0, atk_hp - int(res["damage"]))
			res["target_hp"] = atk_hp
			if def_uses > 0:
				def_uses -= 1
		res["broke"] = uses > 0 and (atk_uses if who == "atk" else def_uses) == 0
		res["by"] = who
		made[who] += 1
		strikes.append(res)
	return {"strikes": strikes, "atk_hp": atk_hp, "def_hp": def_hp,
		"atk_strikes": made["atk"], "def_strikes": made["def"], "atk_uses": atk_uses, "def_uses": def_uses}
