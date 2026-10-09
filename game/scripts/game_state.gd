extends Node
## Runtime playthrough state -- flags set by player choices during play,
## distinct from Canon's static canon.xlsx-derived reference data. Canon
## never changes at runtime; this does. The SaveGame autoload writes it to
## disk: every variable below is either listed in PERSISTED (saved and
## restored) or in TRANSIENT (deliberately not), and a test fails if a new
## variable is added to neither -- so state can't silently go unsaved.
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

## Progression (see the Progression autoload). unit_id -> {"level", "exp",
## "gains": {stat: int}, "class_id", "promoted", "shaped", "auto", "abilities"}.
## Created the first time a unit is needed, so late joiners can be caught up.
var progression: Dictionary = {}

## Gold: earned at the end of maps, spent on certification.
var gold := 0

## class_id -> true once its unlock map has been won (hybrid classes).
var unlocked_classes: Dictionary = {}

## map_id -> true once that map's income has been paid, so replays can't farm.
var income_claimed: Dictionary = {}

## Deeds (epithets) earned: unit_id -> {epithet_id: count}. Kept for the whole
## playthrough; they never expire, so no deed can be missed. See Progression.
var deeds: Dictionary = {}

## map_id -> true once won (any playthrough action that wins it).
var won_maps: Dictionary = {}

## The forge (see the Forge autoload). materials: material_id -> "prime" | "diminished" for the
## beast materials held right now; materials_claimed: material_id -> true once one has ever been
## taken (one per Named per run, so replays can't farm it); forge_orders: Array of commissions
## {forge_id, material_id, weapon_id, quality, chapters_left, ready}; works_started: master
## works commissioned so far (capped).
var materials: Dictionary = {}
var materials_claimed: Dictionary = {}
var forge_orders: Array = []
var works_started: int = 0

## Defections (see the Defections autoload). defections: defection_id -> {"state": "gone" |
## "returned", "map", "class_id", "level", "stats", "titles", "carried" (the weapons they
## took), "fallen"}; guests: guest_id -> "departed" once a guest has left.
var defections: Dictionary = {}
var guests: Dictionary = {}

## The crown's ledger and its deputy (see the Deputy autoload). deputy_ledger: unit_id ->
## {factor_id: how many times}; deputy: {} until the writ scene, then {"unit", "contested"}.
var deputy_ledger: Dictionary = {}
var deputy: Dictionary = {}

## The fallen (see the Epilogue autoload): {"deaths": unit_id -> record, "pending": unit_id ->
## record (fallen on a map not yet won -- discarded if the map is retried), "slain": unit_id ->
## [what they killed that earned 'Slayer of'], "seq": deaths so far}.
var epilogue: Dictionary = {}

## A suspended battle (a mid-map save): {} when there is none, else the snapshot
## map_grid.gd's capture_state() made -- the map, the turn, every unit and enemy -- plus
## a copy of the rest of the playthrough as it was, so resuming rolls everything back
## to that moment. Cleared when that map is won; kept if it is lost or left, so you can
## go back to the save. See map_grid.gd and overworld.gd.
var battle: Dictionary = {}

## Where the party stands on the overworld (a locations.location_id); "" before
## it has gone anywhere. See overworld.gd.
var world_location: String = ""

## Variables that are saved, with the type each must have in a save file.
## Adding gameplay state here is all it takes to persist it.
const PERSISTED := {
	"flags": TYPE_DICTIONARY, "support_ranks": TYPE_DICTIONARY, "support_points": TYPE_DICTIONARY,
	"support_settled_maps": TYPE_DICTIONARY, "support_recent": TYPE_DICTIONARY,
	"inventories": TYPE_DICTIONARY, "convoy": TYPE_ARRAY, "equipment_ready": TYPE_BOOL,
	"drops_claimed": TYPE_DICTIONARY, "progression": TYPE_DICTIONARY, "gold": TYPE_INT,
	"unlocked_classes": TYPE_DICTIONARY, "income_claimed": TYPE_DICTIONARY,
	"deeds": TYPE_DICTIONARY, "won_maps": TYPE_DICTIONARY, "world_location": TYPE_STRING,
	"battle": TYPE_DICTIONARY,
	"materials": TYPE_DICTIONARY, "materials_claimed": TYPE_DICTIONARY, "forge_orders": TYPE_ARRAY, "works_started": TYPE_INT,
	"defections": TYPE_DICTIONARY, "guests": TYPE_DICTIONARY,
	"deputy_ledger": TYPE_DICTIONARY, "deputy": TYPE_DICTIONARY, "epilogue": TYPE_DICTIONARY,
}

## Variables that are deliberately not saved: one-shot UI hand-offs.
const TRANSIENT: Array[String] = ["support_focus"]

## Back to a brand-new playthrough.
func reset() -> void:
	for key in PERSISTED:
		match PERSISTED[key]:
			TYPE_DICTIONARY: set(key, {})
			TYPE_ARRAY: set(key, [])
			TYPE_BOOL: set(key, false)
			TYPE_INT: set(key, 0)
			TYPE_STRING: set(key, "")
	support_focus = ""

## Every persisted variable as one dictionary (deep copies, safe to serialize).
func to_dict() -> Dictionary:
	var out := {}
	for key in PERSISTED:
		out[key] = get(key).duplicate(true) if PERSISTED[key] in [TYPE_DICTIONARY, TYPE_ARRAY] else get(key)
	return out

## "" if `data` is a loadable state, else why not. Missing keys are fine (they
## take their defaults), unknown keys are ignored (a newer build's extras);
## a key of the wrong type is an error. JSON has no int type, so an integral
## float counts as an int (see restore()).
func validate(data: Variant) -> String:
	if typeof(data) != TYPE_DICTIONARY:
		return "the state is not a dictionary"
	for key in PERSISTED:
		if not data.has(key):
			continue
		var v: Variant = data[key]
		var want: int = PERSISTED[key]
		var ok := typeof(v) == want or (want == TYPE_INT and typeof(v) == TYPE_FLOAT and is_equal_approx(v, round(v)))
		if not ok:
			return "'%s' has the wrong type" % key
	return ""

## JSON gives every number back as a float; turn integral floats back into ints,
## all the way down. (Nothing in the playthrough state is a real fraction.)
static func restore(value: Variant) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			return int(value) if is_equal_approx(value, round(value)) else value
		TYPE_DICTIONARY:
			var d := {}
			for k in value:
				d[k] = restore(value[k])
			return d
		TYPE_ARRAY:
			var a := []
			for v in value:
				a.append(restore(v))
			return a
	return value

## Replaces the playthrough with `data` (after validate()). Missing keys reset
## to their defaults first, so a partial save is a valid old save.
func from_dict(data: Dictionary) -> void:
	reset()
	for key in PERSISTED:
		if data.has(key):
			set(key, restore(data[key]))

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
