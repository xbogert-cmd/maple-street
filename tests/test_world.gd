extends RefCounted
## Whole-game checks: builds the real street once and drives it through the main systems.

var t: Node
var main: Node


func _world() -> Node:
	if main == null:
		Game.started = true
		Game.run_seed = 7
		main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
		t.add_child(main)
		while not main.ready_to_play:
			await t.get_tree().physics_frame
	return main


## Undo an arrest from an earlier test so the next one starts from a live game.
func _calm() -> void:
	Game.ended = ""
	Clock.running = true
	main.law.blown = false
	main.law.arrive_at = -1.0
	for o: Walker in main.law.officers:
		o.queue_free()
	main.law.officers.clear()
	main.hud.close()
	Clock.running = true
	for n: Neighbour in main.neighbours:
		if n.state == "alarm":
			n.state = "home"
		n.recognised = false


func _wait(sec: float) -> void:
	await t.get_tree().create_timer(sec).timeout


func _at_hour(h: float) -> void:
	main.skip(Clock.until(h))
	for i in 3:
		await t.get_tree().physics_frame


func test_1_street_and_routines() -> void:
	await _world()
	t.check(main.street.houses.size() == 12, "twelve houses")
	t.check(main.neighbours.size() >= 14, "a street's worth of neighbours, got %d" % main.neighbours.size())
	t.check(not main.street.path(main.street.home.room_pos("living"), main.street.park_center).is_empty(), "a walking route from home to the park")
	Clock.minutes = 1440.0 + 12.0 * 60.0   # Tuesday noon
	main.skip(0.0)
	var away := 0
	for n: Neighbour in main.neighbours:
		away += int(n.is_away())
		if n.d.job == "plant":
			t.check(n.is_away(), "%s should be at the plant at noon" % n.full_name())
	t.check(away >= 6, "most workers are out at noon, got %d" % away)
	await _at_hour(3.0)
	for n: Neighbour in main.neighbours:
		if not n.d.agent:
			t.check(n.state == "sleep", "%s should be asleep at 3 AM, is %s" % [n.full_name(), n.state])


func test_2_walking_out_and_back() -> void:
	await _world()
	var who: Neighbour
	for n: Neighbour in main.neighbours:
		if n.d.job == "plant":
			who = n
			break
	Clock.minutes = 2.0 * 1440.0 + (who.leave_at - 0.1) * 60.0
	main.skip(0.0)
	who.roll_day()
	Clock.minutes = 2.0 * 1440.0 + (who.leave_at - 0.1) * 60.0
	main.skip(0.0)
	t.check(who.state == "home", "home just before leaving, is %s" % who.state)
	Engine.time_scale = 10.0
	await _wait(40.0)
	Engine.time_scale = 1.0
	t.check(who.is_away(), "%s walked to the car and left, is %s" % [who.full_name(), who.state])
	Clock.minutes = 2.0 * 1440.0 + who.back_at * 60.0 + 1.0
	Engine.time_scale = 10.0
	await _wait(40.0)
	Engine.time_scale = 1.0
	t.check(who.state == "home" and who.house.contains(who.global_position), "%s came home and went indoors, is %s" % [who.full_name(), who.state])


func test_3_photo_job_end_to_end() -> void:
	await _world()
	Clock.minutes = 3.0 * 1440.0 + 12.0 * 60.0
	main.skip(0.0)
	var m: Dictionary = main.missions.offer()
	t.check(m.type == "photo", "first job is a photograph")
	var house: House = main.street.houses[m.lot]
	var desk: Dictionary = house.find_furn(m.spot)
	var doc: Dictionary = {}
	for it: Dictionary in desk.items:
		if it.id == "doc":
			doc = it
	t.check(not doc.is_empty(), "the document is in the target's %s" % m.spot)
	Game.give(Game.item("minicam"))
	main.missions.photographed()
	t.check(Game.has("film") and Game.mission.stage == "process", "film in hand")
	main.missions.process()
	t.check(Game.has("microdot") and not Game.has("film"), "developed to a microdot")
	t.check(not main.missions.drop((m.drop + 1) % 3), "the wrong drop refuses it")
	t.check(main.missions.drop(m.drop), "the right drop takes it")
	t.check(Game.intel > 0 and Game.mission.is_empty() and Game.missions_done == 1, "job complete, intel %d" % Game.intel)
	Game.take("minicam")


func test_4_caught_inside() -> void:
	await _world()
	Clock.minutes = 4.0 * 1440.0 + 20.0 * 60.0   # evening: people are home and awake
	main.skip(0.0)
	var who: Neighbour
	for n: Neighbour in main.neighbours:
		if n.state == "home" and n.d.job != "school":
			who = n
			break
	main.player.global_position = who.global_position + who.facing() * 1.5
	Engine.time_scale = 6.0
	await _wait(6.0)
	t.check(who.state == "alarm" or main.law.blown, "%s saw you in their house and went for the phone (state %s)" % [who.full_name(), who.state])
	await _wait(60.0)
	Engine.time_scale = 1.0
	t.check(main.law.blown, "the police have your name")
	t.check(who.suspicion >= 70.0, "and the neighbour is certain, %d" % who.suspicion)


func test_4b_dog() -> void:
	await _world()
	_calm()
	main.law.blown = false
	Clock.minutes = 7.0 * 1440.0 + 13.0 * 60.0
	main.skip(0.0)
	var dog: Dog = main.life.dogs[0]
	main.player.global_position = dog.global_position + Vector3(3, 0, 0)
	await _wait(0.5)
	t.check(dog.barking, "a dog barks at a stranger three metres away")
	Game.give(Game.item("treat"))
	main.life._feed(dog)
	await _wait(0.3)
	t.check(not dog.barking, "a biscuit quiets it")
	main.player.global_position = main.street.home.room_pos("living")


func test_4c_barbecue() -> void:
	await _world()
	_calm()
	Clock.minutes = 12.0 * 1440.0 + 4.0 * 60.0   # a Saturday, 4 AM
	t.check(Clock.weekday() == 5, "it is Saturday")
	main.life.new_day()
	t.check(main.life.event_host >= 0, "someone is hosting")
	main.skip(Clock.until(13.0))
	await _wait(0.3)
	var there := 0
	for n: Neighbour in main.neighbours:
		there += int(n.state == "event" and main.street.lot_at(n.global_position) == main.life.event_host)
	t.check(there >= 6, "the street is at the barbecue, got %d" % there)
	t.check(main.life.event_lot == main.life.event_host, "the event is on")
	var host: House = main.street.houses[main.life.event_host]
	main.player.global_position = Vector3(Street.lot_x(host.index) + 10.0, 0, Street.lot_side(host.index) * 27.0)
	await _wait(0.3)
	t.check(Game.ctx.zone == "yard" and Rules.judge(Game.ctx).is_empty(), "you are welcome in the host's yard")
	main.player.global_position = main.street.home.room_pos("living")
	main.skip(Clock.until(20.0))


func test_4d_body_and_agent() -> void:
	await _world()
	_calm()
	main.law.blown = false
	Clock.minutes = 15.0 * 1440.0 + 19.0 * 60.0
	main.skip(0.0)
	var a: Neighbour
	var b: Neighbour
	for n: Neighbour in main.neighbours:
		if n.state == "home" and n.d.job != "school" and not n.d.agent:
			if a == null:
				a = n
			elif n.house == a.house:
				b = n
	t.check(a != null and b != null, "a couple at home")
	if a == null or b == null:
		return
	# out in the open, so no wall is in the way
	b.stop()
	b._next_activity = Clock.minutes + 999.0
	b.global_position = Vector3(60, 0, 3)
	b.figure.rotation.y = PI
	a.global_position = Vector3(60, 0, 0)
	a.knock_out()
	await _wait(1.0)
	t.check(a.found and b.state == "alarm", "a body in plain sight is found (found %s, state %s)" % [a.found, b.state])
	b.knock_out()
	a.kill()
	a.died_at = Clock.minutes
	a.found = false
	a.hidden_body = true
	Clock.minutes += 30.0 * 60.0
	var before := Game.incident
	main.law.daily()
	t.check(a.missing_reported and Game.incident > before, "a vanished neighbour is reported missing")
	var agent: Neighbour
	for n: Neighbour in main.neighbours:
		if n.d.agent:
			agent = n
	Game.incident = 60.0
	await _wait(0.8)
	Clock.minutes = 17.0 * 1440.0 + 22.5 * 60.0
	await _wait(0.2)
	t.check(agent.watching and agent.plan() == "watch", "the counter-agent comes out at night when the street is hot")
	Game.incident = 0.0


func test_5_search_and_save() -> void:
	await _world()
	_calm()
	main.law.blown = false
	Game.radio_hidden = true
	var stuff: Array = main.law.contraband(false)
	t.check(stuff.size() == 3, "three pieces of kit under the floor, got %d" % stuff.size())
	for s: Dictionary in stuff:
		t.check(s.place == "stash", "kit is in the hiding place")
	Game.give(Game.item("film"))
	t.check(main.law.contraband(true).size() == 4 and main.law.contraband(false).size() == 3, "pockets only count if you are home")
	Game.money = 77
	main.neighbours[0].suspicion = 33.0
	Save.write(main)
	Game.money = 0
	main.neighbours[0].suspicion = 0.0
	Game.inventory.clear()
	# a fresh street from the same seed, then the save on top
	main.queue_free()
	Game.pending_load = true
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	t.add_child(main)
	while not main.ready_to_play:
		await t.get_tree().physics_frame
	t.check(Game.money == 77 and Game.has("film"), "money and pockets restored")
	t.check(main.neighbours[0].suspicion == 33.0, "suspicion restored")
	t.check(main.street.home.find_furn("stash").items.size() == 3, "stash restored")
	Save.wipe()
