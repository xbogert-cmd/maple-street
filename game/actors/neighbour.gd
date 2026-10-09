class_name Neighbour
extends Walker
## A resident of the street: keeps a daily routine, watches, remembers and reports.

signal raised_alarm(who: Neighbour)
signal saw_everything(who: Neighbour)   # the counter-agent, who needs no telephone

const KO_MINUTES := 150.0

var d: Dictionary                # the person from Cast
var house: House
var player: Player
var car: Node3D                  # set for the household's driver
var state := "home"              # home, leaving, away, returning, sleep, ko, dead, alarm, event
var suspicion := 0.0
var memory: Array[String] = []   # what they think they know about you
var notice := 0.0                # 0..1 while they work out what they are looking at
var recognised := false          # got a clear look at you doing something serious
var asset := false               # turned: works for you now
var met := false
var alert := false               # household knows something is wrong (burglary)
var leave_at := 0.0
var back_at := 0.0
var ko_until := 0.0
var alarm_text := ""
var carried := false             # body being carried by the player
var hidden_body := false
var found := false               # someone has come across them lying there
var died_at := -1.0
var missing_reported := false
var event_spot := Vector3.ZERO   # where to stand during a street event
var event_from := -1.0
var event_to := -1.0
var watching := false            # counter-agent only: out at night keeping an eye on you
var watch_spot := Vector3.ZERO

var _seen: Dictionary = {}       # "kind|day" already counted
var _think := 0.0
var _next_activity := 0.0
var _look_at := Vector3.ZERO
var _look_time := 0.0
var _bubble: Label3D
var _name: Label3D
var bubble_on := true
var _dial := 0.0
var _rng := RandomNumberGenerator.new()


func setup(person: Dictionary, h: House, s: Street, p: Player) -> void:
	d = person
	house = h
	street = s
	player = p
	_rng.seed = int(s.cast.seed) * 31 + int(person.id)
	make_figure(person)
	_bubble = Build.label(self, "", Vector3(0, 2.5 * float(person.scale), 0), 96)
	_name = Build.label(self, full_name(), Vector3(0, 2.05 * float(person.scale), 0), 30)
	_name.modulate = Color(0.95, 0.93, 0.85, 0.9)
	roll_day()


func full_name() -> String:
	return "%s %s" % [d.first, d.last]


## Today's hours: a little variance, and sometimes home early.
func roll_day() -> void:
	leave_at = float(d.leave) + _rng.randf_range(-0.15, 0.2)
	back_at = float(d.back) + _rng.randf_range(-0.2, 0.3)
	if d.job in ["plant", "town"] and _rng.randf() < 0.12:
		back_at -= _rng.randf_range(1.0, 4.0)
	if d.job == "agent":
		leave_at = _rng.randf_range(9.0, 13.0)
		back_at = leave_at + _rng.randf_range(2.0, 5.0)


func works_today() -> bool:
	match d.job:
		"retired":
			return false
		"home":
			return true
	return not Clock.is_weekend()


func plan() -> String:
	var h := Clock.hour()
	var sleep_h := fmod(float(d.sleep), 24.0)
	var asleep: bool = (h >= sleep_h or h < d.wake) if sleep_h > d.wake else (h >= sleep_h and h < d.wake)
	if watching and (h >= 21.0 or h < 2.0):
		return "watch"
	if asleep:
		return "sleep"
	if Clock.minutes >= event_from and Clock.minutes < event_to:
		return "event"
	if works_today() and h >= leave_at and h < back_at:
		return "away"
	return "home"


func is_away() -> bool:
	return state == "away"


func is_awake() -> bool:
	return state in ["home", "leaving", "returning", "alarm", "event", "watch"]


func is_out_cold() -> bool:
	return state == "ko" or state == "dead"


## Where this person leaves the map from and comes back to.
func _edge_spot() -> Vector3:
	if car:
		return car.position + Vector3(-1.6, 0, 0)
	return street.exit_west


## Put them where the routine says they should be, with no walking (start, time skips).
func snap() -> void:
	if state in ["ko", "dead", "alarm"]:
		return
	stop()
	figure.set_down(false)
	match plan():
		"away":
			_set_away(true)
		"sleep":
			_set_away(false)
			global_position = house.find_furn("bed").pos
			_sleep()
		"event":
			_set_away(false)
			state = "event"
			global_position = event_spot
		"watch":
			_set_away(false)
			state = "watch"
			global_position = watch_spot
		_:
			_set_away(false)
			state = "home"
			global_position = house.room_pos(["living", "kitchen", "study"][_rng.randi() % 3]) + Vector3(_rng.randf_range(-0.6, 0.6), 0, _rng.randf_range(-0.6, 0.6))
			_next_activity = Clock.minutes + _rng.randf_range(5, 30)


func _set_away(on: bool) -> void:
	state = "away" if on else "home"
	visible = not on
	if car:
		car.visible = not on
		car.process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT


func _sleep() -> void:
	state = "sleep"
	figure.set_down(true)
	figure.position.y = 0.75
	figure.rotation.y = 0.0


func _wake() -> void:
	figure.set_down(false)
	state = "home"
	_next_activity = Clock.minutes


func _process(delta: float) -> void:
	if state == "dead":
		return
	if state == "away":
		_think -= delta
		if _think <= 0.0:
			_think = 0.5
			if plan() != "away":
				come_home()
		return
	if state == "ko":
		if Clock.minutes >= ko_until and not carried:
			_come_round()
		return
	walk(delta)
	if _look_time > 0.0 and arrived:
		_look_time -= delta
		face(_look_at, delta)
	_think -= delta
	if _think <= 0.0:
		_think = 0.2
		_routine()
		if is_awake():
			_watch(0.2)
	_bubble.text = "" if not bubble_on else ("!" if state == "alarm" else ("?" if notice > 0.05 else ""))
	_bubble.modulate = Color("ff5a4a") if state == "alarm" else Color("ffd84a")
	_name.visible = bubble_on and state != "sleep" and global_position.distance_to(player.global_position) < 3.5


func _routine() -> void:
	var want := plan()
	match state:
		"home":
			if want == "away":
				state = "leaving"
				go_to(_edge_spot(), func() -> void: _set_away(true))
			elif want == "sleep":
				state = "returning"   # busy walking; not open to new activities
				go_to(house.find_furn("bed").pos, _sleep)
			elif want == "event" or want == "watch":
				state = want
				go_to(event_spot if want == "event" else watch_spot)
			elif Clock.minutes >= _next_activity and arrived:
				_activity()
		"sleep":
			if want != "sleep":
				_wake()
		"event", "watch":
			if want != state:
				walk_home()
			elif arrived:
				_look_time = 1.0
				if state == "watch":
					_look_at = street.home.portal("front").outside_pos
				elif _rng.randf() < 0.02:
					_look_at = event_spot + Vector3(_rng.randf_range(-4, 4), 0, _rng.randf_range(-4, 4))
		"alarm":
			if arrived:
				_dial += 0.2
				if _dial >= 4.0:
					state = "home"
					_dial = 0.0
					raised_alarm.emit(self)


func walk_home() -> void:
	state = "returning"
	go_to(house.portal("front").inside_pos, func() -> void:
		state = "home"
		_next_activity = Clock.minutes + 5.0)


func come_home() -> void:
	_set_away(false)
	global_position = _edge_spot()
	state = "returning"
	go_to(house.portal("front").inside_pos, func() -> void:
		state = "home"
		_next_activity = Clock.minutes + 5.0)


## Pick something to do around the house. Nosy people watch the street.
func _activity() -> void:
	_next_activity = Clock.minutes + _rng.randf_range(15.0, 45.0)
	var roll := _rng.randf()
	var day := Clock.daylight() > 0.4
	var front := house.portal("front")
	if d.job == "school" and day and roll < 0.7:
		# out on the sidewalk, up and down the street
		_next_activity = Clock.minutes + _rng.randf_range(8.0, 20.0)
		go_to(Vector3(clampf(global_position.x + _rng.randf_range(-35.0, 35.0), 2.0, 118.0), 0, Street.lot_side(house.index) * 5.0))
		return
	if roll < float(d.nosy) * 0.6:
		# stand at a front window or on the porch, looking out
		var spot := front.outside_pos if (day and _rng.randf() < 0.4) else _front_window()
		_look_at = spot + (front.outside_pos - front.inside_pos).normalized() * 20.0 + Vector3(_rng.randf_range(-15, 15), 0, 0)
		_look_time = 60.0
		go_to(spot)
	elif roll < 0.75 or not day:
		var rooms: Array[String] = ["living", "kitchen", "study", "bedroom"]
		go_to(house.room_pos(rooms[_rng.randi() % rooms.size()]) + Vector3(_rng.randf_range(-0.7, 0.7), 0, _rng.randf_range(-0.7, 0.7)))
	else:
		# potter in the yard
		var s := Street.lot_side(house.index)
		go_to(Vector3(Street.lot_x(house.index) + _rng.randf_range(3.0, 17.0), 0, s * _rng.randf_range(Street.FRONT + 14.0, Street.BACK - 2.0)))


func _front_window() -> Vector3:
	var front := house.portal("front")
	var best := front.inside_pos
	var best_d := 1e9
	for p in house.portals:
		if p.is_window:
			var dist := p.inside_pos.distance_to(front.inside_pos)
			if dist < best_d and absf(p.outside_pos.z) < absf(p.inside_pos.z):
				best_d = dist
				best = p.inside_pos
	return best


func _watch(dt: float) -> void:
	if global_position.distance_to(player.global_position) > 30.0 or not player.visible:
		notice = maxf(0.0, notice - dt * 0.5)
		return
	var ctx: Dictionary = Game.ctx
	if not can_see(player.global_position, ctx.get("light", 1.0), player.sneaking):
		notice = maxf(0.0, notice - dt * 0.35)
		return
	met = true
	var j := Rules.judge(ctx)
	if j.is_empty() or asset:
		notice = maxf(0.0, notice - dt * 0.5)
		return
	var dist := global_position.distance_to(player.global_position)
	var rate := clampf(1.5 - dist / 16.0, 0.3, 1.5) * (1.6 if j.severe else 0.8) * (1.5 if d.agent else 1.0)
	if notice <= 0.0:
		Sfx.play("notice", global_position)
	notice = minf(1.0, notice + dt * rate)
	if state != "alarm" and arrived:
		face(player.global_position)
	if notice >= 1.0:
		_witness(j, dist, ctx.get("light", 1.0))


func _witness(j: Dictionary, dist: float, light: float) -> void:
	var key := "%s|%d" % [j.kind, Clock.day()]
	if not _seen.has(key):
		_seen[key] = true
		add_suspicion(j.amount, j.text)
	if j.severe and state != "alarm":
		if light > 0.35 or dist < 6.0:
			recognised = true
		if d.job == "school":
			# a kid tells their parents; it counts for less, and nobody phones on a child's word alone
			for r: Neighbour in house.residents:
				if r != self and r.state != "dead":
					r.add_suspicion(j.amount * 0.5, "was told by their kid, who %s" % j.text)
			notice = 0.0
		elif d.agent and recognised:
			saw_everything.emit(self)
		else:
			alarm(j.text)


func add_suspicion(amount: float, text: String) -> void:
	suspicion = clampf(suspicion + amount, 0.0, 100.0)
	if text != "" and not memory.has(text):
		memory.append(text)
	Game.changed.emit()


## Head for the phone to call the police.
func alarm(text: String) -> void:
	if state in ["ko", "dead", "away"]:
		return
	if state == "sleep":
		figure.set_down(false)
	alarm_text = text
	state = "alarm"
	Sfx.play("alarm", global_position, 4.0)
	_dial = 0.0
	speed = 2.6
	Game.noise.emit(global_position, 14.0, "shout")
	go_to(house.find_furn("phone").pos + Vector3(0.6, 0, 0.4))


func hear(pos: Vector3, kind: String) -> void:
	if asset:
		return
	if state == "sleep":
		if kind in ["shout", "struggle", "glass"] or _rng.randf() < (0.5 if kind == "steps" else 0.2):
			_wake()
			_look_at = pos
			_look_time = 8.0
	elif state == "home" and kind != "shout":
		stop()
		_look_at = pos
		_look_time = 6.0
		_next_activity = Clock.minutes + 6.0
		if kind == "steps" and house.contains(pos):
			# someone is moving about in the house: go and see
			go_to(pos)
		elif kind in ["bark", "struggle", "glass", "lockpick", "steps"] and house.contains(global_position):
			# go and look out of the nearest window toward the noise
			var best := global_position
			var best_d := 1e9
			for p in house.portals:
				var dd := p.inside_pos.distance_to(pos)
				if dd < best_d:
					best_d = dd
					best = p.inside_pos
			go_to(best)


func knock_out() -> void:
	stop()
	state = "ko"
	Sfx.play("thud", global_position)
	speed = 1.5
	figure.set_down(true)
	figure.position.y = 0.2
	ko_until = Clock.minutes + KO_MINUTES
	notice = 0.0
	_bubble.text = ""


func kill() -> void:
	knock_out()
	state = "dead"


func _come_round() -> void:
	figure.set_down(false)
	state = "home"
	if recognised:
		alarm("was attacked by you")
	else:
		alert = true
		Game.incident_add(15.0, "%s was attacked by someone they did not see" % full_name())
		alarm("was attacked")
