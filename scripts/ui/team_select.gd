extends Control
## Team selection (also used for penalty mode, tournament entry and the read-only TEAMS viewer).

var _player_cards: Array[TeamCard] = []
var _opp_cards: Array[TeamCard] = []
var _start: Button
var _formation_opt: OptionButton
var _info: Label

func _ready() -> void:
	add_child(StadiumBackdrop.new())
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var mode := GameState.mode
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 40.0
	v.offset_right = -40.0
	v.offset_top = 16.0
	v.offset_bottom = -16.0
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	var title := {"quick": "TEAM SELECTION", "tournament": "CHOOSE YOUR TOURNAMENT TEAM", "penalty": "PENALTY SHOOTOUT - CHOOSE TEAMS", "teams_view": "TEAMS"}
	v.add_child(UIKit.label(title.get(mode, "TEAM SELECTION"), 40, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 50)
	v.add_child(row)
	row.add_child(_grid_block("YOUR TEAM" if mode != "teams_view" else "ALL TEAMS", _player_cards, UIKit.COL_ACCENT, GameState.player_team_idx, _pick_player))
	if mode == "quick" or mode == "penalty":
		row.add_child(_grid_block("OPPONENT", _opp_cards, UIKit.COL_ACCENT2, GameState.opponent_team_idx, _pick_opp))
	_info = UIKit.label("", 20, UIKit.COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(_info)
	var opts := HBoxContainer.new()
	opts.alignment = BoxContainer.ALIGNMENT_CENTER
	opts.add_theme_constant_override("separation", 16)
	v.add_child(opts)
	if mode == "quick" or mode == "tournament":
		opts.add_child(UIKit.label("FORMATION", 18, UIKit.COL_DIM))
		_formation_opt = OptionButton.new()
		_formation_opt.add_item("TEAM DEFAULT")
		for f: String in Formations.NAMES:
			_formation_opt.add_item(f)
		_formation_opt.item_selected.connect(func(i: int) -> void: GameState.player_formation = "" if i == 0 else Formations.NAMES[i - 1])
		opts.add_child(_formation_opt)
	if mode == "quick":
		opts.add_child(UIKit.label("DIFFICULTY", 18, UIKit.COL_DIM))
		var d := OptionButton.new()
		for n: String in GameState.DIFFICULTY_NAMES:
			d.add_item(n)
		d.select(GameState.difficulty)
		d.item_selected.connect(func(i: int) -> void: GameState.difficulty = i)
		opts.add_child(d)
		opts.add_child(UIKit.label("LENGTH", 18, UIKit.COL_DIM))
		var l := OptionButton.new()
		var sel := 1
		for i in GameState.MATCH_LENGTHS.size():
			l.add_item("%d s" % int(GameState.MATCH_LENGTHS[i]))
			if is_equal_approx(GameState.MATCH_LENGTHS[i], GameState.match_length):
				sel = i
		l.select(sel)
		l.item_selected.connect(func(i: int) -> void: GameState.match_length = GameState.MATCH_LENGTHS[i])
		opts.add_child(l)
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 20)
	v.add_child(btns)
	var back := UIKit.button("BACK", 26, Vector2(220, 54), Color("#ff5c5c"))
	back.pressed.connect(func() -> void: Transition.go("res://scenes/main_menu/main_menu.tscn"))
	btns.add_child(back)
	if mode != "teams_view":
		_start = UIKit.button("KICK OFF" if mode != "tournament" else "START TOURNAMENT", 26, Vector2(300, 54))
		_start.pressed.connect(_go)
		btns.add_child(_start)
		_start.grab_focus()
	_refresh()

func _grid_block(title: String, store: Array[TeamCard], accent: Color, selected: int, cb: Callable) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(UIKit.label(title, 22, accent, HORIZONTAL_ALIGNMENT_CENTER))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	for i in GameState.teams.size():
		var c := TeamCard.new()
		c.setup(i, GameState.teams[i])
		c.accent = accent
		c.chosen.connect(cb)
		grid.add_child(c)
		store.append(c)
	return box

func _pick_player(i: int) -> void:
	GameState.player_team_idx = i
	if GameState.mode != "teams_view" and GameState.opponent_team_idx == i:
		GameState.opponent_team_idx = (i + 1) % GameState.teams.size()
	_refresh()

func _pick_opp(i: int) -> void:
	GameState.opponent_team_idx = i
	if GameState.player_team_idx == i:
		GameState.player_team_idx = (i + 1) % GameState.teams.size()
	_refresh()

func _refresh() -> void:
	for c in _player_cards:
		c.set_selected(c.index == GameState.player_team_idx)
	for c in _opp_cards:
		c.set_selected(c.index == GameState.opponent_team_idx)
	var t := GameState.get_team(GameState.player_team_idx)
	_info.text = "%s   |   Overall %d   |   Default formation %s" % [t.team_name, t.overall(), t.formation]
	if GameState.mode == "quick" or GameState.mode == "penalty":
		var o := GameState.get_team(GameState.opponent_team_idx)
		_info.text += "     VS     %s (Overall %d)" % [o.team_name, o.overall()]

func _go() -> void:
	GameState.save_all()
	match GameState.mode:
		"quick":
			Transition.go("res://scenes/match/match.tscn")
		"penalty":
			GameState.pending_penalty = {"standalone": true, "hg": 0, "ag": 0}
			Transition.go("res://scenes/match/penalty_shootout.tscn")
		"tournament":
			GameState.start_tournament(GameState.player_team_idx)
			Transition.go("res://scenes/menus/tournament_screen.tscn")
