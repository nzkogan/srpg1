extends RefCounted
## Builds the combat forecast panel's BBCode from a forecast (Combat.forecast)
## plus names, weapons and HP. Pure and static so tests can read exactly what
## the player would see.
##
## Colour code, per column: GREEN where that side's weapon has the triangle
## advantage, RED where it is at a disadvantage, plain where neutral. Colour
## is never the only signal -- the weapon line also says "advantage" /
## "disadvantage", effectiveness is tagged EFF, and doubling is written "x2".
##
## info = {
##   "atk": {"name", "weapon", "hp", "max_hp"},
##   "def": {"name", "weapon", "hp", "max_hp"},
##   "forecast": Combat.forecast(...) result,
##   "support_text": optional one line about the attacker's support bonus,
##   "capture_text": optional one line about the Capture action (units that have it),
## }

const GREEN := "#5fd068"
const RED := "#ff6b6b"
const GOLD := "#e8c14a"
const DIM := "#8a8a92"

const VALUE_SIZE := 22

## Wraps text in the colour for a triangle result (+1 green, -1 red, 0 plain).
static func tint(text: String, triangle: int) -> String:
	if triangle > 0:
		return "[color=%s]%s[/color]" % [GREEN, text]
	if triangle < 0:
		return "[color=%s]%s[/color]" % [RED, text]
	return text

static func _big(text: String) -> String:
	return "[font_size=%d]%s[/font_size]" % [VALUE_SIZE, text]

## padding is (left, top, right, bottom): a gap on the right keeps a long word
## like "disadvantage" from running into the next column.
static func _cell(text: String) -> String:
	return "[cell padding=0,0,18,2]%s[/cell]" % text

static func triangle_word(triangle: int) -> String:
	if triangle > 0:
		return "advantage"
	if triangle < 0:
		return "disadvantage"
	return "neutral"

## One side's three number cells (damage / hit / crit), tinted by its triangle.
static func _side_cells(side: Dictionary) -> Array[String]:
	var tri := int(side["triangle"])
	var dmg := str(side["damage"])
	if int(side["hits"]) > 1:
		dmg += " x2"
	var out: Array[String] = []
	var dmg_text := _big(tint(dmg, tri))
	if side["effective"]:
		dmg_text += " [color=%s]EFF[/color]" % GOLD
	out.append(dmg_text)
	out.append(_big(tint("%d%%" % int(side["hit"]), tri)))
	out.append(_big(tint("%d%%" % int(side["crit"]), tri)))
	return out

static func bbcode(info: Dictionary) -> String:
	var fc: Dictionary = info["forecast"]
	var atk: Dictionary = info["atk"]
	var def: Dictionary = info["def"]
	var a: Dictionary = fc["atk"]
	var d: Dictionary = fc["def"]
	var counters := not d.is_empty()

	var lines: Array[String] = []
	lines.append("[b][font_size=20]%s  vs  %s[/font_size][/b]" % [atk["name"], def["name"]])
	lines.append("")
	lines.append("[table=3]")
	lines.append(_cell("") + _cell("[b]%s[/b]" % atk["name"]) + _cell("[b]%s[/b]" % def["name"]))
	lines.append(_cell("Weapon") + _cell(tint(str(atk["weapon"]), a["triangle"])) +
		_cell(tint(str(def["weapon"]), d["triangle"]) if counters else tint(str(def["weapon"]), -int(a["triangle"]))))
	lines.append(_cell("Triangle") + _cell(tint(triangle_word(a["triangle"]), a["triangle"])) +
		_cell(tint(triangle_word(d["triangle"]), d["triangle"]) if counters else
			tint(triangle_word(-int(a["triangle"])), -int(a["triangle"]))))
	if int(atk.get("level", -1)) >= 0 and int(def.get("level", -1)) >= 0:
		lines.append(_cell("Level") + _cell(str(atk["level"])) + _cell(str(def["level"])))
	lines.append(_cell("HP") + _cell("%d / %d" % [atk["hp"], atk["max_hp"]]) + _cell("%d / %d" % [def["hp"], def["max_hp"]]))
	var ac := _side_cells(a)
	if counters:
		var dc := _side_cells(d)
		lines.append(_cell("Damage") + _cell(ac[0]) + _cell(dc[0]))
		lines.append(_cell("Hit") + _cell(ac[1]) + _cell(dc[1]))
		lines.append(_cell("Crit") + _cell(ac[2]) + _cell(dc[2]))
		lines.append(_cell("Speed") + _cell(_big(str(a["speed"]))) + _cell(_big(str(d["speed"]))))
	else:
		var none := "[color=%s]--[/color]" % DIM
		lines.append(_cell("Damage") + _cell(ac[0]) + _cell(none))
		lines.append(_cell("Hit") + _cell(ac[1]) + _cell(none))
		lines.append(_cell("Crit") + _cell(ac[2]) + _cell(none))
		lines.append(_cell("Speed") + _cell(_big(str(a["speed"]))) + _cell(none))
	lines.append("[/table]")
	lines.append("")
	if not counters:
		lines.append("[color=%s]%s cannot counter from here.[/color]" % [DIM, def["name"]])
	if int(a["hits"]) > 1:
		lines.append("%s strikes twice (speed %d vs %d)." % [atk["name"], a["speed"], int(fc["def_speed"])])
	elif counters and int(d["hits"]) > 1:
		lines.append("[color=%s]%s strikes twice (speed %d vs %d).[/color]" % [RED, def["name"], d["speed"], a["speed"]])
	var uses := int(atk.get("uses", -1))
	if uses >= 0 and uses <= int(a["hits"]):
		lines.append("[color=%s]%s's weapon will break (%d use%s left).[/color]" % [GOLD, atk["name"], uses, "" if uses == 1 else "s"])
	if a["effective"]:
		lines.append("[color=%s]%s's weapon is effective here (x2 might).[/color]" % [GOLD, atk["name"]])
	if counters and d["effective"]:
		lines.append("[color=%s]%s's weapon is effective here (x2 might).[/color]" % [GOLD, def["name"]])
	if info.get("support_text", "") != "":
		lines.append("[color=%s]%s[/color]" % [GREEN, info["support_text"]])
	var capture_text := str(info.get("capture_text", ""))
	if capture_text != "":
		var ready := capture_text.begins_with("Capture ready")
		lines.append("[color=%s]%s%s[/color]" % [GREEN if ready else DIM, capture_text, "  (C)" if ready else ""])
	lines.append("")
	lines.append("[color=%s]Green: weapon advantage.[/color]" % DIM)
	lines.append("[color=%s]Red: weapon disadvantage.[/color]" % DIM)
	lines.append("[color=%s]Tab: next target.  F: attack.[/color]" % DIM)
	return "\n".join(lines)
