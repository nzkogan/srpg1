extends Node2D
## Renders a map_*.txt terrain grid as flat colored tiles, places a roster of
## units at deploy tiles, and lets them move and fight -- turn by turn -- any
## enemies wired up for this map via encounter_spawns. One script now serves
## three maps (map_f00, map_a02, map_a03), configured per-scene through the
## @export vars below rather than hardcoded to the prologue.
##
## map_f00 keeps its own bespoke mechanics (wall/statue destruction, the
## Sargath-only seize) gated behind `map_id == "map_f00"` checks -- they were
## never general systems, so genericizing didn't try to force them into one.
## What IS shared across all three maps: terrain rendering, Dijkstra movement
## range, unit/enemy tokens and turn order, weapon-range combat through
## Combat.gd, den-based reinforcement waves, and hazard-tile damage (map_a03's
## cold drain). Objective handling branches on maps.objective_verb: seize
## (f00, unchanged), defend (a02 -- survive to turn_limit, or defeat the
## boss early), escape (a03 -- get min_solution_units units off the map via
## the escape tile).
##
## Known simplification carried over unchanged: units don't block each
## other's (or enemies') movement -- no collision in the pathfinding.
##
## Controls:
##   1-9 = select a unit (shows their range from their current tile)
##   click a highlighted tile = move the selected unit there (once/turn)
##   A   = selected unit attacks the statue (map_f00 only)
##   F   = selected unit fights the nearest living enemy in weapon range
##   N / Enter = advance to the next turn
##   Escape = return to the overworld

## Which map this scene instance plays. Drives the terrain file, unit roster,
## encounter_spawns filter, and objective logic below.
@export var map_id: String = "map_f00"

## Non-prologue maps have no deploy_row/deploy_col baked into their unit
## data (prologue_roster is the only table with that), so units are spread
## programmatically along one row instead: deploy_row is that row, starting
## at deploy_col_start and stepping by deploy_col_step, clamped to the grid.
## Ignored for map_f00, which still deploys from prologue_roster's own columns.
@export var deploy_unit_ids: Array[String] = []
@export var deploy_row: int = -1
@export var deploy_col_start: int = 1
@export var deploy_col_step: int = 2

## map_a02's rainstorm; no per-map wet flag exists in terrain_costs, so this
## stays a per-scene override rather than a general data field, same
## reasoning as the original WET const.
@export var wet: bool = false

const CELL_SIZE := 32
const IMPASSABLE := 90 # terrain_costs uses 99 as its impassable sentinel

## Only 4 tiles are orthogonally adjacent to any single tile, the statue's
## included -- prologue_tuning's own note: "only 4 orthogonal tiles touch
## the image, so 7 combatants cannot all swing in the same turn -- the
## warband has to ROTATE through it." Real positions exist now, but there's
## still no pathing-to-adjacency check, so this cap stands in for it.
const MAX_STATUE_ATTACKERS_PER_TURN := 4

## Non-prologue units have no per-unit move-tiles stat anywhere in canon.xlsx
## (only movement_type exists, via classes.movement) -- these reuse the same
## numbers prologue_roster's own units already established per movement
## type (Tasme=riding 9, Bel-Iddin=armor 4, the infantry majority 5-6).
const MOVEMENT_TYPE_DEFAULT_MOVE := {"infantry": 5, "armor": 4, "riding": 9, "flying": 7}

## Combined legend across all three maps' symbol vocabularies -- each map
## only ever uses its own subset. map_f00's colors are unchanged; a02/a03's
## are new, chosen to read distinctly (cool grey-blue for a03's cold, warm
## reddish/gold/green accents for the D/R/E objective tiles).
const LEGEND := {
	".": Color("cac6bc"), # court (f00)
	"a": Color("b8b4a8"), # the span, one tile (f00)
	"T": Color("8b8377"), # high terrace (f00)
	"x": Color("3d3a35"), # wall face / temple, impassable (f00)
	"W": Color("a0623c"), # the wall, Enmet turn 1 (f00)
	"g": Color("5e8c5a"), # planted terrace (f00)
	"t": Color("aca89c"), # stair (f00)
	"S": Color("2a2723"), # the image / statue (f00)
	"*": Color("d1a851"), # seize, Sargath only (f00)
	"c": Color("4a7fa3"), # channel (f00)
	"r": Color("6b5d4f"), # rooftop, flying only (a02)
	"b": Color("4a4740"), # building, impassable (a02)
	"d": Color("9c9484"), # wide street (a02)
	"s": Color("7d7568"), # narrow street, foot only (a02)
	"p": Color("b5a892"), # crowd plaza / deploy zone (a02)
	"D": Color("c4443a"), # defend point (a02)
	"i": Color("5c5850"), # cloister, indoor (a03)
	"o": Color("8fa3a8"), # open ward, cold (a03)
	"u": Color("6e655a"), # rubble, cold (a03)
	"R": Color("d4af37"), # reliquary (a03)
	"E": Color("4a8f5c"), # escape tile (a03)
}

const REACHABLE_TINT := Color(0.35, 0.65, 1.0, 0.45)
const ORIGIN_TINT := Color(1.0, 0.9, 0.3, 0.7)
const TOKEN_COLOR := Color(0.15, 0.15, 0.18, 0.9)
const TOKEN_SELECTED_COLOR := Color(1.0, 0.85, 0.2, 0.95)
const TOKEN_MOVED_COLOR := Color(0.35, 0.35, 0.4, 0.9)
const ENEMY_TOKEN_COLOR := Color(0.55, 0.12, 0.12, 0.95)

var grid: Array[String] = []
var terrain_by_symbol: Dictionary = {} # symbol -> terrain_costs row (Dictionary)
var units: Array = [] # roster rows, in deploy order
var unit_hp: Dictionary = {} # punit_id -> current hp (separate from each row's static hp)
var selected_unit_index := 0
var origin: Vector2i = Vector2i(-1, -1)
var current_reachable: Dictionary = {} # Vector2i -> cost, for the currently selected unit
var tile_rects: Dictionary = {} # Vector2i -> ColorRect, so structures can recolor their tiles live
var unit_tokens: Dictionary = {} # punit_id -> {container: Node2D, bg: ColorRect}
var unit_positions: Dictionary = {} # punit_id -> Vector2i, current position (starts at deploy tile)
var seize_pos: Vector2i = Vector2i(-1, -1)
var defend_pos: Vector2i = Vector2i(-1, -1)
var escape_pos: Vector2i = Vector2i(-1, -1)
var escaped_count := 0

var weapons_by_id: Dictionary = {} # weapon_id -> weapons row
var enemy_archetypes_by_id: Dictionary = {} # enemy_id -> enemy_archetypes row
var enemies: Array = [] # {inst_id, kind, archetype, pos, hp, max_hp, defeated, token}
var dens: Array = [] # {spawn_row (Dictionary), waves_spawned: int}
var map_row: Dictionary = {} # this map_id's own row from the maps table

# --- turn / structure / win state -------------------------------------------
var turn := 0
var wall_destroyed := false
var statue_hp := 0
var statue_max_hp := 0
var statue_destroyed := false
var attacked_this_turn: Dictionary = {} # punit_id -> true, reset every turn
var moved_this_turn: Dictionary = {} # punit_id -> true, reset every turn
var map_won := false

var highlight_layer: Node2D
var info_label: Label
var status_label: Label

func _ready() -> void:
	grid = _load_grid("res://data/maps/%s.txt" % map_id)
	if grid.is_empty():
		return
	_index_terrain_costs()
	_index_weapons()
	_index_enemy_archetypes()
	_index_map_row()
	units = _build_units()
	if map_id == "map_f00":
		_index_structures()
	_find_seize_tile()
	_find_defend_tile()
	_find_escape_tile()

	_draw_grid()
	_draw_axis_labels()

	highlight_layer = Node2D.new()
	add_child(highlight_layer)

	for unit in units:
		var pos := Vector2i(int(unit.get("deploy_col", -1)), int(unit.get("deploy_row", -1)))
		if pos.x >= 0 and pos.y >= 0:
			unit_positions[unit.get("punit_id")] = pos
			unit_hp[unit.get("punit_id")] = int(unit.get("hp", 0))
	_draw_unit_tokens()
	_spawn_encounter()

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

func _index_map_row() -> void:
	for row in Canon.get_table("maps"):
		if row["map_id"] == map_id:
			map_row = row
			return

## map_f00 uses prologue_roster directly (deploy_row/deploy_col already on
## each row). Other maps build a synthetic roster by joining unit_base_stats
## (current stats) with units (name/base_class_id) and classes
## (movement_type/weapon_art), then spread deploy positions programmatically
## along deploy_row -- there's no per-unit deploy tile data for the 18 main
## roster the way there is for the 8 prologue units.
func _build_units() -> Array:
	if map_id == "map_f00":
		return Canon.get_table("prologue_roster")

	var units_by_id: Dictionary = {}
	for row in Canon.get_table("units"):
		units_by_id[row["unit_id"]] = row
	var classes_by_id: Dictionary = {}
	for row in Canon.get_table("classes"):
		classes_by_id[row["class_id"]] = row

	var result: Array = []
	for i in deploy_unit_ids.size():
		var unit_id: String = deploy_unit_ids[i]
		var base: Dictionary = {}
		for row in Canon.get_table("unit_base_stats"):
			if row["unit_id"] == unit_id:
				base = row.duplicate()
				break
		if base.is_empty():
			continue
		var uinfo: Dictionary = units_by_id.get(unit_id, {})
		var class_row: Dictionary = classes_by_id.get(uinfo.get("base_class_id"), {})
		var movement_type: String = class_row.get("movement", "infantry")
		var art = class_row.get("art_primary", "none")
		if art == "none":
			art = null

		base["punit_id"] = unit_id
		base["name"] = uinfo.get("name", unit_id)
		base["movement_type"] = movement_type
		base["move"] = MOVEMENT_TYPE_DEFAULT_MOVE.get(movement_type, 5)
		base["weapon_art"] = art
		base["dmg_vs_statue"] = 0
		base["what_they_do"] = "no weapon_art on their class (%s)" % class_row.get("name", "?")

		var col: int = deploy_col_start + i * deploy_col_step
		col = clampi(col, 0, grid[0].length() - 1)
		base["deploy_row"] = deploy_row
		base["deploy_col"] = col
		result.append(base)
	return result

func _find_seize_tile() -> void:
	seize_pos = _find_symbol("*")

func _find_defend_tile() -> void:
	defend_pos = _find_symbol("D")

func _find_escape_tile() -> void:
	escape_pos = _find_symbol("E")

func _find_symbol(symbol: String) -> Vector2i:
	for row in grid.size():
		var col := grid[row].find(symbol)
		if col != -1:
			return Vector2i(col, row)
	return Vector2i(-1, -1)

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

## Mirrors _draw_unit_tokens but for one enemy instance, in
## ENEMY_TOKEN_COLOR so enemies read distinctly from player tokens.
func _draw_enemy_token(inst: Dictionary) -> void:
	var container := Node2D.new()
	container.position = Vector2(inst.pos.x * CELL_SIZE, inst.pos.y * CELL_SIZE)
	add_child(container)

	var bg := ColorRect.new()
	bg.size = Vector2(CELL_SIZE - 6, CELL_SIZE - 6)
	bg.position = Vector2(3, 3)
	bg.color = ENEMY_TOKEN_COLOR
	container.add_child(bg)

	var label := Label.new()
	label.text = String(inst.archetype.get("name", "?")).substr(0, 2)
	label.size = bg.size
	label.position = bg.position
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color.WHITE)
	container.add_child(label)

	inst.token = {"container": container, "bg": bg}

func _remove_enemy_token(inst: Dictionary) -> void:
	if inst.token.has("container"):
		inst.token.container.queue_free()
	inst.token = {}

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

func _index_weapons() -> void:
	for row in Canon.get_table("weapons"):
		weapons_by_id[row["weapon_id"]] = row

func _index_enemy_archetypes() -> void:
	for row in Canon.get_table("enemy_archetypes"):
		enemy_archetypes_by_id[row["enemy_id"]] = row

## One weapon each, no repair (map_f00's own design_note, reused as the
## default for every map since no other map states otherwise) -- every
## combat-capable unit (and every enemy) fights with the *_basic tier of
## their weapon_art.
func _weapon_for_art(art: String) -> Dictionary:
	return weapons_by_id.get("wpn_%s_basic" % art, {})

## Reads encounter_spawns for this map_id. 'boss'/'mook' spawn one instance
## immediately; 'den' rows spawn nothing yet -- they're queued in `dens` and
## fire on their own schedule from _process_dens (see _next_turn).
func _spawn_encounter() -> void:
	var next_id := 0
	for row in Canon.get_table("encounter_spawns"):
		if row["map_id"] != map_id:
			continue
		if row["kind"] == "den":
			dens.append({"spawn_row": row, "waves_spawned": 0})
			continue
		var archetype: Dictionary = enemy_archetypes_by_id.get(row["enemy_id"], {})
		if archetype.is_empty():
			continue
		next_id = _spawn_enemy_instance(archetype, Vector2i(int(row["col"]), int(row["row"])), row["kind"], next_id)

func _spawn_enemy_instance(archetype: Dictionary, pos: Vector2i, kind: String, next_id: int) -> int:
	var inst := {
		"inst_id": "%s_%d" % [archetype["enemy_id"], next_id],
		"kind": kind,
		"archetype": archetype,
		"pos": pos,
		"hp": int(archetype["hp"]),
		"max_hp": int(archetype["hp"]),
		"defeated": false,
		"token": {},
	}
	enemies.append(inst)
	if is_inside_tree() and highlight_layer != null:
		_draw_enemy_token(inst)
	return next_id + 1

## Called once per _next_turn, after `turn` increments. Every den whose
## interval divides the current turn (and hasn't hit max_waves) spawns
## wave_size fresh enemies at its own tile.
func _process_dens() -> void:
	var next_id := enemies.size()
	for den in dens:
		var row: Dictionary = den.spawn_row
		var interval := int(row["spawn_interval"])
		if interval <= 0 or turn % interval != 0:
			continue
		var max_waves = row.get("max_waves")
		if max_waves != null and den.waves_spawned >= int(max_waves):
			continue
		var archetype: Dictionary = enemy_archetypes_by_id.get(row["enemy_id"], {})
		if archetype.is_empty():
			continue
		var wave_size := int(row["wave_size"])
		for i in wave_size:
			next_id = _spawn_enemy_instance(archetype, Vector2i(int(row["col"]), int(row["row"])), "mook", next_id)
		den.waves_spawned += 1
		info_label.text = "Reinforcements: %d more %s arrive." % [wave_size, archetype.get("name")]

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
	if map_won:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local := get_local_mouse_position()
		var col := int(floor(local.x / CELL_SIZE))
		var row := int(floor(local.y / CELL_SIZE))
		if row >= 0 and row < grid.size() and col >= 0 and col < grid[0].length():
			_try_move_to(Vector2i(col, row))
	elif event is InputEventKey and event.pressed:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_A and map_id == "map_f00":
			_attack_statue()
		elif key_event.keycode == KEY_F:
			_attack_enemy()
		elif key_event.keycode == KEY_N or key_event.keycode == KEY_ENTER:
			_next_turn()
		elif key_event.keycode == KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/overworld.tscn")
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
	for inst in enemies:
		if not inst.defeated and inst.pos == pos:
			info_label.text = "That tile is occupied by the %s." % inst.archetype.get("name")
			return

	unit_positions[pid] = pos
	moved_this_turn[pid] = true
	var token = unit_tokens.get(pid)
	if token:
		token.container.position = Vector2(pos.x * CELL_SIZE, pos.y * CELL_SIZE)

	origin = pos
	_recompute_and_draw()
	_refresh_token_color(selected_unit_index)

	# map_f00's seize is Sargath-only (the prologue's own stated rule); every
	# other seize map has no such restriction named, so any unit qualifies.
	var seize_allowed := map_id != "map_f00" or pid == "pu_sargath"
	if map_row.get("objective_verb") == "seize" and seize_allowed and pos == seize_pos and not map_won:
		map_won = true
		status_label.text = "SEIZED. %s reaches the objective." % unit.get("name")
		info_label.text = "Victory. (The endgame branches from here aren't modeled in this tool.)"
		return

	# 'escort' reuses the same reach-the-edge-and-leave shape as 'escape' --
	# both are "get units to a tile," the difference (escorting a specific
	# cargo/NPC unit) isn't modeled, flagged on each escort map's own notes.
	var verb: String = map_row.get("objective_verb", "")
	if (verb == "escape" or verb == "escort") and pos == escape_pos:
		unit_positions.erase(pid)
		if token:
			token.container.queue_free()
		unit_tokens.erase(pid)
		escaped_count += 1
		info_label.text = "%s escapes." % unit.get("name")
		var needed := int(map_row.get("min_solution_units", 1))
		if escaped_count >= needed and not map_won:
			map_won = true
			status_label.text = "ESCAPED. %d units reached the edge and got out." % escaped_count
			info_label.text = "Victory."
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
## and for movement math. map_f00-only (wall_destroyed/statue_destroyed stay
## false everywhere else).
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
	if wet:
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

## Dijkstra over the grid, capped at move_budget. The boards are small so a
## plain O(n^2) extract-min is plenty fast; no need for a heap. Does NOT
## account for other units/enemies occupying tiles -- see the file header.
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
## attack action. map_f00-only.
func _next_turn() -> void:
	turn += 1
	attacked_this_turn.clear()
	moved_this_turn.clear()
	for i in units.size():
		_refresh_token_color(i)
	if map_id == "map_f00" and turn == 1 and not wall_destroyed:
		wall_destroyed = true
		_recolor_symbol("W", LEGEND["."])
	_process_dens()
	_apply_hazard_damage()
	_check_defend_win()
	_recompute_and_draw()
	if not map_won:
		_update_status_label()
		_update_info_label()

## map_a03's cold drain (and any future hazard tile): any unit or living
## enemy standing on a tile with hazard_dmg > 0 at turn end loses that much
## HP. Units at 0 HP are removed from play, same shape as an enemy defeat.
func _apply_hazard_damage() -> void:
	for unit in units:
		var pid: String = unit.get("punit_id", "")
		if not unit_positions.has(pid):
			continue
		var pos: Vector2i = unit_positions[pid]
		var dmg := _hazard_at(pos)
		if dmg <= 0:
			continue
		unit_hp[pid] = max(0, unit_hp.get(pid, 0) - dmg)
		if unit_hp[pid] == 0:
			var token = unit_tokens.get(pid)
			if token:
				token.container.queue_free()
			unit_tokens.erase(pid)
			unit_positions.erase(pid)
			info_label.text = "%s succumbs to the cold." % unit.get("name")
	for inst in enemies:
		if inst.defeated:
			continue
		var dmg := _hazard_at(inst.pos)
		if dmg <= 0:
			continue
		inst.hp = max(0, inst.hp - dmg)
		if inst.hp == 0:
			inst.defeated = true
			_remove_enemy_token(inst)

func _hazard_at(pos: Vector2i) -> int:
	var symbol := _effective_symbol(pos)
	var terrain: Dictionary = terrain_by_symbol.get(symbol, {})
	return int(terrain.get("hazard_dmg", 0))

## map_a02's defend objective: surviving to turn_limit is a win. Defeating
## the boss early also ends the threat and wins immediately (checked in
## _attack_enemy instead, since that's when it can happen).
func _check_defend_win() -> void:
	if map_won or map_row.get("objective_verb") != "defend":
		return
	var limit := int(map_row.get("turn_limit", 0))
	if limit > 0 and turn >= limit:
		map_won = true
		status_label.text = "SURVIVED. Turn %d reached -- the crowd is safe." % turn
		info_label.text = "Victory."

## Attacking is deliberately not gated on real adjacency to the statue --
## there's no pathing-to-adjacency check yet, only the movement_type check
## below and MAX_STATUE_ATTACKERS_PER_TURN standing in for "who can reach it".
## map_f00-only (the only map with a statue).
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

## Auto-targets the nearest living enemy within the selected unit's weapon
## range -- there's no enemy-selection UI, just like there was never a
## unit-selection UI beyond "closest in range" would need. Resolved through
## Combat.gd (weapon triangle, hit/crit/damage RNG and all), one-directional:
## no counterattack (no enemy phase yet), same shape as attacking the statue.
func _attack_enemy() -> void:
	if units.is_empty() or enemies.is_empty():
		return
	var unit: Dictionary = units[selected_unit_index]
	var pid: String = unit.get("punit_id", "")
	var weapon_art = unit.get("weapon_art")

	if weapon_art == null or weapon_art == "":
		info_label.text = "%s cannot fight (%s)." % [unit.get("name"), unit.get("what_they_do")]
		return

	if attacked_this_turn.has(pid):
		info_label.text = "%s has already acted this turn." % unit.get("name")
		return

	var pos: Vector2i = unit_positions.get(pid, Vector2i(-1, -1))
	if pos == Vector2i(-1, -1):
		return

	var weapon := _weapon_for_art(weapon_art)
	if weapon.is_empty():
		return

	var target := _nearest_enemy_in_range(pos, weapon)
	if target.is_empty():
		info_label.text = "No enemy in range for %s." % unit.get("name")
		return

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var result := Combat.resolve_attack(unit, target.archetype, weapon, rng)
	attacked_this_turn[pid] = true

	var ename: String = target.archetype.get("name")
	if not result.hit:
		info_label.text = "%s attacks the %s and misses." % [unit.get("name"), ename]
	else:
		target.hp = max(0, target.hp - int(result.damage))
		var crit_text := " CRITICAL HIT!" if result.crit else ""
		info_label.text = "%s hits the %s for %d damage.%s %d/%d HP remaining." % [
			unit.get("name"), ename, result.damage, crit_text, target.hp, target.max_hp
		]
		if target.hp == 0:
			target.defeated = true
			_remove_enemy_token(target)
			info_label.text += " The %s falls." % ename
			if target.kind == "boss" and map_row.get("objective_verb") == "defend" and not map_won:
				map_won = true
				status_label.text = "The %s falls. Threat neutralized." % ename
				info_label.text = "Victory."
				return

	_update_status_label()

func _nearest_enemy_in_range(pos: Vector2i, weapon: Dictionary) -> Dictionary:
	var range_min := int(weapon.get("range_min", 1))
	var range_max := int(weapon.get("range_max", 1))
	var best: Dictionary = {}
	var best_dist := 999999
	for inst in enemies:
		if inst.defeated:
			continue
		var dist: int = abs(pos.x - inst.pos.x) + abs(pos.y - inst.pos.y)
		if dist < range_min or dist > range_max:
			continue
		if dist < best_dist:
			best_dist = dist
			best = inst
	return best

func _update_status_label() -> void:
	if map_won:
		return
	var lines: Array[String] = []
	var header := "Turn %d" % turn
	if map_id == "map_f00":
		var wall_state := "destroyed (Enmet, turn 1)" if wall_destroyed else "standing"
		var statue_state := "RUBBLE" if statue_destroyed else "%d / %d HP" % [statue_hp, statue_max_hp]
		header += " -- Wall: %s -- Statue: %s" % [wall_state, statue_state]
	var alive := 0
	for inst in enemies:
		if not inst.defeated:
			alive += 1
	header += " -- Enemies alive: %d -- attackers: %d/%d this turn -- moved: %d/%d this turn" % [
		alive, attacked_this_turn.size(), MAX_STATUE_ATTACKERS_PER_TURN, moved_this_turn.size(), units.size()
	]
	lines.append(header)
	var controls := "[F] fight nearest enemy in range -- [N] / Enter: next turn -- click a highlighted tile to move"
	if map_id == "map_f00":
		controls = "[A] attack statue -- " + controls
	lines.append(controls)
	status_label.text = "\n".join(lines)

func _update_info_label(reachable_count := -1) -> void:
	if map_won:
		return
	if units.is_empty():
		info_label.text = "No units loaded."
		return
	var unit: Dictionary = units[selected_unit_index]
	var pid: String = unit.get("punit_id", "")
	var lines: Array[String] = []
	lines.append("[1-9] select unit -- click a highlighted tile to move there")
	lines.append("Selected: %s -- move %s, %s, weapon_art %s, hp %s" % [
		unit.get("name"), unit.get("move"), unit.get("movement_type"),
		unit.get("weapon_art"), unit_hp.get(pid, unit.get("hp"))
	])
	if moved_this_turn.has(pid):
		lines.append("At (%d, %d) -- already moved this turn." % [origin.x, origin.y])
	elif origin != Vector2i(-1, -1):
		lines.append("At (%d, %d) -- %d tiles reachable" % [origin.x, origin.y, reachable_count])
	info_label.text = "\n".join(lines)
