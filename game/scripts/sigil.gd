extends Node2D
## A patron's sigil (canon patrons): one distinct mark per pair, drawn from its number, in two hands. The ANGEL's is curved,
## ringed and open; the DEMON's is straight, barbed and closed; a balanced bearer's is the straight mark inside a ring. The same
## points and the same order, so the pair is recognisably one seal seen from its two sides.
## Everything is computed (no art): Sigil.build(number, side, radius) is pure and tested; the node only draws it.

var number := 1
var side := "balanced"
var radius := 8.0
var color := Color(0.9, 0.85, 0.7, 0.95)

static func _next(state: int) -> int:
	return (state * 1103515245 + 12345) & 0x7fffffff

## The seal as {"lines": [PackedVector2Array], "circles": [[centre, radius]]}.
static func build(n: int, who: String, r: float) -> Dictionary:
	var state := _next(n * 7919 + 17)
	var slots := 16
	var order: Array = range(slots)
	for i in range(slots - 1, 0, -1):          # a seeded shuffle of the sixteen places round the ring
		state = _next(state)
		var j := state % (i + 1)
		var t = order[i]
		order[i] = order[j]
		order[j] = t
	state = _next(state)
	var k := 5 + state % 5                     # five to nine points
	var pts: Array[Vector2] = []
	for i in k:
		var a := TAU * float(order[i]) / float(slots) - PI / 2.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	var lines: Array = []
	var circles: Array = []
	for i in range(k - 1):
		var a := pts[i]
		var b := pts[i + 1]
		if who == "angel":
			var mid := (a + b) * 0.5 * 0.55           # bowed toward the centre
			var curve := PackedVector2Array()
			for s in range(9):
				var t := float(s) / 8.0
				curve.append((1 - t) * (1 - t) * a + 2 * (1 - t) * t * mid + t * t * b)
			lines.append(curve)
		else:
			lines.append(PackedVector2Array([a, b]))
	if who == "demon":
		for p in pts:                                 # barbs at every point, pointing out
			lines.append(PackedVector2Array([p, p * 1.25]))
		lines.append(PackedVector2Array([pts[0], pts[k - 1]]))        # and the path is shut
	else:
		circles.append([Vector2.ZERO, r * 1.2])
	if who == "angel" and n % 2 == 0:
		circles.append([Vector2.ZERO, r * 0.35])
	if who != "angel" and n % 3 == 0:
		lines.append(PackedVector2Array([Vector2(-r * 0.3, 0), Vector2(r * 0.3, 0)]))
	return {"lines": lines, "circles": circles}

## A string that tells every (number, side) apart, for tests.
static func signature(n: int, who: String) -> String:
	var b := build(n, who, 10.0)
	var parts: Array[String] = []
	for l in b["lines"]:
		for p in l:
			parts.append("%.1f,%.1f" % [p.x, p.y])
		parts.append("|")
	for c in b["circles"]:
		parts.append("c%.1f" % c[1])
	return " ".join(parts)

func _draw() -> void:
	var b := build(number, side, radius)
	for l in b["lines"]:
		draw_polyline(l, color, 1.2, true)
	for c in b["circles"]:
		draw_arc(c[0], c[1], 0.0, TAU, 20, color, 1.0, true)
