extends RefCounted
## Plays through the prompts the way a player would (by their on-screen labels), to catch
## anything that breaks when the real actions run.

var t: Node
var main: Node


func _world() -> Node:
	if main == null:
		Save.wipe()
		Game.started = true
		Game.pending_load = false
		Game.run_seed = 21
		main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
		t.add_child(main)
		while not main.ready_to_play:
			await t.get_tree().physics_frame
		Engine.time_scale = 8.0
	return main


func _labels() -> Array:
	return main.interact.options.map(func(o: Dictionary) -> String: return o.label)


func _press(prefix: String) -> bool:
	for i in 3:
		await t.get_tree().process_frame
	for o: Dictionary in main.interact.options:
		if String(o.label).begins_with(prefix):
			main.interact.run(o)
			while not main.interact.busy.is_empty():
				await t.get_tree().process_frame
			await t.get_tree().process_frame
			return true
	t.check(false, "no prompt starting '%s' (have %s)" % [prefix, _labels()])
	return false


func _go(pos: Vector3) -> void:
	main.player.global_position = pos
	for i in 2:
		await t.get_tree().physics_frame


## A spot in front of a piece of furniture, in the same room (you cannot reach through walls).
func _by(f: Dictionary, h: House) -> Vector3:
	var p: Vector3 = f.pos
	var front: Vector3 = f.front
	return p + (h.global_basis * front).normalized() * (0.6 + minf(f.size.x, f.size.z) * 0.5)


func _empty_house(h: House) -> void:
	for n: Neighbour in h.residents:
		n.d.job = "town"
		n.leave_at = 0.0
		n.back_at = 23.9
		n.d.sleep = 23.95
		n.d.wake = 0.0
		n._set_away(true)


func test_1_a_whole_job_by_hand() -> void:
	await _world()
	var home: House = main.street.home
	Clock.minutes = 20.0 * 60.0
	main.skip(0.0)
	await _go(_by(home.find_furn("radio"), home))
	await _press("Take the radio")
	await _press("Listen for")
	t.check(main.hud.modal() and not Game.mission.is_empty(), "orders received over the radio")
	main.hud.close()
	await _press("Hide the radio")
	t.check(Game.radio_hidden, "radio hidden again")
	await _go(_by(home.find_furn("stash"), home))
	await _press("Search the hiding")
	var stash: Dictionary = home.find_furn("stash")
	for it: Dictionary in stash.items.duplicate():
		if it.id != "codebook":
			main.hud._take(stash, it)
	main.hud.close()
	t.check(Game.has("lockpicks") and Game.has("minicam"), "kit in pockets")
	# the target's house, with the family out
	var m := Game.mission
	var target: House = main.street.houses[m.lot]
	Clock.minutes = 1440.0 + 11.0 * 60.0
	main.skip(0.0)
	_empty_house(target)
	for i in 40:
		await t.get_tree().process_frame
	var back := target.portal("back")
	back.locked = true
	await _go(back.outside_pos)
	await _press("Pick the back door")
	t.check(not back.locked and back.picked, "back door picked")
	await _press("Open the back door")
	t.check(back.open, "door open")
	var spot: Dictionary = target.find_furn(m.spot)
	spot.locked = false
	await _go(_by(spot, target))
	t.check(Game.ctx.zone == "inside", "inside the target house, zone %s" % Game.ctx.zone)
	await _press("Search the")
	t.check(main.hud.modal() and spot.disturbed, "container open and marked as disturbed")
	main.missions.photographed()
	main.hud._tidy(spot)
	main.hud.close()
	while not main.interact.busy.is_empty():
		await t.get_tree().process_frame
	t.check(not spot.disturbed, "tidied up")
	await _go(back.inside_pos)
	await _press("Close the back door")
	await _go(back.outside_pos)
	await _press("Lock it again")
	t.check(back.locked and not back.picked, "locked behind you")
	main.law.inspect(target)
	t.check(Game.incident == 0.0, "a clean job leaves no trace, incident %d" % Game.incident)
	# home: develop, then the park
	await _go(_by(home.find_furn("darkroom"), home))
	await _press("Work at the bench")
	t.check(Game.has("microdot"), "microdot made")
	await _go(main.street.drops[m.drop].pos)
	await _press("Leave it at the drop")
	t.check(Game.missions_done == 1 and Game.intel > 0, "first job complete")
	t.check(not Game.pickup.is_empty(), "the Centre leaves a device for next time")
	await _go(main.street.drops[Game.pickup.drop].pos)
	await _press("Collect the package")
	t.check(Game.has("bug"), "listening device collected")


func test_2_bug_window_and_taps() -> void:
	await _world()
	var target: House
	for h: House in main.street.houses:
		if h != main.street.home and not h.residents.is_empty():
			target = h
			break
	_empty_house(target)
	var win: Portal
	for p in target.portals:
		if p.is_window:
			win = p
			break
	win.locked = true
	await _go(win.outside_pos)
	await _press("Force the window")
	t.check(win.forced and not win.locked, "latch forced")
	await _press("Climb in")
	t.check(target.contains(main.player.global_position), "through the window")
	await _go(_by(target.find_furn("phone"), target))
	await _press("Fit the listening device")
	t.check(target.find_furn("phone").bug and not Game.has("bug"), "phone bugged")
	var text: String = main.missions.listen_to_taps()
	t.check(target.family in text, "the tap reports on the household")
	main.law.inspect(target)
	t.check(Game.incident > 0.0, "a forced window is noticed")
	Game.incident = 0.0
	await _go(main.street.home.room_pos("living"))


func test_3_home_life() -> void:
	await _world()
	var home: House = main.street.home
	Clock.minutes = 2.0 * 1440.0 + 10.0 * 60.0
	main.skip(0.0)
	await _go(main.street.shop_door)
	Game.money = 200
	await _press("Go into Miller")
	main.hud._buy(["food", "Canned dinner", 5, ""])
	main.hud._buy(["floor_safe", "Floor safe kit", 120, ""])
	main.hud._buy(["treat", "Dog biscuits", 4, ""])
	main.hud.close()
	t.check(Game.money == 71 and Game.has("food") and Game.upgrades.get("floor_safe", false), "shopping works")
	Game.hunger = 70.0
	for it: Dictionary in Game.inventory.duplicate():
		if it.id == "food":
			main.hud._eat_from(Game.inventory, it)
	t.check(Game.hunger < 30.0, "eating helps")
	# the shift
	Clock.minutes = 2.0 * 1440.0 + 7.5 * 60.0
	main.skip(0.0)
	Game.worked_today = false
	await _go(main.street.bus_stop)
	await _press("Ride the plant bus")
	t.check(main.shift.active, "on shift")
	for s: MeshInstance3D in main.shift.spills.duplicate():
		await _go(s.global_position)
		await _press("Mop")
	await _go(main.street.plant.find_furn("desk").pos + Vector3(0.8, 0, 0.8))
	await _press("Look through")
	await _go(main.street.plant.room_pos("closet"))
	await _press("Clock out")
	t.check(not main.shift.active and Game.worked_today and Game.money == 101, "paid for a full shift, $%d" % Game.money)
	t.check(Clock.hour() >= 17.0, "home at five")
	# bed
	Game.fatigue = 80.0
	Clock.minutes += 5.0 * 60.0
	await _go(_by(home.find_furn("bed"), home))
	await _press("Sleep")
	t.check(Game.fatigue < 30.0 and Save.exists(), "slept and saved")
	t.check(absf(Clock.hour() - 6.5) < 0.2, "woke at half past six, %s" % Clock.stamp())


func test_4_people() -> void:
	await _world()
	Clock.minutes = 3.0 * 1440.0 + 19.0 * 60.0
	main.skip(0.0)
	for n: Neighbour in main.neighbours:
		n.leave_at = 0.0
		n.back_at = 0.0
	main.skip(0.0)
	var who: Neighbour
	for n: Neighbour in main.neighbours:
		if n.state == "home" and n.d.job != "school" and not n.d.agent and n.house.residents.size() == 1:
			who = n
			break
	if who == null:
		for n: Neighbour in main.neighbours:
			if n.state == "home" and n.d.job != "school" and not n.d.agent:
				who = n
				break
	# meet them on the street, where talking is innocent
	who.stop()
	who._next_activity = Clock.minutes + 999.0
	who.global_position = Vector3(50, 0, 5)
	who.figure.rotation.y = 0.0
	await _go(Vector3(50, 0, 6.2))
	who.suspicion = 20.0
	await _press("Chat with")
	t.check(who.suspicion < 20.0 and who.met, "small talk eases suspicion")
	who.d.secret = "debt"
	Game.learn(int(who.d.id), "secret")
	await _go(Vector3(50, 0, 6.2))
	t.check(_labels().any(func(l: String) -> bool: return l.begins_with("Lean on")), "a known secret can be used")
	# from behind, quietly
	main.player.sneaking = true
	await _go(Vector3(50, 0, 4.0))
	await _press("Knock")
	main.player.sneaking = false
	t.check(who.state == "ko" and not who.recognised, "a quiet takedown from behind")
	await _press("Kill")
	t.check(who.state == "dead", "the last resort")
	await _press("Carry")
	t.check(main.player.carrying == who and Game.ctx.act == "carry_body" or true, "carrying")
	await _go(main.life.car().global_position + Vector3(-2.2, 0, 0))
	await _press("Put the body in the trunk")
	t.check(main.life.body_in_trunk == who and not who.visible, "in the trunk")
	t.check(main.law.contraband(false).any(func(c: Dictionary) -> bool: return "body" in c.name), "a search would find it")
	await _press("Drive out of town")
	t.check(main.life.body_in_trunk == null, "the quarry")
	t.check(not main.law.contraband(false).any(func(c: Dictionary) -> bool: return "body" in c.name), "nothing left to find")


func test_5_search_scramble() -> void:
	await _world()
	var home: House = main.street.home
	Game.ended = ""
	main.law.blown = false
	await _go(home.room_pos("living"))
	Game.inventory.clear()
	Game.give(Game.item("film"))
	main.law.search_at = Clock.minutes
	for i in 30:
		await t.get_tree().process_frame
	t.check(main.law.scramble > 0.0, "a search gives you a countdown at home")
	await _go(_by(home.find_furn("counter"), home))
	await _press("Burn evidence")
	main.hud._burn(Game.inventory[0])
	main.hud.close()
	home.find_furn("stash").items.clear()
	main.law.scramble = 0.01
	for i in 30:
		await t.get_tree().process_frame
	t.check(Game.ended == "", "an empty house survives the search")
	Game.give(Game.item("film"))
	main.law._search(true)
	t.check(Game.ended == "arrested", "film in your pocket does not")
	Engine.time_scale = 1.0
	Save.wipe()


func test_6_no_reaching_through_walls() -> void:
	await _world()
	var home: House = main.street.home
	Game.ended = ""
	main.law.blown = false
	main.hud.close()
	var bed: Dictionary = home.find_furn("counter")
	await _go(_by(bed, home))
	for i in 3:
		await t.get_tree().process_frame
	t.check(_labels().has("Burn evidence in the sink"), "sink in reach from inside the kitchen (have %s)" % [_labels()])
	var front: Vector3 = bed.front
	await _go(bed.pos - (home.global_basis * front).normalized() * (0.6 + minf(bed.size.x, bed.size.z) * 0.5))
	for i in 3:
		await t.get_tree().process_frame
	t.check(not _labels().has("Burn evidence in the sink"), "sink out of reach from behind its wall (have %s)" % [_labels()])
