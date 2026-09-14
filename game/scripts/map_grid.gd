extends Node2D
## Renders a map_*.txt terrain grid as flat colored tiles (matching
## map_f00_reference.png's palette), places the 8 prologue units at their
## real starting tiles, and lets them actually move, attack the statue, and
## seize -- turn by turn, with the wall and statue as destructible obstacles.
##
## Units start at prologue_roster's deploy_row/deploy_col (all row 15, the
## court, per map_f00_reference.png's caption; only Sargath's and
## Bel-Iddin's columns are textually grounded, see that sheet's note row for
## the rest). Selecting a unit shows their movement range from wherever they
## currently are; clicking a highlighted tile actually moves them there,
## once per turn. Reaching the seize tile as Sargath specifically ends the
## prologue -- "* seize (Sargath only)" in map_f00.txt's own legend.
##
## Known simplification: units don't block each other's movement or occupy
## tiles exclusively (no collision in the pathfinding) -- real adjacency for
## statue attacks is still capped by MAX_STATUE_ATTACKERS_PER_TURN rather
## than computed from position, same as before.
##
## Controls:
##   1-8 = select a unit (shows their range from their current tile)
##   click a highlighted tile = move the selected unit there (once/turn)
##   A   = selected unit attacks the statue
##   N / Enter = advance to the next turn

const CELL_SIZE := 32
const MAP_PATH := "res://data/maps/map_f00.txt"
const IMPASSABLE := 90 # terrain_costs uses 99 as its impassable sentinel

## Only 4 tiles are orthogonally adjacent to any single tile, the statue's
## included -- prologue_tuning's own note: "only 4 orthogonal tiles touch
## the image, so 7 combatants cannot all swing in the same turn -- the
## warband has to ROTATE through it." Real positions exist now, but there's
## still no pathing-to-adjacency check, so this cap stands in for it.
const MAX_STATUE_ATTACKERS_PER_TURN := 4

## map_f00 is explicitly a rainstorm (maps.terrain: "hanging gardens in
## rain"); terrain_costs has no per-map wet flag yet, so this is hardcoded
## for this one map rather than invented as a general data field.
const WET := true

## Legend from map_f00.txt / map_f00_reference.png.
const LEGEND := {
	".": Color("cac6bc"), # court
	"a": Color("b8b4a8"), # the span, one tile
	"T": Color("8b8377"), # high terrace
	"x": Color("3d3a35"), # wall face / temple (impassable)
	"W": Color("a0623c"), # the wall (Enmet, turn 1)
	"g": Color("5e8c5a"), # planted terrace
	"t": Color("aca89c"), # stair
	"S": Color("2a2723"), # the image (statue)
	"*": Color("d1a851"), # seize (Sargath only)
	"c": Color("4a7fa3"), # channel
}

const REACHABLE_TINT := Color(0.35, 0.65, 1.0, 0.45)
const ORIGIN_TINT := Color(1.0, 0.9, 0.3, 0.7)
const TOKEN_COLOR := Color(0.15, 0.15, 0.18, 0.9)
const TOKEN_SELECTED_COLOR := Color(1.0, 0.85, 0.2, 0.95)
const TOKEN_MOVED_COLOR := Color(0.35, 0.35, 0.4, 0.9)

var grid: Array[String] = []
var terrain_by_symbol: Dictionary = {} # symbol -> terrain_costs row (Dictionary)
var units: Array = [] # prologue_roster rows, in file order
var selected_unit_index := 0
var origin: Vector2i = Vector2i(-1, -1)
var current_reachable: Dictionary = {} # Vector2i -> cost, for the currently selected unit
var tile_rects: Dictionary = {} # Vector2i -> ColorRect, so structures can recolor their tiles live
var unit_tokens: Dictionary = {} # punit_id -> {container: Node2D, bg: ColorRect}
var unit_positions: Dictionary = {} # punit_id -> Vector2i, current position (starts at deploy tile)
var seize_pos: Vector2i = Vector2i(-1, -1)

# --- turn / structure / win state -------------------------------------------
var turn := 0
var wall_destroyed := false
var statue_hp := 0
var statue_max_hp := 0
var statue_destroyed := false
var attacked_this_turn: Dictionary = {} # punit_id -> true, reset every turn
var moved_this_turn: Dictionary = {} # punit_id -> true, reset every turn
var prologue_won := false

var highlight_layer: Node2D
var info_label: Label
var status_label: Label

func _ready() -> void:
	grid = _load_grid(MAP_PATH)
	if grid.is_empty():
		return
	_index_terrain_costs()
	units = Canon.get_table("prologue_roster")
	_index_structures()
	_find_seize_tile()

	_draw_grid()
	_draw_axis_labels()

	highlight_layer = Node2D.new()
	add_child(highlight_layer)

	for unit in units:
		var pos := Vector2i(int(unit.get("deploy_col", -1)), int(unit.get("deploy_row", -1)))
		if pos.x >= 0 and pos.y >= 0:
			unit_positions[unit.get("punit_id")] = pos
	_draw_unit_tokens()

	status_label = Label.new()
	status_label.position = Vector2(0, grid.size() * CELL_SIZE + 16)
	status_label.custom_minimum_size = Vector2(grid[0].length() * CELL_SIZE, 60)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(status_label)

	info_label = Label.new()
	info_label.position = Vector2(0, grid.size() * CELL_SIZE + 80)
	info_label.custom_minimum_size = Vector2(grid[0].length() * CELL_SIZE, 100)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(info_label)

	_update_status_label()
	if not units.is_empty():
		_select_unit(0)
	else:
		_update_info_label()

func _find_seize_tile() -> void:
	for row in grid.size():
		var col := grid[row].find("*")
		if col != -1:
			seize_pos = Vector2i(col, row)
			return

## One token per unit at their current position, drawn after highlight_layer
## so movement-range tints never hide who's who. Each token is a small
## container Node2D so moving a unit only means updating one .position.
func _draw_unit_tokens() -> void:
	for unit in units:
		var pid = unit.get("punit_id")
		if not unit_positions.has(pid):
			continue
		var pos: Vector2i = unit_positions[pid]

		var container := Node2D.new()
		container.position = Vector2(pos.x * CELL_SIZE, pos.y * CELL_SIZE)
		add_child(container)

		var bg := ColorRect.new()
		bg.size = Vector2(CELL_SIZE - 6, CELL_SIZE - 6)
		bg.position = Vector2(3, 3)
		bg.color = TOKEN_COLOR
		container.add_child(bg)

		var label := Label.new()
		label.text = String(unit.get("name", "?")).substr(0, 2)
		label.size = bg.size
		label.position = bg.position
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", Color.WHITE)
		container.add_child(label)

		unit_tokens[pid] = {"container": container, "bg": bg}

func _load_grid(path: String) -> Array[String]:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("map_grid: failed to open %s -- run export_canon_json.py first" % path)
		return []
	var rows: Array[String] = []
	while not f.eof_reached():
		var line := f.get_line()
		if line.begins_with("#") or line.strip_edges().is_empty():
			continue
		rows.append(line)
	return rows

func _index_terrain_costs() -> void:
	for row in Canon.get_table("terrain_costs"):
		terrain_by_symbol[row["symbol"]] = row

func _index_structures() -> void:
	for row in Canon.get_table("prologue_structures"):
		if row["structure_id"] == "str_statue":
			statue_max_hp = int(row["hp"])
			statue_hp = statue_max_hp

func _draw_grid() -> void:
	for row in grid.size():
		var line := grid[row]
		for col in line.length():
			var terrain := line[col]
			var color: Color = LEGEND.get(terrain, Color.MAGENTA) # magenta = unmapped symbol, should never show
			var rect := ColorRect.new()
			rect.color = color
			rect.size = Vector2(CELL_SIZE - 1, CELL_SIZE - 1)
			rect.position = Vector2(col * CELL_SIZE, row * CELL_SIZE)
			add_child(rect)
			tile_rects[Vector2i(col, row)] = rect

func _draw_axis_labels() -> void:
	var width := grid[0].length() if not grid.is_empty() else 0
	for col in width:
		_add_label(str(col), Vector2(col * CELL_SIZE + 6, -20))
	for row in grid.size():
		_add_label(str(row), Vector2(-24, row * CELL_SIZE + 4))

func _add_label(text: String, pos: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size", 12)
	add_child(label)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local := get_local_mouse_position()
		var col := int(floor(local.x / CELL_SIZE))
		var row := int(floor(local.y / CELL_SIZE))
		if row >= 0 and row < grid.size() and col >= 0 and col < grid[0].length():
			_try_move_to(Vector2i(col, row))
	elif event is InputEventKey and event.pressed:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_A:
			_attack_statue()
		elif key_event.keycode == KEY_N or key_event.keycode == KEY_ENTER:
			_next_turn()
		else:
			var idx := key_event.keycode - KEY_1
			if idx >= 0 and idx < units.size():
				_select_unit(idx)

## Selecting a unit shows their movement range from wherever they currently
## are (not their static deploy tile -- they may have already moved).
func _select_unit(idx: int) -> void:
	_refresh_token_color(selected_unit_index)
	selected_unit_index = idx
	_refresh_token_color(idx)

	var pid = units[idx].get("punit_id", "")
	if unit_positions.has(pid):
		origin = unit_positions[pid]
	_recompute_and_draw()

func _refresh_token_color(idx: int) -> void:
	if idx < 0 or idx >= units.size():
		return
	var pid = units[idx].get("punit_id", "")
	var token = unit_tokens.get(pid)
	if token == null:
		return
	if idx == selected_unit_index:
		token.bg.color = TOKEN_SELECTED_COLOR
	elif moved_this_turn.has(pid):
		token.bg.color = TOKEN_MOVED_COLOR
	else:
		token.bg.color = TOKEN_COLOR

## Clicking a tile now commits a real move (once per turn) instead of just
## previewing a hypothetical origin -- previewing IS the reachable-tile
## highlight you already see once a unit is selected.
func _try_move_to(pos: Vector2i) -> void:
	if units.is_empty():
		return
	var unit: Dictionary = units[selected_unit_index]
	var pid: String = unit.get("punit_id", "")

	if moved_this_turn.has(pid):
		info_label.text = "%s has already moved this turn." % unit.get("name")
		return
	if not current_reachable.has(pos):
		info_label.text = "Out of range for %s." % unit.get("name")
		return

	unit_positions[pid] = pos
	moved_this_turn[pid] = true
	var token = unit_tokens.get(pid)
	if token:
		token.container.position = Vector2(pos.x * CELL_SIZE, pos.y * CELL_SIZE)

	origin = pos
	_recompute_and_draw()
	_refresh_token_color(selected_unit_index)

	if pid == "pu_sargath" and pos == seize_pos and not prologue_won:
		prologue_won = true
		status_label.text = "SEIZED. Sargath reaches the temple terrace -- the prologue ends here."
		info_label.text = "Victory. (The endgame branches from here aren't modeled in this tool.)"
		return

	_update_status_label()

func _recompute_and_draw() -> void:
	for child in highlight_layer.get_children():
		child.queue_free()
	current_reachable.clear()
	if origin == Vector2i(-1, -1) or units.is_empty():
		_update_info_label()
		return

	var unit: Dictionary = units[selected_unit_index]
	var pid: String = unit.get("punit_id", "")
	var movement_type: String = unit.get("movement_type", "infantry")

	if moved_this_turn.has(pid):
		# already acted this turn -- nothing further to show as reachable
		current_reachable = {origin: 0}
	else:
		var move_budget := int(unit.get("move", 0))
		current_reachable = _compute_reachable(origin, move_budget, movement_type)

	for pos in current_reachable:
		var tint := ORIGIN_TINT if pos == origin else REACHABLE_TINT
		var rect := ColorRect.new()
		rect.color = tint
		rect.size = Vector2(CELL_SIZE - 1, CELL_SIZE - 1)
		rect.position = Vector2(pos.x * CELL_SIZE, pos.y * CELL_SIZE)
		highlight_layer.add_child(rect)

	_update_info_label(current_reachable.size())

## Symbol lookup, overridden by structure state -- once a structure falls
## its tile behaves like plain court, both visually (see _recolor_symbol)
## and for movement math. This is the direct payoff of turn-based
## destruction: the movement-range tool built earlier actually changes
## shape once the wall or statue comes down.
func _effective_symbol(pos: Vector2i) -> String:
	var symbol := grid[pos.y][pos.x]
	if symbol == "W" and wall_destroyed:
		return "."
	if symbol == "S" and statue_destroyed:
		return "."
	return symbol

func _terrain_cost(pos: Vector2i, movement_type: String) -> int:
	var symbol := _effective_symbol(pos)
	var terrain: Dictionary = terrain_by_symbol.get(symbol)
	if terrain == null:
		return IMPASSABLE
	var base_key := "move_%s" % movement_type
	var cost := int(terrain.get(base_key, IMPASSABLE))
	if WET:
		var wet_key := "move_%s_wet" % movement_type
		var wet_cost = terrain.get(wet_key)
		if wet_cost != null:
			cost = int(wet_cost)
	return cost

func _neighbors(pos: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n := pos + d
		if n.y >= 0 and n.y < grid.size() and n.x >= 0 and n.x < grid[0].length():
			result.append(n)
	return result

## Dijkstra over the grid, capped at move_budget. The board is small (24x16)
## so a plain O(n^2) extract-min is plenty fast; no need for a heap. Does
## NOT account for other units occupying tiles -- see the file header.
func _compute_reachable(start: Vector2i, move_budget: int, movement_type: String) -> Dictionary:
	var cost_so_far := {start: 0}
	var frontier: Array[Vector2i] = [start]
	while frontier.size() > 0:
		var min_idx := 0
		for i in range(1, frontier.size()):
			if cost_so_far[frontier[i]] < cost_so_far[frontier[min_idx]]:
				min_idx = i
		var current: Vector2i = frontier[min_idx]
		frontier.remove_at(min_idx)
		var current_cost: int = cost_so_far[current]
		for neighbor in _neighbors(current):
			var step_cost := _terrain_cost(neighbor, movement_type)
			if step_cost >= IMPASSABLE:
				continue
			var new_cost := current_cost + step_cost
			if new_cost > move_budget:
				continue
			if not cost_so_far.has(neighbor) or new_cost < cost_so_far[neighbor]:
				cost_so_far[neighbor] = new_cost
				frontier.append(neighbor)
	return cost_so_far

func _recolor_symbol(symbol: String, color: Color) -> void:
	for row in grid.size():
		var line := grid[row]
		for col in line.length():
			if line[col] == symbol:
				var pos := Vector2i(col, row)
				if tile_rects.has(pos):
					tile_rects[pos].color = color

## Enmet removes the wall in one cast, turn 1 -- scripted, not a player
## choice, so it just happens when turn 1 begins rather than needing an
## attack action.
func _next_turn() -> void:
	turn += 1
	attacked_this_turn.clear()
	moved_this_turn.clear()
	for i in units.size():
		_refresh_token_color(i)
	if turn == 1 and not wall_destroyed:
		wall_destroyed = true
		_recolor_symbol("W", LEGEND["."])
	_recompute_and_draw()
	_update_status_label()
	_update_info_label()

## Attacking is deliberately not gated on real adjacency to the statue --
## there's no pathing-to-adjacency check yet, only the movement_type check
## below and MAX_STATUE_ATTACKERS_PER_TURN standing in for "who can reach it".
func _attack_statue() -> void:
	if units.is_empty():
		return
	var unit: Dictionary = units[selected_unit_index]
	var pid: String = unit.get("punit_id", "")

	if statue_destroyed:
		info_label.text = "The statue is already rubble."
		return

	var dmg := int(unit.get("dmg_vs_statue", 0))
	if dmg <= 0:
		info_label.text = "%s cannot attack (%s)." % [unit.get("name"), unit.get("what_they_do")]
		return

	var movement_type: String = unit.get("movement_type", "infantry")
	var terrace: Dictionary = terrain_by_symbol.get("T", {})
	if int(terrace.get("move_%s" % movement_type, IMPASSABLE)) >= IMPASSABLE:
		info_label.text = "%s can never reach the temple terrace (%s is blocked there)." % [unit.get("name"), movement_type]
		return

	if attacked_this_turn.has(pid):
		info_label.text = "%s has already acted this turn." % unit.get("name")
		return

	if attacked_this_turn.size() >= MAX_STATUE_ATTACKERS_PER_TURN:
		info_label.text = "Only %d units can reach the statue's 4 orthogonal tiles at once -- press N for next turn." % MAX_STATUE_ATTACKERS_PER_TURN
		return

	statue_hp = max(0, statue_hp - dmg)
	attacked_this_turn[pid] = true
	info_label.text = "%s hits the statue for %d. %d/%d HP remaining." % [unit.get("name"), dmg, statue_hp, statue_max_hp]

	if statue_hp == 0:
		statue_destroyed = true
		_recolor_symbol("S", LEGEND["."])
		_recompute_and_draw()
		info_label.text = "The statue is rubble. It goes still."

	_update_status_label()

func _update_status_label() -> void:
	if prologue_won:
		return
	var wall_state := "destroyed (Enmet, turn 1)" if wall_destroyed else "standing"
	var statue_state := "RUBBLE" if statue_destroyed else "%d / %d HP" % [statue_hp, statue_max_hp]
	status_label.text = (
		"Turn %d -- Wall: %s -- Statue: %s -- attackers: %d/%d this turn -- moved: %d/%d this turn\n[A] attack statue -- [N] / Enter: next turn -- click a highlighted tile to move"
		% [turn, wall_state, statue_state, attacked_this_turn.size(), MAX_STATUE_ATTACKERS_PER_TURN, moved_this_turn.size(), units.size()]
	)

func _update_info_label(reachable_count := -1) -> void:
	if prologue_won:
		return
	if units.is_empty():
		info_label.text = "No prologue_roster data loaded."
		return
	var unit: Dictionary = units[selected_unit_index]
	var pid: String = unit.get("punit_id", "")
	var lines: Array[String] = []
	lines.append("[1-8] select unit -- click a highlighted tile to move there (rain map: wet costs apply)")
	lines.append("Selected: %s -- move %s, %s, dmg_vs_statue %s" % [
		unit.get("name"), unit.get("move"), unit.get("movement_type"), unit.get("dmg_vs_statue")
	])
	if moved_this_turn.has(pid):
		lines.append("At (%d, %d) -- already moved this turn." % [origin.x, origin.y])
	elif origin != Vector2i(-1, -1):
		lines.append("At (%d, %d) -- %d tiles reachable" % [origin.x, origin.y, reachable_count])
	info_label.text = "\n".join(lines)
