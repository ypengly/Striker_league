class_name PlayerStats
extends Resource
## Per-player attributes (35..99). Generated from team ratings + role.

@export var speed := 70
@export var acceleration := 70
@export var stamina := 70
@export var passing := 70
@export var shooting := 70
@export var dribbling := 70
@export var defense := 70
@export var strength := 70

static func generate(td: TeamData, role: int, rng: RandomNumberGenerator) -> PlayerStats:
	var s := PlayerStats.new()
	var a := float(td.attack)
	var m := float(td.midfield)
	var d := float(td.defense)
	var g := float(td.goalkeeper)
	match role:
		0:  # goalkeeper
			s.speed = _j(rng, 55.0 + g * 0.25); s.acceleration = _j(rng, 55.0 + g * 0.3)
			s.stamina = _j(rng, 75.0); s.passing = _j(rng, m * 0.75)
			s.shooting = _j(rng, 45.0); s.dribbling = _j(rng, 50.0)
			s.defense = _j(rng, g); s.strength = _j(rng, d * 0.9)
		1:  # defender
			s.speed = _j(rng, d * 0.75 + 15.0); s.acceleration = _j(rng, d * 0.8 + 10.0)
			s.stamina = _j(rng, d * 0.9); s.passing = _j(rng, m * 0.8)
			s.shooting = _j(rng, a * 0.5); s.dribbling = _j(rng, m * 0.7)
			s.defense = _j(rng, d * 1.05); s.strength = _j(rng, d)
		2:  # midfielder
			s.speed = _j(rng, m * 0.8 + 12.0); s.acceleration = _j(rng, m * 0.85 + 8.0)
			s.stamina = _j(rng, m * 1.05); s.passing = _j(rng, m * 1.05)
			s.shooting = _j(rng, a * 0.8); s.dribbling = _j(rng, m)
			s.defense = _j(rng, (d + m) * 0.45); s.strength = _j(rng, m * 0.85)
		3:  # winger
			s.speed = _j(rng, a * 0.9 + 12.0); s.acceleration = _j(rng, a * 0.95 + 5.0)
			s.stamina = _j(rng, m); s.passing = _j(rng, m * 0.9)
			s.shooting = _j(rng, a * 0.85); s.dribbling = _j(rng, a * 1.02)
			s.defense = _j(rng, d * 0.55); s.strength = _j(rng, a * 0.7)
		_:  # striker
			s.speed = _j(rng, a * 0.85 + 10.0); s.acceleration = _j(rng, a * 0.9 + 5.0)
			s.stamina = _j(rng, a * 0.85); s.passing = _j(rng, m * 0.7)
			s.shooting = _j(rng, a * 1.08); s.dribbling = _j(rng, a * 0.95)
			s.defense = _j(rng, d * 0.4); s.strength = _j(rng, a)
	return s

static func _j(rng: RandomNumberGenerator, v: float) -> int:
	return clampi(roundi(v + rng.randf_range(-4.0, 4.0)), 35, 99)
