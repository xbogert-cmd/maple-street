class_name Street
extends Node3D
## Builds the whole map from a Cast: road, twelve lots with houses, the park at the east end,
## the store and plant bus stop at the west end. Also bakes the navmesh neighbours walk on.

const LOT_W := 20.0
const PER_SIDE := 6
const ROAD_HALF := 4.0
const WALK := 6.0          # outer edge of the sidewalk
const FRONT := 11.0        # house fronts
const BACK := 32.0         # back fences
const X0 := -40.0
const X1 := 160.0

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
var _lamps: Array[OmniLight3D] = []
var _lamp_heads: Array[MeshInstance3D] = []
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
	plant = House.new()
	plant.tpl = Templates.PLANT.duplicate(true)
	plant.family = "plant"
	plant.wall_color = Color("b8bcc0")
	nav.add_child(plant)
	plant.position = Vector3(40, 0, -320)
	plant.build()
	plant.set_cutaway(true)
	plant.set_lit(true)
	Build.solid(nav, Vector3(40, 1.0, 26), Vector3(52, -0.5, -314), Build.L_WALL)


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
	Build.box(self, Vector3(span, 0.02, 80), Vector3(cx, -0.01, 0), Color("4f7340"))
	Build.box(self, Vector3(span, 0.03, ROAD_HALF * 2), Vector3(cx, 0.0, 0), Color("3b3d42"))
	for s: float in [-1.0, 1.0]:
		Build.box(self, Vector3(span, 0.05, WALK - ROAD_HALF), Vector3(cx, 0.01, s * (ROAD_HALF + WALK) * 0.5), Color("a8a59c"))
	var x := X0 + 2.0
	while x < X1:
		Build.box(self, Vector3(2.0, 0.035, 0.15), Vector3(x, 0.0, 0), Color("d8cf9a"))
		x += 5.0
	# map edges
	for e: Array in [[Vector3(span, 3, 0.5), Vector3(cx, 1.5, -36)], [Vector3(span, 3, 0.5), Vector3(cx, 1.5, 36)], [Vector3(0.5, 3, 72), Vector3(X0, 1.5, 0)], [Vector3(0.5, 3, 72), Vector3(X1, 1.5, 0)]]:
		Build.solid(nav, e[0], e[1], Build.L_LOW)


func _lot(h: Dictionary) -> void:
	var i: int = h.lot
	var s := lot_side(i)
	var x0 := lot_x(i)
	Build.box(self, Vector3(LOT_W - 0.1, 0.03, BACK - WALK), Vector3(x0 + LOT_W * 0.5, 0.0, s * (BACK + WALK) * 0.5), Color("5f8a4a").lerp(Color("6f9a52"), _rng.randf()))
	var house := House.new()
	house.tpl = Templates.make(h.tpl, h.mirror)
	house.index = i
	house.family = h.family
	house.wall_color = Color(h.wall)
	house.roof_color = Color(h.roof)
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
	Build.box(self, Vector3(1.2, 0.04, absf(fp.z) - WALK + 0.8), Vector3(fp.x, 0.01, s * (absf(fp.z) + WALK + 0.8) * 0.5), Color("b7b2a6"))
	# driveway and car
	Build.box(self, Vector3(3.6, 0.04, 9.0), Vector3(x0 + 17.4, 0.01, s * (WALK + 4.5)), Color("8d8a84"))
	var car: Node3D = null
	if not h.people.is_empty() or i == cast.home:
		car = _car(Color(h.car))
		car.position = Vector3(x0 + 17.4, 0, s * 11.0)
		nav.add_child(car)
	cars.append(car)
	# mailbox and trash can
	Build.box(self, Vector3(0.1, 1.0, 0.1), Vector3(x0 + 14.6, 0.5, s * (WALK + 0.4)), Color("5a4a3a"))
	_outdoor("mailbox", "Mailbox", Vector3(0.3, 0.25, 0.5), Vector3(x0 + 14.6, 1.1, s * (WALK + 0.4)), Color("3c5a8a"), house)
	_outdoor("trash", "Trash can", Vector3(0.6, 0.9, 0.6), Vector3(x0 + 19.4, 0.45, s * 9.0), Color("5c6660"), house)
	# hedge on the lot line (back two thirds) and the back fence
	if i % PER_SIDE > 0:
		_wall_box(Vector3(0.7, 1.5, BACK - 15.0), Vector3(x0, 0.75, s * (BACK + 15.0) * 0.5), Color("3f6a3a"))
	_wall_box(Vector3(LOT_W, 1.7, 0.2), Vector3(x0 + LOT_W * 0.5, 0.85, s * BACK), Color("8a7458"))
	_tree(Vector3(x0 + _rng.randf_range(3.0, 13.0), 0, s * _rng.randf_range(7.5, 9.5)))
	if _rng.randf() < 0.6:
		_tree(Vector3(x0 + _rng.randf_range(4.0, 16.0), 0, s * _rng.randf_range(25.0, 30.0)))


func _outdoor(kind: String, title: String, size: Vector3, pos: Vector3, color: Color, house: House) -> void:
	var node := Build.box(self, size, pos, color)
	if kind == "trash":
		Build.solid(nav, size, pos, Build.L_LOW)
	outdoor.append({"kind": kind, "name": title, "node": node, "pos": Vector3(pos.x, 0, pos.z), "items": [], "locked": false, "disturbed": false, "house": house, "bug": false})


func _wall_box(size: Vector3, pos: Vector3, color: Color) -> void:
	Build.box(self, size, pos, color)
	Build.solid(nav, size, pos, Build.L_WALL)


func _tree(p: Vector3) -> void:
	var h := _rng.randf_range(3.5, 5.5)
	Build.cyl(self, 0.22, h * 0.5, p + Vector3.UP * h * 0.25, Color("5a4330"))
	Build.cyl(self, 1.7, h * 0.75, p + Vector3.UP * h * 0.8, Color("3d6b3a").lerp(Color("547f3f"), _rng.randf()), 0.2)
	Build.solid(nav, Vector3(0.5, 3.0, 0.5), p + Vector3.UP * 1.5, Build.L_WALL)


func _car(color: Color) -> Node3D:
	var car := Node3D.new()
	Build.box(car, Vector3(1.8, 0.6, 4.4), Vector3(0, 0.6, 0), color)
	Build.box(car, Vector3(1.6, 0.55, 2.2), Vector3(0, 1.15, -0.2), color.darkened(0.15))
	Build.box(car, Vector3(1.62, 0.4, 2.0), Vector3(0, 1.15, -0.2), Color("9fb4c4"))
	for wx: float in [-0.9, 0.9]:
		for wz: float in [-1.4, 1.4]:
			Build.box(car, Vector3(0.2, 0.6, 0.6), Vector3(wx, 0.3, wz), Color("1c1c1e"))
	Build.solid(car, Vector3(1.8, 1.4, 4.4), Vector3(0, 0.7, 0), Build.L_WALL)
	return car


func _park() -> void:
	var px := PER_SIDE * LOT_W
	Build.box(self, Vector3(X1 - px, 0.04, 72), Vector3((px + X1) * 0.5, 0.0, 0), Color("57804a"))
	Build.box(self, Vector3(X1 - px - 6, 0.05, 2.0), Vector3((px + X1) * 0.5, 0.01, 0), Color("b9b09a"))
	Build.box(self, Vector3(2.0, 0.05, 50), Vector3(140, 0.01, 0), Color("b9b09a"))
	# pond
	Build.cyl(self, 6.0, 0.06, Vector3(150, 0.03, -18), Color("3f6f8f"))
	Build.solid(nav, Vector3(9, 1, 9), Vector3(150, 0.5, -18), Build.L_LOW)
	# fountain
	Build.cyl(self, 1.6, 0.6, Vector3(140, 0.3, 0), Color("a9a59b"))
	Build.cyl(self, 0.3, 1.6, Vector3(140, 0.8, 0), Color("bfbbb0"))
	Build.solid(nav, Vector3(3.0, 1.0, 3.0), Vector3(140, 0.5, 0), Build.L_LOW)
	for b: Vector3 in [Vector3(132, 0, 2.2), Vector3(148, 0, -2.2), Vector3(141.8, 0, 16)]:
		Build.box(self, Vector3(1.8, 0.45, 0.5), b + Vector3.UP * 0.25, Color("6b4a2e"))
		Build.solid(nav, Vector3(1.8, 0.5, 0.5), b + Vector3.UP * 0.25, Build.L_LOW)
	var oak := Vector3(152, 0, 20)
	for t in 14:
		var p := Vector3(_rng.randf_range(px + 5, X1 - 4), 0, _rng.randf_range(-33, 33))
		if absf(p.z) < 3.0 or absf(p.x - 140) < 3.0 or p.distance_to(Vector3(150, 0, -18)) < 8.0 or p.distance_to(oak) < 4.0:
			continue
		_tree(p)
	Build.cyl(self, 0.6, 3.0, oak + Vector3.UP * 1.5, Color("4a3626"))
	Build.cyl(self, 3.2, 4.5, oak + Vector3.UP * 4.6, Color("35602f"), 0.4)
	Build.solid(nav, Vector3(1.2, 3.0, 1.2), oak + Vector3.UP * 1.5, Build.L_WALL)
	drops = [
		{"name": "the hollow oak", "pos": oak + Vector3(-1.2, 0, 0)},
		{"name": "the loose stone at the fountain", "pos": Vector3(140, 0, 2.2)},
		{"name": "under the far bench", "pos": Vector3(141.8, 0, 17.0)},
	]


func _west_end() -> void:
	Build.box(self, Vector3(38, 0.04, 26), Vector3(-20, 0.0, -21), Color("77756f"))
	Build.box(self, Vector3(38, 0.04, 26), Vector3(-20, 0.0, 21), Color("57804a"))
	# Miller's Market
	_wall_box(Vector3(16, 4.0, 10), Vector3(-20, 2.0, -16), Color("b8946a"))
	Build.box(self, Vector3(16.6, 0.5, 10.6), Vector3(-20, 4.25, -16), Color("7a3b33"))
	Build.box(self, Vector3(1.4, 2.2, 0.1), Vector3(-20, 1.1, -10.95), Color("3a2c22"))
	Build.box(self, Vector3(4.0, 1.4, 0.1), Vector3(-15.5, 1.6, -10.95), Color(0.6, 0.75, 0.85, 0.6))
	Build.label(self, "MILLER'S MARKET", Vector3(-20, 5.2, -11), 64).modulate = Color("f2e6c8")
	# plant bus shelter
	Build.box(self, Vector3(4.0, 0.12, 1.6), Vector3(-9, 2.4, 6.6), Color("5c6b78"))
	Build.box(self, Vector3(4.0, 2.4, 0.1), Vector3(-9, 1.2, 7.35), Color(0.6, 0.75, 0.85, 0.5))
	for px: float in [-10.9, -7.1]:
		Build.box(self, Vector3(0.12, 2.4, 0.12), Vector3(px, 1.2, 6.0), Color("5c6b78"))
	Build.solid(nav, Vector3(4.0, 2.4, 0.2), Vector3(-9, 1.2, 7.35), Build.L_LOW)
	Build.box(self, Vector3(2.4, 0.4, 0.4), Vector3(-9, 0.25, 6.9), Color("6b4a2e"))
	Build.label(self, "PLANT BUS", Vector3(-9, 3.0, 6.6), 48).modulate = Color("f2e6c8")
	for t in 6:
		_tree(Vector3(_rng.randf_range(-37, -3), 0, _rng.randf_range(12, 33)))


func _lamps_row() -> void:
	var x := -30.0
	var s := 1.0
	while x < X1 - 5:
		var p := Vector3(x, 0, s * (ROAD_HALF + 0.4))
		Build.cyl(self, 0.07, 5.0, p + Vector3.UP * 2.5, Color("3c4046"))
		var head := Build.box(self, Vector3(0.5, 0.15, 0.5), p + Vector3(0, 5.0, -s * 0.3), Color("fff0c0"))
		_lamp_heads.append(head)
		var l := OmniLight3D.new()
		l.position = p + Vector3(0, 4.7, -s * 0.5)
		l.omni_range = 13.0
		l.light_color = Color("ffe2a8")
		l.light_energy = 0.0
		l.shadow_enabled = true
		add_child(l)
		_lamps.append(l)
		x += 32.0
		s = -s


## Lamp positions on the ground, for working out how lit a spot is at night.
func lamp_spots() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for l in _lamps:
		out.append(Vector3(l.position.x, 0, l.position.z))
	return out


func set_night(amount: float) -> void:
	for l in _lamps:
		l.light_energy = 2.2 * amount
	var m := Build.mat(Color("fff0c0"), 3.0) if amount > 0.3 else Build.mat(Color("cfc8b0"))
	for h in _lamp_heads:
		h.material_override = m


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
