class_name PlayerVisual
extends Node2D
## Placeholder procedural art + AnimationPlayer clips ("celebrate", "hurt").
## To use real sprites: replace _draw() with an AnimatedSprite2D driven by player.anim.

var p: Player
var bob := 0.0      # animated by AnimationPlayer
var flash := 0.0    # animated by AnimationPlayer
var _anim_player: AnimationPlayer
var _cur := ""
const SKINS := [Color("#f1c27d"), Color("#c68642"), Color("#8d5524"), Color("#ffdbac")]

func setup(player: Player) -> void:
	p = player
	_anim_player = AnimationPlayer.new()
	add_child(_anim_player)
	var lib := AnimationLibrary.new()
	var cel := Animation.new()
	cel.length = 0.5
	cel.loop_mode = Animation.LOOP_LINEAR
	var t1 := cel.add_track(Animation.TYPE_VALUE)
	cel.track_set_path(t1, NodePath(":bob"))
	cel.track_insert_key(t1, 0.0, 0.0)
	cel.track_insert_key(t1, 0.25, -16.0)
	cel.track_insert_key(t1, 0.5, 0.0)
	lib.add_animation("celebrate", cel)
	var hurt := Animation.new()
	hurt.length = 0.5
	var t2 := hurt.add_track(Animation.TYPE_VALUE)
	hurt.track_set_path(t2, NodePath(":flash"))
	hurt.track_insert_key(t2, 0.0, 1.0)
	hurt.track_insert_key(t2, 0.5, 0.0)
	lib.add_animation("hurt", hurt)
	_anim_player.add_animation_library("", lib)

func _process(_delta: float) -> void:
	if p == null or p.team == null:
		return
	var want := ""
	if p.celebrating:
		want = "celebrate"
	elif p.stun > 0.0:
		want = "hurt"
	if want != _cur:
		_cur = want
		if want == "":
			_anim_player.stop()
			bob = 0.0
			flash = 0.0
		else:
			_anim_player.play(want)
	queue_redraw()

func _draw() -> void:
	if p == null or p.team == null:
		return
	var t := p.anim_time
	var f := p.facing
	var speed_ratio := clampf(p.velocity.length() / maxf(p.max_speed(), 1.0), 0.0, 1.3)
	var kit := p.team.gk_kit if p.role == Player.Role.GK else p.team.kit_primary
	kit = kit.lerp(Color(1, 0.2, 0.2), flash * 0.7)
	var trim := p.team.kit_secondary
	var skin: Color = SKINS[p.slot % 4]
	draw_set_transform(Vector2(0, 11), 0.0, Vector2(1.0, 0.42))
	draw_circle(Vector2.ZERO, 17.0, Color(0, 0, 0, 0.32))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if p.is_human:
		draw_arc(Vector2(0, 8), 21.0, 0.0, TAU, 28, Color(1, 0.9, 0.2, 0.9), 2.5)
	if p.team.game.human_pass_target() == p:
		draw_arc(Vector2(0, 8), 26.0, 0.0, TAU, 28, Color(1, 1, 1, 0.9), 2.5)
	if p.anim == Player.Anim.TACKLE or p.anim == Player.Anim.DIVE:
		_draw_lying(kit, trim, skin)
	else:
		_draw_standing(t, f, speed_ratio, kit, trim, skin)
	if p.is_human:
		var y := -44.0 + sin(t * 6.0) * 3.0
		draw_colored_polygon(PackedVector2Array([Vector2(-7, y - 8), Vector2(7, y - 8), Vector2(0, y)]), Color(1, 0.9, 0.2))
	if p.charging:
		draw_arc(Vector2(0, -8), 24.0, -PI * 0.5, -PI * 0.5 + TAU * p.charge, 24, Color(1, 0.5 + 0.5 * (1.0 - p.charge), 0.1), 4.0)

func _draw_standing(t: float, f: Vector2, sr: float, kit: Color, trim: Color, skin: Color) -> void:
	var swing := sin(t * (9.0 + sr * 8.0)) * 7.0 * minf(sr * 1.6, 1.0)
	var lift := bob
	var boot := Color(0.1, 0.1, 0.13)
	var fl := Vector2(-5, 7) + f * swing * 0.9
	var fr := Vector2(5, 7) - f * swing * 0.9
	if p.kick_anim > 0.0:
		fr = Vector2(5, 7) + f * (8.0 + 20.0 * (p.kick_anim / 0.22))
	draw_line(Vector2(-4, -1 + lift), fl + Vector2(0, lift), skin.darkened(0.15), 4.0)
	draw_line(Vector2(4, -1 + lift), fr + Vector2(0, lift), skin.darkened(0.15), 4.0)
	draw_circle(fl + Vector2(0, lift), 3.5, boot)
	draw_circle(fr + Vector2(0, lift), 3.5, boot)
	var tc := Vector2(0, -8 + lift)
	var hand_l := Vector2(-13, -5 + lift) - f * swing * 0.5
	var hand_r := Vector2(13, -5 + lift) + f * swing * 0.5
	if p.anim == Player.Anim.CELEBRATE:
		hand_l = Vector2(-10, -28 + lift)
		hand_r = Vector2(10, -28 + lift)
	draw_line(tc + Vector2(-9, -3), hand_l, skin, 3.0)
	draw_line(tc + Vector2(9, -3), hand_r, skin, 3.0)
	draw_circle(tc, 11.5, kit)
	draw_arc(tc, 9.0, PI * 0.15, PI * 0.85, 10, trim, 3.0)
	draw_circle(tc + Vector2(0, -9), 3.0, trim)
	var hc := Vector2(f.x * 2.0, -21.0 + f.y * 1.5 + lift)
	draw_circle(hc, 6.5, skin)
	draw_arc(hc, 6.5, PI, TAU, 10, Color(0.15, 0.1, 0.08), 3.0)
	draw_circle(hc + f * 3.5, 1.6, skin.darkened(0.3))

func _draw_lying(kit: Color, trim: Color, skin: Color) -> void:
	var dir := p.lunge_dir if p.lunge_time > 0.0 else (p.dive_dir if p.dive_dir != Vector2.ZERO else p.facing)
	draw_set_transform(Vector2(0, 2), dir.angle(), Vector2(1.0, 1.0))
	draw_line(Vector2(-12, -4), Vector2(-26, -6), skin.darkened(0.15), 4.0)
	draw_line(Vector2(-12, 4), Vector2(-26, 6), skin.darkened(0.15), 4.0)
	draw_line(Vector2(6, -8), Vector2(24, -10), skin, 3.0)
	draw_line(Vector2(6, 8), Vector2(24, 10), skin, 3.0)
	draw_set_transform(Vector2(0, 2), dir.angle(), Vector2(1.7, 0.85))
	draw_circle(Vector2.ZERO, 10.0, kit)
	draw_set_transform(Vector2(0, 2), dir.angle(), Vector2.ONE)
	draw_circle(Vector2(18, 0), 6.0, skin)
	draw_arc(Vector2.ZERO, 8.0, -0.6, 0.6, 6, trim, 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
