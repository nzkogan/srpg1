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
## EARNING RULE (see "Earning" below). canon.xlsx does not define one, so this
## is a design proposal, not canon: every number is a const at the top of that
## section and expected to move after playtesting. Summary:
##   1. At the end of each turn, every pair of living deployed units standing
##      within PROXIMITY_RANGE tiles of each other earns their chain +1 point,
##      up to MAP_POINT_CAP points per chain per map.
##   2. Points are banked only when the map is WON, once per map per
##      playthrough (no farming by replaying, none for abandoned maps).
##   3. When banked points reach the next rank's threshold the chain ranks up
##      -- at most one rank per chain per map, so a bond deepens over
##      chapters rather than all at once.
##   4. Diadem x assembly pairs only earn on chapters whose route is "both"
##      (canon's own convergence point); same-route pairs, and anyone with
##      route "both", earn anywhere.
##
## Still not defined anywhere: what a rank does in combat, and how a scene is
## presented. Callers of settle_map() get the list of ranks raised and can
## show scene_text() however they like.
##
## Text: canon stores each chain's scenes as one string,
## "C: ... B: ... A: ... [S (romance): ...]". _parse_summary() splits it once
## at load so callers can ask for one rank's text at a time.

const RANKS: Array[String] = ["C", "B", "A", "S"]
const S_MARKER := " S (romance): "

## Where the win screen and the overworld send the player to read supports.
const VIEWER_SCENE := "res://scenes/support_viewer.tscn"

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

# ------------------------------------------------------------------ Earning
# Design proposal -- tune these after playtesting.

## Cumulative banked points needed to reach each rank. With MAP_POINT_CAP = 3
## and one rank per map, a pair that is together every turn of every map
## reaches C after 1 map, B after 3, A after 5, S after 9; a pair that is
## together on half its maps takes about twice as long.
const POINTS_FOR_RANK := {"C": 3, "B": 8, "A": 15, "S": 25}

## Manhattan distance, in tiles, at which two units count as "together" at
## turn end. 2 rather than 1 because non-boss maps deploy units in a row two
## columns apart, and support should not depend on a strict hug.
const PROXIMITY_RANGE := 2

## Most points one chain can earn on a single map.
const MAP_POINT_CAP := 3

var _map_points: Dictionary = {}  # chain_id -> points earned this map, not yet banked

## Call when a map starts. Discards any points from an unfinished map.
func begin_map() -> void:
	_map_points.clear()

## Whether two units may earn together on a chapter of the given route
## ("diadem", "assembly" or "both"). Opposed-route units only meet once the
## routes converge; canon marks that with chapters.route == "both".
func pair_allowed(unit_x: String, unit_y: String, chapter_route: String) -> bool:
	var ux = Canon.find_by("units", "unit_id", unit_x)
	var uy = Canon.find_by("units", "unit_id", unit_y)
	if ux == null or uy == null:
		return false
	var rx: String = ux["route"]
	var ry: String = uy["route"]
	if rx == ry or rx == "both" or ry == "both":
		return true
	return chapter_route == "both"

## Whether a chain can still gain points: it exists, has text, and hasn't
## reached its maximum rank.
func chain_can_earn(chain_id: String) -> bool:
	var top := max_rank(chain_id)
	return top != "" and current_rank(chain_id) != top

## Applies the proximity rule for one turn end. positions maps unit_id ->
## Vector2i for every LIVING deployed unit (units with no chain, such as the
## prologue roster, are ignored). Returns how many points were awarded.
func record_turn_end(positions: Dictionary, chapter_route: String) -> int:
	var ids: Array = positions.keys()
	ids.sort()
	var awarded := 0
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var chain: Dictionary = get_chain(ids[i], ids[j])
			if chain.is_empty():
				continue
			var chain_id: String = chain["chain_id"]
			if not chain_can_earn(chain_id):
				continue
			if _map_points.get(chain_id, 0) >= MAP_POINT_CAP:
				continue
			var a: Vector2i = positions[ids[i]]
			var b: Vector2i = positions[ids[j]]
			if abs(a.x - b.x) + abs(a.y - b.y) > PROXIMITY_RANGE:
				continue
			if not pair_allowed(ids[i], ids[j], chapter_route):
				continue
			_map_points[chain_id] = _map_points.get(chain_id, 0) + 1
			awarded += 1
	return awarded

## Points earned on the current map so far (not yet banked).
func map_points(chain_id: String) -> int:
	return _map_points.get(chain_id, 0)

## Banked points for a chain this playthrough.
func points(chain_id: String) -> int:
	return GameState.support_points.get(chain_id, 0)

## Points still needed for the next rank, or -1 if there is none.
func points_to_next(chain_id: String) -> int:
	var nxt := next_rank(chain_id)
	if nxt == "":
		return -1
	return max(0, POINTS_FOR_RANK[nxt] - points(chain_id))

## Call when a map is won. Banks this map's points (once per map_id per
## playthrough), then ranks up every chain whose banked points have reached
## its next threshold -- at most one rank per chain. Returns one entry per
## rank-up: {"chain_id", "rank", "unit_a", "unit_b"}. Returns [] if this map
## was already settled.
func settle_map(map_id: String) -> Array:
	var results: Array = []
	if GameState.support_settled_maps.has(map_id):
		_map_points.clear()
		return results
	GameState.support_settled_maps[map_id] = true
	for chain_id in _map_points:
		GameState.support_points[chain_id] = points(chain_id) + _map_points[chain_id]
	_map_points.clear()
	var chain_ids: Array = GameState.support_points.keys()
	chain_ids.sort()
	for chain_id in chain_ids:
		var nxt := next_rank(chain_id)
		if nxt == "" or points(chain_id) < POINTS_FOR_RANK[nxt]:
			continue
		var rank := raise_rank(chain_id)
		var row: Dictionary = _by_id[chain_id]
		results.append({
			"chain_id": chain_id,
			"rank": rank,
			"unit_a": row["unit_a_id"],
			"unit_b": row["unit_b_id"],
		})
	# What the viewer calls NEW: this map's rank-ups (none, if it raised nothing).
	GameState.support_recent = {}
	for entry in results:
		GameState.support_recent[entry["chain_id"]] = entry["rank"]
	return results

## One line of player-facing text for a settle_map() entry.
func describe_raise(entry: Dictionary) -> String:
	var na = Canon.find_by("units", "unit_id", entry["unit_a"])
	var nb = Canon.find_by("units", "unit_id", entry["unit_b"])
	return "Support: %s and %s reach rank %s." % [
		na["name"] if na != null else entry["unit_a"],
		nb["name"] if nb != null else entry["unit_b"],
		entry["rank"],
	]
