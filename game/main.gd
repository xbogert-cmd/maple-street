extends Node3D
## Builds the street and runs the game. See docs/superpowers/specs for the design.

const CAM_PITCH := deg_to_rad(-36.0)
const CAM_YAW := PI * 0.25

var street: Street
var player: Player
var cam: Camera3D
var sun: DirectionalLight3D
var env: Environment
var hud: Hud
var interact: Interact
var missions: Missions
var law: Law
var life: Life
var shift: Shift
var neighbours: Array[Neighbour] = []
var zoom := 22.0
var ready_to_play := false
var _inside: House
var _tick := 0.0
var _occupied: Dictionary = {}     # house index -> someone home and awake (last tick)
var _inspect_at: Dictionary = {}   # house index -> clock minutes when they look around


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
	cam.size = zoom
	add_child(cam)
	cam.make_current()
	_people()
	missions = Missions.new()
	law = Law.new()
	life = Life.new()
	shift = Shift.new()
	interact = Interact.new()
	hud = Hud.new()
	for n: Node in [missions, law, life, shift, interact, hud]:
		n.set("main", self)
		add_child(n)
	add_child(Film.new())
	Game.noise.connect(_on_noise)
	Clock.hour_changed.connect(_on_hour)
	if Game.pending_load:
		Game.pending_load = false
		Save.apply(self)
	else:
		life.new_run()
	# the navigation map is built in the background; nobody walks until it is there
	for i in 600:
		await get_tree().physics_frame
		if not street.path(street.home.room_pos("living"), street.bus_stop).is_empty():
			break
	ready_to_play = true
	for n in neighbours:
		n.snap()
	_frame(1.0)
	Demo.start(self)


func _people() -> void:
	for h: Dictionary in street.cast.houses:
		var first := true
		for p: Dictionary in h.people:
			var n := Neighbour.new()
			add_child(n)
			n.setup(p, street.houses[h.lot], street, player)
			if first and p.job != "school":
				n.car = street.cars[h.lot]
			first = false
			n.raised_alarm.connect(func(who: Neighbour) -> void: law.report(who))
			n.saw_everything.connect(func(who: Neighbour) -> void: law.agent_saw(who))
			street.houses[h.lot].residents.append(n)
			neighbours.append(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = Game.run_seed + 99
	for h in street.houses:
		for p in h.portals:
			p.locked = h != street.home and (not p.is_window or rng.randf() > 0.3)


## Light through the day: [hour, sun colour, sun energy, ambient colour, ambient energy].
const SKY: Array = [
	[0.0, "8fa6e8", 0.16, "1b2440", 0.55],
	[5.4, "8fa6e8", 0.16, "1b2440", 0.55],
	[6.4, "ffa97a", 0.55, "6a6f8f", 0.6],
	[8.0, "ffe6c0", 0.95, "a6b2c6", 0.68],
	[13.0, "fff4e2", 1.05, "b4c2d6", 0.7],
	[17.5, "ffd9a0", 0.95, "b0b0c0", 0.66],
	[19.3, "ff8f52", 0.7, "8a7890", 0.58],
	[20.3, "6a6fb0", 0.26, "343c62", 0.55],
	[21.0, "8fa6e8", 0.16, "1b2440", 0.55],
	[24.0, "8fa6e8", 0.16, "1b2440", 0.55],
]


func _lighting() -> void:
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 140.0
	sun.shadow_blur = 1.5
	add_child(sun)
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 1.8
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.08
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _process(delta: float) -> void:
	_frame(delta)
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.5
		_households()
		_fog()
		# footsteps carry on other people's property
		if player.noise_radius > 0.0 and Game.ctx.get("zone", "") in ["inside", "yard"]:
			Game.noise.emit(player.position, player.noise_radius, "steps")
		Game.heat = Rules.heat(suspicions(), Game.incident)


func _frame(delta: float) -> void:
	var day := Clock.daylight()
	var rain: float = life.rain if life else 0.0
	var hour := Clock.hour()
	var key := 0
	while hour >= float(SKY[key + 1][0]):
		key += 1
	var f := (hour - float(SKY[key][0])) / (float(SKY[key + 1][0]) - float(SKY[key][0]))
	var a: Array = SKY[key]
	var b: Array = SKY[key + 1]
	# sun swings east to west, low at each end of the day; at night it becomes a dim moon
	var t := clampf((hour - 5.5) / 15.0, 0.0, 1.0)
	sun.rotation = Vector3(deg_to_rad(-14.0 - 50.0 * sin(t * PI)), deg_to_rad(lerpf(110.0, -70.0, t)), 0)
	if day <= 0.0:
		sun.rotation = Vector3(deg_to_rad(-55.0), deg_to_rad(30.0), 0)
	sun.light_energy = lerpf(a[2], b[2], f) * (1.0 - rain * 0.45) + (life.flash if life else 0.0)
	sun.light_color = Color(String(a[1])).lerp(Color(String(b[1])), f)
	env.ambient_light_color = Color(String(a[3])).lerp(Color(String(b[3])), f).lerp(Color("707a86"), rain * 0.5 * day)
	env.ambient_light_energy = lerpf(a[4], b[4], f)
	env.background_color = Color("05070d").lerp(Color("5f7f9a"), day).lerp(Color("4a5560"), rain * day)
	street.set_night(1.0 - day)
	# camera follows the player
	zoom = clampf(zoom, 10.0, 60.0)
	cam.size = lerpf(cam.size, zoom, minf(1.0, delta * 8.0))
	var target := player.position + Vector3.UP * 1.0
	cam.position = cam.position.lerp(target + cam.basis.z * 150.0, minf(1.0, delta * 6.0))
	player.cam_yaw = CAM_YAW
	# roof off the house the player is in, and off any house standing between them and the camera
	var h := street.house_at(player.position)
	var toward_cam := Vector3(cam.basis.z.x, 0, cam.basis.z.z).normalized()
	var all: Array[House] = street.houses + ([street.plant] as Array[House])
	for house in all:
		var cut: bool = house == h or house == street.plant
		if not cut and absf(house.global_position.x - player.position.x) < 40.0:
			for k in range(1, 8):
				if house.footprint(player.position + toward_cam * float(k), 0.6):
					cut = true
					break
		house.set_cutaway(cut)
	_inside = h
	# tree tops that would cover the player are hidden; the trunk stays
	for crown in street.crowns:
		var to := crown.position - player.position
		to.y = 0.0
		var along := clampf(to.dot(toward_cam), 0.0, 14.0)
		crown.visible = (to - toward_cam * along).length() > 2.6
	_context(h, day)
	Sfx.listener = player.position
	Sfx.ambience(rain, (1.0 - day) if Clock.running else 0.0, h != null or shift.active)


## Work out what the player is up to, for anyone watching (Rules.judge reads this).
func _context(h: House, day: float) -> void:
	var p := player.position
	var lot := street.lot_at(p)
	var zone := "street"
	var family := ""
	if h:
		zone = "home" if h == street.home else "inside"
		family = h.family
	elif lot >= 0:
		family = street.houses[lot].family
		if lot == street.cast.home:
			zone = "home"
		else:
			zone = "front" if absf(p.z) < Street.FRONT + 0.5 else "yard"
	elif street.in_park(p):
		zone = "park"
	elif p.x < 0.0:
		zone = "west"
	var light := day
	if day < 1.0:
		var lit := 0.12
		for l in street.lamp_spots():
			lit = maxf(lit, 0.95 - l.distance_to(p) / 13.0)
		if h and (h.lit or h == street.home):
			lit = maxf(lit, 0.8)
		light = maxf(day, lit)
	if life and life.rain > 0.5:
		light *= 0.8
	Game.ctx = {
		"zone": zone, "lot": lot, "family": family, "night": day < 0.3, "hour": Clock.hour(), "light": light,
		"act": "carry_body" if player.carrying else interact.act, "what": interact.what,
		"invited": life.event_lot == lot and lot >= 0 and zone != "inside" if life else false,
	}


## People indoors are only drawn if the player is in that house or has a line of sight to them.
func _fog() -> void:
	var eye := player.global_position + Vector3.UP * 1.5
	var space := get_world_3d().direct_space_state
	for n in neighbours:
		if not n.visible:
			continue
		var house := street.house_at(n.global_position)
		var shown := house == null or house == _inside or n.carried
		if not shown and n.global_position.distance_to(player.global_position) < 20.0:
			var q := PhysicsRayQueryParameters3D.create(eye, n.global_position + Vector3.UP * 1.2, Build.L_WALL | Build.L_DOOR)
			shown = space.intersect_ray(q).is_empty()
		n.figure.visible = shown
		n.bubble_on = shown


func suspicions() -> Array[float]:
	var out: Array[float] = []
	for n in neighbours:
		if n.state != "dead":
			out.append(n.suspicion * (0.4 if n.d.job == "school" else 1.0))
	return out


## Lights, locks and coming-home inspections for every house.
func _households() -> void:
	var dark := Clock.daylight() < 0.45
	for h in street.houses:
		if h == street.home:
			h.set_lit(dark and street.house_at(player.position) == h)
			continue
		var awake := false
		var near_door := false
		for r: Neighbour in h.residents:
			if r.is_awake() and r.state != "leaving" and h.contains(r.global_position):
				awake = true
			if r.visible and not r.is_out_cold():
				for p in h.portals:
					if not p.is_window and p.global_position.distance_to(r.global_position) < 1.3:
						near_door = true
		h.set_lit(awake and dark)
		for p in h.portals:
			if not p.is_window and not p.open:
				p.leaf.rotation.y = -PI * 0.5 if near_door and p.global_position.distance_to(_nearest_resident(h, p.global_position)) < 1.3 else 0.0
		var was: bool = _occupied.get(h.index, true)
		if awake and not was:
			_inspect_at[h.index] = Clock.minutes + 12.0
			h.portal("front").locked = false
		elif not awake and was:
			# last one out (or to bed) locks up
			for p in h.portals:
				if not p.is_window and street.house_at(player.position) != h and life.event_lot != h.index:
					p.set_open(false)
					p.locked = true
		_occupied[h.index] = awake
		if awake and _inspect_at.get(h.index, 1e12) <= Clock.minutes:
			_inspect_at[h.index] = Clock.minutes + 90.0
			law.inspect(h)


func _nearest_resident(h: House, at: Vector3) -> Vector3:
	var best := Vector3(1e6, 0, 1e6)
	for r: Neighbour in h.residents:
		if r.visible and r.global_position.distance_to(at) < best.distance_to(at):
			best = r.global_position
	return best


func _on_noise(pos: Vector3, radius: float, kind: String) -> void:
	var r := radius * (0.6 if life.rain > 0.5 else 1.0)
	for n in neighbours:
		if n.visible and n.global_position.distance_to(pos) <= r:
			n.hear(pos, kind)
	life.heard(pos, r, kind)


func _on_hour(hour: int) -> void:
	if hour == 4:
		life.new_day()
	if (hour == 7 or hour == 17) and not Clock.is_weekend():
		Sfx.play("whistle", null, -14.0)   # the plant whistle: shifts start and end


## Jump the clock forward (sleep, work) and put everyone where they should be.
func skip(mins: float) -> void:
	Clock.advance(mins)
	for n in neighbours:
		n.snap()
	_occupied.clear()


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
