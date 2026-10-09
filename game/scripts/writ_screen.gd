extends Control
## The writ scene, before the Second Writ (ch_x11): the crown's auditor reads out the ledger
## and the crown names its deputy -- the highest score. Enter accepts it. To name someone
## else, choose them with Up/Down and press Enter, then Enter again to confirm: the crown
## grants it, once, and withholds Column B's supply attachment. Escape leaves without deciding
## (the writ is still due). Everything is read from and written to the Deputy autoload.

const OVERWORLD_SCENE := "res://scenes/overworld.tscn"
const BAD := "#ff6b6b"
const GOOD := "#5fd068"
const GOLD := "#e8c14a"
const DIM := "#8a8a92"

var _ranking: Array = []
var _index := 0
var _confirming := false          # a contest has been proposed and awaits the second Enter
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
	_list.custom_minimum_size = Vector2(300, 0)
	_list.item_selected.connect(func(i: int) -> void:
		_index = i
		_confirming = false
		_refresh_detail())
	body.add_child(_list)
	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_detail)
	_footer = Label.new()
	_footer.add_theme_font_size_override("font_size", 12)
	page.add_child(_footer)

func _fmt(v: float) -> String:
	return ("%d" % int(v)) if is_equal_approx(v, round(v)) else ("%.2f" % v).rstrip("0")

func row_label(i: int) -> String:
	var r: Dictionary = _ranking[i]
	return "%d. %s   %s%s" % [i + 1, r["name"], _fmt(r["score"]), "   <- the crown's choice" if i == 0 else ""]

func detail_text() -> String:
	var lines: Array[String] = []
	if Deputy.decided():
		lines.append("[b]The deputy is %s.[/b]%s" % [Deputy._unit_name(Deputy.deputy()), " The crown granted the contest and withheld Column B's supply attachment." if Deputy.contested() else ""])
		return "\n".join(lines)
	if _ranking.is_empty():
		return "No one in the company is a candidate for deputy yet."
	var r: Dictionary = _ranking[_index]
	lines.append("[b][font_size=18]%s[/font_size][/b]   [color=%s]%s points[/color]" % [r["name"], GOLD, _fmt(r["score"])])
	var bd := Deputy.breakdown(r["unit_id"])
	if bd.is_empty():
		lines.append("[color=%s]Nothing in the ledger.[/color]" % DIM)
	for b in bd:
		lines.append("%s: %d x %s = %s" % [b["label"], b["count"], _fmt(b["weight"]), _fmt(b["points"])])
	lines.append("")
	if _index == 0:
		lines.append("[color=%s]The crown names %s. Enter accepts.[/color]" % [GOOD, r["name"]])
	elif _confirming:
		lines.append("[color=%s]Press Enter again to name %s over the crown's choice. The crown will grant it, once -- and withhold Column B's supply attachment.[/color]" % [BAD, r["name"]])
	else:
		lines.append("[color=%s]Naming %s over the crown's choice is a contest: Enter, then Enter again. The crown grants it, once, and withholds Column B's supply attachment.[/color]" % [DIM, r["name"]])
	return "\n".join(lines)

## Enter. The crown's choice is accepted at once; anyone else needs a second Enter.
## Returns true once a deputy has been named.
func activate() -> bool:
	if Deputy.decided() or _ranking.is_empty():
		return false
	var uid: String = _ranking[_index]["unit_id"]
	if _index != 0 and not _confirming:
		_confirming = true
		_message = ""
		_refresh()
		return false
	var r := Deputy.decide(uid)
	if r["ok"]:
		_message = "%s is the crown's deputy.%s" % [Deputy._unit_name(uid), " Column B's supply attachment is withheld." if r["contested"] else ""]
	else:
		_message = "Can't: %s." % r["reason"]
	_confirming = false
	_refresh()
	return r["ok"]

func _refresh() -> void:
	_ranking = Deputy.ranking()
	_index = clampi(_index, 0, maxi(0, _ranking.size() - 1))
	_title.text = "The writ scene -- the crown names its deputy"
	_list.clear()
	for i in _ranking.size():
		_list.add_item(row_label(i))
	if _list.item_count > 0:
		_list.select(_index)
	_refresh_detail()
	_footer.text = "%s\nUp/Down choose   Enter accept / name (twice to contest)   Esc %s" % [_message, "continue" if Deputy.decided() else "back (the writ is still due)"]

func _refresh_detail() -> void:
	_detail.text = detail_text()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	match (event as InputEventKey).keycode:
		KEY_ESCAPE:
			SaveGame.autosave()
			get_tree().change_scene_to_file(OVERWORLD_SCENE)
		KEY_UP:
			_index = maxi(0, _index - 1)
			_confirming = false
			_message = ""
			_refresh()
		KEY_DOWN:
			_index = mini(_ranking.size() - 1, _index + 1)
			_confirming = false
			_message = ""
			_refresh()
		KEY_ENTER, KEY_KP_ENTER:
			activate()
