extends Node2D
## ch_h32 "The Kaisareia Trial" -- deliberately not a map_grid battle.
## endings.end_hierophant is explicit this beat is processed through the
## same systemic machine as everything else, not a special cutscene, so
## this is the smallest thing that could represent that: read the scene's
## own summary out of Canon, present the choice, set canon_flags'
## flag_hierophant_verdict via GameState, and hand off to whichever
## chapter that verdict unlocks (see overworld.gd's gating).
##
## Controls: M = recommend mercy, E = recommend execution, Escape = leave
## without deciding (returns to the overworld, flag stays unset).

const FLAG_ID := "flag_hierophant_verdict"

var info_label: Label

func _ready() -> void:
	info_label = Label.new()
	info_label.position = Vector2(20, 20)
	info_label.custom_minimum_size = Vector2(560, 260)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(info_label)
	_update_label()

func _scene_summary() -> String:
	for row in Canon.get_table("scenes"):
		if row.get("chapter_id") == "ch_h32":
			return String(row.get("summary", ""))
	return ""

func _update_label() -> void:
	var verdict = GameState.get_flag(FLAG_ID)
	var lines: Array[String] = []
	lines.append("The Kaisareia Trial")
	lines.append("")
	var summary := _scene_summary()
	if summary != "":
		lines.append(summary)
		lines.append("")
	if verdict == null:
		lines.append("No sentence recommended yet.")
		lines.append("[M] recommend mercy -- [E] recommend execution -- [Escape] leave undecided")
	else:
		lines.append("Sentence recommended: %s." % verdict)
		lines.append("flag_hierophant_verdict = \"%s\" -- [Escape] return to the overworld" % verdict)
	info_label.text = "\n".join(lines)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	var key_event := event as InputEventKey
	if key_event.keycode == KEY_M:
		GameState.set_flag(FLAG_ID, "mercy")
		_update_label()
	elif key_event.keycode == KEY_E:
		GameState.set_flag(FLAG_ID, "execution")
		_update_label()
	elif key_event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://scenes/overworld.tscn")
