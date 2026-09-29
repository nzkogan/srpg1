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
