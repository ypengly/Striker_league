class_name MatchHUD
extends CanvasLayer
## In-match UI: scoreboard, clock, stamina, shot power, animated notifications, summary + pause overlays.

var game: MatchManager
var _home_name: Label
var _away_name: Label
var _score: Label
var _clock: Label
var _period: Label
var _home_col: ColorRect
var _away_col: ColorRect
var _stamina: ProgressBar
var _player_lbl: Label
var _power_root: Control
var _power: ProgressBar
var _notif: Label
var _sub: Label
var _flash: ColorRect
var _summary: Control
var _pause: Control
var _notif_tween: Tween

func setup(g: MatchManager) -> void:
	game = g
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_scoreboard(root)
	_build_bottom(root)
	_build_notifications(root)
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_flash)

func _build_scoreboard(root: Control) -> void:
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 10.0
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	var panel := UIKit.panel(Color(0.03, 0.05, 0.1, 0.85), 14, 10)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	top.add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var t0 := game.teams[0]
	var t1 := game.teams[1]
	_home_name = UIKit.label(t0.data.team_name.to_upper(), 26, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	_home_name.custom_minimum_size = Vector2(230, 0)
	_away_name = UIKit.label(t1.data.team_name.to_upper(), 26, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	_away_name.custom_minimum_size = Vector2(230, 0)
	_home_col = ColorRect.new()
	_home_col.color = t0.kit_primary
	_home_col.custom_minimum_size = Vector2(10, 40)
	_away_col = ColorRect.new()
	_away_col.color = t1.kit_primary
	_away_col.custom_minimum_size = Vector2(10, 40)
	_score = UIKit.label("0 - 0", 44, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_score.custom_minimum_size = Vector2(130, 0)
	for c: Control in [_home_name, _home_col, _score, _away_col, _away_name]:
		row.add_child(c)
	var sub := HBoxContainer.new()
	sub.alignment = BoxContainer.ALIGNMENT_CENTER
	sub.add_theme_constant_override("separation", 14)
	v.add_child(sub)
	_clock = UIKit.label("00:00", 26, UIKit.COL_ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	_period = UIKit.label("1ST HALF", 16, UIKit.COL_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	sub.add_child(_clock)
	sub.add_child(_period)

func _build_bottom(root: Control) -> void:
	var bl := VBoxContainer.new()
	bl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bl.offset_left = 20.0
	bl.offset_top = -90.0
	bl.offset_bottom = -20.0
	bl.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bl)
	_player_lbl = UIKit.label("", 18, Color.WHITE)
	bl.add_child(_player_lbl)
	_stamina = _bar(Color("#19d3a2"), Vector2(230, 14))
	bl.add_child(_stamina)
	bl.add_child(UIKit.label("STAMINA", 12, UIKit.COL_DIM))
	_power_root = VBoxContainer.new()
	_power_root.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_power_root.offset_left = -170.0
	_power_root.offset_right = 170.0
	_power_root.offset_top = -80.0
	_power_root.offset_bottom = -30.0
	_power_root.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_power_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_power_root.visible = false
	root.add_child(_power_root)
	_power_root.add_child(UIKit.label("SHOT POWER", 14, UIKit.COL_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	_power = _bar(Color("#19d3a2"), Vector2(340, 20))
	_power_root.add_child(_power)

func _bar(col: Color, size: Vector2) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.custom_minimum_size = size
	pb.max_value = 1.0
	pb.show_percentage = false
	pb.add_theme_stylebox_override("background", UIKit.box(Color(0, 0, 0, 0.55), 6, Color(1, 1, 1, 0.2), 1))
	pb.add_theme_stylebox_override("fill", UIKit.box(col, 6))
	return pb

func _build_notifications(root: Control) -> void:
	_notif = UIKit.label("", 100, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_notif.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_notif.offset_top = 150.0
	_notif.offset_bottom = 290.0
	_notif.add_theme_constant_override("outline_size", 12)
	_notif.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notif.modulate.a = 0.0
	root.add_child(_notif)
	_sub = UIKit.label("", 28, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_sub.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_sub.offset_top = 290.0
	_sub.offset_bottom = 380.0
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sub.modulate.a = 0.0
	root.add_child(_sub)

# ---------------------------------------------------------------- public API
func notify(text: String, color: Color = Color.WHITE, size: int = 90, sub: String = "") -> void:
	_notif.text = text
	_notif.add_theme_font_size_override("font_size", size)
	_notif.add_theme_color_override("font_color", color)
	_notif.pivot_offset = Vector2(get_viewport().get_visible_rect().size.x * 0.5, 70.0)
	_sub.text = sub
	if _notif_tween != null:
		_notif_tween.kill()
	_notif.scale = Vector2(0.4, 0.4)
	_notif.modulate.a = 1.0
	_sub.modulate.a = 1.0 if sub != "" else 0.0
	_notif_tween = create_tween()
	_notif_tween.tween_property(_notif, "scale", Vector2(1.12, 1.12), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_notif_tween.tween_property(_notif, "scale", Vector2.ONE, 0.1)
	_notif_tween.tween_interval(1.4 if size < 100 else 2.0)
	_notif_tween.tween_property(_notif, "modulate:a", 0.0, 0.4)
	_notif_tween.parallel().tween_property(_sub, "modulate:a", 0.0, 0.4)

func flash(color: Color) -> void:
	_flash.color = Color(color.r, color.g, color.b, 0.7)
	create_tween().tween_property(_flash, "color:a", 0.0, 0.5)

func show_summary(title: String, score_text: String, lines: Array, button_text: String, callback: Callable) -> void:
	hide_summary()
	_summary = Control.new()
	_summary.set_anchors_preset(Control.PRESET_FULL_RECT)
	_summary.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_summary)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_summary.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_summary.add_child(center)
	var panel := UIKit.panel(UIKit.COL_PANEL, 18, 26)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	v.add_child(UIKit.label(title, 48, UIKit.COL_ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label(score_text, 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 30)
	v.add_child(grid)
	for ln: Array in lines:
		var l := UIKit.label(str(ln[0]), 24, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
		l.custom_minimum_size = Vector2(90, 0)
		grid.add_child(l)
		var m := UIKit.label(str(ln[1]), 18, UIKit.COL_DIM, HORIZONTAL_ALIGNMENT_CENTER)
		m.custom_minimum_size = Vector2(160, 0)
		grid.add_child(m)
		grid.add_child(UIKit.label(str(ln[2]), 24, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT))
	if game.goal_log.size() > 0:
		v.add_child(UIKit.label("GOALS", 16, UIKit.COL_DIM, HORIZONTAL_ALIGNMENT_CENTER))
		for gl in game.goal_log:
			v.add_child(UIKit.label(gl, 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	if button_text != "":
		var b := UIKit.button(button_text, 26, Vector2(260, 56))
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(callback)
		v.add_child(b)
		b.grab_focus()
	else:
		v.add_child(UIKit.label("Second half starts shortly - press SHOOT to skip", 16, UIKit.COL_DIM, HORIZONTAL_ALIGNMENT_CENTER))

func hide_summary() -> void:
	if _summary != null:
		_summary.queue_free()
		_summary = null

# ---------------------------------------------------------------- pause
func toggle_pause() -> void:
	if _pause != null:
		_close_pause()
		return
	get_tree().paused = true
	_pause = Control.new()
	_pause.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pause)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	center.add_child(v)
	v.add_child(UIKit.label("PAUSED", 60, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	var resume := UIKit.button("RESUME")
	resume.pressed.connect(_close_pause)
	v.add_child(resume)
	var settings := UIKit.button("SETTINGS")
	settings.pressed.connect(_open_settings.bind(center))
	v.add_child(settings)
	var restart := UIKit.button("RESTART MATCH")
	restart.pressed.connect(func() -> void: Transition.go("res://scenes/match/match.tscn"))
	if GameState.mode != "tournament":
		v.add_child(restart)
	var quit := UIKit.button("QUIT TO MENU", 26, Vector2(300, 56), Color("#ff5c5c"))
	quit.pressed.connect(game.quit_to_menu)
	v.add_child(quit)
	resume.grab_focus()

func _open_settings(center: Control) -> void:
	center.visible = false
	var sp := SettingsPanel.new()
	sp.closed.connect(func() -> void:
		center.visible = true)
	_pause.add_child(sp)

func _close_pause() -> void:
	if _pause != null:
		_pause.queue_free()
		_pause = null
	get_tree().paused = false

# ---------------------------------------------------------------- per-frame
func _process(_delta: float) -> void:
	if game == null:
		return
	_score.text = "%d - %d" % [game.score[0], game.score[1]]
	_clock.text = game.clock_text()
	_period.text = game.period_text()
	var c := game.teams[0].controlled
	if c != null:
		_stamina.value = c.stamina / 100.0
		_stamina.add_theme_stylebox_override("fill", UIKit.box(Color("#ff5c5c") if c.stamina < 25.0 else Color("#19d3a2"), 6))
		_player_lbl.text = "#%d %s  (%s)" % [c.number, c.player_name, Player.ROLE_NAMES[c.role]]
		_power_root.visible = c.charging
		if c.charging:
			_power.value = c.charge
			_power.add_theme_stylebox_override("fill", UIKit.box(Color.from_hsv(0.33 * (1.0 - c.charge), 0.85, 1.0), 6))
