extends Node
## Autoload singleton: the master smiths, the beast materials and the legendary weapons
## (canon's forges and materials tabs). Register after Equipment and Progression.
##
## The loop: defeat a Named creature on its paralogue -- KILL it for a prime material, or
## CAPTURE it (a harvest) for a diminished one -- and the material is yours (one per Named
## per run). Take it to the master smith whose specialty fits (a fixed building on the
## overworld, with an access rule), commission the work (at most `master_works_cap` a run),
## win `cycle_n` more chapters, and collect the legendary weapon into the convoy. A
## diminished material makes a weapon with half the uses. Materials never expire, so banking
## them is legal. State lives in GameState (materials, materials_claimed, forge_orders,
## works_started); this autoload owns no data of its own.

const SCREEN_SCENE := "res://scenes/forge_screen.tscn"
const TIER_RANK := {"worn": 0, "basic": 1, "mid": 2, "high": 3, "legendary": 4}

# ------------------------------------------------------------------- canon

func forge_row(forge_id: String) -> Dictionary:
	var row = Canon.find_by("forges", "forge_id", forge_id)
	return row if row != null else {}

func material_row(material_id: String) -> Dictionary:
	var row = Canon.find_by("materials", "material_id", material_id)
	return row if row != null else {}

## The master smiths (not the abstract standard forges).
func master_forges() -> Array:
	var out: Array = []
	for row in Canon.get_table("forges"):
		if row.get("tier") == "master":
			out.append(row)
	return out

## The masters whose forge stands at an overworld location.
func forges_at(location_id: String) -> Array:
	var out: Array = []
	for row in master_forges():
		if row.get("location_id") == location_id:
			out.append(row)
	return out

## The material a Named stand-in yields ({} if none -- most enemies, and the Huma).
func material_for_enemy(enemy_id: String) -> Dictionary:
	for row in Canon.get_table("materials"):
		if row.get("enemy_id") == enemy_id:
			return row
	return {}

func works_cap() -> int:
	return int(Progression.param("master_works_cap"))

func works_left() -> int:
	return maxi(0, works_cap() - GameState.works_started)

## Whether the party may use this master right now: {"ok", "reason"}.
func access(forge_id: String) -> Dictionary:
	var rule := str(forge_row(forge_id).get("access_rule", ""))
	if rule == "always":
		return {"ok": true, "reason": ""}
	if rule.begins_with("won:"):
		var titles: Array[String] = []
		for map_id in rule.trim_prefix("won:").split("|", false):
			if GameState.won_maps.has(map_id):
				return {"ok": true, "reason": ""}
			var m = Canon.find_by("maps", "map_id", map_id)
			titles.append(str(m.get("title")) if m != null else map_id)
		return {"ok": false, "reason": "needs %s won first" % " or ".join(titles)}
	return {"ok": false, "reason": "this smith can't be reached"}

# --------------------------------------------------------------- materials

## The materials held right now: [{"material_id", "quality", "row"}].
func held() -> Array:
	var out: Array = []
	for mid in GameState.materials:
		out.append({"material_id": mid, "quality": GameState.materials[mid], "row": material_row(mid)})
	return out

## A Named stand-in has fallen: `how` is "killed" (a prime material) or "captured" (a
## diminished one). Returns the line to show ("" if it yields nothing, or already did).
func on_named_defeated(enemy_id: String, how: String) -> String:
	var mat := material_for_enemy(enemy_id)
	if mat.is_empty() or GameState.materials_claimed.has(mat["material_id"]):
		return ""
	var quality := "prime" if how == "killed" else "diminished"
	GameState.materials_claimed[mat["material_id"]] = true
	GameState.materials[mat["material_id"]] = quality
	var named = Canon.find_by("named", "named_id", mat.get("named_id", ""))
	var who: String = str(named.get("name")) if named != null else "the creature"
	who = who.substr(0, 1).to_upper() + who.substr(1)
	return "%s yields %s (%s)." % [who, mat.get("drop", "a material"), "a prime material" if quality == "prime" else "a diminished material, harvested"]

# ------------------------------------------------------------ commissions

## Whether `material_id` could be commissioned right now: {"ok", "reason"}.
func can_commission(material_id: String) -> Dictionary:
	if not GameState.materials.has(material_id):
		return {"ok": false, "reason": "you hold no such material"}
	var mat := material_row(material_id)
	var forge_id := str(mat.get("forge_id", ""))
	var acc := access(forge_id)
	if not acc["ok"]:
		return {"ok": false, "reason": "%s %s" % [forge_row(forge_id).get("name", "the smith"), acc["reason"]]}
	if works_left() <= 0:
		return {"ok": false, "reason": "all %d master works have been commissioned" % works_cap()}
	return {"ok": true, "reason": ""}

## Hands a held material to its smith. The work takes cycle_n newly won chapters.
func commission(material_id: String) -> Dictionary:
	var check := can_commission(material_id)
	if not check["ok"]:
		return check
	var mat := material_row(material_id)
	var forge_id: String = mat["forge_id"]
	var order := {"forge_id": forge_id, "material_id": material_id, "weapon_id": mat["weapon_id"],
		"quality": GameState.materials[material_id], "chapters_left": int(forge_row(forge_id).get("cycle_n", 2)), "ready": false}
	GameState.materials.erase(material_id)
	GameState.forge_orders.append(order)
	GameState.works_started += 1
	return {"ok": true, "reason": "", "order": order}

## A map was won. If it is a chapter not won before (`newly`), every unfinished commission
## moves a chapter closer; returns a line for each one that is finished.
func on_map_won(newly: bool) -> Array[String]:
	var lines: Array[String] = []
	if not newly:
		return lines
	for order in GameState.forge_orders:
		if order["ready"]:
			continue
		order["chapters_left"] = int(order["chapters_left"]) - 1
		if int(order["chapters_left"]) <= 0:
			order["ready"] = true
			lines.append("%s has finished the %s: collect it at %s." % [forge_row(order["forge_id"]).get("name", "the smith"),
				Equipment.weapon_name(order["weapon_id"]), forge_row(order["forge_id"]).get("name", "the forge")])
	return lines

func orders_for(forge_id: String) -> Array:
	var out: Array = []
	for i in GameState.forge_orders.size():
		if GameState.forge_orders[i]["forge_id"] == forge_id:
			out.append(i)
	return out

## The uses a finished weapon comes with: its full uses, or diminished_uses_pct of them.
func uses_for(weapon_id: String, quality: String) -> int:
	var uses := int(Equipment.weapon_row(weapon_id).get("uses", 1))
	if quality == "diminished":
		return maxi(1, int(ceil(uses * Progression.param("diminished_uses_pct") / 100.0)))
	return uses

## Takes a finished weapon (by its index in GameState.forge_orders) into the convoy.
func collect(order_index: int) -> Dictionary:
	if order_index < 0 or order_index >= GameState.forge_orders.size():
		return {"ok": false, "reason": "no such commission"}
	var order: Dictionary = GameState.forge_orders[order_index]
	if not order["ready"]:
		return {"ok": false, "reason": "not finished yet (%d chapter%s to go)" % [order["chapters_left"], "" if int(order["chapters_left"]) == 1 else "s"]}
	var acc := access(order["forge_id"])
	if not acc["ok"]:
		return {"ok": false, "reason": "the smith %s" % acc["reason"]}
	Equipment.convoy_add(order["weapon_id"], uses_for(order["weapon_id"], order["quality"]))
	GameState.forge_orders.remove_at(order_index)
	return {"ok": true, "reason": "", "weapon_id": order["weapon_id"], "quality": order["quality"]}

# ------------------------------------------------------------ weapon effects

## One line saying what a legendary weapon's special does ("" for an ordinary weapon).
func effect_text(weapon: Dictionary) -> String:
	match str(weapon.get("effect", "")):
		"heal_allies":
			return "Heals each ally beside the wielder for %d on a hit." % int(Progression.param("forge_heal"))
		"unmake":
			return "Each hit wears the foe's weapon down; a worn one goes at once, leaving it unarmed."
		"pull":
			return "Drags the foe it hits a tile closer, and cannot be turned off."
	return ""

## How many hits unmake an enemy weapon of this tier: a worn one 1, a silver one 4.
func hits_to_unmake(weapon_tier: String) -> int:
	return int(TIER_RANK.get(weapon_tier, 1)) + 1
