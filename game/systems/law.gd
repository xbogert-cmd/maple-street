class_name Law
extends Node
## Consequences: neighbours finding signs of a break-in, police calls, the investigator,
## house searches and arrest.

const RESPONSE_MIN := 40.0      # game minutes from a call to officers arriving
const SCRAMBLE_SEC := 45.0      # real seconds to hide things before a search

var main: Node
var blown := false              # the police know it was you
var arrive_at := -1.0
var patrol_until := 0.0
var officers: Array[Walker] = []
var police_car: Node3D
var investigating := false
var investigator: Walker
var inv_car: Node3D
var search_at := -1.0
var no_search_until := 0.0
var scramble := -1.0            # seconds left before the search starts (-1: none)
var _inv_next := 0.0
var _think := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = Game.run_seed + 911
	police_car = main.street._car(Color("e8e8ea"))
	Build.box(police_car, Vector3(1.2, 0.15, 0.3), Vector3(0, 1.5, -0.2), Color("c0392b"))
	police_car.visible = false
	add_child(police_car)
	inv_car = main.street._car(Color("23262b"))
	inv_car.visible = false
	add_child(inv_car)
	investigator = Walker.new()
	investigator.street = main.street
	add_child(investigator)
	investigator.make_figure({"shirt": "2f3136", "pants": "25272b", "hair": "3a2a1c", "skin": "e2bd9a"})
	Build.box(investigator.figure, Vector3(0.36, 0.06, 0.36), Vector3(0, 1.88, 0), Color("2a2a2c"))
	investigator.visible = false


## A resident looks around their house for signs someone was in.
func inspect(h: House) -> void:
	var signs: Array[String] = []
	for f in h.furn:
		if f.disturbed:
			f.disturbed = false
			signs.append("the %s had been gone through" % String(f.name).to_lower())
		if f.bug and _rng.randf() < 0.04:
			f.bug = false
			signs.append("a listening device in the telephone")
	var m := Game.mission
	if m.get("type", "") == "borrow" and m.lot == h.index and m.stage in ["process", "deliver"] and not m.returned and _rng.randf() < 0.5:
		signs.append("the %s is missing" % m.doc)
		m.returned = true   # too late to put it back quietly
	for p in h.portals:
		if p.forced:
			p.forced = false
			signs.append("a window latch was forced")
		elif p.picked:
			p.picked = false
			signs.append("the %s was unlocked" % p.label().to_lower())
	if signs.is_empty():
		return
	for r: Neighbour in h.residents:
		r.alert = true
		if r.suspicion >= 25.0:
			r.add_suspicion(12.0, "thinks it was you in their house")
	for p in h.portals:
		p.locked = true
	Game.incident_add(8.0 + 6.0 * signs.size(), "The %s household found %s." % [h.family, ", ".join(signs)])


## A neighbour has reached the phone.
func report(who: Neighbour) -> void:
	for r: Neighbour in who.house.residents:
		r.alert = true
	arrive_at = Clock.minutes + RESPONSE_MIN
	if who.recognised:
		blown = true
		Game.note("%s has called the police and named you. Get out of town." % who.full_name())
	else:
		Game.incident_add(25.0, "%s has called the police about a prowler." % who.full_name())
	patrol_until = Clock.minutes + 180.0


func agent_saw(who: Neighbour) -> void:
	if blown:
		return
	blown = true
	arrive_at = Clock.minutes + 10.0
	Game.note("%s was watching. He is no salesman, and now the Bureau knows everything." % who.full_name())


## Bodies lying where a neighbour can see them.
func _bodies() -> void:
	for b: Neighbour in main.neighbours:
		if not b.is_out_cold() or b.found or b.carried or b.hidden_body:
			continue
		for n: Neighbour in main.neighbours:
			if n == b or not n.is_awake() or n.asset or n.global_position.distance_to(b.global_position) > 14.0:
				continue
			if n.can_see(b.global_position, Game.ctx.get("light", 1.0), true):
				b.found = true
				if b.state == "dead":
					Game.incident_add(35.0, "%s has found %s dead. The street will never be the same." % [n.full_name(), b.full_name()])
					investigating = true
				n.alarm("found %s lying there" % b.full_name())
				break


## Called at 4 AM: decide whether the Bureau takes an interest today.
func daily() -> void:
	for n: Neighbour in main.neighbours:
		if n.state == "dead" and not n.found and not n.missing_reported and Clock.minutes - n.died_at > 20.0 * 60.0:
			n.missing_reported = true
			investigating = true
			Game.incident_add(22.0, "%s has been reported missing. The Bureau is asking questions." % n.full_name())
			if n.d.agent:
				search_at = Clock.minutes + Clock.until(8.0)
				Game.note("The missing man was one of theirs. They will tear the street apart.")
	if Game.heat >= Rules.HEAT_SEARCH and search_at < 0.0 and Clock.minutes >= no_search_until:
		search_at = Clock.minutes + Clock.until(8.0) + _rng.randf_range(0.0, 120.0)
		investigating = true
	elif Game.heat >= Rules.HEAT_INVESTIGATOR:
		if not investigating:
			Game.note("Word is a man from the Bureau has been asking about the street.")
		investigating = true
	elif Game.heat < 22.0:
		investigating = false


func _process(delta: float) -> void:
	if Game.ended != "":
		return
	if scramble >= 0.0:
		scramble -= delta
		if scramble < 0.0:
			_search(true)
	_think -= delta
	if _think > 0.0:
		for o in officers:
			o.walk(delta)
		investigator.walk(delta)
		return
	_think = 0.25
	if arrive_at >= 0.0 and Clock.minutes >= arrive_at:
		arrive_at = -1.0
		_send_officers()
	if search_at >= 0.0 and Clock.minutes >= search_at:
		search_at = -1.0
		if Game.ctx.get("zone", "") == "home":
			scramble = SCRAMBLE_SEC
			Game.say("Two sedans have pulled up outside. They are coming to search the house.")
		else:
			_search(false)
	_officers()
	_investigator()
	_bodies()


func _send_officers() -> void:
	police_car.position = Vector3(-30, 0, -2)
	police_car.rotation.y = PI * 0.5
	police_car.visible = true
	for i in 2:
		var o := Walker.new()
		o.street = main.street
		add_child(o)
		o.make_figure({"shirt": "27365a", "pants": "1f2a44", "hair": "1c1c1c", "skin": "d9a57c"})
		Build.box(o.figure, Vector3(0.34, 0.08, 0.34), Vector3(0, 1.88, 0), Color("1b2440"))
		o.global_position = Vector3(-28, 0, 1.0 + i)
		o.speed = 3.0
		officers.append(o)
	Sfx.play("siren", null, -2.0)
	Game.say("A police car has pulled in at the end of the street.")


func _officers() -> void:
	if officers.is_empty():
		return
	var p: Player = main.player
	var light: float = Game.ctx.get("light", 1.0)
	for o in officers:
		var sees := p.visible and o.can_see(p.global_position, light, p.sneaking)
		if sees and not blown and not Rules.judge(Game.ctx).is_empty():
			blown = true
			Game.note("An officer caught you in the act.")
		if blown and sees:
			o.speed = 4.4
			o.go_to(p.global_position)
			if o.global_position.distance_to(p.global_position) < 1.4:
				Game.end("arrested", "The police took you in the street.")
		elif o.arrived:
			o.speed = 2.2
			if blown and _rng.randf() < 0.5:
				o.go_to(main.street.home.portal("front").outside_pos)
			else:
				o.go_to(Vector3(_rng.randf_range(0.0, 120.0), 0, [-5.0, 5.0][_rng.randi() % 2]))
	if not blown and Clock.minutes > patrol_until:
		for o in officers:
			o.queue_free()
		officers.clear()
		police_car.visible = false
		Game.say("The police car has gone.")


func _investigator() -> void:
	var h := Clock.hour()
	var on := investigating and h >= 9.0 and h < 23.0
	if on != inv_car.visible:
		inv_car.visible = on
		investigator.visible = on
		if on:
			var home_x: float = Street.lot_x(main.street.cast.home)
			inv_car.position = Vector3(clampf(home_x + 34.0, 10.0, 112.0), 0, 2.4)
			inv_car.rotation.y = PI * 0.5
			investigator.global_position = inv_car.position + Vector3(0, 0, 1.6)
			_inv_next = Clock.minutes + 20.0
			Game.say("A dark sedan is parked on the street. A man in a hat is watching.")
	if not on:
		return
	var p: Player = main.player
	if investigator.can_see(p.global_position, Game.ctx.get("light", 1.0), p.sneaking):
		var j := Rules.judge(Game.ctx)
		if not j.is_empty() and not blown:
			if j.severe or j.kind == "yard_night":
				blown = true
				arrive_at = Clock.minutes + 10.0
				Game.note("The man from the Bureau saw everything. They are coming for you.")
	if investigator.arrived and Clock.minutes >= _inv_next:
		_inv_next = Clock.minutes + 45.0
		if h < 17.0:
			# door to door
			var pool: Array[House] = []
			for house: House in main.street.houses:
				if house != main.street.home:
					pool.append(house)
			var pick: House = pool[_rng.randi() % pool.size()]
			investigator.go_to(pick.portal("front").outside_pos, func() -> void: _interview(pick))
		else:
			investigator.go_to(inv_car.position + Vector3(0, 0, 1.6))
			investigator.figure.rotation.y = PI


func _interview(h: House) -> void:
	for r: Neighbour in h.residents:
		if r.is_awake() and h.contains(r.global_position) and r.suspicion >= 15.0 and not r.asset:
			r.add_suspicion(6.0, "told the man from the Bureau about you")


## Contraband in the house, and in your pockets if you are there.
func contraband(at_home: bool) -> Array:
	var items: Array = []
	if at_home:
		for it in Game.inventory:
			if it.contraband:
				items.append({"name": it.name, "place": "pocket"})
	for f in main.street.home.furn:
		var place := "open"
		if f.kind == "stash":
			place = "floor_safe" if Game.upgrades.get("floor_safe", false) else "stash"
		for it: Dictionary in f.items:
			if it.contraband:
				items.append({"name": it.name, "place": place})
	if not Game.radio_hidden:
		items.append({"name": "Shortwave set", "place": "open"})
	for it: Dictionary in main.life.trunk.items:
		if it.contraband:
			items.append({"name": it.name + " (in the car)", "place": "open"})
	if main.life.body_in_trunk:
		items.append({"name": "a body in the trunk of your car", "place": "open"})
	return items


func _search(at_home: bool) -> void:
	var items := contraband(at_home)
	var rolls: Array = []
	for i in items.size():
		rolls.append(_rng.randf())
	var found := Rules.search_finds(items, rolls)
	if not found.is_empty():
		Game.end("arrested", "The search turned up: %s." % ", ".join(found))
		return
	Game.incident = maxf(0.0, Game.incident - 25.0)
	for n: Neighbour in main.neighbours:
		n.suspicion *= 0.7
	no_search_until = Clock.minutes + 3.0 * 1440.0
	investigating = false
	Game.note("They searched the house from attic to cellar and found nothing." if at_home else "You came home to drawers pulled out. The house was searched. They found nothing.")
