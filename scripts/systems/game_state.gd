extends Node
## Global game state: team database, settings, match setup, statistics, tournament progress.
## Autoload "GameState". (No class_name on purpose: autoload names must be unique.)

signal settings_changed

const TEAM_PATHS := [
	"res://data/teams/red_lions.tres", "res://data/teams/blue_sharks.tres",
	"res://data/teams/golden_eagles.tres", "res://data/teams/green_warriors.tres",
	"res://data/teams/black_panthers.tres", "res://data/teams/white_wolves.tres",
	"res://data/teams/orange_united.tres", "res://data/teams/purple_stars.tres",
]
const DIFFICULTY_NAMES := ["EASY", "NORMAL", "HARD"]
const MATCH_LENGTHS := [60.0, 90.0, 120.0, 180.0, 300.0]
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]
const ROUND_NAMES := ["QUARTER FINAL", "SEMI FINAL", "FINAL"]

## Difficulty tuning. These numbers really change AI behaviour (see player.gd / goalkeeper.gd).
## reaction: seconds between AI decisions. pass_acc/shot_acc: 0..1. positioning: 0..1 shape quality.
## speed: run-speed multiplier. tackle: tackle success multiplier. gk: goalkeeper skill multiplier.
const AI_PARAMS := [
	{"reaction": 0.38, "pass_acc": 0.55, "shot_acc": 0.50, "positioning": 0.45, "speed": 0.90, "tackle": 0.55, "gk": 0.70, "aggression": 0.45, "press_count": 1, "shot_range": 0.75},
	{"reaction": 0.20, "pass_acc": 0.80, "shot_acc": 0.75, "positioning": 0.80, "speed": 0.97, "tackle": 0.85, "gk": 1.00, "aggression": 0.75, "press_count": 2, "shot_range": 1.00},
	{"reaction": 0.09, "pass_acc": 0.95, "shot_acc": 0.92, "positioning": 1.00, "speed": 1.03, "tackle": 1.10, "gk": 1.20, "aggression": 1.00, "press_count": 3, "shot_range": 1.15},
]

var teams: Array[TeamData] = []
var mode := "quick"                 # quick | tournament | penalty | teams_view
var player_team_idx := 0
var opponent_team_idx := 1
var player_formation := ""          # "" = team default
var opponent_formation := ""
var pending_penalty: Dictionary = {}

# Settings
var difficulty := 1
var match_length := 90.0
var extra_time := false
var penalties_enabled := true
var master_vol := 0.8
var music_vol := 0.6
var sfx_vol := 0.9
var fullscreen := false
var resolution_idx := 0
var aim_assist := true
var camera_shake := true
var touch_mode := 0                 # 0 auto, 1 always on, 2 off

var stats := {"played": 0, "won": 0, "drawn": 0, "lost": 0, "gf": 0, "ga": 0, "tournaments_won": 0}
var tournament: Dictionary = {}

func _ready() -> void:
	_load_teams()
	_setup_input()
	load_all()
	apply_display()

# ---------------------------------------------------------------- teams
func _load_teams() -> void:
	for path: String in TEAM_PATHS:
		var res: Resource = load(path)
		if res is TeamData:
			teams.append(res)
	if teams.size() < 2:
		push_error("GameState: team resources failed to load, using fallbacks")
		var names := ["Red Lions", "Blue Sharks", "Golden Eagles", "Green Warriors", "Black Panthers", "White Wolves", "Orange United", "Purple Stars"]
		var cols := [Color.RED, Color.BLUE, Color.GOLD, Color.GREEN, Color(0.1, 0.1, 0.12), Color.WHITE, Color.ORANGE, Color.PURPLE]
		teams.clear()
		for i in names.size():
			var t := TeamData.new()
			t.team_name = names[i]
			t.short_name = names[i].substr(0, 3).to_upper()
			t.primary = cols[i]
			teams.append(t)

func get_team(i: int) -> TeamData:
	return teams[clampi(i, 0, teams.size() - 1)]

func ai_params(diff: int) -> Dictionary:
	return AI_PARAMS[clampi(diff, 0, 2)]

# ---------------------------------------------------------------- input map
func _setup_input() -> void:
	_action("move_up", [KEY_W, KEY_UP], [JOY_BUTTON_DPAD_UP])
	_action("move_down", [KEY_S, KEY_DOWN], [JOY_BUTTON_DPAD_DOWN])
	_action("move_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT])
	_action("move_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT])
	_action("shoot", [KEY_SPACE], [JOY_BUTTON_A])
	_action("pass", [KEY_E], [JOY_BUTTON_X])
	_action("sprint", [KEY_SHIFT], [JOY_BUTTON_RIGHT_SHOULDER])
	_action("switch", [KEY_Q], [JOY_BUTTON_Y])
	_action("tackle", [KEY_T], [JOY_BUTTON_B])
	_action("pause", [KEY_ESCAPE], [JOY_BUTTON_START])
	_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_axis("move_up", JOY_AXIS_LEFT_Y, -1.0)
	_axis("move_down", JOY_AXIS_LEFT_Y, 1.0)

func _action(action: String, keys: Array, buttons: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	for k: int in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k as Key
		InputMap.action_add_event(action, e)
	for b: int in buttons:
		var j := InputEventJoypadButton.new()
		j.button_index = b as JoyButton
		InputMap.action_add_event(action, j)

func _axis(action: String, axis: int, value: float) -> void:
	var m := InputEventJoypadMotion.new()
	m.axis = axis as JoyAxis
	m.axis_value = value
	InputMap.action_add_event(action, m)

# ---------------------------------------------------------------- settings / save
func apply_display() -> void:
	if OS.has_feature("web") or OS.has_feature("mobile"):
		return
	var w := get_window()
	if fullscreen:
		w.mode = Window.MODE_FULLSCREEN
	else:
		w.mode = Window.MODE_WINDOWED
		w.size = RESOLUTIONS[clampi(resolution_idx, 0, RESOLUTIONS.size() - 1)]
		w.move_to_center()

func settings_dict() -> Dictionary:
	return {"difficulty": difficulty, "match_length": match_length, "extra_time": extra_time,
		"penalties_enabled": penalties_enabled, "master_vol": master_vol, "music_vol": music_vol,
		"sfx_vol": sfx_vol, "fullscreen": fullscreen, "resolution_idx": resolution_idx,
		"aim_assist": aim_assist, "camera_shake": camera_shake, "touch_mode": touch_mode}

func save_all() -> void:
	SaveSystem.data = {
		"settings": settings_dict(),
		"selection": {"player": player_team_idx, "opponent": opponent_team_idx},
		"stats": stats,
		"tournament": tournament,
	}
	SaveSystem.save_data()

func load_all() -> void:
	var d: Dictionary = _fix(SaveSystem.data)
	var s: Dictionary = d.get("settings", {})
	difficulty = int(s.get("difficulty", difficulty))
	match_length = float(s.get("match_length", match_length))
	extra_time = bool(s.get("extra_time", extra_time))
	penalties_enabled = bool(s.get("penalties_enabled", penalties_enabled))
	master_vol = float(s.get("master_vol", master_vol))
	music_vol = float(s.get("music_vol", music_vol))
	sfx_vol = float(s.get("sfx_vol", sfx_vol))
	fullscreen = bool(s.get("fullscreen", fullscreen))
	resolution_idx = int(s.get("resolution_idx", resolution_idx))
	aim_assist = bool(s.get("aim_assist", aim_assist))
	camera_shake = bool(s.get("camera_shake", camera_shake))
	touch_mode = int(s.get("touch_mode", touch_mode))
	var sel: Dictionary = d.get("selection", {})
	player_team_idx = clampi(int(sel.get("player", 0)), 0, teams.size() - 1)
	opponent_team_idx = clampi(int(sel.get("opponent", 1)), 0, teams.size() - 1)
	var st: Dictionary = d.get("stats", {})
	for k: String in stats.keys():
		stats[k] = int(st.get(k, stats[k]))
	tournament = d.get("tournament", {})

## JSON turns every number into float; convert whole floats back to int so indexing works.
func _fix(v: Variant) -> Variant:
	if v is Dictionary:
		var out := {}
		for k: Variant in v.keys():
			out[k] = _fix(v[k])
		return out
	if v is Array:
		var arr := []
		for e: Variant in v:
			arr.append(_fix(e))
		return arr
	if v is float and v == floorf(v) and absf(v) < 1.0e9:
		return int(v)
	return v

# ---------------------------------------------------------------- match results
func finish_match(hg: int, ag: int, pen_winner: int = -1) -> void:
	stats["played"] += 1
	stats["gf"] += hg
	stats["ga"] += ag
	if hg > ag or (hg == ag and pen_winner == 0):
		stats["won"] += 1
	elif hg < ag or (hg == ag and pen_winner == 1):
		stats["lost"] += 1
	else:
		stats["drawn"] += 1
	if mode == "tournament" and not tournament.is_empty():
		_report_tournament(hg, ag, pen_winner)
	save_all()

func next_scene_after_match() -> String:
	if mode == "tournament":
		return "res://scenes/menus/tournament_screen.tscn"
	return "res://scenes/main_menu/main_menu.tscn"

# ---------------------------------------------------------------- tournament
func has_active_tournament() -> bool:
	return not tournament.is_empty() and int(tournament.get("champion", -1)) == -1 and not bool(tournament.get("eliminated", false))

func start_tournament(player_idx: int) -> void:
	var others: Array = range(teams.size())
	others.erase(player_idx)
	others.shuffle()
	var order: Array = [player_idx]
	order.append_array(others.slice(0, 7))
	order.shuffle()
	var fixtures: Array = []
	for i in range(0, 8, 2):
		fixtures.append({"home": order[i], "away": order[i + 1], "hg": -1, "ag": -1, "winner": -1, "pens": false})
	tournament = {"player": player_idx, "round": 0, "rounds": [fixtures], "eliminated": false, "champion": -1,
		"stats": {"w": 0, "l": 0, "gf": 0, "ga": 0, "pts": 0}}
	save_all()

func player_fixture() -> Dictionary:
	var rounds: Array = tournament["rounds"]
	var fixtures: Array = rounds[int(tournament["round"])]
	for f: Dictionary in fixtures:
		if f["home"] == tournament["player"] or f["away"] == tournament["player"]:
			return f
	return {}

func prepare_next_tournament_match() -> void:
	var f := player_fixture()
	if f.is_empty():
		return
	mode = "tournament"
	player_team_idx = int(tournament["player"])
	opponent_team_idx = int(f["away"]) if int(f["home"]) == player_team_idx else int(f["home"])
	player_formation = ""
	opponent_formation = ""

func _poisson(lam: float) -> int:
	var l := exp(-lam)
	var k := 0
	var p := 1.0
	while p > l:
		k += 1
		p *= randf()
	return k - 1

func _sim_fixture(f: Dictionary) -> void:
	var a: TeamData = teams[int(f["home"])]
	var b: TeamData = teams[int(f["away"])]
	var ra := (a.attack + 0.5 * a.midfield) / (b.defense + 0.5 * b.goalkeeper)
	var rb := (b.attack + 0.5 * b.midfield) / (a.defense + 0.5 * a.goalkeeper)
	var hg := _poisson(1.4 * ra * ra)
	var ag := _poisson(1.4 * rb * rb)
	f["hg"] = hg
	f["ag"] = ag
	f["pens"] = hg == ag
	if hg > ag:
		f["winner"] = f["home"]
	elif ag > hg:
		f["winner"] = f["away"]
	else:
		f["winner"] = f["home"] if randf() < float(a.overall()) / float(a.overall() + b.overall()) else f["away"]

func _report_tournament(hg: int, ag: int, pen_winner: int) -> void:
	var t := tournament
	var fixtures: Array = t["rounds"][int(t["round"])]
	var ts: Dictionary = t["stats"]
	for f: Dictionary in fixtures:
		if f["home"] == t["player"] or f["away"] == t["player"]:
			var is_home: bool = f["home"] == t["player"]
			f["hg"] = hg if is_home else ag
			f["ag"] = ag if is_home else hg
			var won := hg > ag or (hg == ag and pen_winner == 0)
			f["winner"] = t["player"] if won else (f["away"] if is_home else f["home"])
			f["pens"] = hg == ag
			ts["gf"] += hg
			ts["ga"] += ag
			if won:
				ts["w"] += 1
				ts["pts"] += 3
			else:
				ts["l"] += 1
				t["eliminated"] = true
		elif int(f["winner"]) == -1:
			_sim_fixture(f)
	_advance_rounds()

func _advance_rounds() -> void:
	var t := tournament
	while true:
		var rounds: Array = t["rounds"]
		var r := int(t["round"])
		var fixtures: Array = rounds[r]
		for f: Dictionary in fixtures:
			if int(f["winner"]) == -1:
				if bool(t["eliminated"]):
					_sim_fixture(f)
				else:
					return   # player still has to play this round
		var winners: Array = []
		for f: Dictionary in fixtures:
			winners.append(f["winner"])
		if winners.size() == 1:
			t["champion"] = winners[0]
			t["round"] = 3
			if winners[0] == t["player"]:
				stats["tournaments_won"] += 1
			return
		var next: Array = []
		for i in range(0, winners.size(), 2):
			next.append({"home": winners[i], "away": winners[i + 1], "hg": -1, "ag": -1, "winner": -1, "pens": false})
		rounds.append(next)
		t["round"] = r + 1
		if not bool(t["eliminated"]):
			return

func clear_tournament() -> void:
	tournament = {}
	save_all()
