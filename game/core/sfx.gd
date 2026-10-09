extends Node
## Every sound in the game, synthesised at start-up. Sfx.play("door") or Sfx.play("bark", where).

const RATE := 22050

var listener := Vector3.ZERO     # the player's position, for distance fall-off
var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _rain: AudioStreamPlayer
var _night: AudioStreamPlayer
var _birds: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _pad: AudioStreamPlayer
var _tense: AudioStreamPlayer
var tension := 0.0              # 0 calm .. 1 someone is on to you; set by the HUD
var _tension_now := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 1984
	_streams = {
		"step": _wav(_noise(0.05, 0.25, 30.0, 0.25)),
		"pick": _wav(_mix(_tone(2600.0, 0.03, 0.2, 90.0), _noise(0.03, 0.15, 80.0, 0.9))),
		"door": _wav(_mix(_tone(110.0, 0.18, 0.5, 18.0), _noise(0.12, 0.25, 25.0, 0.3))),
		"bark": _wav(_join([_bark(), _silence(0.07), _bark()])),
		"alarm": _wav(_join([_tone(880.0, 0.12, 0.35, 6.0), _tone(660.0, 0.25, 0.35, 5.0)])),
		"notice": _wav(_tone(520.0, 0.09, 0.2, 14.0)),
		"shutter": _wav(_join([_noise(0.02, 0.5, 60.0, 1.0), _silence(0.05), _noise(0.03, 0.4, 50.0, 0.8)])),
		"note": _wav(_noise(0.06, 0.12, 40.0, 0.6)),
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
	_birds = _loop(_birdsong())
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


## Called every frame with how hard it is raining (0..1) and how dark it is (0..1).
func ambience(rain: float, night: float, indoors: bool) -> void:
	_fade(_rain, rain, -10.0 - (8.0 if indoors else 0.0))
	_fade(_night, night * (1.0 - rain) * (0.0 if indoors else 1.0), -20.0)
	_fade(_birds, (1.0 - night) * (1.0 - rain) * (0.35 if indoors else 1.0), -19.0)
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


## Sparse two- and three-note chirps over six seconds.
func _birdsong() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(6.0 * RATE))
	for k in 9:
		var at := _rng.randf_range(0.1, 5.5)
		var base := _rng.randf_range(2400.0, 3800.0)
		for note in _rng.randi_range(2, 4):
			var start := int((at + note * 0.11) * RATE)
			var ph := 0.0
			var n := int(0.07 * RATE)
			for i in n:
				if start + i >= out.size():
					break
				var t := float(i) / n
				ph += TAU * (base + 500.0 * sin(t * PI) + note * 180.0) / RATE
				out[start + i] += sin(ph) * 0.1 * sin(t * PI)
	return out


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
	out.resize(int(2.0 * RATE))
	for i in out.size():
		var t := float(i) / RATE
		var chirp := maxf(0.0, sin(TAU * 3.0 * t)) * maxf(0.0, sin(TAU * 34.0 * t))
		out[i] = sin(TAU * 4100.0 * t) * chirp * 0.1
	return out
