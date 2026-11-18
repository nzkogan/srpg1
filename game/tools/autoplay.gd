extends RefCounted
## Plays a battle map to the end with a simple player AI, through the map's own move and attack functions, against
## the real enemy phase. It is a measuring stick, not an opponent: it plays a plain, sensible game (fight what is in
## reach, favour the weakest target, walk toward the objective otherwise) so a map that it cannot win, or wins with
## nobody hurt, is worth a designer's look. Canon's map laws ask for this ("the two-compositions test is a
## MEASUREMENT, not an opinion").
##
## Use: var r = Autoplay.new().play(map_node, seed, max_turns) -> {"won", "lost", "turns", "fallen", "hp_lost_pct", "enemies_left"}
## (hp_lost_pct: the share of the party's starting HP gone at the end, the fallen counted as all of theirs.)

const IMPASSABLE := 99

var m: Node

func play(map: Node, seed: int = 1, max_turns: int = 40) -> Dictionary:
	m = map
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	m.rng_override = rng
	var start_units: Array = m.units.map(func(u): return str(u.get("punit_id", "")))
	var start_hp := 0
	for p in start_units:
		start_hp += int(m.unit_hp.get(p, 0))
	if m.turn == 0:
		m._next_turn()
	while not m.map_won and not m.map_lost and m.turn <= max_turns:
		_player_phase()
		if m.map_won or m.map_lost:
			break
		m._next_turn()
	var fallen: Array = start_units.filter(func(p): return int(m.unit_hp.get(p, 1)) <= 0)
	var end_hp := 0
	for p in start_units:
		end_hp += maxi(0, int(m.unit_hp.get(p, 0)))
	return {"won": m.map_won, "lost": m.map_lost, "turns": m.turn, "fallen": fallen, "hp_lost_pct": 0 if start_hp == 0 else int(round(100.0 * (start_hp - end_hp) / start_hp)),
		"enemies_left": m.enemies.filter(func(e): return not e.defeated and not e.get("neutral", false)).size()}

# ------------------------------------------------------------------ one turn

func _player_phase() -> void:
	# fighters first, then anyone who cannot fight (they move after the line has formed)
	var order: Array = range(m.units.size())
	order.sort_custom(func(a, b): return int(_can_fight(m.units[a])) > int(_can_fight(m.units[b])))
	for i in order:
		if m.map_won or m.map_lost:
			return
		var unit: Dictionary = m.units[i]
		var pid: String = str(unit.get("punit_id", ""))
		if not m.unit_positions.has(pid):
			continue
		m._select_unit(i)
		_act(unit, pid)

func _act(unit: Dictionary, pid: String) -> void:
	var here: Vector2i = m.unit_positions[pid]
	var reach: Dictionary = m.current_reachable.duplicate()
	var occupied := _occupied(pid)
	var verb := str(m.map_row.get("objective_verb", ""))
	if m._cargo_needed() > 0 and not m._is_cargo(pid) and m.escape_pos != Vector2i(-1, -1):
		reach.erase(m.escape_pos)          # the exit is the wagons'; escorts keep off it
		if here == m.escape_pos:
			occupied.erase(here)

	# 1. the objective, if this unit can take it this turn
	var goal := _goal_for(unit, pid, verb)
	if goal != Vector2i(-1, -1) and reach.has(goal) and not occupied.has(goal) and _goal_takes_unit(unit, pid, verb):
		m._try_move_to(goal)
		return

	# 2. cargo walks toward the exit; non-fighters keep back
	if m._is_cargo(pid):
		_step_toward(m.escape_pos, unit, reach, occupied)
		return
	if not _can_fight(unit):
		if m.map_id == "map_f00":
			_prologue_statue(unit, reach, occupied)
		return

	# 3. the prologue's statue: everyone who can must put hands on it
	if m.map_id == "map_f00" and not m.statue_destroyed and int(unit.get("dmg_vs_statue", 0)) > 0:
		if _prologue_statue(unit, reach, occupied):
			return

	# 4. badly hurt: pull back to the safest tile instead of trading blows
	var max_hp := int(unit.get("hp", 1))
	if int(m.unit_hp.get(pid, max_hp)) * 100 < max_hp * 40 and not m._is_cargo(pid):
		_retreat(unit, reach, occupied)
		return

	# 5. fight: the best tile from which an enemy is in reach
	var weapon: Dictionary = m._weapon_for_unit(unit)
	if not weapon.is_empty():
		var best := _best_attack_tile(unit, weapon, reach, occupied)
		if not best.is_empty():
			if best["tile"] != here:
				m._try_move_to(best["tile"])
			_attack(best["target"], weapon)
			return

	# 6. otherwise advance: on the objective if there is one, else on the nearest enemy
	var dest := goal
	if m._cargo_needed() > 0:
		dest = _nearest_enemy_pos(here)    # escorts clear the road rather than walk to the exit
	if dest == Vector2i(-1, -1) or verb == "defend" or verb == "survive":
		dest = _nearest_enemy_pos(here)
		if verb == "defend" and m.defend_pos != Vector2i(-1, -1):
			dest = m.defend_pos
	if dest != Vector2i(-1, -1):
		_step_toward(dest, unit, reach, occupied)

func _attack(target: Dictionary, weapon: Dictionary) -> void:
	m._update_forecast()
	for i in m._targets.size():
		if m._targets[i] == target:
			m._target_idx = i
	m._attack_enemy()

# ------------------------------------------------------------------ choices

func _can_fight(unit: Dictionary) -> bool:
	var art = unit.get("weapon_art")
	return art != null and str(art) != "" and not m._is_cargo(str(unit.get("punit_id", "")))

func _goal_for(unit: Dictionary, pid: String, verb: String) -> Vector2i:
	match verb:
		"seize":
			return m.seize_pos
		"escape", "escort":
			return m.escape_pos
	return Vector2i(-1, -1)

func _goal_takes_unit(unit: Dictionary, pid: String, verb: String) -> bool:
	if verb == "seize" and m.map_id == "map_f00":
		return pid == "pu_sargath"
	if m._cargo_needed() > 0 and (verb == "escape" or verb == "escort"):
		return m._is_cargo(pid)
	return true

func _occupied(except_pid: String) -> Dictionary:
	var out := {}
	for p in m.unit_positions:
		if p != except_pid:
			out[m.unit_positions[p]] = true
	for e in m.enemies:
		if not e.defeated:
			out[e.pos] = true
	return out

## {"tile", "target"} for the attack worth making: prefer a target that can be finished, then the weakest, then the
## tile fewest enemies can reach next phase.
func _best_attack_tile(unit: Dictionary, weapon: Dictionary, reach: Dictionary, occupied: Dictionary) -> Dictionary:
	var best := {}
	var best_score := -INF
	var here: Vector2i = m.unit_positions[str(unit.get("punit_id", ""))]
	for tile in reach:
		if occupied.has(tile) and tile != here:
			continue
		for inst in m._enemies_in_range(tile, weapon):
			var hp := int(inst.hp)
			var score := 100.0 - hp - 2.0 * _threat_at(tile)
			if score > best_score:
				best_score = score
				best = {"tile": tile, "target": inst}
	return best

## How many living enemies could reach a tile on their next phase (move plus their weapon's reach).
func _threat_at(tile: Vector2i) -> int:
	var n := 0
	for e in m.enemies:
		if e.defeated or e.get("neutral", false):
			continue
		var mv := int(m.MOVEMENT_TYPE_DEFAULT_MOVE.get(str(e.archetype.get("movement_type", "infantry")), 5))
		if m._distance(e.pos, tile) <= mv + 1:
			n += 1
	return n

## Moves to the reachable free tile the fewest enemies can reach next phase (ties: farthest from the nearest enemy).
func _retreat(unit: Dictionary, reach: Dictionary, occupied: Dictionary) -> void:
	var pid := str(unit.get("punit_id", ""))
	var here: Vector2i = m.unit_positions[pid]
	var best := here
	var best_key := Vector2(_threat_at(here), -_gap(here))
	for tile in reach:
		if occupied.has(tile):
			continue
		var key := Vector2(_threat_at(tile), -_gap(tile))
		if key.x < best_key.x or (key.x == best_key.x and key.y < best_key.y):
			best_key = key
			best = tile
	if best != here:
		m._try_move_to(best)

func _gap(tile: Vector2i) -> int:
	var nearest := _nearest_enemy_pos(tile)
	return 99 if nearest == Vector2i(-1, -1) else m._distance(tile, nearest)

func _nearest_enemy_pos(from: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var bd := 1 << 30
	for e in m.enemies:
		if e.defeated or e.get("neutral", false):
			continue
		var d: int = m._distance(from, e.pos)
		if d < bd:
			bd = d
			best = e.pos
	return best

## Moves to the reachable free tile with the shortest walking distance to `dest` (weighted by terrain).
func _step_toward(dest: Vector2i, unit: Dictionary, reach: Dictionary, occupied: Dictionary) -> void:
	var dist := _walk_distances(dest, str(unit.get("movement_type", "infantry")))
	var pid := str(unit.get("punit_id", ""))
	var here: Vector2i = m.unit_positions[pid]
	var best := here
	var bd: int = dist.get(here, 1 << 30)
	for tile in reach:
		if occupied.has(tile):
			continue
		var d: int = dist.get(tile, 1 << 30)
		if d < bd:
			bd = d
			best = tile
	if best != here:
		m._try_move_to(best)

## Walking cost from every tile to `dest` (Dijkstra outward from the destination).
func _walk_distances(dest: Vector2i, movement_type: String) -> Dictionary:
	var cost := {dest: 0}
	var frontier: Array = [dest]
	while not frontier.is_empty():
		var mi := 0
		for i in range(1, frontier.size()):
			if cost[frontier[i]] < cost[frontier[mi]]:
				mi = i
		var cur: Vector2i = frontier[mi]
		frontier.remove_at(mi)
		for n in m._neighbors(cur):
			var step: int = m._terrain_cost(cur, movement_type)
			if step >= IMPASSABLE:
				if cur != dest:
					continue     # walls stay walls; only the destination itself (a statue, say) may be impassable
				step = 1
			var c: int = cost[cur] + step
			if not cost.has(n) or c < cost[n]:
				cost[n] = c
				frontier.append(n)
	return cost

## The prologue: walk to the statue and strike it. Returns true if the unit did something.
func _prologue_statue(unit: Dictionary, reach: Dictionary, occupied: Dictionary) -> bool:
	var statue_tiles: Array = []
	for row in m.grid.size():
		for col in m.grid[row].length():
			if m.grid[row][col] == "S":
				statue_tiles.append(Vector2i(col, row))
	if statue_tiles.is_empty() or m.statue_destroyed:
		return false
	var pid := str(unit.get("punit_id", ""))
	var target: Vector2i = statue_tiles[0]
	var adjacent := func(t: Vector2i) -> bool:
		return statue_tiles.any(func(s): return m._distance(s, t) == 1)
	var best := Vector2i(-1, -1)
	for tile in reach:
		if not occupied.has(tile) and adjacent.call(tile):
			best = tile
			break
	if best != Vector2i(-1, -1):
		if best != m.unit_positions[pid]:
			m._try_move_to(best)
		m._attack_statue()
		return true
	_step_toward(target, unit, reach, occupied)
	return true
