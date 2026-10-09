extends Node
## Every sound in the game, synthesised at start-up. Sfx.play("door") or Sfx.play("bark", where).

const RATE := 22050

var listener := Vector3.ZERO     # the player's position, for distance fall-off
var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _rain: AudioStreamPlayer
var _night: AudioStreamPlayer
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
	}
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_rain = _loop(_noise(1.5, 0.22, 0.0, 0.35))
	_night = _loop(_crickets())


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


func _crickets() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(2.0 * RATE))
	for i in out.size():
		var t := float(i) / RATE
		var chirp := maxf(0.0, sin(TAU * 3.0 * t)) * maxf(0.0, sin(TAU * 34.0 * t))
		out[i] = sin(TAU * 4100.0 * t) * chirp * 0.1
	return out
