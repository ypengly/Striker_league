class_name Team
extends RefCounted
## One side in a match: owns 11 players, formation shape, AI designations (who presses / marks),
## and which player the human controls.

const SURNAMES := ["Silva", "Novak", "Okoye", "Tanaka", "Moreau", "Duarte", "Kovac", "Haddad", "Larsen", "Ferrari",
	"Mensah", "Ivanov", "Costa", "Bauer", "Yilmaz", "Santos", "Petrov", "Nguyen", "Rossi", "Diaz",
	"Keller", "Amari", "Lopez", "Weber", "Sato", "Ramos", "Berg", "Popov", "Fall", "Hale", "Ortiz", "Vega"]
const NUMBERS := [1, 2, 4, 5, 3, 7, 6, 8, 11, 10, 9]

var game: MatchManager
var data: TeamData
var side := 1
var is_human := false
var formation := "4-4-2"
var kit_primary := Color.RED
var kit_secondary := Color.WHITE
var gk_kit := Color(0.2, 0.85, 0.35)
var ai: Dictionary = {}
var gk_mult := 1.0
var players: Array[Player] = []
var goalkeeper: Goalkeeper
var controlled: Player = null
var stats := {"shots": 0, "on_target": 0, "saves": 0, "fouls": 0, "corners": 0, "tackles": 0, "passes": 0, "possession": 0.0}

var _think := 0.0
var _manual_lock := 0.0
var _auto_cd := 0.0

func setup(g: MatchManager, td: TeamData, s: int, human: bool, form: String, params: Dictionary, kp: Color, ks: Color) -> void:
	game = g
	data = td
	side = s
	is_human = human
	formation = form if form != "" else td.formation
	ai = params
	gk_mult = 1.0 if human else float(params.get("gk", 1.0))
	kit_primary = kp
	kit_secondary = ks
	gk_kit = Color(1.0, 0.7, 0.1) if (kp.g > 0.45 and kp.r < 0.5 and kp.b < 0.5) else Color(0.2, 0.85, 0.35)

func spawn_players(parent: Node2D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(data.team_name) + side
	var layout: Array = Formations.get_layout(formation)
	var names: Array = SURNAMES.duplicate()
	for i in layout.size():
		var slot: Array = layout[i]
		var role: int = slot[2]
		var p: Player
		if role == 0:
			p = Goalkeeper.new()
		else:
			p = Player.new()
		var st := PlayerStats.generate(data, role, rng)
		var nm := "%s. %s" % [char(65 + rng.randi() % 26), names.pop_at(rng.randi() % names.size())]
		p.setup(self, i, role, st, nm, NUMBERS[i])
		parent.add_child(p)
		players.append(p)
		if role == 0:
			goalkeeper = p as Goalkeeper
	reset_for_kickoff(false)

func reset_for_kickoff(kicks_off: bool) -> void:
	var layout: Array = Formations.get_layout(formation)
	for i in players.size():
		var p: Player = players[i]
		var pos := Formations.world_pos(layout[i], side, Vector2.ZERO, false, true)
		if not kicks_off and p.role != 0 and pos.length() < Pitch.CIRCLE_R + 30.0:
			pos = pos.normalized() * (Pitch.CIRCLE_R + 35.0) if pos.length() > 1.0 else Vector2(-side * (Pitch.CIRCLE_R + 35.0), 0.0)
		p.reset_state(pos, side)
		p.home_pos = pos

func kickoff_taker() -> Player:
	return players[players.size() - 1]

func nearest_outfield_to(pos: Vector2, exclude: Player = null) -> Player:
	var best: Player = null
	var bd := 1.0e12
	for p in players:
		if p.role == Player.Role.GK or p == exclude:
			continue
		var d := p.position.distance_squared_to(pos)
		if d < bd:
			bd = d
			best = p
	return best

# ---------------------------------------------------------------- human control
func set_controlled(p: Player) -> void:
	if p == null or not is_human or p.role == Player.Role.GK:
		return
	if controlled != null:
		controlled.is_human = false
		controlled.charging = false
		controlled.charge = 0.0
		controlled.pass_preview = null
	controlled = p
	p.is_human = true

func switch_player() -> void:
	if not is_human:
		return
	var b := game.ball
	var target: Player = null
	if b.carrier != null and b.carrier.team == self and b.carrier != controlled and b.carrier.role != Player.Role.GK:
		target = b.carrier
	else:
		target = nearest_outfield_to(b.position, controlled)
	if target != null:
		set_controlled(target)
		_manual_lock = 1.2
		AudioManager.play("hover", -4.0, 1.3)

func _auto_switch(delta: float) -> void:
	_manual_lock -= delta
	_auto_cd -= delta
	if not is_human or _manual_lock > 0.0 or _auto_cd > 0.0:
		return
	_auto_cd = 0.25
	var b := game.ball
	if b.carrier != null and b.carrier.team == self:
		return
	var best := nearest_outfield_to(b.position)
	if best != null and controlled != null and best != controlled:
		if best.position.distance_to(b.position) + 70.0 < controlled.position.distance_to(b.position):
			set_controlled(best)

# ---------------------------------------------------------------- team AI
func update(delta: float) -> void:
	_auto_switch(delta)
	_think -= delta
	if _think > 0.0:
		return
	_think = 0.12
	_designate()
	_compute_home()

func _designate() -> void:
	var b := game.ball
	var opp := game.opponent_of(self)
	for p in players:
		p.designation = ""
		p.mark_target = null
	var carrier := b.carrier
	var has_ball := carrier != null and carrier.team == self
	if has_ball:
		return
	if b.pass_target != null and b.pass_target.team == self and carrier == null:
		return
	var cands: Array[Player] = []
	for p in players:
		if p.role != Player.Role.GK and not p.is_human and p.stun <= 0.0:
			cands.append(p)
	var ref := b.position + b.vel * 0.3
	cands.sort_custom(func(a: Player, c: Player) -> bool: return a.position.distance_squared_to(ref) < c.position.distance_squared_to(ref))
	var n := 1 if carrier == null else int(ai.get("press_count", 1))
	for i in mini(n, cands.size()):
		cands[i].designation = "chase" if carrier == null else "press"
	if carrier != null:
		var free_opps: Array[Player] = []
		for o in opp.players:
			if o != carrier and o.role != Player.Role.GK:
				free_opps.append(o)
		for p in cands:
			if p.designation != "" or (p.role != Player.Role.DEF and p.role != Player.Role.MID):
				continue
			var best: Player = null
			var bd := 350.0
			for o in free_opps:
				var d := p.position.distance_to(o.position)
				if d < bd:
					bd = d
					best = o
			if best != null:
				p.mark_target = best
				free_opps.erase(best)

func _compute_home() -> void:
	var b := game.ball
	var has := b.carrier != null and b.carrier.team == self
	var layout: Array = Formations.get_layout(formation)
	var shift := 0.5 + 0.5 * float(ai.get("positioning", 1.0))
	for i in players.size():
		players[i].home_pos = Formations.world_pos(layout[i], side, b.position, has, false, shift)
