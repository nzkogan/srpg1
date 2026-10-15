extends Node
## Autoload singleton: the Huma (canon named.nmd_huma). Register after Mounts.
##
## Canon: "MAP HAZARD, NOT A MOUNT: drifts overhead; marked units gain stats and become targeting
## priority for every enemy", "its shadow legitimizes whoever it falls on", and a kill-taboo (whoever lands
## the blow dies in forty days, no reload undoes it). It never lands, so it is not a unit and cannot be
## struck: the taboo is kept by making the blow impossible.
## Built as a patch of shadow on the maps named by promotion_rules prm_huma_maps (the open road). Its centre
## lies on the middle row and drifts east huma_drift columns a turn from huma_start_col (turn 1), wrapping at
## the far edge; it covers every tile within huma_radius of the centre. A unit standing in it -- yours or the
## enemy's -- is MARKED: +huma_bonus to str, mag, def, res and spd for as long as it stands there, and every
## enemy that can reach a marked unit of yours goes for it (after a Martyr's Provoke, before anyone else).
## A unit of yours who falls while marked is credited to "the Huma's shadow" in the epilogue.

const STATS := ["str", "mag", "def", "res", "spd"]

func maps() -> Array:
	var row = Canon.find_by("promotion_rules", "param_id", "prm_huma_maps")
	if row == null or row.get("text") == null:
		return []
	var out: Array = []
	for part in str(row["text"]).split("|"):
		out.append(part.strip_edges())
	return out

func active_on(map_id: String) -> bool:
	return maps().has(map_id)

func bonus() -> int:
	return int(Progression.param("huma_bonus"))

func radius() -> int:
	return int(Progression.param("huma_radius"))

## Where the shadow's centre lies on `turn` (turn 0, the deploy screen, shows turn 1's).
func center(turn: int, width: int, height: int) -> Vector2i:
	var t := maxi(turn, 1) - 1
	var col := (int(Progression.param("huma_start_col")) + int(Progression.param("huma_drift")) * t) % maxi(width, 1)
	return Vector2i(col, height / 2)

func covers(tile: Vector2i, map_id: String, turn: int, width: int, height: int) -> bool:
	if not active_on(map_id):
		return false
	var c := center(turn, width, height)
	return absi(tile.x - c.x) <= radius() and absi(tile.y - c.y) <= radius()

## Every tile of the grid the shadow lies over this turn.
func tiles(map_id: String, turn: int, width: int, height: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not active_on(map_id):
		return out
	for y in height:
		for x in width:
			if covers(Vector2i(x, y), map_id, turn, width, height):
				out.append(Vector2i(x, y))
	return out

## A copy of a combatant's stats with the mark's bonus added.
func boost(stats: Dictionary) -> Dictionary:
	var out := stats.duplicate()
	for k in STATS:
		out[k] = int(out.get(k, 0)) + bonus()
	return out

## What the epilogue records for someone who falls while marked.
func killer() -> Dictionary:
	return {"type": "named_creature", "id": "nmd_huma"}

## One line for the map's panel: where the shadow lies and what it does.
func describe(map_id: String, turn: int, width: int, height: int) -> String:
	if not active_on(map_id):
		return ""
	var c := center(turn, width, height)
	var x0 := maxi(0, c.x - radius())
	var x1 := mini(width - 1, c.x + radius())
	return "The Huma's shadow lies over columns %d-%d: whoever stands in it gains +%d to every stat, and every enemy goes for them." % [x0, x1, bonus()]
