extends Node
## Autoload singleton: the scene pipeline (canon scenes tab). Register after Flashback.
##
## Canon lists 36 scenes by chapter: 'pre-battle' scenes (shown before the map), 'post-battle' scenes (after
## the win) and one 'narrative' scene (the Kaisareia Trial, which is a screen of its own). Each has speakers, a
## summary, and optional conditions: depends_on_flags (the flags it reads -- flag_deaths is the epilogue record,
## always there) and depends_on_units (a scene featuring them: shown if ANY of them has joined the company -- a guest counts while with it or once gone).
## Every scene is still 'drafted' with word_count 0 -- the canon has summaries, not scripts -- so the card shows
## the summary and says so; when a script is authored it is what the card will show. A scene is shown once
## (GameState.scenes_seen). The overworld stages pre-battle scenes before a chapter's map, and a won map stages its
## post-battle scenes on the way out.

const SCREEN := "res://scenes/scene_screen.tscn"
const OVERWORLD := "res://scenes/overworld.tscn"

func rows() -> Array:
	return Canon.get_table("scenes").filter(func(r): return str(r.get("scene_id", "")).begins_with("sc_"))

func row(scene_id: String) -> Dictionary:
	for r in rows():
		if r["scene_id"] == scene_id:
			return r
	return {}

func _list(v) -> Array:
	var out: Array = []
	if v == null:
		return out
	for part in str(v).split("|"):
		out.append(part.strip_edges())
	return out

## Whether the scene's conditions hold: every flag it reads is set, and (if it names units) one of them has joined.
func available(r: Dictionary) -> bool:
	for f in _list(r.get("depends_on_flags")):
		if f != "flag_deaths" and GameState.get_flag(f) == null:
			return false
	var units := _list(r.get("depends_on_units"))
	if not units.is_empty():
		var any := false
		for u in units:
			if (Defections.guest_met(u) if Defections.is_guest(u) else Defections.joined(u)):      # a guest is "met" while with the company, or after
				any = true
		if not any:
			return false
	return true

func seen(scene_id: String) -> bool:
	return GameState.scenes_seen.has(scene_id)

func mark_seen(scene_id: String) -> void:
	GameState.scenes_seen[scene_id] = true

## The scenes of `kind` ('pre-battle' / 'post-battle') waiting for a chapter: available and not yet shown, in table order.
func pending(chapter_id: String, kind: String) -> Array:
	var out: Array = []
	for r in rows():
		if r.get("chapter_id") == chapter_id and r.get("type") == kind and not seen(r["scene_id"]) and available(r):
			out.append(r["scene_id"])
	return out

## The scene screen's hand-off (not saved): the scene ids still to show and where to go afterwards.
var queue: Array = []
var next_path: String = OVERWORLD

## Gets the next screen ready: the queue of scene ids to show and where to go afterwards. Returns the screen's path.
func stage(ids: Array, after: String) -> String:
	queue = ids.duplicate()
	next_path = after
	return SCREEN

## "Jost, the church surveyor": a scene's speakers by name.
func speakers(r: Dictionary) -> String:
	var names: Array[String] = []
	for sp in _list(r.get("speaker_ids")):
		var u = Canon.find_by("units", "unit_id", sp)
		if u != null:
			names.append(str(u.get("name")))
			continue
		var g = Canon.find_by("guest_units", "guest_id", sp)
		if g != null:
			names.append(str(g.get("name")))
			continue
		var n = Canon.find_by("npcs", "npc_id", sp)
		names.append(str(n.get("name")) if n != null else sp)
	return ", ".join(names)

## Whether the scene has a script yet (canon word_count above 0).
func has_script(r: Dictionary) -> bool:
	return int(str(r.get("word_count", "0"))) > 0

func chapter_title(chapter_id: String) -> String:
	var c = Canon.find_by("chapters", "chapter_id", chapter_id)
	return str(c.get("title")) if c != null else chapter_id

## The card for a scene: {"title", "speakers", "text", "note"}.
func card(scene_id: String) -> Dictionary:
	var r := row(scene_id)
	var when := "before the battle" if r.get("type") == "pre-battle" else "after the battle"
	return {"title": "%s -- %s" % [chapter_title(str(r.get("chapter_id"))), when], "speakers": speakers(r), "text": str(r.get("summary", "")),
		"note": "" if has_script(r) else "(This scene is drafted but has no script yet; this is its summary.)"}
