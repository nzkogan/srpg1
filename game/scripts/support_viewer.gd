extends Control
## Support conversation viewer: pick a unit, pick one of their 17 partners,
## read that chain's scenes. Reads everything from the Supports autoload (the
## `supports` table plus this playthrough's ranks and points) -- it owns no
## data and changes none.
##
## By default a chain shows only the ranks reached so far this playthrough,
## with the rest listed as locked and the points they need. R reveals every
## rank's text, for reading the writing before the earning rule has produced
## any ranks (and for review).
##
## Controls: Up/Down move in the active column, Left/Right switch between the
## unit and partner columns, PageUp/PageDown scroll the scene text, R toggles
## reveal-all, Escape returns to the overworld. The lists also take the mouse.

const OVERWORLD_SCENE := "res://scenes/overworld.tscn"
const COLUMN_UNITS := 0
const COLUMN_PARTNERS := 1
const INACTIVE_TINT := Color(1, 1, 1, 0.6)
const LOCKED_COLOR := "#8a8a92"

var unit_ids: Array[String] = []
var _unit_names: Dictionary = {}
var _partner_chains: Array[String] = []   # chain ids for the selected unit, in list order

var reveal_all := false
var _column := COLUMN_UNITS
var _unit_index := 0
var _partner_index := 0

var _title: Label
var _units_list: ItemList
var _partners_list: ItemList
var _detail: RichTextLabel
var _footer: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for row in Canon.get_table("units"):
		unit_ids.append(row["unit_id"])
		_unit_names[row["unit_id"]] = row.get("name", row["unit_id"])
	_build_ui()
	select_unit(0)

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

	_units_list = _make_list(body, "Units", 170)
	_partners_list = _make_list(body, "Partners", 310)
	_units_list.item_selected.connect(func(i: int) -> void: _on_list_clicked(COLUMN_UNITS, i))
	_partners_list.item_selected.connect(func(i: int) -> void: _on_list_clicked(COLUMN_PARTNERS, i))

	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_detail)

	_footer = Label.new()
	_footer.add_theme_font_size_override("font_size", 12)
	page.add_child(_footer)

	for u in unit_ids:
		_units_list.add_item(_unit_names[u])

## One column: a small caption over an ItemList. Keyboard focus stays off the
## lists on purpose -- _unhandled_input drives them, so there is one set of keys.
func _make_list(parent: Node, caption: String, width: int) -> ItemList:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(width, 0)
	parent.add_child(col)
	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", 12)
	col.add_child(label)
	var list := ItemList.new()
	list.focus_mode = Control.FOCUS_NONE
	list.select_mode = ItemList.SELECT_SINGLE
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(list)
	return list

# ------------------------------------------------------------- selection

func select_unit(index: int) -> void:
	_unit_index = clampi(index, 0, unit_ids.size() - 1)
	_units_list.select(_unit_index)
	_units_list.ensure_current_is_visible()
	_rebuild_partners()
	select_partner(0)

func select_partner(index: int) -> void:
	if _partner_chains.is_empty():
		_partner_index = 0
		_refresh()
		return
	_partner_index = clampi(index, 0, _partner_chains.size() - 1)
	_partners_list.select(_partner_index)
	_partners_list.ensure_current_is_visible()
	_refresh()

func selected_unit() -> String:
	return unit_ids[_unit_index] if not unit_ids.is_empty() else ""

func selected_chain() -> String:
	return _partner_chains[_partner_index] if _partner_index < _partner_chains.size() else ""

func _on_list_clicked(column: int, index: int) -> void:
	_column = column
	if column == COLUMN_UNITS:
		select_unit(index)
	else:
		select_partner(index)

func _rebuild_partners() -> void:
	var unit := selected_unit()
	var rows: Array = []
	for chain_id in Supports.chains_for(unit):
		rows.append({
			"chain": chain_id,
			"name": _name_of(Supports.partner_of(chain_id, unit)),
			"rank_idx": Supports.RANKS.find(Supports.current_rank(chain_id)),
			"points": Supports.points(chain_id),
		})
	# furthest-along bonds first, then by points, then alphabetical so the order is stable
	rows.sort_custom(func(a, b):
		if a["rank_idx"] != b["rank_idx"]:
			return a["rank_idx"] > b["rank_idx"]
		if a["points"] != b["points"]:
			return a["points"] > b["points"]
		return a["name"] < b["name"]
	)
	_partner_chains.clear()
	_partners_list.clear()
	for r in rows:
		_partner_chains.append(r["chain"])
		_partners_list.add_item(partner_row_text(r["chain"], selected_unit()))

## "Maren   B  8 pts   romance" -- rank (or "--"), banked points, and a romance tag.
func partner_row_text(chain_id: String, unit_id: String) -> String:
	var rank := Supports.current_rank(chain_id)
	var text := "%s   %s   %d pts" % [_name_of(Supports.partner_of(chain_id, unit_id)),
		rank if rank != "" else "--", Supports.points(chain_id)]
	if Supports.is_romance_eligible(chain_id):
		text += "   romance"
	return text

func _name_of(unit_id: String) -> String:
	return _unit_names.get(unit_id, unit_id)

# ---------------------------------------------------------------- display

func _refresh() -> void:
	_units_list.modulate = Color.WHITE if _column == COLUMN_UNITS else INACTIVE_TINT
	_partners_list.modulate = Color.WHITE if _column == COLUMN_PARTNERS else INACTIVE_TINT
	_title.text = "Supports -- %s" % _name_of(selected_unit())
	_detail.text = view_text(selected_chain())
	_detail.scroll_to_line(0)
	_footer.text = "Up/Down choose   Left/Right switch column   PgUp/PgDn scroll   R reveal all: %s   Esc back" % \
		("ON" if reveal_all else "off")

## BBCode for one chain: names, signs, progress, then each rank's scene --
## the text if reached (or reveal_all), otherwise a locked line with the
## points it needs. Public so tests can read exactly what the player would see.
func view_text(chain_id: String) -> String:
	if chain_id == "":
		return ""
	var row: Dictionary = Supports.get_chain_by_id(chain_id)
	var a: String = row.get("unit_a_id", "")
	var b: String = row.get("unit_b_id", "")
	var lines: Array[String] = []
	lines.append("[b]%s & %s[/b]" % [_esc(_name_of(a)), _esc(_name_of(b))])
	var signs: Array = Supports.sign_names(chain_id)
	if signs.size() == 2 and signs[0] != "" and signs[1] != "":
		lines.append("[i]%s and %s[/i]" % [_esc(signs[0]), _esc(signs[1])])
	lines.append(_progress_line(chain_id))
	lines.append("")

	var reached := Supports.RANKS.find(Supports.current_rank(chain_id))
	var top := Supports.RANKS.find(Supports.max_rank(chain_id))
	for i in range(0, top + 1):
		var rank: String = Supports.RANKS[i]
		var text: String = Supports.scene_text(chain_id, rank)
		if text == "":
			continue
		if i <= reached or reveal_all:
			var tag := "" if i <= reached else "  [color=%s](not reached yet)[/color]" % LOCKED_COLOR
			lines.append("[b]Rank %s[/b]%s" % [rank, tag])
			lines.append(_esc(text))
		else:
			lines.append("[color=%s]Rank %s -- locked (%d points)[/color]" % [
				LOCKED_COLOR, rank, Supports.POINTS_FOR_RANK[rank]])
		lines.append("")
	return "\n".join(lines).strip_edges()

func _progress_line(chain_id: String) -> String:
	var rank := Supports.current_rank(chain_id)
	var pts := Supports.points(chain_id)
	var left := Supports.points_to_next(chain_id)
	var kind := "romance-eligible (can reach S)" if Supports.is_romance_eligible(chain_id) \
		else "platonic (tops out at A)"
	var status := "No rank yet" if rank == "" else "Rank %s" % rank
	if left < 0:
		return "%s -- maximum reached, %d points banked -- %s" % [status, pts, kind]
	return "%s -- %d points banked, %d to rank %s -- %s" % [status, pts, left, Supports.next_rank(chain_id), kind]

## BBCode would read a "[" in scene text as a tag; escape it.
func _esc(text: String) -> String:
	return text.replace("[", "[lb]")

# ------------------------------------------------------------------ input

func toggle_reveal() -> void:
	reveal_all = not reveal_all
	_refresh()

func move(delta: int) -> void:
	if _column == COLUMN_UNITS:
		select_unit(wrapi(_unit_index + delta, 0, unit_ids.size()))
	elif not _partner_chains.is_empty():
		select_partner(wrapi(_partner_index + delta, 0, _partner_chains.size()))

func switch_column(column: int) -> void:
	_column = column
	_refresh()

func leave() -> void:
	get_tree().change_scene_to_file(OVERWORLD_SCENE)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	match (event as InputEventKey).keycode:
		KEY_UP: move(-1)
		KEY_DOWN: move(1)
		KEY_LEFT: switch_column(COLUMN_UNITS)
		KEY_RIGHT: switch_column(COLUMN_PARTNERS)
		KEY_PAGEUP: _scroll(-1)
		KEY_PAGEDOWN: _scroll(1)
		KEY_R: toggle_reveal()
		KEY_ESCAPE: leave()
		_: return
	get_viewport().set_input_as_handled()

func _scroll(direction: int) -> void:
	var bar := _detail.get_v_scroll_bar()
	bar.value += direction * _detail.size.y * 0.8
