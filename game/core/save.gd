class_name Save
## One save slot, written when the player sleeps. Permadeath: wiped when a run ends.

const PATH := "user://maple_street.save"
const GAME_FIELDS: Array[String] = ["run_seed", "money", "intel", "hunger", "fatigue", "inventory", "skills", "upgrades", "radio_hidden", "worked_today", "missed_shifts", "writeups", "fired", "mission", "missions_done", "pickup", "known", "journal", "incident"]
const PERSON_FIELDS: Array[String] = ["suspicion", "memory", "asset", "met", "alert", "recognised", "hidden_body", "found", "died_at", "missing_reported"]
const LAW_FIELDS: Array[String] = ["blown", "investigating", "search_at", "no_search_until"]


static func exists() -> bool:
	return FileAccess.file_exists(PATH)


static func wipe() -> void:
	if exists():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


static func seed_of_save() -> int:
	var d: Variant = str_to_var(FileAccess.get_file_as_string(PATH))
	return int(d.game.run_seed) if d is Dictionary else 0


static func write(main: Node) -> void:
	var d := {"version": 1, "minutes": Clock.minutes, "game": {}, "people": {}, "containers": [], "portals": [], "law": {}, "next_at": main.missions.next_at}
	for f in GAME_FIELDS:
		d.game[f] = Game.get(f)
	for n: Neighbour in main.neighbours:
		var p := {"dead": n.state == "dead", "pos": n.global_position}
		for f in PERSON_FIELDS:
			p[f] = n.get(f)
		d.people[int(n.d.id)] = p
	for c: Dictionary in main.street.all_containers():
		d.containers.append({"items": c.items, "locked": c.locked, "disturbed": c.disturbed, "bug": c.bug})
	for h: House in main.street.houses:
		for pt in h.portals:
			d.portals.append([pt.locked, pt.key_copied, pt.picked, pt.forced])
	for f in LAW_FIELDS:
		d.law[f] = main.law.get(f)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(var_to_str(d))


## Restore a save into a freshly built street (built from the same seed).
static func apply(main: Node) -> void:
	var d: Dictionary = str_to_var(FileAccess.get_file_as_string(PATH))
	Game.reset()
	for f in GAME_FIELDS:
		Game.set(f, d.game[f])
	Clock.minutes = d.minutes
	main.life.furnish_home()
	main.missions.next_at = d.next_at
	for n: Neighbour in main.neighbours:
		var p: Dictionary = d.people[int(n.d.id)]
		for f in PERSON_FIELDS:
			n.set(f, p[f])
		if p.dead:
			n.kill()
			n.global_position = p.pos
			n.visible = not n.hidden_body
	var cs: Array[Dictionary] = main.street.all_containers()
	for i in cs.size():
		var s: Dictionary = d.containers[i]
		cs[i].items = s.items
		cs[i].locked = s.locked
		cs[i].disturbed = s.disturbed
		cs[i].bug = s.bug
	var k := 0
	for h: House in main.street.houses:
		for pt in h.portals:
			var s: Array = d.portals[k]
			k += 1
			pt.locked = s[0]
			pt.key_copied = s[1]
			pt.picked = s[2]
			pt.forced = s[3]
	for f in LAW_FIELDS:
		main.law.set(f, d.law[f])
	main.player.global_position = main.street.home.find_furn("bed").pos + Vector3(1.2, 0, 0)
