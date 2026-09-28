class_name StadiumBackdrop
extends Control
## Animated menu background: night stadium, sweeping floodlight beams, crowd, bouncing football.

var _t := 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	var sky := PackedColorArray([Color("#060a18"), Color("#060a18"), Color("#14203f"), Color("#14203f")])
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h * 0.62), Vector2(0, h * 0.62)]), sky)
	# stands with crowd dots
	for r in 6:
		var y := h * 0.30 + r * 26.0
		draw_rect(Rect2(0, y, w, 22.0), Color(0.12 + r * 0.01, 0.15 + r * 0.01, 0.22 + r * 0.012))
		var x := fmod(r * 7.0, 16.0)
		while x < w:
			var hh := absi(int(x) * 31 + r * 17)
			var bob := maxf(0.0, sin(_t * 3.0 + float(hh % 13))) * 3.0
			var col := Color.from_hsv(float(hh % 100) / 100.0, 0.35, 0.55)
			draw_circle(Vector2(x, y + 8.0 - bob), 4.0, col)
			x += 16.0
	# pitch
	var green := PackedColorArray([Color("#1b5c2b"), Color("#1b5c2b"), Color("#2c8541"), Color("#2c8541")])
	draw_polygon(PackedVector2Array([Vector2(w * 0.2, h * 0.62), Vector2(w * 0.8, h * 0.62), Vector2(w, h), Vector2(0, h)]), green)
	for i in 6:
		var k0 := float(i) / 6.0
		var k1 := float(i + 1) / 6.0
		if i % 2 == 0:
			var y0 := lerpf(h * 0.62, h, k0 * k0)
			var y1 := lerpf(h * 0.62, h, k1 * k1)
			var xl0 := lerpf(w * 0.2, 0.0, k0 * k0)
			var xl1 := lerpf(w * 0.2, 0.0, k1 * k1)
			draw_polygon(PackedVector2Array([Vector2(xl0, y0), Vector2(w - xl0, y0), Vector2(w - xl1, y1), Vector2(xl1, y1)]), PackedColorArray([Color(1, 1, 1, 0.04), Color(1, 1, 1, 0.04), Color(1, 1, 1, 0.04), Color(1, 1, 1, 0.04)]))
	draw_line(Vector2(w * 0.2, h * 0.62), Vector2(w * 0.8, h * 0.62), Color(1, 1, 1, 0.6), 3.0)
	draw_arc(Vector2(w * 0.5, h * 0.8), h * 0.14, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 3.0)
	# floodlight towers + sweeping beams
	for tx in [w * 0.08, w * 0.92]:
		var tower := Vector2(tx, h * 0.22)
		draw_line(tower, tower + Vector2(0, h * 0.4), Color("#2a3350"), 6.0)
		var ang := PI * 0.5 + sin(_t * 0.6 + tx) * 0.5 + (0.5 if tx < w * 0.5 else -0.5)
		var a1 := Vector2.from_angle(ang - 0.12)
		var a2 := Vector2.from_angle(ang + 0.12)
		draw_polygon(PackedVector2Array([tower, tower + a1 * h * 1.0, tower + a2 * h * 1.0]),
			PackedColorArray([Color(1, 1, 0.85, 0.28), Color(1, 1, 0.85, 0.0), Color(1, 1, 0.85, 0.0)]))
		draw_circle(tower, 12.0, Color(1, 1, 0.9))
	# bouncing football
	var bx := fmod(_t * 90.0, w + 200.0) - 100.0
	var by := h * 0.86 - absf(sin(_t * 3.2)) * 130.0
	draw_circle(Vector2(bx, h * 0.9), 26.0 * (1.0 - (h * 0.9 - by) / 600.0), Color(0, 0, 0, 0.3))
	UIKit.draw_ball(self, Vector2(bx, by), 30.0, _t * 4.0)
	# vignette
	draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.18))
