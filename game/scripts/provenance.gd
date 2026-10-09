extends Node
## Autoload singleton: weapon names -- the marks a blade earns and what it is called for them
## (canon's epithets.weapon_form and the forge's "provenance grammar"). Register after
## Equipment, Progression and Forge.
##
## A weapon is a plain thing -- "Iron Axe" -- until someone earns a deed WITH it: the deed that
## completes while it is the equipped weapon is written on the blade as a *mark* (the "blood on
## the blade"). The mark outlives the wielder: a marked blade left in a convoy, passed to a
## friend or taken by an enemy keeps its history. A weapon keeps at most prm_weapon_marks_max
## marks (the oldest goes first). Its name uses the strongest: a paragon-gating deed beats one
## that does not, then the most recent -- "Taker's Iron Axe", "Iron Axe, Slayer of the Karkadann".
## A master smith will reforge a marked weapon from the convoy for prm_reforge_fee gold, which
## wipes the marks. A legendary weapon's history is not the smith's to clear.
##
## Marks live on the inventory entry itself, {"weapon_id", "uses", "marks": [{"ep", "object"}]},
## so they are saved, carried and stored with it. An entry with no marks is the old shape.

## The arts each kind of master smith will work.
const SPECIALTY_ARTS := {"edged": ["sword"], "hafted": ["lance", "axe"], "missile": ["bow"]}

func marks(entry: Dictionary) -> Array:
	return entry.get("marks", [])

func is_marked(entry: Dictionary) -> bool:
	return not marks(entry).is_empty()

func max_marks() -> int:
	return maxi(1, int(Progression.param("weapon_marks_max")))

## Writes a deed on a weapon. A repeat of a deed it already carries moves that mark to the
## newest place (and takes the new object). Returns false for an unknown deed or an empty entry.
func add_mark(entry: Dictionary, epithet_id: String, object: String = "") -> bool:
	if entry.is_empty() or Progression.epithet_row(epithet_id).is_empty():
		return false
	var list: Array = marks(entry).duplicate()
	for i in range(list.size() - 1, -1, -1):
		if list[i]["ep"] == epithet_id:
			list.remove_at(i)
	list.append({"ep": epithet_id, "object": object})
	while list.size() > max_marks():
		list.pop_front()
	entry["marks"] = list
	return true

## The deed `unit_id` just earned goes on the weapon in their hand. False if they hold none.
func mark_equipped(unit_id: String, epithet_id: String, object: String = "") -> bool:
	return add_mark(Equipment.equipped(unit_id), epithet_id, object)

## The mark that names the weapon: {} when unmarked.
func strongest(entry: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	for m in marks(entry):
		var gates: bool = Progression.epithet_row(m["ep"]).get("gates_paragon") == "yes"
		var best_gates: bool = not best.is_empty() and Progression.epithet_row(best["ep"]).get("gates_paragon") == "yes"
		if best.is_empty() or gates or not best_gates:       # marks run oldest to newest: later wins a tie
			best = m
	return best

## "Iron Axe" for a plain weapon; "Taker's Iron Axe" once marked.
func name_of(entry: Dictionary) -> String:
	var base := Equipment.weapon_name(str(entry.get("weapon_id", "")))
	var m := strongest(entry)
	if m.is_empty():
		return base
	var row := Progression.epithet_row(m["ep"])
	var form := str(row.get("weapon_form", "")) if row.get("weapon_form") != null else ""
	if "{OBJECT}" in form:
		if str(m.get("object", "")) == "":
			form = str(row.get("weapon_form_bare", "")) if row.get("weapon_form_bare") != null else ""
		else:
			form = form.replace("{OBJECT}", str(m["object"]))
	if form == "":
		return base
	return form.replace("{BASE}", base)

## Every mark as a phrase, oldest first: ["Slayer of the Karkadann", "of the Ford"].
func history(entry: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for m in marks(entry):
		var token := str(Progression.epithet_row(m["ep"]).get("forge_vocab_token", m["ep"]))
		out.append(("%s %s" % [token, m["object"]]) if token.ends_with(" of") and str(m.get("object", "")) != "" else token)
	return out

# --------------------------------------------------------------------- reforging

func reforge_fee() -> int:
	return int(Progression.param("reforge_fee"))

## Whether this master's craft covers a weapon: its specialty names the weapon's art, and it is
## not legendary. (Says nothing about access, gold or marks.)
func reforgeable_by(entry: Dictionary, forge_id: String) -> bool:
	var w := Equipment.weapon_row(str(entry.get("weapon_id", "")))
	var f := Forge.forge_row(forge_id)
	return not w.is_empty() and w.get("tier") != "legendary" and f.get("tier") == "master" \
		and (SPECIALTY_ARTS.get(str(f.get("specialty", "")), []) as Array).has(w.get("art"))

## Whether the convoy weapon at `index` can be reforged by this master right now:
## {"ok", "reason", "fee"}.
func can_reforge(index: int, forge_id: String) -> Dictionary:
	var fee := reforge_fee()
	var convoy: Array = Equipment.convoy()
	if index < 0 or index >= convoy.size():
		return {"ok": false, "reason": "there is no such weapon", "fee": fee}
	var entry: Dictionary = convoy[index]
	if not is_marked(entry):
		return {"ok": false, "reason": "it carries no marks to clear", "fee": fee}
	var w := Equipment.weapon_row(str(entry["weapon_id"]))
	if w.get("tier") == "legendary":
		return {"ok": false, "reason": "a legendary weapon's history is not the smith's to clear", "fee": fee}
	var f := Forge.forge_row(forge_id)
	if f.is_empty() or f.get("tier") != "master":
		return {"ok": false, "reason": "only a master smith reforges", "fee": fee}
	var acc := Forge.access(forge_id)
	if not acc["ok"]:
		return {"ok": false, "reason": "%s %s" % [f.get("name", "the smith"), acc["reason"]], "fee": fee}
	if not (SPECIALTY_ARTS.get(str(f.get("specialty", "")), []) as Array).has(w.get("art")):
		return {"ok": false, "reason": "%s does not work %s" % [f.get("name", "the smith"), w.get("art", "that")], "fee": fee}
	if GameState.gold < fee:
		return {"ok": false, "reason": "it costs %d gold" % fee, "fee": fee}
	return {"ok": true, "reason": "", "fee": fee}

## Reforges the convoy weapon at `index`: marks gone, fee paid. Returns the can_reforge dictionary
## plus "was" (the name it had) on success.
func reforge(index: int, forge_id: String) -> Dictionary:
	var check := can_reforge(index, forge_id)
	if not check["ok"]:
		return check
	var entry: Dictionary = Equipment.convoy()[index]
	check["was"] = name_of(entry)
	entry.erase("marks")
	GameState.gold -= int(check["fee"])
	return check
