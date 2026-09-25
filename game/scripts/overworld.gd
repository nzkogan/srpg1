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
## yet (blue = clickable, grey = not built or currently locked). Ordering
## itself is entirely data-driven (Canon's chapters/maps tables, sorted by
## act then number) -- only the map_id -> scene path lookup below is
## hardcoded, since "does a .tscn file exist" isn't something canon.xlsx
## can know.
##
## ch_h32 "The Kaisareia Trial" has no map_id at all (see chapters' own
## note) -- it's keyed by chapter_id in SPECIAL_SCENES instead, pointing at
## trial.tscn, a non-battle choice screen that sets GameState's
## flag_hierophant_verdict. ch_h33_mercy and ch_h34_war1/2/3 are gated on
## that flag: locked (grey, distinct message) until the trial sets it, then
## only the matching branch unlocks -- the other one stays locked for that
## playthrough, same as canon_flags.flag_hierophant_verdict's own "affects"
## column describes.
##
## Controls: click a blue node to load its map. Press Escape inside any map
## to return here (see map_grid.gd).

const AVAILABLE_SCENES := {
	"map_f00": "res://scenes/map_f00.tscn",
	"map_d01": "res://scenes/map_d01.tscn",
	"map_a02": "res://scenes/map_a02.tscn",
	"map_a03": "res://scenes/map_a03.tscn",
	"map_d03": "res://scenes/map_d03.tscn",
	"map_d04": "res://scenes/map_d04.tscn",
	"map_d06": "res://scenes/map_d06.tscn",
	"map_d07": "res://scenes/map_d07.tscn",
	"map_d08": "res://scenes/map_d08.tscn",
	"map_d09": "res://scenes/map_d09.tscn",
	"map_d10": "res://scenes/map_d10.tscn",
	"map_x11": "res://scenes/map_x11.tscn",
	"map_b15": "res://scenes/map_b15.tscn",
	"map_d02": "res://scenes/map_d02.tscn",
	"map_a01": "res://scenes/map_a01.tscn",
	"map_a04": "res://scenes/map_a04.tscn",
	"map_a05": "res://scenes/map_a05.tscn",
	"map_a06": "res://scenes/map_a06.tscn",
	"map_a07": "res://scenes/map_a07.tscn",
	"map_a08": "res://scenes/map_a08.tscn",
	"map_a09": "res://scenes/map_a09.tscn",
	"map_a10": "res://scenes/map_a10.tscn",
	"map_d05": "res://scenes/map_d05.tscn",
	"map_v21": "res://scenes/map_v21.tscn",
	"map_v22": "res://scenes/map_v22.tscn",
	"map_c21": "res://scenes/map_c21.tscn",
	"map_m21": "res://scenes/map_m21.tscn",
	"map_m22": "res://scenes/map_m22.tscn",
	"map_r16": "res://scenes/map_r16.tscn",
	"map_e31": "res://scenes/map_e31.tscn",
	"map_e32_sanctified": "res://scenes/map_e32_sanctified.tscn",
	"map_e32_perverse": "res://scenes/map_e32_perverse.tscn",
	"map_k21": "res://scenes/map_k21.tscn",
	"map_k22": "res://scenes/map_k22.tscn",
	"map_h31": "res://scenes/map_h31.tscn",
	"map_h33_mercy": "res://scenes/map_h33_mercy.tscn",
	"map_h34_war1": "res://scenes/map_h34_war1.tscn",
	"map_h34_war2": "res://scenes/map_h34_war2.tscn",
	"map_h34_war3": "res://scenes/map_h34_war3.tscn",
	"map_p_macuil": "res://scenes/map_p_macuil.tscn",
	"map_p_indech": "res://scenes/map_p_indech.tscn",
	"map_p_shadhavar": "res://scenes/map_p_shadhavar.tscn",
	"map_p_simurgh": "res://scenes/map_p_simurgh.tscn",
	"map_p_karkadann": "res://scenes/map_p_karkadann.tscn",
	"map_p_anzu": "res://scenes/map_p_anzu.tscn",
	"map_p_huma": "res://scenes/map_p_huma.tscn",
	"map_p_buried_works": "res://scenes/map_p_buried_works.tscn",
}

## Chapters with no map_id at all get keyed by chapter_id instead.
const SPECIAL_SCENES := {
	"ch_h32": "res://scenes/trial.tscn",
}

const HIEROPHANT_FLAG := "flag_hierophant_verdict"
## chapter_id -> the verdict value that unlocks it.
const HIEROPHANT_GATED := {
	"ch_h33_mercy": "mercy",
	"ch_h34_war1": "execution",
	"ch_h34_war2": "execution",
	"ch_h34_war3": "execution",
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
		var chapter_id: String = ch.get("chapter_id", "")
		# a handful of chapters (e.g. ch_h32, "The Kaisareia Trial") have no
		# map at all by design -- .get()'s default only applies when the key
		# is absent, and this key IS present with a null value, so it must
		# be checked explicitly rather than relying on the default.
		var map_id: String = ch.get("map_id") if ch.get("map_id") != null else ""
		var map_row: Dictionary = maps_by_id.get(map_id, {})
		var pos := Vector2(100 + i * NODE_SPACING, NODE_Y)

		var locked_reason := ""
		var has_scene: bool
		if SPECIAL_SCENES.has(chapter_id):
			has_scene = true
		elif HIEROPHANT_GATED.has(chapter_id):
			var needed: String = HIEROPHANT_GATED[chapter_id]
			var verdict = GameState.get_flag(HIEROPHANT_FLAG)
			if verdict == null:
				locked_reason = "requires a sentence recommendation at The Kaisareia Trial (ch_h32) first"
				has_scene = false
			elif verdict != needed:
				locked_reason = "this playthrough's verdict was '%s', not '%s' -- locked for good this run" % [verdict, needed]
				has_scene = false
			else:
				has_scene = AVAILABLE_SCENES.has(map_id)
		else:
			has_scene = AVAILABLE_SCENES.has(map_id)

		nodes.append({
			"chapter": ch, "map_row": map_row, "pos": pos,
			"has_scene": has_scene, "locked_reason": locked_reason,
		})

	_draw_connections()
	_draw_nodes()

	info_label = Label.new()
	info_label.position = Vector2(20, NODE_Y + 90)
	info_label.custom_minimum_size = Vector2(nodes.size() * NODE_SPACING, 100)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(info_label)
	var verdict_text := "no sentence recommended yet" if GameState.get_flag(HIEROPHANT_FLAG) == null \
		else "verdict: %s" % GameState.get_flag(HIEROPHANT_FLAG)
	info_label.text = (
		"Click a blue node to load its map (grey = no scene built, or locked). " +
		"The Kaisareia Trial (ch_h32, %s) forks ch_h33_mercy vs. ch_h34_war1-3 -- " % verdict_text +
		"only one branch is ever reachable in a given run. " +
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
	var chapter_id: String = n.chapter.get("chapter_id", "")
	if SPECIAL_SCENES.has(chapter_id):
		get_tree().change_scene_to_file(SPECIAL_SCENES[chapter_id])
		return
	if not n.has_scene:
		if n.get("locked_reason", "") != "":
			info_label.text = "%s: %s" % [n.chapter.get("title"), n.locked_reason]
		else:
			var map_id: String = n.map_row.get("map_id", "")
			info_label.text = "%s (%s) has no playable scene built yet." % [n.chapter.get("title"), map_id]
		return
	var map_id: String = n.map_row.get("map_id", "")
	get_tree().change_scene_to_file(AVAILABLE_SCENES[map_id])
