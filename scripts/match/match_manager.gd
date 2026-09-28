class_name MatchManager
extends Node2D
## Owns the whole match: world setup, state machine (kickoff / play / goal / restart / half-time / full-time),
## timer, score, possession, out-of-play handling, fouls, extra time and hand-off to penalties.

enum State { INTRO, KICKOFF, PLAYING, GOAL, RESTART, HALFTIME, FULLTIME }

const GOAL_TIME := 3.4

var state: int = State.INTRO
var state_timer := 0.0
var teams: Array[Team] = []
var ball: Ball
var actors: Node2D
var crowd: Crowd
var fx: FXManager
var camera: MatchCamera
var hud: MatchHUD
var goals: Array[Goal] = []
var score: Array[int] = [0, 0]
var period := 1                    # 1, 2 = halves, 3 = extra time
var period_time := 0.0
var match_len := 90.0
var half_len := 45.0
var et_len := 30.0
var restart_taker: Player = null
var last_shot_team: Team = null
var last_shot_time := -100.0
var goal_log: Array[String] = []
var _goal_side := 1
var _finished := false

func _ready() -> void:
	match_len = GameState.match_length
	half_len = match_len * 0.5
	et_len = match_len * 0.34
	_build_world()
	_build_teams()
	_build_ui()
	AudioManager.start_ambience()
	AudioManager.play_music(true)
	_setup_kickoff(teams[0])
	state = State.INTRO
	state_timer = 2.6
	hud.notify("KICK OFF", Color("#19d3a2"), 96, "%s  vs  %s" % [teams[0].data.team_name, teams[1].data.team_name])
	camera.snap()

func _exit_tree() -> void:
	AudioManager.stop_ambience()

# ---------------------------------------------------------------- setup
func _build_world() -> void:
	var pitch := Pitch.new()
	pitch.z_index = -10
	add_child(pitch)
	crowd = Crowd.new()
	crowd.z_index = -9
	add_child(crowd)
	for s in [-1, 1]:
		var gl := Goal.new()
		add_child(gl)
		gl.setup(s)
		gl.z_index = 2
		gl.ball_entered.connect(_on_goal_entered)
		goals.append(gl)
	actors = Node2D.new()
	actors.y_sort_enabled = true
	add_child(actors)
	ball = Ball.new()
	actors.add_child(ball)
	ball.kicked.connect(_on_ball_kicked)
	ball.post_hit.connect(_on_post_hit)
	ball.bounced.connect(_on_ball_bounced)
	ball.possession_changed.connect(_on_possession_changed)
	fx = FXManager.new()
	fx.z_index = 5
	add_child(fx)
	camera = MatchCamera.new()
	add_child(camera)
	camera.setup(self)

func _build_teams() -> void:
	var hi := GameState.player_team_idx
	var ai_idx := GameState.opponent_team_idx
	if hi == ai_idx:
		ai_idx = (hi + 1) % GameState.teams.size()
	var hd := GameState.get_team(hi)
	var ad := GameState.get_team(ai_idx)
	var away_p := ad.primary
	var away_s := ad.secondary
	if _color_dist(hd.primary, away_p) < 0.45:
		away_p = ad.secondary
		away_s = ad.primary
	var home := Team.new()
	home.setup(self, hd, 1, true, GameState.player_formation, GameState.ai_params(1), hd.primary, hd.secondary)
	var away := Team.new()
	away.setup(self, ad, -1, false, GameState.opponent_formation, GameState.ai_params(GameState.difficulty), away_p, away_s)
	teams = [home, away]
	for t in teams:
		t.spawn_players(actors)
	home.set_controlled(home.kickoff_taker())
	crowd.setup(home.kit_primary, away.kit_primary)

func _color_dist(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()

func _build_ui() -> void:
	hud = MatchHUD.new()
	add_child(hud)
	hud.setup(self)
	if GameState.touch_mode == 1 or (GameState.touch_mode == 0 and DisplayServer.is_touchscreen_available()):
		var mc := MobileControls.new()
		add_child(mc)

# ---------------------------------------------------------------- helpers used by players / HUD
func now() -> float:
	return Time.get_ticks_msec() / 1000.0

func can_move() -> bool:
	return state == State.PLAYING or state == State.RESTART

func can_act() -> bool:
	return state == State.PLAYING

func opponent_of(t: Team) -> Team:
	return teams[1] if t == teams[0] else teams[0]

func nearest_opponent_dist(p: Player) -> float:
	var best := 9999.0
	for o in opponent_of(p.team).players:
		best = minf(best, o.position.distance_to(p.position))
	return best

func nearest_opponent_to(pos: Vector2) -> float:
	var best := 9999.0
	for o in teams[0].players + teams[1].players:
		best = minf(best, o.position.distance_to(pos))
	return best

func human_pass_target() -> Player:
	var c := teams[0].controlled
	return c.pass_preview if c != null else null

func clock_seconds() -> int:
	var base := 0.0
	var length := half_len
	if period == 2:
		base = half_len
	elif period == 3:
		base = match_len
		length = et_len
	return int((base + minf(period_time, length)) / match_len * 5400.0)

func clock_text() -> String:
	var s := clock_seconds()
	return "%02d:%02d" % [s / 60, s % 60]

func period_text() -> String:
	return ["1ST HALF", "2ND HALF", "EXTRA TIME"][period - 1]

# ---------------------------------------------------------------- main loop
func _physics_process(delta: float) -> void:
	match state:
		State.INTRO, State.KICKOFF:
			state_timer -= delta
			if state_timer <= 0.0:
				_begin_play(true)
		State.PLAYING:
			_tick_play(delta)
		State.GOAL:
			state_timer -= delta
			_constrain_ball_in_net()
			if state_timer <= 0.0:
				_after_goal()
		State.RESTART:
			state_timer -= delta
			if state_timer <= 0.0:
				_begin_play(false)
		State.HALFTIME:
			state_timer -= delta
			if state_timer <= 0.0 or Input.is_action_just_pressed("shoot"):
				_start_second_half()
	if state == State.PLAYING or state == State.RESTART:
		for t in teams:
			t.update(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and state != State.FULLTIME:
		hud.toggle_pause()

func _begin_play(whistle: bool) -> void:
	state = State.PLAYING
	ball.frozen = false
	if whistle:
		AudioManager.play("whistle")
	if restart_taker != null:
		restart_taker.hold_time = 0.0
		restart_taker.think_timer = 0.0
		restart_taker = null

func _tick_play(delta: float) -> void:
	period_time += delta
	if ball.carrier != null:
		ball.carrier.team.stats["possession"] += delta
	_update_possession(delta)
	_check_bounds()
	if state != State.PLAYING:
		return
	var limit := et_len if period == 3 else half_len
	if period_time >= limit:
		_end_period()

# ---------------------------------------------------------------- possession
func give_ball(p: Player) -> void:
	ball.set_carrier(p)

func _update_possession(delta: float) -> void:
	var c := ball.carrier
	if c != null:
		# pressure steal chance: opponents touching the ball while the carrier is under pressure
		for o in opponent_of(c.team).players:
			if o.stun > 0.0 or o.kick_lock > 0.0 or o.lunge_time > 0.0 or o.role == Player.Role.GK:
				continue
			if o.position.distance_to(ball.position) < 22.0:
				var per_sec := clampf(0.35 + (o.stats.defense - c.stats.dribbling) / 150.0, 0.05, 0.9)
				per_sec *= 0.6 if o.is_human else float(o.team.ai.get("tackle", 1.0))
				if randf() < per_sec * delta:
					c.stun = 0.3
					c.kick_lock = 0.4
					on_tackle(o, c, true)
					give_ball(o)
					return
		return
	if ball.z > 26.0:
		return
	var speed := ball.vel.length()
	var best: Player = null
	var bd := 1.0e9
	for t in teams:
		for p in t.players:
			if p.kick_lock > 0.0 or p.stun > 0.0 or p.hold_time > 0.0 or p.recover_time > 0.0:
				continue
			if p.role == Player.Role.GK and speed > 380.0:
				continue
			var d := p.position.distance_to(ball.position)
			if d < p.reach() + (12.0 if p.role == Player.Role.GK else 0.0) and d < bd:
				bd = d
				best = p
	if best == null:
		return
	if speed > 620.0 and randf() > best.control_chance(speed):
		ball.vel = ball.vel.rotated(randf_range(-0.7, 0.7)) * 0.55
		best.kick_lock = 0.2
		AudioManager.play("pass", -8.0, 1.2)
		return
	give_ball(best)

func _on_possession_changed(p: Player) -> void:
	if p.team.is_human and p.role != Player.Role.GK:
		p.team.set_controlled(p)

# ---------------------------------------------------------------- ball events
func _on_ball_kicked(kicker: Player, speed: float, is_shot: bool) -> void:
	AudioManager.play("kick" if is_shot else "pass", clampf(-9.0 + speed / 130.0, -9.0, 3.0))
	var strength := clampf((speed - 400.0) / 900.0, 0.0, 1.0)
	fx.kick(ball.position, strength)
	if is_shot and speed > 1000.0:
		camera.shake(4.0 + strength * 4.0)
		AudioManager.set_excitement(0.6)

func _on_post_hit(pos: Vector2) -> void:
	AudioManager.play("post")
	AudioManager.ooh()
	camera.shake(5.0)
	fx.ring(pos, Color(1, 1, 1, 0.9), 40.0, 0.3)
	hud.notify("OFF THE POST!", Color("#ffd23f"), 60)

func _on_ball_bounced(pos: Vector2, strength: float) -> void:
	AudioManager.play("pass", -14.0, 0.6)
	fx.dust(pos)

func on_shot(shooter: Player, _power: float) -> void:
	shooter.team.stats["shots"] += 1
	last_shot_team = shooter.team
	last_shot_time = now()
	var pr := ball.predict_x_cross(shooter.side * Pitch.HALF_W)
	if not pr.is_empty() and absf(float(pr["y"])) < Pitch.GOAL_HALF and float(pr["z"]) < Pitch.CROSSBAR_H:
		shooter.team.stats["on_target"] += 1

func on_save(gk: Player, speed: float) -> void:
	gk.team.stats["saves"] += 1
	AudioManager.play("save")
	AudioManager.cheer(0.5)
	fx.ring(gk.position, Color(0.4, 0.9, 1.0, 0.9), 70.0, 0.35)
	camera.shake(4.0)
	hud.notify("WHAT A SAVE!" if speed > 650.0 else "SAVED!", Color("#4fd8ff"), 72)

func on_tackle(tackler: Player, victim: Player, success: bool) -> void:
	AudioManager.play("tackle", 0.0 if success else -6.0)
	fx.dust(victim.position)
	if success:
		fx.ring(victim.position, Color(1, 0.7, 0.3, 0.8), 40.0, 0.25)

func call_foul(fouler: Player, victim: Player) -> void:
	fouler.team.stats["fouls"] += 1
	AudioManager.play("whistle")
	hud.notify("FOUL!", Color("#ff5c5c"), 84, "%s on %s" % [fouler.player_name, victim.player_name])
	var spot := Pitch.clamp_to_pitch(victim.position, 30.0)
	_start_restart("FREE KICK", victim.team, spot, victim)

# ---------------------------------------------------------------- goals
func _on_goal_entered(goal_side: int) -> void:
	_register_goal(goal_side)

func _register_goal(goal_side: int) -> void:
	if state != State.PLAYING or ball.z > Pitch.CROSSBAR_H:
		return
	var scoring: Team = teams[0] if teams[0].side == goal_side else teams[1]
	var idx := 0 if scoring == teams[0] else 1
	score[idx] += 1
	_goal_side = goal_side
	var scorer := ball.last_toucher
	var own_goal := scorer != null and scorer.team != scoring
	var assist: Player = null
	if not own_goal and scorer != null and ball.last_passer != null and ball.last_passer != scorer \
			and ball.last_passer.team == scoring and now() - ball.last_pass_time < 6.0:
		assist = ball.last_passer
	state = State.GOAL
	state_timer = GOAL_TIME
	var who := "OWN GOAL" if own_goal else (scorer.player_name if scorer != null else "")
	var sub := "%s  #%d   %s" % [who, scorer.number if scorer != null else 0, clock_text()]
	if assist != null:
		sub += "\nAssist: %s" % assist.player_name
	goal_log.append("%s %s  %s" % [clock_text(), who, "(%s)" % scoring.data.short_name])
	for p in scoring.players:
		p.celebrating = true
	var goal_node := goals[0] if goal_side < 0 else goals[1]
	goal_node.hit_net(ball.position.y, ball.vel.length())
	var gp := Vector2(goal_side * (Pitch.HALF_W + 30.0), ball.position.y)
	fx.goal_burst(gp, scoring.kit_primary, scoring.kit_secondary)
	camera.shake(16.0)
	camera.punch_zoom(0.06)
	crowd.excitement = 1.0
	AudioManager.play("goal")
	AudioManager.cheer(1.0)
	hud.flash(Color(1, 1, 1))
	hud.notify("GOAL!", scoring.kit_primary.lightened(0.35) if scoring.kit_primary.get_luminance() < 0.3 else scoring.kit_primary, 130, sub)

func _constrain_ball_in_net() -> void:
	var s := float(_goal_side)
	var ax := clampf(absf(ball.position.x), Pitch.HALF_W - 4.0, Pitch.HALF_W + Pitch.GOAL_DEPTH - 10.0)
	ball.position = Vector2(s * ax, clampf(ball.position.y, -Pitch.GOAL_HALF + 9.0, Pitch.GOAL_HALF - 9.0))
	ball.vel *= 0.94

func _after_goal() -> void:
	var conceding := teams[1] if (teams[0].side == _goal_side) else teams[0]
	for t in teams:
		for p in t.players:
			p.celebrating = false
	_setup_kickoff(conceding)

# ---------------------------------------------------------------- restarts
func _setup_kickoff(kicking: Team) -> void:
	ball.frozen = true
	ball.carrier = null
	ball.place(Vector2.ZERO)
	for t in teams:
		t.reset_for_kickoff(t == kicking)
	var kicker := kicking.kickoff_taker()
	kicker.position = Vector2(-kicking.side * 18.0, 0.0)
	ball.set_carrier(kicker)
	ball.position = kicker.position + kicker.facing * 28.0
	for t in teams:
		if t.is_human and t != kicking:
			t.set_controlled(t.nearest_outfield_to(Vector2.ZERO))
	state = State.KICKOFF
	state_timer = 1.5
	camera.punch_zoom(0.0)

func _start_restart(kind: String, taking: Team, spot: Vector2, taker: Player = null) -> void:
	state = State.RESTART
	state_timer = 1.1
	ball.frozen = true
	ball.carrier = null
	ball.place(spot)
	if taker == null or taker.team != taking:
		taker = taking.goalkeeper if kind == "GOAL KICK" else taking.nearest_outfield_to(spot)
	var inward := (-spot).normalized()
	if kind == "GOAL KICK":
		inward = Vector2(-signf(spot.x), 0.0)
	taker.position = spot - inward * 24.0 if kind != "GOAL KICK" else spot - inward * 20.0
	taker.velocity = Vector2.ZERO
	taker.facing = inward
	taker.hold_time = state_timer
	ball.set_carrier(taker)
	ball.position = spot
	restart_taker = taker
	if taking.is_human and taker.role != Player.Role.GK:
		taking.set_controlled(taker)
	if kind != "FREE KICK":
		hud.notify(kind, Color("#ffffff"), 64)

func _check_bounds() -> void:
	var p := ball.position
	if absf(p.x) > Pitch.HALF_W + 12.0:
		var gs := signf(p.x)
		if absf(p.y) < Pitch.GOAL_HALF - 4.0 and ball.z < Pitch.CROSSBAR_H and absf(p.x) > Pitch.HALF_W + 16.0:
			_register_goal(int(gs))
			return
		_ball_over_goal_line(gs, p)
	elif absf(p.y) > Pitch.HALF_H + 10.0:
		var thrower := opponent_of(ball.last_team) if ball.last_team != null else teams[0]
		var spot := Vector2(clampf(p.x, -Pitch.HALF_W + 40.0, Pitch.HALF_W - 40.0), signf(p.y) * (Pitch.HALF_H - 8.0))
		_start_restart("THROW-IN", thrower, spot)

func _ball_over_goal_line(gs: float, p: Vector2) -> void:
	# The team defending this goal is the one whose side == -gs.
	var defending: Team = teams[0] if teams[0].side == -int(gs) else teams[1]
	var attacking := opponent_of(defending)
	var recent_shot := last_shot_team == attacking and now() - last_shot_time < 3.0
	if ball.last_team == defending:
		attacking.stats["corners"] += 1
		var spot := Vector2(gs * (Pitch.HALF_W - 10.0), signf(p.y) * (Pitch.HALF_H - 10.0))
		_start_restart("CORNER", attacking, spot)
	else:
		if recent_shot:
			hud.notify("MISS!", Color("#ff8a5c"), 96)
			AudioManager.ooh()
		var spot2 := Vector2(gs * (Pitch.HALF_W - Pitch.GOAL_AREA_DEPTH + 30.0), signf(p.y) * 60.0)
		_start_restart("GOAL KICK", defending, spot2)

# ---------------------------------------------------------------- periods
func _end_period() -> void:
	AudioManager.play("whistle")
	AudioManager.cheer(0.4)
	if period == 1:
		state = State.HALFTIME
		state_timer = 8.0
		ball.frozen = true
		hud.show_summary("HALF TIME", _score_text(), _stat_lines(), "", Callable())
	else:
		_full_time()

func _start_second_half() -> void:
	hud.hide_summary()
	period = 2
	period_time = 0.0
	_setup_kickoff(teams[1])

func _full_time() -> void:
	state = State.FULLTIME
	ball.frozen = true
	var tied := score[0] == score[1]
	var knockout := GameState.mode == "tournament"
	if tied:
		if period == 2 and (knockout or GameState.extra_time):
			hud.notify("EXTRA TIME", Color("#ffd23f"), 100)
			await get_tree().create_timer(1.8).timeout
			period = 3
			period_time = 0.0
			_setup_kickoff(teams[0])
			return
		if knockout or GameState.penalties_enabled:
			hud.notify("PENALTIES!", Color("#ffd23f"), 100)
			await get_tree().create_timer(1.8).timeout
			GameState.pending_penalty = {"standalone": false, "hg": score[0], "ag": score[1]}
			Transition.go("res://scenes/match/penalty_shootout.tscn")
			return
	hud.notify("FULL TIME!", Color("#ffffff"), 110)
	AudioManager.cheer(0.7)
	await get_tree().create_timer(1.6).timeout
	hud.show_summary("FULL TIME", _score_text(), _stat_lines(), "CONTINUE", _finish)

func _finish() -> void:
	if _finished:
		return
	_finished = true
	GameState.finish_match(score[0], score[1], -1)
	Transition.go(GameState.next_scene_after_match())

func quit_to_menu() -> void:
	Transition.go("res://scenes/main_menu/main_menu.tscn")

func _score_text() -> String:
	return "%s  %d - %d  %s" % [teams[0].data.team_name, score[0], score[1], teams[1].data.team_name]

func _stat_lines() -> Array:
	var a := teams[0].stats
	var b := teams[1].stats
	var total := maxf(float(a["possession"]) + float(b["possession"]), 0.001)
	var pa := roundi(float(a["possession"]) / total * 100.0)
	return [
		[str(pa) + "%", "POSSESSION", str(100 - pa) + "%"],
		[str(a["shots"]), "SHOTS", str(b["shots"])],
		[str(a["on_target"]), "ON TARGET", str(b["on_target"])],
		[str(a["saves"]), "SAVES", str(b["saves"])],
		[str(a["corners"]), "CORNERS", str(b["corners"])],
		[str(a["fouls"]), "FOULS", str(b["fouls"])],
	]
