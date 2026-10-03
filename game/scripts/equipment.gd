extends Node
## Autoload singleton: what each player unit carries and what the shared convoy
## holds. Static weapon data comes from Canon ("weapons", "units", "classes");
## per-playthrough state lives in GameState (inventories, convoy,
## drops_claimed). Register after Canon and GameState in project.godot.
##
## Rules (a design proposal -- canon only supplies the numbers):
##   - Every unit starts with the basic weapon of their class's primary art.
##   - A unit may only equip a weapon if they are proficient in every art it
##     requires (Combat.can_wield), so a halberd needs axe AND lance.
##   - The equipped weapon is the first wieldable entry in the unit's
##     inventory (at most INVENTORY_SIZE entries). Swapping is free on a map,
##     between maps in the convoy screen.
##   - Each strike a unit makes (attack, counter, follow-up) spends one use; at
##     0 the weapon breaks and is gone -- no repair (map_f00's design note) --
##     and the next wieldable weapon, if any, becomes equipped.
##   - The convoy starts with weapons.convoy_qty of each weapon and gains
##     encounter_spawns.drop_weapon_id from defeated enemies, once per spawn.

const CombatScript := preload("res://scripts/combat.gd")
const ARTS := ["sword", "lance", "axe", "bow", "brawl", "reason", "faith"]
const INVENTORY_SIZE := 5

## The between-maps screen for managing all of this (opened with C on the overworld).
const SCREEN_SCENE := "res://scenes/convoy_screen.tscn"

var _weapons: Dictionary = {}   # weapon_id -> weapons row
var _indexed := false

func _ready() -> void:
	_index()

func _index() -> void:
	if _indexed:
		return
	for row in Canon.get_table("weapons"):
		_weapons[row["weapon_id"]] = row
	_indexed = true

# ------------------------------------------------------------------ lookups

func weapon_row(weapon_id: String) -> Dictionary:
	_index()
	return _weapons.get(weapon_id, {})

func weapon_name(weapon_id: String) -> String:
	return weapon_row(weapon_id).get("name", weapon_id)

## "Iron Sword (45)".
func describe(entry: Dictionary) -> String:
	return "%s (%d)" % [weapon_name(entry["weapon_id"]), entry["uses"]]

## The arts a unit is proficient in: their class's primary and secondary art
## (the secondary column holds a movement type for order-tier classes, which
## is not an art and is ignored).
func unit_arts(unit_id: String) -> Array:
	var unit = Canon.find_by("units", "unit_id", unit_id)
	if unit == null:
		return []
	var cls = Canon.find_by("classes", "class_id", unit.get("base_class_id", ""))
	if cls == null:
		return []
	var arts: Array = []
	for key in ["art_primary", "art_secondary"]:
		if ARTS.has(cls.get(key)):
			arts.append(cls[key])
	return arts

func can_wield(unit_id: String, weapon_id: String) -> bool:
	var row := weapon_row(weapon_id)
	return not row.is_empty() and CombatScript.can_wield(unit_arts(unit_id), row)

## Seeds the convoy from canon the first time anything asks.
func ensure_ready() -> void:
	if GameState.equipment_ready:
		return
	GameState.equipment_ready = true
	for row in Canon.get_table("weapons"):
		for i in int(row.get("convoy_qty") if row.get("convoy_qty") != null else 0):
			GameState.convoy.append(_new_entry(row["weapon_id"]))

func _new_entry(weapon_id: String) -> Dictionary:
	return {"weapon_id": weapon_id, "uses": int(weapon_row(weapon_id).get("uses", 1))}

# --------------------------------------------------------------- inventories

## A unit's inventory array (live, not a copy). The first time a unit is seen
## it is given the basic weapon of its primary art, if it has one it can wield.
func inventory(unit_id: String) -> Array:
	ensure_ready()
	if not GameState.inventories.has(unit_id):
		var inv: Array = []
		var unit = Canon.find_by("units", "unit_id", unit_id)
		var cls = Canon.find_by("classes", "class_id", unit.get("base_class_id", "")) if unit != null else null
		if cls != null and ARTS.has(cls.get("art_primary")):
			var wid := "wpn_%s_basic" % cls["art_primary"]
			if can_wield(unit_id, wid):
				inv.append(_new_entry(wid))
		GameState.inventories[unit_id] = inv
	return GameState.inventories[unit_id]

## Index of the equipped weapon in the inventory, or -1 if nothing wieldable.
func equipped_index(unit_id: String) -> int:
	var inv := inventory(unit_id)
	for i in inv.size():
		if inv[i]["uses"] > 0 and can_wield(unit_id, inv[i]["weapon_id"]):
			return i
	return -1

## The equipped entry {"weapon_id", "uses"}, or {} if the unit has nothing it can wield.
func equipped(unit_id: String) -> Dictionary:
	var i := equipped_index(unit_id)
	return inventory(unit_id)[i] if i >= 0 else {}

## Makes inventory[index] the equipped weapon (moves it to the front). False if
## the index is bad or the unit can't wield it.
func equip(unit_id: String, index: int) -> bool:
	var inv := inventory(unit_id)
	if index < 0 or index >= inv.size() or not can_wield(unit_id, inv[index]["weapon_id"]):
		return false
	var entry: Dictionary = inv[index]
	inv.remove_at(index)
	inv.insert(0, entry)
	return true

## Free action: rotate through the weapons this unit can wield. Returns the
## newly equipped entry, or {} if there is nothing to switch to.
func cycle(unit_id: String) -> Dictionary:
	var inv := inventory(unit_id)
	var slots: Array[int] = []
	for i in inv.size():
		if inv[i]["uses"] > 0 and can_wield(unit_id, inv[i]["weapon_id"]):
			slots.append(i)
	if slots.size() < 2:
		return {}
	var order: Array = []
	for i in slots:
		order.append(inv[i])
	order.append(order.pop_front())      # [w1, w2, w3] -> [w2, w3, w1], back into the same slots
	for k in slots.size():
		inv[slots[k]] = order[k]
	return equipped(unit_id)

## Spends `count` uses of the equipped weapon. If it reaches 0 the weapon
## breaks and is removed. Returns {} normally, or {"broke": true, "weapon_id",
## "name"} when it broke.
func spend_use(unit_id: String, count: int = 1) -> Dictionary:
	var i := equipped_index(unit_id)
	if i < 0 or count <= 0:
		return {}
	var inv := inventory(unit_id)
	inv[i]["uses"] = maxi(0, int(inv[i]["uses"]) - count)
	if inv[i]["uses"] > 0:
		return {}
	var wid: String = inv[i]["weapon_id"]
	inv.remove_at(i)
	return {"broke": true, "weapon_id": wid, "name": weapon_name(wid)}

# -------------------------------------------------------------------- convoy

func convoy() -> Array:
	ensure_ready()
	return GameState.convoy

func convoy_add(weapon_id: String, uses: int = -1) -> void:
	ensure_ready()
	var entry := _new_entry(weapon_id)
	if uses >= 0:
		entry["uses"] = uses
	GameState.convoy.append(entry)

## Moves convoy[index] into a unit's inventory. False if the inventory is full
## or the index is bad. (Anyone may carry a weapon they can't wield.)
func take(unit_id: String, index: int) -> bool:
	var inv := inventory(unit_id)
	if index < 0 or index >= GameState.convoy.size() or inv.size() >= INVENTORY_SIZE:
		return false
	inv.append(GameState.convoy[index])
	GameState.convoy.remove_at(index)
	return true

## Moves inventory[index] back to the convoy.
func store(unit_id: String, index: int) -> bool:
	var inv := inventory(unit_id)
	if index < 0 or index >= inv.size():
		return false
	GameState.convoy.append(inv[index])
	inv.remove_at(index)
	return true

## A defeated enemy's drop: into the convoy, once per spawn_id per playthrough.
## Returns the weapon's name if it was added, "" if there was none or it was
## already taken.
func claim_drop(spawn_id: String, weapon_id) -> String:
	if weapon_id == null or str(weapon_id) == "" or spawn_id == "" or GameState.drops_claimed.has(spawn_id):
		return ""
	if weapon_row(str(weapon_id)).is_empty():
		return ""
	GameState.drops_claimed[spawn_id] = true
	convoy_add(str(weapon_id))
	return weapon_name(str(weapon_id))
