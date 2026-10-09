class_name Figure
extends Node3D
## A low-poly person: rounded head, tapered torso and jointed limbs (knees and elbows), with a
## face and one of several hair styles. Walks, crouches, works with its hands, strikes, kneels,
## carries someone across the shoulders, falls over and can be carried.

const POSE_SPEED := 14.0

var action := ""         # "work", "strike", "smother" or "carry"; set by whoever drives the figure
var progress := 0.0      # 0..1 through a timed action
var crouch := false
var _legs: Array[Node3D] = []
var _shins: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _fore: Array[Node3D] = []
var _body: Node3D
var _head: Node3D
var _phase := 0.0
var _down := false
var _idle := 0.0
var _tw: Tween


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
	var jacket: bool = look.get("jacket", false)
	var top := shirt.darkened(0.35) if jacket else shirt
	_idle = float(v % 10)
	_body = Node3D.new()
	add_child(_body)
	# torso (an oval tube, wider at the shoulders), belt or skirt
	Build.cyl(_body, 0.21, 0.58, Vector3(0, 1.16, 0), top, 0.25, 10).scale.z = 0.62
	if jacket:
		Build.box(_body, Vector3(0.11, 0.5, 0.03), Vector3(0, 1.18, 0.15), shirt)
	if dress:
		Build.cyl(_body, 0.3, 0.52, Vector3(0, 0.66, 0), shirt.darkened(0.08), 0.21, 10).scale.z = 0.7
	else:
		Build.cyl(_body, 0.215, 0.08, Vector3(0, 0.87, 0), Color("2a2420"), -1.0, 10).scale.z = 0.64
		Build.cyl(_body, 0.2, 0.14, Vector3(0, 0.8, 0), pants, 0.21, 10).scale.z = 0.64
	# head: neck, skull, face, hair
	_head = Node3D.new()
	_head.position = Vector3(0, 1.5, 0)
	_body.add_child(_head)
	Build.cyl(_head, 0.07, 0.12, Vector3(0, -0.02, 0), skin)
	Build.ball(_head, 0.16, 0.36, Vector3(0, 0.18, 0), skin)
	for sx: float in [-0.06, 0.06]:
		Build.box(_head, Vector3(0.04, 0.045, 0.02), Vector3(sx, 0.21, 0.142), Color("20181a"))
	Build.box(_head, Vector3(0.035, 0.05, 0.03), Vector3(0, 0.16, 0.155), skin.darkened(0.08))
	if man and not kid and v % 4 == 1:
		Build.box(_head, Vector3(0.13, 0.03, 0.02), Vector3(0, 0.115, 0.148), hair)
	if v % 5 == 2 and not kid:
		Build.box(_head, Vector3(0.26, 0.025, 0.02), Vector3(0, 0.215, 0.155), Color("1c1c1e"))
	_hair(hair, man, kid, v, look.get("job", "") == "retired")
	# legs: thigh, knee, shin, shoe
	for sx: float in [-0.11, 0.11]:
		var r := 0.058 if dress else 0.085
		var hip := _joint(_body, Vector3(sx, 0.86, 0))
		Build.cyl(hip, r * 0.9, 0.42, Vector3(0, -0.2, 0), skin if dress else pants, r * 1.1)
		var knee := _joint(hip, Vector3(0, -0.4, 0))
		Build.cyl(knee, r * 0.72, 0.4, Vector3(0, -0.2, 0), skin if dress else pants, r * 0.9)
		Build.box(knee, Vector3(0.14, 0.09, 0.27), Vector3(0, -0.415, 0.05), Color("e6e3d8") if kid else Color("2a2420"))
		_legs.append(hip)
		_shins.append(knee)
	# arms: shoulder, upper arm, elbow, forearm, hand
	for sx: float in [-0.29, 0.29]:
		var shoulder := _joint(_body, Vector3(sx, 1.4, 0))
		Build.ball(shoulder, 0.085, 0.17, Vector3.ZERO, top)
		Build.cyl(shoulder, 0.058, 0.3, Vector3(0, -0.15, 0), top, 0.07)
		var elbow := _joint(shoulder, Vector3(0, -0.3, 0))
		Build.cyl(elbow, 0.048, 0.28, Vector3(0, -0.14, 0), skin if short_sleeves else top, 0.058)
		Build.ball(elbow, 0.06, 0.13, Vector3(0, -0.32, 0), skin)
		_arms.append(shoulder)
		_fore.append(elbow)
	scale = Vector3.ONE * float(look.get("scale", 1.0))


func _joint(parent: Node3D, at: Vector3) -> Node3D:
	var j := Node3D.new()
	j.position = at
	parent.add_child(j)
	return j


func _hair(hair: Color, man: bool, kid: bool, v: int, old: bool) -> void:
	var style := v % 3
	var back := Vector3(0, 0.17, -0.04)
	if kid:
		# a baseball cap
		var cap: Color = [Color("c0392b"), Color("2f4a63"), Color("3d5a3a")][v % 3]
		Build.ball(_head, 0.172, 0.17, Vector3(0, 0.22, 0), cap, true)
		Build.box(_head, Vector3(0.22, 0.025, 0.16), Vector3(0, 0.235, 0.2), cap.darkened(0.2))
		Build.ball(_head, 0.158, 0.24, back + Vector3(0, -0.03, 0), hair)
	elif man:
		Build.ball(_head, 0.158, 0.26, back + (Vector3(0, -0.04, 0) if old and style == 0 else Vector3.ZERO), hair)
		if not (old and style == 0):   # otherwise bald on top
			Build.ball(_head, 0.168, 0.15 + 0.02 * style, Vector3(0, 0.22, -0.012), hair, true)
			if style == 1:
				Build.ball(_head, 0.07, 0.1, Vector3(-0.05, 0.32, 0.1), hair)
	else:
		Build.ball(_head, 0.17, 0.16, Vector3(0, 0.22, -0.012), hair, true)
		match style:
			0:   # bob
				Build.ball(_head, 0.185, 0.36, Vector3(0, 0.14, -0.055), hair)
			1:   # long
				Build.ball(_head, 0.18, 0.34, Vector3(0, 0.15, -0.055), hair)
				Build.cyl(_head, 0.15, 0.34, Vector3(0, -0.06, -0.09), hair, 0.13).scale.z = 0.5
			_:   # bun
				Build.ball(_head, 0.16, 0.28, back, hair)
				Build.ball(_head, 0.075, 0.14, Vector3(0, 0.3, -0.16), hair)


## Call every frame with the walking speed. Returns true on the frame a foot lands.
func animate(speed: float, delta: float) -> bool:
	if _down:
		return false
	_idle += delta
	var step := false
	if speed < 0.1:
		_phase = lerpf(_phase, roundf(_phase / PI) * PI, minf(1.0, delta * 10.0))
	else:
		var before := _phase
		_phase += delta * speed * 2.7
		step = floorf(_phase / PI - 0.5) != floorf(before / PI - 0.5)
	var amt := clampf(speed / 3.0, 0.0, 1.25)
	var s := sin(_phase)
	var c := cos(_phase)
	# targets: [left, right]
	var leg: Array[float] = [s * 0.6 * amt, -s * 0.6 * amt]
	var knee: Array[float] = [maxf(0.0, -c) * 1.0 * amt, maxf(0.0, c) * 1.0 * amt]
	var arm: Array[float] = [-s * 0.5 * amt, s * 0.5 * amt]
	var fore: Array[float] = [-0.12 - 0.4 * amt, -0.12 - 0.4 * amt]
	var lean := 0.14 * clampf((speed - 3.6) / 2.0, 0.0, 1.0)
	var drop := sin(_idle * 1.6) * 0.006 if speed < 0.1 else (1.0 - absf(s)) * 0.04 * amt
	var nod := 0.0
	if crouch:
		leg = [leg[0] * 0.6 - 0.55, leg[1] * 0.6 - 0.55]
		knee = [knee[0] * 0.5 + 1.05, knee[1] * 0.5 + 1.05]
		lean = 0.38
		drop -= 0.11
		nod = -0.3
	match action:
		"work":      # hands busy in front: locks, drawers, a mop
			var j := sin(_idle * 11.0) * 0.1
			arm = [-0.95 + j, -1.05 - j]
			fore = [-0.75, -0.65]
			lean = maxf(lean, 0.14)
			nod = 0.2
		"carry":     # right arm hooked round the legs of someone folded over that shoulder
			arm[1] = -1.25
			fore[1] = -1.7
			lean = 0.16
			nod = 0.15
		"strike":    # wind up with the right arm, then bring it down
			var hit := progress > 0.72
			arm = [-0.9, -0.5 if hit else -3.0]
			fore = [-0.5, -0.2 if hit else -0.9]
			lean = 0.32 if hit else -0.12
		"smother":   # on both knees, pressing down
			var rock := sin(_idle * 5.0) * 0.05
			leg = [0.0, 0.0]
			knee = [PI * 0.5, PI * 0.5]
			arm = [-0.85 + rock, -0.85 + rock]
			fore = [-0.25, -0.25]
			lean = 0.5 + rock
			drop = -0.42
			nod = 0.3
	var k := minf(1.0, delta * POSE_SPEED)
	for i in 2:
		_legs[i].rotation.x = lerpf(_legs[i].rotation.x, leg[i], k)
		_shins[i].rotation.x = lerpf(_shins[i].rotation.x, knee[i], k)
		_arms[i].rotation.x = lerpf(_arms[i].rotation.x, arm[i], k)
		_fore[i].rotation.x = lerpf(_fore[i].rotation.x, fore[i], k)
	_body.rotation.x = lerpf(_body.rotation.x, lean, k)
	_body.position.y = lerpf(_body.position.y, drop, k)
	_head.rotation.x = lerpf(_head.rotation.x, nod, k)
	return step


func _limp(leg: float, arm: float) -> void:
	for i in 2:
		_legs[i].rotation.x = leg
		_shins[i].rotation.x = 0.0
		_arms[i].rotation.x = arm
		_fore[i].rotation.x = 0.0
	_body.rotation.x = 0.0
	_body.position.y = 0.0
	_head.rotation.x = 0.0


## Lie on the back (asleep, unconscious, dead). `fall` topples over instead of snapping flat.
func set_down(on: bool, fall := false) -> void:
	_down = on
	if _tw:
		_tw.kill()
	_limp(0.0, 0.25 if on else 0.0)
	var turn := -PI * 0.5 if on else 0.0
	var lift := 0.2 if on else 0.0
	if fall and is_inside_tree():
		_tw = create_tween().set_parallel().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		_tw.tween_property(self, "rotation:x", turn, 0.4)
		_tw.tween_property(self, "position:y", lift, 0.4)
	else:
		rotation.x = turn
		position.y = lift


const SLUNG_BACK := 0.55    # how far the hanging torso leans away from straight down

## Folded at the waist over someone's shoulder: torso head-down behind, legs down the front.
## The carrier turns this figure to face backwards. Off returns to lying on the ground.
func set_slung(on: bool) -> void:
	if not on:
		set_down(true)
		return
	if _tw:
		_tw.kill()
	rotation.x = PI - SLUNG_BACK
	position.y = 0.0
	_limp(-2.05, -2.9)
	_shins[0].rotation.x = 0.0
	_shins[1].rotation.x = 0.12
	_arms[1].rotation.x = -2.7


func is_down() -> bool:
	return _down
