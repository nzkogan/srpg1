extends Node2D
## Renders a map_*.txt terrain grid as flat colored tiles (matching
## map_f00_reference.png's palette) and lets you click any passable tile to
## see the movement range of one of the 8 prologue units from that spot,
## using terrain_costs.json x prologue_roster.json (movement_type + move).
##
## Deliberately does NOT place the 8 units on real starting tiles -- those
## aren't specified anywhere in canon.db or map_f00.txt (see the sourcing
## note in prologue_roster's own sheet). Click-to-test lets the movement
## math get proven without inventing that data.
##
## Controls: click a passable tile = set movement origin for the selected
## unit. Keys 1-8 = switch which of the 8 units you're testing.

const CELL_SIZE := 32
const MAP_PATH := "res://data/maps/map_f00.txt"
const IMPASSABLE := 90 # terrain_costs uses 99 as its impassable sentinel

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

var grid: Array[String] = []
var terrain_by_symbol: Dictionary = {} # symbol -> terrain_costs row (Dictionary)
var units: Array = [] # prologue_roster rows, in file order
var selected_unit_index := 0
var origin: Vector2i = Vector2i(-1, -1)

var highlight_layer: Node2D
var info_label: Label

func _ready() -> void:
	grid = _load_grid(MAP_PATH)
	if grid.is_empty():
		return
	_index_terrain_costs()
	units = Canon.get_table("prologue_roster")

	_draw_grid()
	_draw_axis_labels()

	highlight_layer = Node2D.new()
	add_child(highlight_layer)

	info_label = Label.new()
	info_label.position = Vector2(0, grid.size() * CELL_SIZE + 16)
	info_label.custom_minimum_size = Vector2(grid[0].length() * CELL_SIZE, 100)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(info_label)
	_update_info_label()

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
			_try_set_origin(Vector2i(col, row))
	elif event is InputEventKey and event.pressed:
		var key_event := event as InputEventKey
		var idx := key_event.keycode - KEY_1
		if idx >= 0 and idx < units.size():
			selected_unit_index = idx
			_recompute_and_draw()

func _try_set_origin(pos: Vector2i) -> void:
	var symbol := grid[pos.y][pos.x]
	var terrain: Dictionary = terrain_by_symbol.get(symbol, {})
	if int(terrain.get("move_infantry", 1)) >= IMPASSABLE and int(terrain.get("move_flying", 1)) >= IMPASSABLE:
		info_label.text = "Can't start on an impassable tile (%s at %d,%d)." % [symbol, pos.x, pos.y]
		return
	origin = pos
	_recompute_and_draw()

func _recompute_and_draw() -> void:
	for child in highlight_layer.get_children():
		child.queue_free()
	if origin == Vector2i(-1, -1) or units.is_empty():
		_update_info_label()
		return

	var unit: Dictionary = units[selected_unit_index]
	var move_budget := int(unit.get("move", 0))
	var movement_type: String = unit.get("movement_type", "infantry")

	var reachable := _compute_reachable(origin, move_budget, movement_type)
	for pos in reachable:
		var tint := ORIGIN_TINT if pos == origin else REACHABLE_TINT
		var rect := ColorRect.new()
		rect.color = tint
		rect.size = Vector2(CELL_SIZE - 1, CELL_SIZE - 1)
		rect.position = Vector2(pos.x * CELL_SIZE, pos.y * CELL_SIZE)
		highlight_layer.add_child(rect)

	_update_info_label(reachable.size())

func _terrain_cost(pos: Vector2i, movement_type: String) -> int:
	var symbol := grid[pos.y][pos.x]
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
## so a plain O(n^2) extract-min is plenty fast; no need for a heap.
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

func _update_info_label(reachable_count := -1) -> void:
	if units.is_empty():
		info_label.text = "No prologue_roster data loaded."
		return
	var unit: Dictionary = units[selected_unit_index]
	var lines: Array[String] = []
	lines.append("[1-8] switch unit -- click a passable tile to test movement range (rain map: wet costs apply)")
	lines.append("Selected: %s -- move %s, %s" % [unit.get("name"), unit.get("move"), unit.get("movement_type")])
	if origin != Vector2i(-1, -1):
		lines.append("Origin: (%d, %d) -- %d tiles reachable" % [origin.x, origin.y, reachable_count])
	else:
		lines.append("Click a tile to set the origin.")
	info_label.text = "\n".join(lines)
