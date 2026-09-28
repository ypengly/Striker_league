class_name Pitch
extends Node2D
## Static pitch + stadium surroundings drawn procedurally (no art assets needed).

const HALF_W := 1100.0
const HALF_H := 650.0
const GOAL_HALF := 120.0
const GOAL_DEPTH := 70.0
const CROSSBAR_H := 62.0
const PEN_DEPTH := 300.0
const PEN_HALF := 320.0
const GOAL_AREA_DEPTH := 110.0
const GOAL_AREA_HALF := 150.0
const CIRCLE_R := 150.0
const PEN_SPOT := 210.0
const MARGIN := 80.0

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var W := HALF_W
	var H := HALF_H
	# outer stadium ground + concrete stands
	draw_rect(Rect2(-W - 700, -H - 600, (W + 700) * 2.0, (H + 600) * 2.0), Color("#12151c"))
	draw_rect(Rect2(-W - 420, -H - 330, (W + 420) * 2.0, (H + 330) * 2.0), Color("#262b38"))
	for i in 8:
		var inset := 110.0 + i * 24.0
		var shade := Color("#2e3444") if i % 2 == 0 else Color("#282d3b")
		draw_rect(Rect2(-W - inset - 12, -H - inset - 12, (W + inset + 12) * 2.0, 24.0), shade)
		draw_rect(Rect2(-W - inset - 12, H + inset - 12, (W + inset + 12) * 2.0, 24.0), shade)
	# grass with mowing stripes
	var gx := -W - MARGIN
	var gw := (W + MARGIN) * 2.0
	draw_rect(Rect2(gx, -H - MARGIN, gw, (H + MARGIN) * 2.0), Color("#2c8541"))
	var sx := gx
	var k := 0
	while sx < gx + gw:
		if k % 2 == 0:
			draw_rect(Rect2(sx, -H - MARGIN, minf(110.0, gx + gw - sx), (H + MARGIN) * 2.0), Color("#308c46"))
		sx += 110.0
		k += 1
	# advertising boards
	var font := ThemeDB.fallback_font
	var bx := -W - MARGIN
	var bi := 0
	while bx < W + MARGIN - 10.0:
		var c := Color("#19d3a2") if bi % 2 == 0 else Color("#ffb020")
		draw_rect(Rect2(bx, -H - MARGIN - 22.0, 250.0, 22.0), c.darkened(0.5))
		draw_rect(Rect2(bx, H + MARGIN, 250.0, 22.0), c.darkened(0.5))
		draw_string(font, Vector2(bx + 12.0, -H - MARGIN - 5.0), "STRIKER LEAGUE", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, c.lightened(0.5))
		draw_string(font, Vector2(bx + 12.0, H + MARGIN + 17.0), "STRIKER LEAGUE", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, c.lightened(0.5))
		bx += 250.0
		bi += 1
	# lines
	var lc := Color(1, 1, 1, 0.92)
	var lw := 4.0
	draw_rect(Rect2(-W, -H, W * 2.0, H * 2.0), lc, false, lw)
	draw_line(Vector2(0, -H), Vector2(0, H), lc, lw)
	draw_arc(Vector2.ZERO, CIRCLE_R, 0.0, TAU, 72, lc, lw)
	draw_circle(Vector2.ZERO, 7.0, lc)
	for s in [-1.0, 1.0]:
		var sd: float = s
		draw_polyline(PackedVector2Array([Vector2(sd * W, -PEN_HALF), Vector2(sd * (W - PEN_DEPTH), -PEN_HALF), Vector2(sd * (W - PEN_DEPTH), PEN_HALF), Vector2(sd * W, PEN_HALF)]), lc, lw)
		draw_polyline(PackedVector2Array([Vector2(sd * W, -GOAL_AREA_HALF), Vector2(sd * (W - GOAL_AREA_DEPTH), -GOAL_AREA_HALF), Vector2(sd * (W - GOAL_AREA_DEPTH), GOAL_AREA_HALF), Vector2(sd * W, GOAL_AREA_HALF)]), lc, lw)
		var spot := Vector2(sd * (W - PEN_SPOT), 0)
		draw_circle(spot, 6.0, lc)
		var a := acos((PEN_DEPTH - PEN_SPOT) / CIRCLE_R)
		if sd > 0.0:
			draw_arc(spot, CIRCLE_R, PI - a, PI + a, 24, lc, lw)
		else:
			draw_arc(spot, CIRCLE_R, -a, a, 24, lc, lw)
	# corner arcs + flags
	var corners := [[1.0, 1.0, PI, 1.5 * PI], [-1.0, 1.0, 1.5 * PI, TAU], [1.0, -1.0, 0.5 * PI, PI], [-1.0, -1.0, 0.0, 0.5 * PI]]
	for c in corners:
		var p := Vector2(float(c[0]) * W, float(c[1]) * H)
		draw_arc(p, 38.0, float(c[2]), float(c[3]), 12, lc, lw)
		draw_line(p, p + Vector2(0, -26), Color("#f4f4f4"), 3.0)
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -26), p + Vector2(15 * -float(c[0]), -20), p + Vector2(0, -14)]), Color("#ff4c4c"))

static func clamp_to_pitch(p: Vector2, margin: float = 0.0) -> Vector2:
	return Vector2(clampf(p.x, -HALF_W + margin, HALF_W - margin), clampf(p.y, -HALF_H + margin, HALF_H - margin))
