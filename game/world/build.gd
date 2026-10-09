class_name Build
## Helpers for making the low-poly world out of coloured boxes.

const L_WALL := 1    # blocks sight and movement
const L_LOW := 2     # blocks movement only (furniture, windows, fences)
const L_DOOR := 4    # blocks sight and movement, left out of the navmesh
const L_PLAYER := 8

static var _mats: Dictionary = {}


static func mat(color: Color, emission := 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f" % [color.to_html(), emission]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = Color(color.r, color.g, color.b)
		m.emission_energy_multiplier = emission
	_mats[key] = m
	return m


static func box(parent: Node, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat(color)
	mi.position = pos
	parent.add_child(mi)
	return mi


static func solid(parent: Node, size: Vector3, pos: Vector3, layer: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	body.position = pos
	parent.add_child(body)
	return body


static func cyl(parent: Node, radius: float, height: float, pos: Vector3, color: Color, top := -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = radius
	cm.top_radius = radius if top < 0.0 else top
	cm.height = height
	cm.radial_segments = 8
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat(color)
	mi.position = pos
	parent.add_child(mi)
	return mi


static func label(parent: Node, text: String, pos: Vector3, size := 48) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.01
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.outline_size = 12
	l.position = pos
	parent.add_child(l)
	return l
