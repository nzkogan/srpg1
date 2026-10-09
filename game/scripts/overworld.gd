extends Node2D
## The overworld: a map of the world you walk across, Super-Mario-World style.
## Locations (canon's `locations`, placed at map_x / map_y) are nodes, `world_paths`
## are the roads between them, and the party is a marker that walks the shortest
## chain of paths to wherever you click. Nothing is free movement: you move along
## the paths. Each chapter sits at a location (chapters.location_id) and opens when
## one of the chapters in its `unlock_after` has been won (blank = open from the
## start), so the map fills in as you play: blue = something to play here, green =
## everything here is won, grey = locked. Enter (or clicking the place you are
## standing) plays the next open chapter there, or replays one if all are won.
##
## The prologue (Ur-Nashet) is a memory, not a place: it has no path, so it sits in
## the corner and the party reaches it, and leaves it, by memory (no walk).
##
## ch_h32 "The Kaisareia Trial" has no map_id at all (see chapters' own note) -- it's
## keyed by chapter_id in SPECIAL_SCENES, pointing at trial.tscn, a non-battle choice
## screen that sets GameState's flag_hierophant_verdict. ch_h33_mercy and
## ch_h34_war1/2/3 are gated on that flag: locked until the trial sets it, then only
## the matching branch opens -- the other stays locked for that playthrough, same as
## canon_flags.flag_hierophant_verdict's own "affects" column describes.
##
## Where the party stands is saved (GameState.world_location). Which map_id has a
## .tscn is the one thing canon.xlsx can't know, so AVAILABLE_SCENES below is hardcoded.
##
## Controls: click a location to walk there (click it again, or Enter, to play it).
## Press S to open the support conversation viewer (support_viewer.gd); Escape there
## returns here. C = convoy (convoy_screen.gd). B = barracks (barracks_screen.gd). L =
## save, load or new game (save_screen.gd). U = free roam: ignore the locks (a
## testing aid, not saved). Escape inside any map returns here (see map_grid.gd).
##
## F opens the forge where a master smith works (see forge.gd).
##
## A battle suspended with P (or quick-saved with F5) waits here: the party stands at its
## place, the panel says so, and Enter resumes it exactly where it stopped. X (pressed twice)
## abandons it. While one is waiting, no other chapter can be started.

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
	"map_ct19": "res://scenes/map_ct19.tscn",
	"map_tp19": "res://scenes/map_tp19.tscn",
	"map_rf20": "res://scenes/map_rf20.tscn",
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

## The map area is a 1152x540 canvas (canon.xlsx's map_x / map_y); the text panel sits beneath it.
const WORLD_W := 1152.0
const WORLD_H := 540.0
const PANEL_Y := 548.0
const NODE_SIZE := 22.0
const WALK_SPEED := 420.0
const FLASHBACK_LOCATION := "loc_ur_nashet"
const START_LOCATION := "loc_tally_house"   # where the avatar starts as a clerk, once the memory is over

const AVAILABLE_COLOR := Color(0.30, 0.55, 0.85, 0.95)
const WON_COLOR := Color(0.30, 0.68, 0.40, 0.95)
const LOCKED_COLOR := Color(0.35, 0.35, 0.38, 0.95)
const PARTY_COLOR := Color(0.98, 0.82, 0.25, 1.0)
const ROUTE_COLORS := {
	"diadem": Color(0.88, 0.50, 0.38, 0.9),
	"assembly": Color(0.45, 0.65, 0.95, 0.9),
	"both": Color(0.78, 0.78, 0.82, 0.8),
}
const REGION_COLORS := {
	"rgn_center": Color(0.62, 0.55, 0.35, 0.16),
	"rgn_drowned_march": Color(0.30, 0.48, 0.65, 0.16),
	"rgn_ashland": Color(0.65, 0.32, 0.25, 0.16),
	"rgn_glass_flats": Color(0.60, 0.65, 0.70, 0.16),
	"rgn_stepped_coast": Color(0.35, 0.60, 0.42, 0.16),
	"rgn_the_throat": Color(0.70, 0.58, 0.28, 0.16),
}
const MAX_PANEL_CHAPTERS := 5

## Emitted when a chapter is about to start (just before its scene loads).
signal chapter_launched(chapter_id: String)

## Test seam: false makes travel instant instead of a walk.
var animate := true
## Test seam: false makes Enter announce the chapter (chapter_launched) without loading its scene.
var launch_enabled := true
## Free roam: every chapter counts as unlocked (the U key; not saved).
var free_roam := false

var locations: Dictionary = {}   # location_id -> {row, pos, chapters: Array (in play order)}
var edges: Array = []            # {a, b, route, kind, points: Array[Vector2] a -> b, length}
var party_location := ""
var selected_location := ""
var info_label: Label
var _node_rects: Dictionary = {} # location_id -> ColorRect
var _marker: Node2D
var _walk: Array = []            # points left to walk (Vector2), empty when standing
var _walk_dest := ""
var _regions_by_id: Dictionary = {}
var _abandon_armed := false

func _ready() -> void:
	var maps_by_id: Dictionary = {}
	for m in Canon.get_table("maps"):
		maps_by_id[m["map_id"]] = m
	for r in Canon.get_table("regions"):
		_regions_by_id[r["region_id"]] = r
	for l in Canon.get_table("locations"):
		locations[l["location_id"]] = {"row": l, "pos": Vector2(float(l.get("map_x", 0)), float(l.get("map_y", 0))), "chapters": []}
	for ch in Canon.get_table("chapters"):
		var lid = ch.get("location_id")
		if lid != null and locations.has(lid):
			var map_id: String = ch.get("map_id") if ch.get("map_id") != null else ""
			locations[lid]["chapters"].append({"chapter": ch, "map_row": maps_by_id.get(map_id, {})})
	for lid in locations:
		locations[lid]["chapters"].sort_custom(func(x, y):
			var ax: int = ACT_RANK.get(str(x.chapter.get("act")), 5)
			var ay: int = ACT_RANK.get(str(y.chapter.get("act")), 5)
			if ax != ay:
				return ax < ay
			return int(x.chapter.get("number", 0)) < int(y.chapter.get("number", 0)))
	for e in Canon.get_table("world_paths"):
		_add_edge(e)

	_draw_regions()
	_draw_flashback_frame()
	_draw_edges()
	_draw_nodes()
	_draw_marker()

	party_location = _initial_location()
	selected_location = party_location
	_marker.position = locations[party_location]["pos"]

	info_label = Label.new()
	info_label.position = Vector2(14, PANEL_Y)
	info_label.custom_minimum_size = Vector2(WORLD_W - 28, 96)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	info_label.add_theme_font_size_override("font_size", 12)
	add_child(info_label)
	_show_location(party_location, true)

func _add_edge(e: Dictionary) -> void:
	var a: String = e["from_location_id"]
	var b: String = e["to_location_id"]
	if not locations.has(a) or not locations.has(b):
		return
	var pts: Array = [locations[a]["pos"]]
	for part in str(e.get("waypoints") if e.get("waypoints") != null else "").split(";", false):
		var xy := part.split(",")
		if xy.size() == 2:
			pts.append(Vector2(float(xy[0]), float(xy[1])))
	pts.append(locations[b]["pos"])
	var length := 0.0
	for i in range(pts.size() - 1):
		length += (pts[i] as Vector2).distance_to(pts[i + 1])
	edges.append({"a": a, "b": b, "route": str(e.get("route", "both")), "kind": str(e.get("kind", "road")), "points": pts, "length": length})

## Where the party starts: in the memory until the prologue is won, then at the tally house;
## afterwards wherever it last stood (GameState.world_location).
func _initial_location() -> String:
	var held := suspended_location()
	if held != "":
		return held
	var saved: String = GameState.world_location
	if saved != "" and locations.has(saved):
		return saved
	if not GameState.won_maps.has("map_f00") and locations.has(FLASHBACK_LOCATION):
		return FLASHBACK_LOCATION
	return START_LOCATION if locations.has(START_LOCATION) else locations.keys()[0]

# ------------------------------------------------------------------ unlocks

## What a chapter is right now: {"status": "won" | "open" | "noscene" | "locked", "reason": String}.
##   won      its map has been won (the Trial: its verdict has been given)
##   open     unlocked and playable
##   noscene  unlocked, but no scene is built for its map yet
##   locked   not unlocked yet, or ruled out by the Hierophant's verdict ("reason" says which)
func chapter_state(entry: Dictionary) -> Dictionary:
	var ch: Dictionary = entry["chapter"]
	var chapter_id: String = ch.get("chapter_id", "")
	var map_id: String = ch.get("map_id") if ch.get("map_id") != null else ""
	if _is_won(ch):
		return {"status": "won", "reason": ""}
	if HIEROPHANT_GATED.has(chapter_id):
		var needed: String = HIEROPHANT_GATED[chapter_id]
		var verdict = GameState.get_flag(HIEROPHANT_FLAG)
		if verdict == null:
			return {"status": "locked", "reason": "needs a sentence recommended at The Kaisareia Trial first"}
		if verdict != needed:
			return {"status": "locked", "reason": "this run's verdict was '%s', not '%s' -- shut for good this run" % [verdict, needed]}
	if not free_roam:
		var need: Array[String] = _unlock_list(ch)
		if not need.is_empty():
			var any_won := false
			for req in need:
				var rc = Canon.find_by("chapters", "chapter_id", req)
				if rc != null and _is_won(rc):
					any_won = true
			if not any_won:
				var names: Array[String] = []
				for req in need:
					var rc2 = Canon.find_by("chapters", "chapter_id", req)
					names.append(str(rc2.get("title")) if rc2 != null else req)
				return {"status": "locked", "reason": "opens after %s" % " or ".join(names)}
	if SPECIAL_SCENES.has(chapter_id) or AVAILABLE_SCENES.has(map_id):
		return {"status": "open", "reason": ""}
	return {"status": "noscene", "reason": "no scene is built for %s yet" % (map_id if map_id != "" else chapter_id)}

func _unlock_list(ch: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var raw = ch.get("unlock_after")
	if raw != null:
		for part in str(raw).split("|", false):
			out.append(part.strip_edges())
	return out

func _is_won(ch: Dictionary) -> bool:
	var map_id = ch.get("map_id")
	if map_id == null:
		return ch.get("chapter_id", "") == "ch_h32" and GameState.get_flag(HIEROPHANT_FLAG) != null
	return GameState.won_maps.has(map_id)

## F: the master smith's forge, if one works where the party stands.
func open_forge() -> bool:
	if is_walking():
		return false
	if Forge.forges_at(party_location).is_empty():
		_show_location(party_location, true, "No master smith works here.")
		return false
	GameState.world_location = party_location
	if launch_enabled:
		get_tree().change_scene_to_file(Forge.SCREEN_SCENE)
	return true

## The map of a suspended battle ("" if none).
func suspended_map() -> String:
	return str(GameState.battle.get("map_id", ""))

## Where a suspended battle waits ("" if none, or its place isn't on this map).
func suspended_location() -> String:
	var lid := str(GameState.battle.get("location_id", ""))
	return lid if lid != "" and locations.has(lid) else ""

## Throws a suspended battle away. Returns false if there was none.
func abandon_suspended() -> bool:
	if GameState.battle.is_empty():
		return false
	GameState.battle = {}
	_abandon_armed = false
	_show_location(selected_location if selected_location != "" else party_location, not is_walking(), "The suspended battle is abandoned.")
	return true

## The chapter Enter would play at a location: the first open one in story order ({} if none).
func next_chapter(location_id: String) -> Dictionary:
	for entry in locations[location_id]["chapters"]:
		if chapter_state(entry)["status"] == "open":
			return entry
	return {}

## "won" if every chapter there is won, "open" if any can be played, else "locked".
func location_status(location_id: String) -> String:
	var all_won := true
	var any_open := false
	for entry in locations[location_id]["chapters"]:
		var st: String = chapter_state(entry)["status"]
		if st != "won":
			all_won = false
		if st == "open":
			any_open = true
	if any_open:
		return "open"
	if all_won and not locations[location_id]["chapters"].is_empty():
		return "won"
	return "locked"

# ------------------------------------------------------------------- paths

## The chain of locations from `from` to `to` along the paths, shortest by road length
## (both ends included); [] if no chain joins them (the flashback has none).
func path_between(from: String, to: String) -> Array[String]:
	var out: Array[String] = []
	if from == to:
		out.append(from)
		return out
	var dist := {from: 0.0}
	var prev := {}
	var todo: Array[String] = [from]
	var done := {}
	while not todo.is_empty():
		todo.sort_custom(func(x, y): return dist[x] < dist[y])
		var cur: String = todo.pop_front()
		if done.has(cur):
			continue
		done[cur] = true
		if cur == to:
			break
		for e in edges:
			var other := ""
			if e["a"] == cur:
				other = e["b"]
			elif e["b"] == cur:
				other = e["a"]
			if other == "" or done.has(other):
				continue
			var nd: float = dist[cur] + float(e["length"])
			if not dist.has(other) or nd < dist[other]:
				dist[other] = nd
				prev[other] = cur
				todo.append(other)
	if not prev.has(to):
		return out
	var cur2 := to
	out.append(cur2)
	while prev.has(cur2):
		cur2 = prev[cur2]
		out.push_front(cur2)
	return out

## The points a walk along the chain follows (waypoints included, in walking order).
func walk_points(chain: Array) -> Array:
	var pts: Array = []
	for i in range(chain.size() - 1):
		for e in edges:
			if e["a"] == chain[i] and e["b"] == chain[i + 1]:
				pts.append_array(e["points"] if pts.is_empty() else e["points"].slice(1))
				break
			if e["b"] == chain[i] and e["a"] == chain[i + 1]:
				var rev: Array = e["points"].duplicate()
				rev.reverse()
				pts.append_array(rev if pts.is_empty() else rev.slice(1))
				break
	return pts

## Moves the party to `location_id`: it walks the shortest chain of paths (instantly if
## `animate` is false or no path joins the two -- the memory is reached by memory).
## Returns false if the party is already walking.
func travel_to(location_id: String) -> bool:
	if not locations.has(location_id) or not _walk.is_empty():
		return false
	selected_location = location_id
	if location_id == party_location:
		_show_location(location_id, true)
		return true
	var chain := path_between(party_location, location_id)
	if not animate or chain.is_empty():
		_arrive(location_id)
		return true
	_walk = walk_points(chain)
	_walk_dest = location_id
	_show_location(location_id, false, "Walking to %s..." % locations[location_id]["row"].get("name"))
	return true

func _process(delta: float) -> void:
	if _walk.is_empty():
		return
	var budget := WALK_SPEED * delta
	while budget > 0.0 and not _walk.is_empty():
		var target: Vector2 = _walk[0]
		var d := _marker.position.distance_to(target)
		if d <= budget:
			_marker.position = target
			budget -= d
			_walk.pop_front()
		else:
			_marker.position += (target - _marker.position).normalized() * budget
			budget = 0.0
	if _walk.is_empty():
		_arrive(_walk_dest)

func _arrive(location_id: String) -> void:
	_walk.clear()
	party_location = location_id
	selected_location = location_id
	GameState.world_location = location_id
	_marker.position = locations[location_id]["pos"]
	_show_location(location_id, true)

func is_walking() -> bool:
	return not _walk.is_empty()

# ------------------------------------------------------------------ drawing

func _draw_regions() -> void:
	var members: Dictionary = {}
	for lid in locations:
		var rid = locations[lid]["row"].get("region_id")
		if rid != null:
			if not members.has(rid):
				members[rid] = []
			members[rid].append(locations[lid]["pos"])
	for rid in members:
		var pts: Array = members[rid]
		var lo := pts[0] as Vector2
		var hi := pts[0] as Vector2
		for p in pts:
			lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
			hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
		var centre := (lo + hi) * 0.5
		var radii := (hi - lo) * 0.5 * 1.3 + Vector2(46, 38)
		var poly := Polygon2D.new()
		var ring := PackedVector2Array()
		for i in 40:
			ring.append(centre + Vector2(cos(TAU * i / 40.0) * radii.x, sin(TAU * i / 40.0) * radii.y))
		poly.polygon = ring
		poly.color = REGION_COLORS.get(rid, Color(0.5, 0.5, 0.5, 0.12))
		add_child(poly)
		var label := Label.new()
		label.text = str(_regions_by_id.get(rid, {}).get("name", rid))
		label.position = Vector2(centre.x - radii.x * 0.4, maxf(4.0, centre.y - radii.y * 0.92))
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", Color(1, 1, 1, 0.38))
		add_child(label)

func _draw_flashback_frame() -> void:
	if not locations.has(FLASHBACK_LOCATION):
		return
	var p: Vector2 = locations[FLASHBACK_LOCATION]["pos"]
	var frame := ColorRect.new()
	frame.size = Vector2(120, 78)
	frame.position = p - Vector2(60, 28)
	frame.color = Color(0.45, 0.4, 0.6, 0.18)
	add_child(frame)
	var label := Label.new()
	label.text = "a memory"
	label.position = p + Vector2(-60, 28)
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	add_child(label)

func _draw_edges() -> void:
	for e in edges:
		var line := Line2D.new()
		for p in e["points"]:
			line.add_point(p)
		line.width = 4.0 if e["kind"] == "road" else 2.0
		line.default_color = ROUTE_COLORS.get(e["route"], ROUTE_COLORS["both"])
		if e["kind"] != "road":
			line.default_color.a *= 0.7
		add_child(line)

func _draw_nodes() -> void:
	for lid in locations:
		var rect := ColorRect.new()
		rect.size = Vector2(NODE_SIZE, NODE_SIZE)
		rect.position = locations[lid]["pos"] - rect.size * 0.5
		add_child(rect)
		_node_rects[lid] = rect
		var label := Label.new()
		var nm := str(locations[lid]["row"].get("name", lid))
		label.text = nm.get_slice(",", 0).get_slice(" (", 0) if lid != FLASHBACK_LOCATION else "Ur-Nashet"
		label.position = locations[lid]["pos"] + Vector2(-52, NODE_SIZE * 0.5 + 1)
		label.custom_minimum_size = Vector2(104, 14)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 9)
		add_child(label)
	_recolor_nodes()

func _recolor_nodes() -> void:
	for lid in _node_rects:
		match location_status(lid):
			"won": _node_rects[lid].color = WON_COLOR
			"open": _node_rects[lid].color = AVAILABLE_COLOR
			_: _node_rects[lid].color = LOCKED_COLOR

func _draw_marker() -> void:
	_marker = Node2D.new()
	var diamond := Polygon2D.new()
	diamond.polygon = PackedVector2Array([Vector2(0, -15), Vector2(11, 0), Vector2(0, 15), Vector2(-11, 0)])
	diamond.color = PARTY_COLOR
	_marker.add_child(diamond)
	var outline := Line2D.new()
	outline.points = PackedVector2Array([Vector2(0, -15), Vector2(11, 0), Vector2(0, 15), Vector2(-11, 0), Vector2(0, -15)])
	outline.width = 2.0
	outline.default_color = Color(0.1, 0.1, 0.1, 1.0)
	_marker.add_child(outline)
	add_child(_marker)

# --------------------------------------------------------------------- text

## "night docks, neutral porters; where the avatar starts as a clerk" -> its first clause.
func _blurb(row: Dictionary) -> String:
	var text := str(row.get("what_the_ground_is_for", ""))
	var cut := text.find(";")
	if cut > 0:
		text = text.substr(0, cut)
	return text if text.length() <= 110 else text.substr(0, 107) + "..."

## The panel: where this is, what is here (each chapter and what state it is in), what
## Enter does, and the standing hints. `here` is false while the party is still walking.
func _show_location(location_id: String, here: bool, extra: String = "") -> void:
	_recolor_nodes()
	if info_label == null:
		return
	var loc: Dictionary = locations[location_id]
	var lines: Array[String] = []
	var row: Dictionary = loc["row"]
	var region_name := str(_regions_by_id.get(row.get("region_id"), {}).get("name", ""))
	lines.append("%s%s -- %s" % [row.get("name", location_id), " (%s)" % region_name if region_name != "" else "", _blurb(row)])
	if extra != "":
		lines.append(extra)
	var shown := 0
	for entry in loc["chapters"]:
		if shown >= MAX_PANEL_CHAPTERS:
			break
		var st := chapter_state(entry)
		var tag := ""
		match st["status"]:
			"won": tag = "won"
			"open": tag = "ready"
			"noscene": tag = st["reason"]
			_: tag = "locked: %s" % st["reason"]
		lines.append("  %s -- %s" % [entry.chapter.get("title", "?"), tag])
		shown += 1
	if suspended_map() != "":
		var bt := str(GameState.battle.get("title", suspended_map()))
		lines.append("SUSPENDED: %s, turn %d. %s" % [bt, int(GameState.battle.get("turn", 0)),
			"Enter resumes it." if location_id == suspended_location() else "It waits at %s; no other chapter can start until it is resumed or abandoned (X twice)." % locations[suspended_location()]["row"].get("name", "another place") if suspended_location() != "" else "X twice abandons it."])
	elif here:
		var nxt := next_chapter(location_id)
		if not nxt.is_empty():
			lines.append("Enter plays %s." % nxt.chapter.get("title"))
		elif location_status(location_id) == "won":
			lines.append("Everything here is won. Enter replays it.")
	if Deputy.decided():
		lines.append("The crown's deputy: %s%s." % [Deputy._unit_name(Deputy.deputy()), " (contested: Column B's supply is withheld)" if Deputy.contested() else ""])
	var smiths := Forge.forges_at(location_id)
	if not smiths.is_empty():
		var names: Array[String] = []
		for f in smiths:
			names.append(str(f["name"]))
		lines.append("A master smith works here: %s. Press F." % ", ".join(names))
	var verdict_text := "no sentence recommended yet" if GameState.get_flag(HIEROPHANT_FLAG) == null \
		else "verdict: %s" % GameState.get_flag(HIEROPHANT_FLAG)
	lines.append("Click a place to walk there. S supports, C convoy, B barracks, F forge, L to save or load, U free roam%s. %s(The Kaisareia Trial: %s.)" % [
		" (ON)" if free_roam else "", _autosave_hint(), verdict_text])
	info_label.text = "\n".join(lines)

## "Autosave found (2026-10-06 14:03): press L to load it. " on a fresh game that
## has one waiting; otherwise nothing.
func _autosave_hint() -> String:
	if not GameState.won_maps.is_empty() or not GameState.progression.is_empty():
		return ""
	var info := SaveGame.slot_info("auto")
	if not info["exists"] or info["damaged"]:
		return ""
	return "Autosave found (%s): press L to load it. " % SaveGame.format_time(info["saved_at"])

# -------------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_S:
		get_tree().change_scene_to_file(Supports.VIEWER_SCENE)
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_L:
		get_tree().change_scene_to_file(SaveGame.SCREEN_SCENE)
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_B:
		get_tree().change_scene_to_file(Progression.SCREEN_SCENE)
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_C:
		get_tree().change_scene_to_file(Equipment.SCREEN_SCENE)
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_F:
		open_forge()
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_X:
		if GameState.battle.is_empty():
			return
		if _abandon_armed:
			abandon_suspended()
		else:
			_abandon_armed = true
			_show_location(selected_location if selected_location != "" else party_location, not is_walking(),
				"Press X again to abandon the suspended battle for good. Any other key keeps it.")
		return
	if event is InputEventKey and event.pressed and _abandon_armed:
		_abandon_armed = false
	if event is InputEventKey and event.pressed and event.keycode == KEY_U:
		free_roam = not free_roam
		_show_location(selected_location if selected_location != "" else party_location, not is_walking())
		return
	if event is InputEventKey and event.pressed and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE):
		enter_location()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		click_at(get_local_mouse_position())

## A click on the map: the location under it (if any) -- walk there, or play it if the
## party is already standing on it.
func click_at(mp: Vector2) -> void:
	for lid in locations:
		if mp.distance_to(locations[lid]["pos"]) <= NODE_SIZE:
			if lid == party_location and not is_walking():
				enter_location()
			else:
				travel_to(lid)
			return

## Plays the next open chapter where the party stands; replays one if all are won.
func enter_location() -> void:
	if is_walking():
		return
	var entry := chapter_to_play(party_location)
	if entry.is_empty():
		if suspended_map() != "":
			_show_location(party_location, true, "A battle is suspended at %s. Go there and press Enter to resume it, or press X twice to abandon it." % locations[suspended_location()]["row"].get("name", "another place") if suspended_location() != "" else "A battle is suspended elsewhere; press X twice to abandon it.")
			return
		_show_location(party_location, true, "Nothing here can be played yet.")
		return
	_launch(entry)

## What Enter plays at a location: the next open chapter, else (everything won) the last
## one won there, as a replay; {} if neither.
func chapter_to_play(location_id: String) -> Dictionary:
	if suspended_map() != "":
		for e in locations[location_id]["chapters"]:
			if e.map_row.get("map_id", "") == suspended_map():
				return e          # a suspended battle is resumed whatever else is open here
		return {}
	var entry := next_chapter(location_id)
	if entry.is_empty():
		for e in locations[location_id]["chapters"]:
			if chapter_state(e)["status"] == "won":
				entry = e
	return entry

## The scene a chapter loads: the writ scene first if the Second Writ is next and no deputy has
## been named, else its special scene or its map ("" if none is built).
func scene_for(entry: Dictionary) -> String:
	var chapter_id: String = entry.chapter.get("chapter_id", "")
	if Deputy.writ_due(chapter_id):
		return Deputy.SCREEN_SCENE
	if SPECIAL_SCENES.has(chapter_id):
		return SPECIAL_SCENES[chapter_id]
	var map_id: String = entry.map_row.get("map_id", "")
	return AVAILABLE_SCENES.get(map_id, "")

func _launch(entry: Dictionary) -> void:
	chapter_launched.emit(entry.chapter.get("chapter_id", ""))
	if not launch_enabled:
		return
	var path := scene_for(entry)
	if path != "":
		get_tree().change_scene_to_file(path)
