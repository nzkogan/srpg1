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
##   F   = selected unit attacks the targeted enemy in weapon range (the
##         forecast panel shows damage / hit / crit / speed first; Tab or a
##         click on an enemy chooses the target)
##   C   = Capture (units with the Capture action): take the targeted enemy
##         alive once it is weakened -- it leaves the map, no kill, no drop
##   S   = Shove / Smite (Gunnar; Housecarls): then an arrow key (or a click) on
##         an adjacent unit pushes it straight back 1 tile (Smite: 2)
##   T   = Talk: then an arrow key (or a click) on an adjacent enemy tries to talk it
##         down (a chance; only some enemies listen) -- it leaves the map unharmed
##   W   = select the next cargo unit (maps with cargo: walk it to the E tile)
##   B   = Bribe (Kheldar): then an arrow key (or a click) on an adjacent enemy
##         pays gold to turn it neutral for the rest of the map (one a map, no bosses)
##   N / Enter = advance to the next turn
##   Escape = return to the overworld
##   S (after a win that raised a support rank) = read the new scene(s)

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

const ForecastView := preload("res://scripts/forecast_view.gd")
const FORECAST_X_GAP := 36
const MAX_ENEMY_LOG_SHOWN := 3

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
##
## flying=7 has no such source -- prologue_roster's 8 units are all ground
## types, nothing flies in it. Calibrated 2026-09-25 by flood-filling
## reachable tiles under each type's own budget across 5 real built maps
## (open ground, terrace/lake, lava-road, rubble+statue, forest canopy):
## on open/mixed terrain flying reaches roughly 60-70% of riding's tile
## count, tracking budget-squared (7^2/9^2=60%) almost exactly -- internally
## consistent, not degenerate. On map_a08 (forest canopy, ter_cloister
## blocks flying outright) flying's reach collapsed to near-zero, which is
## the location's own grounding working as intended ("fliers worthless,
## archers not"), not a bug. Left unchanged: flying's real value is
## exclusive access to flying-only terrain (channels, statue/colossus
## tops) and hazard/block immunity, not raw tile count, so a lower budget
## than riding's 9 isn't itself evidence of a problem -- there was nothing
## in this test that called for a different number.
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
const NEUTRAL_TOKEN_COLOR := Color(0.62, 0.55, 0.18, 0.95) # a bribed enemy: stood down for the map
const ARROW_DIRS := {KEY_UP: Vector2i(0, -1), KEY_DOWN: Vector2i(0, 1), KEY_LEFT: Vector2i(-1, 0), KEY_RIGHT: Vector2i(1, 0)}

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
## Test seam: when set, _attack_enemy rolls with this RNG instead of a freshly
## randomized one, so tests can pin the outcome. Always null in play.
var rng_override: RandomNumberGenerator = null
var forecast_label: RichTextLabel
var _targets: Array = []       # living enemies in the selected unit's weapon range, nearest first
## Deed telemetry for this map (see "Deeds" below): which units were hit, which
## struck, and each unit's run of enemy phases holding one tile alone.
var struck_units: Dictionary = {}   # pid -> true once an enemy strike has hit them
var fought_units: Dictionary = {}   # pid -> true once they have made a strike
var hold_streak: Dictionary = {}    # pid -> {"tile": Vector2i, "phases": int}
var _phase_targets: Dictionary = {} # pids an enemy attacked in the current enemy phase
var _target_idx := 0
var _shove_mode := false       # [S] pressed: the next arrow key / click picks who to push
var _bribe_mode := false       # [B] pressed: the next arrow key / click picks who to bribe
var bribed_count := 0          # enemies turned neutral on this map (Kheldar's bribe)
var _talk_mode := false        # [T] pressed: the next arrow key / click picks who to talk to
var delivered: Array[String] = []   # cargo ids that have reached the goal on this map
var map_lost := false          # every player unit gone: no win is possible
## Test seam: the support tests play whole maps by calling _next_turn() and
## need the player's units to survive; they switch the enemy phase off. Always
## true in play.
var enemy_phase_enabled := true
var enemy_log: Array[String] = []  # what the last enemy phase did, newest last
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
## Setter rather than a call at each of the four places a map can be won
## (seize, escape, survive, boss-defend): any false -> true transition banks
## this map's support points. See Supports.settle_map().
var map_won := false:
	set(value):
		var newly_won: bool = value and not map_won
		map_won = value
		if newly_won:
			_on_map_won()
var chapter_route := ""  # this map's chapter route ("diadem"/"assembly"/"both"); gates cross-route supports

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
	var chapter = Canon.find_by("chapters", "chapter_id", map_row.get("chapter_id", ""))
	chapter_route = chapter["route"] if chapter != null else ""
	Supports.begin_map()
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

	forecast_label = RichTextLabel.new()
	forecast_label.bbcode_enabled = true
	forecast_label.scroll_active = false
	forecast_label.position = Vector2(grid[0].length() * CELL_SIZE + FORECAST_X_GAP, 0)
	forecast_label.size = Vector2(maxf(300.0, 1152.0 - forecast_label.position.x - 8.0), 440)
	forecast_label.visible = false
	add_child(forecast_label)

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
		# proficient arts -- what a weapon's req_arts is checked against
		base["arts"] = Equipment.unit_arts(unit_id)
		if Progression.is_known_unit(unit_id):
			_apply_progression(base, unit_id)
		base["dmg_vs_statue"] = 0
		base["what_they_do"] = "no weapon_art on their class (%s)" % class_row.get("name", "?")

		var col: int = deploy_col_start + i * deploy_col_step
		col = clampi(col, 0, grid[0].length() - 1)
		base["deploy_row"] = deploy_row
		base["deploy_col"] = col
		result.append(base)
	result.append_array(_cargo_rows())
	return result

## The map's cargo units (canon's cargo_units) as player-side roster rows: they can't
## fight, move like their movement type, and are what the escort objective is about.
func _cargo_rows() -> Array:
	var rows: Array = []
	for cu in Canon.get_table("cargo_units"):
		if cu["map_id"] != map_id:
			continue
		var movement := str(cu.get("movement", "armor"))
		rows.append({
			"punit_id": cu["cargo_id"], "name": cu["name"], "cargo": true, "level": 1,
			"hp": int(cu["hp"]), "str": 0, "mag": 0, "dex": 0, "spd": 0, "lck": 0, "def": int(cu["def"]), "res": int(cu["res"]),
			"movement_type": movement, "move": MOVEMENT_TYPE_DEFAULT_MOVE.get(movement, 4),
			"weapon_art": null, "arts": [], "dmg_vs_statue": 0, "what_they_do": "cargo -- cannot fight",
			"deploy_row": int(cu["spawn_row"]), "deploy_col": int(cu["spawn_col"]),
		})
	return rows

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
		next_id = _spawn_enemy_instance(archetype, Vector2i(int(row["col"]), int(row["row"])), row["kind"], next_id, row)

func _spawn_enemy_instance(archetype: Dictionary, pos: Vector2i, kind: String, next_id: int, spawn_row: Dictionary = {}) -> int:
	var inst := {
		"spawn_id": spawn_row.get("spawn_id", ""),
		"drop": spawn_row.get("drop_weapon_id"),   # weapon id or null; den waves never drop
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
	if map_won or map_lost:
		# The battle is over: only the way out, and (after a win) the support link, still work.
		if event is InputEventKey and event.pressed:
			var key := (event as InputEventKey).keycode
			if key == KEY_ESCAPE:
				get_tree().change_scene_to_file("res://scenes/overworld.tscn")
			elif key == KEY_S and map_won and not _support_entries.is_empty():
				open_support_viewer()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local := get_local_mouse_position()
		var col := int(floor(local.x / CELL_SIZE))
		var row := int(floor(local.y / CELL_SIZE))
		if _talk_mode:
			_talk_click(Vector2i(col, row))
		elif _bribe_mode:
			_bribe_click(Vector2i(col, row))
		elif _shove_mode:
			_shove_click(Vector2i(col, row))
		elif row >= 0 and row < grid.size() and col >= 0 and col < grid[0].length():
			if not _try_target_click(Vector2i(col, row)):
				_try_move_to(Vector2i(col, row))
	elif event is InputEventKey and event.pressed:
		var key_event := event as InputEventKey
		if _talk_mode:
			_talk_key(key_event.keycode)
			return
		if _bribe_mode:
			_bribe_key(key_event.keycode)
			return
		if _shove_mode:
			_shove_key(key_event.keycode)
			return
		if key_event.keycode == KEY_T:
			_begin_talk()
		elif key_event.keycode == KEY_W:
			_select_next_cargo()
		elif key_event.keycode == KEY_B:
			_begin_bribe()
		elif key_event.keycode == KEY_S:
			_begin_shove()
		elif key_event.keycode == KEY_A and map_id == "map_f00":
			_attack_statue()
		elif key_event.keycode == KEY_F:
			_attack_enemy()
		elif key_event.keycode == KEY_C:
			_capture_enemy()
		elif key_event.keycode == KEY_TAB:
			_cycle_target()
		elif key_event.keycode == KEY_E:
			_cycle_weapon()
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
	if _cargo_needed() > 0:
		# a map with cargo: the goal is for the CARGO to reach it; nobody else escapes
		if pos == escape_pos and _is_cargo(pid):
			_deliver(pid)
			return
	elif (verb == "escape" or verb == "escort") and pos == escape_pos:
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
		_update_forecast()
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
	_update_forecast()

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
	# unit_positions holds only living units (hazard deaths erase their entry),
	# so this is exactly "who was standing where when the turn ended". Turn 0
	# is the pre-game deploy screen, not a played turn.
	if turn > 0:
		Supports.record_turn_end(unit_positions, chapter_route)
		var miasma_lines := _miasma_deeds()
		_enemy_phase()
		enemy_log.append_array(miasma_lines)
		if map_lost:
			return
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

var _support_lines: Array[String] = []
var _support_entries: Array = []   # this win's Supports.settle_map() results

var _reward_text := ""

func _on_map_won() -> void:
	_support_lines.clear()
	_reward_text = _settle_rewards()
	if _reward_text != "":
		call_deferred("_show_rewards")
	_support_entries = Supports.settle_map(map_id)
	GameState.won_maps[map_id] = true
	SaveGame.autosave()
	for entry in _support_entries:
		_support_lines.append(Supports.describe_raise(entry))
	if not _support_lines.is_empty():
		# The win sites set info_label.text right after assigning map_won,
		# which would overwrite anything written here -- append after they run.
		call_deferred("_show_support_lines")

## The window is only ~650px tall and a map can raise many ranks at once (nine
## on d05 in testing), so the way into the viewer comes first and the list is
## capped to what fits under the map; the viewer's NEW tags carry the rest.
const MAX_SUPPORT_LINES_SHOWN := 2

## Income and class unlocks for a win. Gold: 200 + 15 per enemy defeated + 25 per
## enemy captured + 10 per enemy routed + 20 per enemy talked down (x1.5 if Kheldar is still on the map), paid once per map. Returns the line to show.
func _settle_rewards() -> String:
	if map_id == "map_f00":
		return ""     # the prologue has no income and none of the main roster
	var kills := 0
	var captures := 0
	var routs := 0
	var talks := 0
	for e in enemies:
		if e.defeated:
			if e.get("captured", false):
				captures += 1
			elif e.get("routed", false):
				routs += 1
			elif e.get("talked", false):
				talks += 1
			else:
				kills += 1
	var factor := unit_positions.has("u_kheldar")
	var gold := Progression.award_income(map_id, kills, factor, captures, routs, talks)
	var parts: Array[String] = []
	if gold > 0:
		parts.append("Income: +%d gold%s." % [gold, " (Kheldar's cut)" if factor else ""])
	parts.append_array(_no_hit_deeds())
	var unlocked := Progression.on_map_won(map_id)
	if not unlocked.is_empty():
		parts.append("Class unlocked: %s." % ", ".join(unlocked))
	return " ".join(parts)

func _show_rewards() -> void:
	if status_label != null and _reward_text != "":
		status_label.text += "\n" + _reward_text

func _show_support_lines() -> void:
	if info_label == null:
		return
	var shown := _support_lines.slice(0, MAX_SUPPORT_LINES_SHOWN)
	var extra := _support_lines.size() - shown.size()
	var out: Array[String] = ["Press S to read the new support %s, Escape to leave." % \
		("scene" if _support_entries.size() == 1 else "scenes (%d)" % _support_entries.size())]
	out.append_array(shown)
	if extra > 0:
		out.append("...and %d more." % extra)
	info_label.text += "\n" + "\n".join(out)

## Opens the support viewer on the first rank this win raised; N there steps
## through the rest.
func open_support_viewer() -> void:
	GameState.support_focus = _support_entries[0]["chain_id"]
	get_tree().change_scene_to_file(Supports.VIEWER_SCENE)

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
			_kill_unit(pid)
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
	_check_defeat()

func _hazard_at(pos: Vector2i) -> int:
	var symbol := _effective_symbol(pos)
	var terrain: Dictionary = terrain_by_symbol.get(symbol, {})
	return int(terrain.get("hazard_dmg", 0))

## 'defend' (a02) and 'survive' (d05) share the same shape: reaching
## turn_limit is a win. Defeating a boss early also ends the threat and
## wins immediately for 'defend' maps (checked in _attack_enemy instead,
## since that's when it can happen) -- d05 has no boss row, only mooks/dens,
## so that early-win branch never fires there.
func _check_defend_win() -> void:
	var verb: String = map_row.get("objective_verb", "")
	if map_won or (verb != "defend" and verb != "survive"):
		return
	var limit := int(map_row.get("turn_limit", 0))
	if limit > 0 and turn >= limit:
		map_won = true
		status_label.text = "SURVIVED. Turn %d reached." % turn
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

## Attacks the enemy the forecast panel is showing (nearest in weapon range
## unless Tab or a click picked another). Resolved through Combat.resolve_exchange:
## the attacker strikes, the enemy counters if the attacker is inside its weapon
## range, and whichever side is 4+ attack speed faster follows up. A unit at 0 HP
## leaves the map.
func _attack_enemy() -> void:
	if units.is_empty() or enemies.is_empty() or map_won or map_lost:
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

	var weapon := _weapon_for_unit(unit)
	if weapon.is_empty():
		info_label.text = "%s has no weapon they are proficient with." % unit.get("name")
		return

	var target := _current_target(pos, weapon)
	if target.is_empty():
		info_label.text = "No enemy in range for %s." % unit.get("name")
		return

	var info := _forecast_info(unit, target)
	var rng := rng_override
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var result := Combat.resolve_exchange(info["attacker"], info["defender"], weapon, info["def_weapon"],
		info["distance"], rng, int(unit_hp.get(pid, 0)), int(target.hp), _uses_of(unit), -1)
	attacked_this_turn[pid] = true
	var ename: String = target.archetype.get("name")
	var lines := _describe_exchange(result, unit.get("name"), "the %s" % ename)
	var hp_before: int = target.hp
	target.hp = int(result["def_hp"])
	unit_hp[pid] = int(result["atk_hp"])
	var deed_lines := _note_exchange(pid, target, result, hp_before)
	info_label.text = lines + _support_note(info["support"]) + _spend_uses(unit, int(result["atk_strikes"]))

	if target.hp == 0:
		info_label.text += " The %s falls." % ename
		var drop := _defeat_enemy(target)
		if drop != "":
			info_label.text += " It drops a %s (added to the convoy)." % drop
		if map_won:
			return
	if int(unit_hp[pid]) == 0:
		_kill_unit(pid)
		info_label.text += " %s falls." % unit.get("name")
		_check_defeat()
	else:
		var gained := _award_exp(unit, target, target.hp == 0, rng)
		if not gained.is_empty():
			info_label.text += "\n" + " ".join(gained)
	if not deed_lines.is_empty():
		info_label.text += "\n" + " ".join(deed_lines)

	_update_status_label()
	_update_forecast()

## [C]: the selected unit takes the targeted enemy ALIVE. Only units whose class
## carries the Capture action (classes.map_actions) may, the enemy must be at or
## below capture_hp_pct of its HP and not a boss, and it takes the unit's action
## for the turn. No exchange happens: the enemy simply leaves the map. It counts
## as a fight (so it can't be a no-hit-map spoiler) and earns the EXP of a kill,
## but drops nothing and pays a ransom at the end of the map instead
## (income_per_capture). Each capture is one step toward the capture deed.
func _capture_enemy() -> void:
	if units.is_empty() or enemies.is_empty() or map_won or map_lost:
		return
	var unit: Dictionary = units[selected_unit_index]
	var pid: String = unit.get("punit_id", "")
	if not _is_roster_unit(unit) or not Progression.can_capture(pid):
		info_label.text = "%s has no Capture action." % unit.get("name")
		return
	if attacked_this_turn.has(pid):
		info_label.text = "%s has already acted this turn." % unit.get("name")
		return
	var pos: Vector2i = unit_positions.get(pid, Vector2i(-1, -1))
	if pos == Vector2i(-1, -1):
		return
	var weapon := _weapon_for_unit(unit)
	if weapon.is_empty():
		info_label.text = "%s has no weapon to hold a captive with." % unit.get("name")
		return
	var target := _current_target(pos, weapon)
	if target.is_empty():
		info_label.text = "No enemy in range for %s." % unit.get("name")
		return
	var ename: String = target.archetype.get("name")
	var check := Progression.capture_check(int(target.hp), int(target.max_hp), target.kind == "boss")
	if not check["ok"]:
		info_label.text = "The %s cannot be captured: %s." % [ename, check["reason"]]
		return
	var rng := rng_override
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	attacked_this_turn[pid] = true
	fought_units[pid] = true
	target.defeated = true
	target["captured"] = true
	_remove_enemy_token(target)
	info_label.text = "%s takes the %s alive. It leaves the map and drops nothing." % [unit.get("name"), ename]
	var more := _award_exp(unit, target, true, rng)
	more.append_array(_capture_deed(pid, unit.get("name")))
	info_label.text += "\n" + " ".join(more)
	_update_status_label()
	_update_forecast()

## [S]: the selected unit offers a Shove (or Smite): the next arrow key, or a click
## on an adjacent tile, picks who gets pushed. Any other key cancels.
func _begin_shove() -> void:
	if units.is_empty():
		return
	var unit: Dictionary = units[selected_unit_index]
	var pid: String = unit.get("punit_id", "")
	if not _is_roster_unit(unit) or Progression.shove_distance(pid) <= 0:
		info_label.text = "%s has no Shove action." % unit.get("name")
		return
	if attacked_this_turn.has(pid):
		info_label.text = "%s has already acted this turn." % unit.get("name")
		return
	_shove_mode = true
	info_label.text = "%s: push which way? Arrow key or click an adjacent unit (any other key cancels). %s pushes %d tile%s." % [
		Progression.push_name(pid), unit.get("name"), Progression.shove_distance(pid), "" if Progression.shove_distance(pid) == 1 else "s"]

func _shove_key(keycode: int) -> void:
	if ARROW_DIRS.has(keycode):
		_shove_toward(ARROW_DIRS[keycode])
	else:
		_shove_mode = false
		info_label.text = "Shove cancelled."

func _shove_click(tile: Vector2i) -> void:
	if units.is_empty():
		_shove_mode = false
		return
	var pos: Vector2i = unit_positions.get(units[selected_unit_index].get("punit_id", ""), Vector2i(-1, -1))
	if _distance(pos, tile) == 1:
		_shove_toward(tile - pos)
	else:
		_shove_mode = false
		info_label.text = "Shove cancelled."

## Who stands on `tile`: {"enemy": inst} for a living enemy, {"ally": pid} for a
## player unit, {} for nobody.
func _occupant(tile: Vector2i) -> Dictionary:
	for inst in enemies:
		if not inst.defeated and inst.pos == tile:
			return {"enemy": inst}
	for pid in unit_positions:
		if unit_positions[pid] == tile:
			return {"ally": pid}
	return {}

## Where a push of up to `dist` tiles from `from` along `dir` ends, and what
## stopped it: {"dest": tile, "stopped_by": {} if it went the whole way, else
## {"kind": "edge" | "wall" | "unit", "who": _occupant() result for a unit}}.
## Hazard ground is no obstacle -- pushing someone onto it is the point.
func _push_path(from: Vector2i, dir: Vector2i, dist: int, movement_type: String) -> Dictionary:
	var cur := from
	for i in dist:
		var n := cur + dir
		if n.y < 0 or n.y >= grid.size() or n.x < 0 or n.x >= grid[0].length():
			return {"dest": cur, "stopped_by": {"kind": "edge"}}
		if _terrain_cost(n, movement_type) >= IMPASSABLE:
			return {"dest": cur, "stopped_by": {"kind": "wall"}}
		var occ := _occupant(n)
		if not occ.is_empty():
			return {"dest": cur, "stopped_by": {"kind": "unit", "who": occ}}
		cur = n
	return {"dest": cur, "stopped_by": {}}

## Display name of an _occupant() result, as it reads mid-sentence.
func _occupant_label(who: Dictionary) -> String:
	if who.has("enemy"):
		return "the %s" % who["enemy"].archetype.get("name")
	for u in units:
		if u.get("punit_id", "") == who["ally"]:
			return str(u.get("name"))
	return str(who["ally"])

## A collision hurts `who` for collision_pct of its own max HP (never lethal) and
## returns the damage. An enemy hurt this way counts as damaged by `pusher`, so
## a boss stays "single combat" only if nobody else has touched it.
func _collide(who: Dictionary, pusher: String) -> int:
	if who.has("enemy"):
		var inst: Dictionary = who["enemy"]
		var dmg := Progression.collision_damage(int(inst.hp), int(inst.max_hp))
		var hp_before: int = inst.hp
		inst.hp = int(inst.hp) - dmg
		_note_damage(inst, pusher, hp_before)
		return dmg
	var ally: String = who["ally"]
	var max_hp := 0
	for u in units:
		if u.get("punit_id", "") == ally:
			max_hp = int(u.get("hp", 0))
	var dmg := Progression.collision_damage(int(unit_hp.get(ally, 0)), max_hp)
	unit_hp[ally] = int(unit_hp.get(ally, 0)) - dmg
	return dmg

## The push itself. The selected unit pushes whoever stands on the adjacent tile
## in `dir` straight away from itself -- an enemy or a friend -- and that takes
## its action. No counter, and a pushed unit arrives without triggering the
## map's objective tiles. Bosses hold their ground; armor resists
## shove_armor_resist tiles (a push resisted to nothing is refused, free). A push
## that meets a wall, the map's edge or another unit COLLIDES: the pushed unit
## takes collision_pct of its max HP, and so does a unit it hits -- never enough
## to kill. There are no ledges to be pushed off.
func _shove_toward(dir: Vector2i) -> void:
	_shove_mode = false
	if units.is_empty() or map_won or map_lost:
		return
	var unit: Dictionary = units[selected_unit_index]
	var pid: String = unit.get("punit_id", "")
	var dist := Progression.shove_distance(pid) if _is_roster_unit(unit) else 0
	if dist <= 0:
		info_label.text = "%s has no Shove action." % unit.get("name")
		return
	if attacked_this_turn.has(pid):
		info_label.text = "%s has already acted this turn." % unit.get("name")
		return
	var pos: Vector2i = unit_positions.get(pid, Vector2i(-1, -1))
	if pos == Vector2i(-1, -1):
		return
	var tile := pos + dir
	var who := _occupant(tile)
	if who.is_empty():
		info_label.text = "There is nobody to push there."
		return
	var label := _occupant_label(who)
	var movement := "infantry"
	if who.has("enemy"):
		var inst: Dictionary = who["enemy"]
		movement = str(inst.archetype.get("movement_type", "infantry"))
		if inst.kind == "boss":
			info_label.text = "%s holds its ground and will not be pushed." % _cap(label)
			return
	else:
		for u in units:
			if u.get("punit_id", "") == who["ally"]:
				movement = str(u.get("movement_type", "infantry"))
	var reach := Progression.push_distance_for(dist, movement)
	var verb := "smites" if Progression.push_name(pid) == "Smite" else "shoves"
	if reach <= 0:
		info_label.text = "%s is too heavy to be moved by a %s." % [_cap(label), Progression.push_name(pid)]
		return
	var path := _push_path(tile, dir, reach, movement)
	var dest: Vector2i = path["dest"]
	var moved := _distance(tile, dest)
	if moved > 0:
		if who.has("enemy"):
			_enemy_move(who["enemy"], dest)
		else:
			var ally: String = who["ally"]
			unit_positions[ally] = dest
			var token = unit_tokens.get(ally)
			if token:
				token.container.position = Vector2(dest.x * CELL_SIZE, dest.y * CELL_SIZE)
	attacked_this_turn[pid] = true
	var text := "%s %s %s back %d tile%s" % [unit.get("name"), verb, label, moved, "" if moved == 1 else "s"] if moved > 0 \
		else "%s %s %s, but it cannot move" % [unit.get("name"), verb, label]
	var stopped: Dictionary = path["stopped_by"]
	if stopped.is_empty():
		text += " (too heavy to go further)." if moved < dist else "."
	else:
		var into := "the map's edge" if stopped["kind"] == "edge" else ("the wall" if stopped["kind"] == "wall" else _occupant_label(stopped["who"]))
		text += "; %s slams into %s." % [label, into]
		var hurt: Array = [[_cap(label), _collide(who, pid)]]
		if stopped["kind"] == "unit":
			hurt.append([_cap(_occupant_label(stopped["who"])), _collide(stopped["who"], pid)])
		var parts: Array[String] = []
		for h in hurt:
			if int(h[1]) > 0:
				parts.append("%s takes %d damage" % [h[0], h[1]])
		if not parts.is_empty():
			text += " " + ", ".join(parts) + "."
	info_label.text = text
	_update_status_label()
	_update_forecast()

func _cap(text: String) -> String:
	return text.substr(0, 1).to_upper() + text.substr(1)

## [B]: Kheldar offers a bribe. Lists what each adjacent enemy would cost; the next
## arrow key (or a click) picks one, any other key cancels.
func _begin_bribe() -> void:
	if units.is_empty():
		return
	var unit: Dictionary = units[selected_unit_index]
	var pid: String = unit.get("punit_id", "")
	if not _is_roster_unit(unit) or not Progression.can_bribe(pid):
		info_label.text = "%s has no Bribe action." % unit.get("name")
		return
	if attacked_this_turn.has(pid):
		info_label.text = "%s has already acted this turn." % unit.get("name")
		return
	if bribed_count >= Progression.bribe_limit():
		info_label.text = "%s has already bought off all he can on this map." % unit.get("name")
		return
	var pos: Vector2i = unit_positions.get(pid, Vector2i(-1, -1))
	var offers: Array[String] = []
	for n in _neighbors(pos):
		var who := _occupant(n)
		if who.has("enemy") and not who["enemy"].get("neutral", false):
			var inst: Dictionary = who["enemy"]
			var lvl := int(inst.archetype.get("level", 1))
			offers.append("%s: %s" % [_cap(_occupant_label(who)), "cannot be bought" if inst.kind == "boss" else "Lv %d, %d gold" % [lvl, Progression.bribe_cost(lvl)]])
	if offers.is_empty():
		info_label.text = "There is no enemy beside %s to bribe." % unit.get("name")
		return
	_bribe_mode = true
	info_label.text = "Bribe: which way? Arrow key or click an adjacent enemy (any other key cancels). %s. You have %d gold." % ["; ".join(offers), GameState.gold]

func _bribe_key(keycode: int) -> void:
	if ARROW_DIRS.has(keycode):
		_bribe_toward(ARROW_DIRS[keycode])
	else:
		_bribe_mode = false
		info_label.text = "Bribe cancelled."

func _bribe_click(tile: Vector2i) -> void:
	if units.is_empty():
		_bribe_mode = false
		return
	var pos: Vector2i = unit_positions.get(units[selected_unit_index].get("punit_id", ""), Vector2i(-1, -1))
	if _distance(pos, tile) == 1:
		_bribe_toward(tile - pos)
	else:
		_bribe_mode = false
		info_label.text = "Bribe cancelled."

## The bribe itself: the adjacent enemy in `dir` is paid off. It costs gold
## (bribe_cost_base + bribe_cost_per_level x its level) and the unit's action;
## the enemy turns NEUTRAL for the rest of the map -- it stops acting, can't be
## attacked or captured, but still stands where it is (it blocks, and can still be
## shoved). It is neither a kill nor a capture, so it pays no income. Bosses can't
## be bought. Refusals (no gold, none left, a boss) cost nothing.
func _bribe_toward(dir: Vector2i) -> void:
	_bribe_mode = false
	if units.is_empty() or map_won or map_lost:
		return
	var unit: Dictionary = units[selected_unit_index]
	var pid: String = unit.get("punit_id", "")
	if not _is_roster_unit(unit) or not Progression.can_bribe(pid):
		info_label.text = "%s has no Bribe action." % unit.get("name")
		return
	if attacked_this_turn.has(pid):
		info_label.text = "%s has already acted this turn." % unit.get("name")
		return
	if bribed_count >= Progression.bribe_limit():
		info_label.text = "%s has already bought off all he can on this map." % unit.get("name")
		return
	var pos: Vector2i = unit_positions.get(pid, Vector2i(-1, -1))
	if pos == Vector2i(-1, -1):
		return
	var who := _occupant(pos + dir)
	if not who.has("enemy"):
		info_label.text = "There is nobody there to bribe."
		return
	var inst: Dictionary = who["enemy"]
	var label := _occupant_label(who)
	if inst.get("neutral", false):
		info_label.text = "%s has already been paid off." % _cap(label)
		return
	if inst.kind == "boss":
		info_label.text = "%s cannot be bought." % _cap(label)
		return
	var cost := Progression.bribe_cost(int(inst.archetype.get("level", 1)))
	if GameState.gold < cost:
		info_label.text = "%s wants %d gold and you have %d." % [_cap(label), cost, GameState.gold]
		return
	GameState.gold -= cost
	bribed_count += 1
	inst["neutral"] = true
	if inst.token.has("bg"):
		inst.token.bg.color = NEUTRAL_TOKEN_COLOR
	attacked_this_turn[pid] = true
	info_label.text = "%s presses a purse into the hand of %s (%d gold). It stands down for the rest of the map. %d gold left." % [unit.get("name"), label, cost, GameState.gold]
	_update_status_label()
	_update_forecast()

## [T]: the selected unit tries to talk an adjacent enemy down. Lists the odds for each
## adjacent enemy that will listen; the next arrow key (or a click) picks one, any other
## key cancels.
func _begin_talk() -> void:
	if units.is_empty():
		return
	var unit: Dictionary = units[selected_unit_index]
	var pid: String = unit.get("punit_id", "")
	if not _is_roster_unit(unit) or map_id == "map_f00":
		info_label.text = "%s has no one to talk to here." % unit.get("name")
		return
	if attacked_this_turn.has(pid):
		info_label.text = "%s has already acted this turn." % unit.get("name")
		return
	var pos: Vector2i = unit_positions.get(pid, Vector2i(-1, -1))
	var offers: Array[String] = []
	for n in _neighbors(pos):
		var who := _occupant(n)
		if who.has("enemy") and not who["enemy"].get("neutral", false):
			var inst: Dictionary = who["enemy"]
			if not Progression.can_talk_to(inst.archetype):
				offers.append("%s: nothing to say" % _cap(_occupant_label(who)))
			elif inst.get("talk_failed", false):
				offers.append("%s: has stopped listening" % _cap(_occupant_label(who)))
			else:
				offers.append("%s: %d%%" % [_cap(_occupant_label(who)), _talk_chance_for(unit, inst)])
	if offers.is_empty():
		info_label.text = "There is no enemy beside %s to talk to." % unit.get("name")
		return
	_talk_mode = true
	info_label.text = "Talk: which way? Arrow key or click an adjacent enemy (any other key cancels). %s." % "; ".join(offers)

func _talk_chance_for(unit: Dictionary, inst: Dictionary) -> int:
	return Progression.talk_chance(int(unit.get("lck", 0)), int(unit.get("level", 1)), inst.archetype)

func _talk_key(keycode: int) -> void:
	if ARROW_DIRS.has(keycode):
		_talk_toward(ARROW_DIRS[keycode])
	else:
		_talk_mode = false
		info_label.text = "Talk cancelled."

func _talk_click(tile: Vector2i) -> void:
	if units.is_empty():
		_talk_mode = false
		return
	var pos: Vector2i = unit_positions.get(units[selected_unit_index].get("punit_id", ""), Vector2i(-1, -1))
	if _distance(pos, tile) == 1:
		_talk_toward(tile - pos)
	else:
		_talk_mode = false
		info_label.text = "Talk cancelled."

## The attempt: a roll against talk_chance. A yielded enemy leaves the map unharmed (its
## talk_line says why) -- no kill, no drop, EXP as for a kill, a little income at the end --
## and the speaker earns the talk deed. A boss that yields still ends a 'defend' map. A
## failure costs the action and that enemy won't listen again this map. An enemy with
## nothing to say, or that has stopped listening, is refused for free.
func _talk_toward(dir: Vector2i) -> void:
	_talk_mode = false
	if units.is_empty() or map_won or map_lost:
		return
	var unit: Dictionary = units[selected_unit_index]
	var pid: String = unit.get("punit_id", "")
	if not _is_roster_unit(unit) or map_id == "map_f00":
		info_label.text = "%s has no one to talk to here." % unit.get("name")
		return
	if attacked_this_turn.has(pid):
		info_label.text = "%s has already acted this turn." % unit.get("name")
		return
	var pos: Vector2i = unit_positions.get(pid, Vector2i(-1, -1))
	if pos == Vector2i(-1, -1):
		return
	var who := _occupant(pos + dir)
	if not who.has("enemy") or who["enemy"].get("neutral", false):
		info_label.text = "There is nobody there to talk to."
		return
	var inst: Dictionary = who["enemy"]
	var label := _occupant_label(who)
	if not Progression.can_talk_to(inst.archetype):
		info_label.text = "%s has nothing to say to %s." % [_cap(label), unit.get("name")]
		return
	if inst.get("talk_failed", false):
		info_label.text = "%s has stopped listening." % _cap(label)
		return
	var rng := rng_override
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var chance := _talk_chance_for(unit, inst)
	var roll := rng.randi_range(1, 100)
	attacked_this_turn[pid] = true
	fought_units[pid] = true
	if roll > chance:
		inst["talk_failed"] = true
		info_label.text = "%s tries to talk the %s down, but it will not hear it (%d%%)." % [unit.get("name"), inst.archetype.get("name"), chance]
		_update_status_label()
		_update_forecast()
		return
	inst.defeated = true
	inst["talked"] = true
	_remove_enemy_token(inst)
	var text := "%s talks the %s down (%d%%): \"%s\"" % [unit.get("name"), inst.archetype.get("name"), chance, inst.archetype.get("talk_line", "...")]
	var more := _award_exp(unit, inst, true, rng)
	more.append_array(_talk_deed(pid, unit.get("name")))
	text += "\n" + " ".join(more)
	_boss_resolved(inst, "yields")
	info_label.text = ("Victory. " if map_won else "") + text
	_update_status_label()
	_update_forecast()

func _talk_deed(pid: String, unit_name: String) -> Array[String]:
	return _earn_deed(pid, "ep_talk", unit_name)

## One more capture for `pid`: announces the deed when it is earned, else how far along it is.
func _capture_deed(pid: String, unit_name: String) -> Array[String]:
	var lines := _earn_deed(pid, "ep_capture", unit_name)
	if lines.is_empty() and Progression.is_known_unit(pid) and map_id != "map_f00":
		var need := Progression.count_needed("ep_capture")
		var got := Progression.deed_count(pid, "ep_capture")
		if got < need:
			lines.append("%s has taken %d of %d captives." % [unit_name, got, need])
	return lines

## "Sigrun hits the Looter for 7 damage. The Looter counters, hitting Sigrun for
## 3 damage. ..." -- one sentence per strike, in the order they happened.
## Labels are as they read mid-sentence ("Sigrun", "the Looter").
func _describe_exchange(result: Dictionary, atk_label: String, def_label: String) -> String:
	var parts: Array[String] = []
	for s in result["strikes"]:
		var by_atk: bool = s["by"] == "atk"
		var subject: String = atk_label if by_atk else def_label
		var object: String = def_label if by_atk else atk_label
		subject = subject.substr(0, 1).to_upper() + subject.substr(1)
		var verb := "attacks" if by_atk else "counters"
		if not s["hit"]:
			parts.append("%s %s %s and misses." % [subject, verb, object])
		else:
			var crit := " CRITICAL HIT!" if s["crit"] else ""
			parts.append("%s %s %s for %d damage.%s" % [subject, "hits" if by_atk else "counters, hitting", object, s["damage"], crit])
	return " ".join(parts)

# ---------------------------------------------------------- forecast & targets

func _arts_of(unit: Dictionary) -> Array:
	if unit.has("arts"):
		return unit["arts"]
	var art = unit.get("weapon_art")   # prologue_roster rows have one art and no class
	return [art] if art != null and art != "" else []

## The weapon a player unit fights with: their class art's basic weapon, or a
## `weapon_id` on the unit (future equipment), but only if they are proficient
## in every art it requires. {} if they can't wield it.
func _weapon_for_unit(unit: Dictionary) -> Dictionary:
	var wid: String = unit.get("weapon_id", "")
	if wid == "" and _is_roster_unit(unit):
		# a main-roster unit fights with whatever their inventory has equipped
		var equipped := Equipment.equipped(unit.get("punit_id", ""))
		return weapons_by_id.get(equipped["weapon_id"], {}) if not equipped.is_empty() else {}
	var art = unit.get("weapon_art")   # null for the unarmed; prologue and test units use their art's basic weapon
	var weapon: Dictionary = {}
	if wid != "":
		weapon = weapons_by_id.get(wid, {})
	elif art != null and art != "":
		weapon = _weapon_for_art(art)
	if weapon.is_empty() or not Combat.can_wield(_arts_of(unit), weapon):
		return {}
	return weapon

## Copies a main unit's CURRENT stats, level and abilities (Progression) into
## its roster row, replacing the starting values from unit_base_stats. Also the
## way a level-up reaches the map. Returns the HP gained (for the live HP bar).
func _apply_progression(row: Dictionary, unit_id: String) -> int:
	Progression.ensure(unit_id)
	var old_hp := int(row.get("hp", 0))
	var stats := Progression.stats_for(unit_id)
	for s in Progression.STATS:
		row[s] = stats[s]
	row["level"] = Progression.level(unit_id)
	row["abilities"] = Progression.ability_effects(unit_id)
	return int(row["hp"]) - old_hp

## True for the 18 main units, whose weapons live in Equipment.
func _is_roster_unit(unit: Dictionary) -> bool:
	return Canon.find_by("units", "unit_id", unit.get("punit_id", "")) != null

## Uses left on the unit's equipped weapon; -1 (unlimited) for units whose
## weapon isn't tracked (prologue and test units, or a weapon_id override).
func _uses_of(unit: Dictionary) -> int:
	if unit.get("weapon_id", "") != "" or not _is_roster_unit(unit):
		return -1
	var equipped := Equipment.equipped(unit.get("punit_id", ""))
	return int(equipped["uses"]) if not equipped.is_empty() else -1

## Charges `strikes` uses to the unit's weapon; returns " X's Y breaks!" if that
## broke it, else "".
func _spend_uses(unit: Dictionary, strikes: int) -> String:
	if strikes <= 0 or unit.get("weapon_id", "") != "" or not _is_roster_unit(unit):
		return ""
	var broke := Equipment.spend_use(unit.get("punit_id", ""), strikes)
	if broke.is_empty():
		return ""
	var next := Equipment.equipped(unit.get("punit_id", ""))
	var tail := " They switch to the %s." % Equipment.weapon_name(next["weapon_id"]) if not next.is_empty() else " They have nothing left to fight with."
	return " %s's %s breaks!%s" % [unit.get("name"), broke["name"], tail]

## An enemy's weapon: its archetype's weapon_id when set (overlap weapons),
## else the weapon_art/weapon_tier pattern. Enemies are proficient by definition.
func _enemy_weapon(inst: Dictionary) -> Dictionary:
	var arch: Dictionary = inst.archetype
	var wid = arch.get("weapon_id")
	if wid == null or wid == "":
		wid = "wpn_%s_%s" % [arch.get("weapon_art", ""), arch.get("weapon_tier", "")]
	return weapons_by_id.get(wid, {})

func _distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

## A player unit's combat stats plus whatever its best nearby partner adds.
func _combatant_for_unit(pid: String) -> Dictionary:
	var row: Dictionary = {}
	for u in units:
		if u.get("punit_id", "") == pid:
			row = u
			break
	var c: Dictionary = row.duplicate()
	c["cur_hp"] = int(unit_hp.get(pid, 0))     # for the abilities' HP conditions
	c["max_hp"] = int(row.get("hp", 0))
	c.merge(Supports.combat_keys(Supports.best_partner(pid, unit_positions, chapter_route).get("effect", {})))
	return c

## Everything the forecast panel and an exchange need for `unit` attacking `inst`.
func _forecast_info(unit: Dictionary, inst: Dictionary) -> Dictionary:
	var pid: String = unit.get("punit_id", "")
	var weapon := _weapon_for_unit(unit)
	var def_weapon := _enemy_weapon(inst)
	var attacker := _combatant_for_unit(pid)
	var defender: Dictionary = inst.archetype.duplicate()
	var distance := _distance(unit_positions[pid], inst.pos)
	var support := Supports.best_partner(pid, unit_positions, chapter_route)
	return {
		"attacker": attacker, "defender": defender, "weapon": weapon, "def_weapon": def_weapon,
		"distance": distance, "support": support, "support_text": _support_line(support),
		"capture_text": _capture_text(pid, inst),
		"atk": {"name": unit.get("name"), "weapon": _weapon_label(weapon, _uses_of(unit)), "uses": _uses_of(unit),
			"level": unit.get("level", -1),
			"hp": int(unit_hp.get(pid, 0)), "max_hp": int(unit.get("hp", 0))},
		"def": {"name": inst.archetype.get("name"), "weapon": def_weapon.get("name", "none"), "hp": int(inst.hp), "max_hp": int(inst.max_hp),
			"level": int(inst.archetype.get("level", -1))},
		"forecast": Combat.forecast(attacker, defender, weapon, def_weapon, distance),
	}

## The forecast panel's Capture line for a unit that has the action: "" for one
## that doesn't, otherwise whether this enemy can be taken now, and why not.
func _capture_text(pid: String, inst: Dictionary) -> String:
	if not Progression.can_capture(pid):
		return ""
	var check := Progression.capture_check(int(inst.hp), int(inst.max_hp), inst.kind == "boss")
	if not check["ok"]:
		return "Capture: %s." % check["reason"]
	return "Capture ready: no kill, no drop, +%d gold ransom." % int(Progression.param("income_per_capture"))

## "Iron Sword (45)" while the weapon's uses are tracked, else just its name.
func _weapon_label(weapon: Dictionary, uses: int) -> String:
	var wname: String = weapon.get("name", "none")
	return "%s (%d)" % [wname, uses] if uses >= 0 and not weapon.is_empty() else wname

## Living enemies the weapon can reach from `pos`, nearest first (ties by id).
func _enemies_in_range(pos: Vector2i, weapon: Dictionary) -> Array:
	var range_min := int(weapon.get("range_min", 1))
	var range_max := int(weapon.get("range_max", 1))
	var found: Array = []
	for inst in enemies:
		if inst.defeated or inst.get("neutral", false):
			continue
		var d := _distance(pos, inst.pos)
		if d >= range_min and d <= range_max:
			found.append(inst)
	found.sort_custom(func(a, b):
		var da := _distance(pos, a.pos)
		var db := _distance(pos, b.pos)
		return da < db if da != db else str(a.inst_id) < str(b.inst_id)
	)
	return found

## The enemy an attack will hit: the one the forecast shows, else the nearest.
func _current_target(pos: Vector2i, weapon: Dictionary) -> Dictionary:
	var in_range := _enemies_in_range(pos, weapon)
	if in_range.is_empty():
		return {}
	if _target_idx < _targets.size() and in_range.has(_targets[_target_idx]):
		return _targets[_target_idx]
	return in_range[0]

func _update_forecast() -> void:
	if forecast_label == null:
		return
	forecast_label.visible = false
	if map_won or map_lost or units.is_empty():
		return
	var unit: Dictionary = units[selected_unit_index]
	var pid: String = unit.get("punit_id", "")
	if not unit_positions.has(pid) or attacked_this_turn.has(pid):
		return
	var weapon := _weapon_for_unit(unit)
	if weapon.is_empty():
		return
	var previous: Dictionary = _targets[_target_idx] if _target_idx < _targets.size() else {}
	_targets = _enemies_in_range(unit_positions[pid], weapon)
	if _targets.is_empty():
		return
	_target_idx = maxi(0, _targets.find(previous))
	forecast_label.text = ForecastView.bbcode(_forecast_info(unit, _targets[_target_idx]))
	forecast_label.visible = true

## [E]: a free action -- swap to the next weapon the selected unit can wield.
## Not once they have attacked this turn.
func _cycle_weapon() -> void:
	if units.is_empty():
		return
	var unit: Dictionary = units[selected_unit_index]
	var pid: String = unit.get("punit_id", "")
	if not _is_roster_unit(unit):
		return
	if attacked_this_turn.has(pid):
		info_label.text = "%s has already attacked this turn." % unit.get("name")
		return
	var now := Equipment.cycle(pid)
	if now.is_empty():
		info_label.text = "%s has no other weapon they can use." % unit.get("name")
		return
	info_label.text = "%s equips the %s." % [unit.get("name"), Equipment.describe(now)]
	_update_forecast()

func _cycle_target() -> void:
	if _targets.size() > 1:
		_target_idx = (_target_idx + 1) % _targets.size()
		_update_forecast()

## Clicking an enemy standing in range makes it the forecast target.
func _try_target_click(pos: Vector2i) -> bool:
	for i in _targets.size():
		if _targets[i].pos == pos:
			_target_idx = i
			_update_forecast()
			return true
	return false

## An enemy is defeated: off the map, and a boss falling ends a 'defend' map.
## Returns the name of the weapon it dropped into the convoy ("" if none).
func _defeat_enemy(inst: Dictionary) -> String:
	inst.defeated = true
	_remove_enemy_token(inst)
	var drop := Equipment.claim_drop(str(inst.get("spawn_id", "")), inst.get("drop"))
	_boss_resolved(inst, "falls")
	return drop

## A boss leaving the fight, however it ends (falls, yields), wins a 'defend' map.
func _boss_resolved(inst: Dictionary, how: String) -> void:
	if inst.kind == "boss" and map_row.get("objective_verb") == "defend" and not map_won:
		map_won = true
		status_label.text = "The %s %s. Threat neutralized." % [inst.archetype.get("name"), how]
		info_label.text = "Victory."

# ------------------------------------------------------------------ enemy phase
#
# After each played turn every living enemy acts once, in spawn order:
#   - a boss holds its tile (it guards something) and strikes only what is in
#     reach from where it stands;
#   - everyone else looks at every tile it can reach this turn and every player
#     unit it could hit from there, and takes the best trade (expected damage
#     dealt, plus a bonus for a kill, less half the expected counter damage --
#     so it prefers a matchup the triangle favours); if nothing is reachable
#     it walks toward the nearest unit.
# The attack is a full exchange: the unit counters if the enemy is inside its
# weapon range, and a side 4+ speed ahead follows up. Behaviours described in
# enemy_archetypes.behavior (fleeing, looting, converting) are not modelled.
# Units still don't block movement, but enemies never END a move on an
# occupied tile.

const KILL_BONUS := 1000.0
const COUNTER_WEIGHT := 0.5

func _enemy_phase() -> void:
	enemy_log.clear()
	_phase_targets.clear()
	if not enemy_phase_enabled:
		return
	var rng := rng_override
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	for inst in enemies:
		if inst.defeated or inst.get("neutral", false) or map_won or map_lost:
			continue
		_enemy_act(inst, rng)
		_check_defeat()
	enemy_log.append_array(_update_solo_holds())

## The live roster row for a player unit id ({} if none).
func defender_row_for(pid: String) -> Dictionary:
	for u in units:
		if u.get("punit_id", "") == pid:
			return u
	return {}

## Expected damage dealt minus the weighted expected damage taken, from a forecast.
func _exchange_score(fc: Dictionary, target_hp: int) -> float:
	var a: Dictionary = fc["atk"]
	var dealt: float = a["hit"] / 100.0 * a["damage"] * a["hits"]
	var taken := 0.0
	if not fc["def"].is_empty():
		var d: Dictionary = fc["def"]
		taken = d["hit"] / 100.0 * d["damage"] * d["hits"]
	var score := dealt - COUNTER_WEIGHT * taken
	if dealt >= target_hp:
		score += KILL_BONUS
	return score

func _enemy_act(inst: Dictionary, rng: RandomNumberGenerator) -> void:
	if not unit_positions.is_empty() and Progression.is_routing(inst.archetype, int(inst.hp), int(inst.max_hp), inst.kind == "boss"):
		_enemy_flee(inst)
		return
	var weapon := _enemy_weapon(inst)
	if weapon.is_empty() or unit_positions.is_empty():
		return
	var mtype: String = inst.archetype.get("movement_type", "infantry")
	var budget := 0 if inst.kind == "boss" else int(MOVEMENT_TYPE_DEFAULT_MOVE.get(mtype, 5))
	var reach := _compute_reachable(inst.pos, budget, mtype)
	var occupied := {}
	for pid in unit_positions:
		occupied[unit_positions[pid]] = true
	for other in enemies:
		if other != inst and not other.defeated:
			occupied[other.pos] = true
	var attacker: Dictionary = inst.archetype.duplicate()

	var best := {}
	var best_score := -INF
	for dest in reach:
		if dest != inst.pos and occupied.has(dest):
			continue
		for pid in unit_positions:
			var d := _distance(dest, unit_positions[pid])
			if d < int(weapon.get("range_min", 1)) or d > int(weapon.get("range_max", 1)):
				continue
			var defender := _combatant_for_unit(pid)
			var fc := Combat.forecast(attacker, defender, weapon, _weapon_for_unit(defender), d)
			var score := _exchange_score(fc, int(unit_hp.get(pid, 0))) - 0.01 * int(reach[dest])  # tie-break: shorter walk
			if score > best_score:
				best_score = score
				best = {"dest": dest, "pid": pid, "distance": d}

	if best.is_empty():
		if budget > 0:
			_enemy_advance(inst, reach, occupied)
		return
	_enemy_move(inst, best["dest"])

	var pid: String = best["pid"]
	var defender := _combatant_for_unit(pid)
	var def_weapon := _weapon_for_unit(defender)
	var result := Combat.resolve_exchange(attacker, defender, weapon, def_weapon, best["distance"],
		rng, inst.hp, int(unit_hp.get(pid, 0)), -1, _uses_of(defender))
	var inst_hp_before: int = inst.hp
	inst.hp = int(result["atk_hp"])
	unit_hp[pid] = int(result["def_hp"])
	_phase_targets[pid] = true
	var uname: String = defender.get("name", pid)
	var ename: String = inst.archetype.get("name", "enemy")
	enemy_log.append(_describe_exchange(result, "the %s" % ename, uname))
	# swap the result's sides: for the unit, "atk" strikes are the enemy's
	enemy_log.append_array(_note_exchange(pid, inst, {"strikes": result["strikes"], "enemy_attacked": true,
		"def_strikes": result["def_strikes"]}, inst_hp_before))
	var broke := _spend_uses(defender, int(result["def_strikes"]))
	if broke != "":
		enemy_log.append(broke.strip_edges())
	if int(unit_hp[pid]) == 0:
		_kill_unit(pid)
		enemy_log.append("%s falls." % uname)
	elif int(result["def_strikes"]) > 0:
		# the unit fought (countered): it earns EXP, though the log only shows level-ups
		enemy_log.append_array(_award_exp(defender_row_for(pid), inst, inst.hp == 0, rng, false))
	if inst.hp == 0:
		enemy_log.append("The %s falls." % ename)
		var drop := _defeat_enemy(inst)
		if drop != "":
			enemy_log.append("It drops a %s." % drop)

## A routed enemy (below its flee threshold) doesn't fight: it runs for the nearest edge
## it can reach, or failing that the tile farthest from every player unit. Reaching a
## map-edge tile takes it off the field for good (a dispersal, not a kill).
func _enemy_flee(inst: Dictionary) -> void:
	var mtype: String = inst.archetype.get("movement_type", "infantry")
	var reach := _compute_reachable(inst.pos, int(MOVEMENT_TYPE_DEFAULT_MOVE.get(mtype, 5)), mtype)
	var occupied := {}
	for pid in unit_positions:
		occupied[unit_positions[pid]] = true
	for other in enemies:
		if other != inst and not other.defeated:
			occupied[other.pos] = true
	var best: Vector2i = inst.pos
	var best_score := -INF
	for dest in reach:
		if dest != inst.pos and occupied.has(dest):
			continue
		var nearest := 999999
		for pid in unit_positions:
			nearest = mini(nearest, _distance(dest, unit_positions[pid]))
		var score := float(nearest) - 0.01 * float(reach[dest])
		if _on_map_edge(dest):
			score += 1000.0
		if score > best_score:
			best_score = score
			best = dest
	var ename: String = inst.archetype.get("name", "enemy")
	if _on_map_edge(best):
		_enemy_move(inst, best)
		enemy_log.append("The %s breaks and flees the field." % ename)
		enemy_log.append_array(_rout_off(inst))
	elif best != inst.pos:
		_enemy_move(inst, best)
		enemy_log.append("The %s breaks and runs." % ename)

func _on_map_edge(pos: Vector2i) -> bool:
	return pos.x == 0 or pos.y == 0 or pos.y == grid.size() - 1 or pos.x == grid[0].length() - 1

## An enemy leaves the field unharmed-and-unkilled. Whoever dealt the blow that broke it
## gets a step toward the dispersal deed. Returns the lines to show.
func _rout_off(inst: Dictionary) -> Array[String]:
	inst.defeated = true
	inst["routed"] = true
	_remove_enemy_token(inst)
	var lines: Array[String] = []
	var pid: String = str(inst.get("rout_blow", ""))
	if pid != "" and Progression.is_known_unit(pid) and map_id != "map_f00":
		var row = Canon.find_by("units", "unit_id", pid)
		var uname: String = str(row["name"]) if row != null else pid
		lines.append_array(_earn_deed(pid, "ep_dispersal", uname))
		if lines.is_empty():
			var need := Progression.count_needed("ep_dispersal")
			var got := Progression.deed_count(pid, "ep_dispersal")
			if got < need:
				lines.append("%s has routed %d of %d." % [uname, got, need])
	return lines

## No target within reach this turn: walk to the reachable free tile closest
## (by straight-line tiles) to the nearest player unit.
func _enemy_advance(inst: Dictionary, reach: Dictionary, occupied: Dictionary) -> void:
	var best_dest: Vector2i = inst.pos
	var best_d := 999999
	for dest in reach:
		if dest != inst.pos and occupied.has(dest):
			continue
		for pid in unit_positions:
			var d := _distance(dest, unit_positions[pid])
			if d < best_d or (d == best_d and reach[dest] < reach.get(best_dest, 0)):
				best_d = d
				best_dest = dest
	_enemy_move(inst, best_dest)

func _enemy_move(inst: Dictionary, dest: Vector2i) -> void:
	if dest == inst.pos:
		return
	inst.pos = dest
	if inst.token.has("container"):
		inst.token.container.position = Vector2(dest.x * CELL_SIZE, dest.y * CELL_SIZE)

## One fight's EXP for a main unit that fought `inst`: the lines to show (EXP
## gained, then one per level reached). Applies the level-ups to the roster row
## and raises current HP by any HP gained. Prologue and test units earn nothing.
func _award_exp(unit: Dictionary, inst: Dictionary, killed: bool, rng: RandomNumberGenerator, show_exp: bool = true) -> Array[String]:
	var lines: Array[String] = []
	var pid: String = unit.get("punit_id", "")
	if not _is_roster_unit(unit) or not unit_positions.has(pid):
		return lines
	var res := Progression.award_fight(pid, int(inst.archetype.get("level", 1)), killed, rng)
	if show_exp:
		lines.append("%s gains %d EXP." % [unit.get("name"), res["exp"]])
	for up in res["levelups"]:
		lines.append(Progression.describe_levelup(unit.get("name"), up))
	if not res["levelups"].is_empty():
		var hp_gain := _apply_progression(unit, pid)
		unit_hp[pid] = int(unit_hp.get(pid, 0)) + maxi(0, hp_gain)
	return lines

# ------------------------------------------------------------------------ deeds
#
# Three of canon's epithets gate the paragon tier and are recordable now
# (epithets.tracked): the boss kill, the solo hold and the no-hit map. A deed is
# kept for the whole playthrough, so none can be missed; the first time a unit
# earns one the map says so. Capture, miasma, delivery, dispersal and talk need
# mechanics that don't exist yet.

## Records one deed for a main unit and returns the announcement lines (empty if
## it wasn't new, or the unit isn't a main-roster unit).
func _earn_deed(pid: String, epithet_id: String, unit_name: String) -> Array[String]:
	var out: Array[String] = []
	if map_id == "map_f00" or not Progression.is_known_unit(pid):
		return out
	if Progression.record_deed(pid, epithet_id):
		var row := Progression.epithet_row(epithet_id)
		out.append("%s earns a deed: %s ('%s')." % [unit_name, str(row.get("deed_category", epithet_id)).replace("_", " "), row.get("forge_vocab_token", "")])
	return out

## Bookkeeping after an exchange between player unit `pid` and enemy `inst`.
## Works on both player attacks (result as returned by resolve_exchange) and
## enemy attacks (flagged enemy_attacked, where "atk" strikes are the enemy's).
## Tracks who has been struck / has struck, remembers which units damaged the
## enemy, and awards the boss-kill deed for a lone killer. Returns announcements.
func _note_exchange(pid: String, inst: Dictionary, result: Dictionary, enemy_hp_before: int) -> Array[String]:
	var enemy_side := "atk" if result.get("enemy_attacked", false) else "def"
	var unit_side := "def" if enemy_side == "atk" else "atk"
	for s in result["strikes"]:
		if s["by"] == enemy_side and s["hit"] and int(s["damage"]) > 0:
			struck_units[pid] = true
	if int(result.get("%s_strikes" % unit_side, 0)) > 0:
		fought_units[pid] = true
	if not inst.has("hit_by"):
		inst["hit_by"] = {}
	var lines: Array[String] = []
	_note_damage(inst, pid, enemy_hp_before)
	if int(inst.hp) == 0 and inst.kind == "boss" and inst["hit_by"].size() == 1 and inst["hit_by"].has(pid):
		var uname: String = str(Canon.find_by("units", "unit_id", pid)["name"]) if Canon.find_by("units", "unit_id", pid) != null else pid
		lines.append_array(_earn_deed(pid, "ep_bosskill", uname))
	return lines

## `pid` took `inst` from `hp_before` down to its current HP: it counts as having damaged
## the enemy, and if that blow is what took a flee-prone enemy (a levy) below its flee
## threshold, `pid` is the one who routed it -- the credit for the dispersal deed if it
## then runs from the field instead of being finished off.
func _note_damage(inst: Dictionary, pid: String, hp_before: int) -> void:
	if int(inst.hp) >= hp_before:
		return
	if not inst.has("hit_by"):
		inst["hit_by"] = {}
	inst["hit_by"][pid] = true
	var boss: bool = inst.kind == "boss"
	if not inst.has("rout_blow") and Progression.is_routing(inst.archetype, int(inst.hp), int(inst.max_hp), boss) \
			and not Progression.is_routing(inst.archetype, hp_before, int(inst.max_hp), boss):
		inst["rout_blow"] = pid

## At the end of an enemy phase: a unit that stood on the same tile, was attacked
## this phase, and has no other player unit within solo_hold_radius extends its
## run; anything else resets it. solo_hold_phases in a row earns the deed.
func _update_solo_holds() -> Array[String]:
	var lines: Array[String] = []
	var need := int(Progression.param("solo_hold_phases"))
	var radius := int(Progression.param("solo_hold_radius"))
	for pid in unit_positions.keys():
		var pos: Vector2i = unit_positions[pid]
		var alone := true
		for other in unit_positions:
			if other != pid and _distance(pos, unit_positions[other]) <= radius:
				alone = false
		if not (alone and _phase_targets.has(pid)):
			hold_streak.erase(pid)
			continue
		var run: Dictionary = hold_streak.get(pid, {})
		if run.get("tile", Vector2i(-1, -1)) == pos:
			run["phases"] = int(run["phases"]) + 1
		else:
			run = {"tile": pos, "phases": 1}
		hold_streak[pid] = run
		if int(run["phases"]) >= need:
			var row = Canon.find_by("units", "unit_id", pid)
			lines.append_array(_earn_deed(pid, "ep_solohold", str(row["name"]) if row != null else pid))
	return lines

## On a win: every surviving unit that fought and was never hit earns the
## no-hit-map deed. Returns the announcement lines.
func _no_hit_deeds() -> Array[String]:
	var lines: Array[String] = []
	for pid in unit_positions.keys():
		if fought_units.has(pid) and not struck_units.has(pid):
			var row = Canon.find_by("units", "unit_id", pid)
			lines.append_array(_earn_deed(pid, "ep_nohit", str(row["name"]) if row != null else pid))
	return lines

# ----------------------------------------------------------- miasma and cargo
#
# Two more deeds. Miasma ("ends turn on miasma tiles 5+ times"): each main unit that
# ends the player turn standing on the terrain epithets.deed_terrain names counts one
# (before the hazard damage lands), and the deed is earned at count_needed. Delivery
# ("escorts a cargo unit to its goal"): see _deliver.

## At the end of the player turn: one more miasma turn for every main unit standing on
## miasma. Returns the lines to show (the deed, or how far along the unit is).
func _miasma_deeds() -> Array[String]:
	var lines: Array[String] = []
	var terrain_id := Progression.deed_terrain("ep_miasma")
	if terrain_id == "" or map_id == "map_f00":
		return lines
	for pid in unit_positions.keys():
		if not Progression.is_known_unit(pid):
			continue
		var terrain = terrain_by_symbol.get(_effective_symbol(unit_positions[pid]))
		if terrain == null or terrain.get("terrain_id") != terrain_id:
			continue
		var row = Canon.find_by("units", "unit_id", pid)
		var uname: String = str(row["name"]) if row != null else pid
		var earned := _earn_deed(pid, "ep_miasma", uname)
		if not earned.is_empty():
			lines.append_array(earned)
		else:
			var need := Progression.count_needed("ep_miasma")
			var got := Progression.deed_count(pid, "ep_miasma")
			if got < need:
				lines.append("%s has ended %d of %d turns in the miasma." % [uname, got, need])
	return lines

func _cargo_needed() -> int:
	var n = map_row.get("cargo_needed")
	return int(n) if n != null else 0

func _is_cargo(pid: String) -> bool:
	for u in units:
		if u.get("punit_id", "") == pid:
			return bool(u.get("cargo", false))
	return false

## Cargo units still on the map.
func _cargo_remaining() -> int:
	var n := 0
	for pid in unit_positions:
		if _is_cargo(pid):
			n += 1
	return n

## [W]: select the next cargo unit still on the map (the number keys only reach the first nine units).
func _select_next_cargo() -> void:
	var n := units.size()
	for step in range(1, n + 1):
		var idx := (selected_unit_index + step) % n
		var pid: String = units[idx].get("punit_id", "")
		if _is_cargo(pid) and unit_positions.has(pid):
			_select_unit(idx)
			return
	info_label.text = "There is no cargo left on the map."

## A cargo unit reaches the goal: it leaves the map and counts as delivered. Every main unit
## that is alive and within delivery_radius of the goal at that moment has ESCORTED it and
## earns the delivery deed. Enough deliveries (maps.cargo_needed) win the map.
func _deliver(pid: String) -> void:
	var cargo_name := "The cargo"
	for u in units:
		if u.get("punit_id", "") == pid:
			cargo_name = str(u.get("name"))
	var token = unit_tokens.get(pid)
	if token:
		token.container.queue_free()
	unit_tokens.erase(pid)
	unit_positions.erase(pid)
	delivered.append(pid)
	var lines: Array[String] = ["%s is delivered (%d of %d)." % [cargo_name, delivered.size(), _cargo_needed()]]
	var radius := int(Progression.param("delivery_radius"))
	for other in unit_positions.keys():
		if _is_cargo(other) or not Progression.is_known_unit(other) or _distance(unit_positions[other], escape_pos) > radius:
			continue
		var row = Canon.find_by("units", "unit_id", other)
		lines.append_array(_earn_deed(other, "ep_delivery", str(row["name"]) if row != null else other))
	if delivered.size() >= _cargo_needed() and not map_won:
		map_won = true
		status_label.text = "DELIVERED. %d of %d reached the goal." % [delivered.size(), _cargo_needed()]
		info_label.text = "Victory. " + " ".join(lines)
		return
	info_label.text = " ".join(lines)
	_update_status_label()

## Cargo lost: if the cargo still on the map plus what was delivered can no longer reach
## cargo_needed, the map is lost.
func _check_cargo_lost() -> void:
	if _cargo_needed() <= 0 or map_won or map_lost or units.is_empty():
		return
	if delivered.size() + _cargo_remaining() < _cargo_needed():
		map_lost = true
		status_label.text = "DEFEAT. Too much of the cargo is lost."
		info_label.text = "Defeat. Press Escape to leave."
		_update_forecast()

## A player unit leaves play (dead): token, position and all.
func _kill_unit(pid: String) -> void:
	var token = unit_tokens.get(pid)
	if token:
		token.container.queue_free()
	unit_tokens.erase(pid)
	unit_positions.erase(pid)
	_check_cargo_lost()

## With every player unit gone no win is possible. Units that escaped no
## longer count as on the map, so this also ends a map where too few escaped.
func _check_defeat() -> void:
	if map_won or map_lost or units.is_empty() or not unit_positions.is_empty():
		return
	map_lost = true
	status_label.text = "DEFEAT. No units are left on the map."
	info_label.text = "Defeat. Press Escape to leave."
	_update_forecast()

## " (Support with Maren, rank B: +5 hit/avoid, +1 crit/dodge)" when a partner's
## support applied to this attack, else "".
## "Support with Maren, rank B: +5 hit/avoid, +1 crit/dodge" for the forecast panel.
func _support_line(support: Dictionary) -> String:
	return _support_note(support).strip_edges().trim_prefix("(").trim_suffix(")")

func _support_note(support: Dictionary) -> String:
	if support.is_empty() or Supports.effect_text(support["effect"]) == "":
		return ""
	var row = Canon.find_by("units", "unit_id", support["partner"])
	var partner_name: String = row["name"] if row != null else support["partner"]
	return " (Support with %s, rank %s: %s)" % [partner_name, support["rank"], Supports.effect_text(support["effect"])]

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
	var neutral := 0
	for inst in enemies:
		if not inst.defeated:
			if inst.get("neutral", false):
				neutral += 1
			else:
				alive += 1
	header += " -- Enemies alive: %d%s -- attackers: %d/%d this turn -- moved: %d/%d this turn" % [
		alive, " (+%d neutral)" % neutral if neutral > 0 else "", attacked_this_turn.size(), MAX_STATUE_ATTACKERS_PER_TURN, moved_this_turn.size(), units.size()
	]
	if _cargo_needed() > 0:
		header += " -- Cargo: %d/%d delivered" % [delivered.size(), _cargo_needed()]
	lines.append(header)
	var controls := "[F] attack -- [Tab] retarget -- [E] weapon -- [N] / Enter: next turn -- click a tile to move"
	for u in units:
		if _is_roster_unit(u) and Progression.can_capture(u.get("punit_id", "")):
			controls = controls.replace("[Tab] retarget", "[C] capture -- [Tab] retarget")
			break
	var push_names: Array[String] = []
	for u in units:
		var push := Progression.push_name(u.get("punit_id", "")) if _is_roster_unit(u) else ""
		if push != "" and not push_names.has(push):
			push_names.append(push)
	if map_id != "map_f00":
		controls = controls.replace("[E] weapon", "[T] talk -- [E] weapon")
	if _cargo_needed() > 0:
		controls = controls.replace("[E] weapon", "[W] cargo -- [E] weapon")
	for u in units:
		if _is_roster_unit(u) and Progression.can_bribe(u.get("punit_id", "")):
			controls = controls.replace("[E] weapon", "[B] bribe -- [E] weapon")
			break
	if not push_names.is_empty():
		controls = controls.replace("[E] weapon", "[S] " + "/".join(push_names).to_lower() + " -- [E] weapon")
	if map_id == "map_f00":
		controls = "[A] attack statue -- " + controls
	lines.append(controls)
	status_label.text = "\n".join(lines)

func _update_info_label(reachable_count := -1) -> void:
	if map_won or map_lost:
		return
	if units.is_empty():
		info_label.text = "No units loaded."
		return
	var unit: Dictionary = units[selected_unit_index]
	var pid: String = unit.get("punit_id", "")
	var lines: Array[String] = []
	lines.append("[1-9] select unit -- click a highlighted tile to move there")
	var weapon_text := _weapon_label(_weapon_for_unit(unit), _uses_of(unit)) if not _weapon_for_unit(unit).is_empty() else "no weapon"
	lines.append("Selected: %s%s -- move %s, %s, weapon %s ([E] switch), hp %s" % [
		unit.get("name"), " (Lv %d)" % int(unit["level"]) if unit.has("level") and _is_roster_unit(unit) else "",
		unit.get("move"), unit.get("movement_type"),
		weapon_text, unit_hp.get(pid, unit.get("hp"))
	])
	if moved_this_turn.has(pid):
		lines.append("At (%d, %d) -- already moved this turn." % [origin.x, origin.y])
	elif origin != Vector2i(-1, -1):
		lines.append("At (%d, %d) -- %d tiles reachable" % [origin.x, origin.y, reachable_count])
	if not enemy_log.is_empty():
		lines.append("Enemy phase: " + " ".join(enemy_log.slice(maxi(0, enemy_log.size() - MAX_ENEMY_LOG_SHOWN))))
	info_label.text = "\n".join(lines)
