extends SceneTree
## Headless checks for the Supports autoload against the real exported data.
## Run from the repo root:
##   godot --headless --path game --script res://tests/test_supports.gd
## Exits 0 if every check passes, 1 otherwise.

var _failures: int = 0
var _checks: int = 0

# Autoload names aren't resolvable at compile time in a --script test, so
# fetch the nodes from the scene root instead.
var _canon: Node
var _gs: Node
var _sup: Node

func check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: ", label)

func _initialize() -> void:
	_canon = root.get_node("Canon")
	_gs = root.get_node("GameState")
	_sup = root.get_node("Supports")
	# Autoload _ready() hasn't run yet during _initialize; wait a frame so
	# Canon has loaded its tables and Supports has built its indexes.
	await process_frame
	_run()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)

func _run() -> void:
	var rows: Array = _canon.get_table("supports")
	var units: Array = []
	for u in _canon.get_table("units"):
		units.append(u["unit_id"])

	# --- the grid is complete and every lookup is symmetric
	check(rows.size() == 153, "153 chains loaded (got %d)" % rows.size())
	check(units.size() == 18, "18 units loaded (got %d)" % units.size())
	var sym_ok := true
	var pairs := 0
	for i in units.size():
		for j in range(i + 1, units.size()):
			var ab: Dictionary = _sup.get_chain(units[i], units[j])
			var ba: Dictionary = _sup.get_chain(units[j], units[i])
			pairs += 1
			if ab.is_empty() or ab != ba:
				sym_ok = false
	check(pairs == 153 and sym_ok, "all 153 pairs resolve to the same chain in either order")
	check(_sup.get_chain("u_avatar", "u_avatar").is_empty(), "a unit has no chain with itself")
	check(_sup.get_chain("u_avatar", "u_nobody").is_empty(), "unknown unit has no chain")
	var seventeen := true
	for u in units:
		if _sup.chains_for(u).size() != 17:
			seventeen = false
	check(seventeen, "every main unit belongs to exactly 17 chains")

	# --- text: C/B/A everywhere, S exactly on the romance chains
	var romance := 0
	var text_ok := true
	var s_rule_ok := true
	var max_ok := true
	var signs_ok := true
	for row in rows:
		var id: String = row["chain_id"]
		for r in ["C", "B", "A"]:
			if _sup.scene_text(id, r).length() < 40:
				text_ok = false
		var elig: bool = _sup.is_romance_eligible(id)
		if elig:
			romance += 1
		if (_sup.scene_text(id, "S") != "") != elig:
			s_rule_ok = false
		if _sup.max_rank(id) != ("S" if elig else "A"):
			max_ok = false
		var names: Array = _sup.sign_names(id)
		if names.size() != 2 or names[0] == "" or names[1] == "":
			signs_ok = false
	check(text_ok, "every chain has non-trivial C, B and A text")
	check(romance == 10, "10 romance-eligible chains (got %d)" % romance)
	check(s_rule_ok, "S text exists exactly on romance-eligible chains")
	check(max_ok, "max_rank is S for romance chains and A for the rest")
	check(signs_ok, "every chain resolves two sign names")

	# --- parsing lands the right words in the right rank
	check(_sup.scene_text("sup_ricberta_sigrun", "C").begins_with("They meet over dispatch"),
		"Ricberta/Sigrun C text starts where the canon C text starts")
	check(_sup.scene_text("sup_ricberta_sigrun", "S").begins_with("what holds"),
		"Ricberta/Sigrun S text starts after the (romance) marker")
	check(not _sup.scene_text("sup_ricberta_sigrun", "A").contains("S (romance)"),
		"A text does not swallow the S marker")
	check(_sup.sign_names("sup_ricberta_sigrun") == ["the Crab", "the Archer"],
		"Ricberta/Sigrun signs are the Crab and the Archer")
	check(_sup.partner_of("sup_ricberta_sigrun", "u_ricberta") == "u_sigrun", "partner_of a -> b")
	check(_sup.partner_of("sup_ricberta_sigrun", "u_sigrun") == "u_ricberta", "partner_of b -> a")
	check(_sup.partner_of("sup_ricberta_sigrun", "u_kest") == "", "partner_of a non-member is empty")

	# --- rank rules
	_gs.support_ranks.clear()
	var plain := "sup_dietmar_torvald"   # platonic, tops out at A
	var rom := "sup_ricberta_sigrun"      # romance-eligible, tops out at S
	check(_sup.current_rank(plain) == "", "no rank at the start of a playthrough")
	check(_sup.next_rank(plain) == "C", "first rank up is C")
	check(_sup.raise_rank(plain) == "C", "raise -> C")
	check(_sup.raise_rank(plain) == "B", "raise -> B")
	check(_sup.raise_rank(plain) == "A", "raise -> A")
	check(_sup.raise_rank(plain) == "", "platonic chain refuses to go past A")
	check(_sup.current_rank(plain) == "A", "platonic chain stays at A")
	for want in ["C", "B", "A", "S"]:
		check(_sup.raise_rank(rom) == want, "romance chain raise -> %s" % want)
	check(_sup.raise_rank(rom) == "", "romance chain refuses to go past S")
	check(_sup.raise_rank("sup_no_such_chain") == "", "unknown chain refuses to rank")
	check(_gs.get_support_rank("sup_no_such_chain") == "", "refusal writes nothing")

	# --- epilogue-facing support_status
	_gs.support_ranks.clear()
	check(_sup.support_status("u_kest") == {"paired": false}, "no ranks -> unpaired")
	_sup.raise_rank("sup_rinsa_kest")            # C
	_sup.raise_rank("sup_kheldar_kest")          # C
	var st: Dictionary = _sup.support_status("u_kest")
	check(st["paired"] and st["tier"] == "C", "paired at C")
	check(st["chain_id"] == "sup_kheldar_kest" and st["partner"] == "u_kheldar",
		"tie at the same rank breaks by chain_id order, deterministically")
	_sup.raise_rank("sup_rinsa_kest")            # B
	st = _sup.support_status("u_kest")
	check(st["partner"] == "u_rinsa" and st["tier"] == "B" and not st["romantic"],
		"higher rank wins; B is not romantic even on a romance-eligible chain")
	_sup.raise_rank("sup_rinsa_kest")            # A
	_sup.raise_rank("sup_rinsa_kest")            # S
	st = _sup.support_status("u_kest")
	check(st["tier"] == "S" and st["romantic"], "S rank reads as romantic")
	st = _sup.support_status("u_kest", ["u_rinsa"])
	check(st["paired"] and st["partner"] == "u_kheldar",
		"exclude_partners skips a partner and falls back to the next closest bond")
	check(_sup.support_status("u_kest", ["u_rinsa", "u_kheldar"]) == {"paired": false},
		"excluding every ranked partner reads as unpaired")
	check(_sup.support_status("u_rinsa")["partner"] == "u_kest",
		"the bond is visible from both sides")

	_gs.support_ranks.clear()
