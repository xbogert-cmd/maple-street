class_name Interact
extends Node
## What the player can do right now (E, R, F prompts) and the timed actions those start.

const POND := Vector3(150, 0, -18)

var main: Node
var what := ""                       # "mail" or "trash" while snooping
var act := ""                        # how the current action looks to a witness (Rules.judge)
var options: Array[Dictionary] = []  # {key, label, time, act, noise, radius, done}
var busy: Dictionary = {}            # the action in progress, with "left" seconds
var _noise_t := 0.0
var _chatted: Dictionary = {}        # "id|day"


func _process(delta: float) -> void:
	var p: Player = main.player
	if p.carrying:
		p.carrying.global_position = p.global_position + Vector3(0, 1.1, 0)
	if Game.ended != "" or main.hud.modal():
		options = []
		_cancel()
		return
	if not busy.is_empty():
		options = []
		if p.speed_now > 0.1:
			_cancel()
			return
		busy.left -= delta
		_noise_t -= delta
		if busy.noise != "" and _noise_t <= 0.0:
			_noise_t = 1.0
			Game.noise.emit(p.global_position, busy.radius, busy.noise)
		if busy.left <= 0.0:
			var done: Callable = busy.done
			busy = {}
			act = ""
			done.call()
		return
	options = _build()


func _cancel() -> void:
	busy = {}
	act = ""


func _unhandled_key_input(e: InputEvent) -> void:
	if not e.is_pressed() or e.is_echo() or not busy.is_empty():
		return
	var k := (e as InputEventKey).physical_keycode
	var key := "E" if k == KEY_E else ("R" if k == KEY_R else ("T" if k == KEY_T else ("F" if k == KEY_F else "")))
	for o in options:
		if o.key == key:
			run(o)
			return


func run(o: Dictionary) -> void:
	if not o.done.is_valid():
		return
	if o.time <= 0.0:
		o.done.call()
		return
	busy = o.duplicate()
	busy.left = o.time * (1.5 if Game.fatigue > 80.0 else 1.0)
	busy.total = busy.left
	act = o.act
	_noise_t = 0.3


func _opt(label: String, done: Callable, time := 0.0, how := "", noise := "", radius := 0.0, violent := false) -> Dictionary:
	return {"key": "F" if violent else "", "label": label, "time": time, "act": how, "noise": noise, "radius": radius, "done": done}


func _build() -> Array[Dictionary]:
	var p: Player = main.player
	var st: Street = main.street
	var pos := p.global_position
	var found: Array = []   # [distance, option]
	if main.shift.active:
		return _keys(main.shift.options(pos))
	if p.carrying:
		var body := p.carrying
		found.append([0.0, _opt("Put %s down" % body.d.first, func() -> void: _put_down())])
		if pos.distance_to(POND) < 8.0:
			found.append([0.1, _opt("Sink the body in the pond", func() -> void: _sink(), 6.0, "carry_body")])
		main.life.body_options(found, pos)
		return _keys(found)
	# people
	for n: Neighbour in main.neighbours:
		var dist := n.global_position.distance_to(pos)
		if not n.visible or dist > 1.6 or n.hidden_body:
			continue
		if n.is_out_cold():
			found.append([dist, _opt("Carry %s" % n.d.first, func() -> void: _carry(n))])
			if n.state == "ko":
				found.append([dist, _opt("Kill %s" % n.d.first, func() -> void: _kill(n), 3.0, "attack", "", 0.0, true)])
		elif n.d.job != "school":
			if n.state == "sleep":
				found.append([dist, _opt("Knock %s out" % n.d.first, func() -> void: _takedown(n, true), 1.0, "attack", "", 0.0, true)])
			else:
				if n.state == "home" or n.state == "event":
					found.append([dist, _opt("Chat with %s" % n.d.first, func() -> void: _chat(n), 3.0)])
					if Game.knows(int(n.d.id), "secret") and not n.asset:
						found.append([dist + 0.01, _opt("Lean on %s" % n.d.first, func() -> void: _lean(n), 4.0)])
				var behind := n.facing().dot((pos - n.global_position).normalized()) < 0.0
				found.append([dist, _opt("Knock %s out" % n.d.first, func() -> void: _takedown(n, behind), 0.8, "attack", "" if behind else "struggle", 12.0, true)])
	# doors and windows
	for h in st.houses:
		if absf(h.global_position.x - pos.x) > 40.0:
			continue
		for pt in h.portals:
			var dist := pt.global_position.distance_to(pos)
			if dist < 1.5:
				for o in _portal(pt, h, pos):
					found.append([dist, o])
	# containers and furniture
	var here := st.house_at(pos)
	var list: Array[Dictionary] = st.outdoor.duplicate()
	if here:
		list = here.furn
	for f in list:
		var dist: float = (f.pos as Vector3).distance_to(pos)
		var reach := 1.7 + maxf(f.node.mesh.size.x, f.node.mesh.size.z) * 0.3
		if dist < reach:
			for o in _furniture(f, here):
				found.append([dist, o])
	# places
	if pos.distance_to(st.bus_stop) < 2.6:
		var h := Clock.hour()
		if not Clock.is_weekend() and h >= 6.5 and h < 10.0 and not Game.worked_today and not Game.fired:
			found.append([0.5, _opt("Ride the plant bus to work", func() -> void: main.shift.start())])
		found.append([0.9, _opt("Leave town for good", func() -> void: _leave())])
	if pos.distance_to(st.shop_door) < 2.4:
		var h := Clock.hour()
		if h >= 8.0 and h < 20.0:
			found.append([0.5, _opt("Go into Miller's Market", func() -> void: main.hud.open_shop())])
		else:
			found.append([0.5, _opt("Miller's Market is closed (8 AM to 8 PM)", Callable())])
	for i in st.drops.size():
		var dist: float = (st.drops[i].pos as Vector3).distance_to(pos)
		if dist > 1.8:
			continue
		if Game.pickup.get("drop", -1) == i:
			found.append([dist, _opt("Collect the package", func() -> void: _collect(), 2.0)])
		var m := Game.mission
		if m.get("stage", "") == "deliver" and m.drop == i and not m.dropped and Game.has("microdot" if m.type == "photo" else "copy"):
			found.append([dist, _opt("Leave it at the drop", func() -> void: main.missions.drop(i), 2.0)])
	main.life.extra_options(found, pos)
	return _keys(found)


## Nearest first; E then R for ordinary actions, F for violence.
func _keys(found: Array) -> Array[Dictionary]:
	found.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var out: Array[Dictionary] = []
	var free: Array[String] = ["E", "R", "T"]
	var f_used := false
	for pair: Array in found:
		var o: Dictionary = pair[1]
		if o.key == "F":
			if f_used:
				continue
			f_used = true
		elif free.is_empty():
			continue
		else:
			o.key = free.pop_front()
		out.append(o)
	return out


func _portal(pt: Portal, h: House, pos: Vector3) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var mine: bool = h == main.street.home
	var picks := Game.has("lockpicks")
	if pt.is_window:
		if mine:
			return out
		var outside := pos.distance_to(pt.outside_pos) < pos.distance_to(pt.inside_pos)
		if not outside:
			out.append(_opt("Climb out of the window", func() -> void: main.player.global_position = pt.outside_pos, 2.0))
		elif not pt.locked:
			out.append(_opt("Climb in through the window", func() -> void: main.player.global_position = pt.inside_pos, 2.5, "window"))
		elif picks:
			out.append(_opt("Force the window latch", func() -> void: _forced(pt), 9.0 / (1.0 + 0.3 * Game.level("locks")), "window", "lockpick", 5.0))
		else:
			out.append(_opt("Window is latched (needs lockpicks)", Callable()))
		return out
	var name := pt.label()
	if pt.open:
		out.append(_opt("Close the %s" % name.to_lower(), func() -> void: pt.set_open(false)))
	elif mine or not pt.locked:
		out.append(_opt("Open the %s" % name.to_lower(), func() -> void: pt.set_open(true)))
		if not mine and (picks or pt.key_copied):
			out.append(_opt("Lock it again", func() -> void: _relock(pt), 0.5 if pt.key_copied else 3.0, "lock"))
		if not mine and Game.has("clay"):
			out.append(_opt("Take an impression of the lock", func() -> void: _mould(pt, h), 5.0, "lock"))
	elif pt.key_copied:
		out.append(_opt("Unlock the %s with your copy" % name.to_lower(), func() -> void: _unlocked(pt, false), 0.5, "lock"))
	elif picks:
		out.append(_opt("Pick the %s lock" % name.to_lower(), func() -> void: _unlocked(pt, true), 8.0 / (1.0 + 0.3 * Game.level("locks")), "lock", "lockpick", 4.0))
	else:
		out.append(_opt("%s is locked (needs lockpicks)" % name, Callable()))
	return out


func _unlocked(pt: Portal, picked: bool) -> void:
	pt.locked = false
	pt.picked = true
	if picked:
		Game.train("locks", 4.0)
	Game.say("The lock gives.")


func _relock(pt: Portal) -> void:
	pt.locked = true
	pt.picked = false
	Game.say("Locked, as you found it.")


func _forced(pt: Portal) -> void:
	pt.locked = false
	pt.forced = true
	Game.train("locks", 3.0)
	Game.say("The latch gives. It will show marks.")


func _mould(pt: Portal, h: House) -> void:
	Game.take("clay")
	Game.give(Game.item("mould", {"name": "Key impression (%s %s)" % [h.family, pt.label().to_lower()], "lot": h.index, "tag": pt.tag}))
	Game.say("You have the shape of the key. Cut a copy at your bench.")


func _furniture(f: Dictionary, here: House) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var mine: bool = f.house == main.street.home
	var lvl := Game.level("search")
	if f.name != "":
		if f.locked:
			if Game.has("lockpicks"):
				out.append(_opt("Crack the %s" % String(f.name).to_lower(), func() -> void: _crack(f), 15.0 / (1.0 + 0.3 * Game.level("locks")), "search", "lockpick", 3.0))
			else:
				out.append(_opt("%s is locked (needs lockpicks)" % f.name, Callable()))
		else:
			var how := ""
			if here == null and not mine:
				how = "snoop"
				what = "mail" if f.kind == "mailbox" else "trash"
			out.append(_opt("Search the %s" % String(f.name).to_lower(), func() -> void: main.hud.open_container(f), 0.0 if mine else 2.0 / (1.0 + 0.25 * lvl), how))
	var m := Game.mission
	match f.kind:
		"phone":
			if not mine and Game.has("bug") and not f.bug and f.house != main.street.plant:
				out.append(_opt("Fit the listening device", func() -> void: main.missions.planted_bug(f), 8.0, "search"))
		"radio":
			if Game.radio_hidden:
				out.append(_opt("Take the radio out of hiding", func() -> void: _radio_hide(false), 3.0))
			else:
				out.append(_opt("Listen for the Centre", func() -> void: _listen(), 4.0))
				out.append(_opt("Hide the radio", func() -> void: _radio_hide(true), 3.0))
				out.append(_opt("Listen to the telephone taps", func() -> void: _taps(), 4.0))
		"darkroom":
			if m.get("stage", "") == "process":
				out.append(_opt("Work at the bench", func() -> void: _bench(), 6.0))
			elif Game.has("mould"):
				out.append(_opt("Cut a key from the impression", func() -> void: _cut_key(), 6.0))
		"bed":
			if mine:
				out.append(_opt("Sleep", func() -> void: main.life.sleep(), 2.0))
		"counter":
			if mine:
				out.append(_opt("Burn evidence in the sink", func() -> void: main.hud.open_burn()))
	return out


func _crack(f: Dictionary) -> void:
	f.locked = false
	f.disturbed = true
	Game.train("locks", 6.0)
	Game.say("It opens.")


func _bench() -> void:
	Clock.advance(20.0)
	Game.note(main.missions.process())


func _radio_hide(hide: bool) -> void:
	Game.radio_hidden = hide
	main.street.home.find_furn("radio").node.visible = not hide
	Game.say("The set is back behind the panel." if hide else "The shortwave set is out.")


func _listen() -> void:
	var h := Clock.hour()
	if not (h >= 19.0 or h < 1.0):
		Game.say("Nothing but static. The Centre transmits between 7 PM and 1 AM.")
		return
	if not Game.has("codebook") and not _in_stash("codebook"):
		Game.say("Without the one-time pad the numbers mean nothing.")
		return
	Clock.advance(5.0)
	if Game.mission.is_empty() and Clock.minutes >= main.missions.next_at:
		main.missions.offer()
	main.hud.open_text("From the Centre", main.missions.brief(), [["Understood", Callable()]])


func _taps() -> void:
	Clock.advance(15.0)
	main.hud.open_text("On the taps", main.missions.listen_to_taps(), [["Headphones off", Callable()]])


func _in_stash(id: String) -> bool:
	for it: Dictionary in main.street.home.find_furn("stash").items:
		if it.id == id:
			return true
	return false


func _cut_key() -> void:
	var mould := Game.take("mould")
	var pt: Portal = main.street.houses[mould.lot].portal(mould.tag)
	pt.key_copied = true
	Game.note("You now have a key to the %s %s." % [main.street.houses[mould.lot].family, pt.label().to_lower()])


func _chat(n: Neighbour) -> void:
	var key := "%d|%d" % [n.d.id, Clock.day()]
	Clock.advance(10.0)
	n.met = true
	if n.suspicion > 60.0:
		Game.say("%s has nothing to say to you." % n.d.first)
		return
	if _chatted.has(key):
		Game.say("You have already passed the time of day with %s." % n.d.first)
		return
	_chatted[key] = true
	n.suspicion = maxf(0.0, n.suspicion - (3.0 + Game.level("talk")))
	Game.train("talk", 2.0)
	if randf() < 0.3 + 0.1 * Game.level("talk") and not Game.knows(int(n.d.id), "hours") and float(n.d.leave) > 0.0:
		Game.learn(int(n.d.id), "hours")
		Game.note("%s mentions being out from %s to %s most days." % [n.d.first, Life.hhmm(n.d.leave), Life.hhmm(n.d.back)])
	else:
		Game.say("You talk about the weather and the ball game. %s seems easier with you." % n.d.first)


## Use a known secret to recruit a neighbour.
func _lean(n: Neighbour) -> void:
	var chance := 0.5 + 0.08 * Game.level("talk") - n.suspicion / 200.0
	if n.d.agent:
		chance = 0.0
	if randf() < chance:
		n.asset = true
		n.suspicion = 0.0
		Game.note("%s understands the arrangement. %s" % [n.full_name(), "Papers will come out of the plant for you." if int(n.d.clearance) > 0 else "They will keep an eye out for you."])
	else:
		n.add_suspicion(35.0, "knows you tried to blackmail them")
		if randf() < 0.35 or n.d.agent:
			n.recognised = true
			n.alarm("was threatened by you")
			Game.say("%s goes white, then heads for the telephone." % n.d.first)
		else:
			Game.say("%s tells you to get off the property." % n.d.first)


func _takedown(n: Neighbour, quiet: bool) -> void:
	if not quiet:
		n.recognised = true
		Game.noise.emit(n.global_position, 12.0, "struggle")
	n.knock_out()
	Game.say("%s goes down%s." % [n.d.first, " without a sound" if quiet else " after a struggle. They saw your face"])


func _kill(n: Neighbour) -> void:
	n.kill()
	n.died_at = Clock.minutes
	Game.note("%s is dead. The body cannot be found here." % n.full_name())


func _carry(n: Neighbour) -> void:
	n.carried = true
	main.player.carrying = n


func _put_down() -> void:
	var n: Neighbour = main.player.carrying
	n.carried = false
	n.global_position = main.player.global_position + main.player.figure.basis.z * 0.8
	main.player.carrying = null


func _sink() -> void:
	var n: Neighbour = main.player.carrying
	main.player.carrying = null
	n.carried = false
	n.hidden_body = true
	n.visible = false
	if n.state != "dead":
		n.kill()
		n.died_at = Clock.minutes
	Game.note("The pond closes over %s." % n.full_name())


func _collect() -> void:
	for id: String in Game.pickup.items:
		Game.give(Game.item(id))
	Game.money += int(Game.pickup.get("money", 0))
	Game.pickup = {}
	if Game.mission.get("stage", "") == "collect":
		Game.mission.stage = "get"
	Game.note("Package collected from the drop.")


func _leave() -> void:
	main.hud.open_text("Leave town", "Walk away from the street, the job and the name you have been using. This ends the game.", [
		["Stay", Callable()],
		["Leave for good", func() -> void: Game.end("extracted", "You left on the evening bus and were never seen on Maple Street again.")],
	])
