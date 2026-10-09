class_name Templates
## House floor plans, in metres. The front of the house is the z = d edge.
## rooms: [name, x, z, w, d]. Edges are unit wall segments: "h" runs along x at (x, z),
## "v" runs along z at (x, z). doors: [axis, x, z, kind] with kind "front", "back" or "in".
## furniture: [kind, x, z, rotation in quarter turns].

const HOUSES: Array[Dictionary] = [
	{
		"w": 12, "d": 9,
		"rooms": [["living", 0, 5, 7, 4], ["study", 7, 5, 5, 4], ["kitchen", 0, 0, 5, 5], ["bath", 5, 0, 3, 5], ["bedroom", 8, 0, 4, 5]],
		"doors": [["h", 3, 9, "front"], ["h", 2, 0, "back"], ["h", 1, 5, "in"], ["v", 7, 7, "in"], ["h", 6, 5, "in"], ["h", 9, 5, "in"]],
		"windows": [["h", 1, 9], ["h", 5, 9], ["h", 9, 9], ["v", 0, 7], ["v", 0, 2], ["v", 12, 2], ["v", 12, 7], ["h", 10, 0], ["h", 6, 0]],
		"furniture": [
			["sofa", 5.6, 8.3, 0], ["tv", 4.5, 5.5, 0], ["phone", 0.5, 6.0, 0],
			["desk", 11.4, 7.0, 1], ["cabinet", 7.6, 8.5, 0], ["shelf", 9.5, 8.7, 0],
			["fridge", 0.6, 0.6, 0], ["counter", 4.5, 2.0, 1], ["table", 2.2, 3.2, 0],
			["tub", 7.5, 1.2, 0], ["toilet", 5.5, 0.5, 0],
			["bed", 10.8, 1.5, 0], ["dresser", 8.9, 0.4, 0],
		],
	},
	{
		"w": 13, "d": 8,
		"rooms": [["hall", 5, 4, 3, 4], ["living", 0, 3, 5, 5], ["kitchen", 8, 3, 5, 5], ["bedroom", 0, 0, 5, 3], ["bath", 5, 0, 3, 4], ["study", 8, 0, 5, 3]],
		"doors": [["h", 6, 8, "front"], ["v", 13, 5, "back"], ["v", 5, 6, "in"], ["v", 8, 6, "in"], ["h", 6, 4, "in"], ["h", 2, 3, "in"], ["h", 10, 3, "in"]],
		"windows": [["h", 2, 8], ["h", 10, 8], ["v", 0, 5], ["v", 0, 1], ["h", 2, 0], ["h", 10, 0], ["v", 13, 1], ["h", 6, 0]],
		"furniture": [
			["sofa", 0.6, 5.5, 1], ["tv", 4.6, 4.5, 1], ["phone", 5.4, 7.5, 0],
			["desk", 10.5, 0.5, 0], ["cabinet", 12.6, 2.5, 0], ["shelf", 8.4, 1.0, 1],
			["fridge", 12.4, 7.4, 0], ["counter", 10.5, 7.6, 0], ["table", 10.5, 5.0, 0],
			["tub", 7.5, 1.2, 0], ["toilet", 5.5, 0.5, 0],
			["bed", 1.2, 1.3, 0], ["dresser", 4.0, 0.4, 0],
		],
	},
	{
		"w": 11, "d": 10,
		"rooms": [["living", 0, 5, 6, 5], ["kitchen", 6, 5, 5, 5], ["hall", 0, 3, 11, 2], ["bedroom", 0, 0, 4, 3], ["bath", 4, 0, 3, 3], ["study", 7, 0, 4, 3]],
		"doors": [["h", 2, 10, "front"], ["v", 11, 7, "back"], ["h", 3, 5, "in"], ["h", 8, 5, "in"], ["h", 1, 3, "in"], ["h", 5, 3, "in"], ["h", 9, 3, "in"]],
		"windows": [["h", 4, 10], ["h", 8, 10], ["v", 0, 7], ["v", 0, 1], ["h", 2, 0], ["h", 9, 0], ["v", 11, 1], ["v", 11, 9]],
		"furniture": [
			["sofa", 0.6, 7.5, 1], ["tv", 5.5, 7.5, 1], ["phone", 5.5, 9.5, 0],
			["desk", 9.0, 0.5, 0], ["cabinet", 10.6, 2.4, 0], ["shelf", 7.4, 1.2, 1],
			["fridge", 10.4, 9.4, 0], ["counter", 8.0, 9.6, 0], ["table", 8.5, 7.0, 0],
			["tub", 6.5, 1.0, 0], ["toilet", 4.5, 0.5, 0],
			["bed", 1.0, 1.3, 0], ["dresser", 3.0, 0.4, 0],
		],
	},
]

## kind: [size, colour, container name ("" if not a container)]
const FURNITURE: Dictionary = {
	"sofa": [Vector3(2.0, 0.75, 0.9), Color("7a4f3a"), ""],
	"tv": [Vector3(1.0, 1.0, 0.5), Color("2b2b33"), ""],
	"phone": [Vector3(0.5, 0.85, 0.5), Color("8a6b4a"), ""],
	"desk": [Vector3(1.6, 0.8, 0.8), Color("6b4a2e"), "Desk"],
	"cabinet": [Vector3(0.6, 1.4, 0.6), Color("7d8790"), "Filing cabinet"],
	"shelf": [Vector3(1.4, 1.8, 0.4), Color("5a3d28"), ""],
	"fridge": [Vector3(0.8, 1.8, 0.8), Color("e6e2d6"), "Fridge"],
	"counter": [Vector3(2.4, 0.9, 0.7), Color("c9b48a"), ""],
	"table": [Vector3(1.4, 0.78, 1.0), Color("8a6240"), ""],
	"tub": [Vector3(0.8, 0.6, 1.7), Color("dfe7ea"), ""],
	"toilet": [Vector3(0.5, 0.6, 0.6), Color("eef2f2"), ""],
	"bed": [Vector3(1.6, 0.55, 2.1), Color("4d6a8a"), ""],
	"dresser": [Vector3(1.2, 1.0, 0.5), Color("6b4a2e"), "Dresser"],
	"safe": [Vector3(0.6, 0.8, 0.6), Color("3c4046"), "Safe"],
	"radio": [Vector3(0.7, 0.95, 0.5), Color("3a3f35"), ""],
	"darkroom": [Vector3(1.4, 0.9, 0.6), Color("5b2e2e"), ""],
	"stash": [Vector3(0.7, 0.06, 0.7), Color("5a4630"), "Hiding place"],
}

const FLOORS: Dictionary = {
	"living": Color("9c7b55"), "study": Color("7d5f43"), "kitchen": Color("c8c2a8"),
	"bath": Color("a9c4c9"), "bedroom": Color("8f8266"), "hall": Color("94765a"),
}


## A copy of template `i`, flipped left to right if `mirror`.
static func make(i: int, mirror: bool) -> Dictionary:
	var t: Dictionary = HOUSES[i].duplicate(true)
	if not mirror:
		return t
	var w: int = t.w
	for r: Array in t.rooms:
		r[1] = w - r[1] - r[3]
	for list: Array in [t.doors, t.windows]:
		for e: Array in list:
			e[1] = (w - 1 - e[1]) if e[0] == "h" else (w - e[1])
	for f: Array in t.furniture:
		f[1] = w - f[1]
		f[3] = (4 - f[3]) % 4
	return t
