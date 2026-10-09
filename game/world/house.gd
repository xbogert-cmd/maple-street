class_name House
extends Node3D
## One house built from a Templates plan: thin sided walls, doors, shuttered windows, porch,
## shingled roof with a chimney, textured floors and detailed furniture.
## Add it to the tree and set its transform before calling build().

const WALL_H := 2.7
const WALL_T := 0.2
const WALL := 0
const DOOR := 1
const WINDOW := 2
const OPENING := 3
const TRIM := Color("f1ede2")
const FLOOR_PATTERN: Dictionary = {"kitchen": "tile", "bath": "tile", "bedroom": "carpet", "corridor": "tile", "lab": "tile", "closet": "concrete", "security": "carpet", "office": "carpet"}

var tpl: Dictionary
var index := 0
var family := ""
var is_home := false                  # the player's house
var plain := false                    # workplace: no porch, chimney or homely touches
var residents: Array = []             # Neighbour nodes
var furn: Array[Dictionary] = []      # {kind, name, pos, size, front, node, items, locked, disturbed, house, bug}
var portals: Array[Portal] = []       # outside doors and windows
var wall_color := Color("d9d2c0")
var roof_color := Color("6e4b3c")
var accent := Color("5c3a26")         # front door and shutters
var lit := false

var _vis: Node3D      # walls and windows; squashed when the player is inside
var _frames: Node3D   # door frames and doors: stay full height in the cutaway
var _tops: Node3D     # wall above doorways: hidden in the cutaway
var _roof: Node3D
var _lamp: OmniLight3D
var _porch: OmniLight3D
var _tv: OmniLight3D
var _smoke: CPUParticles3D
var _glass: Array[MeshInstance3D] = []
var _bulbs: Array[MeshInstance3D] = []   # lamp shades that glow when the house is lit
var _cut := false
var _rng := RandomNumberGenerator.new()


func build() -> void:
	_rng.seed = hash(family) + index
	_vis = Node3D.new()
	add_child(_vis)
	_roof = Node3D.new()
	add_child(_roof)
	_frames = Node3D.new()
	add_child(_frames)
	_tops = Node3D.new()
	add_child(_tops)
	var w: int = tpl.w
	var d: int = tpl.d
	for r: Array in tpl.rooms:
		var c: Color = Templates.FLOORS.get(r[0], Color("9c7b55"))
		Build.box(self, Vector3(r[3], 0.04, r[4]), Vector3(r[1] + r[3] * 0.5, 0.02, r[2] + r[4] * 0.5), c, FLOOR_PATTERN.get(r[0], "planks"))
	var edges := _edges()
	_wall_runs(edges, 0, w, d)
	_wall_runs(edges, 1, d, w)
	for key: Vector3i in edges:
		var kind: int = edges[key][0]
		if kind != WALL:
			_opening(key, kind, edges[key][1])
	for f: Array in tpl.furniture:
		add_furniture(f[0], Vector2(f[1], f[2]), f[3])
	if not plain:
		_homely()
	# roof: shingled gable over a pale fascia, and a brick chimney
	var prism := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(w + 1.3, 2.0, d + 1.3)
	pm.material = Build.mat(roof_color, 0.0, "shingle")
	prism.mesh = pm
	prism.position = Vector3(w * 0.5, WALL_H + 1.08, d * 0.5)
	_roof.add_child(prism)
	Build.box(_roof, Vector3(w + 1.4, 0.12, d + 1.4), Vector3(w * 0.5, WALL_H + 0.04, d * 0.5), TRIM)
	_lamp = OmniLight3D.new()
	_lamp.position = Vector3(w * 0.5, 2.3, d * 0.5)
	_lamp.omni_range = 9.0
	_lamp.light_color = Color("ffd9a0")
	_lamp.light_energy = 0.0
	add_child(_lamp)
	if plain:
		return
	var cx := w * (0.72 if index % 2 == 0 else 0.28)
	Build.box(_roof, Vector3(0.75, 2.6, 0.75), Vector3(cx, WALL_H + 1.3, d * 0.5 - 1.5), Color("8a5a48"), "brick")
	Build.box(_roof, Vector3(0.9, 0.12, 0.9), Vector3(cx, WALL_H + 2.64, d * 0.5 - 1.5), Color("5a5550"))
	_smoke = CPUParticles3D.new()
	_smoke.position = Vector3(cx, WALL_H + 2.8, d * 0.5 - 1.5)
	_smoke.amount = 14
	_smoke.lifetime = 4.0
	_smoke.direction = Vector3(0.25, 1, 0.1)
	_smoke.spread = 12.0
	_smoke.gravity = Vector3.ZERO
	_smoke.initial_velocity_min = 0.5
	_smoke.initial_velocity_max = 0.8
	_smoke.scale_amount_min = 0.5
	_smoke.scale_amount_max = 1.1
	var puff := BoxMesh.new()
	puff.size = Vector3(0.35, 0.35, 0.35)
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.8, 0.8, 0.82, 0.3)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff.material = sm
	_smoke.mesh = puff
	_smoke.emitting = false
	_roof.add_child(_smoke)
	var tv := find_furn("tv")
	if not tv.is_empty():
		_tv = OmniLight3D.new()
		_tv.position = to_local(tv.pos) + (tv.front as Vector3) * 0.8 + Vector3.UP * 0.9
		_tv.omni_range = 4.5
		_tv.light_color = Color("8fb8ff")
		_tv.light_energy = 0.0
		add_child(_tv)


func _process(_delta: float) -> void:
	if _tv and lit:
		var t := Time.get_ticks_msec() * 0.001 + index * 7.0
		_tv.light_energy = 0.5 + 0.35 * sin(t * 9.0) * sin(t * 2.3) + 0.2 * sin(t * 23.0)


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


## Merge consecutive wall edges on each line into single boxes, with a skirting band at the foot.
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
				Build.box(_vis, size, pos, wall_color, "siding")
				var band := Vector3(size.x + 0.06, 0.28, size.z + 0.06)
				Build.box(_vis, band, Vector3(pos.x, 0.14, pos.z), wall_color.darkened(0.3))
				Build.solid(self, size, pos, Build.L_WALL)
				start = -1


func _opening(key: Vector3i, kind: int, tag: String) -> void:
	var h := key.x == 0
	var mid := Vector3(key.y + 0.5, 0, key.z) if h else Vector3(key.y, 0, key.z + 0.5)
	var along := Vector3(1, 0, 0) if h else Vector3(0, 0, 1)
	var across := Vector3(0, 0, 1) if h else Vector3(1, 0, 0)
	var span := func(length: float, height: float, thick: float) -> Vector3: return along * length + Vector3.UP * height + across * thick
	# lintel over every opening
	Build.box(_vis if kind == WINDOW else _tops, span.call(1.0, 0.6, WALL_T), mid + Vector3.UP * 2.4, wall_color, "siding")
	if kind == OPENING:
		for s: float in [-0.5, 0.5]:
			Build.box(_frames, span.call(0.07, 2.1, WALL_T + 0.06), mid + along * s + Vector3.UP * 1.05, TRIM)
		Build.box(_frames, span.call(1.07, 0.08, WALL_T + 0.06), mid + Vector3.UP * 2.14, TRIM)
		return
	var p := Portal.new()
	p.house = self
	p.is_window = kind == WINDOW
	p.tag = tag
	add_child(p)
	p.position = mid
	# which side is indoors
	var side := 1.0 if _inside_local(mid + across * 0.6) else -1.0
	var out := across * -side
	p.inside_pos = to_global(mid - out * 0.75)
	p.outside_pos = to_global(mid + out * 0.75)
	if kind == WINDOW:
		Build.box(_vis, span.call(1.0, 0.9, WALL_T), mid + Vector3.UP * 0.45, wall_color, "siding")
		Build.box(_vis, span.call(1.0, 0.28, WALL_T + 0.06), mid + Vector3.UP * 0.14, wall_color.darkened(0.3))
		var g := Build.box(_vis, span.call(1.0, 1.2, 0.05), mid + Vector3.UP * 1.5, Color(0.5, 0.66, 0.78, 0.5))
		_glass.append(g)
		# frame, sill and glazing bars
		Build.box(_vis, span.call(1.12, 0.07, WALL_T + 0.16), mid + Vector3.UP * 0.9, TRIM)
		Build.box(_vis, span.call(1.08, 0.07, WALL_T + 0.06), mid + Vector3.UP * 2.1, TRIM)
		Build.box(_vis, span.call(0.04, 1.2, 0.09), mid + Vector3.UP * 1.5, TRIM)
		Build.box(_vis, span.call(1.0, 0.04, 0.09), mid + Vector3.UP * 1.5, TRIM)
		for s: float in [-1.0, 1.0]:
			Build.box(_vis, span.call(0.05, 1.2, WALL_T + 0.04), mid + along * s * 0.5 + Vector3.UP * 1.5, TRIM)
			if not plain:
				# shutters outside, curtains inside
				Build.box(_vis, span.call(0.26, 1.24, 0.05), mid + along * s * 0.66 + out * 0.13 + Vector3.UP * 1.5, accent)
				Build.box(_vis, span.call(0.2, 1.16, 0.04), mid + along * s * 0.38 - out * 0.13 + Vector3.UP * 1.5, accent.lerp(Color("f4ead8"), 0.75))
		Build.solid(self, span.call(1.0, WALL_H, WALL_T), mid + Vector3.UP * WALL_H * 0.5, Build.L_LOW)
	else:
		var front := tag == "front"
		var color := accent if front else Color("8a8478")
		p.leaf = Node3D.new()
		p.leaf.position = mid - along * 0.5
		_frames.add_child(p.leaf)
		Build.box(p.leaf, span.call(0.92, 2.1, 0.07), along * 0.5 + Vector3.UP * 1.05, color)
		for py: float in [0.6, 1.5]:
			Build.box(p.leaf, span.call(0.6, 0.6, 0.09), along * 0.5 + Vector3.UP * py, color.darkened(0.12))
		for s: float in [-1.0, 1.0]:
			Build.box(p.leaf, Vector3(0.07, 0.07, 0.07), along * 0.82 + across * s * 0.07 + Vector3.UP * 1.0, Color("c9a44a"))
			Build.box(_frames, span.call(0.07, 2.16, WALL_T + 0.06), mid + along * s * 0.5 + Vector3.UP * 1.08, TRIM)
		Build.box(_frames, span.call(1.14, 0.08, WALL_T + 0.06), mid + Vector3.UP * 2.14, TRIM)
		p.body = Build.solid(self, span.call(1.0, 2.1, WALL_T), mid + Vector3.UP * 1.05, Build.L_DOOR)
		if not plain:
			# step, and for the front door a small porch with a light
			var slab: Vector3 = span.call(2.4, 0.12, 1.5) if front else span.call(1.5, 0.1, 1.0)
			Build.box(self, slab, mid + out * (0.8 if front else 0.55) + Vector3.UP * 0.05, Color("b9b4a8"), "concrete")
			if front:
				for s: float in [-1.0, 1.0]:
					Build.box(_vis, Vector3(0.12, 2.4, 0.12), mid + along * s * 1.1 + out * 1.4 + Vector3.UP * 1.2, TRIM)
				Build.box(_roof, span.call(2.6, 0.12, 1.7), mid + out * 0.85 + Vector3.UP * 2.46, roof_color, "shingle")
				_bulbs.append(Build.box(_vis, Vector3(0.14, 0.18, 0.14), mid + along * 0.75 + out * 0.2 + Vector3.UP * 1.9, Color("d8d2bc")))
				_porch = OmniLight3D.new()
				_porch.position = mid + out * 0.9 + Vector3.UP * 2.0
				_porch.omni_range = 5.5
				_porch.light_color = Color("ffdca6")
				_porch.light_energy = 0.0
				add_child(_porch)
	portals.append(p)


## Rugs, a standing lamp and a pot plant, placed where the plan leaves room.
func _homely() -> void:
	for r: Array in tpl.rooms:
		var c := Vector3(r[1] + r[3] * 0.5, 0, r[2] + r[4] * 0.5)
		match r[0]:
			"living":
				var rug: Color = [Color("7a3b33"), Color("3f5a6e"), Color("6a6a3a")][index % 3]
				Build.box(self, Vector3(r[3] * 0.5, 0.02, r[4] * 0.45), c + Vector3.UP * 0.05, rug, "carpet")
				var corner := Vector3(r[1] + 0.45, 0, r[2] + r[4] - 0.45)
				Build.cyl(self, 0.04, 1.5, corner + Vector3.UP * 0.75, Color("3a3a3c"))
				_bulbs.append(Build.cyl(self, 0.22, 0.3, corner + Vector3.UP * 1.6, Color("e8dcc0"), 0.14))
			"bedroom":
				Build.box(self, Vector3(r[3] * 0.4, 0.02, r[4] * 0.3), c + Vector3(0, 0.05, r[4] * 0.2), Color("8a7a5a"), "carpet")
			"hall":
				var corner := Vector3(r[1] + r[3] - 0.4, 0, r[2] + 0.4)
				Build.cyl(self, 0.18, 0.35, corner + Vector3.UP * 0.18, Color("8a5a48"), 0.22)
				Build.leaf(self, 0.3, 0.7, corner + Vector3.UP * 0.7, Color("3f7a3f"), false)


func add_furniture(kind: String, at: Vector2, quarter_turns := 0) -> Dictionary:
	var def: Array = Templates.FURNITURE[kind]
	var plan: Vector3 = def[0]
	var size := plan
	if quarter_turns % 2 == 1:
		size = Vector3(plan.z, plan.y, plan.x)
	var pos := Vector3(at.x, size.y * 0.5, at.y)
	if kind != "stash":
		Build.solid(self, size, pos, Build.L_LOW)
	# face into the room: across the short side, toward the room's middle
	var room := _room_local(Vector3(at.x, 0, at.y))
	var to_mid := Vector3(0, 0, 1)
	if not room.is_empty():
		to_mid = Vector3(room[1] + room[3] * 0.5 - at.x, 0, room[2] + room[4] * 0.5 - at.y)
	var fz := Vector3(0, 0, 1.0 if to_mid.z >= 0.0 else -1.0)
	var fx := Vector3(1.0 if to_mid.x >= 0.0 else -1.0, 0, 0)
	var front := fz
	if size.z > size.x + 0.01 or (absf(size.x - size.z) <= 0.01 and absf(to_mid.x) > absf(to_mid.z)):
		front = fx
	if kind == "bed":
		# a bed lies along its length with the pillow at the wall end
		front = fz if size.z > size.x else fx
	var node := Node3D.new()
	node.position = Vector3(at.x, 0, at.y)
	node.rotation.y = atan2(front.x, front.z)
	add_child(node)
	var across := maxf(size.x, size.z) if kind != "bed" else minf(size.x, size.z)
	var deep := minf(size.x, size.z) if kind != "bed" else maxf(size.x, size.z)
	Furnish.make(self, node, kind, Vector3(across, size.y, deep), def[1], _rng)
	var f := {
		"kind": kind, "name": def[2], "node": node, "pos": to_global(Vector3(at.x, 0, at.y)), "size": size, "front": front,
		"items": [], "locked": kind == "safe", "disturbed": false, "house": self, "bug": false,
	}
	furn.append(f)
	return f


## A lamp shade that should glow when the house lights are on.
func add_bulb(m: MeshInstance3D) -> void:
	_bulbs.append(m)


func _room_local(p: Vector3) -> Array:
	for r: Array in tpl.rooms:
		if p.x > r[1] and p.x < r[1] + r[3] and p.z > r[2] and p.z < r[2] + r[4]:
			return r
	return []


func _inside_local(p: Vector3) -> bool:
	return not _room_local(p).is_empty()


func contains(world: Vector3) -> bool:
	return _inside_local(to_local(world))


## True if `world` is over the house's footprint grown by `margin` metres.
func footprint(world: Vector3, margin: float) -> bool:
	var p := to_local(world)
	return p.x > -margin and p.x < tpl.w + margin and p.z > -margin and p.z < tpl.d + margin


func room_at(world: Vector3) -> String:
	var r := _room_local(to_local(world))
	return "" if r.is_empty() else String(r[0])


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
	_tops.visible = not on
	_vis.scale.y = 0.3 if on else 1.0


func set_lit(on: bool) -> void:
	if on == lit:
		return
	lit = on
	_lamp.light_energy = 1.3 if on else 0.0
	if _porch:
		_porch.light_energy = 1.1 if on else 0.0
	if _tv and not on:
		_tv.light_energy = 0.0
	if _smoke:
		_smoke.emitting = on
	var m: Material = Build.mat(Color(1.0, 0.84, 0.5, 0.92), 2.2) if on else null
	for g in _glass:
		g.material_override = m
	var b: Material = Build.mat(Color("ffe6b0"), 3.0) if on else null
	for bulb in _bulbs:
		bulb.material_override = b
