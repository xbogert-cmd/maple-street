class_name Missions
extends Node
## Jobs from the Centre: photograph a document, borrow and copy one, or bug a phone.
## The current job lives in Game.mission: {type, n, target, name, family, lot, doc, stage, drop, reward, ...}.

const DOCS: Array[String] = ["Guidance test schedule", "Gyro tolerance tables", "Telemetry frequency list", "Contractor roster", "Range safety memo", "Engine burn data", "Security rota", "Wind tunnel report", "Fuel mixture notes", "Launch window calendar"]
const SPOT_FOR_CLEARANCE: Array[String] = ["desk", "desk", "cabinet", "cabinet"]

var main: Node
var next_at := 0.0     # clock minutes when the Centre next has a job
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = Game.run_seed + 555


func targets() -> Array[Neighbour]:
	var out: Array[Neighbour] = []
	for n: Neighbour in main.neighbours:
		if int(n.d.clearance) > 0 and n.state != "dead":
			out.append(n)
	return out


## Make the next job and put its document in the target's house.
func offer() -> Dictionary:
	var pool := targets()
	if pool.is_empty():
		return {}
	var n := Game.missions_done
	var type := "photo"
	if n >= 1:
		type = ["photo", "bug", "borrow"][_rng.randi() % 3]
	if n == 0:
		pool.sort_custom(func(a: Neighbour, b: Neighbour) -> bool: return int(a.d.clearance) < int(b.d.clearance))
	var who: Neighbour = pool[0] if n == 0 else pool[_rng.randi() % pool.size()]
	var c := int(who.d.clearance)
	var m := {
		"type": type, "n": n, "target": int(who.d.id), "name": who.full_name(), "family": who.d.last,
		"lot": who.house.index, "stage": "get", "drop": _rng.randi() % main.street.drops.size(),
		"reward": {"photo": 10 * c, "borrow": 18 * c, "bug": 15}[type], "doc": "", "spot": "", "returned": false, "dropped": false, "until": 0.0,
	}
	if type == "bug":
		m.stage = "collect"
		Game.pickup = {"drop": m.drop, "items": ["bug"], "money": 0}
	else:
		m.doc = DOCS[_rng.randi() % DOCS.size()]
		m.spot = SPOT_FOR_CLEARANCE[c]
		var f: Dictionary = who.house.find_furn(m.spot)
		f.items.append({"id": "doc", "name": m.doc + " (SECRET)", "contraband": true, "mission": n})
	Game.mission = m
	Game.changed.emit()
	return m


func brief() -> String:
	var m := Game.mission
	if m.is_empty():
		return "Nothing but static and a numbers station counting in Spanish."
	var drop: String = main.street.drops[m.drop].name
	var spot := {"desk": "the desk", "cabinet": "the filing cabinet", "safe": "a safe"}
	match m.type:
		"photo":
			return "[b]%s[/b] keeps the [b]%s[/b] at home, in %s. Photograph it and leave it exactly as you found it. Develop the film, then leave it at %s in the park." % [m.name, m.doc, spot[m.spot], drop]
		"borrow":
			return "The [b]%s[/b] is too long to photograph in place. [b]%s[/b] has it in %s. Take it, copy it at your bench, and put it back before it is missed. Leave the copy at %s in the park." % [m.doc, m.name, spot[m.spot], drop]
	return "We want to hear what is said in the [b]%s[/b] house. A listening device is waiting for you at %s in the park. Fit it to their telephone." % [m.family, drop]


## One line for the HUD.
func objective() -> String:
	var m := Game.mission
	if m.is_empty():
		if Clock.minutes >= next_at:
			return "Listen to the radio at home between 7 PM and 1 AM"
		return "No orders. Keep up appearances"
	var drop: String = main.street.drops[m.drop].name
	match m.stage:
		"collect":
			return "Collect the device from %s in the park" % drop
		"get":
			match m.type:
				"photo":
					return "Photograph the %s in the %s house" % [m.doc, m.family]
				"borrow":
					return "Take the %s from the %s house" % [m.doc, m.family]
			return "Fit the device to the %s telephone" % m.family
		"process":
			return "Develop the film at your bench" if m.type == "photo" else "Copy the document at your bench"
		"deliver":
			if m.type == "borrow" and not m.returned:
				return "Put the %s back in the %s house%s" % [m.doc, m.family, "" if m.dropped else ", and leave the copy at " + drop]
			return "Leave the %s at %s in the park" % ["microdot" if m.type == "photo" else "copy", drop]
		"wait":
			return "The device is in. Wait for the Centre to confirm"
	return ""


func photographed() -> void:
	Sfx.play("shutter")
	Game.give(Game.item("film", {"mission": Game.mission.n}))
	Game.mission.stage = "process"
	Game.note("Photographed the %s." % Game.mission.doc)


func took_doc() -> void:
	if Game.mission.get("stage", "") == "get" and Game.mission.type == "borrow":
		Game.mission.stage = "process"
		Game.changed.emit()


func returned_doc() -> void:
	var m := Game.mission
	if m.get("type", "") == "borrow" and m.stage == "deliver":
		m.returned = true
		Game.note("The %s is back where it belongs." % m.doc)
		_check_done()


## At the darkroom bench. Returns what happened, or "" if there was nothing to do.
func process() -> String:
	var m := Game.mission
	if m.get("stage", "") != "process":
		return ""
	if m.type == "photo":
		Game.take("film")
		Game.give(Game.item("microdot"))
	else:
		Game.give(Game.item("copy"))
	m.stage = "deliver"
	Game.changed.emit()
	return "Film developed and reduced to a microdot." if m.type == "photo" else "Document copied."


func planted_bug(f: Dictionary) -> void:
	f.bug = true
	Game.take("bug")
	var h: House = f.house
	var m := Game.mission
	if m.get("type", "") == "bug" and m.stage == "get" and m.lot == h.index:
		m.stage = "wait"
		m.until = Clock.minutes + 20.0 * 60.0
	Game.note("The device is fitted to the %s telephone. Listen in from your radio set." % h.family)


## At your own set: what the taps on the street are picking up.
func listen_to_taps() -> String:
	var lines: Array[String] = []
	for h: House in main.street.houses:
		var phone: Dictionary = h.find_furn("phone")
		if phone.is_empty() or not phone.bug:
			continue
		var home_now: Array[String] = []
		for n: Neighbour in h.residents:
			if n.state == "dead":
				continue
			var id := int(n.d.id)
			if not n.is_away():
				home_now.append("%s (%s)" % [n.d.first, "asleep" if n.state == "sleep" else "up"])
			if float(n.d.leave) > 0.0 and not Game.knows(id, "hours"):
				Game.learn(id, "hours")
				lines.append("%s talks about being out %s to %s." % [n.d.first, Life.hhmm(n.d.leave), Life.hhmm(n.d.back)])
			if n.d.secret != "" and not Game.knows(id, "secret") and _rng.randf() < 0.4:
				Game.learn(id, "secret")
				lines.append("[color=#e8a23a]A hushed call: %s %s.[/color]" % [n.full_name(), Life.SECRET_TEXT[n.d.secret]])
			if n.d.agent and not Game.knows(id, "agent") and _rng.randf() < 0.4:
				Game.learn(id, "agent")
				lines.append("[color=#e2574c]%s reads a report down the line to a field office. He is Bureau.[/color]" % n.full_name())
		lines.append("[b]%s house[/b]: %s." % [h.family, "nobody home" if home_now.is_empty() else "home now: " + ", ".join(home_now)])
	if lines.is_empty():
		return "You have no devices in place. The Centre leaves one at a dead drop after each completed job."
	return "\n".join(lines)


## Leaving the goods at the dead drop. Returns true if this drop wanted something we had.
func drop(i: int) -> bool:
	var m := Game.mission
	if m.get("stage", "") != "deliver" or m.drop != i or m.dropped:
		return false
	var id := "microdot" if m.type == "photo" else "copy"
	if not Game.has(id):
		return false
	Game.take(id)
	m.dropped = true
	Game.money += 40 + 10 * int(m.reward / 10)
	Game.note("Left the %s at the drop. An envelope of cash was waiting." % Game.ITEMS[id][0].to_lower())
	_check_done()
	return true


func _check_done() -> void:
	var m := Game.mission
	if m.dropped and (m.type != "borrow" or m.returned):
		_complete()


func _complete() -> void:
	var m := Game.mission
	Game.intel += int(m.reward)
	Game.missions_done += 1
	Game.mission = {}
	next_at = Clock.minutes + Clock.until(19.0)
	Game.note("Job done. Intelligence sent home: %d." % Game.intel)
	if Game.pickup.is_empty():
		# the Centre rewards good work with a spare listening device
		var i: int = _rng.randi() % main.street.drops.size()
		Game.pickup = {"drop": i, "items": ["bug"], "money": 0}
		Game.note("The Centre has left something for you at %s in the park." % main.street.drops[i].name)


func _process(_delta: float) -> void:
	var m := Game.mission
	if m.get("stage", "") == "wait" and Clock.minutes >= m.until:
		# a day of listening: the household's hours and secrets come through
		for n: Neighbour in main.street.houses[m.lot].residents:
			Game.learn(int(n.d.id), "hours")
			if n.d.secret != "":
				Game.learn(int(n.d.id), "secret")
		Game.note("A day of tape from the %s house. Their routines are in your notebook." % m.family)
		_complete()
