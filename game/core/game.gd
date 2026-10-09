extends Node
## State of the current run (one agent's life) and the signals the HUD listens to.

signal toast(text: String)
signal changed

var run_seed := 0
var money := 40
var intel := 0
var hunger := 10.0      # 0 full, 100 starving
var fatigue := 10.0     # 0 rested, 100 exhausted
var inventory: Array[Dictionary] = []
var ended := ""         # "" while playing, else "arrested" or "extracted"
var journal: Array[String] = []
var args: Dictionary = {}   # command line: --key=value after "--"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"


func say(text: String) -> void:
	toast.emit(text)


func note(text: String) -> void:
	journal.append("%s — %s" % [Clock.stamp(), text])
	changed.emit()


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


func give(item: Dictionary) -> void:
	inventory.append(item)
	changed.emit()
