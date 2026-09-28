class_name MatchCamera
extends Camera2D
## Smooth dynamic camera: follows ball + controlled player, zooms with the action, shakes on impacts.

var game: MatchManager
var _shake := 0.0
var _zoom_punch := 0.0
var _target_zoom := 1.0

func setup(g: MatchManager) -> void:
	game = g
	make_current()
	position_smoothing_enabled = false

func shake(amount: float) -> void:
	if GameState.camera_shake:
		_shake = maxf(_shake, amount)

func punch_zoom(amount: float) -> void:
	_zoom_punch = amount

func snap() -> void:
	position = game.ball.position

func _process(delta: float) -> void:
	if game == null or game.ball == null:
		return
	var b := game.ball
	var focus := b.position + (b.vel * 0.22).limit_length(240.0)
	var ctrl: Player = game.teams[0].controlled
	var pts: Array[Vector2] = [b.position]
	if ctrl != null:
		focus = focus.lerp(ctrl.position, 0.3)
		pts.append(ctrl.position)
	if b.carrier != null:
		pts.append(b.carrier.position)
	var rect := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		rect = rect.expand(p)
	var vp := get_viewport_rect().size
	var z := minf(vp.x / (rect.size.x + 560.0), vp.y / (rect.size.y + 380.0))
	z = clampf(z, 0.72, 1.06)
	# crowded situations: pull back; attacking third: push in a touch
	var near := 0
	for t in game.teams:
		for p in t.players:
			if p.position.distance_squared_to(b.position) < 90000.0:
				near += 1
	if near >= 6:
		z *= 0.93
	if absf(b.position.x) > Pitch.HALF_W * 0.6:
		z *= 1.05
	_target_zoom = z + _zoom_punch
	_zoom_punch = move_toward(_zoom_punch, 0.0, delta * 0.25)
	var zz := lerpf(zoom.x, _target_zoom, 1.0 - exp(-2.2 * delta))
	zoom = Vector2(zz, zz)
	var half := vp / (2.0 * zz)
	var mx := Pitch.HALF_W + 340.0
	var my := Pitch.HALF_H + 300.0
	var lo_x := -mx + half.x
	var hi_x := mx - half.x
	var lo_y := -my + half.y
	var hi_y := my - half.y
	var tgt := focus
	tgt.x = 0.0 if lo_x > hi_x else clampf(tgt.x, lo_x, hi_x)
	tgt.y = 0.0 if lo_y > hi_y else clampf(tgt.y, lo_y, hi_y)
	position = position.lerp(tgt, 1.0 - exp(-4.5 * delta))
	_shake = move_toward(_shake, 0.0, 40.0 * delta)
	offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
