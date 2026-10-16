extends Control
## A scene card (canon scenes tab): who speaks and what happens, one card per scene, then on to wherever the
## Scenes autoload was told (the chapter's map, or back to the overworld). Enter / Space shows the next card;
## Escape skips what is left. Each card is marked seen as it is shown, so a scene plays once.

var _ids: Array = []
var _index := 0

var _title: Label
var _speakers: Label
var _body: RichTextLabel
var _footer: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
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
	page.add_child(_speakers)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(_body)
	_footer = Label.new()
	_footer.add_theme_font_size_override("font_size", 12)
	page.add_child(_footer)
	_show()

func _show() -> void:
	if _index >= _ids.size():
		finish()
		return
	var id: String = _ids[_index]
	Scenes.mark_seen(id)
	var c := Scenes.card(id)
	_title.text = c["title"]
	_speakers.text = ("Speaking: %s" % c["speakers"]) if c["speakers"] != "" else ""
	_body.text = "%s\n\n[color=#8a8a92]%s[/color]" % [c["text"], c["note"]]
	_footer.text = "Scene %d of %d    Enter continue   Esc skip" % [_index + 1, _ids.size()]

## Next card, or on to the next screen when there are none left. Returns true when it is done.
func advance() -> bool:
	_index += 1
	_show()
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
	if not (event is InputEventKey and event.pressed):
		return
	match (event as InputEventKey).keycode:
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			advance()
		KEY_ESCAPE:
			skip()
