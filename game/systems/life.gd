class_name Life
extends Node
## Everyday things: stocking the houses at the start of a run, hunger and tiredness, sleep,
## the daily turnover (gossip, forgetting, missed work), weather and street events.

const JUNK: Dictionary = {
	"desk": ["Utility bills", "Chequebook", "Stationery", "Tax forms"],
	"cabinet": ["Insurance papers", "Old report cards", "Appliance manuals"],
	"dresser": ["Folded shirts", "Socks", "Costume jewellery"],
	"fridge": ["Leftover casserole", "Milk", "Half a meatloaf"],
	"mailbox": ["Sears catalogue", "Electric bill", "Church newsletter"],
	"trash": ["Coffee grounds", "Yesterday's newspaper", "Empty cans"],
}
const SECRET_CLUES: Dictionary = {
	"debt": "A final notice from Riverside Savings & Loan",
	"affair": "A motel receipt for a Thursday afternoon",
	"drinking": "Empty bourbon bottles wrapped in newspaper",
	"gambling": "Racing forms and a bookmaker's slips",
}
const SECRET_TEXT: Dictionary = {"debt": "is deep in debt", "affair": "is having an affair", "drinking": "is hiding a drinking problem", "gambling": "owes money to a bookmaker"}

var main: Node
var rain := 0.0            # 0 dry .. 1 raining
var rain_from := -1.0      # today's rain, clock hours (-1: none)
var rain_to := -1.0
var event_lot := -1        # lot hosting a street event right now (-1: none)
var event_host := -1       # lot hosting the next or current event
var event_from := -1.0
var event_to := -1.0
var dogs: Array[Dog] = []
var trunk: Dictionary = {}  # the car boot, shaped like a furniture container
var body_in_trunk: Neighbour
var _attended := 0.0
var _props: Node3D
var _rain_fx: CPUParticles3D
var _rng := RandomNumberGenerator.new()


const HOW_TO := """You are a sleeper agent. On paper you are the new janitor at the defence plant, and half this street works there.

[b]Tonight:[/b] after 7 PM, take the radio out of hiding in your study and listen for orders. Your camera and lockpicks are under the bedroom floor.

[b]The work:[/b] learn when a house is empty. Cars in the drive and lit windows tell you who is home. Get in, find the papers, photograph them, put everything back, lock up behind you. Develop the film at your bench and leave it at the dead drop in the park.

[b]The street is watching.[/b] Yards, locks and windows are how people get noticed. Darkness, sneaking (C) and rain hide you. A "?" over a neighbour means they are working out what they see. A "!" means they are going for the telephone.

[b]Keep your cover.[/b] Ride the plant bus to work on weekday mornings. Eat. Sleep in your own bed, which saves the game.

If you are caught, that agent is finished. Press Esc for the controls."""
const FILLER: Array[String] = ["County fair opens Saturday", "Plant wins new Air Force contract", "School board votes on new gymnasium", "Water main work on Elm Street next week", "Bowling league standings inside", "Church bake sale raises record sum", "Hardware store marks forty years"]


func _ready() -> void:
	_rng.seed = Game.run_seed + 2024
	var st: Street = main.street
	for h: Dictionary in st.cast.houses:
		if h.dog:
			var dog := Dog.new()
			add_child(dog)
			dog.setup(st.houses[h.lot], main.player, [Color("7a5a3a"), Color("2e2a26"), Color("c9b48a")][dogs.size() % 3])
			dog.position = Vector3(Street.lot_x(h.lot) + _rng.randf_range(5.0, 13.0), 0, Street.lot_side(h.lot) * 26.0)
			dogs.append(dog)
	trunk = {"kind": "trunk", "name": "Car trunk", "node": null, "pos": Vector3.ZERO, "items": [], "locked": false, "disturbed": false, "house": st.home, "bug": false}
	_rain_fx = CPUParticles3D.new()
	_rain_fx.amount = 700
	_rain_fx.lifetime = 0.7
	_rain_fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_rain_fx.emission_box_extents = Vector3(22, 0.1, 22)
	_rain_fx.direction = Vector3(0.15, -1, 0.1)
	_rain_fx.spread = 2.0
	_rain_fx.gravity = Vector3.ZERO
	_rain_fx.initial_velocity_min = 22.0
	_rain_fx.initial_velocity_max = 26.0
	var drop := BoxMesh.new()
	drop.size = Vector3(0.025, 0.7, 0.025)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.albedo_color = Color(0.8, 0.86, 0.95, 0.35)
	drop.material = dm
	_rain_fx.mesh = drop
	_rain_fx.emitting = false
	add_child(_rain_fx)


func new_run() -> void:
	Game.reset()
	var st: Street = main.street
	furnish_home()
	var stash: Dictionary = st.home.find_furn("stash")
	for id: String in ["lockpicks", "minicam", "codebook"]:
		stash.items.append(Game.item(id))
	for i in 3:
		st.home.find_furn("fridge").items.append(Game.item("food"))
	for c in st.all_containers():
		var h: House = c.house
		if h == st.home or c.name == "":
			continue
		var pool: Array = JUNK.get(c.kind, [])
		for i in _rng.randi_range(1, 2):
			if not pool.is_empty():
				c.items.append({"id": "junk", "name": pool[_rng.randi() % pool.size()], "contraband": false})
		if c.kind == "fridge":
			c.items.append(Game.item("food"))
	for n: Neighbour in main.neighbours:
		var h := n.house
		if int(n.d.clearance) >= 3:
			h.find_furn("cabinet").locked = true
		if n.d.secret != "":
			_clue(h, ["trash", "mailbox", "dresser"][_rng.randi() % 3], SECRET_CLUES[n.d.secret], n, "secret")
		if n.d.agent:
			_clue(h, ["trash", "cabinet"][_rng.randi() % 2], "Carbon paper from a typed surveillance log", n, "agent")
		elif n.d.job in ["plant", "town"]:
			_clue(h, ["mailbox", "desk"][_rng.randi() % 2], "%s's shift card" % n.d.first, n, "hours")
	main.missions.next_at = Clock.minutes + Clock.until(19.0)
	Game.note("Day one. Radio contact after 7 PM. Your kit is under the bedroom floor.")
	if not Game.args.has("demo") and not Game.args.has("shot") and DisplayServer.get_name() != "headless":
		main.hud.open_text.call_deferred("Maple Street, 1984", HOW_TO, [["Begin", Callable()]], true)


func furnish_home() -> void:
	var home: House = main.street.home
	for f: Array in home.tpl.home:
		home.add_furniture(f[0], Vector2(f[1], f[2]), f[3])
	home.find_furn("radio").node.visible = not Game.radio_hidden


func _clue(h: House, kind: String, title: String, n: Neighbour, what: String) -> void:
	for c in main.street.all_containers():
		if c.house == h and c.kind == kind:
			c.items.append({"id": "clue", "name": title, "contraband": false, "person": int(n.d.id), "what": what})
			return


## Reading whatever is informative in a container the player has just opened.
func read_clues(c: Dictionary) -> void:
	for it: Dictionary in c.items:
		if it.id != "clue" or Game.knows(it.person, it.what):
			continue
		Game.learn(it.person, it.what)
		var n := person(it.person)
		match it.what:
			"secret":
				Game.note("%s. %s %s." % [it.name, n.full_name(), SECRET_TEXT[n.d.secret]])
			"hours":
				Game.note("%s: out %s to %s on weekdays." % [it.name, hhmm(n.d.leave), hhmm(n.d.back)])
			"agent":
				Game.note("%s. %s is no salesman. The Bureau has a man on this street." % [it.name, n.full_name()])


func person(id: int) -> Neighbour:
	for n: Neighbour in main.neighbours:
		if int(n.d.id) == id:
			return n
	return null


static func hhmm(h: float) -> String:
	var hh := int(h)
	return "%d:%02d %s" % [(hh + 11) % 12 + 1, int((h - hh) * 60.0), "AM" if hh % 24 < 12 else "PM"]


func _process(delta: float) -> void:
	if not Clock.running:
		return
	var mins := delta / Clock.SEC_PER_MIN * Clock.rate
	Game.hunger = minf(100.0, Game.hunger + mins * 100.0 / (22.0 * 60.0))
	Game.fatigue = minf(100.0, Game.fatigue + mins * 100.0 / (19.0 * 60.0))
	var h := Clock.hour()
	var want := 1.0 if rain_from >= 0.0 and h >= rain_from and h < rain_to else 0.0
	rain = move_toward(rain, want, delta * 0.2)
	_rain_fx.emitting = rain > 0.3
	_rain_fx.position = main.player.position + Vector3(0, 14, 0)
	# street event
	var on := Clock.minutes >= event_from and Clock.minutes < event_to
	if on and event_lot < 0:
		Game.say("The barbecue at the %s place has started." % main.street.houses[event_host].family)
		_props = Node3D.new()
		add_child(_props)
		var c := Vector3(Street.lot_x(event_host) + 10.0, 0, Street.lot_side(event_host) * 23.0)
		Build.box(_props, Vector3(2.4, 0.75, 0.9), c + Vector3(-2, 0.375, 0), Color("d9d4c7"))
		Build.cyl(_props, 0.4, 0.5, c + Vector3(2, 0.85, 0), Color("2a2a2c"), 0.3)
		Build.cyl(_props, 0.04, 0.7, c + Vector3(2, 0.35, 0), Color("55585c"))
	elif not on and event_lot >= 0:
		if _props:
			_props.queue_free()
			_props = null
		if _attended < 15.0:
			for n: Neighbour in main.neighbours:
				if float(n.d.nosy) > 0.5:
					n.add_suspicion(3.0, "noticed you stayed away from the barbecue")
		else:
			for n: Neighbour in main.neighbours:
				n.suspicion = maxf(0.0, n.suspicion - 4.0)
			Game.note("You were seen at the barbecue, a neighbour like any other.")
	event_lot = event_host if on else -1
	if on and Game.ctx.get("lot", -1) == event_lot:
		_attended += mins
	# the counter-agent comes out at night once the street is uneasy
	for n: Neighbour in main.neighbours:
		if n.d.agent and n.state != "dead":
			n.watching = Game.heat >= 18.0
			var home_lot: int = main.street.cast.home
			n.watch_spot = Vector3(Street.lot_x(home_lot) + 10.0, 0, -Street.lot_side(home_lot) * 5.0)


func eat(it: Dictionary) -> void:
	if it.id == "coffee":
		Game.fatigue = maxf(0.0, Game.fatigue - 22.0)
		Game.say("Coffee. That helps.")
	else:
		Game.hunger = maxf(0.0, Game.hunger - 45.0)
		Game.say("You eat.")
	Game.changed.emit()


## Sleep in your own bed. Saves the game.
func sleep() -> void:
	var h := Clock.hour()
	var night := h >= 19.0 or h < 5.0
	var mins := Clock.until(6.5) if night else 120.0
	Game.fatigue = maxf(0.0, Game.fatigue - mins / 480.0 * 100.0)
	Game.hunger = minf(100.0, Game.hunger + mins / 60.0 * 1.5)
	main.skip(mins)
	Save.write(main)
	Game.say("You slept until %s. Game saved." % Clock.stamp() if night else "You napped for two hours. Game saved.")


## 4 AM turnover.
func new_day() -> void:
	var ns: Array[Neighbour] = main.neighbours
	# gossip: housemates compare notes, next-door neighbours hear a share
	var add: Dictionary = {}
	for n in ns:
		if n.state == "dead" or n.asset:
			continue
		for o in ns:
			if o == n or o.state == "dead" or o.asset:
				continue
			if o.house == n.house:
				add[n] = maxf(add.get(n, 0.0), o.suspicion * 0.8 - n.suspicion)
			elif _adjacent(o.house.index, n.house.index):
				add[n] = maxf(add.get(n, 0.0), Rules.gossip(o.suspicion))
	for n: Neighbour in add:
		if add[n] > 0.5:
			n.add_suspicion(add[n], "has heard talk about you")
	for n in ns:
		if n.suspicion < 40.0:
			n.suspicion = maxf(0.0, n.suspicion - 2.0)
		n.roll_day()
	Game.incident = maxf(0.0, Game.incident - 4.0)
	# yesterday's shift
	var yesterday := (Clock.weekday() + 6) % 7
	if yesterday < 5 and not Game.worked_today and not Game.fired and Clock.day() > 1:
		Game.missed_shifts += 1
		for n in ns:
			if float(n.d.nosy) > 0.6:
				n.add_suspicion(4.0, "noticed you at home on a workday")
		if Game.missed_shifts >= 3:
			Game.fired = true
			Game.incident_add(10.0, "The plant has let you go for missing shifts. People will wonder how you pay the rent.")
		else:
			Game.note("You missed a shift. The foreman will remember. (%d of 3)" % Game.missed_shifts)
	Game.worked_today = false
	_weather()
	_assets()
	if Clock.weekday() == 5:
		_plan_event()
	_paper()
	main.law.daily()


func _adjacent(a: int, b: int) -> bool:
	if a / Street.PER_SIDE == b / Street.PER_SIDE:
		return absi(a - b) == 1
	return a % Street.PER_SIDE == b % Street.PER_SIDE


func _weather() -> void:
	rain_from = -1.0
	if _rng.randf() < 0.3:
		rain_from = _rng.randf_range(0.0, 20.0)
		rain_to = rain_from + _rng.randf_range(2.0, 7.0)


func heard(_pos: Vector3, _radius: float, _kind: String) -> void:
	pass


## Saturday: one household has the street round at noon.
func _plan_event() -> void:
	var hosts: Array[House] = []
	for h: House in main.street.houses:
		if h != main.street.home and not h.residents.is_empty() and not (h.residents[0] as Neighbour).d.agent and (h.residents[0] as Neighbour).state != "dead":
			hosts.append(h)
	if hosts.is_empty():
		return
	var host: House = hosts[_rng.randi() % hosts.size()]
	event_host = host.index
	event_from = Clock.minutes + Clock.until(12.0)
	event_to = event_from + 180.0
	_attended = 0.0
	var s := Street.lot_side(host.index)
	for n: Neighbour in main.neighbours:
		n.event_from = event_from + _rng.randf_range(0.0, 25.0)
		n.event_to = event_to - _rng.randf_range(0.0, 30.0)
		n.event_spot = Vector3(Street.lot_x(host.index) + _rng.randf_range(4.0, 16.0), 0, s * _rng.randf_range(24.0, 30.0))
	Game.note("The %s family are having the whole street round for a barbecue at noon today." % host.family)


## Recruited neighbours bring papers out, and may lose their nerve when the street is hot.
func _assets() -> void:
	for n: Neighbour in main.neighbours:
		if not n.asset or n.state == "dead":
			continue
		if Game.heat > 55.0 and _rng.randf() < 0.15:
			n.asset = false
			main.law.blown = true
			main.law.arrive_at = Clock.minutes + 30.0
			Game.note("%s has lost their nerve and gone to the Bureau. They are coming for you." % n.full_name())
		elif int(n.d.clearance) > 0:
			Game.intel += 3 * int(n.d.clearance)
			Game.note("%s left papers for you. Intelligence +%d." % [n.d.first, 3 * int(n.d.clearance)])


## The morning paper lands in your mailbox: yesterday's trouble and today's weather.
func _paper() -> void:
	var lines: Array[String] = []
	var since := "%s " % Clock.DAY_NAMES[(Clock.weekday() + 6) % 7]
	for j in Game.journal:
		if j.begins_with(since) and ("police" in j or "missing" in j or "dead" in j or "break-in" in j or "found" in j):
			lines.append(j.get_slice(" — ", 1))
	var text := ""
	if lines.is_empty():
		text = "[b]%s[/b]\n\n" % FILLER[_rng.randi() % FILLER.size()]
	else:
		text = "[b]TROUBLE ON MAPLE STREET[/b]\n%s\n\n" % "\n".join(lines.slice(0, 3))
	if rain_from >= 0.0:
		text += "Weather: rain from about %s until %s." % [hhmm(rain_from), hhmm(rain_to)]
	else:
		text += "Weather: dry and clear."
	if Clock.weekday() == 4:
		text += "\n\nSocial notes: a neighbourhood barbecue is planned for Saturday noon."
	for c in main.street.outdoor:
		if c.house == main.street.home and c.kind == "mailbox":
			for it: Dictionary in c.items.duplicate():
				if it.id == "paper":
					c.items.erase(it)
			c.items.append({"id": "paper", "name": "The Morning Courier", "contraband": false, "text": text})


func car() -> Node3D:
	return main.street.cars[main.street.cast.home]


func extra_options(found: Array, pos: Vector3) -> void:
	var it: Interact = main.interact
	for dog in dogs:
		var dist := dog.global_position.distance_to(pos)
		if dist < 8.0 and Game.has("treat") and Clock.minutes >= dog.quiet_until:
			found.append([dist * 0.1, it._opt("Throw the dog a biscuit", func() -> void: _feed(dog), 0.6)])
	var dist := car().global_position.distance_to(pos)
	if dist < 3.2:
		found.append([dist, it._opt("Open the car trunk", func() -> void: main.hud.open_container(trunk))])
		if body_in_trunk:
			found.append([dist, it._opt("Drive out of town and dump the body", func() -> void: _dump())])
		else:
			found.append([dist + 0.1, it._opt("Drive away for good", func() -> void: it._leave())])


func body_options(found: Array, pos: Vector3) -> void:
	if car().global_position.distance_to(pos) < 3.2 and body_in_trunk == null:
		found.append([0.05, main.interact._opt("Put the body in the trunk", func() -> void: _load_body(), 3.0, "carry_body")])


func _feed(dog: Dog) -> void:
	Game.take("treat")
	dog.feed()


func _load_body() -> void:
	var n: Neighbour = main.player.carrying
	main.player.carrying = null
	n.carried = false
	n.hidden_body = true
	n.visible = false
	if n.state != "dead":
		n.kill()
		n.died_at = Clock.minutes
	body_in_trunk = n
	Game.note("%s is in the trunk. Do not let anyone look in there." % n.full_name())


func _dump() -> void:
	var h := Clock.hour()
	if h >= 5.5 and h < 21.5:
		Game.incident_add(8.0, "You were seen driving out toward the quarry in the middle of the day.")
	body_in_trunk = null
	Game.fatigue = minf(100.0, Game.fatigue + 12.0)
	main.skip(120.0)
	Game.note("Two hours out and back. The quarry keeps its secrets.")
