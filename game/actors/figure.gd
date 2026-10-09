class_name Figure
extends Node3D
## A low-poly person made of boxes, with a walk swing and a lying-down pose.

var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _phase := 0.0
var _down := false
var carried: Node3D   # small box shown in the hands


func build(look: Dictionary) -> void:
	var skin := Color(look.get("skin", "e8c4a0"))
	var shirt := Color(look.get("shirt", "3b5d8a"))
	var pants := Color(look.get("pants", "3a3f52"))
	var hair := Color(look.get("hair", "2b2118"))
	Build.box(self, Vector3(0.5, 0.6, 0.28), Vector3(0, 1.15, 0), shirt)
	Build.box(self, Vector3(0.3, 0.3, 0.3), Vector3(0, 1.62, 0), skin)
	Build.box(self, Vector3(0.32, 0.12, 0.32), Vector3(0, 1.8, -0.01), hair)
	Build.box(self, Vector3(0.32, 0.2, 0.08), Vector3(0, 1.7, -0.13), hair)
	for sx: float in [-0.13, 0.13]:
		var leg := Node3D.new()
		leg.position = Vector3(sx, 0.85, 0)
		add_child(leg)
		Build.box(leg, Vector3(0.2, 0.85, 0.22), Vector3(0, -0.425, 0), pants)
		_legs.append(leg)
	for sx: float in [-0.32, 0.32]:
		var arm := Node3D.new()
		arm.position = Vector3(sx, 1.42, 0)
		add_child(arm)
		Build.box(arm, Vector3(0.14, 0.6, 0.16), Vector3(0, -0.3, 0), shirt)
		Build.box(arm, Vector3(0.12, 0.12, 0.14), Vector3(0, -0.64, 0), skin)
		_arms.append(arm)
	scale = Vector3.ONE * float(look.get("scale", 1.0))


func animate(speed: float, delta: float) -> void:
	if _down:
		return
	if speed < 0.1:
		_phase = lerpf(_phase, roundf(_phase / PI) * PI, minf(1.0, delta * 10.0))
	else:
		_phase += delta * speed * 3.2
	var swing := sin(_phase) * clampf(speed / 3.0, 0.0, 1.0) * 0.7
	_legs[0].rotation.x = swing
	_legs[1].rotation.x = -swing
	_arms[0].rotation.x = -swing * 0.8
	_arms[1].rotation.x = swing * 0.8


func set_down(on: bool) -> void:
	_down = on
	rotation.x = -PI * 0.5 if on else 0.0
	position.y = 0.2 if on else 0.0


func is_down() -> bool:
	return _down
