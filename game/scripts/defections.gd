extends Node
## Autoload singleton: defections and the guest unit (canon's defections and guest_units
## tabs). Register after Progression, Equipment and Forge.
##
## Three units can leave the company in Act 2: Waldrada (diadem, scripted), Anselm
## (assembly, scripted) and Maren (assembly, conditional, recoverable). A defection fires
## when its trigger map is first won (Maren's only if her `trigger_unless` map has NOT been
## won -- the Ashland column was never worked). The defector leaves the roster, taking
## their weapons, and "appears later as a lieutenant standing near someone else's seal",
## carrying the titles (deeds) the player generated. Never the boss. Killing the lieutenant
## is permanent and, for Maren, ends any way back; winning her return map brings her home.
## Anna, a guest, joins once every defection she requires has happened and leaves for
## good when her departure map is won. State is in GameState (defections, guests).

const TIER_BY_PROMOTION := {"promoted": "high", "plain": "mid"}

# ------------------------------------------------------------------- canon

func rows() -> Array:
	var out: Array = []
	for r in Canon.get_table("defections"):
		if str(r.get("defection_id", "")).begins_with("def_"):
			out.append(r)
	return out

func row(defection_id: String) -> Dictionary:
	for r in rows():
		if r["defection_id"] == defection_id:
			return r
	return {}

func row_for_unit(unit_id: String) -> Dictionary:
	for r in rows():
		if r["unit_id"] == unit_id:
			return r
	return {}

func state(defection_id: String) -> String:
	return str(GameState.defections.get(defection_id, {}).get("state", ""))

## Whether a unit has left the company right now (and so is off the roster).
func is_gone(unit_id: String) -> bool:
	if Epilogue.is_dead(unit_id):         # the fallen have left the company too
		return true
	var r := row_for_unit(unit_id)
	return not r.is_empty() and state(r["defection_id"]) == "gone"

func is_fallen(defection_id: String) -> bool:
	return bool(GameState.defections.get(defection_id, {}).get("fallen", false))

## Whether a unit has joined the company yet: fielded, or their recruiting map won.
func joined(unit_id: String) -> bool:
	if Progression.has_state(unit_id):
		return true
	var u = Canon.find_by("units", "unit_id", unit_id)
	if u == null or u.get("join_chapter_id") == null:
		return false
	var ch = Canon.find_by("chapters", "chapter_id", u["join_chapter_id"])
	return ch != null and ch.get("map_id") != null and GameState.won_maps.has(ch["map_id"])

func _map_title(map_id: String) -> String:
	var m = Canon.find_by("maps", "map_id", map_id)
	return str(m.get("title")) if m != null else map_id

func _unit_name(unit_id: String) -> String:
	var u = Canon.find_by("units", "unit_id", unit_id)
	return str(u.get("name")) if u != null else unit_id

# ------------------------------------------------------------------ events

## The titles a unit has earned, as the epithet vocabulary tokens ("Untouched", "Taker"...).
func titles_for(unit_id: String) -> Array:
	var out: Array = []
	for ep in Canon.get_table("epithets"):
		if Progression.has_deed(unit_id, ep["epithet_id"]) and ep.get("forge_vocab_token") != null:
			out.append(str(ep["forge_vocab_token"]))
	return out

## A map was won. If it is a chapter not won before (`newly`): defections whose trigger it
## is happen, a recoverable defector whose return map it is comes home, and a guest whose
## departure map it is leaves. Returns the lines to show.
func on_map_won(map_id: String, newly: bool) -> Array[String]:
	var lines: Array[String] = []
	if not newly:
		return lines
	for r in rows():
		var did: String = r["defection_id"]
		var uid: String = r["unit_id"]
		var st := state(did)
		if st == "" and r.get("trigger_map_id") == map_id and joined(uid) and not Epilogue.is_dead(uid):
			var unless = r.get("trigger_unless_map_id")
			if unless == null or not GameState.won_maps.has(unless):
				lines.append(_defect(r))
		elif st == "gone" and r.get("return_map_id") == map_id and r.get("recruitable_back") == "yes" and not is_fallen(did):
			lines.append(_return(r))
	for g in Canon.get_table("guest_units"):
		var gid := str(g.get("guest_id", ""))
		if gid.begins_with("gst_") and guest_active(gid) and g.get("depart_map_id") == map_id:
			GameState.guests[gid] = "departed"
			lines.append("%s leaves the company for good: back to the rebaptism fieldwork." % g["name"] if g.get("off_screen_purpose_on_exit") != null else "%s leaves." % g["name"])
	return lines

func _defect(r: Dictionary) -> String:
	var uid: String = r["unit_id"]
	var carried: Array = []
	if GameState.inventories.has(uid):
		carried = GameState.inventories[uid].duplicate(true)
		GameState.inventories.erase(uid)
	var stats: Dictionary = Progression.stats_for(uid)
	GameState.defections[r["defection_id"]] = {
		"state": "gone", "map": r.get("trigger_map_id"), "class_id": Progression.class_id_of(uid), "level": Progression.level(uid),
		"stats": stats, "titles": titles_for(uid), "carried": carried, "fallen": false}
	var line := "%s leaves the company: %s." % [_unit_name(uid), str(r.get("trigger", "")).strip_edges()]
	if r.get("recruitable_back") == "yes":
		line += " It is not final: %s can be won back by working %s." % [_unit_name(uid), _map_title(str(r.get("return_map_id")))]
	return line

func _return(r: Dictionary) -> String:
	var did: String = r["defection_id"]
	var uid: String = r["unit_id"]
	var rec: Dictionary = GameState.defections[did]
	if not rec.get("carried", []).is_empty():
		GameState.inventories[uid] = (rec["carried"] as Array).duplicate(true)
	rec["state"] = "returned"
	rec["carried"] = []
	return "%s comes back to the company, weapons and all." % _unit_name(uid)

# ------------------------------------------------------------- lieutenants

## The defectors who stand on this map as lieutenants: [{"defection_id", "unit_id", "name", "titles", "archetype"}].
func lieutenants_for(map_id: String) -> Array:
	var out: Array = []
	for r in rows():
		var did: String = r["defection_id"]
		if state(did) == "gone" and not is_fallen(did) and r.get("appears_map_id") == map_id:
			var rec: Dictionary = GameState.defections[did]
			out.append({"defection_id": did, "unit_id": r["unit_id"], "name": _unit_name(r["unit_id"]), "titles": rec.get("titles", []), "archetype": _archetype(r, rec)})
	return out

## An enemy archetype built from the defector as they left: their level, stats, movement and art.
func _archetype(r: Dictionary, rec: Dictionary) -> Dictionary:
	var cls = Canon.find_by("classes", "class_id", rec.get("class_id", ""))
	var art := "sword"
	var movement := "infantry"
	var promoted := false
	if cls != null:
		art = str(cls["art_primary"]) if cls["art_primary"] != null and cls["art_primary"] != "none" else "sword"
		movement = str(cls["movement"])
		promoted = cls["tier"] != "trained" and cls["tier"] != "commoner"
	var st: Dictionary = rec.get("stats", {})
	var a := {"enemy_id": "def_%s" % str(r["unit_id"]).trim_prefix("u_"), "name": _unit_name(r["unit_id"]), "weapon_art": art,
		"weapon_tier": TIER_BY_PROMOTION["promoted" if promoted else "plain"], "movement_type": movement, "tier": "order",
		"level": int(rec.get("level", 1)), "behavior": "A defector, standing near another's seal. Never the boss.", "defector": r["defection_id"]}
	for stat in Progression.STATS:
		a[stat] = int(st.get(stat, 1))
	a["weapon_id"] = null
	return a

## A defector-lieutenant has fallen (`how` is "killed" or "captured"): a kill is permanent --
## they never appear again and, for a recoverable one, can no longer be won back.
func on_lieutenant_down(defection_id: String, how: String) -> String:
	if not GameState.defections.has(defection_id) or how != "killed":
		return ""
	GameState.defections[defection_id]["fallen"] = true
	var r := row(defection_id)
	var line := "%s is dead by your hand. Defection is not death, but this is." % _unit_name(r.get("unit_id", ""))
	if r.get("recruitable_back") == "yes":
		line += " There is no way back now."
	return line

## "Waldrada stands near the seal: Untouched, Taker." -- the pre-battle line.
func intro_line(lt: Dictionary) -> String:
	var titles: Array = lt["titles"]
	return "%s stands near the seal as a lieutenant%s." % [lt["name"], (": " + ", ".join(titles)) if not titles.is_empty() else ", with no titles earned"]

# ------------------------------------------------------------------ guests

## Whether a guest is with the company right now: every defection they require has happened
## (not merely one), and they have not yet departed.
func guest_active(guest_id: String) -> bool:
	if GameState.guests.get(guest_id, "") == "departed":
		return false
	var g = Canon.find_by("guest_units", "guest_id", guest_id)
	if g == null:
		return false
	var need := str(g.get("requires_defections", "")).split("|", false)
	if need.is_empty():
		return false
	for did in need:
		if state(did) == "":
			return false
	return true

func active_guests() -> Array:
	var out: Array = []
	for g in Canon.get_table("guest_units"):
		if str(g.get("guest_id", "")).begins_with("gst_") and guest_active(g["guest_id"]):
			out.append(g)
	return out

## A guest's level: the squad's median less guest_level_gap (never under their baseline's).
func guest_level(guest: Dictionary) -> int:
	var base := _guest_base(guest)
	var floor_level := int(base.get("level", 1))
	var median := Progression.squad_median()
	return maxi(floor_level, (median if median > 0 else floor_level) - int(Progression.param("guest_level_gap")))

## The baseline stat row for a guest: the first unit with the same class and growth profile.
func _guest_base(guest: Dictionary) -> Dictionary:
	for u in Canon.get_table("units"):
		if u.get("base_class_id") == guest.get("base_class_id") and u.get("growth_profile_id") == guest.get("growth_profile_id"):
			var b = Canon.find_by("unit_base_stats", "unit_id", u["unit_id"])
			if b != null:
				return b
	return {}

## The guest's stats at their level: baseline plus the profile's expected growth per level.
func guest_stats(guest: Dictionary) -> Dictionary:
	var base := _guest_base(guest)
	var prof = Canon.find_by("growths", "profile_id", guest.get("growth_profile_id", ""))
	var level := guest_level(guest)
	var out := {}
	for stat in Progression.STATS:
		var rate := float(prof.get(stat, 0)) / 100.0 if prof != null else 0.0
		out[stat] = int(base.get(stat, 1)) + int(round(rate * float(level - int(base.get("level", 1)))))
	return out
