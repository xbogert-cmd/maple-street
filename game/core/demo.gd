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
