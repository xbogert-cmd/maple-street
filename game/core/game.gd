extends Node
## State of the current run (one agent's life) and the signals the HUD listens to.

signal toast(text: String)
signal changed
signal noise(pos: Vector3, radius: float, kind: String)
signal run_ended

## id: [name, contraband]
const ITEMS: Dictionary = {
	"lockpicks": ["Lockpick roll", true],
	"minicam": ["Minox camera", true],
	"codebook": ["One-time pad", true],
	"bug": ["Listening device", true],
	"film": ["Exposed film", true],
	"microdot": ["Microdot", true],
	"copy": ["Document copy", true],
	"mould": ["Key impression", true],
	"clay": ["Modelling clay", false],
	"food": ["Canned dinner", false],
	"treat": ["Dog biscuits", false],
	"coffee": ["Instant coffee", false],
}

var run_seed := 0
var pending_load := false
var started := false       # past the title menu
var money := 40
var intel := 0
var hunger := 10.0      # 0 full, 100 starving
var fatigue := 10.0     # 0 rested, 100 exhausted
var inventory: Array[Dictionary] = []
var skills: Dictionary = {"locks": 0.0, "search": 0.0, "talk": 0.0}   # experience points
var upgrades: Dictionary = {}      # "floor_safe": true ...
var radio_hidden := true
var worked_today := false
var missed_shifts := 0
var writeups := 0
var fired := false
var mission: Dictionary = {}       # the current job from the Centre ({} if none)
var missions_done := 0
var pickup: Dictionary = {}        # package waiting at a dead drop: {drop, items, money}
var known: Dictionary = {}         # person id -> {hours: bool, secret: bool, agent: bool}
var ended := ""                    # "" while playing, else "arrested" or "extracted"
var end_reason := ""
var journal: Array[String] = []
var ctx: Dictionary = {}           # what the player is doing right now (see Rules.judge)
var incident := 0.0                # heat from unsolved incidents; fades daily
var heat := 0.0
var args: Dictionary = {}          # command line: --key=value after "--"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"


func reset() -> void:
	money = 40
	intel = 0
	hunger = 10.0
	fatigue = 10.0
	inventory = []
	skills = {"locks": 0.0, "search": 0.0, "talk": 0.0}
	upgrades = {}
	radio_hidden = true
	worked_today = true    # the game opens on Monday evening, after the first day at the plant
	missed_shifts = 0
	writeups = 0
	fired = false
	mission = {}
	missions_done = 0
	pickup = {}
	known = {}
	ended = ""
	end_reason = ""
	journal = []
	incident = 0.0
	heat = 0.0
	Clock.minutes = 17.0 * 60.0   # Monday, 5 PM: home from the first day at the plant
	Clock.running = true
	Clock.rate = 1.0


func say(text: String) -> void:
	toast.emit(text)


func note(text: String) -> void:
	journal.append("%s — %s" % [Clock.stamp(), text])
	Sfx.play("note")
	toast.emit(text)
	changed.emit()


func item(id: String, extra := {}) -> Dictionary:
	var it := {"id": id, "name": ITEMS[id][0], "contraband": ITEMS[id][1]}
	it.merge(extra, true)
	return it


func has(id: String) -> bool:
	for it in inventory:
		if it.id == id:
			return true
	return false


func take(id: String) -> Dictionary:
	for i in inventory.size():
		if inventory[i].id == id:
			var it := inventory[i]
			inventory.remove_at(i)
			changed.emit()
			return it
	return {}


func give(it: Dictionary) -> void:
	inventory.append(it)
	changed.emit()


## Skill level 0..5 from experience (10 points a level).
func level(skill: String) -> int:
	return mini(5, int(float(skills.get(skill, 0.0)) / 10.0))


func train(skill: String, xp: float) -> void:
	var before := level(skill)
	skills[skill] = float(skills.get(skill, 0.0)) + xp
	if level(skill) > before:
		say("%s skill is now level %d" % [{"locks": "Lock", "search": "Search", "talk": "Small talk"}[skill], level(skill)])


func knows(id: int, what: String) -> bool:
	return known.get(id, {}).get(what, false)


func learn(id: int, what: String) -> void:
	if not known.has(id):
		known[id] = {}
	known[id][what] = true
	changed.emit()


func incident_add(amount: float, text: String) -> void:
	incident = clampf(incident + amount, 0.0, 100.0)
	note(text)


func mood() -> String:
	if heat < 12.0:
		return "Quiet"
	if heat < Rules.HEAT_INVESTIGATOR:
		return "Uneasy"
	if heat < Rules.HEAT_SEARCH:
		return "Watchful"
	return "Closing in"


func end(kind: String, reason: String) -> void:
	if ended != "":
		return
	ended = kind
	end_reason = reason
	Clock.running = false
	Save.wipe()
	run_ended.emit()
