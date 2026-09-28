extends Control
## Penalty shootout mode.
## You SHOOT: aim with movement keys, hold SHOOT to charge power (sweet spot ~60-85%, too much skies it), release to fire.
## You DEFEND: press LEFT / UP / RIGHT to choose the dive before the AI takes its kick.
## The AI keeper picks a dive direction using its rating (+ difficulty); it sometimes reads your aim.

enum Phase { AIM, FLIGHT, RESULT, DEFEND, END }

const GOAL := Rect2(340, 150, 600, 230)
const SPOT := Vector2(640, 610)
const KEEPER_BASE := Vector2(640, 330)

var home: TeamData
var away: TeamData
var standalone := true
var carry_hg := 0
var carry_ag := 0
var score: Array[int] = [0, 0]
var taken: Array[int] = [0, 0]
var results: Array = [[], []]
var turn := 0
var phase: int = Phase.AIM
var reticle := Vector2(640, 260)
var charge := 0.0
var charging := false
var flight_t := 0.0
var ball_target := Vector2.ZERO
var ball_pos := SPOT
var keeper_zone := 0
var keeper_pos := KEEPER_BASE
var keeper_angle := 0.0
var outcome := ""
var outcome_good := false
var result_timer := 0.0
var defend_timer := 0.0
var chosen_dive := 9
var pending_goal := false
var _t := 0.0
var _label: Label
var _sub: Label
var _button: Button

func _ready() -> void:
	var pp := GameState.pending_penalty
	standalone = bool(pp.get("standalone", true))
	carry_hg = int(pp.get("hg", 0))
	carry_ag = int(pp.get("ag", 0))
	home = GameState.get_team(GameState.player_team_idx)
	away = GameState.get_team(GameState.opponent_team_idx)
	if home == away:
		away = GameState.get_team((GameState.player_team_idx + 1) % GameState.teams.size())
	AudioManager.start_ambience()
	AudioManager.play_music(true)
	_label = UIKit.label("", 90, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_label.offset_left = -400.0
	_label.offset_right = 400.0
	_label.offset_top = 400.0
	_label.modulate.a = 0.0
	add_child(_label)
	_sub = UIKit.label("", 22, UIKit.COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_sub.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_sub.offset_left = -400.0
	_sub.offset_right = 400.0
	_sub.offset_top = -90.0
	add_child(_sub)
	_button = UIKit.button("CONTINUE", 28, Vector2(280, 60))
	_button.set_anchors_preset(Control.PRESET_CENTER)
	_button.offset_left = -140.0
	_button.offset_right = 140.0
	_button.offset_top = 150.0
	_button.offset_bottom = 210.0
	_button.visible = false
	_button.pressed.connect(_continue)
	add_child(_button)
	_begin_turn()

func _begin_turn() -> void:
	keeper_pos = KEEPER_BASE
	keeper_angle = 0.0
	ball_pos = SPOT
	charge = 0.0
	charging = false
	if turn == 0:
		phase = Phase.AIM
		reticle = Vector2(640, 260)
		_sub.text = "AIM with WASD / arrows  -  hold SPACE to charge, release to shoot"
	else:
		phase = Phase.DEFEND
		defend_timer = 2.4
		chosen_dive = 9
		_sub.text = "%s are about to shoot!  Dive: LEFT / UP / RIGHT" % away.team_name

func _process(delta: float) -> void:
	_t += delta
	match phase:
		Phase.AIM:
			var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
			reticle += v * 330.0 * delta
			reticle.x = clampf(reticle.x, GOAL.position.x - 90.0, GOAL.end.x + 90.0)
			reticle.y = clampf(reticle.y, GOAL.position.y - 70.0, GOAL.end.y + 40.0)
			if Input.is_action_just_pressed("shoot"):
				charging = true
				charge = 0.0
			if charging:
				charge = minf(1.0, charge + delta / 1.2)
				if Input.is_action_just_released("shoot"):
					charging = false
					_take_player_shot()
		Phase.DEFEND:
			defend_timer -= delta
			if Input.is_action_just_pressed("move_left"): chosen_dive = -1
			elif Input.is_action_just_pressed("move_right"): chosen_dive = 1
			elif Input.is_action_just_pressed("move_up"): chosen_dive = 0
			if chosen_dive != 9 or defend_timer <= 0.0:
				if chosen_dive == 9:
					chosen_dive = 0
				_take_ai_shot()
		Phase.FLIGHT:
			flight_t += delta / 0.55
			var k := clampf(flight_t, 0.0, 1.0)
			ball_pos = SPOT.lerp(ball_target, 1.0 - pow(1.0 - k, 2.0))
			ball_pos.y -= sin(k * PI) * 40.0
			# keeper dive
			var kt := clampf(flight_t * 1.4, 0.0, 1.0)
			var zone_x := {-1: 470.0, 0: 640.0, 1: 810.0}[keeper_zone] as float
			keeper_pos = KEEPER_BASE.lerp(Vector2(zone_x, KEEPER_BASE.y - (30.0 if keeper_zone == 0 else -10.0)), kt)
			keeper_angle = float(keeper_zone) * 1.15 * kt
			if flight_t >= 1.0:
				_show_result()
		Phase.RESULT:
			result_timer -= delta
			_label.modulate.a = clampf(result_timer * 2.0, 0.0, 1.0)
			if result_timer <= 0.0:
				_next_turn()
	queue_redraw()

# ---------------------------------------------------------------- shots
func _zone_of(x: float) -> int:
	if x < GOAL.position.x + 200.0:
		return -1
	if x > GOAL.end.x - 200.0:
		return 1
	return 0

func _take_player_shot() -> void:
	AudioManager.play("kick")
	var err := (100.0 - home.attack) * 0.9 + charge * 30.0
	var tgt := reticle + Vector2.from_angle(randf() * TAU) * randf() * err
	if charge > 0.9 and randf() < (charge - 0.88) * 7.0:
		tgt.y -= 220.0   # skied over the bar
	var gk_mult := float(GameState.ai_params(GameState.difficulty)["gk"])
	var read := clampf((away.goalkeeper - 50.0) / 100.0 * gk_mult, 0.1, 0.6)
	keeper_zone = _zone_of(tgt.x) if randf() < read else [-1, 0, 1][randi() % 3]
	_start_flight(tgt, charge, away.goalkeeper * gk_mult)

func _take_ai_shot() -> void:
	AudioManager.play("kick")
	var tgt := Vector2(randf_range(GOAL.position.x - 30.0, GOAL.end.x + 30.0), randf_range(GOAL.position.y + 20.0, GOAL.end.y - 20.0))
	if randf() < 0.08:
		tgt.y = GOAL.position.y - 60.0
	keeper_zone = chosen_dive
	_start_flight(tgt, randf_range(0.4, 0.9), float(home.goalkeeper))

func _start_flight(tgt: Vector2, power: float, gk_skill: float) -> void:
	ball_target = tgt
	flight_t = 0.0
	phase = Phase.FLIGHT
	var inside := tgt.x > GOAL.position.x + 10.0 and tgt.x < GOAL.end.x - 10.0 and tgt.y > GOAL.position.y + 6.0 and tgt.y < GOAL.end.y
	pending_goal = false
	outcome = "MISSED!"
	if not inside:
		var near_post := tgt.y > GOAL.position.y and tgt.y < GOAL.end.y and (absf(tgt.x - GOAL.position.x) < 24.0 or absf(tgt.x - GOAL.end.x) < 24.0)
		outcome = "OFF THE POST!" if near_post else "MISSED!"
		return
	var zone := _zone_of(tgt.x)
	var save_p := 0.0
	if zone == keeper_zone:
		save_p = clampf(0.55 + (gk_skill - 70.0) / 150.0 - power * 0.35 + (0.3 if power < 0.3 else 0.0), 0.15, 0.92)
	elif zone == 0 or keeper_zone == 0:
		save_p = 0.1
	if randf() < save_p:
		outcome = "SAVED!"
	else:
		outcome = "GOAL!"
		pending_goal = true

func _show_result() -> void:
	phase = Phase.RESULT
	result_timer = 1.6
	var shooter := turn
	taken[shooter] += 1
	results[shooter].append(pending_goal)
	if pending_goal:
		score[shooter] += 1
		AudioManager.play("goal")
		AudioManager.cheer(1.0 if shooter == 0 else 0.5)
	elif outcome == "SAVED!":
		AudioManager.play("save")
		AudioManager.cheer(0.5)
	else:
		AudioManager.play("post" if outcome == "OFF THE POST!" else "click")
		AudioManager.ooh()
	_label.text = outcome
	var good := (pending_goal and shooter == 0) or (not pending_goal and shooter == 1)
	_label.add_theme_color_override("font_color", UIKit.COL_ACCENT if good else Color("#ff5c5c"))
	_label.modulate.a = 1.0
	_label.pivot_offset = Vector2(400, 60)
	_label.scale = Vector2(0.5, 0.5)
	create_tween().tween_property(_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)

func _winner() -> int:
	var th := taken[0]
	var ta := taken[1]
	if th <= 5 and ta <= 5:
		if score[0] > score[1] + (5 - ta):
			return 0
		if score[1] > score[0] + (5 - th):
			return 1
	elif th == ta and score[0] != score[1]:
		return 0 if score[0] > score[1] else 1
	return -1

func _next_turn() -> void:
	var w := _winner()
	if w != -1:
		_end(w)
		return
	turn = 1 - turn
	_begin_turn()

func _end(w: int) -> void:
	phase = Phase.END
	_label.modulate.a = 1.0
	_label.text = "YOU WIN!" if w == 0 else "YOU LOSE"
	_label.add_theme_color_override("font_color", UIKit.COL_ACCENT2 if w == 0 else Color("#ff5c5c"))
	_sub.text = "%d - %d on penalties" % [score[0], score[1]]
	_button.visible = true
	_button.grab_focus()
	AudioManager.play("whistle")
	if w == 0:
		AudioManager.cheer(1.0)

func _continue() -> void:
	if standalone:
		Transition.go("res://scenes/main_menu/main_menu.tscn")
	else:
		var w := 0 if score[0] > score[1] else 1
		GameState.finish_match(carry_hg, carry_ag, w)
		Transition.go(GameState.next_scene_after_match())

# ---------------------------------------------------------------- drawing
func _draw() -> void:
	var off := (size - Vector2(1280, 720)) * 0.5
	draw_set_transform(off, 0.0, Vector2.ONE)
	draw_rect(Rect2(-600, -400, 2480, 800), Color("#0b1226"))
	for r in 4:
		draw_rect(Rect2(-600, 20 + r * 30, 2480, 26), Color(0.12 + r * 0.02, 0.15 + r * 0.02, 0.24 + r * 0.02))
		var x := -20.0
		while x < 1300.0:
			var hh := absi(int(x) * 31 + r * 17)
			draw_circle(Vector2(x, 32 + r * 30 - maxf(0.0, sin(_t * 3.0 + hh % 11)) * 3.0), 5.0, Color.from_hsv(float(hh % 100) / 100.0, 0.4, 0.6))
			x += 18.0
	draw_rect(Rect2(-600, 130, 2480, 800), Color("#2c8541"))
	draw_rect(Rect2(-600, 380, 2480, 30), Color("#308c46"))
	draw_rect(Rect2(-600, 470, 2480, 40), Color("#308c46"))
	draw_rect(Rect2(-600, 590, 2480, 60), Color("#308c46"))
	# goal + net
	draw_rect(GOAL, Color(0, 0, 0, 0.35))
	for i in range(0, 31):
		draw_line(Vector2(GOAL.position.x + i * 20.0, GOAL.position.y), Vector2(GOAL.position.x + i * 20.0, GOAL.end.y), Color(1, 1, 1, 0.16), 1.0)
	for j in range(0, 13):
		draw_line(Vector2(GOAL.position.x, GOAL.position.y + j * 20.0), Vector2(GOAL.end.x, GOAL.position.y + j * 20.0), Color(1, 1, 1, 0.16), 1.0)
	draw_line(GOAL.position + Vector2(0, 230), GOAL.position + Vector2(600, 230), Color(1, 1, 1, 0.7), 4.0)
	# penalty spot + box lines
	draw_circle(SPOT, 7.0, Color(1, 1, 1, 0.9))
	draw_line(Vector2(140, 410), Vector2(1140, 410), Color(1, 1, 1, 0.6), 4.0)
	# keeper
	_draw_keeper()
	draw_rect(Rect2(GOAL.position.x - 8, GOAL.position.y - 8, 616, 8), Color.WHITE)
	draw_rect(Rect2(GOAL.position.x - 8, GOAL.position.y - 8, 8, 246), Color.WHITE)
	draw_rect(Rect2(GOAL.end.x, GOAL.position.y - 8, 8, 246), Color.WHITE)
	# kicker silhouette
	var kit := home.primary if turn == 0 else away.primary
	draw_circle(SPOT + Vector2(-46, -8), 26.0, kit)
	draw_circle(SPOT + Vector2(-46, -44), 12.0, Color("#f1c27d"))
	# ball
	var k := clampf(flight_t, 0.0, 1.0) if phase == Phase.FLIGHT or phase == Phase.RESULT else 0.0
	UIKit.draw_ball(self, ball_pos, lerpf(17.0, 9.0, k), _t * 8.0 * k)
	# reticle + power
	if phase == Phase.AIM:
		draw_arc(reticle, 22.0, 0.0, TAU, 28, Color(1, 0.9, 0.2), 3.0)
		draw_line(reticle + Vector2(-32, 0), reticle + Vector2(32, 0), Color(1, 0.9, 0.2), 2.0)
		draw_line(reticle + Vector2(0, -32), reticle + Vector2(0, 32), Color(1, 0.9, 0.2), 2.0)
		draw_rect(Rect2(490, 660, 300, 22), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(490 + 300 * 0.6, 660, 300 * 0.25, 22), Color(0.2, 1, 0.5, 0.25))
		draw_rect(Rect2(490, 660, 300.0 * charge, 22), Color.from_hsv(0.33 * (1.0 - charge), 0.85, 1.0))
		draw_rect(Rect2(490, 660, 300, 22), Color.WHITE, false, 2.0)
	if phase == Phase.DEFEND:
		var f := ThemeDB.fallback_font
		draw_string(f, Vector2(500, 520), "%.1f" % maxf(defend_timer, 0.0), HORIZONTAL_ALIGNMENT_CENTER, 280, 60, Color.WHITE)
	_draw_scoreboard()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_keeper() -> void:
	var off := (size - Vector2(1280, 720)) * 0.5
	draw_set_transform(off + keeper_pos, keeper_angle, Vector2.ONE)
	var col := Color(1.0, 0.7, 0.1)
	draw_rect(Rect2(-16, -34, 32, 56), col)
	draw_circle(Vector2(0, -46), 12.0, Color("#c68642"))
	var up := phase == Phase.FLIGHT
	draw_line(Vector2(-16, -26), Vector2(-34, -48 if up else -6), col, 7.0)
	draw_line(Vector2(16, -26), Vector2(34, -48 if up else -6), col, 7.0)
	draw_circle(Vector2(-34, -48 if up else -6), 7.0, Color.WHITE)
	draw_circle(Vector2(34, -48 if up else -6), 7.0, Color.WHITE)
	draw_line(Vector2(-8, 22), Vector2(-10, 44), Color(0.1, 0.1, 0.15), 8.0)
	draw_line(Vector2(8, 22), Vector2(10, 44), Color(0.1, 0.1, 0.15), 8.0)
	draw_set_transform(off, 0.0, Vector2.ONE)

func _draw_scoreboard() -> void:
	var f := ThemeDB.fallback_font
	draw_rect(Rect2(30, 20, 320, 130), Color(0, 0, 0, 0.6))
	draw_string(f, Vector2(44, 46), "PENALTY SHOOTOUT", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UIKit.COL_ACCENT)
	var names := [home.team_name, away.team_name]
	for side in 2:
		var y := 80.0 + side * 34.0
		draw_string(f, Vector2(44, y + 6.0), ("YOU" if side == 0 else "AI"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
		var n := maxi(5, taken[side] + (1 if taken[side] >= 5 else 0))
		for i in mini(n, 9):
			var c := Vector2(100 + i * 24.0, y)
			var r: Array = results[side]
			if i < r.size():
				draw_circle(c, 9.0, UIKit.COL_ACCENT if r[i] else Color("#ff5c5c"))
			else:
				draw_arc(c, 9.0, 0.0, TAU, 16, Color(1, 1, 1, 0.6), 2.0)
		draw_string(f, Vector2(300, y + 6.0), str(score[side]), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	draw_string(f, Vector2(44, 140), "%s vs %s" % [home.team_name, away.team_name], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UIKit.COL_DIM)
