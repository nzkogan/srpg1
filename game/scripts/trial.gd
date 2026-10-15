extends Control
## ch_h32 "The Kaisareia Trial" -- deliberately not a map_grid battle. endings.end_hierophant is explicit
## that the trial is processed by the same machine that names the deputy off the ledger, "not a special
## cutscene outside the system": the crown reads out the company's docket (mercies against kills), and
## the avatar -- or whoever holds the commission, the crown's deputy -- recommends the sentence.
##
## Controls: M = recommend mercy yourself, E = recommend execution yourself (each asks for a second
## press), Enter = let the commission recommend off its holder's own record (also asks for a second
## Enter), Escape = leave (undecided, or back to the overworld once the sentence is given).
## The sentence is final. Everything is read from and written to the Deputy autoload.

const OVERWORLD_SCENE := "res://scenes/overworld.tscn"
const BAD := "#ff6b6b"
const GOOD := "#5fd068"
const GOLD := "#e8c14a"
const DIM := "#8a8a92"

var _proposed := ""          # "mercy" / "execution" / "commission" awaiting its second press
var _message := ""

var _title: Label
var _detail: RichTextLabel
var _footer: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
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
	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(_detail)
	_footer = Label.new()
	_footer.add_theme_font_size_override("font_size", 12)
	page.add_child(_footer)
	_refresh()

func _scene_summary() -> String:
	for row in Canon.get_table("scenes"):
		if row.get("chapter_id") == "ch_h32":
			return String(row.get("summary", "")).split(" ADDENDUM")[0]
	return ""

func _name(uid: String) -> String:
	return "the avatar" if uid == "avatar" else Deputy._unit_name(uid)

func detail_text() -> String:
	var lines: Array[String] = []
	lines.append(_scene_summary())
	lines.append("")
	if Deputy.trial_done():
		var t: Dictionary = GameState.trial
		lines.append("[b]Sentence recommended: %s.[/b]" % t["verdict"])
		lines.append("%s recommended it." % ("The commission, off %s's own record" % Deputy._unit_name(t["by"]) if t.get("commission", false) else "The avatar, in person"))
		lines.append("The docket then: the company's %d mercies against %d kills." % [int(t["company_mercies"]), int(t["company_kills"])])
		lines.append("[color=%s]It is written, and it stands.[/color]" % DIM)
		return "\n".join(lines)
	var company := Deputy.company_docket()
	lines.append("[b]The docket[/b]")
	lines.append("The company: [color=%s]%d mercies[/color] (captures, talks, routs without killing) against [color=%s]%d kills[/color] in the crown's ledger." % [GOOD, int(company["mercies"]), BAD, int(company["kills"])])
	var holder := Deputy.trial_holder()
	if holder != "":
		var r := Deputy.commission_reading(holder)
		lines.append("")
		lines.append("[b]The commission is held by %s.[/b]" % Deputy._unit_name(holder))
		lines.append("Their own record: %d mercies (each worth %d kills) against %d kills. The commission would recommend [color=%s]%s[/color]." % [int(r["mercies"]), int(r["weight"]), int(r["kills"]), GOLD, r["verdict"]])
	else:
		lines.append("")
		lines.append("No deputy holds the commission: the sentence is the avatar's alone.")
	lines.append("")
	match _proposed:
		"mercy", "execution":
			lines.append("[color=%s]Press %s again to recommend %s yourself. It is final.[/color]" % [BAD, "M" if _proposed == "mercy" else "E", _proposed])
		"commission":
			lines.append("[color=%s]Press Enter again to let the commission recommend. It is final.[/color]" % BAD)
		_:
			lines.append("[color=%s]M mercy / E execution: you recommend, yourself (press twice).%s[/color]" % [DIM, " Enter: the commission recommends, off its holder's record (twice)." if holder != "" else ""])
	return "\n".join(lines)

## One press of a recommending key: the first proposes, the second (the same key) confirms.
## `which` is "mercy", "execution" or "commission". Returns true once the sentence is given.
func press(which: String) -> bool:
	if Deputy.trial_done():
		return false
	if which == "commission" and Deputy.trial_holder() == "":
		_message = "No deputy holds the commission."
		_refresh()
		return false
	if _proposed != which:
		_proposed = which
		_message = ""
		_refresh()
		return false
	var r: Dictionary
	if which == "commission":
		var holder := Deputy.trial_holder()
		r = Deputy.recommend(holder, Deputy.commission_reading(holder)["verdict"])
	else:
		r = Deputy.recommend("avatar", which)
	_proposed = ""
	_message = "The sentence is recommended." if r["ok"] else "Can't: %s." % r["reason"]
	_refresh()
	return r["ok"]

func _refresh() -> void:
	_title.text = "The Kaisareia Trial"
	_detail.text = detail_text()
	_footer.text = "%s\n%s" % [_message, "Esc return to the overworld" if Deputy.trial_done() else "M mercy   E execution   Enter the commission   Esc leave undecided"]

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	match (event as InputEventKey).keycode:
		KEY_M:
			press("mercy")
		KEY_E:
			press("execution")
		KEY_ENTER, KEY_KP_ENTER:
			press("commission")
		KEY_ESCAPE:
			SaveGame.autosave()
			get_tree().change_scene_to_file(OVERWORLD_SCENE)
		_:
			if _proposed != "":
				_proposed = ""
				_refresh()
