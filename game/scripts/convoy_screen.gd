extends Control
## Convoy screen: manage who carries what between maps. Three columns -- the
## roster, the selected unit's inventory, and the shared convoy -- and a detail
## pane for whichever weapon is highlighted. Everything is read from and written
## to the Equipment autoload; this screen owns no data.
##
## Weapons a unit can't wield are shown in red with the arts they lack. A unit
## may carry such a weapon (to hand it on), they just can't equip it.
##
## Controls: Up/Down move in the active column, Left/Right switch column
## (units / inventory / convoy), Enter equips the highlighted inventory weapon
## or takes the highlighted convoy weapon, T (or Space) moves a weapon between
## the inventory and the convoy, Escape returns to the overworld. The lists
## take the mouse too.

const CombatScript := preload("res://scripts/combat.gd")
const OVERWORLD_SCENE := "res://scenes/overworld.tscn"
const COLUMN_UNITS := 0
const COLUMN_INVENTORY := 1
const COLUMN_CONVOY := 2
const INACTIVE_TINT := Color(1, 1, 1, 0.6)
const BAD := "#ff6b6b"
const GOOD := "#5fd068"
const GOLD := "#e8c14a"
const DIM := "#8a8a92"

var unit_ids: Array[String] = []
var _unit_names: Dictionary = {}
var _column := COLUMN_UNITS
var _unit_index := 0
var _inv_index := 0
var _convoy_index := 0
var _message := ""

var _title: Label
var _units_list: ItemList
var _inv_list: ItemList
var _convoy_list: ItemList
var _detail: RichTextLabel
var _footer: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for row in Canon.get_table("units"):
		unit_ids.append(row["unit_id"])
		_unit_names[row["unit_id"]] = row.get("name", row["unit_id"])
	_build_ui()
	_refresh_all()

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
	_units_list = _make_list(body, "Units", 225)
	_inv_list = _make_list(body, "Carrying", 240)
	_convoy_list = _make_list(body, "Convoy", 200)
	_units_list.item_selected.connect(func(i: int) -> void: _on_clicked(COLUMN_UNITS, i))
	_inv_list.item_selected.connect(func(i: int) -> void: _on_clicked(COLUMN_INVENTORY, i))
	_convoy_list.item_selected.connect(func(i: int) -> void: _on_clicked(COLUMN_CONVOY, i))
	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_detail)
	_footer = Label.new()
	_footer.add_theme_font_size_override("font_size", 12)
	page.add_child(_footer)

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

# ----------------------------------------------------------------- state

func selected_unit() -> String:
	return unit_ids[_unit_index] if not unit_ids.is_empty() else ""

func selected_inventory() -> Array:
	return Equipment.inventory(selected_unit())

func _name_of(unit_id: String) -> String:
	return _unit_names.get(unit_id, unit_id)

func _count(column: int) -> int:
	match column:
		COLUMN_UNITS: return unit_ids.size()
		COLUMN_INVENTORY: return selected_inventory().size()
		_: return Equipment.convoy().size()

func _index_of(column: int) -> int:
	match column:
		COLUMN_UNITS: return _unit_index
		COLUMN_INVENTORY: return _inv_index
		_: return _convoy_index

func _set_index(column: int, value: int) -> void:
	var n := _count(column)
	value = clampi(value, 0, maxi(0, n - 1))
	match column:
		COLUMN_UNITS: _unit_index = value
		COLUMN_INVENTORY: _inv_index = value
		_: _convoy_index = value

## The entry under the cursor in the inventory or convoy column ({} otherwise).
func highlighted_entry() -> Dictionary:
	if _column == COLUMN_INVENTORY and _inv_index < selected_inventory().size():
		return selected_inventory()[_inv_index]
	if _column == COLUMN_CONVOY and _convoy_index < Equipment.convoy().size():
		return Equipment.convoy()[_convoy_index]
	return {}

# --------------------------------------------------------------- display

## "Jost   Iron Axe (45)" -- the roster row.
func unit_row_text(unit_id: String) -> String:
	var e := Equipment.equipped(unit_id)
	return "%s   %s" % [_name_of(unit_id), Equipment.describe(e) if not e.is_empty() else "--"]

## "* Iron Axe (45)" (star = equipped), with a tag if the unit can't wield it.
func inventory_row_text(unit_id: String, entry: Dictionary, is_equipped: bool) -> String:
	var text := "%s%s" % ["* " if is_equipped else "  ", Equipment.describe(entry)]
	if not Equipment.can_wield(unit_id, entry["weapon_id"]):
		text += "   can't use"
	return text

func _refresh_all() -> void:
	_title.text = "Convoy -- %s" % _name_of(selected_unit())
	_units_list.clear()
	for u in unit_ids:
		_units_list.add_item(unit_row_text(u))
	_inv_list.clear()
	var inv := selected_inventory()
	var eq_idx := Equipment.equipped_index(selected_unit())
	for i in inv.size():
		_inv_list.add_item(inventory_row_text(selected_unit(), inv[i], i == eq_idx))
		if not Equipment.can_wield(selected_unit(), inv[i]["weapon_id"]):
			_inv_list.set_item_custom_fg_color(i, Color(BAD))
	_convoy_list.clear()
	for e in Equipment.convoy():
		_convoy_list.add_item(Equipment.describe(e))
	_set_index(COLUMN_INVENTORY, _inv_index)
	_set_index(COLUMN_CONVOY, _convoy_index)
	if _units_list.item_count > 0:
		_units_list.select(_unit_index)
	if _inv_list.item_count > 0:
		_inv_list.select(_inv_index)
	if _convoy_list.item_count > 0:
		_convoy_list.select(_convoy_index)
	_units_list.modulate = Color.WHITE if _column == COLUMN_UNITS else INACTIVE_TINT
	_inv_list.modulate = Color.WHITE if _column == COLUMN_INVENTORY else INACTIVE_TINT
	_convoy_list.modulate = Color.WHITE if _column == COLUMN_CONVOY else INACTIVE_TINT
	_detail.text = detail_text()
	_footer.text = "%s\nUp/Down choose   Left/Right column   Enter equip / take   T store / take   Esc back   (carrying %d/%d)" % [
		_message, selected_inventory().size(), Equipment.INVENTORY_SIZE]

## BBCode for the highlighted weapon: its numbers, who can wield it, and what it
## would do for the selected unit.
func detail_text() -> String:
	var entry := highlighted_entry()
	if entry.is_empty():
		return "[color=%s]Nothing highlighted.[/color]" % DIM
	var row := Equipment.weapon_row(entry["weapon_id"])
	var req: Array = CombatScript.required_arts(row)
	var lines: Array[String] = []
	lines.append("[b][font_size=20]%s[/font_size][/b]   %d / %d uses" % [row.get("name", entry["weapon_id"]), entry["uses"], int(row.get("uses", entry["uses"]))])
	lines.append("%s -- requires %s" % [row.get("art", "?"), " + ".join(req)])
	var rng := str(row.get("range_min", 1)) if row.get("range_min") == row.get("range_max") else "%s-%s" % [row.get("range_min", 1), row.get("range_max", 1)]
	lines.append("Might %s   Hit %s   Crit %s   Weight %s   Range %s" % [row.get("might"), row.get("hit"), row.get("crit"), row.get("weight"), rng])
	var eff := str(row.get("effective_vs", "")) if row.get("effective_vs") != null else ""
	if eff != "":
		lines.append("[color=%s]Effective vs %s (x%d might).[/color]" % [GOLD, eff.replace("|", ", "), CombatScript.EFFECTIVE_MULT])
	if CombatScript.is_hybrid(row):
		lines.append("[color=%s]Overlap weapon: neutral on the weapon triangle.[/color]" % DIM)
	lines.append("")
	var u := selected_unit()
	if Equipment.can_wield(u, entry["weapon_id"]):
		var stats := _stats_of(u)
		lines.append("[color=%s]%s can wield this.[/color]  Attack speed with it: %d (spd %d)" % [GOOD, _name_of(u), CombatScript.attack_speed(stats, row), int(stats.get("spd", 0))])
	else:
		var have := Equipment.unit_arts(u)
		var missing: Array = []
		for art in req:
			if not have.has(art):
				missing.append(art)
		lines.append("[color=%s]%s can't wield this -- missing %s.[/color]" % [BAD, _name_of(u), " + ".join(missing)])
	var wielders: Array[String] = []
	for other in unit_ids:
		if Equipment.can_wield(other, entry["weapon_id"]):
			wielders.append(_name_of(other))
	if wielders.is_empty():
		lines.append("[color=%s]No one on the roster can wield this yet.[/color]" % GOLD)
	else:
		lines.append("[color=%s]Can be wielded by: %s.[/color]" % [DIM, ", ".join(wielders)])
	return "\n".join(lines)

func _stats_of(unit_id: String) -> Dictionary:
	var row = Canon.find_by("unit_base_stats", "unit_id", unit_id)
	return row if row != null else {}

# ---------------------------------------------------------------- actions

func _on_clicked(column: int, index: int) -> void:
	_column = column
	_set_index(column, index)
	if column == COLUMN_UNITS:
		_inv_index = 0
	_message = ""
	_refresh_all()

func move(delta: int) -> void:
	var n := _count(_column)
	if n == 0:
		return
	_set_index(_column, wrapi(_index_of(_column) + delta, 0, n))
	if _column == COLUMN_UNITS:
		_inv_index = 0
	_message = ""
	_refresh_all()

func switch_column(column: int) -> void:
	_column = clampi(column, COLUMN_UNITS, COLUMN_CONVOY)
	_message = ""
	_refresh_all()

## Enter: equip the highlighted inventory weapon, or take the highlighted convoy one.
func activate() -> void:
	var u := selected_unit()
	if _column == COLUMN_INVENTORY:
		var inv := selected_inventory()
		if _inv_index >= inv.size():
			return
		var entry: Dictionary = inv[_inv_index]
		if Equipment.equip(u, _inv_index):
			_inv_index = 0
			_message = "%s equips the %s." % [_name_of(u), Equipment.describe(entry)]
		else:
			_message = "%s can't equip the %s." % [_name_of(u), Equipment.weapon_name(entry["weapon_id"])]
	elif _column == COLUMN_CONVOY:
		_take_highlighted()
	_refresh_all()

## T / Space: inventory -> convoy, or convoy -> inventory.
func transfer() -> void:
	var u := selected_unit()
	if _column == COLUMN_INVENTORY:
		var inv := selected_inventory()
		if _inv_index < inv.size():
			var entry: Dictionary = inv[_inv_index]
			if Equipment.store(u, _inv_index):
				_message = "%s stores the %s in the convoy." % [_name_of(u), Equipment.describe(entry)]
	elif _column == COLUMN_CONVOY:
		_take_highlighted()
	_refresh_all()

func _take_highlighted() -> void:
	var u := selected_unit()
	if _convoy_index >= Equipment.convoy().size():
		return
	var entry: Dictionary = Equipment.convoy()[_convoy_index]
	if Equipment.take(u, _convoy_index):
		_message = "%s takes the %s." % [_name_of(u), Equipment.describe(entry)]
	else:
		_message = "%s is already carrying %d weapons." % [_name_of(u), Equipment.INVENTORY_SIZE]

func leave() -> void:
	get_tree().change_scene_to_file(OVERWORLD_SCENE)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	match (event as InputEventKey).keycode:
		KEY_UP: move(-1)
		KEY_DOWN: move(1)
		KEY_LEFT: switch_column(_column - 1)
		KEY_RIGHT: switch_column(_column + 1)
		KEY_ENTER, KEY_KP_ENTER: activate()
		KEY_T, KEY_SPACE: transfer()
		KEY_ESCAPE: leave()
		_: return
	get_viewport().set_input_as_handled()
