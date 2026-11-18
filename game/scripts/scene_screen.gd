extends Control
## The scene screen (canon scenes tab): the scenes the Scenes autoload has queued, then on to wherever it was told (the
## chapter's map, or back to the overworld). A scene with a script (game/dialogue/<scene_id>.txt) plays line by line,
## each with its speaker's name and portrait; a scene without one shows its summary as a card. Enter, Space or a click
## goes on; Escape skips what is left. A scene is marked seen when it is shown, so it plays once.

const PortraitScript := preload("res://scripts/portrait.gd")
const BACKDROP_DIR := "res://art/backdrops/"       # <chapter_id>.png (or .jpg / .webp): the painted scene behind the dialogue

var _ids: Array = []
var _index := 0                 # which scene
var _lines: Array = []          # the current scene's script ([] for a summary card)
var _line := 0                  # which line of it

var _title: Label
var _speakers: Label
var _body: RichTextLabel
var _footer: Label
var _portrait: Control
var _name: Label
var _backdrop: TextureRect

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.085, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_backdrop = TextureRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)
	_ids = Scenes.queue.duplicate()
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	margin.add_child(page)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 20)
	page.add_child(_title)
	_speakers = Label.new()
	_speakers.add_theme_font_size_override("font_size", 13)
	_speakers.modulate = Color(0.75, 0.72, 0.65)
	page.add_child(_speakers)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(spacer)
	# the dialogue box: portrait on the left, the speaker's name over the line
	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.13, 0.12, 0.96)
	style.border_color = Color(0.85, 0.75, 0.45, 0.7)
	style.set_border_width_all(1)
	style.set_content_margin_all(14)
	box.add_theme_stylebox_override("panel", style)
	box.custom_minimum_size = Vector2(0, 196)
	page.add_child(box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	_portrait = PortraitScript.new()
	row.add_child(_portrait)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 17)
	_name.modulate = Color(0.95, 0.82, 0.5)
	col.add_child(_name)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_font_size_override("normal_font_size", 17)
	_body.add_theme_font_size_override("italics_font_size", 17)
	col.add_child(_body)
	_footer = Label.new()
	_footer.add_theme_font_size_override("font_size", 12)
	_footer.modulate = Color(0.6, 0.6, 0.62)
	page.add_child(_footer)
	_open_scene()

## Starts the scene at _index (or finishes when there are none left).
func _open_scene() -> void:
	if _index >= _ids.size():
		finish()
		return
	var id: String = _ids[_index]
	Scenes.mark_seen(id)
	var c := Scenes.card(id)
	_title.text = c["title"]
	_speakers.text = ("Speaking: %s" % c["speakers"]) if c["speakers"] != "" else ""
	_backdrop.texture = backdrop_for(str(Scenes.row(id).get("chapter_id", "")))
	_lines = Scenes.script(id)
	_line = 0
	_show()

func _show() -> void:
	var id: String = _ids[_index]
	if _lines.is_empty():
		var c := Scenes.card(id)
		_portrait.show_speaker("", "")
		_name.text = ""
		_body.text = "%s\n\n[color=#8a8a92]%s[/color]" % [c["text"], c["note"]]
		_footer.text = "Scene %d of %d    Enter continue   Esc skip" % [_index + 1, _ids.size()]
		return
	var l: Dictionary = _lines[_line]
	_portrait.show_speaker(str(l["speaker_id"]), str(l["name"]))
	_name.text = str(l["name"])
	_body.text = ("[i]%s[/i]" % l["text"]) if l["name"] == "" else str(l["text"])
	_footer.text = "Scene %d of %d, line %d of %d    Enter continue   Esc skip" % [_index + 1, _ids.size(), _line + 1, _lines.size()]

## The painted backdrop for a chapter's scenes, or null until one is added.
static func backdrop_for(chapter_id: String) -> Texture2D:
	for ext in ["png", "jpg", "webp"]:
		var path := "%s%s.%s" % [BACKDROP_DIR, chapter_id, ext]
		if chapter_id != "" and ResourceLoader.exists(path):
			return load(path)
	return null

## The next line, or the next scene, or on to the next screen. Returns true when everything has been shown.
func advance() -> bool:
	if not _lines.is_empty() and _line + 1 < _lines.size():
		_line += 1
		_show()
		return false
	_index += 1
	_open_scene()
	return _index >= _ids.size()

func skip() -> void:
	for i in range(_index, _ids.size()):
		Scenes.mark_seen(_ids[i])
	_index = _ids.size()
	finish()

func finish() -> void:
	var dest: String = Scenes.next_path
	Scenes.queue = []
	Scenes.next_path = Scenes.OVERWORLD
	if is_inside_tree() and get_tree().current_scene == self:
		SaveGame.autosave()
		get_tree().change_scene_to_file(dest)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance()
		return
	if not (event is InputEventKey and event.pressed):
		return
	match (event as InputEventKey).keycode:
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			advance()
		KEY_ESCAPE:
			skip()
