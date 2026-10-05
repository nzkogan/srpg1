extends Control
## Save / load screen: four slots (the automatic one plus three manual), a
## detail pane for the highlighted slot beside a summary of the game in play.
## Reads and writes through the SaveGame autoload; owns no data.
##
## Controls: Up/Down choose a slot, Tab switches between Save and Load, Enter
## does the current mode on the slot (saving over an existing save, deleting and
## starting a new game all ask for a second press), X deletes a slot, N starts a
## new game, Escape returns to the overworld. The list takes the mouse too.
##
## The automatic slot is written for you after every won map and when you leave
## the barracks or convoy; it can be loaded and deleted but not saved over by hand.

const OVERWORLD_SCENE := "res://scenes/overworld.tscn"
const MODE_SAVE := 0
const MODE_LOAD := 1
const MODE_NAMES := ["Save", "Load"]
const BAD := "#ff6b6b"
const GOOD := "#5fd068"
const GOLD := "#e8c14a"
const DIM := "#8a8a92"

## Tests switch this off so a successful load doesn't swap the scene mid-check.
var leave_after_load := true

var _mode := MODE_LOAD
var _index := 0
var _confirm := ""        # the action awaiting a second press, e.g. "save:1", "delete:2", "new"
var _message := ""

var _title: Label
var _list: ItemList
var _detail: RichTextLabel
var _footer: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_refresh()

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	margin.add_child(page)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 20)
	page.add_child(_title)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	page.add_child(body)
	_list = ItemList.new()
	_list.focus_mode = Control.FOCUS_NONE
	_list.custom_minimum_size = Vector2(540, 0)
	_list.select_mode = ItemList.SELECT_SINGLE
	_list.item_selected.connect(_on_clicked)
	body.add_child(_list)
	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_detail)
	_footer = Label.new()
	_footer.add_theme_font_size_override("font_size", 12)
	page.add_child(_footer)

# ----------------------------------------------------------------- state

func selected_slot() -> String:
	return SaveGame.SLOTS[_index]

func slot_label(slot: String) -> String:
	return "Autosave" if slot == "auto" else "Slot %s" % slot

## "Slot 1   2026-10-06 14:03   Lv 21   1234 gold   3 maps" / "(empty)" / "(damaged)".
func row_text(info: Dictionary) -> String:
	var label := slot_label(info["slot"])
	if info["damaged"]:
		return "%s   (damaged)" % label
	if not info["exists"]:
		return "%s   (empty)" % label
	var s: Dictionary = info["summary"]
	return "%s   %s   Lv %d   %d gold   %d map%s" % [label, SaveGame.format_time(info["saved_at"]), int(s.get("top_level", 0)),
		int(s.get("gold", 0)), int(s.get("maps_won", 0)), "" if int(s.get("maps_won", 0)) == 1 else "s"]

func _summary_lines(s: Dictionary) -> Array[String]:
	return [
		"Maps won: %d" % int(s.get("maps_won", 0)),
		"Squad: %d unit%s fielded, highest level %d, %d at order tier or above" % [int(s.get("units", 0)), "" if int(s.get("units", 0)) == 1 else "s", int(s.get("top_level", 0)), int(s.get("certified", 0))],
		"Gold: %d" % int(s.get("gold", 0)),
		"Deeds earned: %d" % int(s.get("deeds", 0)),
	]

func _refresh() -> void:
	_title.text = "%s    [%s]" % ["Save / Load", MODE_NAMES[_mode]]
	_list.clear()
	var infos := SaveGame.list_slots()
	for info in infos:
		_list.add_item(row_text(info))
		if info["damaged"]:
			_list.set_item_custom_fg_color(_list.item_count - 1, Color(BAD))
	_list.select(_index)
	_detail.text = detail_text(infos[_index])
	var hint := "Up/Down choose   Tab Save/Load   Enter %s   X delete   N new game   Esc back" % MODE_NAMES[_mode].to_lower()
	_footer.text = "%s\n%s" % [_message, hint]

func detail_text(info: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("[b][font_size=20]%s[/font_size][/b]" % slot_label(info["slot"]))
	if info["damaged"]:
		lines.append("[color=%s]This save can't be read: %s.[/color]" % [BAD, info["error"]])
	elif not info["exists"]:
		lines.append("[color=%s]Empty.[/color]" % DIM)
	else:
		lines.append("Saved %s" % SaveGame.format_time(info["saved_at"]))
		lines.append_array(_summary_lines(info["summary"]))
	lines.append("")
	lines.append("[b]The game in play[/b]")
	lines.append_array(_summary_lines(SaveGame.make_summary()))
	lines.append("")
	if info["slot"] == "auto":
		lines.append("[color=%s]Written automatically after every won map and when you leave the barracks or convoy.[/color]" % DIM)
	if _confirm != "":
		lines.append("[color=%s]%s Press the same key again to confirm, anything else to cancel.[/color]" % [GOLD, _confirm_text()])
	return "\n".join(lines)

func _confirm_text() -> String:
	var parts := _confirm.split(":")
	match parts[0]:
		"save": return "Overwrite %s?" % slot_label(parts[1])
		"delete": return "Delete %s?" % slot_label(parts[1])
		"new": return "Start a new game and discard the one in play (it keeps its saves)?"
	return ""

# ---------------------------------------------------------------- actions

func _on_clicked(index: int) -> void:
	_index = clampi(index, 0, SaveGame.SLOTS.size() - 1)
	_confirm = ""
	_message = ""
	_refresh()

func move(delta: int) -> void:
	_index = wrapi(_index + delta, 0, SaveGame.SLOTS.size())
	_confirm = ""
	_message = ""
	_refresh()

func set_mode(mode: int) -> void:
	_mode = wrapi(mode, 0, MODE_NAMES.size())
	_confirm = ""
	_message = ""
	_refresh()

## True if `key` is the pending action, else arms it. Used for the second press.
func _confirmed(key: String) -> bool:
	if _confirm == key:
		_confirm = ""
		return true
	_confirm = key
	return false

func activate() -> void:
	var slot := selected_slot()
	if _mode == MODE_SAVE:
		if slot == "auto":
			_message = "The autosave is written for you; pick a numbered slot to save by hand."
			_refresh()
			return
		var existing := SaveGame.slot_info(slot)
		if (existing["exists"]) and not _confirmed("save:%s" % slot):
			_refresh()
			return
		var r := SaveGame.save(slot)
		_message = "Saved to %s." % slot_label(slot) if r["ok"] else "Couldn't save: %s." % r["error"]
		_confirm = ""
	else:
		var info := SaveGame.slot_info(slot)
		if not info["exists"]:
			_message = "%s is empty." % slot_label(slot)
		else:
			var r := SaveGame.load_slot(slot)
			if r["ok"]:
				_message = "Loaded %s%s." % [slot_label(slot), " from its backup (the main file was damaged)" if r["used_backup"] else ""]
				_refresh()
				if leave_after_load:
					leave()
				return
			_message = "Couldn't load: %s." % r["error"]
		_confirm = ""
	_refresh()

func delete_selected() -> void:
	var slot := selected_slot()
	if not SaveGame.slot_info(slot)["exists"]:
		_message = "%s is already empty." % slot_label(slot)
		_confirm = ""
	elif _confirmed("delete:%s" % slot):
		SaveGame.delete_slot(slot)
		_message = "Deleted %s." % slot_label(slot)
	_refresh()

func new_game() -> void:
	if _confirmed("new"):
		GameState.reset()
		Supports.begin_map()
		_message = "A new game. (Your saves are untouched.)"
	_refresh()

func leave() -> void:
	get_tree().change_scene_to_file(OVERWORLD_SCENE)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	var key := (event as InputEventKey).keycode
	# any key other than the one that armed a confirmation cancels it
	if _confirm != "" and key not in [KEY_ENTER, KEY_KP_ENTER, KEY_X, KEY_N]:
		_confirm = ""
	match key:
		KEY_UP: move(-1)
		KEY_DOWN: move(1)
		KEY_TAB: set_mode(_mode + 1)
		KEY_ENTER, KEY_KP_ENTER: activate()
		KEY_X: delete_selected()
		KEY_N: new_game()
		KEY_ESCAPE: leave()
		_: return
	get_viewport().set_input_as_handled()
