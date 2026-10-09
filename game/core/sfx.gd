extends Node
## Every sound in the game, synthesised at start-up. Sfx.play("door") or Sfx.play("bark", where).

const RATE := 22050

var listener := Vector3.ZERO     # the player's position, for distance fall-off
var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _rain: AudioStreamPlayer
var _night: AudioStreamPlayer
var _bird: AudioStreamPlayer        # one bird call at a time, at random intervals
var _calls: Array[AudioStreamWAV] = []
var _bird_wait := 3.0
var _indoors := false
var _wind: AudioStreamPlayer
var _pad: AudioStreamPlayer
var _tense: AudioStreamPlayer
var tension := 0.0              # 0 calm .. 1 someone is on to you; set by the HUD
var _tension_now := 0.0
var _rng := RandomNumberGenerator.new()


var volume := 0.6                # master volume 0..1; the - and = keys change it


func _unhandled_key_input(e: InputEvent) -> void:
	var k := (e as InputEventKey).physical_keycode
	if e.is_pressed() and (k == KEY_MINUS or k == KEY_EQUAL):
		volume = clampf(volume + (-0.1 if k == KEY_MINUS else 0.1), 0.0, 1.0)
		AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.001)))
		Game.say("Volume %d%%" % roundi(volume * 100.0))


func _ready() -> void:
	_rng.seed = 1984
	AudioServer.set_bus_volume_db(0, linear_to_db(volume))
	_streams = {
		# footsteps: a heel knock on boards, a sharper tap on pavement, a soft brush through grass
		"step_wood": _wav(_join([_mix(_tone(92.0, 0.07, 0.5, 45.0), _noise(0.03, 0.3, 90.0, 0.5)), _silence(0.03), _noise(0.03, 0.1, 80.0, 0.4)])),
		"step_hard": _wav(_join([_mix(_tone(170.0, 0.035, 0.22, 80.0), _noise(0.03, 0.4, 90.0, 0.8)), _silence(0.035), _noise(0.025, 0.14, 90.0, 0.7)])),
		"step_grass": _wav(_soft(_noise(0.14, 0.3, 16.0, 0.3), 0.025)),
		"hit": _wav(_mix(_tone(130.0, 0.1, 0.7, 30.0), _noise(0.06, 0.6, 55.0, 0.45))),
		"pick": _wav(_mix(_tone(2600.0, 0.03, 0.2, 90.0), _noise(0.03, 0.15, 80.0, 0.9))),
		# hinge creak, latch click, then the door meeting its frame
		"door": _wav(_join([_creak(), _mix(_tone(1700.0, 0.02, 0.2, 120.0), _noise(0.02, 0.3, 120.0, 0.9)), _silence(0.04), _mix(_tone(85.0, 0.16, 0.5, 22.0), _noise(0.08, 0.2, 35.0, 0.25))])),
		"bark": _wav(_join([_bark(), _silence(0.07), _bark()])),
		"alarm": _wav(_join([_tone(880.0, 0.12, 0.35, 6.0), _tone(660.0, 0.25, 0.35, 5.0)])),
		"notice": _wav(_tone(520.0, 0.09, 0.2, 14.0)),
		"shutter": _wav(_join([_noise(0.02, 0.5, 60.0, 1.0), _silence(0.05), _noise(0.03, 0.4, 50.0, 0.8)])),
		"note": _wav(_rustle()),
		"static": _wav(_static()),
		"siren": _wav(_siren()),
		"thud": _wav(_mix(_tone(70.0, 0.25, 0.7, 12.0), _noise(0.1, 0.3, 30.0, 0.2))),
		"whistle": _wav(_mix(_tone(392.0, 1.6, 0.14, 0.6), _tone(494.0, 1.6, 0.1, 0.6))),
		"thunder": _wav(_mix(_noise(3.0, 0.7, 1.2, 0.03), _noise(0.4, 0.3, 6.0, 0.15))),
	}
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_rain = _loop(_noise(1.5, 0.22, 0.0, 0.35))
	_night = _loop(_crickets())
	_bird = AudioStreamPlayer.new()
	add_child(_bird)
	_calls = [_wav(_chirps(3, 3100.0)), _wav(_chirps(2, 2500.0)), _wav(_chirps(9, 3600.0)), _wav(_whistle_call()), _wav(_coo())]
	_wind = _loop(_windy())
	_pad = _loop(_chords([110.0, 130.81, 164.81], [98.0, 123.47, 146.83]))
	_tense = _loop(_chords([55.0, 58.27, 82.41], [55.0, 61.74, 77.78]))


func play(sound: String, at: Variant = null, volume_db := 0.0) -> void:
	var vol := volume_db
	if at is Vector3:
		var d: float = (at as Vector3).distance_to(listener)
		if d > 40.0:
			return
		vol -= d * 0.6
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = _streams[sound]
	p.volume_db = vol
	p.pitch_scale = _rng.randf_range(0.94, 1.06)
	p.play()


## A footfall for the player: boards indoors, pavement on the road and sidewalk, grass elsewhere.
func step(paved: bool, volume_db: float) -> void:
	play("step_wood" if _indoors else ("step_hard" if paved else "step_grass"), null, volume_db + (0.0 if _indoors or paved else 4.0))


## Called every frame with how hard it is raining (0..1) and how dark it is (0..1).
func ambience(rain: float, night: float, indoors: bool) -> void:
	_fade(_rain, rain, -10.0 - (8.0 if indoors else 0.0))
	_fade(_night, night * (1.0 - rain) * (0.0 if indoors else 1.0), -20.0)
	_indoors = indoors
	# birds: single calls at random, busy at dawn and sparse by afternoon
	_bird_wait -= get_process_delta_time()
	if _bird_wait <= 0.0:
		var h := Clock.hour()
		var dawn := h >= 5.0 and h < 9.0
		_bird_wait = _rng.randf_range(1.5, 5.0) if dawn else _rng.randf_range(6.0, 16.0)
		if night < 0.6 and rain < 0.3:
			_bird.stream = _calls[_rng.randi() % _calls.size()]
			_bird.pitch_scale = _rng.randf_range(0.85, 1.2)
			_bird.volume_db = _rng.randf_range(-32.0, -23.0) - (9.0 if indoors else 0.0)
			_bird.play()
	_fade(_wind, 0.5 + rain * 0.5, -24.0 - (6.0 if indoors else 0.0))
	_tension_now = move_toward(_tension_now, tension, 0.01)
	_fade(_pad, night * (1.0 - _tension_now), -21.0)
	_fade(_tense, _tension_now, -13.0)


func _fade(p: AudioStreamPlayer, amount: float, full_db: float) -> void:
	if amount < 0.02:
		if p.playing:
			p.stop()
		return
	if not p.playing:
		p.play()
	p.volume_db = full_db + linear_to_db(clampf(amount, 0.02, 1.0))


func _loop(samples: PackedFloat32Array) -> AudioStreamPlayer:
	var s := _wav(samples)
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_end = samples.size()
	var p := AudioStreamPlayer.new()
	p.stream = s
	add_child(p)
	return p


func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.data = bytes
	return s


func _tone(freq: float, dur: float, vol: float, decay: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(dur * RATE))
	for i in out.size():
		var t := float(i) / RATE
		out[i] = sin(TAU * freq * t) * vol * exp(-decay * t) * minf(1.0, t * 400.0)
	return out


## White noise through a one-pole low-pass (`bright` 0 dull .. 1 hissy).
func _noise(dur: float, vol: float, decay: float, bright: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(dur * RATE))
	var y := 0.0
	for i in out.size():
		var t := float(i) / RATE
		y += (_rng.randf_range(-1.0, 1.0) - y) * bright
		out[i] = y * vol * exp(-decay * t)
	return out


func _silence(dur: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(dur * RATE))
	return out


func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var out := a.duplicate() if a.size() >= b.size() else b.duplicate()
	var other := b if a.size() >= b.size() else a
	for i in other.size():
		out[i] += other[i]
	return out


func _join(parts: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for p: PackedFloat32Array in parts:
		out.append_array(p)
	return out


func _bark() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(0.13 * RATE))
	var ph := 0.0
	for i in out.size():
		var t := float(i) / RATE
		ph += TAU * (420.0 - 1400.0 * t) / RATE
		out[i] = (signf(sin(ph)) * 0.25 + _rng.randf_range(-0.2, 0.2)) * exp(-14.0 * t) * minf(1.0, t * 300.0)
	return out


func _static() -> PackedFloat32Array:
	var out := _noise(2.2, 0.22, 0.2, 0.7)
	# a numbers station under the hiss: five slow pips
	for k in 5:
		var pip := _tone(700.0, 0.12, 0.2, 4.0)
		var at := int((0.3 + k * 0.36) * RATE)
		for i in pip.size():
			out[at + i] += pip[i]
	return out


func _siren() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(2.4 * RATE))
	var ph := 0.0
	for i in out.size():
		var t := float(i) / RATE
		ph += TAU * (650.0 + 250.0 * sin(TAU * t / 1.2)) / RATE
		out[i] = sin(ph) * 0.16 * minf(1.0, (2.4 - t) * 2.0)
	return out


## `notes` quick rising chirps (three is a sparrow, nine is a trill).
func _chirps(notes: int, base: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var gap := 0.11 if notes < 5 else 0.06
	out.resize(int((notes * gap + 0.1) * RATE))
	for note in notes:
		var start := int(note * gap * RATE)
		var ph := 0.0
		var n := int(minf(gap * 0.7, 0.07) * RATE)
		for i in n:
			var t := float(i) / n
			ph += TAU * (base + 500.0 * sin(t * PI) + (note % 3) * 180.0) / RATE
			out[start + i] += sin(ph) * 0.1 * sin(t * PI)
	return out


## Two long falling notes, like a chickadee.
func _whistle_call() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for f: float in [3300.0, 2750.0]:
		var n := int(0.3 * RATE)
		var ph := 0.0
		for i in n:
			var t := float(i) / n
			ph += TAU * (f - 120.0 * t) / RATE
			out.append(sin(ph) * 0.08 * sin(t * PI))
		out.append_array(_silence(0.08))
	return out


## A mourning dove: coo-COOO, coo, coo.
func _coo() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for part: Array in [[0.18, 470.0], [0.5, 560.0], [0.3, 470.0], [0.3, 470.0]]:
		var n := int(float(part[0]) * RATE)
		var ph := 0.0
		for i in n:
			var t := float(i) / n
			ph += TAU * (float(part[1]) - 40.0 * t) / RATE
			out.append((sin(ph) + 0.3 * sin(ph * 2.0)) * 0.09 * sin(t * PI))
		out.append_array(_silence(0.12))
	return out


## A dry hinge: a quiet, wavering rasp that rises as the door swings.
func _creak() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(0.24 * RATE))
	var ph := 0.0
	for i in out.size():
		var t := float(i) / out.size()
		ph += (230.0 + 170.0 * t + 25.0 * sin(t * 60.0)) / RATE
		out[i] = (fmod(ph, 1.0) * 2.0 - 1.0) * 0.05 * sin(t * PI)
	return out


## Paper: a crackle of short bright bursts.
func _rustle() -> PackedFloat32Array:
	var out := _noise(0.28, 0.3, 5.0, 0.85)
	var gate := 0.0
	for i in out.size():
		if i % 180 == 0:
			gate = _rng.randf()
		out[i] *= gate * gate * sin(PI * float(i) / out.size())
	return out


## Fade the start in over `secs`, for sounds with no hard edge.
func _soft(samples: PackedFloat32Array, secs: float) -> PackedFloat32Array:
	var n := int(secs * RATE)
	for i in mini(n, samples.size()):
		samples[i] *= float(i) / n
	return samples


## Slow breathing hiss.
func _windy() -> PackedFloat32Array:
	var out := _noise(8.0, 0.3, 0.0, 0.04)
	for i in out.size():
		var t := float(i) / out.size()
		out[i] *= 0.55 + 0.45 * sin(TAU * t) * sin(TAU * t * 3.0)
	return out


## A slow pad: two chords, eight seconds each, soft detuned sines that loop cleanly.
func _chords(first: Array, second: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var half := int(8.0 * RATE)
	out.resize(half * 2)
	for c in 2:
		var notes: Array = first if c == 0 else second
		for i in half:
			var t := float(i) / RATE
			var env := sin(PI * float(i) / half)
			var v := 0.0
			for f: float in notes:
				# whole numbers of cycles in 8 s, so the loop point is silent and click-free
				var ff := roundf(f * 8.0) / 8.0
				v += sin(TAU * ff * t) + 0.5 * sin(TAU * ff * 2.0 * t + 0.4) + 0.6 * sin(TAU * (ff + 0.25) * t)
			out[c * half + i] = v * 0.035 * env * env
	return out


func _crickets() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(6.0 * RATE))
	for i in out.size():
		var t := float(i) / RATE
		var near := maxf(0.0, sin(TAU * 3.0 * t)) * maxf(0.0, sin(TAU * 34.0 * t)) * (0.6 + 0.4 * sin(TAU * t / 6.0))
		var far := maxf(0.0, sin(TAU * 2.5 * t + 1.0)) * maxf(0.0, sin(TAU * 29.0 * t)) * maxf(0.0, sin(TAU * t / 3.0))
		out[i] = sin(TAU * 4100.0 * t) * near * 0.09 + sin(TAU * 3650.0 * t) * far * 0.05
	return out
