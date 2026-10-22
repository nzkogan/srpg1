extends Node2D
## THE IMAGE (canon maps.image_*): one silhouette that grows with the register. Canon makes the prologue's statue, the synod's colossus,
## the Hierophant's image and the Idol deliberately convergent, so the player should recognise the same figure each time before being
## told it is the same thing. Stage 1 is a robed figure with its hands folded (the statue, the church's image); stage 2 raises the arms and
## is fed by conduits (the colossus); stage 3 has four arms and a larger halo (the Hierophant's, and the movement's hidden one); stage 4 is
## the Idol: six arms, the coins and chains of what was taken, and a halo of all 72 patrons. The halo has one dot for each patron written
## into the register by then (1, 12, 36, 72).
## Everything is computed: ImageFigure.build(stage, w, h, broken) is pure (and tested); the node only draws it. A BROKEN figure is the same
## silhouette fallen into pieces (the prologue's statue when it is rubble).

var stage := 1
var size := Vector2(96, 96)
var broken := false

const HALO_DOTS := {1: 1, 2: 12, 3: 36, 4: 72}
const ARMS := {1: 2, 2: 2, 3: 4, 4: 6}

## The silhouette in a w x h box: {"polys": [PackedVector2Array], "lines": [PackedVector2Array], "dots": [Vector2], "rings": [[centre, radius]]}.
static func build(st: int, w: float, h: float, is_broken: bool) -> Dictionary:
	var polys: Array = []
	var lines: Array = []
	var dots: Array = []
	var rings: Array = []
	var cx := w * 0.5
	var scale_w := w * (0.34 + 0.03 * st)             # the body widens with the stage
	# plinth
	polys.append(PackedVector2Array([Vector2(cx - w * 0.42, h * 0.94), Vector2(cx + w * 0.42, h * 0.94), Vector2(cx + w * 0.38, h), Vector2(cx - w * 0.38, h)]))
	# robe: a long trapezoid from the plinth to the shoulders
	var shoulder_y := h * 0.34
	polys.append(PackedVector2Array([Vector2(cx - scale_w * 0.55, shoulder_y), Vector2(cx + scale_w * 0.55, shoulder_y), Vector2(cx + scale_w * 0.85, h * 0.94), Vector2(cx - scale_w * 0.85, h * 0.94)]))
	# neck and head
	polys.append(PackedVector2Array([Vector2(cx - w * 0.04, h * 0.27), Vector2(cx + w * 0.04, h * 0.27), Vector2(cx + w * 0.06, shoulder_y), Vector2(cx - w * 0.06, shoulder_y)]))
	var head_r := minf(w, h) * (0.085 + 0.01 * st)
	var head_c := Vector2(cx, h * 0.22)
	rings.append([head_c, head_r])
	# arms: pairs raised outward, one pair per two arms; stage 1's hang folded in front
	var n_arms: int = ARMS[st]
	if st == 1:
		lines.append(PackedVector2Array([Vector2(cx - scale_w * 0.5, shoulder_y + h * 0.02), Vector2(cx - scale_w * 0.2, h * 0.56), Vector2(cx, h * 0.58)]))
		lines.append(PackedVector2Array([Vector2(cx + scale_w * 0.5, shoulder_y + h * 0.02), Vector2(cx + scale_w * 0.2, h * 0.56), Vector2(cx, h * 0.58)]))
	else:
		for i in range(n_arms / 2):
			var lift := 0.30 + 0.17 * i                  # each higher pair reaches higher
			var y_end := h * (0.30 - 0.14 * (i % 2) + 0.18 * (i / 2))
			lines.append(PackedVector2Array([Vector2(cx - scale_w * 0.55, shoulder_y + h * 0.03 * i), Vector2(cx - minf(w * 0.48, w * (0.30 + lift * 0.4)), y_end)]))
			lines.append(PackedVector2Array([Vector2(cx + scale_w * 0.55, shoulder_y + h * 0.03 * i), Vector2(cx + minf(w * 0.48, w * (0.30 + lift * 0.4)), y_end)]))
	# conduits feeding the base (the colossus; and what the Idol is made of)
	if st >= 2:
		lines.append(PackedVector2Array([Vector2(cx - w * 0.36, h * 0.96), Vector2(w * 0.04, h * 0.80), Vector2(w * 0.04, h * 0.60)]))
		lines.append(PackedVector2Array([Vector2(cx + w * 0.36, h * 0.96), Vector2(w * 0.96, h * 0.80), Vector2(w * 0.96, h * 0.60)]))
	# coins and chains: what was taken
	if st == 4:
		for i in 6:
			dots.append(Vector2(cx - scale_w * 0.4 + i * scale_w * 0.16, h * 0.62 + (i % 2) * h * 0.06))
		lines.append(PackedVector2Array([Vector2(cx - scale_w * 0.6, h * 0.5), Vector2(cx, h * 0.58), Vector2(cx + scale_w * 0.6, h * 0.5)]))
	# the halo: one dot for each patron the register holds by now, evenly round the head
	var halo_n: int = HALO_DOTS[st]
	var halo_r := minf(head_r * (1.8 + 0.25 * st), minf(head_c.y * 0.95, w * 0.45))
	for i in halo_n:
		var a := TAU * float(i) / float(halo_n) - PI / 2.0
		dots.append(head_c + Vector2(cos(a), sin(a)) * halo_r)
	if is_broken:
		return _broken(polys, lines, dots, rings, w, h)
	return {"polys": polys, "lines": lines, "dots": dots, "rings": rings}

## The same pieces, fallen: every part shifted down and tilted by its own amount, the halo scattered along the ground.
static func _broken(polys: Array, lines: Array, dots: Array, rings: Array, w: float, h: float) -> Dictionary:
	var bp: Array = []
	var bl: Array = []
	var bd: Array = []
	var br: Array = []
	for i in polys.size():
		var shift := Vector2((float(i % 3) - 1.0) * w * 0.06, h * 0.10 * float(i % 4))
		var out := PackedVector2Array()
		for p in polys[i]:
			out.append(Vector2(clampf(p.x + shift.x, 0.0, w), clampf(p.y * 0.5 + h * 0.5 + shift.y, 0.0, h)))
		bp.append(out)
	for i in lines.size():
		var out := PackedVector2Array()
		for p in lines[i]:
			out.append(Vector2(clampf(p.x + float(i % 5 - 2) * w * 0.02, 0.0, w), clampf(h * 0.70 + (p.y / h) * h * 0.25, 0.0, h)))
		bl.append(out)
	for i in dots.size():
		bd.append(Vector2(clampf(w * 0.08 + w * 0.84 * float(i) / float(maxi(1, dots.size())), 0.0, w), h * 0.92 - float(i % 3) * h * 0.03))
	for r in rings:
		br.append([Vector2(clampf(r[0].x + w * 0.2, 0.0, w), h * 0.82), r[1]])
	return {"polys": bp, "lines": bl, "dots": bd, "rings": br}

## A string that tells every (stage, broken) apart, for tests.
static func signature(st: int, is_broken: bool) -> String:
	var b := build(st, 100.0, 100.0, is_broken)
	var parts: Array[String] = []
	for key in ["polys", "lines"]:
		for l in b[key]:
			for p in l:
				parts.append("%.1f,%.1f" % [p.x, p.y])
			parts.append("|")
	parts.append("dots%d" % b["dots"].size())
	return " ".join(parts)

func _draw() -> void:
	var b := build(stage, size.x, size.y, broken)
	var body := Color(0.10, 0.09, 0.12, 0.62)
	var edge := Color(0.78, 0.70, 0.52, 0.55)
	if stage == 4 and not broken:
		edge = Color(0.85, 0.42, 0.30, 0.65)             # the Idol's red-gold: what was taken
	for p in b["polys"]:
		draw_colored_polygon(p, body)
		draw_polyline(PackedVector2Array(Array(p) + [p[0]]), edge, 1.0, true)
	for l in b["lines"]:
		draw_polyline(l, edge, 2.0 if not broken else 1.0, true)
	for r in b["rings"]:
		draw_circle(r[0], r[1], body)
		draw_arc(r[0], r[1], 0.0, TAU, 20, edge, 1.0, true)
	for d in b["dots"]:
		draw_circle(d, 1.6 if stage < 4 else 1.2, Color(0.96, 0.84, 0.45, 0.85) if not broken else Color(0.7, 0.6, 0.4, 0.6))
