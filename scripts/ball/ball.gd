class_name Ball
extends Area2D
## The football. Custom arcade physics (velocity, drag, spin curve, simulated height + bounce).
## It is an Area2D on physics layer 2 so goals can detect it. Carried balls follow their carrier
## with a spring, so dribbling feels loose rather than glued.

signal kicked(kicker: Player, speed: float, is_shot: bool)
signal bounced(pos: Vector2, strength: float)
signal post_hit(pos: Vector2)
signal possession_changed(new_carrier: Player)

const RADIUS := 9.0
const GRAVITY := 950.0
const BOUNCE := 0.52
const DRAG_GROUND := 0.5
const DRAG_AIR := 0.18
const ROLL_FRICTION := 42.0
const POST_R := 7.0

var vel := Vector2.ZERO
var z := 0.0
var vz := 0.0
var spin := 0.0                 # rad/s the velocity vector is rotated by (curve)
var carrier: Player = null
var last_toucher: Player = null
var last_team: Team = null
var pass_target: Player = null
var last_passer: Player = null
var last_pass_time := -100.0
var frozen := true
var roll := 0.0

var _trail: Line2D
var _trail_pts: Array[Vector2] = []

func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	monitoring = false
	monitorable = true
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = RADIUS
	cs.shape = sh
	add_child(cs)
	_trail = Line2D.new()
	_trail.top_level = true
	_trail.z_index = -1
	_trail.width = 10.0
	_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.0))
	g.set_color(1, Color(1, 1, 1, 0.55))
	_trail.gradient = g
	add_child(_trail)

# ---------------------------------------------------------------- control
func place(pos: Vector2) -> void:
	position = pos
	vel = Vector2.ZERO
	z = 0.0
	vz = 0.0
	spin = 0.0
	_trail_pts.clear()

func set_carrier(p: Player) -> void:
	var changed := carrier != p
	carrier = p
	last_toucher = p
	last_team = p.team
	pass_target = null
	vel = Vector2.ZERO
	z = 0.0
	vz = 0.0
	spin = 0.0
	if changed:
		possession_changed.emit(p)

func kick(dir: Vector2, speed: float, lift: float, curve: float, kicker: Player, is_shot: bool) -> void:
	carrier = null
	vel = dir.normalized() * speed
	if lift > 0.0:
		z = maxf(z, 2.0)
		vz = lift
	else:
		vz = 0.0
	spin = curve
	pass_target = null
	if kicker != null:
		last_toucher = kicker
		last_team = kicker.team
	kicked.emit(kicker, speed, is_shot)

## Knocks the ball loose (tackles, deflections) without treating it as a deliberate kick.
func knock(dir: Vector2, speed: float) -> void:
	carrier = null
	vel = dir.normalized() * speed
	spin = 0.0

## Where the ball will be in t seconds (ground movement only, ignores spin).
func predict_position(t: float) -> Vector2:
	return position + vel * ((1.0 - exp(-DRAG_GROUND * t)) / DRAG_GROUND)

## Simulates flight until the ball crosses x = x_target. Returns {} if it never does within 2.5 s.
func predict_x_cross(x_target: float) -> Dictionary:
	var p := position
	var v := vel
	var zz := z
	var vzz := vz
	var t := 0.0
	while t < 2.5:
		if (v.x > 0.0 and p.x >= x_target) or (v.x < 0.0 and p.x <= x_target):
			return {"t": t, "y": p.y, "z": zz}
		v *= exp(-(DRAG_AIR if zz > 0.0 else DRAG_GROUND) * 0.03)
		p += v * 0.03
		vzz -= GRAVITY * 0.03
		zz += vzz * 0.03
		if zz < 0.0:
			zz = 0.0
			vzz = absf(vzz) * BOUNCE
		t += 0.03
	return {}

# ---------------------------------------------------------------- simulation
func _physics_process(delta: float) -> void:
	if frozen:
		queue_redraw()
		return
	if carrier != null:
		_update_carried(delta)
	else:
		_update_free(delta)
	roll += vel.length() * delta * 0.08
	_update_trail()
	queue_redraw()

func _update_carried(delta: float) -> void:
	var c := carrier
	var speed_ratio := clampf(c.velocity.length() / maxf(c.max_speed(), 1.0), 0.0, 1.3)
	var dist := 28.0 + (16.0 if c.is_sprinting else 0.0)
	dist += sin(c.anim_time * 9.0) * 5.0 * speed_ratio   # little "touches" while running
	var target := c.position + c.facing * dist
	var k := 12.0 + c.stats.dribbling * 0.05
	var old := position
	position = position.lerp(target, 1.0 - exp(-k * delta))
	vel = ((position - old) / maxf(delta, 0.0001)).limit_length(900.0)
	z = 0.0
	vz = 0.0
	if position.distance_to(c.position) > 56.0 + c.stats.dribbling * 0.1:
		c.lose_ball_control()

func _update_free(delta: float) -> void:
	if spin != 0.0 and vel.length() > 60.0:
		vel = vel.rotated(spin * delta)
		spin = move_toward(spin, 0.0, 1.1 * delta)
	if z > 0.0 or vz != 0.0:
		vz -= GRAVITY * delta
		z += vz * delta
		if z <= 0.0:
			z = 0.0
			if absf(vz) > 130.0:
				bounced.emit(position, absf(vz))
				vz = -vz * BOUNCE
				vel *= 0.93
			else:
				vz = 0.0
	vel *= exp(-(DRAG_AIR if z > 0.0 else DRAG_GROUND) * delta)
	if z <= 0.0:
		var sp := vel.length()
		if sp > 0.0:
			vel = vel * (maxf(sp - ROLL_FRICTION * delta, 0.0) / sp)
	if vel.length() < 5.0 and z <= 0.0:
		vel = Vector2.ZERO
	position += vel * delta
	_collide_posts()

func _collide_posts() -> void:
	for s: int in [-1, 1]:
		for sy: int in [-1, 1]:
			var pp := Vector2(s * Pitch.HALF_W, sy * Pitch.GOAL_HALF)
			var d := position - pp
			var dist := d.length()
			if dist < POST_R + RADIUS and z < Pitch.CROSSBAR_H:
				var n := d.normalized() if dist > 0.01 else Vector2(-s, 0)
				position = pp + n * (POST_R + RADIUS + 0.5)
				if vel.dot(n) < 0.0:
					vel = vel.bounce(n) * 0.72
					post_hit.emit(pp)

func _update_trail() -> void:
	if vel.length() > 420.0:
		_trail_pts.append(position)
		if _trail_pts.size() > 16:
			_trail_pts.pop_front()
	elif not _trail_pts.is_empty():
		_trail_pts.pop_front()
	_trail.points = PackedVector2Array(_trail_pts)

func _draw() -> void:
	var sh := 1.0 - minf(z / 140.0, 0.6)
	draw_set_transform(Vector2(0, 3), 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, RADIUS * sh + 1.0, Color(0, 0, 0, 0.35 * sh))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var c := Vector2(0.0, -z * 0.55 - 5.0)
	draw_circle(c, RADIUS, Color.WHITE)
	var pts := PackedVector2Array()
	for i in 5:
		pts.append(c + Vector2.from_angle(roll + TAU * i / 5.0) * 4.2)
	draw_colored_polygon(pts, Color(0.1, 0.1, 0.13))
	draw_arc(c, RADIUS, 0.0, TAU, 20, Color(0.2, 0.2, 0.25), 1.5)
