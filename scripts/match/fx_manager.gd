class_name FXManager
extends Node2D
## Pooled particle bursts and expanding rings. Reuses a fixed set of CPUParticles2D nodes.

var _pool: Array[CPUParticles2D] = []
var _rings: Array = []
var _ramp: Gradient

func _ready() -> void:
	_ramp = Gradient.new()
	_ramp.set_color(0, Color(1, 1, 1, 1))
	_ramp.set_color(1, Color(1, 1, 1, 0))
	for i in 24:
		var p := CPUParticles2D.new()
		p.emitting = false
		p.one_shot = true
		p.explosiveness = 0.95
		p.color_ramp = _ramp
		add_child(p)
		_pool.append(p)

func burst(pos: Vector2, color: Color, amount: int, speed: float, life: float = 0.5, spread: float = 180.0, dir: Vector2 = Vector2.UP, size: float = 4.0, gravity: Vector2 = Vector2.ZERO) -> void:
	var p: CPUParticles2D = null
	for q in _pool:
		if not q.emitting:
			p = q
			break
	if p == null:
		return
	p.position = pos
	p.amount = maxi(amount, 1)
	p.lifetime = life
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = gravity
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size
	p.color = color
	p.restart()
	p.emitting = true

func dust(pos: Vector2) -> void:
	burst(pos, Color(0.85, 0.8, 0.65, 0.6), 4, 60.0, 0.35, 180.0, Vector2.UP, 3.0)

func kick(pos: Vector2, strength: float) -> void:
	burst(pos, Color(1, 1, 0.9, 0.9), 5 + int(strength * 8.0), 120.0 + strength * 220.0, 0.35, 180.0, Vector2.UP, 3.0)
	if strength > 0.6:
		ring(pos, Color(1, 1, 1, 0.8), 30.0 + strength * 60.0, 0.3)

func goal_burst(pos: Vector2, c1: Color, c2: Color) -> void:
	for col: Color in [c1, c2, Color.WHITE, Color("#ffd23f")]:
		burst(pos + Vector2(randf_range(-90, 90), randf_range(-70, 70)), col, 26, 460.0, 1.3, 180.0, Vector2.UP, 5.0, Vector2(0, 420))
	ring(pos, Color(1, 1, 1, 0.9), 220.0, 0.7)

func ring(pos: Vector2, color: Color, radius: float, dur: float) -> void:
	_rings.append({"pos": pos, "color": color, "radius": radius, "t": 0.0, "dur": dur})

func _process(delta: float) -> void:
	if _rings.is_empty():
		return
	for r in _rings:
		r["t"] += delta
	_rings = _rings.filter(func(r: Dictionary) -> bool: return r["t"] < r["dur"])
	queue_redraw()

func _draw() -> void:
	for r in _rings:
		var k: float = r["t"] / r["dur"]
		var col: Color = r["color"]
		col.a *= 1.0 - k
		draw_arc(r["pos"], float(r["radius"]) * (0.25 + 0.75 * sqrt(k)), 0.0, TAU, 36, col, 4.0 * (1.0 - k) + 1.0)
