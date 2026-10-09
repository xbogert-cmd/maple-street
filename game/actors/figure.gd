class_name Figure
extends Node3D
## A low-poly person made of boxes: shoes, trousers or a skirt, shirt, hands, a face with eyes
## and one of several hair styles. Walks with a swing and a slight bob; can lie down.

var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _body: Node3D
var _phase := 0.0
var _down := false
var _idle := 0.0


func build(look: Dictionary) -> void:
	var skin := Color(look.get("skin", "e8c4a0"))
	var shirt := Color(look.get("shirt", "3b5d8a"))
	var pants := Color(look.get("pants", "3a3f52"))
	var hair := Color(look.get("hair", "2b2118"))
	var man: bool = look.get("man", true)
	var kid: bool = look.get("job", "") == "school"
	var v := int(look.get("id", 0)) * 7 + 3          # stable variety per person
	var dress := not man and not kid and v % 3 != 0
	var short_sleeves := v % 2 == 0 or kid
	_idle = float(v % 10)
	_body = Node3D.new()
	add_child(_body)
	# torso, belt, neck
	Build.box(_body, Vector3(0.5, 0.58, 0.28), Vector3(0, 1.16, 0), shirt)
	if look.get("jacket", false):
		for sx: float in [-1.0, 1.0]:
			Build.box(_body, Vector3(0.2, 0.6, 0.31), Vector3(sx * 0.17, 1.16, 0), shirt.darkened(0.35))
	if dress:
		Build.box(_body, Vector3(0.54, 0.5, 0.36), Vector3(0, 0.66, 0), shirt.darkened(0.08))
	else:
		Build.box(_body, Vector3(0.51, 0.07, 0.29), Vector3(0, 0.87, 0), Color("2a2420"))
	Build.box(_body, Vector3(0.16, 0.08, 0.16), Vector3(0, 1.48, 0), skin)
	# head and face
	Build.box(_body, Vector3(0.3, 0.3, 0.3), Vector3(0, 1.66, 0), skin)
	for sx: float in [-0.075, 0.075]:
		Build.box(_body, Vector3(0.045, 0.045, 0.02), Vector3(sx, 1.69, 0.152), Color("20181a"))
	if man and not kid and v % 4 == 1:
		Build.box(_body, Vector3(0.16, 0.035, 0.02), Vector3(0, 1.6, 0.152), hair)
	if v % 5 == 2 and not kid:
		Build.box(_body, Vector3(0.3, 0.03, 0.02), Vector3(0, 1.695, 0.16), Color("1c1c1e"))
	_hair(hair, man, kid, v, look.get("job", "") == "retired")
	# legs with shoes
	for sx: float in [-0.13, 0.13]:
		var leg := Node3D.new()
		leg.position = Vector3(sx, 0.86, 0)
		_body.add_child(leg)
		if dress:
			Build.box(leg, Vector3(0.14, 0.78, 0.15), Vector3(0, -0.4, 0), skin)
		else:
			Build.box(leg, Vector3(0.2, 0.78, 0.22), Vector3(0, -0.39, 0), pants)
		Build.box(leg, Vector3(0.2, 0.1, 0.3), Vector3(0, -0.81, 0.04), Color("2a2420") if not kid else Color("e6e3d8"))
		_legs.append(leg)
	# arms: sleeve, forearm, hand
	for sx: float in [-0.32, 0.32]:
		var arm := Node3D.new()
		arm.position = Vector3(sx, 1.42, 0)
		_body.add_child(arm)
		Build.box(arm, Vector3(0.15, 0.3 if short_sleeves else 0.58, 0.17), Vector3(0, -0.15 if short_sleeves else -0.29, 0), shirt)
		if short_sleeves:
			Build.box(arm, Vector3(0.12, 0.3, 0.14), Vector3(0, -0.44, 0), skin)
		Build.box(arm, Vector3(0.12, 0.12, 0.14), Vector3(0, -0.64, 0), skin)
		_arms.append(arm)
	scale = Vector3.ONE * float(look.get("scale", 1.0))


func _hair(hair: Color, man: bool, kid: bool, v: int, old: bool) -> void:
	var style := v % 3
	if kid:
		# a baseball cap
		var cap: Color = [Color("c0392b"), Color("2f4a63"), Color("3d5a3a")][v % 3]
		Build.box(_body, Vector3(0.33, 0.12, 0.33), Vector3(0, 1.84, 0), cap)
		Build.box(_body, Vector3(0.26, 0.03, 0.16), Vector3(0, 1.8, 0.22), cap.darkened(0.2))
		Build.box(_body, Vector3(0.32, 0.12, 0.06), Vector3(0, 1.72, -0.14), hair)
	elif man:
		if old and style == 0:
			# bald on top
			for sx: float in [-1.0, 1.0]:
				Build.box(_body, Vector3(0.04, 0.14, 0.26), Vector3(sx * 0.15, 1.7, -0.03), hair)
			Build.box(_body, Vector3(0.3, 0.16, 0.05), Vector3(0, 1.7, -0.15), hair)
		else:
			Build.box(_body, Vector3(0.33, 0.1 + 0.03 * style, 0.33), Vector3(0, 1.84, -0.01), hair)
			Build.box(_body, Vector3(0.33, 0.2, 0.08), Vector3(0, 1.72, -0.14), hair)
			if style == 1:
				Build.box(_body, Vector3(0.12, 0.06, 0.1), Vector3(-0.09, 1.83, 0.14), hair)
	else:
		Build.box(_body, Vector3(0.35, 0.12, 0.35), Vector3(0, 1.85, -0.01), hair)
		match style:
			0:   # bob
				Build.box(_body, Vector3(0.36, 0.3, 0.1), Vector3(0, 1.68, -0.15), hair)
				for sx: float in [-1.0, 1.0]:
					Build.box(_body, Vector3(0.05, 0.26, 0.26), Vector3(sx * 0.17, 1.7, -0.03), hair)
			1:   # long
				Build.box(_body, Vector3(0.36, 0.52, 0.1), Vector3(0, 1.56, -0.16), hair)
				for sx: float in [-1.0, 1.0]:
					Build.box(_body, Vector3(0.05, 0.36, 0.2), Vector3(sx * 0.17, 1.64, -0.06), hair)
			_:   # bun
				Build.box(_body, Vector3(0.34, 0.2, 0.08), Vector3(0, 1.72, -0.15), hair)
				Build.box(_body, Vector3(0.16, 0.16, 0.14), Vector3(0, 1.84, -0.2), hair)


func animate(speed: float, delta: float) -> void:
	if _down:
		return
	_idle += delta
	if speed < 0.1:
		_phase = lerpf(_phase, roundf(_phase / PI) * PI, minf(1.0, delta * 10.0))
		_body.position.y = sin(_idle * 1.6) * 0.006
	else:
		_phase += delta * speed * 3.2
		_body.position.y = absf(sin(_phase)) * 0.035
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
