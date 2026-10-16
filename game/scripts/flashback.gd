extends Node
## Autoload singleton: the flashbacks (canon flashbacks tab). Register after Almanac.
##
## A flashback is a memory, "and it is teaching, not testing": it may break the map laws. The prologue (F0) and
## the two later flashbacks (F1 "The scribes' quarter", F2 "The last court of the Long Reign") are chapters whose
## act is 'prologue' or 'flashback'. On them: no permadeath (nobody's fall is recorded), no forge, no requisition,
## no income, no deputy ledger, no supports, no Named, no suspending; one weapon each (the basic one of their art),
## no repair; a roster of their own (prologue_roster, by flashbacks.flashback_id); nobody is recruitable.
## flashbacks.engine_rule names the mechanics of each (a pipe list):
##   copyists / clerk_ledger / lost_page  (F1)   see map_grid and on_won
##   free_pact / falls                    (F2)   see map_grid, free_pact and on_fallen
## The party is taken into a memory when one falls due (the overworld asks due_chapter).

const FLAG_PAGE := "flashback_f1_page_lost"
const FLAG_COURT := "flashback_f2_court"

func _chapter_of(map_id: String) -> Dictionary:
	for ch in Canon.get_table("chapters"):
		if ch.get("map_id") == map_id:
			return ch
	return {}

func is_flashback(map_id: String) -> bool:
	return str(_chapter_of(map_id).get("act", "")) in ["prologue", "flashback"]

## The flashbacks row for a map ({} for any other map).
func row_for_map(map_id: String) -> Dictionary:
	var ch := _chapter_of(map_id)
	for r in Canon.get_table("flashbacks"):
		if r.get("chapter_id") != null and r.get("chapter_id") == ch.get("chapter_id"):
			return r
	return {}

func rules(map_id: String) -> Array:
	var out: Array = []
	var v = row_for_map(map_id).get("engine_rule")
	if v == null:
		return out
	for part in str(v).split("|"):
		out.append(part.strip_edges())
	return out

func has_rule(map_id: String, rule: String) -> bool:
	return rules(map_id).has(rule)

## The roster of this flashback: its prologue_roster rows.
func roster(map_id: String) -> Array:
	var fid = row_for_map(map_id).get("flashback_id")
	var out: Array = []
	for r in Canon.get_table("prologue_roster"):
		if r.get("flashback_id") == fid and str(r.get("punit_id", "")).begins_with("pu_"):
			out.append(r)
	return out

# ------------------------------------------------------------------ F1

## The ledger line a clerk writes when `who` has brought `foe` down.
func clerk_line(who: String, foe: String) -> String:
	return "The clerk writes it under %s's name: brought down a %s." % [who, foe.to_lower()]

## The clerk's tally at the end of a round of fighting: "Hadda 2, Zimri 1."
func clerk_tally(counts: Dictionary) -> String:
	var parts: Array[String] = []
	for name in counts:
		parts.append("%s %d" % [name, int(counts[name])])
	return ", ".join(parts)

## The copy is finished: a page of it is lost, and nothing ever says which. Remembered only as a flag the
## game never shows (the missing name enters the world here, as an accident nobody notices).
func lose_a_page(rng: RandomNumberGenerator = null) -> void:
	if GameState.flags.has(FLAG_PAGE):
		return
	var r := rng
	if r == null:
		r = RandomNumberGenerator.new()
		r.randomize()
	GameState.flags[FLAG_PAGE] = str(r.randi_range(1, int(Progression.param("flashback_register_pages"))))

# ------------------------------------------------------------------ F2

## Every pact answers once, free: a blow that would fell one of the court leaves them standing on 1 HP,
## once each. `used` is the map's record (unit id -> true). Returns whether the pact answered.
func free_pact(map_id: String, pid: String, used: Dictionary) -> bool:
	if not has_rule(map_id, "free_pact") or used.has(pid):
		return false
	used[pid] = true
	return true

## The memory ends: how the court fell, remembered (and shown to no one).
func on_fallen(held: bool) -> void:
	GameState.flags[FLAG_COURT] = "dawn" if held else "fell"

# ------------------------------------------------------------------ due

## The chapter ids of flashbacks (act 'flashback') in order.
func chapters() -> Array:
	var out: Array = []
	for ch in Canon.get_table("chapters"):
		if ch.get("act") == "flashback":
			out.append(ch)
	out.sort_custom(func(a, b): return int(a.get("number", 0)) < int(b.get("number", 0)))
	return out
