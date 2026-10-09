class_name Shift
extends Node
## The day job: a shift as janitor on the plant floor. Mop the spills, clock out. Desks and
## records can be looked through for leads, but being seen at it gets you written up.

const RATE := 5.0          # clock speed on shift: eight hours pass in about a minute and a quarter
const PAY := 30

var main: Node
var active := false
var spills: Array[MeshInstance3D] = []
var staff: Array[Walker] = []
var _left := 0
var _snooped: Dictionary = {}
var _caught_today := false
var _think := 0.0
var _rng := RandomNumberGenerator.new()


func start() -> void:
	var plant: House = main.street.plant
	active = true
	_caught_today = false
	_snooped.clear()
	_rng.seed = Game.run_seed + Clock.day() * 13
	Clock.advance(Clock.until(9.0))
	Clock.rate = RATE
	main.player.global_position = plant.room_pos("closet")
	main.cam.position = main.player.position + main.cam.basis.z * 150.0
	for i in 6:
		var room: Array = plant.tpl.rooms[_rng.randi() % plant.tpl.rooms.size()]
		var at := plant.to_global(Vector3(room[1] + _rng.randf_range(1.0, room[3] - 1.0), 0, room[2] + _rng.randf_range(0.8, room[4] - 0.8)))
		var s := Build.cyl(self, 0.55, 0.03, at + Vector3.UP * 0.05, Color(0.35, 0.5, 0.6, 0.8))
		spills.append(s)
	_left = spills.size()
	if staff.is_empty():
		for i in 4:
			var w := Walker.new()
			w.street = main.street
			add_child(w)
			var guard := i == 0
			w.make_figure({"shirt": "27365a" if guard else Cast.SHIRTS[_rng.randi() % 8], "pants": "2c2f36", "hair": Cast.HAIRS[_rng.randi() % 6], "skin": Cast.SKINS[_rng.randi() % 5]})
			if guard:
				Build.box(w.figure, Vector3(0.34, 0.08, 0.34), Vector3(0, 1.88, 0), Color("1b2440"))
			staff.append(w)
	for w in staff:
		w.visible = true
		var room: Array = plant.tpl.rooms[_rng.randi() % plant.tpl.rooms.size()]
		w.global_position = plant.to_global(Vector3(room[1] + room[3] * 0.5, 0, room[2] + room[4] * 0.5))
		w.stop()
	Game.say("Nine o'clock. Six spills on the floor sheet. Mop them, then clock out in the closet.")


func options(pos: Vector3) -> Array:
	var it: Interact = main.interact
	var found: Array = []
	var plant: House = main.street.plant
	for s in spills:
		if s.visible and s.global_position.distance_to(pos) < 1.4:
			found.append([0.1, it._opt("Mop the spill", func() -> void: _mopped(s), 2.0)])
	for f in plant.furn:
		if f.name == "" or (f.pos as Vector3).distance_to(pos) > 1.6:
			continue
		found.append([0.5, it._opt("Look through the %s" % String(f.name).to_lower(), func() -> void: _snoop(f), 3.5, "search")])
	if pos.distance_to(plant.room_pos("closet")) < 2.2:
		found.append([0.3, it._opt("Clock out" if _left == 0 else "Clock out early (%d spills left)" % _left, func() -> void: finish())])
	return found


func _mopped(s: MeshInstance3D) -> void:
	s.visible = false
	_left -= 1
	Game.say("Done. %d to go." % _left if _left > 0 else "Floor sheet finished. Clock out in the closet.")


func _snoop(f: Dictionary) -> void:
	var key: int = plant_index(f)
	if _snooped.has(key):
		Game.say("Nothing more here today.")
		return
	_snooped[key] = true
	var pool: Array[Neighbour] = main.missions.targets()
	if pool.is_empty():
		return
	var n: Neighbour = pool[_rng.randi() % pool.size()]
	var id := int(n.d.id)
	if not Game.knows(id, "hours"):
		Game.learn(id, "hours")
		Game.note("A duty roster: %s is at the plant %s to %s." % [n.full_name(), Life.hhmm(n.d.leave), Life.hhmm(n.d.back)])
	elif n.d.secret != "" and not Game.knows(id, "secret"):
		Game.learn(id, "secret")
		Game.note("A personnel note: %s %s." % [n.full_name(), Life.SECRET_TEXT[n.d.secret]])
	else:
		Game.intel += 2
		Game.note("A memo worth remembering. Intelligence +2.")


func plant_index(f: Dictionary) -> int:
	return main.street.plant.furn.find(f)


func _process(delta: float) -> void:
	if not active:
		return
	var plant: House = main.street.plant
	var p: Player = main.player
	for w in staff:
		w.walk(delta)
	_think -= delta
	if _think > 0.0:
		return
	_think = 0.3
	for w in staff:
		if w.arrived and _rng.randf() < 0.08:
			var room: Array = plant.tpl.rooms[_rng.randi() % plant.tpl.rooms.size()]
			w.go_to(plant.to_global(Vector3(room[1] + _rng.randf_range(1.0, room[3] - 1.0), 0, room[2] + _rng.randf_range(1.0, room[4] - 1.0))))
		if main.interact.act == "search" and not _caught_today and w.can_see(p.global_position, 1.0, p.sneaking):
			_caught_today = true
			Game.writeups += 1
			for n: Neighbour in main.neighbours:
				if n.d.job == "plant":
					n.add_suspicion(6.0, "heard you were caught going through an office at the plant")
			if Game.writeups >= 2:
				Game.fired = true
				Game.incident_add(12.0, "Caught in an office again. The plant has fired you and security has your name.")
				finish()
				return
			Game.note("\"What are you doing in there?\" You have been written up. Once more and you are out.")
	if Clock.hour() >= 17.0:
		finish()


func finish() -> void:
	if not active:
		return
	active = false
	Clock.rate = 1.0
	for s in spills:
		s.queue_free()
	spills.clear()
	for w in staff:
		w.visible = false
	Game.worked_today = true
	Game.fatigue = minf(100.0, Game.fatigue + 8.0)
	if Game.fired:
		pass
	elif _left == 0:
		Game.money += PAY
		Game.say("Shift done. $%d in the pay packet." % PAY)
	else:
		Game.money += PAY / 2
		Game.note("You left the floor half done. Half pay, and the foreman noticed.")
		Game.missed_shifts += 1
	main.player.global_position = main.street.bus_stop
	main.cam.position = main.player.position + main.cam.basis.z * 150.0
	if Clock.hour() < 17.0:
		main.skip(Clock.until(17.0))
	else:
		main.skip(15.0)
