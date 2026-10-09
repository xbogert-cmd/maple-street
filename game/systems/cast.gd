class_name Cast
## Decides who lives on the street for one run: families, jobs, hours, secrets, dogs,
## which house is yours and which neighbour is the counter-agent. Pure data, from a seed.

const LOTS := 12
const SURNAMES: Array[String] = ["Henderson", "Kowalski", "Marsh", "Whitaker", "Delgado", "Pruitt", "Lindqvist", "Okafor", "Brandt", "Castellano", "Hooper", "Yates", "Novak", "Ferris", "Gallagher", "Tran", "Abbott", "Sorensen"]
const MEN: Array[String] = ["Frank", "Walter", "Gene", "Ray", "Dennis", "Carl", "Hal", "Stan", "Lou", "Vern", "Russ", "Dale", "Glenn", "Marty"]
const WOMEN: Array[String] = ["Barbara", "Joyce", "Linda", "Carol", "Ruth", "Peggy", "Diane", "Marge", "Helen", "Donna", "Gail", "Nancy", "Sheila", "Irene"]
const KIDS: Array[String] = ["Tommy", "Jenny", "Scott", "Missy", "Kevin", "Stacy", "Brian", "Tina"]
const PLANT_TITLES: Array[String] = ["Guidance engineer", "Propulsion engineer", "Security supervisor", "Records clerk", "Test technician", "Contracts officer", "Draftsman", "Telemetry analyst"]
const TOWN_JOBS: Array[String] = ["Bank teller", "High school teacher", "Mechanic", "Nurse", "Realtor", "Postal clerk"]
const SECRETS: Array[String] = ["debt", "affair", "drinking", "gambling"]
const WALLS: Array[String] = ["d9d2c0", "c9d3cf", "e3d6b8", "cfc4d1", "bfcfd9", "e0c9b5", "d6dcc4"]
const ROOFS: Array[String] = ["6e4b3c", "4d5560", "7a3b33", "56604a", "5a4a5c"]
const SHIRTS: Array[String] = ["8a3b3b", "3b5d8a", "4f7a52", "c9b25a", "7a5a8a", "d9d4c7", "b56b3a", "4a8a8a"]
const HAIRS: Array[String] = ["2b2118", "5a3d24", "8a6a3a", "b9b3a8", "1c1c1c", "a0522d"]
const SKINS: Array[String] = ["e8c4a0", "d9a57c", "b07a52", "8a5a3c", "f0d2b6"]


static func generate(run_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed
	var surnames := SURNAMES.duplicate()
	_shuffle(surnames, rng)
	var home := rng.randi_range(2, LOTS - 3)
	if home == 5 or home == 6:
		home = 4  # keep the two lots nearest the park for neighbours
	# What each household's main adult does. Enough plant staff to give missions variety.
	var jobs: Array[String] = ["plant", "plant", "plant", "plant", "plant", "plant", "retired", "retired", "town", "town", "agent"]
	_shuffle(jobs, rng)
	var kid_lots := _pick(LOTS, 3, rng, home)
	var dog_lots := _pick(LOTS, 3, rng, home)
	var houses: Array[Dictionary] = []
	var next_id := 0
	var j := 0
	for i in LOTS:
		var h := {
			"lot": i, "family": surnames[i], "tpl": rng.randi_range(0, Templates.HOUSES.size() - 1),
			"mirror": rng.randf() < 0.5, "wall": WALLS[rng.randi() % WALLS.size()],
			"roof": ROOFS[rng.randi() % ROOFS.size()], "dog": false, "people": [],
			"car": SHIRTS[rng.randi() % SHIRTS.size()],
		}
		if i == home:
			h.family = "(you)"
			houses.append(h)
			continue
		var job: String = jobs[j]
		j += 1
		h.dog = i in dog_lots
		var man := rng.randf() < 0.6
		var main := _person(next_id, rng, man, h.family, job)
		next_id += 1
		h.people.append(main)
		if job != "retired" or rng.randf() < 0.5:
			if job != "agent":
				var partner_job := "home" if rng.randf() < 0.55 else "town"
				if job == "retired":
					partner_job = "retired"
				h.people.append(_person(next_id, rng, not man, h.family, partner_job))
				next_id += 1
		if i in kid_lots and job != "retired" and job != "agent":
			h.people.append(_person(next_id, rng, rng.randf() < 0.5, h.family, "school"))
			next_id += 1
		houses.append(h)
	return {"seed": run_seed, "home": home, "houses": houses}


static func _person(id: int, rng: RandomNumberGenerator, man: bool, last: String, job: String) -> Dictionary:
	var p := {
		"id": id, "last": last, "man": man, "job": job, "title": "", "clearance": 0,
		"leave": 0.0, "back": 0.0, "sleep": 22.5 + rng.randf_range(-0.75, 1.0), "wake": 6.5 + rng.randf_range(-0.5, 0.75),
		"nosy": rng.randf_range(0.1, 0.5), "secret": "", "agent": false,
		"shirt": SHIRTS[rng.randi() % SHIRTS.size()], "pants": ["3a3f52", "4a4238", "2e3a2e", "55504a"][rng.randi() % 4],
		"hair": HAIRS[rng.randi() % HAIRS.size()], "skin": SKINS[rng.randi() % SKINS.size()], "scale": 1.0,
	}
	p.first = (MEN if man else WOMEN)[rng.randi() % 14]
	match job:
		"plant":
			p.title = PLANT_TITLES[rng.randi() % PLANT_TITLES.size()]
			p.clearance = rng.randi_range(1, 3)
			p.leave = 7.5 + rng.randf_range(-0.25, 0.5)
			p.back = 17.25 + rng.randf_range(-0.25, 0.75)
		"town":
			p.title = TOWN_JOBS[rng.randi() % TOWN_JOBS.size()]
			p.leave = 8.25 + rng.randf_range(-0.5, 0.75)
			p.back = 16.75 + rng.randf_range(-0.75, 1.0)
		"agent":
			# Cover story is a travelling salesman: irregular hours, never at the plant.
			p.title = "Insurance salesman"
			p.agent = true
			p.leave = 10.0 + rng.randf_range(-0.5, 1.0)
			p.back = 14.5 + rng.randf_range(-0.5, 1.0)
			p.sleep = 25.0
			p.nosy = 0.7
		"retired":
			p.title = "Retired"
			p.nosy = rng.randf_range(0.7, 1.0)
			p.hair = "b9b3a8"
			p.sleep = 21.5 + rng.randf_range(-0.5, 0.5)
			p.wake = 5.75 + rng.randf_range(-0.25, 0.5)
		"home":
			p.title = "At home"
			p.leave = 10.0 + rng.randf_range(0.0, 1.5)   # errands
			p.back = p.leave + rng.randf_range(1.0, 2.0)
		"school":
			p.first = KIDS[rng.randi() % KIDS.size()]
			p.title = "Kid"
			p.leave = 7.75
			p.back = 15.25 + rng.randf_range(0.0, 0.5)
			p.sleep = 21.0
			p.scale = 0.7
			p.nosy = 0.9
	if job in ["plant", "town", "home"] and rng.randf() < 0.4:
		p.secret = SECRETS[rng.randi() % SECRETS.size()]
	return p


static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var k := rng.randi_range(0, i)
		var t: Variant = a[i]
		a[i] = a[k]
		a[k] = t


static func _pick(n: int, count: int, rng: RandomNumberGenerator, skip: int) -> Array[int]:
	var pool: Array[int] = []
	for i in n:
		if i != skip:
			pool.append(i)
	_shuffle(pool, rng)
	return pool.slice(0, count)
