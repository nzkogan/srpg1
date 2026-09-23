extends Node2D
## A traversable overworld: one node per chapter, laid out left to right in
## a straight line and clicked to load that chapter's map. "Linear" is a
## deliberate simplification, not a claim about canon structure -- Act 1
## actually branches into two routes (chapters.route: 'diadem' vs
## 'assembly', both converging into Act 2's 'both'), so this line
## interleaves them by chapter number (d01, a01, d02, a02, d03, a03, ...)
## rather than showing them as parallel choices. A real route-select
## overworld is future work; this just needs to exist and be navigable now.
##
## Node color marks whether that chapter's map actually has a scene built
## yet (blue = clickable, grey = not built). Ordering itself is entirely
## data-driven (Canon's chapters/maps tables, sorted by act then number) --
## only the map_id -> scene path lookup below is hardcoded, since "does a
## .tscn file exist" isn't something canon.xlsx can know.
##
## Controls: click a blue node to load its map. Press Escape inside any map
## to return here (see map_grid.gd).

const AVAILABLE_SCENES := {
	"map_f00": "res://scenes/map_f00.tscn",
	"map_d01": "res://scenes/map_d01.tscn",
	"map_a02": "res://scenes/map_a02.tscn",
	"map_a03": "res://scenes/map_a03.tscn",
	"map_d03": "res://scenes/map_d03.tscn",
	"map_x11": "res://scenes/map_x11.tscn",
	"map_b15": "res://scenes/map_b15.tscn",
	"map_d02": "res://scenes/map_d02.tscn",
	"map_a01": "res://scenes/map_a01.tscn",
	"map_d05": "res://scenes/map_d05.tscn",
	"map_v21": "res://scenes/map_v21.tscn",
	"map_v22": "res://scenes/map_v22.tscn",
	"map_c21": "res://scenes/map_c21.tscn",
	"map_m21": "res://scenes/map_m21.tscn",
	"map_m22": "res://scenes/map_m22.tscn",
	"map_r16": "res://scenes/map_r16.tscn",
}

const ACT_RANK := {"prologue": 0, "1": 1, "2": 2, "3": 3, "paralogue": 9}

const NODE_RADIUS := 24.0
const NODE_SPACING := 150.0
const NODE_Y := 160.0
const AVAILABLE_COLOR := Color(0.30, 0.55, 0.85, 0.95)
const LOCKED_COLOR := Color(0.35, 0.35, 0.38, 0.95)
const LINE_COLOR := Color(0.5, 0.5, 0.55, 0.8)

var nodes: Array = [] # {chapter: Dictionary, map_row: Dictionary, pos: Vector2, has_scene: bool}
var info_label: Label

func _ready() -> void:
	var maps_by_id: Dictionary = {}
	for m in Canon.get_table("maps"):
		maps_by_id[m["map_id"]] = m

	var sortable: Array = []
	for ch in Canon.get_table("chapters"):
		var rank: int = ACT_RANK.get(str(ch.get("act")), 5)
		sortable.append([rank, int(ch.get("number", 0)), str(ch.get("route", "")), ch])
	sortable.sort_custom(func(a, b):
		if a[0] != b[0]:
			return a[0] < b[0]
		if a[1] != b[1]:
			return a[1] < b[1]
		return a[2] < b[2]
	)

	for i in sortable.size():
		var ch: Dictionary = sortable[i][3]
		# a handful of chapters (e.g. ch_h32, "The Kaisareia Trial") have no
		# map at all by design -- .get()'s default only applies when the key
		# is absent, and this key IS present with a null value, so it must
		# be checked explicitly rather than relying on the default.
		var map_id: String = ch.get("map_id") if ch.get("map_id") != null else ""
		var map_row: Dictionary = maps_by_id.get(map_id, {})
		var pos := Vector2(100 + i * NODE_SPACING, NODE_Y)
		nodes.append({
			"chapter": ch, "map_row": map_row, "pos": pos,
			"has_scene": AVAILABLE_SCENES.has(map_id),
		})

	_draw_connections()
	_draw_nodes()

	info_label = Label.new()
	info_label.position = Vector2(20, NODE_Y + 90)
	info_label.custom_minimum_size = Vector2(nodes.size() * NODE_SPACING, 100)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(info_label)
	info_label.text = (
		"Click a blue node to load its map (grey = no scene built yet). " +
		"Route note: diadem (d) and assembly (a) chapters shown here are " +
		"actually alternate Act 1 branches in canon.xlsx, not one real " +
		"sequential path -- interleaved by chapter number for now, see this " +
		"script's own header comment."
	)

func _draw_connections() -> void:
	for i in range(nodes.size() - 1):
		var line := Line2D.new()
		line.add_point(nodes[i].pos)
		line.add_point(nodes[i + 1].pos)
		line.width = 3
		line.default_color = LINE_COLOR
		add_child(line)

func _draw_nodes() -> void:
	for n in nodes:
		var rect := ColorRect.new()
		rect.size = Vector2(NODE_RADIUS * 2, NODE_RADIUS * 2)
		rect.position = n.pos - Vector2(NODE_RADIUS, NODE_RADIUS)
		rect.color = AVAILABLE_COLOR if n.has_scene else LOCKED_COLOR
		add_child(rect)

		var label := Label.new()
		label.text = "%s\n%s" % [n.chapter.get("title", "?"), n.map_row.get("title", "?")]
		label.position = n.pos + Vector2(-NODE_RADIUS - 20, NODE_RADIUS + 4)
		label.custom_minimum_size = Vector2(NODE_RADIUS * 2 + 40, 44)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 10)
		add_child(label)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mp := get_local_mouse_position()
		for n in nodes:
			if mp.distance_to(n.pos) <= NODE_RADIUS:
				_select_node(n)
				return

func _select_node(n: Dictionary) -> void:
	var map_id: String = n.map_row.get("map_id", "")
	if not n.has_scene:
		info_label.text = "%s (%s) has no playable scene built yet." % [n.chapter.get("title"), map_id]
		return
	get_tree().change_scene_to_file(AVAILABLE_SCENES[map_id])
