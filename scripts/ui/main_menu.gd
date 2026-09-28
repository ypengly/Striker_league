extends Control
## Main menu: animated stadium backdrop, staggered button slide-in, settings + how-to overlays.

const MATCH := "res://scenes/match/match.tscn"
const TEAM_SELECT := "res://scenes/menus/team_select.tscn"
const TOURNAMENT := "res://scenes/menus/tournament_screen.tscn"

var _title: Label
var _t := 0.0

func _ready() -> void:
	add_child(StadiumBackdrop.new())
	AudioManager.stop_ambience()
	AudioManager.play_music(false)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 70)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 30)
	add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	margin.add_child(v)
	_title = UIKit.label("STRIKER LEAGUE", 76, Color.WHITE)
	_title.add_theme_constant_override("outline_size", 10)
	v.add_child(_title)
	v.add_child(UIKit.label("ARCADE FOOTBALL", 24, UIKit.COL_ACCENT))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	v.add_child(gap)
	var items: Array = [
		["PLAY", _play], ["QUICK MATCH", _quick], ["TOURNAMENT", _tournament],
		["PENALTY SHOOTOUT", _penalty], ["TEAMS", _teams], ["SETTINGS", _settings],
		["HOW TO PLAY", _how_to],
	]
	if not OS.has_feature("web"):
		items.append(["EXIT", get_tree().quit])
	var delay := 0.1
	for it: Array in items:
		var b := UIKit.button(it[0], 24, Vector2(320, 46), UIKit.COL_ACCENT if it[0] != "EXIT" else Color("#ff5c5c"))
		b.pressed.connect(it[1])
		v.add_child(b)
		UIKit.slide_in(b, delay)
		delay += 0.06
		if it[0] == "PLAY":
			b.call_deferred("grab_focus")
	var stats := GameState.stats
	var foot := UIKit.label("Played %d   Won %d   Drawn %d   Lost %d   Goals %d-%d   Cups won %d" % [stats["played"], stats["won"], stats["drawn"], stats["lost"], stats["gf"], stats["ga"], stats["tournaments_won"]], 14, UIKit.COL_DIM)
	foot.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	foot.offset_left = -560.0
	foot.offset_top = -34.0
	foot.offset_right = -20.0
	foot.offset_bottom = -10.0
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(foot)

func _process(delta: float) -> void:
	_t += delta
	_title.pivot_offset = _title.size * 0.5
	_title.rotation = sin(_t * 0.9) * 0.008
	_title.scale = Vector2.ONE * (1.0 + sin(_t * 1.6) * 0.01)

func _play() -> void:
	GameState.mode = "quick"
	Transition.go(TEAM_SELECT)

func _quick() -> void:
	GameState.mode = "quick"
	if GameState.opponent_team_idx == GameState.player_team_idx:
		GameState.opponent_team_idx = (GameState.player_team_idx + 1) % GameState.teams.size()
	Transition.go(MATCH)

func _tournament() -> void:
	GameState.mode = "tournament"
	Transition.go(TOURNAMENT)

func _penalty() -> void:
	GameState.mode = "penalty"
	Transition.go(TEAM_SELECT)

func _teams() -> void:
	GameState.mode = "teams_view"
	Transition.go(TEAM_SELECT)

func _settings() -> void:
	add_child(SettingsPanel.new())

func _how_to() -> void:
	var o := Control.new()
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(o)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.add_child(dim)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.add_child(c)
	var p := UIKit.panel(UIKit.COL_PANEL, 18, 26)
	c.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	v.add_child(UIKit.label("HOW TO PLAY", 40, UIKit.COL_ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	var rows := [
		["WASD / ARROWS", "Move (left stick on a gamepad)"],
		["SHIFT", "Sprint - drains stamina, and makes the ball harder to control"],
		["SPACE", "Shoot - HOLD to charge power, release to fire"],
		["E", "Pass to the highlighted teammate (ring shows the target)"],
		["T", "Slide tackle - time it well or you may give away a foul"],
		["Q", "Switch to the nearest player"],
		["ESC", "Pause"],
		["TOUCH", "On-screen joystick + buttons appear on mobile"],
		["GAMEPAD", "A shoot, X pass, B tackle, Y switch, RB sprint"],
	]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 26)
	v.add_child(grid)
	for r: Array in rows:
		grid.add_child(UIKit.label(r[0], 20, UIKit.COL_ACCENT2))
		grid.add_child(UIKit.label(r[1], 20, UIKit.COL_TEXT))
	v.add_child(UIKit.label("Tip: dribbling into space and passing early beats running at defenders.", 16, UIKit.COL_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var b := UIKit.button("BACK", 24, Vector2(220, 48))
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(o.queue_free)
	v.add_child(b)
	b.grab_focus()
