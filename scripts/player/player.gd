class_name Player
extends CharacterBody2D
## A footballer. Human control and AI both drive the same movement / action code.
## Visuals live in PlayerVisual so placeholder art can be swapped for AnimatedSprite2D later.

enum Role { GK, DEF, MID, WING, STR }
enum AIState { IDLE, POSITIONING, CHASING_BALL, ATTACKING, DEFENDING, MARKING, PASSING, SHOOTING, TACKLING, RETURNING }
enum Anim { IDLE, RUN, SPRINT, SHOOT, PASS, TACKLE, CELEBRATE, HURT, DIVE }

const SPRINT_MULT := 1.3
const SHOT_MIN := 520.0
const SHOT_MAX := 1250.0
const CHARGE_TIME := 0.9
const ROLE_NAMES := ["GK", "DEF", "MID", "WING", "STR"]

var team: Team
var slot := 0
var role: int = Role.DEF
var stats: PlayerStats
var player_name := "Player"
var number := 0
var side := 1

var facing := Vector2.RIGHT
var move_input := Vector2.ZERO
var want_sprint := false
var is_sprinting := false
var is_human := false
var stamina := 100.0

var ai_state: int = AIState.IDLE
var anim: int = Anim.IDLE
var home_pos := Vector2.ZERO
var target_pos := Vector2.ZERO
var designation := ""
var mark_target: Player = null
var pos_noise := Vector2.ZERO
var think_timer := 0.0
var state_hold := 0.0

var kick_lock := 0.0
var stun := 0.0
var hold_time := 0.0
var lunge_time := 0.0
var lunge_dir := Vector2.RIGHT
var tackle_cd := 0.0
var recover_time := 0.0
var dive_time := 0.0
var dive_dir := Vector2.ZERO
var dive_speed := 0.0
var kick_anim := 0.0
var kick_kind: int = Anim.SHOOT
var celebrating := false
var charge := 0.0
var charging := false
var pass_preview: Player = null
var anim_time := 0.0
var visual: PlayerVisual
var _dust_t := 0.0

func setup(t: Team, p_slot: int, p_role: int, p_stats: PlayerStats, p_name: String, p_number: int) -> void:
	team = t
	slot = p_slot
	role = p_role
	stats = p_stats
	player_name = p_name
	number = p_number
	side = t.side
	facing = Vector2(side, 0)
	collision_layer = 1
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 13.0
	cs.shape = sh
	add_child(cs)
	visual = PlayerVisual.new()
	add_child(visual)
	visual.setup(self)
	pos_noise = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * (1.0 - float(t.ai.get("positioning", 1.0))) * 120.0
	think_timer = randf() * 0.2

func reset_state(pos: Vector2, s: int) -> void:
	position = pos
	velocity = Vector2.ZERO
	facing = Vector2(s, 0)
	stun = 0.0
	hold_time = 0.0
	lunge_time = 0.0
	dive_time = 0.0
	recover_time = 0.0
	kick_lock = 0.0
	kick_anim = 0.0
	celebrating = false
	charging = false
	charge = 0.0
	move_input = Vector2.ZERO
	ai_state = AIState.IDLE
	designation = ""
	mark_target = null
	stamina = minf(100.0, stamina + 20.0)
	think_timer = randf() * 0.2

# ---------------------------------------------------------------- stats helpers
func max_speed() -> float:
	var s := 160.0 + stats.speed * 1.35
	if not is_human:
		s *= float(team.ai.get("speed", 1.0))
	if stamina < 30.0:
		s *= 0.85 + 0.5 * stamina / 100.0
	if team.game.ball != null and team.game.ball.carrier == self:
		s *= 0.92 + stats.dribbling / 1300.0
	return s

func reach() -> float:
	return 21.0 + stats.defense * 0.06

func control_chance(ball_speed: float) -> float:
	var base := (stats.dribbling * 0.6 + stats.defense * 0.4) / 100.0
	return clampf(base * (1.3 - ball_speed / 1300.0), 0.05, 0.95)

func has_ball() -> bool:
	return team.game.ball.carrier == self

func can_kick() -> bool:
	var b := team.game.ball
	if stun > 0.0 or recover_time > 0.0 or not team.game.can_act():
		return false
	if b.carrier == self:
		return true
	return b.carrier == null and b.z < 30.0 and kick_lock <= 0.0 and position.distance_to(b.position) < 30.0

func lose_ball_control() -> void:
	var b := team.game.ball
	if b.carrier == self:
		b.knock(velocity.normalized() if velocity.length() > 5.0 else facing, maxf(velocity.length() * 1.05, 120.0))
		kick_lock = 0.2

# ---------------------------------------------------------------- main loop
func _physics_process(delta: float) -> void:
	if team == null:
		return
	var g := team.game
	anim_time += delta
	kick_lock = maxf(0.0, kick_lock - delta)
	stun = maxf(0.0, stun - delta)
	tackle_cd = maxf(0.0, tackle_cd - delta)
	kick_anim = maxf(0.0, kick_anim - delta)
	recover_time = maxf(0.0, recover_time - delta)
	state_hold = maxf(0.0, state_hold - delta)
	if not g.can_move():
		velocity = velocity.move_toward(Vector2.ZERO, 2500.0 * delta)
		if velocity.length() > 1.0:
			move_and_slide()
		_finish_frame()
		return
	if hold_time > 0.0:
		hold_time -= delta
		velocity = Vector2.ZERO
		_finish_frame()
		return
	_pre_move(delta)
	if is_human:
		_read_human_input(delta)
	else:
		_ai_tick(delta)
	_move(delta)
	_finish_frame()

func _pre_move(_delta: float) -> void:
	pass   # Goalkeeper overrides

func _move(delta: float) -> void:
	if stun > 0.0 or recover_time > 0.0:
		velocity = velocity.move_toward(Vector2.ZERO, 1800.0 * delta)
		is_sprinting = false
	elif lunge_time > 0.0:
		lunge_time -= delta
		velocity = lunge_dir * (max_speed() * 1.5)
		_check_tackle_contact()
		if lunge_time <= 0.0:
			recover_time = maxf(recover_time, 0.35)
	elif dive_time > 0.0:
		dive_time -= delta
		velocity = dive_dir * dive_speed
	else:
		var sprint := want_sprint and stamina > 8.0 and move_input.length() > 0.2
		is_sprinting = sprint
		var spd := max_speed() * (SPRINT_MULT if sprint else 1.0)
		var target_vel := move_input * spd
		var accel := 900.0 + stats.acceleration * 10.0
		var rate := accel if target_vel.length() >= velocity.length() * 0.9 else 1500.0
		var old_dir := velocity.normalized()
		velocity = velocity.move_toward(target_vel, rate * delta)
		_sharp_turn_check(old_dir)
		if sprint:
			stamina = maxf(0.0, stamina - 26.0 * (1.5 - stats.stamina / 100.0) * delta)
			_dust_t -= delta
			if _dust_t <= 0.0 and velocity.length() > 200.0:
				_dust_t = 0.16
				team.game.fx.dust(position + Vector2(0, 10))
		else:
			stamina = minf(100.0, stamina + (14.0 if velocity.length() < 20.0 else 7.0) * delta)
		if want_sprint and stamina <= 1.0:
			want_sprint = false
	move_and_slide()
	# turn to face movement direction
	var dir := move_input if is_human else velocity
	if lunge_time <= 0.0 and dive_time <= 0.0 and dir.length() > 0.15:
		var ang := facing.angle_to(dir.normalized())
		var maxturn := 14.0 * delta
		facing = facing.rotated(clampf(ang, -maxturn, maxturn))

## Sprinting and reversing direction while dribbling can lose the ball.
func _sharp_turn_check(old_dir: Vector2) -> void:
	if not is_sprinting or not has_ball() or old_dir == Vector2.ZERO or move_input.length() < 0.3:
		return
	if velocity.length() > 220.0 and absf(old_dir.angle_to(move_input)) > 2.0:
		if randf() < (1.0 - stats.dribbling / 130.0) * 0.5:
			lose_ball_control()

func _finish_frame() -> void:
	# animation state
	if celebrating:
		anim = Anim.CELEBRATE
	elif stun > 0.0:
		anim = Anim.HURT
	elif lunge_time > 0.0 or (recover_time > 0.0 and role != Role.GK):
		anim = Anim.TACKLE
	elif dive_time > 0.0 or (role == Role.GK and recover_time > 0.0):
		anim = Anim.DIVE
	elif kick_anim > 0.0:
		anim = kick_kind
	elif velocity.length() > 12.0:
		anim = Anim.SPRINT if is_sprinting else Anim.RUN
	else:
		anim = Anim.IDLE

# ---------------------------------------------------------------- human input
func _read_human_input(delta: float) -> void:
	var g := team.game
	move_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	want_sprint = Input.is_action_pressed("sprint")
	if not g.can_act():
		charging = false
		charge = 0.0
		return
	if Input.is_action_just_pressed("shoot") and can_kick():
		charging = true
		charge = 0.0
	if charging:
		charge = minf(1.0, charge + delta / CHARGE_TIME)
		if Input.is_action_just_released("shoot") or not Input.is_action_pressed("shoot"):
			charging = false
			if can_kick():
				shoot(maxf(charge, 0.12), _aim_dir())
			charge = 0.0
	if can_kick():
		pass_preview = pick_pass_target(_aim_dir())
	else:
		pass_preview = null
	if Input.is_action_just_pressed("pass") and can_kick():
		if pass_preview != null:
			pass_to(pass_preview, -1.0, false)
	if Input.is_action_just_pressed("tackle"):
		try_tackle()
	if Input.is_action_just_pressed("switch"):
		team.switch_player()

func _aim_dir() -> Vector2:
	var d := move_input.normalized() if move_input.length() > 0.2 else facing
	if GameState.aim_assist:
		var gx := side * Pitch.HALF_W
		if d.x * side > 0.15:
			var iy := position.y + d.y / d.x * (gx - position.x)
			if absf(iy) < Pitch.GOAL_HALF * 2.4:
				var aim := Vector2(gx, clampf(iy, -Pitch.GOAL_HALF * 0.85, Pitch.GOAL_HALF * 0.85))
				d = d.lerp((aim - position).normalized(), 0.5).normalized()
	return d

# ---------------------------------------------------------------- actions
func shoot(power: float, dir: Vector2, accuracy: float = -1.0) -> void:
	var g := team.game
	var b := g.ball
	var acc := accuracy if accuracy >= 0.0 else stats.shooting / 100.0
	var err := (1.0 - acc) * 0.22 * (0.6 + power * 0.8)
	var d := Vector2.from_angle(dir.angle() + randfn(0.0, err * 0.5))
	var speed := lerpf(SHOT_MIN, SHOT_MAX, power) * (0.86 + stats.shooting * 0.0016)
	var lift := 40.0 + power * power * 170.0 + randf() * 40.0 * (1.0 - acc)
	var curve := clampf(d.cross(velocity) / 220.0, -1.3, 1.3) * (0.5 + acc * 0.5)
	if not is_human:
		curve = randf_range(-0.5, 0.5)
	facing = d
	b.place(position + d * 16.0)
	b.kick(d, speed, lift, curve, self, true)
	kick_lock = 0.35
	kick_anim = 0.22
	kick_kind = Anim.SHOOT
	g.on_shot(self, power)

func pass_to(target: Player, accuracy: float = -1.0, lob: bool = false) -> void:
	var g := team.game
	var b := g.ball
	var acc := accuracy if accuracy >= 0.0 else stats.passing / 100.0
	var dist := position.distance_to(target.position)
	var speed := clampf(dist * 1.05 + 280.0, 450.0, 900.0)
	var lead := dist / (speed * 0.75)
	var aim := target.position + target.velocity * lead * 0.8 - position
	var d := Vector2.from_angle(aim.angle() + randfn(0.0, (1.0 - acc) * 0.16))
	var lift := 0.0
	if lob or dist > 560.0:
		lift = 190.0
	facing = d
	b.place(position + d * 16.0)
	b.kick(d, speed, lift, 0.0, self, false)
	b.pass_target = target
	b.last_passer = self
	b.last_pass_time = g.now()
	kick_lock = 0.3
	kick_anim = 0.18
	kick_kind = Anim.PASS
	team.stats["passes"] += 1

func try_tackle() -> bool:
	var g := team.game
	if role == Role.GK or tackle_cd > 0.0 or stun > 0.0 or lunge_time > 0.0 or recover_time > 0.0:
		return false
	if not g.can_act() or g.ball.carrier == self:
		return false
	var dir := facing
	var d := g.ball.position - position
	if d.length() < 170.0 and d.length() > 1.0 and absf(facing.angle_to(d)) < 1.2:
		dir = d.normalized()
	lunge_dir = dir
	facing = dir
	lunge_time = 0.26
	tackle_cd = 1.1
	AudioManager.play("pass", -6.0, 0.7)
	return true

func _check_tackle_contact() -> void:
	var g := team.game
	var b := g.ball
	if b.carrier != null and b.carrier.team != team:
		if position.distance_to(b.carrier.position) < 34.0:
			_resolve_tackle(b.carrier)
	elif b.carrier == null and b.z < 25.0 and position.distance_to(b.position) < 30.0:
		lunge_time = 0.05
		g.give_ball(self)

func _resolve_tackle(victim: Player) -> void:
	var g := team.game
	var atk := stats.defense * 0.6 + stats.strength * 0.4
	var dfn := victim.stats.dribbling * 0.6 + victim.stats.strength * 0.4
	var skill := 1.0 if is_human else float(team.ai.get("tackle", 1.0))
	var chance := clampf(0.5 + (atk - dfn) / 110.0, 0.15, 0.88) * skill
	lunge_time = 0.0
	if randf() < chance:
		team.stats["tackles"] += 1
		g.on_tackle(self, victim, true)
		victim.stun = 0.5
		victim.kick_lock = 0.5
		if randf() < 0.55:
			g.give_ball(self)
		else:
			g.ball.knock(lunge_dir + Vector2(randf_range(-0.4, 0.4), randf_range(-0.4, 0.4)), 380.0)
	else:
		recover_time = 0.6
		if randf() < 0.28:
			g.call_foul(self, victim)
		else:
			g.on_tackle(self, victim, false)

# ---------------------------------------------------------------- passing helpers
func _lane_danger(from: Vector2, to: Vector2) -> float:
	var worst := 999.0
	for o in team.game.opponent_of(team).players:
		var cp := Geometry2D.get_closest_point_to_segment(o.position, from, to)
		worst = minf(worst, cp.distance_to(o.position))
	return worst

## Human pass targeting: best teammate in the aim cone, favouring open lanes.
func pick_pass_target(dir: Vector2) -> Player:
	var best: Player = null
	var best_s := -1.0e9
	var nearest: Player = null
	var nearest_d := 1.0e9
	for m in team.players:
		if m == self:
			continue
		var to := m.position - position
		var d := to.length()
		if d < 50.0:
			continue
		if m.role != Role.GK and d < nearest_d:
			nearest_d = d
			nearest = m
		var ang := absf(dir.angle_to(to))
		if ang > 1.15:
			continue
		var s := (1.15 - ang) * 100.0 - d * 0.03
		if _lane_danger(position, m.position) < 40.0:
			s -= 25.0
		if m.role == Role.GK:
			s -= 30.0
		if s > best_s:
			best_s = s
			best = m
	return best if best != null else nearest

# ---------------------------------------------------------------- AI
func _ai_tick(delta: float) -> void:
	think_timer -= delta
	if think_timer <= 0.0:
		think_timer = float(team.ai.get("reaction", 0.2)) * randf_range(0.7, 1.3)
		_ai_think()
	var d := target_pos - position
	if d.length() < 6.0:
		move_input = Vector2.ZERO
	else:
		move_input = d.normalized() * clampf(d.length() / 50.0, 0.0, 1.0)

func _ai_think() -> void:
	var g := team.game
	var b := g.ball
	if not g.can_act():
		ai_state = AIState.POSITIONING
		target_pos = home_pos + pos_noise
		want_sprint = false
		return
	if state_hold > 0.0 and b.carrier != self:
		state_hold = 0.0
	if b.carrier == self:
		_think_with_ball()
		return
	want_sprint = false
	# incoming pass: run onto it
	if b.pass_target == self and b.carrier == null:
		ai_state = AIState.CHASING_BALL
		target_pos = b.predict_position(0.4)
		want_sprint = true
		return
	if designation == "chase":
		ai_state = AIState.CHASING_BALL
		target_pos = b.position + b.vel * 0.25
		want_sprint = position.distance_to(target_pos) > 120.0
		return
	if designation == "press":
		var c := b.carrier
		if c == null:
			designation = ""
			return
		target_pos = c.position + c.velocity * 0.2
		var dd := position.distance_to(c.position)
		want_sprint = dd > 110.0
		if dd < 60.0:
			ai_state = AIState.TACKLING
			if tackle_cd <= 0.0 and randf() < float(team.ai.get("aggression", 0.7)) * 0.6:
				facing = (c.position - position).normalized()
				try_tackle()
		else:
			ai_state = AIState.CHASING_BALL
		return
	if b.carrier != null and b.carrier.team == team:
		ai_state = AIState.ATTACKING
		target_pos = _support_target()
		want_sprint = position.distance_to(target_pos) > 260.0
	elif b.carrier != null:
		if mark_target != null:
			ai_state = AIState.MARKING
			var own_goal := Vector2(-side * Pitch.HALF_W, 0.0)
			var back := (own_goal - mark_target.position).normalized()
			var gap := 40.0 + (1.0 - float(team.ai.get("positioning", 1.0))) * 80.0
			target_pos = mark_target.position + back * gap
		else:
			ai_state = AIState.DEFENDING
			target_pos = home_pos + pos_noise
	else:
		ai_state = AIState.POSITIONING
		target_pos = home_pos + pos_noise
	if position.distance_to(target_pos) > 420.0 and ai_state == AIState.POSITIONING:
		ai_state = AIState.RETURNING
		want_sprint = true
	target_pos = Pitch.clamp_to_pitch(target_pos, 20.0)

func _support_target() -> Vector2:
	var base := home_pos + Vector2(side * 60.0, 0.0)
	if role == Role.STR:
		base.x += side * 60.0
	var offsets: Array[Vector2] = [Vector2.ZERO, Vector2(0, -90), Vector2(0, 90), Vector2(80.0 * side, 0), Vector2(-60.0 * side, 0)]
	var best := base
	var best_s := -1.0e9
	var opps := team.game.opponent_of(team).players
	for off in offsets:
		var c := Pitch.clamp_to_pitch(base + off, 40.0)
		var nearest := 200.0
		for o in opps:
			nearest = minf(nearest, o.position.distance_to(c))
		var s := nearest - c.distance_to(home_pos) * 0.15
		if s > best_s:
			best_s = s
			best = c
	return best

func _think_with_ball() -> void:
	var g := team.game
	var ai := team.ai
	var goal := Vector2(side * Pitch.HALF_W, 0.0)
	var dist_goal := position.distance_to(goal)
	var pressure := g.nearest_opponent_dist(self)
	var gk := g.opponent_of(team).goalkeeper
	want_sprint = false
	# --- shoot?
	var range_mult := 1.0 if (role == Role.STR or role == Role.WING) else 0.75
	var shoot_range := (330.0 + stats.shooting * 4.2) * float(ai.get("shot_range", 1.0)) * range_mult
	if dist_goal < shoot_range and position.x * side > 200.0:
		var aim_y := (-1.0 if gk.position.y > 0.0 else 1.0) * Pitch.GOAL_HALF * randf_range(0.45, 0.85)
		if absf(gk.position.y) < 15.0 and randf() < 0.5:
			aim_y = -aim_y
		var aim := Vector2(goal.x, aim_y)
		if _lane_danger(position, aim) > 30.0 or dist_goal < 260.0:
			if randf() < 0.55 + 0.4 * (1.0 - dist_goal / shoot_range):
				var acc := float(ai.get("shot_acc", 0.8)) * clampf(stats.shooting / 85.0, 0.5, 1.1)
				ai_state = AIState.SHOOTING
				shoot(randf_range(0.55, 0.95) * (0.7 + 0.3 * float(ai.get("shot_acc", 0.8))), aim - position, clampf(acc, 0.1, 1.0))
				return
	# --- pass?
	var best := _best_pass_option()
	var opt: Player = best["player"]
	var score: float = best["score"]
	var do_pass := false
	if opt != null:
		if pressure < 85.0:
			do_pass = randf() < 0.75
		elif score > 95.0:
			do_pass = randf() < 0.35
		elif score > 70.0:
			do_pass = randf() < 0.08
	if do_pass:
		ai_state = AIState.PASSING
		pass_to(opt, float(ai.get("pass_acc", 0.8)) * clampf(stats.passing / 85.0, 0.5, 1.1), false)
		return
	# --- dribble towards goal, steering around opponents
	ai_state = AIState.ATTACKING
	var dir := (goal - position).normalized()
	for o in g.opponent_of(team).players:
		var dv := o.position - position
		var dl := dv.length()
		if dl < 170.0 and dv.dot(dir) > 0.0:
			dir -= dv.normalized() * (1.0 - dl / 170.0) * 1.1
	dir = dir.normalized()
	target_pos = Pitch.clamp_to_pitch(position + dir * 400.0, 30.0)
	want_sprint = pressure > 100.0 and stamina > 25.0

func _best_pass_option() -> Dictionary:
	var g := team.game
	var goal := Vector2(side * Pitch.HALF_W, 0.0)
	var noise := (1.0 - float(team.ai.get("positioning", 1.0))) * 40.0
	var best: Player = null
	var best_s := -1.0e9
	for m in team.players:
		if m == self:
			continue
		var d := position.distance_to(m.position)
		if d < 70.0 or d > 900.0:
			continue
		var s := 50.0
		s += (m.position.x - position.x) * side * 0.06
		s -= absf(d - 380.0) * 0.03
		var lane := _lane_danger(position, m.position)
		s += -45.0 if lane < 45.0 else minf(lane, 120.0) * 0.1
		var open := 200.0
		for o in g.opponent_of(team).players:
			open = minf(open, o.position.distance_to(m.position))
		s += open * 0.15
		s += (1.0 - m.position.distance_to(goal) / 2200.0) * 30.0
		if m.role == Role.GK:
			s -= 40.0
		s += randf_range(-1.0, 1.0) * noise
		if s > best_s:
			best_s = s
			best = m
	return {"player": best, "score": best_s}
