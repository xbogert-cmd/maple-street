extends Node3D
## Builds the street and runs the game. See docs/superpowers/specs for the design.

const CAM_PITCH := deg_to_rad(-36.0)
const CAM_YAW := PI * 0.25

var street: Street
var player: Player
var cam: Camera3D
var sun: DirectionalLight3D
var env: Environment
var zoom := 22.0
var _inside: House


func _ready() -> void:
	if Game.run_seed == 0:
		Game.run_seed = int(Game.args.get("seed", str(randi() % 100000 + 1)))
	street = Street.new()
	add_child(street)
	street.build(Cast.generate(Game.run_seed))
	street.bake_nav()
	_lighting()
	player = Player.new()
	add_child(player)
	player.position = street.home.room_pos("living")
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.rotation = Vector3(CAM_PITCH, CAM_YAW, 0)
	cam.far = 400.0
	add_child(cam)
	cam.make_current()
	_dev_args()
	_frame(1.0)


func _lighting() -> void:
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _process(delta: float) -> void:
	_frame(delta)


func _frame(delta: float) -> void:
	var day := Clock.daylight()
	# sun swings east to west through the day; at night it becomes a dim moon
	var t := clampf((Clock.hour() - 5.5) / 15.0, 0.0, 1.0)
	sun.rotation = Vector3(deg_to_rad(-25.0 - 40.0 * sin(t * PI)), deg_to_rad(lerpf(110.0, -70.0, t)), 0)
	if day <= 0.0:
		sun.rotation = Vector3(deg_to_rad(-55.0), deg_to_rad(30.0), 0)
	sun.light_energy = lerpf(0.12, 1.25, day)
	sun.light_color = Color("9db4ff").lerp(Color("ffe0b0").lerp(Color("fff6e6"), day), day)
	env.ambient_light_color = Color("26304f").lerp(Color("c9d6e8"), day)
	env.ambient_light_energy = lerpf(0.55, 0.9, day)
	env.background_color = Color("06080f").lerp(Color("5f7f9a"), day)
	street.set_night(1.0 - day)
	# camera follows the player
	zoom = clampf(zoom, 10.0, 60.0)
	cam.size = lerpf(cam.size, zoom, minf(1.0, delta * 8.0))
	var target := player.position + Vector3.UP * 1.0
	cam.position = cam.position.lerp(target + cam.basis.z * 150.0, minf(1.0, delta * 6.0))
	player.cam_yaw = CAM_YAW
	# roof off the house the player is in
	var h := street.house_at(player.position)
	if h != _inside:
		if _inside:
			_inside.set_cutaway(false)
		if h:
			h.set_cutaway(true)
		_inside = h


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMagnifyGesture:
		zoom /= (e as InputEventMagnifyGesture).factor
	elif e is InputEventMouseButton and e.is_pressed():
		var b := (e as InputEventMouseButton).button_index
		if b == MOUSE_BUTTON_WHEEL_UP:
			zoom -= 1.5
		elif b == MOUSE_BUTTON_WHEEL_DOWN:
			zoom += 1.5
	elif e is InputEventKey and e.is_pressed():
		var k := (e as InputEventKey).physical_keycode
		if k == KEY_EQUAL:
			zoom -= 3.0
		elif k == KEY_MINUS:
			zoom += 3.0


## Developer switches: -- --hour=22 --at=x,z --zoom=40 --shot=/path.png
func _dev_args() -> void:
	var a := Game.args
	if a.has("hour"):
		Clock.minutes = float(a.hour) * 60.0
	if a.has("at"):
		var p: PackedStringArray = a.at.split(",")
		player.position = Vector3(float(p[0]), 0, float(p[1]))
	if a.has("zoom"):
		zoom = float(a.zoom)
		cam.size = zoom
	if a.has("shot"):
		Clock.running = false
		await get_tree().create_timer(float(a.get("wait", "1.0"))).timeout
		get_viewport().get_texture().get_image().save_png(a.shot)
		print("SHOT ", a.shot)
		get_tree().quit()
