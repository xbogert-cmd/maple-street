class_name Street
extends Node3D
## Builds the whole map from a Cast: road, twelve lots with houses and gardens, the park at the
## east end, the market and plant bus stop at the west end. Also bakes the navmesh neighbours
## walk on.

const LOT_W := 20.0
const PER_SIDE := 6
const ROAD_HALF := 4.0
const WALK := 6.0          # outer edge of the sidewalk
const FRONT := 11.0        # house fronts
const BACK := 32.0         # back fences
const X0 := -40.0
const X1 := 160.0
const ACCENTS: Array[String] = ["5c3a26", "7a2e2a", "2f4a63", "3d5a3a", "2c2c30", "8a6a2a", "5a3a5c"]
const FLOWERS: Array[String] = ["e2574c", "f2c94c", "f4f1e6", "c77dff", "ff9f6b"]

var cast: Dictionary
var houses: Array[House] = []
var home: House
var outdoor: Array[Dictionary] = []     # mailboxes and trash cans (same shape as House.furn)
var cars: Array[Node3D] = []            # one per lot (null if none)
var drops: Array[Dictionary] = []       # dead drops: {name, pos}
var bus_stop := Vector3(-9, 0, 5.2)
var shop_door := Vector3(-20, 0, -9.2)
var exit_west := Vector3(X0 + 2, 0, 5.0)
var park_center := Vector3(140, 0, 0)
var nav: NavigationRegion3D
var plant: House                        # the workplace, far off the street
var crowns: Array[Node3D] = []          # tree tops, hidden when they would cover the player
var _lamps: Array[OmniLight3D] = []
var _lamp_heads: Array[MeshInstance3D] = []
var _night_fx: Array[CPUParticles3D] = []   # moths and fireflies
var _shop_glass: Array[MeshInstance3D] = []
var _shafts: Array[MeshInstance3D] = []
var _rng := RandomNumberGenerator.new()


func build(c: Dictionary) -> void:
	cast = c
	_rng.seed = int(c.seed) + 7
	nav = NavigationRegion3D.new()
	add_child(nav)
	_ground()
	for h: Dictionary in c.houses:
		_lot(h)
	home = houses[c.home]
	home.is_home = true
	_park()
	_west_end()
	_lamps_row()
	_poles()
	plant = House.new()
	plant.tpl = Templates.PLANT.duplicate(true)
	plant.family = "plant"
	plant.plain = true
	plant.wall_color = Color("b8bcc0")
	nav.add_child(plant)
	plant.position = Vector3(40, 0, -320)
	plant.build()
	plant.set_cutaway(true)
	plant.set_lit(true)
	Build.solid(nav, Vector3(40, 1.0, 26), Vector3(52, -0.5, -314), Build.L_WALL)
	Build.box(self, Vector3(120, 0.02, 100), Vector3(52, -0.03, -314), Color("3f4347"), "asphalt")


static func lot_side(i: int) -> float:
	return -1.0 if i < PER_SIDE else 1.0


static func lot_x(i: int) -> float:
	return (i % PER_SIDE) * LOT_W


## Lot index for a position, or -1 on the road, sidewalk, park or west end.
func lot_at(p: Vector3) -> int:
	if p.x < 0.0 or p.x >= PER_SIDE * LOT_W or absf(p.z) <= WALK or absf(p.z) > BACK:
		return -1
	return int(p.x / LOT_W) + (0 if p.z < 0.0 else PER_SIDE)


func house_at(p: Vector3) -> House:
	var i := lot_at(p)
	if i >= 0 and houses[i].contains(p):
		return houses[i]
	return null


func in_park(p: Vector3) -> bool:
	return p.x > PER_SIDE * LOT_W + 2.0


func _ground() -> void:
	var cx := (X0 + X1) * 0.5
	var span := X1 - X0
	Build.solid(nav, Vector3(span, 1.0, 80), Vector3(cx, -0.5, 0), Build.L_WALL)
	Build.box(self, Vector3(span + 80, 0.02, 160), Vector3(cx, -0.02, 0), Color("4a6e3c"), "grass")
	# the road runs on west past the edge of the map, toward town and the plant
	var road := span + 60.0
	var rx := cx - 30.0
	Build.box(self, Vector3(road, 0.03, ROAD_HALF * 2), Vector3(rx, 0.0, 0), Color("44464b"), "asphalt")
	for s: float in [-1.0, 1.0]:
		Build.box(self, Vector3(road, 0.07, WALK - ROAD_HALF - 0.2), Vector3(rx, 0.03, s * (ROAD_HALF + WALK + 0.2) * 0.5), Color("b3b0a6"), "concrete")
		Build.box(self, Vector3(road, 0.1, 0.2), Vector3(rx, 0.04, s * (ROAD_HALF + 0.1)), Color("c9c6bc"))
	var x := X0 - 58.0
	while x < X1:
		Build.box(self, Vector3(2.0, 0.035, 0.15), Vector3(x, 0.0, 0), Color("d8cf9a"))
		x += 5.0
	for cross: float in [-3.0, 121.5]:
		for i in 7:
			Build.box(self, Vector3(1.6, 0.036, 0.5), Vector3(cross, 0.0, -3.3 + i * 1.1), Color("e6e3d8"))
	for dx: float in [15.0, 55.0, 95.0]:
		for s: float in [-1.0, 1.0]:
			Build.box(self, Vector3(0.8, 0.05, 0.3), Vector3(dx, 0.0, s * (ROAD_HALF - 0.2)), Color("1e1f22"))
	# map edges
	for e: Array in [[Vector3(span, 3, 0.5), Vector3(cx, 1.5, -36)], [Vector3(span, 3, 0.5), Vector3(cx, 1.5, 36)], [Vector3(0.5, 3, 72), Vector3(X0, 1.5, 0)], [Vector3(0.5, 3, 72), Vector3(X1, 1.5, 0)]]:
		Build.solid(nav, e[0], e[1], Build.L_LOW)


func _lot(h: Dictionary) -> void:
	var i: int = h.lot
	var s := lot_side(i)
	var x0 := lot_x(i)
	Build.box(self, Vector3(LOT_W - 0.1, 0.03, BACK - WALK), Vector3(x0 + LOT_W * 0.5, 0.0, s * (BACK + WALK) * 0.5), Color("5f8a4a").lerp(Color("70a055"), _rng.randf()), "grass")
	var house := House.new()
	house.tpl = Templates.make(h.tpl, h.mirror)
	house.index = i
	house.family = h.family
	house.wall_color = Color(h.wall)
	house.roof_color = Color(h.roof)
	house.accent = Color(ACCENTS[_rng.randi() % ACCENTS.size()])
	nav.add_child(house)
	var w: float = house.tpl.w
	var d: float = house.tpl.d
	if s < 0.0:
		house.position = Vector3(x0 + 1.5, 0, -FRONT - d)
	else:
		house.position = Vector3(x0 + 1.5 + w, 0, FRONT + d)
		house.rotation.y = PI
	house.build()
	houses.append(house)
	# front path
	var fp := house.portal("front").outside_pos
	Build.box(self, Vector3(1.2, 0.05, absf(fp.z) - WALK - 0.6), Vector3(fp.x, 0.01, s * (absf(fp.z) + WALK - 0.6) * 0.5), Color("b7b2a6"), "concrete")
	# flower beds and shrubs along the front of the house
	for side: float in [-1.0, 1.0]:
		var from := fp.x + side * 1.5
		var to := (x0 + 1.9) if side < 0.0 else (x0 + 1.1 + w)
		if absf(to - from) < 1.2:
			continue
		var bx := (from + to) * 0.5
		Build.box(self, Vector3(absf(to - from), 0.1, 0.7), Vector3(bx, 0.04, s * (FRONT - 0.5)), Color("4a3626"))
		var fx := minf(from, to) + 0.3
		while fx < maxf(from, to) - 0.2:
			if _rng.randf() < 0.3:
				Build.leaf(self, 0.42, 0.7, Vector3(fx, 0.38, s * (FRONT - 0.5)), Color("3d6b3a").lerp(Color("5a8a45"), _rng.randf()), false)
				fx += 0.9
			else:
				Build.box(self, Vector3(0.04, 0.3, 0.04), Vector3(fx, 0.2, s * (FRONT - 0.5)), Color("4f7a3f"))
				Build.box(self, Vector3(0.16, 0.12, 0.16), Vector3(fx, 0.4, s * (FRONT - 0.5)), Color(FLOWERS[_rng.randi() % FLOWERS.size()]))
				fx += 0.4
	# driveway and car
	Build.box(self, Vector3(3.6, 0.05, 11.2 - WALK + 3.0), Vector3(x0 + 17.4, 0.01, s * (WALK + 4.1)), Color("9a978f"), "concrete")
	var car: Node3D = null
	if not h.people.is_empty() or i == cast.home:
		car = _car(Color(h.car), _rng.randf() < 0.35)
		car.position = Vector3(x0 + 17.4, 0, s * 11.0)
		car.rotation.y = 0.0 if s < 0.0 else PI
		nav.add_child(car)
	cars.append(car)
	# mailbox and trash can
	var mb := Vector3(x0 + 14.6, 0, s * (WALK + 0.4))
	Build.box(self, Vector3(0.1, 1.0, 0.1), mb + Vector3.UP * 0.5, Color("5a4a3a"))
	Build.box(self, Vector3(0.03, 0.18, 0.1), mb + Vector3(0.17, 1.2, 0.1), Color("c0392b"))
	_outdoor("mailbox", "Mailbox", Vector3(0.3, 0.25, 0.5), mb + Vector3.UP * 1.1, Color("3c5a8a"), house)
	var tc := Vector3(x0 + 19.4, 0, s * 9.0)
	Build.cyl(self, 0.3, 0.8, tc + Vector3.UP * 0.4, Color("7a8480"), 0.34, 10)
	Build.cyl(self, 0.36, 0.08, tc + Vector3.UP * 0.84, Color("5c6660"), -1.0, 10)
	Build.solid(nav, Vector3(0.6, 0.9, 0.6), tc + Vector3.UP * 0.45, Build.L_LOW)
	_outdoor("trash", "Trash can", Vector3(0.6, 0.9, 0.6), tc, Color("5c6660"), house, false)
	# hedge on the lot line (back two thirds) and the back fence
	if i % PER_SIDE > 0:
		_wall_box(Vector3(0.8, 1.5, BACK - 15.0), Vector3(x0, 0.75, s * (BACK + 15.0) * 0.5), Color("3f6a3a"), "leaf")
	_wall_box(Vector3(LOT_W, 1.7, 0.12), Vector3(x0 + LOT_W * 0.5, 0.85, s * BACK), Color("8a7458"), "planks")
	for px in 6:
		Build.box(self, Vector3(0.16, 1.85, 0.2), Vector3(x0 + px * 4.0, 0.92, s * BACK), Color("6e5c46"))
	# a low rail fence along some front yards, open at the path and the drive
	if _rng.randf() < 0.45:
		var fz := s * (WALK + 0.35)
		var px := x0 + 0.6
		while px < x0 + 14.0:
			if absf(px - fp.x) > 1.0:
				Build.box(self, Vector3(0.09, 0.85, 0.09), Vector3(px, 0.42, fz), House.TRIM)
				if absf(px + 1.0 - fp.x) > 1.0 and px + 1.0 < x0 + 14.0:
					for ry: float in [0.35, 0.7]:
						Build.box(self, Vector3(1.0, 0.07, 0.05), Vector3(px + 0.5, ry, fz), House.TRIM)
			px += 1.0
	_tree(Vector3(x0 + _rng.randf_range(3.0, 13.0), 0, s * _rng.randf_range(7.5, 9.0)))
	if _rng.randf() < 0.6:
		_tree(Vector3(x0 + _rng.randf_range(4.0, 12.0), 0, s * _rng.randf_range(26.0, 30.0)))
	_back_yard(h, x0, s)


## Each back yard gets a couple of things from a small set: shed, washing line, vegetable patch,
## barbecue, and a kennel or toys where a dog or a child lives.
func _back_yard(h: Dictionary, x0: float, s: float) -> void:
	if _rng.randf() < 0.55:
		var p := Vector3(x0 + 17.0, 0, s * 29.0)
		_wall_box(Vector3(2.4, 2.0, 2.4), p + Vector3.UP * 1.0, Color("7a5a3c"), "planks")
		var roof := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(2.8, 0.8, 2.8)
		pm.material = Build.mat(Color("4d5560"), 0.0, "shingle")
		roof.mesh = pm
		roof.position = p + Vector3.UP * 2.4
		add_child(roof)
		Build.box(self, Vector3(0.8, 1.6, 0.06), p + Vector3(-0.3, 0.8, -s * 1.22), Color("5a4330"))
	if _rng.randf() < 0.45:
		var p := Vector3(x0 + 4.0, 0, s * 25.0)
		for e: float in [0.0, 5.0]:
			Build.box(self, Vector3(0.08, 1.9, 0.08), p + Vector3(e, 0.95, 0), Color("c9c6bc"))
			Build.box(self, Vector3(0.08, 0.06, 1.0), p + Vector3(e, 1.85, 0), Color("c9c6bc"))
		Build.box(self, Vector3(5.0, 0.02, 0.02), p + Vector3(2.5, 1.84, 0), Color("e6e3d8"))
		for k in 3:
			Build.box(self, Vector3(_rng.randf_range(0.7, 1.2), _rng.randf_range(0.6, 1.0), 0.03), p + Vector3(0.9 + k * 1.5, 1.4, 0), Color(Cast.SHIRTS[_rng.randi() % Cast.SHIRTS.size()]).lightened(0.3))
	if _rng.randf() < 0.4:
		var p := Vector3(x0 + 9.0, 0, s * 30.0)
		Build.box(self, Vector3(4.0, 0.1, 2.0), p + Vector3.UP * 0.04, Color("4a3626"))
		for r in 3:
			for k in 6:
				Build.leaf(self, 0.16, 0.3, p + Vector3(-1.6 + k * 0.64, 0.22, -0.6 + r * 0.6), Color("4f8a3f").lerp(Color("7aa04a"), _rng.randf()), false)
	if h.dog:
		var p := Vector3(x0 + 2.6, 0, s * 29.5)
		Build.box(self, Vector3(1.0, 0.8, 1.2), p + Vector3.UP * 0.4, Color("8a5a3c"), "planks")
		Build.box(self, Vector3(0.5, 0.55, 0.05), p + Vector3(0, 0.28, -s * 0.6), Color("1c1612"))
		Build.box(self, Vector3(1.2, 0.1, 1.4), p + Vector3.UP * 0.86, Color("7a3b33"))
		Build.cyl(self, 0.16, 0.08, p + Vector3(0.9, 0.04, -s * 0.5), Color("b0b0b4"))
	for p: Dictionary in h.people:
		if p.job == "school":
			var at := Vector3(x0 + 7.0, 0, s * 24.0)
			Build.leaf(self, 0.22, 0.44, at + Vector3.UP * 0.22, Color("e2574c"), false)
			Build.box(self, Vector3(0.9, 0.5, 0.35), at + Vector3(1.6, 0.25, 0.6), Color("c0392b"))
			for wx: float in [-0.35, 0.35]:
				Build.cyl(self, 0.14, 0.06, at + Vector3(1.6 + wx, 0.14, 0.8), Color("1c1c1e")).rotation.x = PI * 0.5
			break


func _outdoor(kind: String, title: String, size: Vector3, pos: Vector3, color: Color, house: House, draw := true) -> void:
	var node: Node3D = Build.box(self, size, pos, color) if draw else null
	outdoor.append({"kind": kind, "name": title, "node": node, "size": size, "pos": Vector3(pos.x, 0, pos.z), "items": [], "locked": false, "disturbed": false, "house": house, "bug": false})


func _wall_box(size: Vector3, pos: Vector3, color: Color, pattern := "") -> void:
	Build.box(self, size, pos, color, pattern)
	Build.solid(nav, size, pos, Build.L_WALL)


## A pine, a broad oak or a small blossom tree. The top goes in `crowns` so it can be hidden.
func _tree(p: Vector3, kind := -1) -> void:
	var k: int = kind if kind >= 0 else [0, 0, 1, 1, 1, 2][_rng.randi() % 6]
	var crown := Node3D.new()
	crown.position = p
	add_child(crown)
	crowns.append(crown)
	var green := Color("35602f").lerp(Color("5a8a45"), _rng.randf())
	match k:
		0:
			var h := _rng.randf_range(4.5, 6.5)
			Build.cyl(self, 0.2, h * 0.4, p + Vector3.UP * h * 0.2, Color("5a4330"), 0.14, 6)
			for t in 3:
				Build.leaf(crown, 1.7 - t * 0.42, h * 0.38, Vector3(0, h * (0.42 + t * 0.2), 0), green.darkened(0.1).lerp(green.lightened(0.12), t / 2.0))
		1:
			var h := _rng.randf_range(3.2, 4.4)
			Build.cyl(self, 0.26, h, p + Vector3.UP * h * 0.5, Color("5a4330"), 0.18, 6)
			Build.leaf(crown, 1.9, 2.8, Vector3(0, h + 0.9, 0), green, false)
			Build.leaf(crown, 1.3, 2.0, Vector3(1.1, h + 0.4, 0.5), green.darkened(0.08), false)
			Build.leaf(crown, 1.2, 1.9, Vector3(-1.0, h + 0.6, -0.4), green.lightened(0.08), false)
			Build.leaf(crown, 1.1, 1.6, Vector3(0.1, h + 1.9, -0.2), green.lightened(0.14), false)
		_:
			var h := _rng.randf_range(2.0, 2.6)
			Build.cyl(self, 0.12, h, p + Vector3.UP * h * 0.5, Color("6a5040"), 0.09, 6)
			var bloom: Color = [Color("e8a8b8"), Color("f0d890"), Color("d8e0a0")][_rng.randi() % 3]
			Build.leaf(crown, 1.1, 1.7, Vector3(0, h + 0.5, 0), bloom, false)
			Build.leaf(crown, 0.7, 1.1, Vector3(0.5, h + 0.9, 0.3), bloom.lightened(0.1), false)
	Build.solid(nav, Vector3(0.5, 3.0, 0.5), p + Vector3.UP * 1.5, Build.L_WALL)


## A boxy 1980s sedan, or a station wagon. Front of the car is +z.
func _car(color: Color, wagon := false) -> Node3D:
	var car := Node3D.new()
	var glass := Color("27323c")
	var chrome := Color("c8cace")
	Build.box(car, Vector3(1.8, 0.5, 4.5), Vector3(0, 0.62, 0), color)
	Build.box(car, Vector3(1.82, 0.08, 4.52), Vector3(0, 0.42, 0), color.darkened(0.35))
	var cab_len := 2.9 if wagon else 2.0
	var cab_z := -0.65 if wagon else -0.25
	Build.box(car, Vector3(1.62, 0.5, cab_len), Vector3(0, 1.1, cab_z), color.darkened(0.06))
	Build.box(car, Vector3(1.5, 0.05, cab_len - 0.2), Vector3(0, 1.36, cab_z), color.darkened(0.12))
	Build.box(car, Vector3(1.64, 0.34, cab_len - 0.5), Vector3(0, 1.1, cab_z), glass)
	Build.box(car, Vector3(1.4, 0.34, cab_len + 0.02), Vector3(0, 1.1, cab_z), glass)
	for end: float in [-1.0, 1.0]:
		Build.box(car, Vector3(1.86, 0.14, 0.14), Vector3(0, 0.46, end * 2.28), chrome)
		for sx: float in [-1.0, 1.0]:
			var lamp := Color("f4ecc0") if end > 0.0 else Color("b02a22")
			Build.box(car, Vector3(0.34, 0.16, 0.05), Vector3(sx * 0.62, 0.7, end * 2.26), lamp)
			var wheel := Build.cyl(car, 0.33, 0.22, Vector3(sx * 0.86, 0.33, end * 1.4), Color("1c1c1e"), -1.0, 10)
			wheel.rotation.z = PI * 0.5
			var hub := Build.cyl(car, 0.16, 0.24, Vector3(sx * 0.86, 0.33, end * 1.4), chrome, -1.0, 8)
			hub.rotation.z = PI * 0.5
	Build.box(car, Vector3(1.0, 0.16, 0.05), Vector3(0, 0.7, 2.26), Color("2a2a2c"))
	Build.solid(car, Vector3(1.8, 1.4, 4.4), Vector3(0, 0.7, 0), Build.L_WALL)
	return car


func _bench(p: Vector3, turn := 0.0) -> void:
	var b := Node3D.new()
	b.position = p
	b.rotation.y = turn
	add_child(b)
	Build.box(b, Vector3(1.8, 0.07, 0.5), Vector3(0, 0.45, 0), Color("6b4a2e"), "wood")
	Build.box(b, Vector3(1.8, 0.45, 0.07), Vector3(0, 0.75, -0.24), Color("6b4a2e"), "wood")
	for x: float in [-0.75, 0.75]:
		Build.box(b, Vector3(0.08, 0.45, 0.5), Vector3(x, 0.22, 0), Color("2c2c30"))
	Build.solid(nav, Vector3(1.8, 0.5, 0.5).rotated(Vector3.UP, turn).abs(), p + Vector3.UP * 0.25, Build.L_LOW)


func _park_lamp(p: Vector3) -> void:
	Build.cyl(self, 0.06, 3.0, p + Vector3.UP * 1.5, Color("2c3036"))
	_lamp_heads.append(Build.box(self, Vector3(0.36, 0.36, 0.36), p + Vector3.UP * 3.15, Color("cfc8b0")))
	Build.box(self, Vector3(0.5, 0.06, 0.5), p + Vector3.UP * 3.36, Color("2c3036"))
	_light(p + Vector3.UP * 3.0, 9.0, false)
	_shaft(p + Vector3.UP * 1.55, 2.2, 3.1)
	_moths(p + Vector3.UP * 3.0)


func _light(at: Vector3, reach: float, shadows: bool) -> void:
	var l := OmniLight3D.new()
	l.position = at
	l.omni_range = reach
	l.light_color = Color("ffe2a8")
	l.light_energy = 0.0
	l.shadow_enabled = shadows
	add_child(l)
	_lamps.append(l)


## A faint cone of light under a lamp, shown at night.
func _shaft(mid: Vector3, radius: float, height: float) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.15
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 10
	cm.cap_top = false
	cm.cap_bottom = false
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(1.0, 0.86, 0.6, 0.035)
	cm.material = m
	mi.mesh = cm
	mi.position = mid
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	add_child(mi)
	_shafts.append(mi)


## A few pale specks circling a lamp at night.
func _moths(at: Vector3) -> void:
	var m := CPUParticles3D.new()
	m.position = at
	m.amount = 6
	m.lifetime = 3.0
	m.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.6
	m.gravity = Vector3.ZERO
	m.orbit_velocity_min = 0.4
	m.orbit_velocity_max = 0.9
	m.initial_velocity_min = 0.2
	m.initial_velocity_max = 0.5
	m.spread = 180.0
	m.mesh = _speck(0.05, Color(1.0, 0.96, 0.8, 0.8))
	m.emitting = false
	add_child(m)
	_night_fx.append(m)


func _speck(size: float, color: Color) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size, size, size)
	var sm := StandardMaterial3D.new()
	sm.albedo_color = color
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = sm
	return mesh


func _park() -> void:
	var px := PER_SIDE * LOT_W
	Build.box(self, Vector3(X1 - px, 0.04, 72), Vector3((px + X1) * 0.5, 0.0, 0), Color("57804a"), "grass")
	Build.box(self, Vector3(X1 - px - 6, 0.05, 2.0), Vector3((px + X1) * 0.5, 0.01, 0), Color("b9b09a"), "gravel")
	Build.box(self, Vector3(2.0, 0.05, 50), Vector3(140, 0.01, 0), Color("b9b09a"), "gravel")
	# pond with a stone rim and reeds
	var pond := Vector3(150, 0, -18)
	Build.cyl(self, 6.4, 0.08, pond + Vector3.UP * 0.02, Color("8a8a84"), -1.0, 14)
	var water := Build.cyl(self, 6.0, 0.06, pond + Vector3.UP * 0.05, Color("3f6f8f"), -1.0, 14)
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color("3a6a8c")
	wm.roughness = 0.08
	wm.metallic = 0.3
	water.material_override = wm
	for k in 14:
		var a := _rng.randf() * TAU
		var at := pond + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(5.2, 6.2)
		if _rng.randf() < 0.5:
			Build.box(self, Vector3(_rng.randf_range(0.4, 0.9), 0.35, _rng.randf_range(0.4, 0.8)), at + Vector3.UP * 0.15, Color("7d7d78")).rotation.y = a
		else:
			for q in 3:
				Build.box(self, Vector3(0.04, _rng.randf_range(0.7, 1.2), 0.04), at + Vector3(q * 0.12, 0.45, 0), Color("5a7a3a"))
	Build.solid(nav, Vector3(9, 1, 9), pond + Vector3.UP * 0.5, Build.L_LOW)
	# fountain in a ring of flowers
	Build.cyl(self, 1.7, 0.5, Vector3(140, 0.25, 0), Color("a9a59b"), -1.0, 12)
	Build.cyl(self, 1.45, 0.06, Vector3(140, 0.5, 0), Color("4a7a9a"), -1.0, 12)
	Build.cyl(self, 0.25, 1.4, Vector3(140, 0.9, 0), Color("bfbbb0"))
	Build.cyl(self, 0.6, 0.12, Vector3(140, 1.55, 0), Color("bfbbb0"), 0.7)
	var spray := CPUParticles3D.new()
	spray.position = Vector3(140, 1.7, 0)
	spray.amount = 30
	spray.lifetime = 0.9
	spray.direction = Vector3.UP
	spray.spread = 25.0
	spray.initial_velocity_min = 2.2
	spray.initial_velocity_max = 3.0
	spray.gravity = Vector3(0, -7, 0)
	spray.mesh = _speck(0.07, Color(0.8, 0.9, 1.0, 0.7))
	add_child(spray)
	Build.solid(nav, Vector3(3.2, 1.0, 3.2), Vector3(140, 0.5, 0), Build.L_LOW)
	for k in 20:
		var a := k * TAU / 20.0
		if absf(sin(a)) < 0.3 or absf(cos(a)) < 0.3:
			continue
		var at := Vector3(140, 0, 0) + Vector3(cos(a), 0, sin(a)) * 3.2
		Build.box(self, Vector3(0.5, 0.1, 0.5), at + Vector3.UP * 0.05, Color("4a3626"))
		Build.box(self, Vector3(0.2, 0.25, 0.2), at + Vector3.UP * 0.22, Color(FLOWERS[k % FLOWERS.size()]))
	_bench(Vector3(132, 0, 2.2), PI)
	_bench(Vector3(148, 0, -2.2))
	_bench(Vector3(141.8, 0, 16), -PI * 0.5)
	for lp: Vector3 in [Vector3(128, 0, 1.6), Vector3(141.4, 0, -12), Vector3(141.4, 0, 11), Vector3(153, 0, 1.6)]:
		_park_lamp(lp)
	# playground: swings, a slide and a sandbox
	var pg := Vector3(130, 0, 18)
	Build.box(self, Vector3(9, 0.05, 7), pg + Vector3.UP * 0.02, Color("c9b48a"), "gravel")
	for e: float in [-1.5, 1.5]:
		for lean: float in [-1.0, 1.0]:
			Build.box(self, Vector3(0.08, 2.5, 0.08), pg + Vector3(-2 + e, 1.2, lean * 0.5), Color("c0392b")).rotation.x = lean * 0.22
	Build.box(self, Vector3(3.2, 0.09, 0.09), pg + Vector3(-2, 2.4, 0), Color("c0392b"))
	for sx: float in [-0.7, 0.7]:
		for c: float in [-0.2, 0.2]:
			Build.box(self, Vector3(0.02, 1.8, 0.02), pg + Vector3(-2 + sx + c, 1.5, 0), Color("8a8a8e"))
		Build.box(self, Vector3(0.5, 0.05, 0.22), pg + Vector3(-2 + sx, 0.6, 0), Color("2c2c30"))
	Build.box(self, Vector3(0.7, 0.06, 3.0), pg + Vector3(2.4, 0.95, 0.6), Color("d8a53a")).rotation.x = 0.55
	Build.box(self, Vector3(0.8, 1.8, 0.8), pg + Vector3(2.4, 0.9, -1.0), Color("3b5d8a"))
	Build.box(self, Vector3(2.4, 0.2, 2.4), pg + Vector3(0.3, 0.1, -2.2), Color("8a6a4a"))
	Build.box(self, Vector3(2.1, 0.22, 2.1), pg + Vector3(0.3, 0.1, -2.2), Color("e2cf9a"), "gravel")
	Build.solid(nav, Vector3(3.4, 2.5, 1.2), pg + Vector3(-2, 1.2, 0), Build.L_LOW)
	Build.solid(nav, Vector3(0.9, 1.8, 3.6), pg + Vector3(2.4, 0.9, 0.2), Build.L_LOW)
	var oak := Vector3(152, 0, 20)
	for t in 16:
		var p := Vector3(_rng.randf_range(px + 5, X1 - 4), 0, _rng.randf_range(-33, 33))
		if absf(p.z) < 3.0 or absf(p.x - 140) < 4.5 or p.distance_to(pond) < 8.5 or p.distance_to(oak) < 5.0 or p.distance_to(pg) < 7.0:
			continue
		_tree(p)
	# the old oak, with a hollow
	Build.cyl(self, 0.65, 3.2, oak + Vector3.UP * 1.6, Color("4a3626"), 0.5, 7)
	Build.box(self, Vector3(0.3, 0.45, 0.1), oak + Vector3(-0.6, 1.1, 0), Color("1a1410"))
	var top := Node3D.new()
	top.position = oak
	add_child(top)
	crowns.append(top)
	Build.leaf(top, 3.4, 4.4, Vector3(0, 5.0, 0), Color("2f5a2c"), false)
	Build.leaf(top, 2.3, 3.0, Vector3(2.0, 4.0, 0.8), Color("386634"), false)
	Build.leaf(top, 2.2, 3.0, Vector3(-1.8, 4.3, -0.9), Color("2b5228"), false)
	Build.leaf(top, 2.0, 2.6, Vector3(0.2, 6.6, -0.3), Color("3f7038"), false)
	Build.solid(nav, Vector3(1.2, 3.0, 1.2), oak + Vector3.UP * 1.5, Build.L_WALL)
	drops = [
		{"name": "the hollow oak", "pos": oak + Vector3(-1.2, 0, 0)},
		{"name": "the loose stone at the fountain", "pos": Vector3(140, 0, 2.3)},
		{"name": "under the far bench", "pos": Vector3(140.8, 0, 16.0)},
	]
	# fireflies over the grass at dusk
	var ff := CPUParticles3D.new()
	ff.position = Vector3(140, 1.0, 0)
	ff.amount = 40
	ff.lifetime = 5.0
	ff.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	ff.emission_box_extents = Vector3(18, 0.8, 30)
	ff.gravity = Vector3.ZERO
	ff.initial_velocity_min = 0.1
	ff.initial_velocity_max = 0.4
	ff.spread = 180.0
	ff.mesh = _speck(0.07, Color(0.85, 1.0, 0.45, 0.95))
	(ff.mesh.material as StandardMaterial3D).emission_enabled = true
	(ff.mesh.material as StandardMaterial3D).emission = Color(0.8, 1.0, 0.4)
	(ff.mesh.material as StandardMaterial3D).emission_energy_multiplier = 3.0
	ff.emitting = false
	add_child(ff)
	_night_fx.append(ff)


func _west_end() -> void:
	Build.box(self, Vector3(38, 0.04, 26), Vector3(-20, 0.0, -21), Color("5a5c60"), "asphalt")
	Build.box(self, Vector3(38, 0.04, 26), Vector3(-20, 0.0, 21), Color("57804a"), "grass")
	for k in 5:
		Build.box(self, Vector3(0.12, 0.045, 4.5), Vector3(-36 + k * 3.0, 0.0, -9.5), Color("e6e3d8"))
	for k in 2:
		var parked := _car(Color(Cast.SHIRTS[(k * 3 + 1) % Cast.SHIRTS.size()]), k == 1)
		parked.position = Vector3(-34.5 + k * 6.0, 0, -9.6)
		nav.add_child(parked)
	# Miller's Market: brick, striped awning, lit windows, crates out front
	_wall_box(Vector3(16, 4.0, 10), Vector3(-20, 2.0, -16), Color("a2674f"), "brick")
	Build.box(self, Vector3(16.5, 0.4, 10.5), Vector3(-20, 4.2, -16), Color("d9d4c7"))
	Build.box(self, Vector3(15.9, 0.1, 9.9), Vector3(-20, 4.4, -16), Color("6a6c70"), "gravel")
	Build.box(self, Vector3(2.2, 0.9, 1.6), Vector3(-16, 4.85, -18), Color("9aa0a6"))
	Build.box(self, Vector3(1.8, 0.1, 1.2), Vector3(-16, 5.33, -18), Color("5c6268"))
	Build.cyl(self, 0.25, 1.0, Vector3(-24, 4.9, -14), Color("8a8e92"))
	Build.box(self, Vector3(1.0, 0.6, 1.0), Vector3(-21, 4.7, -19), Color("8a8e92"))
	Build.box(self, Vector3(1.5, 2.3, 0.1), Vector3(-20, 1.15, -10.95), Color("3a2c22"))
	Build.box(self, Vector3(1.1, 1.2, 0.12), Vector3(-20, 1.5, -10.94), Color(0.6, 0.75, 0.85, 0.6))
	for wx: float in [-24.5, -15.5]:
		_shop_glass.append(Build.box(self, Vector3(4.6, 1.6, 0.1), Vector3(wx, 1.7, -10.95), Color(0.6, 0.75, 0.85, 0.6)))
		Build.box(self, Vector3(4.8, 0.1, 0.2), Vector3(wx, 0.85, -10.9), House.TRIM)
	for k in 16:
		Build.box(self, Vector3(1.0, 0.08, 1.6), Vector3(-27.5 + k, 3.0, -10.3), Color("b03a2e") if k % 2 == 0 else Color("efe9da")).rotation.x = 0.35
	Build.label(self, "MILLER'S MARKET", Vector3(-20, 5.0, -11), 64).modulate = Color("f2e6c8")
	for k in 4:
		var cp := Vector3(-25.5 + k * 0.95, 0, -10.2)
		Build.box(self, Vector3(0.8, 0.5, 0.6), cp + Vector3.UP * 0.25, Color("8a6a4a"), "planks")
		for q in 3:
			Build.leaf(self, 0.13, 0.24, cp + Vector3(-0.25 + q * 0.25, 0.58, 0), [Color("d9432e"), Color("e89a2a"), Color("5a9a3a"), Color("e8d04a")][k], false)
	# telephone box
	var tb := Vector3(-10.5, 0, -8.0)
	Build.box(self, Vector3(1.0, 2.4, 1.0), tb + Vector3.UP * 1.2, Color(0.6, 0.75, 0.85, 0.35))
	Build.box(self, Vector3(1.1, 0.25, 1.1), tb + Vector3.UP * 2.5, Color("3b5d8a"))
	Build.box(self, Vector3(1.1, 0.12, 1.1), tb + Vector3.UP * 0.06, Color("3b5d8a"))
	Build.box(self, Vector3(0.3, 0.45, 0.15), tb + Vector3(0, 1.3, -0.38), Color("2a2a2c"))
	Build.solid(nav, Vector3(1.0, 2.4, 1.0), tb + Vector3.UP * 1.2, Build.L_LOW)
	_park_lamp(Vector3(-28, 0, -8.5))
	# plant bus shelter
	Build.box(self, Vector3(4.2, 0.08, 1.8), Vector3(-9, 2.45, 6.6), Color(0.3, 0.36, 0.42, 0.5))   # see-through, so you can find yourself under it
	Build.box(self, Vector3(4.0, 2.4, 0.08), Vector3(-9, 1.2, 7.35), Color(0.6, 0.75, 0.85, 0.25))
	for bx: float in [-10.9, -7.1]:
		Build.box(self, Vector3(0.1, 2.4, 0.1), Vector3(bx, 1.2, 5.9), Color("4d5a66"))
		Build.box(self, Vector3(0.08, 2.4, 1.4), Vector3(bx, 1.2, 6.65), Color(0.6, 0.75, 0.85, 0.3))
	Build.solid(nav, Vector3(4.0, 2.4, 0.2), Vector3(-9, 1.2, 7.35), Build.L_LOW)
	Build.box(self, Vector3(2.6, 0.08, 0.45), Vector3(-9, 0.45, 6.95), Color("6b4a2e"), "wood")
	Build.cyl(self, 0.05, 2.6, Vector3(-6.4, 1.3, 5.9), Color("8a8a8e"))
	Build.box(self, Vector3(0.6, 0.6, 0.04), Vector3(-6.4, 2.4, 5.9), Color("2f4a63"))
	Build.label(self, "PLANT BUS", Vector3(-9, 3.1, 6.6), 48).modulate = Color("f2e6c8")
	# stop sign and a hydrant
	Build.cyl(self, 0.05, 2.4, Vector3(-2.2, 1.2, -4.6), Color("8a8a8e"))
	Build.cyl(self, 0.38, 0.05, Vector3(-2.2, 2.4, -4.6), Color("c0281e"), -1.0, 8).rotation.z = PI * 0.5
	Build.cyl(self, 0.16, 0.6, Vector3(58, 0.3, 4.7), Color("c0392b"))
	Build.cyl(self, 0.2, 0.1, Vector3(58, 0.62, 4.7), Color("c0392b"), 0.08)
	Build.box(self, Vector3(0.5, 0.12, 0.12), Vector3(58, 0.4, 4.7), Color("a02a20"))
	for t in 7:
		_tree(Vector3(_rng.randf_range(-37, -3), 0, _rng.randf_range(12, 33)))


func _lamps_row() -> void:
	var x := -30.0
	var s := 1.0
	while x < X1 - 5:
		var p := Vector3(x, 0, s * (ROAD_HALF + 0.5))
		Build.cyl(self, 0.09, 0.5, p + Vector3.UP * 0.25, Color("2c3036"), 0.07)
		Build.cyl(self, 0.06, 5.4, p + Vector3.UP * 2.7, Color("3c4046"))
		Build.box(self, Vector3(0.07, 0.07, 1.5), p + Vector3(0, 5.4, -s * 0.7), Color("3c4046"))
		Build.box(self, Vector3(0.32, 0.14, 0.7), p + Vector3(0, 5.36, -s * 1.3), Color("3c4046"))
		_lamp_heads.append(Build.box(self, Vector3(0.24, 0.06, 0.56), p + Vector3(0, 5.27, -s * 1.3), Color("cfc8b0")))
		_light(p + Vector3(0, 5.0, -s * 1.3), 14.0, true)
		_shaft(p + Vector3(0, 2.6, -s * 1.3), 3.4, 5.2)
		_moths(p + Vector3(0, 4.9, -s * 1.3))
		x += 32.0
		s = -s


## Telephone poles and wires along the back of the north sidewalk.
func _poles() -> void:
	var prev := Vector3.ZERO
	var x := -36.0
	while x < 125.0:
		var p := Vector3(x, 0, -(BACK + 0.9))
		Build.cyl(self, 0.11, 7.0, p + Vector3.UP * 3.5, Color("5a4634"), 0.08, 6)
		Build.box(self, Vector3(0.1, 0.1, 1.8), p + Vector3.UP * 6.5, Color("5a4634"))
		Build.solid(nav, Vector3(0.3, 3.0, 0.3), p + Vector3.UP * 1.5, Build.L_LOW)
		if prev != Vector3.ZERO:
			for wz: float in [-0.75, 0.0, 0.75]:
				Build.box(self, Vector3(x - prev.x, 0.025, 0.025), Vector3((x + prev.x) * 0.5, 6.5, p.z + wz), Color("1a1a1c"))
		prev = p
		x += 40.0


## Lamp positions on the ground, for working out how lit a spot is at night.
func lamp_spots() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for l in _lamps:
		out.append(Vector3(l.position.x, 0, l.position.z))
	return out


func set_night(amount: float) -> void:
	for l in _lamps:
		l.light_energy = (2.4 if l.shadow_enabled else 1.4) * amount
	var on := amount > 0.3
	var m: Material = Build.mat(Color("fff0c0"), 3.5) if on else null
	for h in _lamp_heads:
		h.material_override = m
	for fx in _night_fx:
		fx.emitting = on
	for sh in _shafts:
		sh.visible = on
	var hour := Clock.hour()
	var open: Material = Build.mat(Color(1.0, 0.9, 0.62, 0.9), 1.6) if on and hour >= 8.0 and hour < 20.0 else null
	for g in _shop_glass:
		g.material_override = open


func all_containers() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for h in houses:
		out.append_array(h.furn)
	out.append_array(outdoor)
	return out


func bake_nav() -> void:
	var nm := NavigationMesh.new()
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nm.agent_radius = 0.0   # doorways are under a metre; any erosion closes them
	nm.agent_height = 1.75
	nm.agent_max_climb = 0.25
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = Build.L_WALL | Build.L_LOW
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	var src := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, nav)
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	nav.navigation_mesh = nm


func path(from: Vector3, to: Vector3) -> PackedVector3Array:
	return NavigationServer3D.map_get_path(get_world_3d().navigation_map, from, to, true)
