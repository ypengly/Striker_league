class_name MobileControls
extends CanvasLayer
## On-screen touch controls: virtual joystick + PASS / SHOOT / SPRINT / SWITCH / TACKLE buttons.
## They inject the same input actions as the keyboard, so gameplay code needs no special cases.

class Stick extends Control:
	var _index := -1
	var _vec := Vector2.ZERO
	const R := 90.0
	func _init() -> void:
		custom_minimum_size = Vector2(R * 2.4, R * 2.4)
		size = custom_minimum_size
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventScreenTouch:
			if e.pressed and _index == -1:
				_index = e.index
				_update(e.position)
			elif not e.pressed and e.index == _index:
				_index = -1
				_set(Vector2.ZERO)
		elif e is InputEventScreenDrag and e.index == _index:
			_update(e.position)
	func _update(p: Vector2) -> void:
		_set(((p - size * 0.5) / R).limit_length(1.0))
	func _set(v: Vector2) -> void:
		_vec = v
		Input.action_release("move_left")
		Input.action_release("move_right")
		Input.action_release("move_up")
		Input.action_release("move_down")
		if v.x < -0.1: Input.action_press("move_left", -v.x)
		if v.x > 0.1: Input.action_press("move_right", v.x)
		if v.y < -0.1: Input.action_press("move_up", -v.y)
		if v.y > 0.1: Input.action_press("move_down", v.y)
		queue_redraw()
	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, R, Color(1, 1, 1, 0.12))
		draw_arc(c, R, 0.0, TAU, 40, Color(1, 1, 1, 0.35), 3.0)
		draw_circle(c + _vec * R * 0.6, 34.0, Color(1, 1, 1, 0.4))

class TouchButton extends Control:
	var action := ""
	var text := ""
	var radius := 46.0
	var color := Color("#19d3a2")
	var _index := -1
	func _init(a: String, t: String, r: float, c: Color) -> void:
		action = a
		text = t
		radius = r
		color = c
		custom_minimum_size = Vector2(r * 2.0, r * 2.0)
		size = custom_minimum_size
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventScreenTouch:
			if e.pressed and _index == -1:
				_index = e.index
				Input.action_press(action)
				queue_redraw()
			elif not e.pressed and e.index == _index:
				_index = -1
				Input.action_release(action)
				queue_redraw()
	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, radius, Color(color.r, color.g, color.b, 0.55 if _index != -1 else 0.3))
		draw_arc(c, radius, 0.0, TAU, 32, Color(1, 1, 1, 0.5), 3.0)
		var f := ThemeDB.fallback_font
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_string(f, c + Vector2(-w * 0.5, 6.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)

func _ready() -> void:
	layer = 12
	var stick := Stick.new()
	stick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	stick.offset_left = 30.0
	stick.offset_top = -260.0
	stick.offset_right = 250.0
	stick.offset_bottom = -30.0
	add_child(stick)
	_btn("shoot", "SHOOT", 58.0, Color("#ff5c5c"), -150.0, -150.0)
	_btn("pass", "PASS", 46.0, Color("#19d3a2"), -290.0, -110.0)
	_btn("sprint", "SPRINT", 40.0, Color("#ffb020"), -120.0, -290.0)
	_btn("switch", "SWITCH", 36.0, Color("#4fa3d9"), -250.0, -240.0)
	_btn("tackle", "TACKLE", 36.0, Color("#b06cff"), -360.0, -200.0)

func _btn(action: String, text: String, r: float, col: Color, ox: float, oy: float) -> void:
	var b := TouchButton.new(action, text, r, col)
	b.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	b.offset_left = ox - r
	b.offset_top = oy - r
	b.offset_right = ox + r
	b.offset_bottom = oy + r
	add_child(b)
