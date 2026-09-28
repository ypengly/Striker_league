class_name Crowd
extends Node2D
## Animated stadium crowd. Only draws what the camera can see, at ~10 Hz.

const GAP := 20.0
const ROWS := 7

var excitement := 0.0
var _colors: Array[Color] = []
var _skins: Array[Color] = [Color("#f1c27d"), Color("#c68642"), Color("#8d5524"), Color("#ffdbac")]
var _t := 0.0
var _acc := 0.0

func setup(home: Color, away: Color) -> void:
	_colors = [home, away, Color("#e8e8ee"), Color("#3b4460"), Color("#d94f4f"), Color("#f2c14e"), Color("#4fa3d9"), home, away]

func _process(delta: float) -> void:
	_t += delta
	excitement = maxf(0.0, excitement - delta * 0.3)
	_acc += delta
	if _acc >= 0.1:
		_acc = 0.0
		queue_redraw()

func _draw() -> void:
	if _colors.is_empty():
		return
	var vr: Rect2 = get_canvas_transform().affine_inverse() * get_viewport_rect()
	vr = vr.grow(50.0)
	var W := Pitch.HALF_W
	var H := Pitch.HALF_H
	for r in ROWS:
		var off := 130.0 + r * 24.0
		for side in [-1, 1]:
			var sd: int = side
			# horizontal stands (top / bottom)
			var y := sd * (H + off)
			if y >= vr.position.y and y <= vr.end.y:
				var x := maxf(vr.position.x, -W - 330.0)
				x = floorf(x / GAP) * GAP
				var xe := minf(vr.end.x, W + 330.0)
				while x < xe:
					_dot(x, y, int(x / GAP), r * 2 + (0 if sd < 0 else 1))
					x += GAP
			# vertical stands (left / right)
			var vx := sd * (W + off)
			if vx >= vr.position.x and vx <= vr.end.x:
				var yy := maxf(vr.position.y, -H - 80.0)
				yy = floorf(yy / GAP) * GAP
				var ye := minf(vr.end.y, H + 80.0)
				while yy < ye:
					_dot(vx, yy, int(yy / GAP) + 500, r * 2 + (0 if sd < 0 else 1) + 40)
					yy += GAP

func _dot(x: float, y: float, ix: int, salt: int) -> void:
	var h := absi((ix * 73856093) ^ (salt * 19349663))
	var col: Color = _colors[h % _colors.size()]
	var bob := maxf(0.0, sin(_t * 6.0 + float(h % 97))) * excitement * 7.0
	if excitement > 0.6 and (h + int(_t * 8.0)) % 19 == 0:
		col = Color.WHITE
	draw_rect(Rect2(x - 5.0, y - 5.0 - bob, 10.0, 12.0), col)
	draw_circle(Vector2(x, y - 9.0 - bob), 4.0, _skins[h % 4])
