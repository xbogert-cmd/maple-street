class_name Player
extends CharacterBody3D
## The agent. WASD to move (screen-relative), Shift to run, C to toggle sneaking.

const SNEAK := 1.7
const WALK := 3.3
const RUN := 5.6

var figure: Figure
var sneaking := false
var cam_yaw := PI * 0.25
var frozen := false          # menus, timed actions
var speed_now := 0.0
var carrying: Neighbour       # a body over the shoulder
var noise_radius := 0.0     # how far the current movement can be heard


func _ready() -> void:
	collision_layer = Build.L_PLAYER
	collision_mask = Build.L_WALL | Build.L_LOW | Build.L_DOOR
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.7
	cs.shape = cap
	cs.position.y = 0.85
	add_child(cs)
	figure = Figure.new()
	add_child(figure)
	figure.build({"shirt": "8a8f86", "pants": "33373f", "hair": "3a2a1c", "skin": "e2bd9a", "jacket": true, "id": 4})


func _unhandled_key_input(e: InputEvent) -> void:
	if e.is_pressed() and not e.is_echo() and (e as InputEventKey).physical_keycode == KEY_C:
		sneaking = not sneaking


func _physics_process(delta: float) -> void:
	var dir := Vector3.ZERO
	if not frozen:
		var ix := float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
		var iz := float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
		dir = Vector3(ix, 0, iz).rotated(Vector3.UP, cam_yaw)
	var running := Input.is_physical_key_pressed(KEY_SHIFT) and not sneaking
	var top := SNEAK if sneaking else (RUN if running else WALK)
	if Game.fatigue > 80.0 or Game.hunger > 85.0:
		top *= 0.8
	if carrying:
		top = minf(top, 1.5)
	if dir.length() > 0.1:
		dir = dir.normalized()
		velocity = dir * top
		figure.rotation.y = lerp_angle(figure.rotation.y, atan2(dir.x, dir.z), minf(1.0, delta * 12.0))
	else:
		velocity = Vector3.ZERO
	move_and_slide()
	position.y = 0.0
	speed_now = velocity.length()
	noise_radius = 0.0 if speed_now < 0.1 or sneaking else (11.0 if running else 4.0)
	figure.crouch = sneaking
	if figure.animate(speed_now, delta):
		Sfx.step(absf(position.z) < Street.WALK or position.x < 0.0, -20.0 if sneaking else (-5.0 if running else -11.0))
