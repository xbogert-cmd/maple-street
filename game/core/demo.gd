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
