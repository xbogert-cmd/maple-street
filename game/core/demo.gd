class_name Demo
extends Node
## Developer runs: -- --hour=22 --at=x,z --zoom=40 --shot=/path.png, or --demo=<name> --shots=<dir>
## for a scripted sequence of screenshots.

var main: Node
var dir := ""


static func start(m: Node) -> void:
	var a := Game.args
	if a.has("hour"):
		Clock.minutes = float(a.hour) * 60.0
		m.skip(0.0)
	if a.has("at"):
		var p: PackedStringArray = String(a.at).split(",")
		m.player.position = Vector3(float(p[0]), 0, float(p[1]))
	if a.has("zoom"):
		m.zoom = float(a.zoom)
		m.cam.size = m.zoom
	if not a.has("shot") and not a.has("demo"):
		return
	var d := Demo.new()
	d.main = m
	d.dir = a.get("shots", "")
	m.add_child(d)
	if a.has("demo"):
		d.call(String(a.demo))
	else:
		d.single(a.shot, float(a.get("wait", "1.0")))


func single(path: String, wait: float) -> void:
	Clock.running = false
	await get_tree().create_timer(wait).timeout
	_save(path)
	get_tree().quit()


func shot(name: String, wait := 0.6) -> void:
	await get_tree().create_timer(wait).timeout
	_save("%s/%s.png" % [dir, name])


func _save(path: String) -> void:
	get_viewport().get_texture().get_image().save_png(path)
	print("SHOT ", path)


func at(hour: float, pos: Vector3, zoom: float) -> void:
	Clock.minutes = floorf(Clock.minutes / 1440.0) * 1440.0 + hour * 60.0
	main.skip(0.0)
	main.player.global_position = pos
	main.zoom = zoom
	main.cam.size = zoom
	main.cam.position = pos + main.cam.basis.z * 150.0


## A tour of the street for judging the look.
func look() -> void:
	Clock.running = false
	var home: House = main.street.home
	await at(14.0, home.room_pos("living"), 16.0)
	await shot("1_home_inside")
	await at(8.0, home.portal("front").outside_pos + Vector3(0, 0, 4.0 * -Street.lot_side(home.index)), 30.0)
	await shot("2_morning_street")
	await at(21.5, Vector3(60, 0, 0), 50.0)
	await shot("3_night_wide", 1.0)
	await at(23.0, Vector3(Street.lot_x(home.index) + 30.0, 0, 5.0), 22.0)
	await shot("4_night_close", 1.0)
	await at(13.0, main.street.park_center, 40.0)
	await shot("5_park")
	await at(11.0, main.street.shop_door + Vector3(4, 0, 6), 30.0)
	await shot("6_west_end")
	get_tree().quit()


## Run the prompt whose label starts with `label` and wait for it to finish.
func press(label: String) -> bool:
	await get_tree().process_frame
	await get_tree().process_frame
	for o: Dictionary in main.interact.options:
		if String(o.label).begins_with(label):
			main.interact.run(o)
			while not main.interact.busy.is_empty():
				await get_tree().process_frame
			return true
	print("DEMO no prompt '%s' in %s" % [label, main.interact.options.map(func(o: Dictionary) -> String: return o.label)])
	return false


func go(pos: Vector3) -> void:
	main.player.global_position = pos
	main.cam.position = pos + main.cam.basis.z * 150.0
	await get_tree().process_frame


## The interface: radio, containers, notebook, a door at night, the shop.
func ui() -> void:
	var home: House = main.street.home
	await at(20.0, home.find_furn("radio").pos + Vector3(0, 0, 1.0), 14.0)
	Clock.running = true
	await press("Take the radio")
	await press("Listen")
	await shot("1_radio")
	main.hud.close()
	await go(home.find_furn("stash").pos + Vector3(0.9, 0, 0))
	await press("Search")
	await shot("2_stash")
	for id: String in ["lockpicks", "minicam"]:
		main.hud._take(home.find_furn("stash"), home.find_furn("stash").items[0])
	main.hud.close()
	var m := Game.mission
	var target: House = main.street.houses[m.lot]
	await at(1.0, target.portal("back").outside_pos, 16.0)
	Clock.running = true
	await shot("3_back_door")
	await press("Pick")
	await press("Open")
	await go(target.find_furn(m.spot).pos + Vector3(0.9, 0, 0.9))
	await shot("4_inside_target", 1.0)
	await press("Search")
	await shot("5_desk")
	main.hud.close()
	main.hud.open_notebook()
	await shot("6_notebook")
	main.hud.close()
	await at(11.0, main.street.shop_door, 20.0)
	await press("Go into")
	await shot("7_shop")
	main.hud.close()
	main.hud.open_pause()
	await shot("8_pause")
	get_tree().quit()


func key(code: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = down
	Input.parse_input_event(e)


## Walk about with real key presses: out of the front door and down the path.
func walk() -> void:
	var home: House = main.street.home
	var front := home.portal("front")
	await at(9.0, front.inside_pos, 18.0)
	Clock.running = true
	var start: Vector3 = main.player.global_position
	await press("Open")
	var out := (front.outside_pos - front.inside_pos).normalized()
	# screen-relative keys: W is up-left on the ground (-x, -z), S the opposite
	var keys: Array[Key] = [KEY_S, KEY_D]
	if out.z < 0.0:
		keys = [KEY_W, KEY_A]
	for k in keys:
		key(k, true)
	await get_tree().create_timer(1.5).timeout
	for k in keys:
		key(k, false)
	await shot("1_walked_out")
	print("DEMO moved ", start, " -> ", main.player.global_position, " zone ", Game.ctx.zone)
	key(KEY_SHIFT, true)
	key(KEY_A, true)
	await get_tree().create_timer(2.0).timeout
	key(KEY_A, false)
	key(KEY_SHIFT, false)
	print("DEMO ran to ", main.player.global_position, " zone ", Game.ctx.zone)
	await shot("2_ran")
	get_tree().quit()


## The livelier scenes: the plant shift, a barbecue, a dog, rain, behind a house, the police.
func scenes() -> void:
	Clock.running = true
	await at(7.5, main.street.bus_stop, 20.0)
	Game.worked_today = false
	await press("Ride")
	await shot("1_plant", 1.5)
	main.shift.finish()
	Clock.minutes = 5.0 * 1440.0 + 4.0 * 60.0
	main.life.new_day()
	var host: House = main.street.houses[main.life.event_host]
	await at(13.0, Vector3(Street.lot_x(host.index) + 10.0, 0, Street.lot_side(host.index) * 27.0), 22.0)
	await shot("2_barbecue", 1.0)
	var dog: Dog = main.life.dogs[0]
	main.life.rain_from = 0.0
	main.life.rain_to = 24.0
	main.life.rain = 1.0
	await at(22.0, dog.global_position + Vector3(4, 0, 0), 18.0)
	await shot("3_dog_rain_night", 1.5)
	main.life.rain_from = -1.0
	main.life.rain = 0.0
	var north: House = main.street.houses[2]
	await at(15.0, north.portal("back").outside_pos if north.portal("back") else north.global_position, 16.0)
	await shot("4_behind_house", 0.8)
	main.law.blown = true
	main.law._send_officers()
	await at(16.0, Vector3(-18, 0, 3), 24.0)
	await shot("5_police", 1.0)
	get_tree().quit()


## The title menu, then the first-night briefing.
func title() -> void:
	if not Game.started:
		await shot("1_title", 1.0)
		main.hud._restart(false)
	else:
		await shot("2_intro", 1.5)
		get_tree().quit()


## Let a week run at speed with nobody at the controls, printing a line a day. Finds script
## errors in the daily turnover, the investigator and the search.
func soak() -> void:
	Engine.time_scale = float(Game.args.get("speed", "25"))
	Clock.running = true
	var frames := 0
	var t0 := Time.get_ticks_msec()
	var last_day := 0
	while Clock.day() <= int(Game.args.get("days", "8")) and Game.ended == "":
		await get_tree().process_frame
		frames += 1
		if Clock.day() != last_day:
			last_day = Clock.day()
			var states: Dictionary = {}
			for n: Neighbour in main.neighbours:
				states[n.state] = int(states.get(n.state, 0)) + 1
			print("DAY %d %s heat %.0f incident %.0f investigating %s  %s" % [last_day, Clock.stamp(), Game.heat, Game.incident, main.law.investigating, states])
			if last_day == 3:
				Game.incident = 50.0    # stir things up: bring the Bureau in
			if last_day == 5:
				Game.incident = 90.0    # and then a search
	print("SOAK end: %s %s  journal %d lines, %d frames in %d ms" % [Game.ended, Game.end_reason, Game.journal.size(), frames, Time.get_ticks_msec() - t0])
	for j in Game.journal:
		print("  ", j)
	get_tree().quit()


## Frame cost with a window open: -- --demo=fps
func fps() -> void:
	Clock.running = true
	for setup: Array in [["day street", 14.0, Vector3(60, 0, 0), 30.0], ["night street", 22.0, Vector3(60, 0, 0), 30.0], ["night wide", 22.0, Vector3(60, 0, 0), 60.0], ["indoors", 20.0, main.street.home.room_pos("living"), 16.0]]:
		await at(setup[1], setup[2], setup[3])
		await get_tree().create_timer(1.0).timeout
		var n := 0
		var t0 := Time.get_ticks_usec()
		var proc := 0.0
		while Time.get_ticks_usec() - t0 < 3000000:
			await get_tree().process_frame
			n += 1
			proc += Performance.get_monitor(Performance.TIME_PROCESS)
		print("DEMO fps %s: %.0f fps, script+engine process %.2f ms" % [setup[0], n / 3.0, proc / n * 1000.0])
	get_tree().quit()


## One interior of each floor plan, to check doorways and furniture by eye.
func plans() -> void:
	Clock.running = false
	var seen: Dictionary = {}
	for h: House in main.street.houses:
		var key: int = h.tpl.w
		if seen.has(key):
			continue
		seen[key] = true
		await at(13.0, h.to_global(Vector3(h.tpl.w * 0.5, 0, h.tpl.d * 0.5)), 13.0)
		await shot("plan_%d" % key, 0.8)
	get_tree().quit()


## People up close, doorways in the cutaway, and the takedown, kill and carry poses: --demo=acts
func acts() -> void:
	var home: House = main.street.home
	await at(14.0, home.room_pos("hall"), 9.0)
	main.player.figure.rotation.y = PI * 0.25
	await shot("1_doorways")
	var spot := Vector3(60, 0, 0)
	await at(10.0, spot, 6.5)
	Clock.running = false
	main.player.figure.rotation.y = PI * 0.25
	var shown: Array[Neighbour] = []
	for n: Neighbour in main.neighbours:
		if shown.size() < 6:
			n.stop()
			n.visible = true
			n.state = "event"
			n.global_position = spot + Vector3(-3.6 + shown.size() * 1.2, 0, 3.6 - shown.size() * 1.2) + Vector3(-1.2, 0, -1.2)
			n.figure.rotation.y = PI * 0.25
			shown.append(n)
	await shot("2_people")
	var victim := shown[2]
	for n in shown:
		if n != victim:
			n.visible = false
	await go(spot)
	victim.global_position = spot + Vector3(0.9, 0, -0.5)
	main.player.sneaking = true
	await _begin("Knock")
	await shot("3_strike_windup", 0.35)
	await shot("4_strike_lands", 0.6)
	main.player.sneaking = false
	await _begin("Kill")
	await shot("5_kill", 1.5)
	while not main.interact.busy.is_empty():
		await get_tree().process_frame
	await press("Carry")
	await shot("6_carry", 0.5)
	main.player.figure.rotation.y = -PI * 0.25
	await shot("7_carry_side", 0.3)
	main.player.sneaking = true
	await press("Put")
	await shot("8_sneak", 0.5)
	get_tree().quit()


func _begin(label: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	for o: Dictionary in main.interact.options:
		if String(o.label).begins_with(label):
			main.interact.run(o)
			return
	print("DEMO no prompt '%s'" % label)
