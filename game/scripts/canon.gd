extends Node
## Autoload singleton. Loads every table exported by export_canon_json.py
## from res://data/*.json into memory as Array[Dictionary], keyed by table
## name (the json filename minus extension). Regenerate the data with:
##   python build_sqlite.py && python export_canon_json.py

var tables: Dictionary = {}

func _ready() -> void:
	_load_all()

func _load_all() -> void:
	var dir := DirAccess.open("res://data")
	if dir == null:
		push_error("Canon: res://data not found -- run export_canon_json.py first")
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			var table_name := file_name.get_basename()
			tables[table_name] = _load_json("res://data/%s" % file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

func _load_json(path: String) -> Array:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Canon: failed to open %s" % path)
		return []
	var data = JSON.parse_string(f.get_as_text())
	if data == null:
		push_error("Canon: failed to parse %s" % path)
		return []
	return data

## Returns all rows for a table, e.g. Canon.get_table("units").
func get_table(table_name: String) -> Array:
	return tables.get(table_name, [])

## Returns the single row whose id_field matches id_value, or null.
## e.g. Canon.find_by("units", "unit_id", "u_avatar")
func find_by(table: String, id_field: String, id_value: String) -> Variant:
	for row in get_table(table):
		if row.get(id_field) == id_value:
			return row
	return null
