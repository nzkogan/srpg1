extends Node2D
## Renders a map_*.txt terrain grid as flat colored tiles, matching the
## palette in map_f00_reference.png. Proves the tile-legend text format
## actually drives a real grid before any tactics logic (movement, combat)
## gets built on top of it. Deliberately does NOT place units -- their
## starting tiles aren't specified anywhere in canon.db or the map file,
## only the structures that are already baked into the terrain symbols
## (S the statue, W the wall, * the seize tile).

const CELL_SIZE := 32
const MAP_PATH := "res://data/maps/map_f00.txt"

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

var grid: Array[String] = []

func _ready() -> void:
	grid = _load_grid(MAP_PATH)
	if grid.is_empty():
		return
	_draw_grid()
	_draw_axis_labels()

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
