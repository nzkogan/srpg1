extends Node2D
## Sanity-check scene: proves the canon.db -> JSON -> Godot pipeline works
## by loading every table via the Canon autoload and printing row counts.

@onready var label: Label = $Label

func _ready() -> void:
	var lines: PackedStringArray = ["canon data loaded via Canon singleton:"]
	var table_names := Canon.tables.keys()
	table_names.sort()
	for t in table_names:
		lines.append("  %s: %d rows" % [t, Canon.get_table(t).size()])
	var avatar = Canon.find_by("units", "unit_id", "u_avatar")
	if avatar != null:
		lines.append("")
		lines.append("spot check -- u_avatar: %s" % avatar)
	label.text = "\n".join(lines)
	print(label.text)
