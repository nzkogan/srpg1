extends SceneTree
## Headless checks for the Kaisareia Trial run as the crown's ledger machine: the docket of mercies and
## kills, the commission holder (the deputy) and what it would recommend, the avatar's own recommendation,
## the sentence being final, and the trial screen.
## Run from the repo root:
##   godot --headless --path game --script res://tests/test_trial.gd
## Exits 0 if every check passes, 1 otherwise.

var _failures: int = 0
var _checks: int = 0
var _p: Node
var _gs: Node
var _d: Node

func check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: ", label)

func _initialize() -> void:
	_p = root.get_node("Progression")
	_gs = root.get_node("GameState")
	_d = root.get_node("Deputy")
	await process_frame
	await _run()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)

func _fresh(ids: Array = []) -> void:
	_gs.reset()
	for u in ids:
		_p.state(u)
		_gs.progression[u]["level"] = 10

func _key(k: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.pressed = true
	return ev

func _run() -> void:
	# ---- canon
	var eps: Array = _d.mercy_epithets()
	eps.sort()
	check(eps == ["ep_capture", "ep_dispersal", "ep_talk"] and _p.param("trial_mercy_weight") == 3, "canon: capture, talk and dispersal read as mercy; one mercy is worth 3 kills")

	# ---- the docket
	_fresh(["u_brandt", "u_jost", "u_gunnar"])
	_p.record_deed("u_brandt", "ep_capture", 2)
	_p.record_deed("u_brandt", "ep_talk", 1)
	_p.record_deed("u_brandt", "ep_dispersal", 1)
	_p.record_deed("u_brandt", "ep_bosskill", 4)
	_d.record("u_brandt", "raw_kill", 5)
	_d.record("u_brandt", "unwitnessed_kill", 2)
	_d.record("u_brandt", "writ_deed", 9)
	var bd: Dictionary = _d.docket("u_brandt")
	check(bd["mercies"] == 4 and bd["kills"] == 7, "a unit's docket: mercies are capture + talk + dispersal (4); kills are witnessed + unwitnessed (7); other deeds do not count (%s)" % str(bd))
	_p.record_deed("u_jost", "ep_capture", 1)
	_d.record("u_jost", "raw_kill", 3)
	_d.record("u_nobody_joined", "raw_kill", 50)
	var cd: Dictionary = _d.company_docket()
	check(cd["mercies"] == 5 and cd["kills"] == 10, "the company's docket sums everyone who has joined, and no one else (%s)" % str(cd))
	_gs.defections["def_waldrada"] = {"state": "gone"}
	_p.state("u_waldrada")
	_d.record("u_waldrada", "raw_kill", 40)
	check(_d.company_docket()["kills"] == 10, "...and not a defector")

	# ---- the commission
	check(_d.trial_holder() == "" and not _d.decided(), "no deputy, no commission holder")
	_gs.deputy = {"unit": "u_brandt", "contested": false}
	check(_d.trial_holder() == "u_brandt", "the crown's deputy holds the commission")
	var r: Dictionary = _d.commission_reading("u_brandt")
	check(r["verdict"] == "mercy" and r["mercies"] == 4 and r["kills"] == 7 and r["weight"] == 3, "4 mercies x 3 = 12 against 7 kills: the commission recommends mercy")
	_fresh(["u_brandt"])
	_p.record_deed("u_brandt", "ep_capture", 2)
	_d.record("u_brandt", "raw_kill", 6)
	check(_d.commission_reading("u_brandt")["verdict"] == "mercy", "2 mercies = 6 kills: a tie is mercy")
	_d.record("u_brandt", "raw_kill", 1)
	check(_d.commission_reading("u_brandt")["verdict"] == "execution", "one kill more and it is execution")
	_fresh(["u_sigrun"])
	check(_d.commission_reading("u_sigrun")["verdict"] == "mercy", "an empty record recommends mercy")

	# ---- recommending
	_fresh(["u_brandt", "u_jost"])
	check(not _d.trial_done() and _gs.trial.is_empty(), "no sentence yet")
	check(not _d.recommend("avatar", "pardon")["ok"] and not _d.recommend("avatar", "")["ok"] and not _d.trial_done(), "the court hears only mercy or execution")
	_d.record("u_jost", "raw_kill", 4)
	r = _d.recommend("avatar", "execution")
	check(r["ok"] and _gs.get_flag("flag_hierophant_verdict") == "execution" and _gs.trial["by"] == "avatar" and _gs.trial["verdict"] == "execution" and not _gs.trial["commission"] and _gs.trial["company_kills"] == 4, "the avatar recommends in person: the flag is set and the docket recorded")
	check(not _d.recommend("avatar", "mercy")["ok"] and _gs.get_flag("flag_hierophant_verdict") == "execution", "it is final")
	_fresh(["u_brandt"])
	_gs.set_flag("flag_hierophant_verdict", "mercy")
	check(not _d.recommend("avatar", "execution")["ok"], "a verdict already on the books also closes it")

	# the commission recommends off its holder's record
	_fresh(["u_brandt", "u_jost"])
	_gs.deputy = {"unit": "u_brandt", "contested": false}
	_p.record_deed("u_brandt", "ep_talk", 1)
	_d.record("u_brandt", "raw_kill", 9)
	check(not _d.recommend("u_jost", "mercy")["ok"], "only the holder may speak for the commission")
	check(not _d.recommend("u_brandt", "mercy")["ok"] and not _d.trial_done(), "...and only as its record reads (1 x 3 < 9: execution)")
	r = _d.recommend("u_brandt", "execution")
	check(r["ok"] and _gs.trial["commission"] and _gs.trial["by"] == "u_brandt" and _gs.trial["mercies"] == 1 and _gs.trial["kills"] == 9 and _gs.get_flag("flag_hierophant_verdict") == "execution", "the commission recommends execution")

	# ---- saved with the run
	var d: Dictionary = _gs.to_dict()
	check(d.has("trial") and _gs.validate(d) == "", "the record is part of the saved state")
	_gs.reset()
	check(_gs.trial.is_empty(), "a new run starts without one")

	# ---- the screen
	_fresh(["u_brandt", "u_jost"])
	_p.record_deed("u_jost", "ep_capture", 2)
	_d.record("u_jost", "raw_kill", 3)
	var sc: Node = load("res://scenes/trial.tscn").instantiate()
	root.add_child(sc)
	await process_frame
	var t: String = sc.detail_text()
	check(t.contains("2 mercies") and t.contains("3 kills") and t.contains("No deputy holds the commission"), "it reads out the docket, and that no one holds the commission")
	check(not sc.press("commission") and sc._message.contains("No deputy"), "with no deputy the commission cannot speak")
	sc._unhandled_input(_key(KEY_M))
	check(not _d.trial_done() and sc.detail_text().contains("Press M again"), "one M only proposes")
	sc._unhandled_input(_key(KEY_E))
	check(not _d.trial_done() and sc.detail_text().contains("Press E again"), "a different key moves the proposal")
	sc._unhandled_input(_key(KEY_SPACE))
	check(sc._proposed == "", "any other key withdraws it")
	sc._unhandled_input(_key(KEY_E))
	sc._unhandled_input(_key(KEY_E))
	check(_d.trial_done() and _gs.get_flag("flag_hierophant_verdict") == "execution" and sc.detail_text().contains("It is written") and sc.detail_text().contains("recommended it") , "E twice gives the sentence, and the screen shows it final")
	check(not sc.press("mercy") and _gs.get_flag("flag_hierophant_verdict") == "execution", "...nothing changes it")
	sc.queue_free()
	await process_frame

	_fresh(["u_brandt", "u_jost"])
	_gs.deputy = {"unit": "u_jost", "contested": false}
	_p.record_deed("u_jost", "ep_capture", 2)
	_d.record("u_jost", "raw_kill", 3)
	sc = load("res://scenes/trial.tscn").instantiate()
	root.add_child(sc)
	await process_frame
	t = sc.detail_text()
	check(t.contains("held by Jost") and t.contains("2 mercies") and t.contains("recommend [color") and t.contains("mercy"), "with a deputy the screen names the holder and what the commission would say")
	sc._unhandled_input(_key(KEY_ENTER))
	check(not _d.trial_done() and sc.detail_text().contains("Press Enter again"), "Enter proposes the commission's recommendation")
	sc._unhandled_input(_key(KEY_ENTER))
	check(_d.trial_done() and _gs.trial["commission"] and _gs.trial["by"] == "u_jost" and _gs.get_flag("flag_hierophant_verdict") == "mercy" and sc.detail_text().contains("off Jost's own record"), "Enter twice: the commission recommends mercy, off Jost's own record")
	sc.queue_free()
	await process_frame
