class_name Goalkeeper
extends Player
## Goalkeeper AI: tracks the ball on an arc, predicts shots, dives, catches slow shots,
## parries hard ones, recovers, comes out for loose balls, and distributes after a catch.
## Reaction time and save chance scale with the team's goalkeeper rating (and the difficulty multiplier).

enum GKState { TRACK, DIVE, RECOVER, HOLD, COLLECT }

var gk_state: int = GKState.TRACK
var shot_pending := false
var dive_used := false
var predicted := Vector2.ZERO
var react_timer := 0.0
var attempt_cd := 0.0
var hold_t := 0.0
var _think_t := 0.0
var _was_diving := false

func skill() -> float:
	return team.data.goalkeeper * team.gk_mult

func goal_center() -> Vector2:
	return Vector2(-side * Pitch.HALF_W, 0.0)

func _ai_tick(delta: float) -> void:
	_think_t -= delta
	if _think_t <= 0.0:
		_think_t = 0.05
		_ai_think()
	var d := target_pos - position
	move_input = Vector2.ZERO if d.length() < 4.0 else d.normalized() * clampf(d.length() / 30.0, 0.0, 1.0)

func _ai_think() -> void:
	var g := team.game
	var b := g.ball
	var gc := goal_center()
	var inward := Vector2(side, 0.0)
	want_sprint = false
	if b.carrier == self:
		target_pos = position
		return
	if not g.can_act():
		target_pos = gc + inward * 40.0
		return
	# --- shot detection
	if b.carrier == null and b.vel.length() > 320.0 and b.vel.x * -side > 0.0:
		var line_x := gc.x + inward.x * 20.0
		var pr := b.predict_x_cross(line_x)
		if not pr.is_empty() and absf(float(pr["y"])) < Pitch.GOAL_HALF + 60.0:
			if not shot_pending:
				shot_pending = true
				dive_used = false
				react_timer = lerpf(0.34, 0.06, clampf((skill() - 50.0) / 50.0, 0.0, 1.0))
			predicted = Vector2(line_x, float(pr["y"]))
	else:
		shot_pending = false
	if shot_pending:
		ai_state = AIState.DEFENDING
		if react_timer <= 0.0:
			target_pos = Vector2(position.x, clampf(predicted.y, -Pitch.GOAL_HALF + 10.0, Pitch.GOAL_HALF - 10.0))
			want_sprint = true
		return
	# --- come out for loose balls in the box
	var dgk := position.distance_to(b.position)
	if b.carrier == null and b.vel.length() < 250.0 and absf(b.position.x - gc.x) < Pitch.PEN_DEPTH - 40.0 \
			and absf(b.position.y) < Pitch.PEN_HALF - 40.0 and dgk < 230.0 and g.nearest_opponent_to(b.position) > dgk:
		gk_state = GKState.COLLECT
		target_pos = b.position
		want_sprint = true
		return
	gk_state = GKState.TRACK
	ai_state = AIState.POSITIONING
	var bd := b.position - gc
	var arc_r := 55.0 + minf(bd.length() * 0.02, 25.0)
	var tp := gc + bd.normalized() * arc_r if bd.length() > 1.0 else gc + inward * 50.0
	tp.y = clampf(tp.y, -Pitch.GOAL_HALF + 14.0, Pitch.GOAL_HALF - 14.0)
	target_pos = tp

func _pre_move(delta: float) -> void:
	var g := team.game
	var b := g.ball
	attempt_cd = maxf(0.0, attempt_cd - delta)
	if shot_pending:
		react_timer -= delta
	if _was_diving and dive_time <= 0.0:
		recover_time = lerpf(1.0, 0.45, clampf(skill() / 100.0, 0.0, 1.0))
	_was_diving = dive_time > 0.0
	if b.carrier == self:
		gk_state = GKState.HOLD
		hold_t += delta
		if hold_t > 1.3 and g.can_act():
			_distribute()
		return
	hold_t = 0.0
	if shot_pending and react_timer <= 0.0 and not dive_used and dive_time <= 0.0 and recover_time <= 0.0:
		_commit_dive()
	if b.carrier == null and attempt_cd <= 0.0 and b.z < Pitch.CROSSBAR_H + 10.0 and g.can_act():
		var r := (56.0 if dive_time > 0.0 else 30.0) + skill() * 0.12
		if position.distance_to(b.position) < r and b.vel.length() > 200.0 and b.vel.x * -side > 0.0:
			_attempt_save()

func _commit_dive() -> void:
	dive_used = true
	var dy := predicted.y - position.y
	if absf(dy) < 40.0:
		return   # can simply step across
	dive_dir = Vector2(side * 0.25, signf(dy)).normalized()
	dive_time = 0.4
	dive_speed = clampf((absf(dy) + 24.0) / 0.4, 250.0, 700.0)
	gk_state = GKState.DIVE

func _attempt_save() -> void:
	attempt_cd = 0.5
	var g := team.game
	var b := g.ball
	var speed := b.vel.length()
	var d := position.distance_to(b.position)
	var p := 0.86 + (skill() - 70.0) / 120.0 - speed / 2100.0 + (1.0 - clampf(d / 40.0, 0.0, 1.0)) * 0.2
	p = clampf(p, 0.08, 0.95)
	if randf() < p:
		g.on_save(self, speed)
		if speed < 560.0 + skill() * 3.0:
			b.set_carrier(self)
		else:
			var n := (b.position - position).normalized()
			if n == Vector2.ZERO:
				n = Vector2(side, 0.0)
			b.vel = b.vel.bounce(n) * 0.35 + Vector2(side * 120.0, randf_range(-260.0, 260.0))
			b.vz = 120.0
			b.z = 4.0
			b.last_toucher = self
			b.last_team = team
			kick_lock = 0.3

func _distribute() -> void:
	hold_t = 0.0
	var g := team.game
	var t := pick_pass_target(Vector2(side, randf_range(-0.7, 0.7)).normalized())
	if t != null:
		pass_to(t, 0.9, true)
	else:
		facing = Vector2(side, 0.0)
		g.ball.place(position + facing * 16.0)
		g.ball.kick(facing.rotated(randf_range(-0.4, 0.4)), 800.0, 150.0, 0.0, self, false)
