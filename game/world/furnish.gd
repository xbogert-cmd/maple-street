class_name Furnish
## Draws each kind of furniture out of small boxes. Local space: x across, +z toward the room,
## origin on the floor at the centre of the piece. `s` is (width, height, depth).

const WOOD := Color("6b4a2e")
const BOOKS: Array[Color] = [Color("8a3b3b"), Color("3b5d8a"), Color("4f7a52"), Color("c9b25a"), Color("7a5a8a"), Color("d9d4c7"), Color("b56b3a")]


static func make(house: House, n: Node3D, kind: String, s: Vector3, c: Color, rng: RandomNumberGenerator) -> void:
	var w := s.x
	var h := s.y
	var d := s.z
	match kind:
		"sofa":
			Build.box(n, Vector3(w, 0.4, d), Vector3(0, 0.2, 0), c)
			Build.box(n, Vector3(w, 0.5, 0.22), Vector3(0, 0.6, -d * 0.5 + 0.11), c.darkened(0.08))
			for x: float in [-1.0, 1.0]:
				Build.box(n, Vector3(0.2, 0.58, d), Vector3(x * (w * 0.5 - 0.1), 0.29, 0), c.darkened(0.15))
				Build.box(n, Vector3(w * 0.5 - 0.26, 0.12, d - 0.34), Vector3(x * (w * 0.25 - 0.06), 0.46, 0.08), c.lightened(0.12))
		"tv":
			Build.box(n, Vector3(w, 0.45, d), Vector3(0, 0.225, 0), WOOD, "wood")
			Build.box(n, Vector3(0.78, 0.56, 0.42), Vector3(0, 0.73, 0), Color("2b2b33"))
			Build.glow(n, Vector3(0.56, 0.4, 0.02), Vector3(-0.07, 0.75, 0.215), Color("5d7f8c"), 0.5)
			for x: float in [-1.0, 1.0]:
				Build.box(n, Vector3(0.015, 0.4, 0.015), Vector3(x * 0.12, 1.2, -0.05), Color("b0b0b4")).rotation.z = -x * 0.5
		"phone":
			Build.box(n, Vector3(w, 0.04, d), Vector3(0, 0.7, 0), WOOD, "wood")
			for x: float in [-1.0, 1.0]:
				for z: float in [-1.0, 1.0]:
					Build.box(n, Vector3(0.05, 0.7, 0.05), Vector3(x * (w * 0.5 - 0.05), 0.35, z * (d * 0.5 - 0.05)), WOOD.darkened(0.2))
			Build.box(n, Vector3(0.24, 0.09, 0.2), Vector3(0, 0.765, 0), Color("b5352b"))
			Build.box(n, Vector3(0.28, 0.05, 0.07), Vector3(0, 0.835, 0), Color("9c2b23"))
		"desk":
			Build.box(n, Vector3(w, 0.06, d), Vector3(0, 0.77, 0), c, "wood")
			for x: float in [-1.0, 1.0]:
				Build.box(n, Vector3(0.42, 0.74, d - 0.08), Vector3(x * (w * 0.5 - 0.23), 0.37, 0), c.darkened(0.12))
				for y: float in [0.2, 0.45, 0.65]:
					Build.box(n, Vector3(0.12, 0.03, 0.02), Vector3(x * (w * 0.5 - 0.23), y, d * 0.5 - 0.03), Color("c9a44a"))
			Build.box(n, Vector3(0.36, 0.13, 0.3), Vector3(-0.25, 0.86, -0.05), Color("3a4038"))
			Build.box(n, Vector3(0.3, 0.02, 0.22), Vector3(0.3, 0.81, 0.05), Color("efe9d2"))
			_lamp(house, n, Vector3(w * 0.5 - 0.15, 0.8, -d * 0.5 + 0.15))
			_chair(n, Vector3(0, 0, d * 0.5 + 0.3), 0.0)
		"cabinet":
			Build.box(n, Vector3(w, h, d), Vector3(0, h * 0.5, 0), c)
			for i in 4:
				var y := 0.2 + i * (h - 0.1) / 4.0
				Build.box(n, Vector3(w - 0.08, 0.02, 0.02), Vector3(0, y + 0.14, d * 0.5 + 0.005), c.darkened(0.3))
				Build.box(n, Vector3(0.14, 0.03, 0.03), Vector3(0, y, d * 0.5 + 0.015), Color("d8d8dc"))
		"shelf":
			Build.box(n, Vector3(w, h, 0.05), Vector3(0, h * 0.5, -d * 0.5 + 0.025), c.darkened(0.2))
			for x: float in [-1.0, 1.0]:
				Build.box(n, Vector3(0.05, h, d), Vector3(x * (w * 0.5 - 0.025), h * 0.5, 0), c)
			for i in 5:
				var y := i * (h - 0.05) / 4.0 + 0.025
				Build.box(n, Vector3(w, 0.04, d), Vector3(0, y, 0), c)
				if i < 4:
					var x := -w * 0.5 + 0.08
					while x < w * 0.5 - 0.14:
						var bw := rng.randf_range(0.06, 0.13)
						var bh := rng.randf_range(0.24, 0.36)
						if rng.randf() < 0.85:
							Build.box(n, Vector3(bw, bh, d * 0.7), Vector3(x + bw * 0.5, y + 0.02 + bh * 0.5, 0.02), BOOKS[rng.randi() % BOOKS.size()])
						x += bw + 0.01
		"fridge":
			Build.box(n, Vector3(w, h, d), Vector3(0, h * 0.5, 0), c)
			Build.box(n, Vector3(w + 0.01, 0.02, d + 0.01), Vector3(0, h * 0.68, 0), c.darkened(0.25))
			for y: float in [h * 0.45, h * 0.82]:
				Build.box(n, Vector3(0.04, 0.3, 0.04), Vector3(-w * 0.5 + 0.1, y, d * 0.5 + 0.02), Color("b8b8bc"))
		"counter":
			Build.box(n, Vector3(w, 0.86, d - 0.04), Vector3(0, 0.43, -0.02), Color("a88e62"), "wood")
			Build.box(n, Vector3(w + 0.04, 0.05, d + 0.04), Vector3(0, 0.885, 0), Color("d9d4c7"))
			Build.box(n, Vector3(0.5, 0.02, 0.36), Vector3(-w * 0.22, 0.915, 0), Color("9aa0a6"))
			Build.box(n, Vector3(0.03, 0.2, 0.03), Vector3(-w * 0.22, 1.0, -d * 0.5 + 0.1), Color("c8c8cc"))
			if house.plain:
				return
			Build.box(n, Vector3(0.62, 0.9, d), Vector3(w * 0.5 - 0.33, 0.45, 0), Color("e6e2d6"))
			Build.box(n, Vector3(0.6, 0.02, d - 0.04), Vector3(w * 0.5 - 0.33, 0.915, 0), Color("2c2c30"))
			for x: float in [-0.14, 0.14]:
				for z: float in [-0.14, 0.14]:
					Build.cyl(n, 0.09, 0.015, Vector3(w * 0.5 - 0.33 + x, 0.93, z), Color("55555a"))
			for i in 3:
				Build.box(n, Vector3(0.1, 0.03, 0.02), Vector3(-w * 0.5 + 0.3 + i * 0.45, 0.6, d * 0.5 - 0.03), Color("c9a44a"))
		"table":
			Build.box(n, Vector3(w, 0.05, d), Vector3(0, 0.755, 0), c, "wood")
			for x: float in [-1.0, 1.0]:
				for z: float in [-1.0, 1.0]:
					Build.box(n, Vector3(0.07, 0.73, 0.07), Vector3(x * (w * 0.5 - 0.08), 0.365, z * (d * 0.5 - 0.08)), c.darkened(0.2))
			if house.plain:
				return
			_chair(n, Vector3(-w * 0.2, 0, d * 0.5 + 0.22), 0.0)
			_chair(n, Vector3(w * 0.2, 0, -d * 0.5 - 0.22), PI)
			Build.cyl(n, 0.13, 0.08, Vector3(0, 0.82, 0), Color("c9b25a"))
		"tub":
			Build.box(n, Vector3(w, h, d), Vector3(0, h * 0.5, 0), c)
			Build.box(n, Vector3(w - 0.16, 0.02, d - 0.16), Vector3(0, h + 0.005, 0), Color("9cc4d4"))
			Build.box(n, Vector3(0.05, 0.25, 0.05), Vector3(0, h + 0.12, -d * 0.5 + 0.08), Color("c8c8cc"))
		"toilet":
			Build.box(n, Vector3(w - 0.1, 0.4, d - 0.12), Vector3(0, 0.2, 0.06), c)
			Build.box(n, Vector3(w, 0.4, 0.2), Vector3(0, 0.6, -d * 0.5 + 0.1), c)
			Build.box(n, Vector3(w - 0.08, 0.04, d - 0.14), Vector3(0, 0.42, 0.06), c.darkened(0.08))
		"bed":
			Build.box(n, Vector3(w, 0.3, d), Vector3(0, 0.15, 0), WOOD, "wood")
			Build.box(n, Vector3(w - 0.06, 0.2, d - 0.06), Vector3(0, 0.4, 0), Color("ece8dc"))
			Build.box(n, Vector3(w, 0.07, d * 0.62), Vector3(0, 0.52, d * 0.19), c)
			Build.box(n, Vector3(w, 0.03, 0.14), Vector3(0, 0.56, -d * 0.12), c.lightened(0.25))
			Build.box(n, Vector3(w, 0.95, 0.08), Vector3(0, 0.475, -d * 0.5 + 0.04), WOOD.darkened(0.15), "wood")
			var pillows: Array = [-0.36, 0.36] if w > 1.3 else [0.0]
			for x: float in pillows:
				Build.box(n, Vector3(0.6, 0.12, 0.38), Vector3(x, 0.55, -d * 0.5 + 0.34), Color("f6f3ea"))
		"dresser":
			Build.box(n, Vector3(w, h, d), Vector3(0, h * 0.5, 0), c, "wood")
			for i in 3:
				var y := 0.2 + i * 0.3
				Build.box(n, Vector3(w - 0.08, 0.02, 0.02), Vector3(0, y + 0.16, d * 0.5 + 0.005), c.darkened(0.3))
				for x: float in [-0.3, 0.3]:
					Build.box(n, Vector3(0.05, 0.04, 0.03), Vector3(x, y, d * 0.5 + 0.015), Color("c9a44a"))
			_lamp(house, n, Vector3(w * 0.5 - 0.2, h, 0))
			Build.box(n, Vector3(0.22, 0.26, 0.03), Vector3(-w * 0.25, h + 0.13, -0.05), Color("3a2c22"))
		"radio":
			Build.box(n, Vector3(w, 0.72, d), Vector3(0, 0.36, 0), WOOD, "wood")
			Build.box(n, Vector3(0.52, 0.26, 0.32), Vector3(0, 0.85, 0), Color("2a2e27"))
			Build.glow(n, Vector3(0.2, 0.08, 0.01), Vector3(-0.1, 0.9, 0.165), Color("e8c45a"), 1.2)
			for x: float in [0.08, 0.18]:
				Build.cyl(n, 0.03, 0.03, Vector3(x, 0.84, 0.17), Color("8a8a8e")).rotation.x = PI * 0.5
			Build.box(n, Vector3(0.012, 0.6, 0.012), Vector3(0.22, 1.28, -0.1), Color("b0b0b4"))
			Build.box(n, Vector3(0.18, 0.05, 0.14), Vector3(-0.2, 1.005, 0.02), Color("1a1a1c"))
		"darkroom":
			Build.box(n, Vector3(w, 0.05, d), Vector3(0, 0.875, 0), Color("4a4d52"))
			Build.box(n, Vector3(w - 0.1, 0.85, d - 0.08), Vector3(0, 0.425, 0), Color("5a4a3a"), "wood")
			for i in 3:
				Build.box(n, Vector3(0.3, 0.04, 0.24), Vector3(-w * 0.5 + 0.25 + i * 0.36, 0.92, 0.08), [Color("d9d4c7"), Color("b9c4c9"), Color("c9b9a8")][i])
			Build.box(n, Vector3(0.05, 0.6, 0.05), Vector3(w * 0.5 - 0.2, 1.2, -d * 0.5 + 0.12), Color("2a2a2c"))
			Build.box(n, Vector3(0.2, 0.16, 0.2), Vector3(w * 0.5 - 0.2, 1.42, -d * 0.5 + 0.24), Color("2a2a2c"))
			Build.glow(n, Vector3(0.1, 0.1, 0.1), Vector3(-w * 0.5 + 0.12, 1.25, -d * 0.5 + 0.1), Color("c0281e"), 2.5)
		"stash":
			Build.box(n, Vector3(w, 0.05, d), Vector3(0, 0.03, 0), Color("86694a"), "planks")
			Build.box(n, Vector3(0.08, 0.02, 0.03), Vector3(0, 0.065, d * 0.5 - 0.08), Color("3a3a3c"))
		_:
			Build.box(n, Vector3(w, h, d), Vector3(0, h * 0.5, 0), c)


static func _chair(n: Node3D, at: Vector3, turn: float) -> void:
	var ch := Node3D.new()
	ch.position = at
	ch.rotation.y = turn
	n.add_child(ch)
	Build.box(ch, Vector3(0.4, 0.05, 0.4), Vector3(0, 0.45, 0), WOOD)
	Build.box(ch, Vector3(0.4, 0.5, 0.05), Vector3(0, 0.72, 0.18), WOOD.darkened(0.1))
	for x: float in [-0.16, 0.16]:
		for z: float in [-0.16, 0.16]:
			Build.box(ch, Vector3(0.04, 0.45, 0.04), Vector3(x, 0.225, z), WOOD.darkened(0.25))


static func _lamp(house: House, n: Node3D, at: Vector3) -> void:
	Build.cyl(n, 0.05, 0.22, at + Vector3.UP * 0.11, Color("8a6a3a"))
	house.add_bulb(Build.cyl(n, 0.13, 0.18, at + Vector3.UP * 0.3, Color("e8dcc0"), 0.08))
