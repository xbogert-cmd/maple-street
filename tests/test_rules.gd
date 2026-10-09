extends RefCounted

var t: Node


func test_cast_is_stable_and_complete() -> void:
	var a := Cast.generate(42)
	var b := Cast.generate(42)
	t.check(str(a) == str(b), "same seed gives the same street")
	t.check(str(a) != str(Cast.generate(43)), "different seed gives a different street")
	t.check(a.houses.size() == 12, "twelve lots")
	t.check(a.houses[a.home].people.is_empty(), "nobody else lives in your house")
	var agents := 0
	var cleared := 0
	for h: Dictionary in a.houses:
		for p: Dictionary in h.people:
			agents += int(p.agent)
			cleared += int(p.clearance > 0)
	t.check(agents == 1, "exactly one counter-agent, got %d" % agents)
	t.check(cleared >= 5, "enough plant staff to target, got %d" % cleared)


func test_judge() -> void:
	t.check(Rules.judge({"zone": "street", "hour": 14.0}).is_empty(), "walking the street by day is fine")
	t.check(Rules.judge({"zone": "home", "act": "lock"}).is_empty(), "your own door is fine")
	t.check(Rules.judge({"zone": "yard", "night": true}).amount > Rules.judge({"zone": "yard", "night": false}).amount, "yards are worse at night")
	t.check(Rules.judge({"zone": "inside"}).severe, "inside a house is severe")
	t.check(Rules.judge({"zone": "yard", "invited": true}).is_empty(), "invited guests are fine")
	t.check(Rules.judge({"zone": "yard", "invited": true, "act": "lock"}).severe, "but not at the lock")


func test_heat_and_search() -> void:
	t.check(Rules.heat([0.0, 0.0], 0.0) == 0.0, "calm street")
	t.check(Rules.heat([100.0, 100.0, 100.0, 100.0, 0.0], 0.0) == 70.0, "four certain neighbours is 70")
	t.check(Rules.heat([10.0], 30.0) > Rules.heat([10.0], 0.0), "incidents add heat")
	t.check(Rules.find_chance("pocket") == 1.0 and Rules.find_chance("floor_safe") < Rules.find_chance("stash"), "better hiding places are safer")
	t.check(Rules.sight_range(0.1, true) < Rules.sight_range(1.0, false), "dark and sneaking is harder to see")
