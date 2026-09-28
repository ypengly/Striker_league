extends Node
## Procedural audio. Every sound is synthesised at start-up so the project needs no asset files.
## To swap in real audio: AudioManager.register_stream("kick", load("res://assets/audio/kick.wav"))
## Autoload "AudioManager". Buses "Music" and "SFX" are created at runtime.

const RATE := 22050
const LOW_RATE := 11025
const POOL_SIZE := 12

var _sfx: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()
var _lp := 0.0
var _phase := 0.0
var _rate := RATE
var _amb_on := false
var _excite := 0.0
var _excite_target := 0.0
var _music_low := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 4242
	_ensure_bus("Music")
	_ensure_bus("SFX")
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = "SFX"
	add_child(_ambience)
	for k: String in ["kick", "pass", "tackle", "save", "post", "click", "hover", "whistle", "goal"]:
		var dur := {"kick": 0.2, "pass": 0.14, "tackle": 0.35, "save": 0.25, "post": 0.45, "click": 0.08, "hover": 0.05, "whistle": 0.7, "goal": 0.95}[k] as float
		_sfx[k] = _gen(k, dur, RATE, false)
	_sfx["cheer"] = _gen("cheer", 2.6, LOW_RATE, false)
	_sfx["ooh"] = _gen("ooh", 1.4, LOW_RATE, false)
	apply_volumes()

func register_stream(sound: String, stream: AudioStream) -> void:
	_sfx[sound] = stream

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, bus_name)
		AudioServer.set_bus_send(i, "Master")

func apply_volumes() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(GameState.master_vol, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(GameState.music_vol, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(GameState.sfx_vol, 0.0001)))

# ---------------------------------------------------------------- playback
func play(sound: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var stream: AudioStream = _sfx.get(sound)
	if stream == null:
		return
	for p in _pool:
		if not p.playing:
			p.stream = stream
			p.volume_db = volume_db
			p.pitch_scale = pitch * randf_range(0.96, 1.04)
			p.play()
			return

func cheer(strength: float = 1.0) -> void:
	play("cheer", -6.0 + strength * 5.0)
	_excite_target = maxf(_excite_target, strength)
	_excite = maxf(_excite, strength * 0.7)

func ooh() -> void:
	play("ooh", -4.0)
	_excite = maxf(_excite, 0.4)

func set_excitement(v: float) -> void:
	_excite_target = maxf(_excite_target, v)

func play_music(low: bool = false) -> void:
	_music_low = low
	if _music.stream == null:
		_music.stream = _gen_music()
	_music.volume_db = -14.0 if low else -3.0
	if not _music.playing:
		_music.play()

func stop_music() -> void:
	_music.stop()

func start_ambience() -> void:
	if _ambience.stream == null:
		_ambience.stream = _gen("ambience", 3.0, LOW_RATE, true)
	_amb_on = true
	_excite = 0.15
	_excite_target = 0.15
	if not _ambience.playing:
		_ambience.play()

func stop_ambience() -> void:
	_amb_on = false
	_ambience.stop()

func _process(delta: float) -> void:
	if _amb_on:
		_excite = move_toward(_excite, _excite_target, delta * 0.9)
		_excite_target = move_toward(_excite_target, 0.15, delta * 0.2)
		_ambience.volume_db = lerpf(-26.0, -7.0, clampf(_excite, 0.0, 1.0))

# ---------------------------------------------------------------- synthesis
func _noise() -> float:
	return _rng.randf() * 2.0 - 1.0

func _gen(kind: String, dur: float, rate: int, loop: bool) -> AudioStreamWAV:
	_rate = rate
	_lp = 0.0
	_phase = 0.0
	var n := int(dur * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var s := _sample(kind, float(i) / rate, dur)
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 30000.0))
	return _wav(data, rate, loop, n)

func _wav(data: PackedByteArray, rate: int, loop: bool, n: int) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = n
	return w

func _sample(kind: String, t: float, dur: float) -> float:
	match kind:
		"kick":
			return _noise() * exp(-t * 70.0) * 0.55 + sin(TAU * 150.0 * t) * exp(-t * 28.0) * 0.8
		"pass":
			return _noise() * exp(-t * 90.0) * 0.3 + sin(TAU * 210.0 * t) * exp(-t * 40.0) * 0.5
		"tackle":
			_lp += (_noise() - _lp) * 0.25
			return _lp * exp(-t * 14.0) * 1.6 + sin(TAU * 80.0 * t) * exp(-t * 20.0) * 0.6
		"save":
			_lp += (_noise() - _lp) * 0.5
			return _lp * exp(-t * 12.0) * 1.1 + sin(TAU * 320.0 * t) * exp(-t * 30.0) * 0.4
		"post":
			return (sin(TAU * 1250.0 * t) * 0.5 + sin(TAU * 1870.0 * t) * 0.3) * exp(-t * 9.0)
		"click":
			return sin(TAU * (900.0 + t * 3000.0) * t) * exp(-t * 60.0) * 0.6
		"hover":
			return sin(TAU * 1400.0 * t) * exp(-t * 90.0) * 0.35
		"whistle":
			var f := 2850.0 + sin(TAU * 30.0 * t) * 260.0
			_phase += TAU * f / _rate
			var env := minf(t * 40.0, 1.0) * clampf((dur - t) * 8.0, 0.0, 1.0)
			return (sin(_phase) * 0.55 + _noise() * 0.08) * env
		"goal":
			var idx := mini(int(t / 0.13), 4)
			var notes := [523.25, 659.25, 783.99, 1046.5, 1318.5]
			var fr: float = notes[idx]
			var lt := t - float(idx) * 0.13
			return (signf(sin(TAU * fr * t)) * 0.16 + sin(TAU * fr * t) * 0.3) * exp(-lt * 3.5)
		"cheer":
			_lp += (_noise() - _lp) * 0.22
			var e := clampf(t / 0.35, 0.0, 1.0) * exp(-maxf(t - 0.5, 0.0) * 1.3)
			return _lp * e * 2.6
		"ooh":
			_phase += TAU * (260.0 - t * 90.0) / _rate
			_lp += (_noise() - _lp) * 0.15
			var e2 := clampf(t / 0.2, 0.0, 1.0) * exp(-t * 1.6)
			return (sin(_phase) * 0.35 + _lp * 0.8) * e2
		"ambience":
			_lp += (_noise() - _lp) * 0.06
			var edge := minf(minf(t, dur - t) / 0.08, 1.0)
			return _lp * (1.5 + sin(TAU * 0.5 * t) * 0.4) * edge
	return 0.0

## Simple looping chiptune-style track (Am - F - C - G).
func _gen_music() -> AudioStreamWAV:
	var rate := LOW_RATE
	var beat := 60.0 / 124.0
	var dur := beat * 4.0 * 4.0
	var n := int(dur * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	var roots := [110.0, 87.31, 130.81, 98.0]
	var thirds := [3, 4, 4, 4]
	for i in n:
		var t := float(i) / rate
		var b := t / beat
		var bar := int(b / 4.0) % 4
		var root: float = roots[bar]
		var third: int = thirds[bar]
		var tb := fmod(b, 1.0) * beat
		var s := signf(sin(TAU * root * t)) * 0.13 * exp(-tb * 4.0)
		s += sin(TAU * (48.0 + 90.0 * exp(-tb * 40.0)) * tb) * exp(-tb * 12.0) * 0.5
		var th := fmod(b + 0.5, 1.0) * beat
		s += _noise() * exp(-th * 60.0) * 0.06
		var step := int(b * 2.0)
		var e8 := fmod(b * 2.0, 1.0) * beat * 0.5
		var offs := [0, third, 7, 12]
		var off: int = offs[step % 4]
		var fr := root * 4.0 * pow(2.0, off / 12.0)
		s += signf(sin(TAU * fr * t)) * 0.07 * exp(-e8 * 9.0)
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 26000.0))
	return _wav(data, rate, true, n)
