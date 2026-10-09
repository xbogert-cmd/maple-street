class_name Hud
extends CanvasLayer
## All 2D interface: status, objective, prompts, toasts and the one modal window used for
## containers, the notebook, the shop, radio messages and menus.

const INK := Color("e9e3d2")
const DIM := Color("a8a290")
const WARN := Color("e8a23a")
const BAD := Color("e2574c")
const PANEL := Color(0.07, 0.08, 0.1, 0.88)

var main: Node
var _status: Label
var _needs: Label
var _mood: Label
var _objective: Label
var _eye: Label
var _prompts: VBoxContainer
var _bar: ProgressBar
var _toasts: VBoxContainer
var _window: PanelContainer
var _title: Label
var _body: RichTextLabel
var _rows: VBoxContainer
var _buttons: HBoxContainer
var _shade: ColorRect
var _rain: ColorRect
var _on_close: Callable
var _pauses := false      # the open window stops the clock
var _refresh: Callable    # rebuilds the open window when the game state changes


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_rain = ColorRect.new()
	_rain.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rain.color = Color(0.55, 0.62, 0.72, 0.0)
	_rain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_rain)

	var tl := _box(root, Control.PRESET_TOP_LEFT, Vector2(16, 14))
	_status = _label(tl, 20, INK)
	_needs = _label(tl, 15, DIM)
	_eye = _label(tl, 15, DIM)

	var tr := _box(root, Control.PRESET_TOP_RIGHT, Vector2(-16, 14))
	tr.alignment = BoxContainer.ALIGNMENT_BEGIN
	tr.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tr.custom_minimum_size.x = 380
	_mood = _label(tr, 18, INK)
	_mood.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_objective = _label(tr, 15, DIM)
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var bc := _box(root, Control.PRESET_CENTER_BOTTOM, Vector2(0, -24))
	bc.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bc.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bc.alignment = BoxContainer.ALIGNMENT_END
	_prompts = VBoxContainer.new()
	bc.add_child(_prompts)
	_label(_prompts, 18, INK).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(320, 14)
	_bar.show_percentage = false
	_bar.visible = false
	bc.add_child(_bar)

	_toasts = _box(root, Control.PRESET_BOTTOM_LEFT, Vector2(16, -20))
	_toasts.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toasts.alignment = BoxContainer.ALIGNMENT_END
	_toasts.custom_minimum_size.x = 460

	_shade = ColorRect.new()
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.color = Color(0, 0, 0, 0.45)
	_shade.visible = false
	root.add_child(_shade)
	_window = PanelContainer.new()
	_window.set_anchors_preset(Control.PRESET_CENTER)
	_window.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_window.grow_vertical = Control.GROW_DIRECTION_BOTH
	_window.custom_minimum_size = Vector2(620, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL
	sb.border_color = Color("5a5646")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(18)
	_window.add_theme_stylebox_override("panel", sb)
	_window.visible = false
	root.add_child(_window)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_window.add_child(v)
	_title = _label(v, 24, INK)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.custom_minimum_size.x = 580
	_body.add_theme_font_size_override("normal_font_size", 16)
	_body.add_theme_font_size_override("bold_font_size", 16)
	_body.add_theme_color_override("default_color", INK)
	v.add_child(_body)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(580, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)
	_rows.set_meta("scroll", scroll)
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_END
	_buttons.add_theme_constant_override("separation", 10)
	v.add_child(_buttons)

	Game.toast.connect(_toast)
	Game.run_ended.connect(_ended)
	Game.changed.connect(func() -> void:
		if _window.visible and _refresh.is_valid():
			_refresh.call())
	if not Game.started and not Game.args.has("demo") and not Game.args.has("shot"):
		open_menu()


func _box(parent: Control, preset: int, offset: Vector2) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(b)
	b.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE)
	b.offset_left += offset.x
	b.offset_right += offset.x
	b.offset_top += offset.y
	b.offset_bottom += offset.y
	return b


func _label(parent: Control, size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func modal() -> bool:
	return _window.visible


func _process(_delta: float) -> void:
	var p: Player = main.player
	p.frozen = modal()
	_status.text = "%s   Day %d      $%d      Intel %d" % [Clock.stamp(), Clock.day(), Game.money, Game.intel]
	var bits: Array[String] = []
	if Game.hunger > 60.0:
		bits.append("Hungry" if Game.hunger < 85.0 else "Starving")
	if Game.fatigue > 60.0:
		bits.append("Tired" if Game.fatigue < 85.0 else "Exhausted")
	if p.sneaking:
		bits.append("Sneaking (C)")
	if main.life.rain > 0.5:
		bits.append("Raining")
	_needs.text = "   ".join(bits)
	var worst := 0.0
	var alarm := false
	for n: Neighbour in main.neighbours:
		worst = maxf(worst, n.notice)
		alarm = alarm or n.state == "alarm"
	_eye.text = "SOMEONE IS GOING FOR THE PHONE" if alarm else ("Being watched" if worst > 0.05 else "")
	_eye.add_theme_color_override("font_color", BAD if alarm else WARN)
	_mood.text = "Street: %s" % Game.mood()
	_mood.add_theme_color_override("font_color", INK if Game.heat < Rules.HEAT_INVESTIGATOR else (WARN if Game.heat < Rules.HEAT_SEARCH else BAD))
	var obj: String = main.missions.objective()
	if main.law.blown:
		obj = "They know. Reach the bus stop and leave town"
	if main.law.scramble >= 0.0:
		obj = "SEARCH IN %d SECONDS. Hide or burn everything" % int(main.law.scramble)
	_objective.text = obj
	_rain.color.a = main.life.rain * 0.12
	# prompts
	var it: Interact = main.interact
	var lines: Array[String] = []
	for o in it.options:
		lines.append("[%s]  %s" % [o.key, o.label] if o.done.is_valid() else o.label)
	while _prompts.get_child_count() < lines.size():
		var l := _label(_prompts, 18, INK)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for i in _prompts.get_child_count():
		var l := _prompts.get_child(i) as Label
		l.visible = i < lines.size()
		if l.visible:
			l.text = lines[i]
	_bar.visible = not it.busy.is_empty()
	if _bar.visible:
		_bar.value = 100.0 * (1.0 - it.busy.left / it.busy.total)
		(_prompts.get_child(0) as Label).visible = true
		(_prompts.get_child(0) as Label).text = it.busy.label + "…  (move to stop)"


func _toast(text: String) -> void:
	var l := _label(_toasts, 16, INK)
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 460
	if _toasts.get_child_count() > 6:
		_toasts.get_child(0).queue_free()
	var tw := create_tween()
	tw.tween_interval(7.0)
	tw.tween_property(l, "modulate:a", 0.0, 1.5)
	tw.tween_callback(l.queue_free)


func _unhandled_key_input(e: InputEvent) -> void:
	if not e.is_pressed() or e.is_echo():
		return
	var k := (e as InputEventKey).physical_keycode
	if k == KEY_ESCAPE:
		if modal():
			if _on_close.is_valid() or not _pauses:
				close()
		else:
			open_pause()
	elif Game.ended != "" or (modal() and _pauses):
		return
	elif k == KEY_N or k == KEY_TAB:
		if modal():
			close()
		else:
			open_notebook()
	elif k == KEY_I and not modal():
		open_container({})


# --- the window ---------------------------------------------------------------

func _open(title: String, body: String, pauses := false) -> void:
	_title.text = title
	_body.text = body
	_body.visible = body != ""
	for c in _rows.get_children():
		c.queue_free()
	for c in _buttons.get_children():
		c.queue_free()
	(_rows.get_meta("scroll") as ScrollContainer).custom_minimum_size.y = 0
	_window.visible = true
	_shade.visible = true
	_pauses = pauses
	_on_close = Callable()
	_refresh = Callable()
	if pauses:
		Clock.running = false


func close() -> void:
	_window.visible = false
	_shade.visible = false
	if _pauses and Game.ended == "":
		Clock.running = true
	_refresh = Callable()
	if _on_close.is_valid():
		var cb := _on_close
		_on_close = Callable()
		cb.call()


func _button(parent: Control, text: String, action: Callable, closes := true) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 15)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void:
		if closes:
			close()
		if action.is_valid():
			action.call())
	parent.add_child(b)
	return b


func _row(text: String, color := INK) -> HBoxContainer:
	var r := HBoxContainer.new()
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", color)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.add_child(l)
	_rows.add_child(r)
	return r


func _tall(rows: int) -> void:
	(_rows.get_meta("scroll") as ScrollContainer).custom_minimum_size.y = minf(420.0, rows * 34.0)


func open_text(title: String, body: String, buttons: Array, pauses := false) -> void:
	_open(title, body, pauses)
	for b: Array in buttons:
		_button(_buttons, b[0], b[1])


## A container's contents beside your pockets. `c` is a furniture dictionary, or {} for pockets only.
func open_container(c: Dictionary) -> void:
	var home: House = main.street.home
	var mine: bool = c.is_empty() or c.house == home
	if not c.is_empty():
		if not mine and c.house != main.street.plant:
			c.disturbed = true
		main.life.read_clues(c)
		Game.train("search", 1.0)
	_open("Your pockets" if c.is_empty() else c.name, "")
	_refresh = func() -> void: _fill_container(c, mine)
	_fill_container(c, mine)


func _fill_container(c: Dictionary, mine: bool) -> void:
	for ch in _rows.get_children():
		ch.queue_free()
	for ch in _buttons.get_children():
		ch.queue_free()
	var n := 2
	var m := Game.mission
	if not c.is_empty():
		_row("In the %s" % String(c.name).to_lower(), DIM)
		if c.items.is_empty():
			_row("   Nothing.", DIM)
		for it: Dictionary in c.items.duplicate():
			n += 1
			var r := _row("   " + it.name, WARN if it.contraband else INK)
			if it.id == "doc" and m.get("type", "") == "photo" and m.stage == "get" and it.mission == m.n:
				if Game.has("minicam"):
					_button(r, "Photograph", func() -> void: main.missions.photographed(), false)
				else:
					_row("      (you need the Minox camera)", DIM)
			if it.id in ["food", "coffee"] and mine:
				_button(r, "Eat" if it.id == "food" else "Drink", _eat_from.bind(c.items, it), false)
			_button(r, "Take", _take.bind(c, it), false)
	_row("In your pockets", DIM)
	if Game.inventory.is_empty():
		_row("   Nothing.", DIM)
	for it: Dictionary in Game.inventory.duplicate():
		n += 1
		var r := _row("   " + it.name, WARN if it.contraband else INK)
		if it.id in ["food", "coffee"]:
			_button(r, "Eat" if it.id == "food" else "Drink", _eat_from.bind(Game.inventory, it), false)
		if not c.is_empty():
			_button(r, "Put", _put.bind(c, it), false)
	_tall(n + 1)
	if c.is_empty() or mine or c.house == main.street.plant:
		_button(_buttons, "Close", Callable())
	else:
		_button(_buttons, "Leave it as it is", Callable())
		_button(_buttons, "Tidy up and close", _tidy.bind(c))


func _take(c: Dictionary, it: Dictionary) -> void:
	c.items.erase(it)
	Game.give(it)
	if it.id == "doc":
		main.missions.took_doc()


func _put(c: Dictionary, it: Dictionary) -> void:
	Game.inventory.erase(it)
	c.items.append(it)
	var m := Game.mission
	if it.id == "doc" and c.house.index == m.get("lot", -1) and c.kind == m.get("spot", ""):
		main.missions.returned_doc()
	Game.changed.emit()


func _eat_from(list: Array, it: Dictionary) -> void:
	list.erase(it)
	main.life.eat(it)


func _tidy(c: Dictionary) -> void:
	main.interact.run(main.interact._opt("Putting everything back", func() -> void: c.disturbed = false, 3.0 / (1.0 + 0.25 * Game.level("search")), "search"))


func _burn(it: Dictionary) -> void:
	Game.inventory.erase(it)
	Game.changed.emit()


func _buy(s: Array) -> void:
	Game.money -= int(s[2])
	if s[0] == "floor_safe":
		Game.upgrades["floor_safe"] = true
		Game.note("Floor safe fitted. A search is far less likely to find what is in it.")
	else:
		Game.give(Game.item(s[0]))


func open_burn() -> void:
	_open("The kitchen sink", "Anything burned here is gone for good.")
	_refresh = _fill_burn
	_fill_burn()


func _fill_burn() -> void:
	for ch in _rows.get_children():
		ch.queue_free()
	for ch in _buttons.get_children():
		ch.queue_free()
	for it: Dictionary in Game.inventory.duplicate():
		if it.contraband:
			_button(_row(it.name, WARN), "Burn", _burn.bind(it), false)
	if _rows.get_child_count() == 0:
		_row("Nothing in your pockets needs burning.", DIM)
	_tall(Game.inventory.size() + 1)
	_button(_buttons, "Done", Callable())


func open_shop() -> void:
	_open("Miller's Market", "")
	_refresh = _fill_shop
	_fill_shop()


func _fill_shop() -> void:
	for ch in _rows.get_children():
		ch.queue_free()
	for ch in _buttons.get_children():
		ch.queue_free()
	_row("You have $%d." % Game.money, DIM)
	var stock: Array = [
		["food", "Canned dinner", 5, "A meal."],
		["coffee", "Instant coffee", 3, "Takes the edge off tiredness."],
		["treat", "Dog biscuits", 4, "A dog with a biscuit does not bark."],
		["clay", "Modelling clay", 8, "Takes the shape of a key from an unlocked door."],
		["floor_safe", "Floor safe kit", 120, "A far better hiding place under the bedroom floor."],
	]
	for s: Array in stock:
		if s[0] == "floor_safe" and Game.upgrades.get("floor_safe", false):
			continue
		var r := _row("%s — $%d.  %s" % [s[1], s[2], s[3]])
		var b := _button(r, "Buy", _buy.bind(s), false)
		b.disabled = Game.money < int(s[2])
	_tall(stock.size() + 2)
	_button(_buttons, "Leave", Callable())


func open_notebook() -> void:
	var t := "[b]Orders[/b]\n%s\n\n" % main.missions.objective()
	t += "[b]You[/b]\nLocks %d   Search %d   Small talk %d      %s\n\n" % [Game.level("locks"), Game.level("search"), Game.level("talk"), "No longer employed at the plant" if Game.fired else "Janitor at the plant. Missed shifts %d of 3" % Game.missed_shifts]
	t += "[b]Neighbours[/b]\n"
	for h: House in main.street.houses:
		for n: Neighbour in h.residents:
			if not n.met and Game.known.get(int(n.d.id), {}).is_empty():
				continue
			var id := int(n.d.id)
			var line := "%s, %s" % [n.full_name(), String(n.d.title).to_lower()]
			if n.state == "dead":
				line += " [color=#a8a290](dead)[/color]"
			elif n.asset:
				line += " [color=#8fc27a](yours)[/color]"
			else:
				line += " — " + _feeling(n.suspicion)
			if Game.knows(id, "hours") and float(n.d.leave) > 0.0:
				line += "\n      Out %s to %s on weekdays. Asleep by %s." % [Life.hhmm(n.d.leave), Life.hhmm(n.d.back), Life.hhmm(fmod(n.d.sleep, 24.0))]
			if Game.knows(id, "secret"):
				line += "\n      [color=#e8a23a]%s.[/color]" % String(Life.SECRET_TEXT[n.d.secret]).capitalize()
			if Game.knows(id, "agent"):
				line += "\n      [color=#e2574c]Works for the Bureau.[/color]"
			for mem in n.memory:
				line += "\n      [color=#a8a290]%s[/color]" % mem.capitalize()
			t += line + "\n"
	t += "\n[b]Journal[/b]\n"
	for i in range(Game.journal.size() - 1, maxi(-1, Game.journal.size() - 16), -1):
		t += Game.journal[i] + "\n"
	_open("Notebook", "")
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.text = t
	rt.fit_content = true
	rt.custom_minimum_size.x = 560
	rt.add_theme_font_size_override("normal_font_size", 15)
	rt.add_theme_font_size_override("bold_font_size", 16)
	rt.add_theme_color_override("default_color", INK)
	_rows.add_child(rt)
	(_rows.get_meta("scroll") as ScrollContainer).custom_minimum_size.y = 440
	_button(_buttons, "Close", Callable())


func _feeling(s: float) -> String:
	if s < 10.0:
		return "thinks nothing of you"
	if s < 30.0:
		return "[color=#e9e3d2]curious about you[/color]"
	if s < 60.0:
		return "[color=#e8a23a]suspicious of you[/color]"
	return "[color=#e2574c]sure you are up to something[/color]"


func open_pause() -> void:
	open_text("Paused", "[b]Move[/b] W A S D    [b]Run[/b] Shift    [b]Sneak[/b] C\n[b]Act[/b] E, R    [b]Force[/b] F    [b]Notebook[/b] N    [b]Pockets[/b] I\n[b]Zoom[/b] pinch, or - and =\n\nThe game saves only when you sleep in your own bed.", [
		["Quit to desktop", func() -> void: get_tree().quit()],
		["Resume", Callable()],
	], true)
	_on_close = func() -> void: pass


func open_menu() -> void:
	var buttons: Array = [["Quit", func() -> void: get_tree().quit()]]
	if Save.exists():
		buttons.append(["Continue", func() -> void: _restart(true)])
	buttons.append(["New agent", func() -> void: _restart(false)])
	open_text("MAPLE STREET", "1984. To the neighbours you are the quiet new janitor at the plant.\nThe Centre knows you by a number.\n\nLearn the street. Do the work. Do not be noticed.", buttons, true)


func _restart(load_save: bool) -> void:
	Game.started = true
	Game.pending_load = load_save
	if not load_save:
		Game.run_seed = randi() % 1000000 + 1
	Clock.running = true
	get_tree().reload_current_scene()


func _ended() -> void:
	var title := "ARRESTED" if Game.ended == "arrested" else "GONE"
	var body := "%s\n\nDays on Maple Street: %d\nIntelligence sent home: %d\nJobs completed: %d" % [Game.end_reason, Clock.day(), Game.intel, Game.missions_done]
	open_text(title, body, [
		["Quit", func() -> void: get_tree().quit()],
		["New agent", func() -> void: _restart(false)],
	], true)
