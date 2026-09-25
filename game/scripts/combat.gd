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
## just in the abstract. Adjacent finding, NOT addressed here (out of
## scope for the triangle specifically): crit is close to nonfunctional
## game-wide -- every one of the 28 weapons has crit=0, so crit_chance is
## pure dex/2 - defender_lck, which clears zero in only 52 of 270 real
## attacker/defender combos this session tested, usually by 1-4%. That's
## a crit-formula/weapon-data calibration question, a separate pass.
##
## Stat dicts use growths.gd's own column names (str, mag, dex, spd, lck,
## def, res) so they'll drop in directly once real current-stat generation
## exists, plus a weapon_art key (the DEFENDER's own equipped weapon's art,
## needed to resolve the triangle from their side). Weapon dicts (the
## attacker's weapon, passed separately): {art: String, might: int,
## hit: int, crit: int}.

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

static func is_magic_art(art: String) -> bool:
	return MAGIC_ARTS.has(art)

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
	var mod := triangle_modifier(weapon.get("art", ""), defender.get("weapon_art", ""))
	var atk_hit: float = weapon.get("hit", 0) + attacker.get("dex", 0) * 2 + attacker.get("lck", 0) / 2.0
	var def_avoid: float = defender.get("spd", 0) * 2 + defender.get("lck", 0)
	return clampi(int(round(atk_hit - def_avoid + mod.hit)), 0, 100)

## crit = weapon_crit + dex/2, minus defender's lck as crit avoid.
## Clamped to [0, 100]. Triangle does not affect crit in this design.
static func crit_chance(attacker: Dictionary, defender: Dictionary, weapon: Dictionary) -> int:
	var atk_crit: float = weapon.get("crit", 0) + attacker.get("dex", 0) / 2.0
	var def_crit_avoid: float = defender.get("lck", 0)
	return clampi(int(round(atk_crit - def_crit_avoid)), 0, 100)

## Physical arts use str/def; reason/faith use mag/res. Triangle adds a flat
## damage bonus/penalty. A crit triples the pre-mitigation attack power
## (classic FE convention) before defense is subtracted. Floored at 0.
static func damage(attacker: Dictionary, defender: Dictionary, weapon: Dictionary, is_crit: bool) -> int:
	var art: String = weapon.get("art", "")
	var mod := triangle_modifier(art, defender.get("weapon_art", ""))
	var atk_power: float = attacker.get("mag", 0) if is_magic_art(art) else attacker.get("str", 0)
	var mitigation: float = defender.get("res", 0) if is_magic_art(art) else defender.get("def", 0)
	var might: float = weapon.get("might", 0) + mod.damage
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
