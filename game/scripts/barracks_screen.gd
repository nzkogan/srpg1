extends Control
## Barracks screen: levels, certification (promotion), recertification and
## abilities, between maps. Reads and writes the Progression autoload; owns no
## data.
##
## Four modes (Tab, or 1/2/3/4): Certify, Recertify, Abilities, Paragon (the
## second certification: requirements checklist, deeds, class menu). The left column
## is the roster, the middle column the options for the chosen mode, and the
## right pane explains the highlighted one -- what it costs, what it gives, and
## what waiting costs.
##
## Controls: Up/Down move in the active column, Left/Right switch column, Tab
## cycles the mode, Enter confirms (certify / recertify / toggle an ability),
## Escape returns to the overworld. The lists take the mouse too.

const OVERWORLD_SCENE := "res://scenes/overworld.tscn"
const MODE_CERTIFY := 0
const MODE_RECERTIFY := 1
const MODE_ABILITIES := 2
const MODE_PARAGON := 3
const MODE_NAMES := ["Certify", "Recertify", "Abilities", "Paragon"]
const COLUMN_UNITS := 0
const COLUMN_OPTIONS := 1
const INACTIVE_TINT := Color(1, 1, 1, 0.6)
const BAD := "#ff6b6b"
const GOOD := "#5fd068"
const GOLD := "#e8c14a"
const DIM := "#8a8a92"

var unit_ids: Array[String] = []
var _unit_names: Dictionary = {}
var _mode := MODE_CERTIFY
var _column := COLUMN_UNITS
var _unit_index := 0
var _option_index := 0
var _message := ""

var _title: Label
var _units_list: ItemList
var _options_list: ItemList
var _options_caption: Label
var _detail: RichTextLabel
var _footer: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# only units that have been fielded: a unit joins the squad (and gets caught
	# up to it) when first deployed, so looking here must not join anyone early
	for row in Canon.get_table("units"):
		_unit_names[row["unit_id"]] = row.get("name", row["unit_id"])
		if Progression.has_state(row["unit_id"]) and not Defections.is_gone(row["unit_id"]):
			unit_ids.append(row["unit_id"])
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
	_units_list = _make_list(body, "Roster", 235, false)
	_options_list = _make_list(body, "", 250, true)
	_units_list.item_selected.connect(func(i: int) -> void: _on_clicked(COLUMN_UNITS, i))
	_options_list.item_selected.connect(func(i: int) -> void: _on_clicked(COLUMN_OPTIONS, i))
	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_detail)
	_footer = Label.new()
	_footer.add_theme_font_size_override("font_size", 12)
	page.add_child(_footer)

func _make_list(parent: Node, caption: String, width: int, is_options: bool) -> ItemList:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(width, 0)
	parent.add_child(col)
	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", 12)
	col.add_child(label)
	if is_options:
		_options_caption = label
	var list := ItemList.new()
	list.focus_mode = Control.FOCUS_NONE
	list.select_mode = ItemList.SELECT_SINGLE
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(list)
	return list

# ----------------------------------------------------------------- state

func selected_unit() -> String:
	return unit_ids[_unit_index] if not unit_ids.is_empty() else ""

func _name_of(unit_id: String) -> String:
	return _unit_names.get(unit_id, unit_id)

## The rows in the middle column for the current mode and unit. Each is a
## dictionary with a "kind" ("class" or "ability"), display text, and the id.
func options() -> Array:
	var u := selected_unit()
	var out: Array = []
	if u == "":
		return out
	match _mode:
		MODE_CERTIFY:
			for o in Progression.promotion_options(u):
				out.append({"kind": "class", "id": o["class_id"], "data": o, "locked": o["locked"]})
		MODE_RECERTIFY:
			for o in Progression.recertify_options(u):
				out.append({"kind": "class", "id": o["class_id"], "data": o, "locked": o["locked"]})
		MODE_PARAGON:
			for o in Progression.paragon_options(u):
				out.append({"kind": "class", "id": o["class_id"], "data": o, "locked": o["locked"]})
		MODE_ABILITIES:
			var chosen: Array = Progression.chosen(u)
			for row in Progression.pool(u):
				out.append({"kind": "ability", "id": row["ability_id"], "data": row, "chosen": chosen.has(row["ability_id"]), "locked": false})
	return out

func _count(column: int) -> int:
	return unit_ids.size() if column == COLUMN_UNITS else options().size()

func unit_row_text(unit_id: String) -> String:
	var tag := ""
	if not Progression.is_promoted(unit_id):
		if Progression.level(unit_id) >= int(Progression.param("promote_min_level")) and not Progression.promotion_options(unit_id).is_empty():
			tag = "  *"
	elif not Progression.is_paragon(unit_id) and Progression.level(unit_id) >= int(Progression.param("paragon_min_level")) \
			and not Progression.paragon_options(unit_id).is_empty() and not Progression.gating_deeds_earned(unit_id).is_empty():
		tag = "  ^"
	return "%s   Lv %d   %s%s" % [_name_of(unit_id), Progression.level(unit_id), Progression.class_name_of(unit_id), tag]

func option_row_text(opt: Dictionary) -> String:
	if opt["kind"] == "ability":
		return "%s %s" % ["[x]" if opt["chosen"] else "[ ]", opt["data"]["name"]]
	var o: Dictionary = opt["data"]
	var text: String = o["name"]
	if o["locked"]:
		text += "   (locked)"
	return text

# --------------------------------------------------------------- display

func _refresh() -> void:
	var u := selected_unit()
	_title.text = "Barracks -- %s    Gold: %d    [%s]" % [_name_of(u) if u != "" else "(empty)", GameState.gold, MODE_NAMES[_mode]]
	_units_list.clear()
	for id in unit_ids:
		_units_list.add_item(unit_row_text(id))
	_options_caption.text = ["Certify into", "Switch to", "Abilities (%d / %d slots)" % [Progression.chosen(u).size(), Progression.slots(u)], "Paragon classes"][_mode]
	_options_list.clear()
	var opts := options()
	for i in opts.size():
		_options_list.add_item(option_row_text(opts[i]))
		if opts[i]["locked"]:
			_options_list.set_item_custom_fg_color(i, Color(BAD))
	_option_index = clampi(_option_index, 0, maxi(0, opts.size() - 1))
	if _units_list.item_count > 0:
		_units_list.select(_unit_index)
	if opts.size() > 0:
		_options_list.select(_option_index)
	_units_list.modulate = Color.WHITE if _column == COLUMN_UNITS else INACTIVE_TINT
	_options_list.modulate = Color.WHITE if _column == COLUMN_OPTIONS else INACTIVE_TINT
	_detail.text = detail_text()
	_footer.text = "%s\nUp/Down choose   Left/Right column   Tab or 1-4 mode   Enter confirm   Esc back   (* = ready to certify, ^ = ready for paragon)" % _message

func _stat_line(u: String) -> String:
	var stats := Progression.stats_for(u)
	var cells: Array[String] = []
	for s in Progression.STATS:
		cells.append("%s %d (%d%%)" % [s.to_upper(), stats[s], Progression.growth_rate(u, s)])
	return "   ".join(cells.slice(0, 4)) + "\n" + "   ".join(cells.slice(4))

## "HP 23 -> 27 (+4)   STR ..." comparing two stat dictionaries.
func _diff_line(now: Dictionary, after: Dictionary) -> String:
	var cells: Array[String] = []
	for s in Progression.STATS:
		var d := int(after[s]) - int(now[s])
		cells.append("%s %d -> %d (%s)" % [s.to_upper(), now[s], after[s], ("+%d" % d) if d >= 0 else str(d)])
	return "\n".join([", ".join(cells.slice(0, 4)), ", ".join(cells.slice(4))])

func detail_text() -> String:
	var u := selected_unit()
	if u == "":
		return "[color=%s]No one has been fielded yet. Units join the barracks the first time you deploy them.[/color]" % DIM
	var st := Progression.state(u)
	var lines: Array[String] = []
	lines.append("[b][font_size=20]%s[/font_size][/b]   Level %d   (%d / %d EXP)" % [_name_of(u), st["level"], st["exp"], int(Progression.param("exp_per_level"))])
	if Deputy.deputy() == u:
		lines.append("[color=%s]The crown's deputy.[/color]" % GOLD)
	lines.append("%s%s   Ability slots: %d" % [Progression.class_name_of(u), "  [color=%s](certified)[/color]" % GOOD if st["promoted"] else "", Progression.slots(u)])
	lines.append(_stat_line(u))
	lines.append("")
	var opts := options()
	var opt: Dictionary = opts[_option_index] if _option_index < opts.size() else {}
	match _mode:
		MODE_CERTIFY: lines.append_array(_certify_text(u, st, opt))
		MODE_RECERTIFY: lines.append_array(_recertify_text(u, st, opt))
		MODE_PARAGON: lines.append_array(_paragon_text(u, st, opt))
		_: lines.append_array(_ability_text(u, opt))
	return "\n".join(lines)

func _certify_text(u: String, st: Dictionary, opt: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var min_level := int(Progression.param("promote_min_level"))
	if st["promoted"]:
		lines.append("Already certified. (A further tier isn't built yet.)")
		return lines
	if Progression.promotion_options(u).is_empty():
		lines.append("Nothing to certify into.")
		return lines
	var fee := Progression.promotion_fee(int(st["level"]))
	if int(st["level"]) < min_level:
		lines.append("[color=%s]Certification opens at level %d (%d to go).[/color]" % [DIM, min_level, min_level - int(st["level"])])
		lines.append("It will cost %d gold at level %d, and %d more for every level after." % [Progression.promotion_fee(min_level), min_level, int(Progression.param("fee_per_level"))])
	else:
		var afford := GameState.gold >= fee
		lines.append("[color=%s]Certification costs %d gold now[/color] (you have %d). Every level you wait adds %d." % [GOOD if afford else BAD, fee, GameState.gold, int(Progression.param("fee_per_level"))])
		if not afford:
			lines.append("[color=%s]Short by %d gold.[/color]" % [BAD, fee - GameState.gold])
	if opt.is_empty():
		return lines
	var o: Dictionary = opt["data"]
	lines.append("")
	lines.append("[b]%s[/b] -- %s, %s movement" % [o["name"], o["tier"], o["movement"]])
	if o["locked"]:
		lines.append("[color=%s]Locked: %s.[/color]" % [BAD, o["reason"]])
	var after := Progression.preview_promotion(u, o["class_id"])
	if not after.is_empty():
		lines.append(_diff_line(Progression.stats_for(u), after))
	lines.append("Plus +%d to every growth rate from then on, an ability slot, and high-tier weapons." % int(Progression.param("growth_bonus")))
	var acts = Canon.find_by("classes", "class_id", o["class_id"]).get("map_actions")
	if acts != null and "shove" in String(acts).split("|", false) and "smite" not in String(acts).split("|", false):
		lines.append("[color=%s]Your Shove becomes Smite: it pushes %d tiles, not %d.[/color]" % [GOOD, int(Progression.param("smite_distance")), int(Progression.param("shove_distance"))])
	return lines

func _paragon_text(u: String, st: Dictionary, opt: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	if Progression.is_paragon(u):
		lines.append("[color=%s]Paragon (%s).[/color] Nothing further to take." % [GOLD, Progression.class_name_of(u)])
		_append_deeds(lines, u)
		return lines
	lines.append("[b]Requirements[/b]")
	for r in Progression.paragon_requirements(u):
		lines.append("[color=%s]%s %s[/color]  [color=%s](%s)[/color]" % [GOOD if r["ok"] else BAD, "[x]" if r["ok"] else "[ ]", r["label"], DIM, r["detail"]])
	lines.append("Waiting adds %d gold per level past %d. Deeds never expire." % [int(Progression.param("paragon_fee_per_level")), int(Progression.param("paragon_min_level"))])
	lines.append("")
	_append_deeds(lines, u)
	if Progression.paragon_options(u).is_empty():
		lines.append("")
		lines.append("[color=%s]%s[/color]" % [DIM, "Certify first." if not st["promoted"] else "No paragon class fits this unit's arts."])
		return lines
	if opt.is_empty():
		return lines
	var o: Dictionary = opt["data"]
	lines.append("")
	lines.append("[b]%s[/b] -- %s movement%s" % [o["name"], o["movement"], "  (milestone: keeps its class)" if o["class_id"] == Progression.class_id_of(u) else ""])
	if o["locked"]:
		lines.append("[color=%s]Locked: %s.[/color]" % [BAD, o["reason"]])
	var after := Progression.preview_paragon(u, o["class_id"])
	if not after.is_empty():
		lines.append(_diff_line(Progression.stats_for(u), after))
	lines.append("Plus +%d more to every growth rate, an ability slot, and the class's signature skill." % int(Progression.param("paragon_growth_bonus")))
	return lines

## The four deeds that gate paragon, earned ones ticked; untracked ones say so.
func _append_deeds(lines: Array[String], u: String) -> void:
	lines.append("[b]Deeds that gate paragon[/b]")
	for row in Progression.gating_epithets():
		var id: String = row["epithet_id"]
		var n := Progression.deed_count(u, id)
		var need := Progression.count_needed(id)
		var label := str(row["deed_category"]).replace("_", " ")
		if Progression.has_deed(u, id):
			lines.append("[color=%s][x] %s[/color]  [color=%s](%s) x%d[/color]" % [GOOD, label, DIM, row["trigger"], n])
		elif Progression.is_tracked(id):
			var progress := " -- %d of %d" % [n, need] if need > 1 else ""
			lines.append("[ ] %s  [color=%s](%s)%s[/color]" % [label, DIM, row["trigger"], progress])
		else:
			lines.append("[color=%s][ ] %s (%s) -- not recordable yet[/color]" % [DIM, label, row["trigger"]])
	var others := Progression.other_tracked_epithets()
	if not others.is_empty():
		lines.append("[b]Other deeds[/b] [color=%s](they don't gate paragon)[/color]" % DIM)
		for row in others:
			var oid: String = row["epithet_id"]
			var on := Progression.deed_count(u, oid)
			var oneed := Progression.count_needed(oid)
			var olabel := str(row["deed_category"]).replace("_", " ")
			if Progression.has_deed(u, oid):
				lines.append("[color=%s][x] %s[/color]  [color=%s](%s) x%d[/color]" % [GOOD, olabel, DIM, row["trigger"], on])
			else:
				lines.append("[ ] %s  [color=%s](%s)%s[/color]" % [olabel, DIM, row["trigger"], " -- %d of %d" % [on, oneed] if oneed > 1 else ""])

func _recertify_text(u: String, st: Dictionary, opt: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	if Progression.recertify_options(u).is_empty():
		lines.append("[color=%s]Only a certified unit in an order class can switch to another order class of its art.[/color]" % DIM)
		return lines
	var fee := Progression.recert_fee(int(st["level"]))
	lines.append("Switching costs %d gold (you have %d). Level and every stat earned are kept; only the class's flat shape changes." % [fee, GameState.gold])
	if opt.is_empty():
		return lines
	var o: Dictionary = opt["data"]
	lines.append("")
	lines.append("[b]%s[/b] -- %s movement" % [o["name"], o["movement"]])
	var cur := Progression.stats_for(u)
	var cls_now := Progression.class_row(u)
	var after := {}
	for s in Progression.STATS:
		after[s] = cur[s]
	var old_shape: Dictionary = Progression._shapes.get(String(cls_now.get("movement", "")), {})
	var new_shape: Dictionary = Progression._shapes.get(String(o["movement"]), {})
	for s in Progression.STATS:
		after[s] = int(cur[s]) - int(old_shape.get(s, 0)) + int(new_shape.get(s, 0))
	lines.append(_diff_line(cur, after))
	return lines

func _ability_text(u: String, opt: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var slots := Progression.slots(u)
	lines.append("Choose up to %d. New slots come every %d levels and on certification; picks are free to change any time." % [slots, int(Progression.param("slots_every"))])
	if opt.is_empty():
		return lines
	var row: Dictionary = opt["data"]
	lines.append("")
	lines.append("[b]%s[/b]%s" % [row["name"], "   [color=%s](chosen)[/color]" % GOOD if opt["chosen"] else ""])
	lines.append(Progression.describe_ability(row))
	if str(row.get("notes", "")) != "":
		lines.append("[color=%s]%s[/color]" % [DIM, row["notes"]])
	return lines

# ---------------------------------------------------------------- actions

func _on_clicked(column: int, index: int) -> void:
	_column = column
	if column == COLUMN_UNITS:
		_unit_index = clampi(index, 0, unit_ids.size() - 1)
		_option_index = 0
	else:
		_option_index = index
	_message = ""
	_refresh()

func move(delta: int) -> void:
	var n := _count(_column)
	if n == 0:
		return
	if _column == COLUMN_UNITS:
		_unit_index = wrapi(_unit_index + delta, 0, n)
		_option_index = 0
	else:
		_option_index = wrapi(_option_index + delta, 0, n)
	_message = ""
	_refresh()

func switch_column(column: int) -> void:
	_column = clampi(column, COLUMN_UNITS, COLUMN_OPTIONS)
	_message = ""
	_refresh()

func set_mode(mode: int) -> void:
	_mode = wrapi(mode, 0, MODE_NAMES.size())
	_option_index = 0
	_message = ""
	_refresh()

## Enter in the options column: certify, recertify, or toggle the ability.
func activate() -> void:
	if _column != COLUMN_OPTIONS:
		switch_column(COLUMN_OPTIONS)
		return
	var opts := options()
	if _option_index >= opts.size():
		return
	var opt: Dictionary = opts[_option_index]
	var u := selected_unit()
	match _mode:
		MODE_CERTIFY:
			var r := Progression.promote(u, opt["id"])
			_message = "%s certifies as %s for %d gold." % [_name_of(u), _a(opt["data"]["name"]), r["fee"]] if r["ok"] else "Can't certify: %s." % r["reason"]
		MODE_RECERTIFY:
			var r := Progression.recertify(u, opt["id"])
			_message = "%s switches to %s for %d gold." % [_name_of(u), opt["data"]["name"], r["fee"]] if r["ok"] else "Can't switch: %s." % r["reason"]
		MODE_PARAGON:
			var r := Progression.take_paragon(u, opt["id"])
			_message = "%s becomes %s for %d gold." % [_name_of(u), _a(opt["data"]["name"]), r["fee"]] if r["ok"] else "Can't take paragon: %s." % r["reason"]
		_:
			var now = Progression.toggle_ability(u, opt["id"])
			_message = "" if now != null else "No free slot -- remove an ability first."
	_option_index = clampi(_option_index, 0, maxi(0, options().size() - 1))
	_refresh()

## "a Warrior" / "an Axe knight".
func _a(noun: String) -> String:
	return "%s %s" % ["an" if noun.substr(0, 1).to_lower() in ["a", "e", "i", "o", "u"] else "a", noun]

func leave() -> void:
	SaveGame.autosave()
	get_tree().change_scene_to_file(OVERWORLD_SCENE)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	match (event as InputEventKey).keycode:
		KEY_UP: move(-1)
		KEY_DOWN: move(1)
		KEY_LEFT: switch_column(COLUMN_UNITS)
		KEY_RIGHT: switch_column(COLUMN_OPTIONS)
		KEY_TAB: set_mode(_mode + 1)
		KEY_1: set_mode(MODE_CERTIFY)
		KEY_2: set_mode(MODE_RECERTIFY)
		KEY_3: set_mode(MODE_ABILITIES)
		KEY_4: set_mode(MODE_PARAGON)
		KEY_ENTER, KEY_KP_ENTER: activate()
		KEY_ESCAPE: leave()
		_: return
	get_viewport().set_input_as_handled()
