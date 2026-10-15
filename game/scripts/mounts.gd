extends Node
## Autoload singleton: mounts (canon's mounts tab). Register after Progression, Equipment and Forge.
##
## Canon (roster_gaps): a mount is acquirable equipment -- by requisition, by capture, by inheritance
## -- not a class trait, so any of the 18 can end up mounted. A mount gives its rider its movement
## type (riding or flying) and, for a Named creature taken intact, its signature mechanic:
##   mnt_warhorse    -- riding, nothing else; ordered at the standard forges (400 gold) or taken by capturing a
##                      mounted enemy (one a map).
##   mnt_simurgh     -- flying; the rider and every ally beside them recover 5 HP at the start of each turn.
##   mnt_shadhavar   -- riding; every turn the nearest enemy is pulled one tile toward the rider.
##   mnt_karkadann   -- riding; the rider's blows are effective against mounted foes, and a charge (an
##                      attack after moving 3+ tiles) adds damage but leaves the rider stuck next turn.
##   mnt_anzu        -- flying; the rider's hits wear an enemy's weapon down (the Anzu Edge's unmake), and an
##                      enemy it has left unarmed drops nothing.
## A Named is taken INTACT by capturing it at or below capture_intact_hp_pct of its HP (a harvest, a
## diminished material, between that and capture_hp_pct; a kill, a prime material). A rider who falls
## leaves the mount riderless: it comes back to the stable if whoever killed the rider is dealt with by
## the end of the map (the same fate rule as a fallen unit's weapon), and is lost otherwise.
## State: GameState.mounts = {"stable": [mount ids], "assigned": {unit_id: mount_id}, "claimed": {named_id: true}}.

func _s() -> Dictionary:
	if not GameState.mounts.has("stable"):
		GameState.mounts["stable"] = []
	if not GameState.mounts.has("assigned"):
		GameState.mounts["assigned"] = {}
	if not GameState.mounts.has("claimed"):
		GameState.mounts["claimed"] = {}
	return GameState.mounts

func rows() -> Array:
	var out: Array = []
	for r in Canon.get_table("mounts"):
		if str(r.get("mount_id", "")).begins_with("mnt_"):
			out.append(r)
	return out

func row(mount_id: String) -> Dictionary:
	for r in rows():
		if r["mount_id"] == mount_id:
			return r
	return {}

func name_of(mount_id: String) -> String:
	return str(row(mount_id).get("name", mount_id))

func stable() -> Array:
	return _s()["stable"]

func mount_of(unit_id: String) -> String:
	return str(GameState.mounts.get("assigned", {}).get(unit_id, ""))

func effect_of(unit_id: String) -> String:
	var m := mount_of(unit_id)
	return str(row(m).get("effect", "")) if m != "" and row(m).get("effect") != null else ""

## The movement type a unit moves with: its mount's, if it has one.
func movement_for(unit_id: String, base: String) -> String:
	var m := mount_of(unit_id)
	return str(row(m).get("movement", base)) if m != "" else base

func describe(mount_id: String) -> String:
	match str(row(mount_id).get("effect", "")):
		"rider_heal":
			return "The rider and every ally beside them recover %d HP at the start of each turn." % int(Progression.param("mount_heal"))
		"pull_foe":
			return "Each turn the nearest enemy is pulled a tile toward the rider, and it cannot be turned off."
		"charge":
			return "The rider's blows are effective against mounted foes. After moving %d or more tiles an attack gains +%d damage, and the rider is stuck next turn." % [int(Progression.param("charge_distance")), int(Progression.param("charge_bonus"))]
		"unmake_touch":
			return "The rider's hits wear the foe's weapon down. An enemy it leaves unarmed drops nothing."
	return "Moves as %s." % row(mount_id).get("movement", "riding")

# --------------------------------------------------------------- who may ride

## Whether `unit_id` may take `mount_id`: {"ok", "reason"}. Declared gaps hold (no mounted brawler, no flying
## reader); someone who already moves as riding, flying or armor is not given a second mount.
func can_mount(unit_id: String, mount_id: String) -> Dictionary:
	var m := row(mount_id)
	if m.is_empty():
		return {"ok": false, "reason": "there is no such mount"}
	if not Progression.is_known_unit(unit_id) or Defections.is_gone(unit_id):
		return {"ok": false, "reason": "they are not with the company"}
	var cls := Progression.class_row(unit_id)
	var movement := str(cls.get("movement", "infantry"))
	if movement != "infantry":
		return {"ok": false, "reason": "a %s unit already has its own way of moving" % movement}
	var arts: Array = [cls.get("art_primary"), cls.get("art_secondary")]
	if arts.has("brawl"):
		return {"ok": false, "reason": "there is no mounted brawling tradition"}
	if str(m.get("movement")) == "flying" and arts.has("reason"):
		return {"ok": false, "reason": "no reader has flown yet"}
	return {"ok": true, "reason": ""}

# --------------------------------------------------------------- the stable

func add_to_stable(mount_id: String) -> bool:
	if row(mount_id).is_empty():
		return false
	_s()["stable"].append(mount_id)
	return true

## Gives a unit a mount from the stable (their old one goes back). {"ok", "reason"}.
func assign(unit_id: String, mount_id: String) -> Dictionary:
	var check := can_mount(unit_id, mount_id)
	if not check["ok"]:
		return check
	var st := _s()
	var i: int = st["stable"].find(mount_id)
	if i < 0:
		return {"ok": false, "reason": "%s is not in the stable" % name_of(mount_id)}
	st["stable"].remove_at(i)
	unassign(unit_id)
	st["assigned"][unit_id] = mount_id
	return {"ok": true, "reason": ""}

## Takes a unit's mount back to the stable. False if they had none.
func unassign(unit_id: String) -> bool:
	var st := _s()
	if not st["assigned"].has(unit_id):
		return false
	st["stable"].append(st["assigned"][unit_id])
	st["assigned"].erase(unit_id)
	return true

## A Named creature taken intact: its mount joins the stable, once a run. Returns the line ("" if it has
## no mount, or was already taken).
func bond_named(named_id: String) -> String:
	var st := _s()
	if st["claimed"].has(named_id):
		return ""
	for r in rows():
		if r.get("named_id") == named_id:
			st["claimed"][named_id] = true
			st["stable"].append(r["mount_id"])
			return "%s submits and will bear a rider: %s joins the stable intact. %s" % [str(r["name"]).substr(0, 1).to_upper() + str(r["name"]).substr(1), r["name"], describe(r["mount_id"])]
	return ""

## Whether capturing this Named at this HP is an intact capture.
func is_intact_capture(hp: int, max_hp: int) -> bool:
	return hp <= int(floor(max_hp * Progression.param("capture_intact_hp_pct") / 100.0))

## A rider has fallen for good: the mount is riderless. `recovered` is whether the map's fate lets it come
## home (see Epilogue.fate_for). Returns the line ("" if they had none).
func on_rider_fell(unit_id: String, recovered: bool) -> String:
	var st := _s()
	if not st["assigned"].has(unit_id):
		return ""
	var mount: String = st["assigned"][unit_id]
	st["assigned"].erase(unit_id)
	if recovered:
		st["stable"].append(mount)
		return "%s is recovered, riderless, and goes back to the stable." % name_of(mount).capitalize()
	if row(mount).get("kind") == "named":
		st["claimed"].erase(row(mount).get("named_id"))         # the creature goes back to the wild: it can be won again
	return "%s runs off riderless and is lost." % name_of(mount).capitalize()

## The line the barracks and the ledger show for a unit's mount ("" if none).
func summary(unit_id: String) -> String:
	var m := mount_of(unit_id)
	return "" if m == "" else "%s (%s)" % [name_of(m), str(row(m).get("movement", "riding"))]
