extends PanelContainer
## The battle map's action menu: what the selected unit can do right now, as a list to pick from.
##
## The menu owns no rules. Each entry carries the hotkey that already runs the action, and choosing it hands that key
## back to the map (signal `chosen`), so a command behaves the same whether it was picked here or pressed directly.
## Opened with Space or a right-click; Up/Down move, Enter or a click chooses, Escape closes.

signal chosen(keycode: int)
signal closed

var entries: Array = []          # [{"label": String, "key": int}]
var index := 0
var _list: VBoxContainer
var _buttons: Array = []

func _init() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.12, 0.11, 0.10, 0.96)
	bg.border_color = Color(0.85, 0.75, 0.45, 0.9)
	bg.set_border_width_all(1)
	bg.set_content_margin_all(6)
	add_theme_stylebox_override("panel", bg)
	_list = VBoxContainer.new()
	add_child(_list)
	visible = false
	z_index = 50

## Shows the menu at `at` (map-local pixels) with these entries.
func open(new_entries: Array, at: Vector2, title: String) -> void:
	entries = new_entries
	index = 0
	for b in _buttons:
		b.queue_free()
	_buttons.clear()
	for child in _list.get_children():
		child.queue_free()
	var head := Label.new()
	head.text = title
	head.add_theme_font_size_override("font_size", 12)
	_list.add_child(head)
	for i in entries.size():
		var b := Button.new()
		b.text = "%s  [%s]" % [entries[i]["label"], OS.get_keycode_string(entries[i]["key"])]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_choose.bind(i))
		_list.add_child(b)
		_buttons.append(b)
	position = at
	visible = true
	_highlight()

func close() -> void:
	if visible:
		visible = false
		closed.emit()

func is_open() -> bool:
	return visible

## Keyboard while open. Returns true if the key was the menu's.
func handle_key(keycode: int) -> bool:
	if not visible:
		return false
	match keycode:
		KEY_UP:
			index = wrapi(index - 1, 0, maxi(1, entries.size()))
			_highlight()
		KEY_DOWN:
			index = wrapi(index + 1, 0, maxi(1, entries.size()))
			_highlight()
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_choose(index)
		KEY_ESCAPE:
			close()
		_:
			return false
	return true

func _choose(i: int) -> void:
	if i < 0 or i >= entries.size():
		return
	var key: int = entries[i]["key"]
	visible = false
	chosen.emit(key)

func _highlight() -> void:
	for i in _buttons.size():
		_buttons[i].modulate = Color(1.0, 0.92, 0.55) if i == index else Color(1, 1, 1)
