class_name Dog
extends Node3D
## A yard dog. Barks at strangers who come close, which brings its owners to the window.

var house: House
var player: Player
var quiet_until := 0.0     # clock minutes: busy with a biscuit
var barking := false
var _bark_t := 0.0
var _calm := 0.0
var _body: Node3D
var _bubble: Label3D


func setup(h: House, p: Player, color: Color) -> void:
	house = h
	player = p
	_body = Node3D.new()
	add_child(_body)
	Build.box(_body, Vector3(0.3, 0.32, 0.75), Vector3(0, 0.42, 0), color)
	Build.box(_body, Vector3(0.24, 0.24, 0.28), Vector3(0, 0.62, 0.42), color.darkened(0.1))
	Build.box(_body, Vector3(0.06, 0.06, 0.3), Vector3(0, 0.6, -0.45), color)
	for x: float in [-0.1, 0.1]:
		for z: float in [-0.28, 0.28]:
			Build.box(_body, Vector3(0.08, 0.3, 0.08), Vector3(x, 0.15, z), color.darkened(0.2))
	_bubble = Build.label(self, "", Vector3(0, 1.4, 0), 64)
	_bubble.modulate = Color("ffd84a")


## How close the player can get before the dog kicks off.
func alert_range() -> float:
	var r := 5.0 if player.sneaking else (13.0 if player.speed_now > 4.0 else 8.5)
	if Clock.is_night():
		r *= 0.6   # asleep on the porch
	return r


func _process(delta: float) -> void:
	var to := player.global_position - global_position
	to.y = 0.0
	var trigger: bool = to.length() < alert_range() and Clock.minutes >= quiet_until and player.visible and Game.ctx.get("zone", "") != "home"
	if trigger:
		_calm = 3.0
	else:
		_calm -= delta
	barking = _calm > 0.0 and Clock.minutes >= quiet_until
	_bubble.text = "WOOF" if barking else ""
	if not barking:
		_body.position.y = 0.0
		return
	_body.rotation.y = lerp_angle(_body.rotation.y, atan2(to.x, to.z), minf(1.0, delta * 8.0))
	_body.position.y = absf(sin(Time.get_ticks_msec() * 0.012)) * 0.12
	_bark_t -= delta
	if _bark_t <= 0.0:
		_bark_t = 1.5
		Game.noise.emit(global_position, 18.0, "bark")


func feed() -> void:
	quiet_until = Clock.minutes + 180.0
	_calm = 0.0
	Game.say("The dog settles down with the biscuit. That buys you a few hours.")
