extends Node
## Autoload singleton: the fallen, and the epilogue sentence written for each (canon's
## epilogue_generation and epilogue_text tabs). Register after Supports, Equipment,
## Progression and Defections.
##
## Permadeath. A main-roster unit (not the avatar) who falls on a map is recorded as pending;
## winning the map makes it final -- they leave the company (Defections.is_gone says so, so every
## roster screen already hides them), their pack goes to the convoy and the weapon they carried
## meets its fate. Losing or retrying the map discards the pending falls. Anna, cargo and the
## prologue's units are not "the 18" and are never recorded. GameState.flags["casual"] = true
## turns permadeath off.
##
## The sentence is assembled, never stored:
##   [NAME], [TITLE CLAUSE], fell at [CHAPTER TITLE] to [KILLER CLAUSE]. [WEAPON]. [SUPPORT].
## from the structured record taken at the moment of the fall. The text lives in the
## epilogue_text tab; this file only chooses and fills.

const AVATAR := "u_avatar"
const FATES := ["lost_to_enemy", "retrieved", "thrown_and_lost", "with_the_body"]
const SUPPORT_TIERS := ["C", "B", "A", "S"]

# ------------------------------------------------------------------ state

func _section(name: String, fallback: Variant) -> Variant:
	if not GameState.epilogue.has(name):
		GameState.epilogue[name] = fallback
	return GameState.epilogue[name]

func _deaths() -> Dictionary:
	return _section("deaths", {})

func _pending() -> Dictionary:
	return _section("pending", {})

func is_dead(unit_id: String) -> bool:
	return GameState.epilogue.get("deaths", {}).has(unit_id)

func is_pending(unit_id: String) -> bool:
	return GameState.epilogue.get("pending", {}).has(unit_id)

func death(unit_id: String) -> Dictionary:
	return GameState.epilogue.get("deaths", {}).get(unit_id, {})

func count() -> int:
	return GameState.epilogue.get("deaths", {}).size()

## Whether this unit's fall is recorded: one of the 18, not the avatar, and not in casual mode.
func eligible(unit_id: String) -> bool:
	if unit_id == AVATAR or bool(GameState.flags.get("casual", false)):
		return false
	return Canon.find_by("units", "unit_id", unit_id) != null

## A map is starting fresh: falls from an unfinished earlier attempt do not count.
func begin_map() -> void:
	GameState.epilogue["pending"] = {}

# ------------------------------------------------------------- canon text

func _phrases() -> Dictionary:
	var out := {}
	for r in Canon.get_table("epilogue_text"):
		if str(r.get("phrase_id", "")).begins_with("epi_"):
			out[r["phrase_id"]] = str(r.get("text", ""))
	return out

## A phrase with its {PLACEHOLDERS} filled; "{A}" becomes "a" or "an" for the word after it.
func fill(phrase_id: String, vars: Dictionary = {}) -> String:
	var text: String = _phrases().get(phrase_id, "")
	for k in vars:
		text = text.replace("{%s}" % k, str(vars[k]))
	return _articles(text)

static func _articles(text: String) -> String:
	var out := text
	var at := out.find("{A} ")
	while at >= 0:
		var next := out.substr(at + 4, 1).to_lower()
		out = out.substr(0, at) + ("an" if next in ["a", "e", "i", "o", "u"] else "a") + out.substr(at + 3)
		at = out.find("{A} ")
	return out

func _unit_name(unit_id: String) -> String:
	var u = Canon.find_by("units", "unit_id", unit_id)
	return str(u.get("name")) if u != null else unit_id

func _chapter_id(map_id: String) -> String:
	var m = Canon.find_by("maps", "map_id", map_id)
	return str(m.get("chapter_id", "")) if m != null and m.get("chapter_id") != null else ""

## The place a fall is set at: the chapter's title, "The tally house" -> "the tally house".
func place_name(chapter_id: String) -> String:
	var ch = Canon.find_by("chapters", "chapter_id", chapter_id)
	var title: String = str(ch.get("title", chapter_id)) if ch != null else chapter_id
	return "the " + title.substr(4) if title.begins_with("The ") else title

# --------------------------------------------------------------- killers

## Who dealt a blow, from the enemy instance: {"type", "id", "noun", "who"}. In the order the
## canon schema asks for them: a defector is named, a Named is credited by its signature verb,
## a chapter boss is named, a state's soldier is "a <polity> <weapon>", anyone else is a band.
func classify(inst: Dictionary, map_id: String) -> Dictionary:
	var arch: Dictionary = inst.get("archetype", {})
	var name := str(arch.get("name", "enemy"))
	var noun := str(arch.get("death_noun", "blade")) if arch.get("death_noun") != null else "blade"
	if inst.has("defector"):
		var d := Defections.row(str(inst["defector"]))
		return {"type": "defector", "id": str(inst["defector"]), "noun": noun, "who": _unit_name(str(d.get("unit_id", "")))}
	if arch.get("named_id") != null and str(arch.get("named_id")) != "":
		return {"type": "named_creature", "id": str(arch["named_id"]), "noun": noun, "who": name}
	if inst.get("kind", "") == "boss":
		return {"type": "boss", "id": str(arch.get("enemy_id", "")), "noun": noun, "who": quarry_name(arch)}
	var m = Canon.find_by("maps", "map_id", map_id)
	var polity: String = str(m.get("enemy_polity_id")) if m != null and m.get("enemy_polity_id") != null else ""
	if str(arch.get("affiliation", "")) == "state" and polity != "":
		return {"type": "polity", "id": polity, "noun": noun, "who": name.to_lower()}
	return {"type": "band", "id": str(arch.get("enemy_id", "")), "noun": noun, "who": name.to_lower()}

## What a victory over this archetype is "Slayer of": the Karkadann, Boyan, the Warlord.
func quarry_name(arch: Dictionary) -> String:
	if arch.get("named_id") != null and str(arch.get("named_id")) != "":
		var n = Canon.find_by("named", "named_id", str(arch["named_id"]))
		if n != null:
			return str(n.get("name"))
	var name := str(arch.get("name", "enemy"))
	if str(arch.get("affiliation", "")) == "individual":
		return name.split(",")[0]
	return "the " + name.to_lower() if not name.begins_with("The ") else "the " + name.substr(4)

## The boss-kill deed was earned against this archetype.
func note_slain(unit_id: String, arch: Dictionary) -> void:
	var slain: Dictionary = _section("slain", {})
	var list: Array = slain.get(unit_id, [])
	list.append(quarry_name(arch))
	slain[unit_id] = list

# ---------------------------------------------------------------- falling

## `unit_id` has fallen on `map_id`. `killer` is what classify() returned, or {"type": "hazard",
## "id": "cold"} / {"type": "unknown"}; map_grid adds "own_action" (the unit died attacking) and
## "enemy_idx" (which enemy did it, for the weapon's fate). Returns the pending record, or {}
## when the fall is not recorded.
func note_fall(unit_id: String, map_id: String, killer: Dictionary) -> Dictionary:
	if map_id == "map_f00" or not eligible(unit_id) or is_dead(unit_id):
		return {}
	var held: Array = []
	for ep in Canon.get_table("epithets"):
		if Progression.has_deed(unit_id, ep["epithet_id"]):
			held.append(ep["epithet_id"])
	var carried: Dictionary = Equipment.equipped(unit_id)
	var pack: Array = []
	for entry in Equipment.inventory(unit_id):
		if carried.is_empty() or not is_same(entry, carried):
			pack.append(entry.duplicate(true))
	var gone_or_dead: Array = []
	for u in Canon.get_table("units"):
		var uid: String = u["unit_id"]
		if uid != unit_id and (is_dead(uid) or Defections.is_gone(uid)):
			gone_or_dead.append(uid)
	var bond: Dictionary = Supports.support_status(unit_id, gone_or_dead)
	if not bond.get("paired", false):
		bond = Supports.support_status(unit_id)
	var rec := {
		"unit_id": unit_id, "map_id": map_id, "chapter_id": _chapter_id(map_id),
		"killed_by_type": str(killer.get("type", "unknown")), "killed_by_id": str(killer.get("id", "")),
		"noun": str(killer.get("noun", "")), "who": str(killer.get("who", "")),
		"own_action": bool(killer.get("own_action", false)), "enemy_idx": int(killer.get("enemy_idx", -1)),
		"epithets": held, "slain": (GameState.epilogue.get("slain", {}).get(unit_id, []) as Array).duplicate(),
		"weapon_id": str(carried.get("weapon_id", "")), "weapon_uses": int(carried.get("uses", 0)), "weapon_fate": "",
		"pack": pack, "order": _pending().size(),
		"partner": str(bond.get("partner", "")), "tier": str(bond.get("tier", "")), "romantic": bool(bond.get("romantic", false)),
	}
	_pending()[unit_id] = rec
	return rec

## The default fate of the weapon a unit carried, given whether the one who killed them
## still holds it (`killer_holds`: alive and on the field, or fled).
func fate_for(rec: Dictionary, killer_holds: bool) -> String:
	match rec.get("killed_by_type", "unknown"):
		"hazard":
			return "with_the_body"
		"unknown":
			return "lost_to_enemy"
	if not killer_holds:
		return "retrieved"
	return "thrown_and_lost" if rec.get("own_action", false) else "lost_to_enemy"

## The map was won: the pending falls become final. `fates` maps unit_id -> weapon fate (any
## missing falls back to fate_for with the killer holding the weapon). Returns the sentences.
func commit(fates: Dictionary = {}) -> Array[String]:
	var out: Array[String] = []
	var pending := _pending()
	var ids: Array = pending.keys()
	ids.sort_custom(func(a, b): return int(pending[a].get("order", 0)) < int(pending[b].get("order", 0)))
	for uid in ids:
		var rec: Dictionary = pending[uid]
		var seq := int(GameState.epilogue.get("seq", 0)) + 1
		GameState.epilogue["seq"] = seq
		rec["seq"] = seq
		var fate: String = str(fates.get(uid, fate_for(rec, true)))
		rec["weapon_fate"] = fate if rec["weapon_id"] != "" else ""
		for entry in rec["pack"]:
			GameState.convoy.append(entry)
		if rec["weapon_id"] != "" and fate == "retrieved":
			GameState.convoy.append({"weapon_id": rec["weapon_id"], "uses": int(rec["weapon_uses"])})
		GameState.inventories.erase(uid)
		rec["pack"] = []
		_deaths()[uid] = rec
		out.append(sentence(rec))
	GameState.epilogue["pending"] = {}
	return out

# -------------------------------------------------------------- the text

## The strongest title the record holds: a paragon-gating deed beats one that does not, then
## canon order. "" when the unit held none.
func title_clause(rec: Dictionary) -> String:
	var best: Dictionary = {}
	for ep in Canon.get_table("epithets"):
		if not (rec.get("epithets", []) as Array).has(ep["epithet_id"]) or ep.get("forge_vocab_token") == null:
			continue
		if best.is_empty() or (ep.get("gates_paragon") == "yes" and best.get("gates_paragon") != "yes"):
			best = ep
	if best.is_empty():
		return ""
	var token := str(best["forge_vocab_token"])
	if token.ends_with(" of"):
		var slain: Array = rec.get("slain", [])
		if slain.is_empty():
			return fill("epi_title_slayer_fallback")
		return fill("epi_title_slayer_of", {"TOKEN": token, "OBJECT": slain[-1]})
	if token.begins_with("of "):
		return token
	return fill("epi_title_the", {"TOKEN": token})

## "to an Assembly arrow" / ", in the chaos, to no blade anyone could name" -- the tail after "fell at X".
func killer_tail(rec: Dictionary) -> String:
	var type := str(rec.get("killed_by_type", "unknown"))
	match type:
		"unknown":
			return fill("epi_tail_unknown")
		"hazard":
			var h := fill("epi_hazard_" + str(rec.get("killed_by_id", "")))
			return fill("epi_tail_hazard", {"HAZARD": h if h != "" else "the elements"})
	var clause := ""
	match type:
		"polity":
			var pol = Canon.find_by("polities", "polity_id", str(rec.get("killed_by_id", "")))
			clause = fill("epi_killer_polity", {"ADJ": str(pol.get("epilogue_adjective", "")) if pol != null else "", "NOUN": rec.get("noun", "blade")})
		"band":
			clause = fill("epi_killer_band", {"WHO": rec.get("who", "enemy"), "NOUN": rec.get("noun", "blade")})
		"named_creature":
			var n = Canon.find_by("named", "named_id", str(rec.get("killed_by_id", "")))
			clause = fill("epi_killer_named", {"PHRASE": str(n.get("death_phrase", "")) if n != null else str(rec.get("who", ""))})
		"defector":
			clause = fill("epi_killer_defector", {"DEFECTOR": rec.get("who", "")})
		"boss":
			clause = fill("epi_killer_boss", {"BOSS": rec.get("who", "")})
	return fill("epi_tail_known", {"KILLER": clause})

## "" when the unit died unarmed.
func weapon_clause(rec: Dictionary) -> String:
	var wid := str(rec.get("weapon_id", ""))
	var fate := str(rec.get("weapon_fate", ""))
	if wid == "" or not FATES.has(fate):
		return ""
	return fill("epi_weapon_" + fate, {"NAME": _unit_name(str(rec["unit_id"])), "WEAPON": Equipment.weapon_name(wid)})

## What became of the bond, read now: the partner may have since fallen or left.
func support_clause(rec: Dictionary) -> String:
	var partner := str(rec.get("partner", ""))
	if partner == "":
		return fill("epi_support_alone")
	var vars := {"PARTNER": _unit_name(partner), "NAME": _unit_name(str(rec["unit_id"]))}
	var theirs := death(partner)
	if not theirs.is_empty():
		var later := int(theirs.get("seq", 0)) > int(rec.get("seq", 1 << 30))
		return fill("epi_support_fallen_after" if later else "epi_support_fallen_before", vars)
	if Defections.is_gone(partner):
		return fill("epi_support_gone", vars)
	var kind := "romantic" if rec.get("romantic", false) else "platonic"
	var line := fill("epi_support_%s_%s" % [kind, rec.get("tier", "C")], vars)
	return line if line != "" else fill("epi_support_platonic_A", vars)

## The whole epilogue sentence group for one record.
func sentence(rec: Dictionary) -> String:
	var name := _unit_name(str(rec["unit_id"]))
	var place := place_name(str(rec.get("chapter_id", "")))
	var title := title_clause(rec)
	var head := fill("epi_head", {"NAME": name, "TITLE": title, "PLACE": place}) if title != "" \
		else fill("epi_head_plain", {"NAME": name, "PLACE": place})
	var parts: Array[String] = [head + killer_tail(rec) + "."]
	var w := weapon_clause(rec)
	if w != "":
		parts.append(w)
	parts.append(support_clause(rec))
	return " ".join(parts)

# --------------------------------------------------------------- the roll

## The fallen in the order they fell: [{"unit_id", "seq", "text"}].
func roll() -> Array:
	var out: Array = []
	for uid in GameState.epilogue.get("deaths", {}):
		var rec: Dictionary = GameState.epilogue["deaths"][uid]
		out.append({"unit_id": uid, "seq": int(rec.get("seq", 0)), "text": sentence(rec)})
	out.sort_custom(func(a, b): return a["seq"] < b["seq"])
	return out

func roll_text() -> String:
	var rows := roll()
	if rows.is_empty():
		return fill("epi_roll_empty")
	var lines: Array[String] = [fill("epi_roll_title"), ""]
	for r in rows:
		lines.append(r["text"])
		lines.append("")
	return "\n".join(lines).strip_edges()
