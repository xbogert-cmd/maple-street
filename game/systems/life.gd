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
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = Game.run_seed + 2024


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


func furnish_home() -> void:
	var home: House = main.street.home
	for f: Array in home.tpl.home:
		home.add_furniture(f[0], Vector2(f[1], f[2]), f[3])
	home.find_furn("radio").node.visible = not Game.radio_hidden


func extra_options(_found: Array, _pos: Vector3) -> void:
	pass


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
