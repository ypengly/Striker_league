class_name SettingsPanel
extends Control
## Modal settings screen (menu + pause). Changes apply immediately and are saved on close.

signal closed

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := UIKit.panel(UIKit.COL_PANEL, 18, 22)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	v.add_child(UIKit.label("SETTINGS", 40, UIKit.COL_ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	_slider(grid, "MASTER VOLUME", GameState.master_vol, func(x: float) -> void:
		GameState.master_vol = x
		AudioManager.apply_volumes())
	_slider(grid, "MUSIC VOLUME", GameState.music_vol, func(x: float) -> void:
		GameState.music_vol = x
		AudioManager.apply_volumes())
	_slider(grid, "SFX VOLUME", GameState.sfx_vol, func(x: float) -> void:
		GameState.sfx_vol = x
		AudioManager.apply_volumes())
	_option(grid, "DIFFICULTY", GameState.DIFFICULTY_NAMES, GameState.difficulty, func(i: int) -> void: GameState.difficulty = i)
	var lens: Array = []
	var li := 1
	for i in GameState.MATCH_LENGTHS.size():
		lens.append("%d SECONDS" % int(GameState.MATCH_LENGTHS[i]))
		if is_equal_approx(GameState.MATCH_LENGTHS[i], GameState.match_length):
			li = i
	_option(grid, "MATCH DURATION", lens, li, func(i: int) -> void: GameState.match_length = GameState.MATCH_LENGTHS[i])
	var res: Array = []
	for r: Vector2i in GameState.RESOLUTIONS:
		res.append("%d x %d" % [r.x, r.y])
	_option(grid, "RESOLUTION", res, GameState.resolution_idx, func(i: int) -> void:
		GameState.resolution_idx = i
		GameState.apply_display())
	_option(grid, "TOUCH CONTROLS", ["AUTO", "ALWAYS ON", "OFF"], GameState.touch_mode, func(i: int) -> void: GameState.touch_mode = i)
	_check(grid, "FULLSCREEN", GameState.fullscreen, func(b: bool) -> void:
		GameState.fullscreen = b
		GameState.apply_display())
	_check(grid, "AIM ASSIST", GameState.aim_assist, func(b: bool) -> void: GameState.aim_assist = b)
	_check(grid, "CAMERA SHAKE", GameState.camera_shake, func(b: bool) -> void: GameState.camera_shake = b)
	_check(grid, "EXTRA TIME (QUICK MATCH)", GameState.extra_time, func(b: bool) -> void: GameState.extra_time = b)
	_check(grid, "PENALTIES IF LEVEL", GameState.penalties_enabled, func(b: bool) -> void: GameState.penalties_enabled = b)
	v.add_child(UIKit.label("Keyboard: WASD/Arrows move  |  Space shoot (hold)  |  E pass  |  Shift sprint  |  Q switch  |  T tackle  |  Esc pause", 14, UIKit.COL_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var back := UIKit.button("BACK", 26, Vector2(240, 52))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_close)
	v.add_child(back)
	back.grab_focus()

func _row_label(grid: GridContainer, text: String) -> void:
	var l := UIKit.label(text, 18, UIKit.COL_TEXT)
	l.custom_minimum_size = Vector2(260, 0)
	grid.add_child(l)

func _slider(grid: GridContainer, text: String, value: float, cb: Callable) -> void:
	_row_label(grid, text)
	var s := HSlider.new()
	s.custom_minimum_size = Vector2(260, 24)
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.value_changed.connect(cb)
	grid.add_child(s)

func _option(grid: GridContainer, text: String, items: Array, selected: int, cb: Callable) -> void:
	_row_label(grid, text)
	var o := OptionButton.new()
	o.custom_minimum_size = Vector2(260, 34)
	for it in items:
		o.add_item(str(it))
	o.select(clampi(selected, 0, items.size() - 1))
	o.item_selected.connect(cb)
	grid.add_child(o)

func _check(grid: GridContainer, text: String, value: bool, cb: Callable) -> void:
	_row_label(grid, text)
	var c := CheckButton.new()
	c.button_pressed = value
	c.toggled.connect(cb)
	grid.add_child(c)

func _close() -> void:
	GameState.save_all()
	closed.emit()
	queue_free()
