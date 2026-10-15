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

## Set by the overworld's O key just before it opens the forge screen: show the standard forges'
## requisitions instead of the master smith where the party stands. The screen clears it.
var orders_mode := false
const TIER_RANK := {"worn": 0, "basic": 1, "mid": 2, "high": 3, "legendary": 4, "mythic": 5}

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
			if is_standard(str(order["forge_id"])):
				lines.append("Your order of a %s is ready: press O on the overworld to collect it." % order_name(order))
				continue
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
	if str(order.get("mount_id", "")) != "":                 # a mount goes to the stable, not the convoy
		Mounts.add_to_stable(str(order["mount_id"]))
		GameState.forge_orders.remove_at(order_index)
		return {"ok": true, "reason": "", "weapon_id": "", "mount_id": order["mount_id"], "quality": order["quality"]}
	Equipment.convoy_add(order["weapon_id"], uses_for(order["weapon_id"], order["quality"]))
	GameState.forge_orders.remove_at(order_index)
	return {"ok": true, "reason": "", "weapon_id": order["weapon_id"], "quality": order["quality"]}

# ------------------------------------------------------- the standard forges
#
# Canon's frg_standard_a (the Diadem's forge orders) and frg_standard_b (the Assembly's): the ordinary
# spine sidequest, no master, no place on the map ("wherever your column currently is"). You order an
# ordinary weapon for gold; it is ready after one newly won chapter and collected into the convoy. How
# many orders may be open at once is your REQUISITION TIER, 1 to 3, which rises as the war does: tier 2
# once the Second Writ is won, tier 3 once the Reunion is (canon's "1/2/3 open orders at tier 1/2/3"). Silver
# weapons are for tier 3. A forge makes its house arts (forges.house_arts) for less. Orders live in
# GameState.forge_orders beside the master works, but are not master works (no cap, no material).

func standard_forges() -> Array:
	var out: Array = []
	for row in Canon.get_table("forges"):
		if row.get("tier") == "standard":
			out.append(row)
	return out

func is_standard(forge_id: String) -> bool:
	return forge_row(forge_id).get("tier") == "standard"

## 1, 2 or 3: the war's requisition tier, from the maps won.
func requisition_tier() -> int:
	var tier := 1
	for t in [2, 3]:
		var row = Canon.find_by("promotion_rules", "param_id", "prm_requisition_tier_%d" % t)
		if row != null and row.get("text") != null and GameState.won_maps.has(str(row["text"])):
			tier = t
	return tier

## How many standard orders may be open (ordered and not yet collected) at once.
func open_order_limit() -> int:
	return requisition_tier()

func open_standard_orders() -> int:
	var n := 0
	for o in GameState.forge_orders:
		if is_standard(str(o.get("forge_id", ""))):
			n += 1
	return n

## Which standard forge serves a place: the Assembly's where the chapters are the Assembly's route,
## the Diadem's anywhere else.
func standard_forge_for(location_id: String) -> String:
	for ch in Canon.get_table("chapters"):
		if ch.get("location_id") == location_id and ch.get("route") == "assembly":
			return "frg_standard_b"
	return "frg_standard_a"

## What a standard forge will make: [{weapon_id, name, art, tier, cost}], cheapest tier first. Basic and
## mid weapons always; silver only at requisition tier 3. One-art weapons only (no overlap weapons).
func catalogue(forge_id: String) -> Array:
	var out: Array = []
	var house := str(forge_row(forge_id).get("house_arts", "")).split("|", false)
	for w in Canon.get_table("weapons"):
		if not str(w.get("weapon_id", "")).begins_with("wpn_") or w.get("req_arts") != null:
			continue
		var tier := str(w.get("tier", ""))
		if not (tier in ["basic", "mid", "high"]) or w.get("effect") != null or (tier == "high" and requisition_tier() < 3):
			continue
		out.append({"weapon_id": w["weapon_id"], "name": w["name"], "art": w["art"], "tier": tier, "cost": order_cost(w, house)})
	out.sort_custom(func(a, b): return int(TIER_RANK[a["tier"]]) < int(TIER_RANK[b["tier"]]))
	return out

func order_cost(weapon: Dictionary, house_arts: Array) -> int:
	var cost := int(Progression.param("standard_cost_%s" % weapon.get("tier", "basic")))
	if house_arts.has(weapon.get("art")):
		cost = int(floor(cost * (100.0 - Progression.param("standard_house_discount_pct")) / 100.0))
	return cost

## Whether the company could order this weapon from this forge now: {"ok", "reason", "cost"}.
func can_order(forge_id: String, weapon_id: String) -> Dictionary:
	if not is_standard(forge_id):
		return {"ok": false, "reason": "that is not a standard forge", "cost": 0}
	var entry := {}
	for e in catalogue(forge_id):
		if e["weapon_id"] == weapon_id:
			entry = e
	if entry.is_empty():
		var w := Equipment.weapon_row(weapon_id)
		var why := "the forge does not make it"
		if w.get("tier") == "high" and requisition_tier() < 3:
			why = "silver weapons need requisition tier 3 (you are at tier %d)" % requisition_tier()
		return {"ok": false, "reason": why, "cost": 0}
	if open_standard_orders() >= open_order_limit():
		return {"ok": false, "reason": "your requisition tier (%d) allows %d open order%s" % [requisition_tier(), open_order_limit(), "" if open_order_limit() == 1 else "s"], "cost": entry["cost"]}
	if GameState.gold < int(entry["cost"]):
		return {"ok": false, "reason": "it costs %d gold (you have %d)" % [entry["cost"], GameState.gold], "cost": entry["cost"]}
	return {"ok": true, "reason": "", "cost": entry["cost"]}

## The name of what an order is for: a weapon, or a mount.
func order_name(order: Dictionary) -> String:
	if str(order.get("mount_id", "")) != "":
		return Mounts.name_of(str(order["mount_id"]))
	return Equipment.weapon_name(str(order.get("weapon_id", "")))

## The ordinary mount a standard forge will breed for gold: {"mount_id", "name", "cost"} or {} if none.
func mount_offer() -> Dictionary:
	for m in Mounts.rows():
		if m.get("kind") == "horse" and m.get("requisition_cost") != null:
			return {"mount_id": m["mount_id"], "name": m["name"], "cost": int(m["requisition_cost"])}
	return {}

func can_order_mount(forge_id: String) -> Dictionary:
	var offer := mount_offer()
	if not is_standard(forge_id) or offer.is_empty():
		return {"ok": false, "reason": "that forge has no mounts", "cost": 0}
	if open_standard_orders() >= open_order_limit():
		return {"ok": false, "reason": "your requisition tier (%d) allows %d open order%s" % [requisition_tier(), open_order_limit(), "" if open_order_limit() == 1 else "s"], "cost": offer["cost"]}
	if GameState.gold < int(offer["cost"]):
		return {"ok": false, "reason": "it costs %d gold (you have %d)" % [offer["cost"], GameState.gold], "cost": offer["cost"]}
	return {"ok": true, "reason": "", "cost": offer["cost"]}

func order_mount(forge_id: String) -> Dictionary:
	var check := can_order_mount(forge_id)
	if not check["ok"]:
		return check
	GameState.gold -= int(check["cost"])
	var o := {"forge_id": forge_id, "weapon_id": "", "mount_id": mount_offer()["mount_id"], "quality": "standard",
		"chapters_left": int(forge_row(forge_id).get("cycle_n", 1)), "ready": false}
	GameState.forge_orders.append(o)
	check["order"] = o
	return check

## Places an order: pays, and it is ready after the forge's cycle_n newly won chapters.
func order(forge_id: String, weapon_id: String) -> Dictionary:
	var check := can_order(forge_id, weapon_id)
	if not check["ok"]:
		return check
	GameState.gold -= int(check["cost"])
	var o := {"forge_id": forge_id, "weapon_id": weapon_id, "quality": "standard",
		"chapters_left": int(forge_row(forge_id).get("cycle_n", 1)), "ready": false}
	GameState.forge_orders.append(o)
	check["order"] = o
	return check

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
		"res_strike":
			return "Strikes at the foe's RES instead of its DEF: armor is no shelter."
		"renew":
			return "The wielder recovers %d HP with every blow that lands." % int(Progression.param("renew_heal"))
		"drain":
			return "Returns %d%% of the damage it deals to the wielder as health." % int(Progression.param("drain_pct"))
		"recoil":
			return "Costs the wielder %d HP each time they fight with it (never lethal)." % int(Progression.param("recoil_damage"))
	return ""

## How many hits unmake an enemy weapon of this tier: a worn one 1, a silver one 4.
func hits_to_unmake(weapon_tier: String) -> int:
	return int(TIER_RANK.get(weapon_tier, 1)) + 1
