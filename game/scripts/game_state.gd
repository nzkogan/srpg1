extends Node
## Runtime playthrough state -- flags set by player choices during play,
## distinct from Canon's static canon.xlsx-derived reference data. Canon
## never changes at runtime; this does. In-memory only for now (resets on
## restart) -- save/load persistence is a separate, unrequested feature.
##
## Flag ids/allowed_values are documented in canon.xlsx's canon_flags tab;
## this autoload doesn't validate against that table at runtime, it just
## holds whatever gets set.

var flags: Dictionary = {}

## chain_id -> highest support rank reached this playthrough ("C"/"B"/"A"/"S").
## Absent means no rank yet. This is a dumb store: the rank rules (order, S only
## on romance chains) live in the Supports autoload, so go through
## Supports.raise_rank() rather than calling set_support_rank() directly.
var support_ranks: Dictionary = {}

## chain_id -> support points banked this playthrough. Points are earned per
## map and only committed here when that map is won (see Supports.settle_map).
var support_points: Dictionary = {}

## map_id -> true once that map's support points have been banked, so
## replaying a won map can't farm points a second time.
var support_settled_maps: Dictionary = {}

## chain_id -> rank raised by the most recently won map (set by
## Supports.settle_map). The support viewer tags these NEW and can jump
## between them. Replaced each time a new map is won.
var support_recent: Dictionary = {}

## One-shot: a chain id for the support viewer to open on, then clear. Set by
## the win screen's S key.
var support_focus: String = ""

## Player equipment (see Equipment autoload). unit_id -> Array of
## {"weapon_id", "uses"}; the first wieldable entry is the equipped weapon.
var inventories: Dictionary = {}

## The shared convoy: Array of {"weapon_id", "uses"}. Filled once per
## playthrough from weapons.convoy_qty, then by boss drops.
var convoy: Array = []

## True once the convoy has been seeded from canon for this playthrough.
var equipment_ready := false

## spawn_id -> true once that enemy's drop has been taken, so replaying a map
## can't farm it.
var drops_claimed: Dictionary = {}

func set_flag(flag_id: String, value: String) -> void:
	flags[flag_id] = value

func get_flag(flag_id: String, default_value = null):
	return flags.get(flag_id, default_value)

func has_flag(flag_id: String) -> bool:
	return flags.has(flag_id)

func get_support_rank(chain_id: String) -> String:
	return support_ranks.get(chain_id, "")

func set_support_rank(chain_id: String, rank: String) -> void:
	support_ranks[chain_id] = rank
