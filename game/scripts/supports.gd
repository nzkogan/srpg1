extends Node
## Autoload singleton: read-only queries over canon's supports table (all 153
## pairs among the 18 main units) plus the rank rules that follow from the
## data itself. Register after Canon and GameState in project.godot.
##
## Static data comes from Canon ("supports", "signs"); per-playthrough
## progress lives in GameState.support_ranks. This file holds RULES that are
## implied by canon, not balance:
##   - ranks go C -> B -> A -> S, one step at a time, never down
##   - S exists only on chains flagged romance_eligible == "yes"; every other
##     chain tops out at A (see supports!A2 in canon.xlsx)
##
## Deliberately NOT here, because canon.xlsx does not define them: how support
## points are earned, what a rank does in combat, or when a scene plays. Call
## raise_rank() from whatever system ends up owning that decision.
##
## Text: canon stores each chain's scenes as one string,
## "C: ... B: ... A: ... [S (romance): ...]". _parse_summary() splits it once
## at load so callers can ask for one rank's text at a time.

const RANKS: Array[String] = ["C", "B", "A", "S"]
const S_MARKER := " S (romance): "

var _by_id: Dictionary = {}     # chain_id -> supports row
var _by_pair: Dictionary = {}   # "unit_x|unit_y" (sorted) -> chain_id
var _by_unit: Dictionary = {}   # unit_id -> Array[chain_id]
var _text: Dictionary = {}      # chain_id -> {"C": String, "B": ..., "A": ..., "S": ...}

func _ready() -> void:
	_index()

func _index() -> void:
	_by_id.clear()
	_by_pair.clear()
	_by_unit.clear()
	_text.clear()
	for row in Canon.get_table("supports"):
		var id: String = row["chain_id"]
		var a: String = row["unit_a_id"]
		var b: String = row["unit_b_id"]
		_by_id[id] = row
		_by_pair[_pair_key(a, b)] = id
		for u in [a, b]:
			if not _by_unit.has(u):
				_by_unit[u] = []
			_by_unit[u].append(id)
		var summary = row.get("summary")
		if summary != null and String(summary) != "":
			var parsed := _parse_summary(String(summary))
			if parsed.is_empty():
				push_error("Supports: could not parse summary for %s" % id)
			else:
				_text[id] = parsed

static func _pair_key(a: String, b: String) -> String:
	return "%s|%s" % ([a, b] if a < b else [b, a])

## Splits "C: x B: y A: z [S (romance): w]" into {"C","B","A"[,"S"]}.
## Returns {} if the markers are missing or out of order.
static func _parse_summary(s: String) -> Dictionary:
	if not s.begins_with("C: "):
		return {}
	var i_b := s.find(" B: ")
	if i_b == -1:
		return {}
	var i_a := s.find(" A: ", i_b)
	if i_a == -1:
		return {}
	var i_s := s.find(S_MARKER, i_a)
	var out := {}
	out["C"] = s.substr(3, i_b - 3)
	out["B"] = s.substr(i_b + 4, i_a - (i_b + 4))
	if i_s == -1:
		out["A"] = s.substr(i_a + 4)
	else:
		out["A"] = s.substr(i_a + 4, i_s - (i_a + 4))
		out["S"] = s.substr(i_s + S_MARKER.length())
	return out

# ---------------------------------------------------------------- lookups

## The chain row for two units, in either order. {} if there is none
## (including a unit paired with itself).
func get_chain(unit_x: String, unit_y: String) -> Dictionary:
	var id: String = _by_pair.get(_pair_key(unit_x, unit_y), "")
	return _by_id.get(id, {})

func get_chain_by_id(chain_id: String) -> Dictionary:
	return _by_id.get(chain_id, {})

## Every chain id a unit belongs to (17 for a main-roster unit).
func chains_for(unit_id: String) -> Array:
	return _by_unit.get(unit_id, [])

## The other unit in a chain, or "" if unit_id isn't in it.
func partner_of(chain_id: String, unit_id: String) -> String:
	var row: Dictionary = _by_id.get(chain_id, {})
	if row.is_empty():
		return ""
	if row["unit_a_id"] == unit_id:
		return row["unit_b_id"]
	if row["unit_b_id"] == unit_id:
		return row["unit_a_id"]
	return ""

func is_romance_eligible(chain_id: String) -> bool:
	var row: Dictionary = _by_id.get(chain_id, {})
	return not row.is_empty() and row["romance_eligible"] == "yes"

## Highest rank this chain can reach: "S" for romance-eligible chains, "A"
## for every other chain, "" if the chain doesn't exist or has no text yet.
func max_rank(chain_id: String) -> String:
	if not _text.has(chain_id):
		return ""
	return "S" if _text[chain_id].has("S") else "A"

## The scene text for one rank of one chain, or "" if it doesn't exist
## (unknown chain, or asking for S on a non-romance chain).
func scene_text(chain_id: String, rank: String) -> String:
	var t: Dictionary = _text.get(chain_id, {})
	return t.get(rank, "")

## Display names of a chain's two signs, in unit_a/unit_b order, e.g.
## ["the Crab", "the Archer"]. "" for a missing sign.
func sign_names(chain_id: String) -> Array:
	var row: Dictionary = _by_id.get(chain_id, {})
	if row.is_empty():
		return []
	var out: Array = []
	for key in ["sign_a", "sign_b"]:
		var sign_row = Canon.find_by("signs", "sign_id", String(row.get(key, "")))
		out.append(sign_row["name"] if sign_row != null else "")
	return out

# ------------------------------------------------------- playthrough state

## Current rank of a chain this playthrough: "" (none yet), or C/B/A/S.
func current_rank(chain_id: String) -> String:
	return GameState.get_support_rank(chain_id)

## The rank raise_rank() would grant next, or "" if the chain is unknown,
## has no text, or is already at its maximum.
func next_rank(chain_id: String) -> String:
	var top := max_rank(chain_id)
	if top == "":
		return ""
	var cur := current_rank(chain_id)
	var idx := -1 if cur == "" else RANKS.find(cur)
	var nxt := idx + 1
	if nxt >= RANKS.size() or (RANKS[nxt] == "S" and top != "S"):
		return ""
	return RANKS[nxt]

## Advances a chain one rank. Returns the new rank, or "" if refused.
func raise_rank(chain_id: String) -> String:
	var nxt := next_rank(chain_id)
	if nxt == "":
		return ""
	GameState.set_support_rank(chain_id, nxt)
	return nxt

## What the epilogue's support clause needs (canon epilogue_generation D9:
## "paired_with unit_id + tier, OR unpaired"). Considers every chain the unit
## has reached at least rank C in this playthrough and picks the closest
## bond: the highest rank, ties broken by chain_id order so the result is
## deterministic. Pass ids of units who should not count as partners (e.g.
## ones who are also dead) in exclude_partners.
##
## "romantic" means the chain reached S -- a romance-eligible chain still at
## A reads as platonic, since S is the rank canon labels "(romance)".
##
## Returns {"paired": false} or
##   {"paired": true, "partner": id, "tier": "C".."S", "romantic": bool,
##    "chain_id": id}
func support_status(unit_id: String, exclude_partners: Array = []) -> Dictionary:
	var best_chain := ""
	var best_score := -1
	for chain_id in chains_for(unit_id):
		var partner := partner_of(chain_id, unit_id)
		if exclude_partners.has(partner):
			continue
		var rank := current_rank(chain_id)
		if rank == "":
			continue
		var score := RANKS.find(rank)
		if score > best_score or (score == best_score and chain_id < best_chain):
			best_score = score
			best_chain = chain_id
	if best_chain == "":
		return {"paired": false}
	var tier := current_rank(best_chain)
	return {
		"paired": true,
		"partner": partner_of(best_chain, unit_id),
		"tier": tier,
		"romantic": tier == "S",
		"chain_id": best_chain,
	}
