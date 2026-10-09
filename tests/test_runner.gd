extends Node3D
## Minimal test runner. Runs every tests/test_*.gd file's test_* methods, and first loads every
## script under res://game so parse errors show up here. Prints "TESTS PASSED n".

var failures: Array[String] = []
var current := ""


func _ready() -> void:
	_scan("res://game")
	var total := 0
	var files := Array(DirAccess.open("res://tests").get_files()).filter(func(f: String) -> bool: return f.begins_with("test_") and f.ends_with(".gd") and f != "test_runner.gd")
	files.sort()
	for f: String in files:
		var suite: Object = (load("res://tests/" + f) as GDScript).new()
		suite.set("t", self)
		for m in suite.get_method_list():
			var mname: String = m.name
			if not mname.begins_with("test_"):
				continue
			total += 1
			current = f.get_basename() + "." + mname
			var before := failures.size()
			await suite.call(mname)
			if failures.size() == before:
				print("  ok  ", current)
	if failures.is_empty():
		print("TESTS PASSED %d" % total)
	else:
		for fl in failures:
			printerr("FAIL ", fl)
		print("TESTS FAILED %d of %d" % [failures.size(), total])
	get_tree().quit(0 if failures.is_empty() else 1)


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append("%s: %s" % [current, msg])


func _scan(dir: String) -> void:
	var d := DirAccess.open(dir)
	for sub in d.get_directories():
		_scan(dir + "/" + sub)
	for f in d.get_files():
		if f.ends_with(".gd"):
			var r := load(dir + "/" + f) as GDScript
			if r == null or not r.can_instantiate():
				failures.append("script does not load: " + dir + "/" + f)
