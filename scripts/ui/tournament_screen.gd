extends Control
## Tournament hub: new / continue, bracket view (QF -> SF -> Final -> Champion), player record.

var _bracket: Control
var _body: VBoxContainer

func _ready() -> void:
	add_child(StadiumBackdrop.new())
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_body = VBoxContainer.new()
	_body.set_anchors_preset(Control.PRESET_FULL_RECT)
	_body.offset_left = 40.0
	_body.offset_right = -40.0
	_body.offset_top = 16.0
	_body.offset_bottom = -16.0
	_body.add_theme_constant_override("separation", 10)
	add_child(_body)
	_build()

func _build() -> void:
	for c in _body.get_children():
		c.queue_free()
	_body.add_child(UIKit.label("TOURNAMENT", 44, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	var t := GameState.tournament
	if t.is_empty():
		_body.add_child(UIKit.label("No tournament in progress.", 24, UIKit.COL_DIM, HORIZONTAL_ALIGNMENT_CENTER))
		var nb := UIKit.button("NEW TOURNAMENT", 28, Vector2(360, 60))
		nb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		nb.pressed.connect(func() -> void:
			GameState.mode = "tournament"
			Transition.go("res://scenes/menus/team_select.tscn"))
		_body.add_child(nb)
		nb.grab_focus()
		_add_back()
		return
	_bracket = BracketView.new()
	_bracket.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(_bracket)
	var ts: Dictionary = t["stats"]
	var pt := GameState.get_team(int(t["player"]))
	_body.add_child(UIKit.label("%s   Wins %d   Losses %d   Goals For %d   Against %d   Points %d" % [pt.team_name, ts["w"], ts["l"], ts["gf"], ts["ga"], ts["pts"]], 20, UIKit.COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	_body.add_child(row)
	var champion := int(t["champion"])
	if champion != -1:
		var won := champion == int(t["player"])
		_body.add_child(UIKit.label("CHAMPIONS: %s" % GameState.get_team(champion).team_name.to_upper() + ("  -  YOU WIN THE CUP!" if won else ""), 30, UIKit.COL_ACCENT2, HORIZONTAL_ALIGNMENT_CENTER))
		if won:
			AudioManager.cheer(1.0)
		var fin := UIKit.button("FINISH", 26, Vector2(260, 54))
		fin.pressed.connect(func() -> void:
			GameState.clear_tournament()
			Transition.go("res://scenes/main_menu/main_menu.tscn"))
		row.add_child(fin)
		fin.grab_focus()
	elif bool(t["eliminated"]):
		_body.add_child(UIKit.label("YOU WERE ELIMINATED", 30, Color("#ff5c5c"), HORIZONTAL_ALIGNMENT_CENTER))
		var fin2 := UIKit.button("FINISH", 26, Vector2(260, 54))
		fin2.pressed.connect(func() -> void:
			GameState.clear_tournament()
			Transition.go("res://scenes/main_menu/main_menu.tscn"))
		row.add_child(fin2)
		fin2.grab_focus()
	else:
		var f := GameState.player_fixture()
		var opp := int(f["away"]) if int(f["home"]) == int(t["player"]) else int(f["home"])
		_body.add_child(UIKit.label("NEXT: %s vs %s" % [GameState.ROUND_NAMES[int(t["round"])], GameState.get_team(opp).team_name.to_upper()], 24, UIKit.COL_ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
		var play := UIKit.button("PLAY MATCH", 26, Vector2(280, 54))
		play.pressed.connect(func() -> void:
			GameState.prepare_next_tournament_match()
			Transition.go("res://scenes/match/match.tscn"))
		row.add_child(play)
		play.grab_focus()
	var back := UIKit.button("MAIN MENU", 24, Vector2(220, 54), Color("#ff5c5c"))
	back.pressed.connect(func() -> void: Transition.go("res://scenes/main_menu/main_menu.tscn"))
	row.add_child(back)

func _add_back() -> void:
	var back := UIKit.button("BACK", 24, Vector2(220, 50), Color("#ff5c5c"))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void: Transition.go("res://scenes/main_menu/main_menu.tscn"))
	_body.add_child(back)

## Draws the knockout bracket from GameState.tournament.
class BracketView extends Control:
	func _ready() -> void:
		custom_minimum_size = Vector2(0, 360)
	func _draw() -> void:
		var t := GameState.tournament
		var rounds: Array = t["rounds"]
		var font := ThemeDB.fallback_font
		var col_w := size.x / 4.0
		var box_w := minf(col_w - 40.0, 240.0)
		var box_h := 44.0
		var centers: Array = []
		for r in 3:
			var names: String = GameState.ROUND_NAMES[r]
			draw_string(font, Vector2(r * col_w + 20.0, 20.0), names, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UIKit.COL_DIM)
		draw_string(font, Vector2(3 * col_w + 20.0, 20.0), "CHAMPION", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UIKit.COL_ACCENT2)
		for r in 3:
			var fixtures: Array = rounds[r] if r < rounds.size() else []
			var n := 4 >> r
			var cs: Array = []
			for i in n:
				var cy := 40.0 + (size.y - 60.0) * (float(i) + 0.5) / float(n)
				cs.append(cy)
				var x := r * col_w + 20.0
				var f: Dictionary = fixtures[i] if i < fixtures.size() else {}
				_draw_fixture(font, Vector2(x, cy - box_h), box_w, box_h, f, t)
			centers.append(cs)
		var ch := int(t["champion"])
		var cx := 3 * col_w + 20.0
		var cy2 := size.y * 0.5 + 10.0
		draw_rect(Rect2(cx, cy2 - 30.0, box_w, 60.0), Color(0.3, 0.22, 0.05, 0.9))
		draw_rect(Rect2(cx, cy2 - 30.0, box_w, 60.0), UIKit.COL_ACCENT2, false, 3.0)
		if ch != -1:
			var td := GameState.get_team(ch)
			td.draw_logo(self, Vector2(cx + 30.0, cy2), 40.0)
			draw_string(font, Vector2(cx + 60.0, cy2 + 7.0), td.team_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
		else:
			draw_string(font, Vector2(cx + 20.0, cy2 + 7.0), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UIKit.COL_DIM)
	func _draw_fixture(font: Font, pos: Vector2, w: float, h: float, f: Dictionary, t: Dictionary) -> void:
		draw_rect(Rect2(pos, Vector2(w, h * 2.0)), Color(0.06, 0.09, 0.16, 0.9))
		draw_rect(Rect2(pos, Vector2(w, h * 2.0)), Color(1, 1, 1, 0.15), false, 2.0)
		if f.is_empty():
			return
		var teams := [int(f["home"]), int(f["away"])]
		var goals := [int(f["hg"]), int(f["ag"])]
		var win := int(f["winner"])
		for i in 2:
			var td := GameState.get_team(teams[i])
			var y := pos.y + i * h
			if teams[i] == int(t["player"]):
				draw_rect(Rect2(pos.x + 2.0, y + 2.0, w - 4.0, h - 4.0), Color(0.1, 0.5, 0.4, 0.35))
			td.draw_logo(self, Vector2(pos.x + 22.0, y + h * 0.5), 28.0)
			var c := Color.WHITE if (win == -1 or win == teams[i]) else UIKit.COL_DIM
			draw_string(font, Vector2(pos.x + 44.0, y + h * 0.5 + 6.0), td.team_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, c)
			if goals[i] >= 0:
				draw_string(font, Vector2(pos.x + w - 26.0, y + h * 0.5 + 6.0), str(goals[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, c)
