extends SceneTree
## Headless checks for the Equipment autoload: loadouts, proficiency, equipping,
## cycling, durability, the convoy and drops.
## Run from the repo root:
##   godot --headless --path game --script res://tests/test_equipment.gd
## Exits 0 if every check passes, 1 otherwise.

var _failures: int = 0
var _checks: int = 0
var _eq: Node
var _gs: Node

func check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: ", label)

func _initialize() -> void:
	_eq = root.get_node("Equipment")
	_gs = root.get_node("GameState")
	await process_frame
	_reset()
	_data_and_loadouts()
	_reset()
	_equip_and_cycle()
	_reset()
	_durability()
	_reset()
	_convoy_and_drops()
	_reset()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)

func _reset() -> void:
	_gs.inventories.clear()
	_gs.convoy.clear()
	_gs.equipment_ready = false
	_gs.drops_claimed.clear()

func _data_and_loadouts() -> void:
	check(_eq.unit_arts("u_jost") == ["axe"], "Jost is proficient in axe")
	check(_eq.unit_arts("u_torvald") == ["axe"], "an order class's movement-type column is not an art (Torvald: axe only)")
	check(_eq.unit_arts("u_edda").is_empty(), "Edda has no arts")
	check(_eq.unit_arts("u_nobody").is_empty(), "unknown unit: none")
	var inv: Array = _eq.inventory("u_jost")
	check(inv.size() == 1 and inv[0]["weapon_id"] == "wpn_axe_basic" and inv[0]["uses"] == 45, "Jost starts with a basic axe, 45 uses")
	check(_eq.equipped("u_jost")["weapon_id"] == "wpn_axe_basic", "...and it is equipped")
	check(_eq.inventory("u_edda").is_empty() and _eq.equipped("u_edda").is_empty(), "the unarmed start with nothing and have nothing equipped")
	check(_eq.inventory("u_dietmar")[0]["weapon_id"] == "wpn_lance_basic", "Dietmar (paladin) starts with a lance")
	check(_eq.inventory("u_jost") == _gs.inventories["u_jost"], "inventory() is the live array, not a copy")
	# the convoy is seeded from canon exactly once
	var c: Array = _eq.convoy()
	check(c.size() == 7, "the convoy starts with 7 weapons (got %d)" % c.size())
	var ids := {}
	for e in c:
		ids[e["weapon_id"]] = true
	check(ids.has("wpn_sword_mid") and ids.has("wpn_faith_mid") and not ids.has("wpn_halberd"), "one mid-tier weapon per art; no halberd yet")
	_eq.ensure_ready(); _eq.ensure_ready()
	check(_eq.convoy().size() == 7, "seeding twice doesn't duplicate")
	check(_eq.convoy()[0]["uses"] == 30, "convoy entries carry the weapon's own uses (mid = 30)")

func _equip_and_cycle() -> void:
	_eq.ensure_ready()
	# give Jost (axe) a steel axe and a steel sword he can't use
	var steel_axe := -1
	var steel_sword := -1
	var c: Array = _eq.convoy()
	for i in c.size():
		if c[i]["weapon_id"] == "wpn_axe_mid": steel_axe = i
	check(_eq.take("u_jost", steel_axe), "take: convoy -> inventory")
	for i in _eq.convoy().size():
		if _eq.convoy()[i]["weapon_id"] == "wpn_sword_mid": steel_sword = i
	check(_eq.take("u_jost", steel_sword), "anyone may carry a weapon they can't wield")
	var inv: Array = _eq.inventory("u_jost")
	check(inv.size() == 3 and inv[0]["weapon_id"] == "wpn_axe_basic", "inventory: basic axe, steel axe, steel sword")
	check(_eq.equipped("u_jost")["weapon_id"] == "wpn_axe_basic", "the first wieldable is equipped")
	check(not _eq.equip("u_jost", 2), "equip refuses a sword for an axe user")
	check(_eq.equip("u_jost", 1) and _eq.equipped("u_jost")["weapon_id"] == "wpn_axe_mid" and inv[0]["weapon_id"] == "wpn_axe_mid", "equip(1) moves the steel axe to the front")
	check(not _eq.equip("u_jost", 9) and not _eq.equip("u_jost", -1), "bad indexes refused")
	# an unwieldable weapon at the front is skipped, not equipped
	var sw: Dictionary = inv.pop_at(2); inv.push_front(sw)
	check(_eq.equipped("u_jost")["weapon_id"] == "wpn_axe_mid", "an unwieldable weapon in front is skipped over")
	# cycling rotates through wieldable weapons only
	var first: String = _eq.equipped("u_jost")["weapon_id"]
	var now: Dictionary = _eq.cycle("u_jost")
	check(now["weapon_id"] != first, "cycle switches weapons")
	var again: Dictionary = _eq.cycle("u_jost")
	check(again["weapon_id"] == first, "two wieldable weapons: cycling twice returns")
	check(_eq.inventory("u_jost").size() == 3, "cycling loses nothing")
	check(_eq.cycle("u_edda").is_empty() and _eq.cycle("u_ricberta").is_empty(), "nothing to cycle to with 0 or 1 weapons")
	# the overlap weapon: needs axe AND lance
	_eq.convoy_add("wpn_halberd")
	var hal: int = _eq.convoy().size() - 1
	check(_eq.take("u_jost", hal), "Jost can carry a halberd")
	check(not _eq.can_wield("u_jost", "wpn_halberd") and not _eq.can_wield("u_dietmar", "wpn_halberd") and not _eq.can_wield("u_torvald", "wpn_halberd"),
		"...but no one on the roster can wield it (axe alone, lance alone)")
	var jost_inv: Array = _eq.inventory("u_jost")
	check(not _eq.equip("u_jost", jost_inv.size() - 1), "equip refuses the halberd")
	# inventory cap
	for i in 5:
		_eq.convoy_add("wpn_axe_basic")
	var taken := 0
	for i in 5:
		if _eq.take("u_jost", 0): taken += 1
	check(_eq.inventory("u_jost").size() == _eq.INVENTORY_SIZE, "an inventory holds at most %d" % _eq.INVENTORY_SIZE)
	check(not _eq.take("u_jost", 0), "a full inventory refuses another")
	# store
	var before: int = _eq.convoy().size()
	check(_eq.store("u_jost", 0) and _eq.convoy().size() == before + 1 and _eq.inventory("u_jost").size() == _eq.INVENTORY_SIZE - 1, "store returns an entry to the convoy")
	check(not _eq.store("u_jost", 99), "bad store index refused")

func _durability() -> void:
	var inv: Array = _eq.inventory("u_jost")
	_eq.convoy_add("wpn_axe_mid", 3)
	check(_eq.take("u_jost", _eq.convoy().size() - 1), "(a 3-use steel axe for Jost)")
	check(_eq.equip("u_jost", 1), "(equip it)")
	check(_eq.spend_use("u_jost", 1).is_empty() and _eq.equipped("u_jost")["uses"] == 2, "spending 1 use leaves 2")
	check(_eq.spend_use("u_jost", 0).is_empty() and _eq.equipped("u_jost")["uses"] == 2, "spending 0 does nothing")
	var r: Dictionary = _eq.spend_use("u_jost", 2)
	check(r.get("broke") == true and r["weapon_id"] == "wpn_axe_mid" and r["name"] == "Steel Axe", "using the last use breaks it, and says which weapon")
	check(_eq.inventory("u_jost").size() == 1 and _eq.equipped("u_jost")["weapon_id"] == "wpn_axe_basic", "a broken weapon is gone and the next wieldable is equipped")
	# spending more than is left still just breaks it
	_eq.convoy_add("wpn_axe_mid", 1)
	_eq.take("u_jost", _eq.convoy().size() - 1); _eq.equip("u_jost", 1)
	check(_eq.spend_use("u_jost", 5).get("broke") == true and _eq.inventory("u_jost").size() == 1, "overspending breaks it and no further")
	# the last weapon breaking leaves the unit unarmed
	_eq.inventory("u_jost")[0]["uses"] = 1
	check(_eq.spend_use("u_jost", 1).get("broke") == true and _eq.equipped("u_jost").is_empty() and _eq.inventory("u_jost").is_empty(), "the last weapon breaking leaves the unit unarmed")
	check(_eq.spend_use("u_jost", 1).is_empty(), "spending with nothing equipped is a no-op")
	check(_eq.spend_use("u_edda", 1).is_empty(), "so is spending for the unarmed")
	# a 0-use entry is never 'equipped'
	_eq.inventory("u_ricberta")[0]["uses"] = 0
	check(_eq.equipped("u_ricberta").is_empty(), "a weapon at 0 uses isn't equipped")

func _convoy_and_drops() -> void:
	_eq.ensure_ready()
	var n: int = _eq.convoy().size()
	check(_eq.claim_drop("spn_test", "wpn_halberd") == "Halberd" and _eq.convoy().size() == n + 1, "a drop adds the weapon to the convoy and returns its name")
	check(_eq.claim_drop("spn_test", "wpn_halberd") == "" and _eq.convoy().size() == n + 1, "the same spawn can't drop twice")
	check(_eq.claim_drop("spn_other", "wpn_halberd") == "Halberd" and _eq.convoy().size() == n + 2, "another spawn can")
	check(_eq.claim_drop("spn_none", null) == "" and _eq.claim_drop("spn_none", "") == "", "no drop configured: nothing")
	check(_eq.claim_drop("spn_bad", "wpn_nonesuch") == "" and not _gs.drops_claimed.has("spn_bad"), "an unknown weapon id is ignored, and doesn't use up the claim")
	check(_eq.describe({"weapon_id": "wpn_sword_basic", "uses": 12}) == "Iron Sword (12)", "describe reads 'Iron Sword (12)'")
	# canon sanity: every real drop resolves and the overlap weapons come only from drops
	var drops := 0
	for row in root.get_node("Canon").get_table("encounter_spawns"):
		var d = row.get("drop_weapon_id")
		if d != null and d != "":
			drops += 1
			check(not _eq.weapon_row(d).is_empty(), "drop %s resolves (%s)" % [d, row["spawn_id"]])
	check(drops == 22, "22 drops in canon (got %d)" % drops)
