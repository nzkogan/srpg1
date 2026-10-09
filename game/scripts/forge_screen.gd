extends Control
## The master smith's forge, opened with F on the overworld where one works (the edged
## master at Kaisareia, the hafted master at Vashti, the missile master at Ostrova). Lists
## what can be done here -- commission a work from a beast material you hold, collect a
## finished weapon, or watch one in progress -- with the weapon and the smith's terms beside
## it. Everything is read from and written to the Forge autoload; this screen owns no data.
##
## Controls: Up/Down choose, Enter commissions or collects, Escape returns to the overworld.

const OVERWORLD_SCENE := "res://scenes/overworld.tscn"
const BAD := "#ff6b6b"
const GOOD := "#5fd068"
const GOLD := "#e8c14a"
const DIM := "#8a8a92"

var location_id := ""
var forge_rows: Array = []        # the masters at this place
var _rows: Array = []             # {kind: commission|collect|waiting|none, forge_id, ...}
var _index := 0
var _message := ""

var _title: Label
var _list: ItemList
var _detail: RichTextLabel
var _footer: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	location_id = GameState.world_location
	forge_rows = Forge.forges_at(location_id)
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
	_list.custom_minimum_size = Vector2(380, 0)
	_list.item_selected.connect(func(i: int) -> void:
		_index = i
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

# -------------------------------------------------------------------- data

## What can be selected here, in order: for each master at this place its collectable
## weapons, its commissionable materials, and its works in progress; or one "none" row.
func rows() -> Array:
	var out: Array = []
	for f in forge_rows:
		var fid: String = f["forge_id"]
		for i in Forge.orders_for(fid):
			var order: Dictionary = GameState.forge_orders[i]
			if order["ready"]:
				out.append({"kind": "collect", "forge_id": fid, "order_index": i})
		for h in Forge.held():
			if h["row"].get("forge_id") == fid:
				out.append({"kind": "commission", "forge_id": fid, "material_id": h["material_id"]})
		for i in Forge.orders_for(fid):
			if not GameState.forge_orders[i]["ready"]:
				out.append({"kind": "waiting", "forge_id": fid, "order_index": i})
		var convoy: Array = Equipment.convoy()
		for i in convoy.size():
			if Provenance.is_marked(convoy[i]) and Provenance.reforgeable_by(convoy[i], fid):
				out.append({"kind": "reforge", "forge_id": fid, "convoy_index": i})
	if out.is_empty():
		out.append({"kind": "none"})
	return out

func row_label(row: Dictionary) -> String:
	match row["kind"]:
		"collect":
			var o: Dictionary = GameState.forge_orders[row["order_index"]]
			return "Collect: %s (%s)" % [Equipment.weapon_name(o["weapon_id"]), o["quality"]]
		"commission":
			var m := Forge.material_row(row["material_id"])
			return "Commission from %s (%s)" % [m.get("drop", "a material"), GameState.materials[row["material_id"]]]
		"waiting":
			var o2: Dictionary = GameState.forge_orders[row["order_index"]]
			return "In the forge: %s -- %d chapter%s to go" % [Equipment.weapon_name(o2["weapon_id"]), o2["chapters_left"], "" if int(o2["chapters_left"]) == 1 else "s"]
		"reforge":
			return "Reforge: %s" % Provenance.name_of(Equipment.convoy()[row["convoy_index"]])
	return "Nothing to do here yet"

func _weapon_lines(weapon_id: String, quality: String) -> Array[String]:
	var w := Equipment.weapon_row(weapon_id)
	var lines: Array[String] = []
	lines.append("[b]%s[/b]  (%s, legendary)" % [w.get("name", weapon_id), w.get("art", "?")])
	lines.append("Might %d   Hit %d   Crit %d   Weight %d   Range %d%s   Uses %d" % [int(w.get("might", 0)), int(w.get("hit", 0)), int(w.get("crit", 0)),
		int(w.get("weight", 0)), int(w.get("range_min", 1)), "" if int(w.get("range_max", 1)) == int(w.get("range_min", 1)) else "-%d" % int(w.get("range_max", 1)),
		Forge.uses_for(weapon_id, quality)])
	if w.get("effective_vs") != null:
		lines.append("[color=%s]Effective against %s (might x2).[/color]" % [GOLD, w["effective_vs"]])
	var fx := Forge.effect_text(w)
	if fx != "":
		lines.append("[color=%s]%s[/color]" % [GOLD, fx])
	if quality == "diminished":
		lines.append("[color=%s]A harvested material: half the uses.[/color]" % DIM)
	lines.append("[color=%s]Needs a certified class to wield.[/color]" % DIM)
	return lines

func detail_text(row: Dictionary) -> String:
	var lines: Array[String] = []
	if row["kind"] == "none":
		if forge_rows.is_empty():
			lines.append("No master smith works here. The masters are fixed buildings: the edged master at Kaisareia, the hafted master at Vashti gate, the missile master at Ostrova.")
		else:
			lines.append("[b]%s[/b]" % ", ".join(forge_rows.map(func(f): return f["name"])))
			lines.append("You have nothing for this smith yet. A master works from the remains of a Named creature: defeat one on its paralogue -- kill it for a prime material, or capture it for a diminished one.")
		lines.append("")
		lines.append_array(_status_lines())
		return "\n".join(lines)
	var f := Forge.forge_row(row["forge_id"])
	lines.append("[b][font_size=18]%s[/font_size][/b]  [color=%s]%s -- %s[/color]" % [f["name"], DIM, f.get("specialty", ""), f.get("smith_notes", "")])
	var acc := Forge.access(row["forge_id"])
	lines.append("[color=%s]%s[/color]" % [GOOD if acc["ok"] else BAD, "Open to you." if acc["ok"] else "Closed: " + acc["reason"] + "."])
	lines.append("")
	match row["kind"]:
		"commission":
			var m := Forge.material_row(row["material_id"])
			var q: String = GameState.materials[row["material_id"]]
			lines.append("%s -- [i]%s[/i], a %s material." % [m.get("drop", ""), m.get("resulting_weapon", ""), q])
			lines.append("")
			lines.append_array(_weapon_lines(m["weapon_id"], q))
			lines.append("")
			var check := Forge.can_commission(row["material_id"])
			lines.append("[color=%s]%s[/color]" % [GOOD if check["ok"] else BAD,
				"Enter commissions it. It takes %d chapters." % int(f.get("cycle_n", 2)) if check["ok"] else "Can't commission: %s." % check["reason"]])
		"collect":
			var o: Dictionary = GameState.forge_orders[row["order_index"]]
			lines.append_array(_weapon_lines(o["weapon_id"], o["quality"]))
			lines.append("")
			lines.append("[color=%s]Finished. Enter takes it into the convoy.[/color]" % GOOD)
		"reforge":
			var entry: Dictionary = Equipment.convoy()[row["convoy_index"]]
			lines.append("[b]%s[/b]  (%s)" % [Provenance.name_of(entry), Equipment.weapon_row(entry["weapon_id"]).get("art", "?")])
			lines.append("Marks: %s." % "; ".join(Provenance.history(entry)))
			lines.append("")
			var rc := Provenance.can_reforge(row["convoy_index"], row["forge_id"])
			lines.append("[color=%s]%s[/color]" % [GOOD if rc["ok"] else BAD,
				"Enter reforges it for %d gold. The marks are wiped; it goes back to being a plain %s." % [rc["fee"], Equipment.weapon_name(entry["weapon_id"])] if rc["ok"] else "Can't reforge: %s." % rc["reason"]])
		"waiting":
			var o2: Dictionary = GameState.forge_orders[row["order_index"]]
			lines.append_array(_weapon_lines(o2["weapon_id"], o2["quality"]))
			lines.append("")
			lines.append("[color=%s]%d more newly won chapter%s and it is done.[/color]" % [DIM, o2["chapters_left"], "" if int(o2["chapters_left"]) == 1 else "s"])
	lines.append("")
	lines.append_array(_status_lines())
	return "\n".join(lines)

func _status_lines() -> Array[String]:
	var lines: Array[String] = ["[color=%s]Master works commissioned: %d of %d.[/color]" % [DIM, GameState.works_started, Forge.works_cap()]]
	var held := Forge.held()
	if held.is_empty():
		lines.append("[color=%s]Materials held: none.[/color]" % DIM)
	else:
		var names: Array[String] = []
		for h in held:
			names.append("%s (%s)" % [h["row"].get("drop", h["material_id"]), h["quality"]])
		lines.append("[color=%s]Materials held: %s.[/color]" % [DIM, ", ".join(names)])
	return lines

## Enter: commission or collect the highlighted row. Returns false if it did nothing.
func activate() -> bool:
	var all := rows()
	if _index >= all.size():
		return false
	var row: Dictionary = all[_index]
	match row["kind"]:
		"commission":
			var r := Forge.commission(row["material_id"])
			_message = "The smith takes the work: %s in %d chapters." % [Equipment.weapon_name(r["order"]["weapon_id"]), r["order"]["chapters_left"]] if r["ok"] else "Can't: %s." % r["reason"]
			_refresh()
			return r["ok"]
		"collect":
			var c := Forge.collect(row["order_index"])
			_message = "The %s is yours (added to the convoy)." % Equipment.weapon_name(c["weapon_id"]) if c["ok"] else "Can't: %s." % c["reason"]
			_refresh()
			return c["ok"]
		"reforge":
			var rf := Provenance.reforge(row["convoy_index"], row["forge_id"])
			_message = "The smith strips %s back to the steel (%d gold)." % [rf["was"], rf["fee"]] if rf["ok"] else "Can't: %s." % rf["reason"]
			_refresh()
			return rf["ok"]
	return false

# ----------------------------------------------------------------- display

func _refresh() -> void:
	var all := rows()
	_index = clampi(_index, 0, all.size() - 1)
	_title.text = "The forge -- %s" % (", ".join(forge_rows.map(func(f): return f["name"])) if not forge_rows.is_empty() else "no master smith here")
	_list.clear()
	for row in all:
		_list.add_item(row_label(row))
	if _list.item_count > 0:
		_list.select(_index)
	_refresh_detail()
	_footer.text = "%s\nUp/Down choose   Enter commission, collect or reforge   Esc back" % _message

func _refresh_detail() -> void:
	var all := rows()
	_detail.text = detail_text(all[clampi(_index, 0, all.size() - 1)])

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	match (event as InputEventKey).keycode:
		KEY_ESCAPE:
			SaveGame.autosave()
			get_tree().change_scene_to_file(OVERWORLD_SCENE)
		KEY_UP:
			_index = maxi(0, _index - 1)
			_message = ""
			_refresh()
		KEY_DOWN:
			_index = mini(rows().size() - 1, _index + 1)
			_message = ""
			_refresh()
		KEY_ENTER, KEY_KP_ENTER:
			activate()
