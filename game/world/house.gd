class_name House
extends Node3D
## One house built from a Templates plan: thin walls, doors, windows, floors, furniture, roof.
## Add it to the tree and set its transform before calling build().

const WALL_H := 2.7
const WALL_T := 0.2
const WALL := 0
const DOOR := 1
const WINDOW := 2
const OPENING := 3

var tpl: Dictionary
var index := 0
var family := ""
var is_home := false                  # the player's house
var residents: Array = []             # Neighbour nodes
var furn: Array[Dictionary] = []      # {kind, name, pos, node, items, locked, disturbed, house}
var portals: Array[Portal] = []       # outside doors and windows
var wall_color := Color("d9d2c0")
var roof_color := Color("6e4b3c")
var lit := false

var _vis: Node3D      # walls and windows; squashed when the player is inside
var _roof: Node3D
var _lamp: OmniLight3D
var _glass: Array[MeshInstance3D] = []
var _cut := false


func build() -> void:
	_vis = Node3D.new()
	add_child(_vis)
	var w: int = tpl.w
	var d: int = tpl.d
	for r: Array in tpl.rooms:
		var c: Color = Templates.FLOORS.get(r[0], Color("9c7b55"))
		Build.box(self, Vector3(r[3], 0.04, r[4]), Vector3(r[1] + r[3] * 0.5, 0.02, r[2] + r[4] * 0.5), c)
	var edges := _edges()
	_wall_runs(edges, 0, w, d)
	_wall_runs(edges, 1, d, w)
	for key: Vector3i in edges:
		var kind: int = edges[key][0]
		if kind != WALL:
			_opening(key, kind, edges[key][1])
	for f: Array in tpl.furniture:
		add_furniture(f[0], Vector2(f[1], f[2]), f[3])
	_roof = Node3D.new()
	add_child(_roof)
	var prism := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(w + 1.2, 2.0, d + 1.2)
	prism.mesh = pm
	prism.material_override = Build.mat(roof_color)
	prism.position = Vector3(w * 0.5, WALL_H + 1.0, d * 0.5)
	_roof.add_child(prism)
	_lamp = OmniLight3D.new()
	_lamp.position = Vector3(w * 0.5, 2.3, d * 0.5)
	_lamp.omni_range = 9.0
	_lamp.light_color = Color("ffd9a0")
	_lamp.light_energy = 0.0
	add_child(_lamp)


func _edges() -> Dictionary:
	var e: Dictionary = {}
	for r: Array in tpl.rooms:
		for x in range(r[1], r[1] + r[3]):
			e[Vector3i(0, x, r[2])] = [WALL, ""]
			e[Vector3i(0, x, r[2] + r[4])] = [WALL, ""]
		for z in range(r[2], r[2] + r[4]):
			e[Vector3i(1, r[1], z)] = [WALL, ""]
			e[Vector3i(1, r[1] + r[3], z)] = [WALL, ""]
	for dr: Array in tpl.doors:
		e[Vector3i(0 if dr[0] == "h" else 1, dr[1], dr[2])] = [OPENING if dr[3] == "in" else DOOR, dr[3]]
	for wn: Array in tpl.windows:
		e[Vector3i(0 if wn[0] == "h" else 1, wn[1], wn[2])] = [WINDOW, ""]
	return e


## Merge consecutive wall edges on each line into single boxes.
func _wall_runs(edges: Dictionary, axis: int, along: int, lines: int) -> void:
	for line in range(lines + 1):
		var start := -1
		for i in range(along + 1):
			var key := Vector3i(0, i, line) if axis == 0 else Vector3i(1, line, i)
			var is_wall: bool = i < along and edges.has(key) and edges[key][0] == WALL
			if is_wall and start < 0:
				start = i
			elif not is_wall and start >= 0:
				var length := float(i - start)
				var mid := start + length * 0.5
				var size := Vector3(length + WALL_T, WALL_H, WALL_T) if axis == 0 else Vector3(WALL_T, WALL_H, length + WALL_T)
				var pos := Vector3(mid, WALL_H * 0.5, line) if axis == 0 else Vector3(line, WALL_H * 0.5, mid)
				Build.box(_vis, size, pos, wall_color)
				Build.solid(self, size, pos, Build.L_WALL)
				start = -1


func _opening(key: Vector3i, kind: int, tag: String) -> void:
	var h := key.x == 0
	var mid := Vector3(key.y + 0.5, 0, key.z) if h else Vector3(key.y, 0, key.z + 0.5)
	var along := Vector3(1, 0, 0) if h else Vector3(0, 0, 1)
	var across := Vector3(0, 0, 1) if h else Vector3(1, 0, 0)
	var span := func(height: float, thick: float) -> Vector3: return along * 1.0 + Vector3.UP * height + across * thick
	# lintel over every opening
	Build.box(_vis, span.call(0.6, WALL_T), mid + Vector3.UP * 2.4, wall_color)
	if kind == OPENING:
		return
	var p := Portal.new()
	p.house = self
	p.is_window = kind == WINDOW
	p.tag = tag
	add_child(p)
	p.position = mid
	# which side is indoors
	var side := 1.0 if _inside_local(mid + across * 0.6) else -1.0
	p.inside_pos = to_global(mid + across * 0.75 * side)
	p.outside_pos = to_global(mid - across * 0.75 * side)
	if kind == WINDOW:
		Build.box(_vis, span.call(0.9, WALL_T), mid + Vector3.UP * 0.45, wall_color)
		var g := Build.box(_vis, span.call(1.2, 0.06), mid + Vector3.UP * 1.5, Color(0.55, 0.7, 0.8, 0.45))
		_glass.append(g)
		Build.solid(self, span.call(WALL_H, WALL_T), mid + Vector3.UP * WALL_H * 0.5, Build.L_LOW)
	else:
		p.leaf = Node3D.new()
		p.leaf.position = mid - along * 0.5
		_vis.add_child(p.leaf)
		Build.box(p.leaf, span.call(2.1, 0.08), along * 0.5 + Vector3.UP * 1.05, Color("5c3a26") if tag == "front" else Color("7a7468"))
		p.body = Build.solid(self, span.call(2.1, WALL_T), mid + Vector3.UP * 1.05, Build.L_DOOR)
	portals.append(p)


func add_furniture(kind: String, at: Vector2, quarter_turns := 0) -> Dictionary:
	var def: Array = Templates.FURNITURE[kind]
	var size: Vector3 = def[0]
	if quarter_turns % 2 == 1:
		size = Vector3(size.z, size.y, size.x)
	var pos := Vector3(at.x, size.y * 0.5, at.y)
	var node := Build.box(self, size, pos, def[1])
	if kind != "stash":
		Build.solid(self, size, pos, Build.L_LOW)
	_dress(kind, node, size)
	var f := {
		"kind": kind, "name": def[2], "node": node, "pos": to_global(Vector3(at.x, 0, at.y)),
		"items": [], "locked": kind == "safe", "disturbed": false, "house": self, "bug": false,
	}
	furn.append(f)
	return f


## Small extra boxes so furniture reads as what it is.
func _dress(kind: String, node: Node3D, size: Vector3) -> void:
	match kind:
		"bed":
			Build.box(node, Vector3(size.x * 0.9, 0.12, 0.5), Vector3(0, size.y * 0.5 + 0.06, -size.z * 0.5 + 0.35), Color("ece8dc"))
		"tv":
			Build.box(node, Vector3(size.x * 0.75, size.y * 0.5, 0.02), Vector3(0, 0.12, size.z * 0.5 + 0.01), Color("5d7f8c"))
		"phone":
			Build.box(node, Vector3(0.25, 0.1, 0.2), Vector3(0, size.y * 0.5 + 0.05, 0), Color("b5352b"))
		"desk":
			Build.box(node, Vector3(0.35, 0.03, 0.25), Vector3(0, size.y * 0.5 + 0.02, 0), Color("efe9d2"))
		"radio":
			Build.box(node, Vector3(0.5, 0.25, 0.3), Vector3(0, size.y * 0.5 + 0.13, 0), Color("1e211c"))
		"sofa":
			Build.box(node, Vector3(size.x, 0.3, size.z), Vector3(0, -0.1, 0), Color("8d5c44")).scale = Vector3(1.04, 1, 1.04)


func _inside_local(p: Vector3) -> bool:
	for r: Array in tpl.rooms:
		if p.x > r[1] and p.x < r[1] + r[3] and p.z > r[2] and p.z < r[2] + r[4]:
			return true
	return false


func contains(world: Vector3) -> bool:
	return _inside_local(to_local(world))


## True if `world` is over the house's footprint grown by `margin` metres.
func footprint(world: Vector3, margin: float) -> bool:
	var p := to_local(world)
	return p.x > -margin and p.x < tpl.w + margin and p.z > -margin and p.z < tpl.d + margin


func room_at(world: Vector3) -> String:
	var p := to_local(world)
	for r: Array in tpl.rooms:
		if p.x > r[1] and p.x < r[1] + r[3] and p.z > r[2] and p.z < r[2] + r[4]:
			return r[0]
	return ""


## Centre of the named room, in world space (falls back to the first room).
func room_pos(room: String) -> Vector3:
	var pick: Array = tpl.rooms[0]
	for r: Array in tpl.rooms:
		if r[0] == room:
			pick = r
	return to_global(Vector3(pick[1] + pick[3] * 0.5, 0, pick[2] + pick[4] * 0.5))


func find_furn(kind: String) -> Dictionary:
	for f in furn:
		if f.kind == kind:
			return f
	return {}


func portal(tag: String) -> Portal:
	for p in portals:
		if p.tag == tag:
			return p
	return null


## Roof off and walls low while the player is inside.
func set_cutaway(on: bool) -> void:
	if on == _cut:
		return
	_cut = on
	_roof.visible = not on
	_vis.scale.y = 0.3 if on else 1.0


func set_lit(on: bool) -> void:
	if on == lit:
		return
	lit = on
	_lamp.light_energy = 1.6 if on else 0.0
	var m := Build.mat(Color(1.0, 0.85, 0.5, 0.9), 2.0) if on else Build.mat(Color(0.55, 0.7, 0.8, 0.45))
	for g in _glass:
		g.material_override = m
