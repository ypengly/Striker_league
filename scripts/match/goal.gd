class_name Goal
extends Area2D
## Goal mouth + net. Area2D detects the ball (Ball is an Area2D on layer 2) and animates net bulge.

signal ball_entered(side: int)

var side := 1            # +1 = goal on the right (x = +HALF_W), -1 = left
var bulge := 0.0
var bulge_y := 0.0

func setup(s: int) -> void:
	side = s
	position = Vector2(s * Pitch.HALF_W, 0.0)
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(Pitch.GOAL_DEPTH, Pitch.GOAL_HALF * 2.0 - 20.0)
	cs.shape = rs
	cs.position = Vector2(s * Pitch.GOAL_DEPTH * 0.5, 0.0)
	add_child(cs)
	area_entered.connect(_on_area_entered)
	queue_redraw()

func _on_area_entered(a: Area2D) -> void:
	if a is Ball:
		ball_entered.emit(side)

func hit_net(y: float, power: float) -> void:
	bulge = clampf(power / 40.0, 8.0, 30.0)
	bulge_y = y

func _process(delta: float) -> void:
	if bulge > 0.0:
		bulge = maxf(0.0, bulge - delta * 26.0)
		queue_redraw()

func _draw() -> void:
	var d := Pitch.GOAL_DEPTH
	var g := Pitch.GOAL_HALF
	var s := float(side)
	draw_rect(Rect2(Vector2(minf(0.0, s * d), -g), Vector2(d, g * 2.0)), Color(1, 1, 1, 0.10))
	var net := Color(1, 1, 1, 0.45)
	# lines running away from the goal line
	var y := -g + 12.0
	while y < g:
		var pts := PackedVector2Array()
		for i in range(0, 6):
			var dd := d * i / 5.0
			pts.append(Vector2(s * (dd + bulge * (dd / d) * exp(-pow((y - bulge_y) / 70.0, 2.0))), y))
		draw_polyline(pts, net, 1.5)
		y += 16.0
	# lines parallel to the goal line
	var dx := 14.0
	while dx <= d:
		var pts2 := PackedVector2Array()
		var yy := -g
		while yy <= g:
			pts2.append(Vector2(s * (dx + bulge * (dx / d) * exp(-pow((yy - bulge_y) / 70.0, 2.0))), yy))
			yy += 20.0
		draw_polyline(pts2, net, 1.5)
		dx += 14.0
	# frame
	draw_line(Vector2(0, -g), Vector2(s * d, -g), Color(0.95, 0.95, 0.95), 4.0)
	draw_line(Vector2(0, g), Vector2(s * d, g), Color(0.95, 0.95, 0.95), 4.0)
	draw_line(Vector2(s * d, -g), Vector2(s * d, g), Color(0.95, 0.95, 0.95), 4.0)
	draw_circle(Vector2(0, -g), 7.0, Color.WHITE)
	draw_circle(Vector2(0, g), 7.0, Color.WHITE)
