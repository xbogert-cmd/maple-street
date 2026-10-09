class_name Build
## Helpers for making the low-poly world: coloured boxes, cylinders and faceted blobs, with
## small generated textures (siding, shingles, grass...) for surface detail.
## Meshes and materials are shared by size and colour so the renderer can batch them.

const L_WALL := 1    # blocks sight and movement
const L_LOW := 2     # blocks movement only (furniture, windows, fences)
const L_DOOR := 4    # blocks sight and movement, left out of the navmesh
const L_PLAYER := 8

const TEX := 64
## pattern: metres per repeat
const PATTERN_SIZE: Dictionary = {
	"grass": 2.0, "asphalt": 2.0, "concrete": 2.0, "siding": 1.0, "shingle": 1.0, "planks": 1.6,
	"tile": 1.0, "carpet": 1.0, "brick": 1.0, "leaf": 1.5, "gravel": 1.5, "wood": 1.0,
}

static var _mats: Dictionary = {}
static var _meshes: Dictionary = {}
static var _textures: Dictionary = {}
static var _foliage: ShaderMaterial


static func mat(color: Color, emission := 0.0, pattern := "") -> StandardMaterial3D:
	var key := "%s|%.2f|%s" % [color.to_html(), emission, pattern]
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
	if pattern != "":
		m.albedo_texture = texture(pattern)
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		var s := 1.0 / float(PATTERN_SIZE[pattern])
		m.uv1_scale = Vector3(s, s, s)
	_mats[key] = m
	return m


static func box(parent: Node, size: Vector3, pos: Vector3, color: Color, pattern := "") -> MeshInstance3D:
	var key := "b|%s|%s|%s" % [size, color.to_html(), pattern]
	var mesh: BoxMesh = _meshes.get(key)
	if mesh == null:
		mesh = BoxMesh.new()
		mesh.size = size
		mesh.material = mat(color, 0.0, pattern)
		_meshes[key] = mesh
	return _place(parent, mesh, pos)


## A box that glows (lamps, lit windows, tail lights).
static func glow(parent: Node, size: Vector3, pos: Vector3, color: Color, energy: float) -> MeshInstance3D:
	var mi := box(parent, size, pos, color)
	mi.material_override = mat(color, energy)
	return mi


static func cyl(parent: Node, radius: float, height: float, pos: Vector3, color: Color, top := -1.0, sides := 8, pattern := "") -> MeshInstance3D:
	var key := "c|%.3f|%.3f|%.3f|%d|%s|%s" % [radius, height, top, sides, color.to_html(), pattern]
	var mesh: CylinderMesh = _meshes.get(key)
	if mesh == null:
		mesh = CylinderMesh.new()
		mesh.bottom_radius = radius
		mesh.top_radius = radius if top < 0.0 else top
		mesh.height = height
		mesh.radial_segments = sides
		mesh.rings = 1
		mesh.material = mat(color, 0.0, pattern)
		_meshes[key] = mesh
	return _place(parent, mesh, pos)


## Faceted foliage: a cone (top 0) or a blob, lit per face, swaying a little in the wind.
static func leaf(parent: Node, radius: float, height: float, pos: Vector3, color: Color, cone := true) -> MeshInstance3D:
	var key := "l|%.2f|%.2f|%s" % [radius, height, cone]
	var mesh: Mesh = _meshes.get(key)
	if mesh == null:
		if cone:
			var cm := CylinderMesh.new()
			cm.bottom_radius = radius
			cm.top_radius = radius * 0.12
			cm.height = height
			cm.radial_segments = 7
			cm.rings = 1
			mesh = cm
		else:
			var sm := SphereMesh.new()
			sm.radius = radius
			sm.height = height
			sm.radial_segments = 7
			sm.rings = 4
			mesh = sm
		mesh.surface_set_material(0, foliage())
		_meshes[key] = mesh
	var mi := _place(parent, mesh, pos)
	mi.set_instance_shader_parameter("tint", color)
	return mi


static func foliage() -> ShaderMaterial:
	if _foliage == null:
		var sh := Shader.new()
		sh.code = """
shader_type spatial;
instance uniform vec3 tint : source_color = vec3(0.3, 0.5, 0.3);
varying float h;
void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	h = clamp(VERTEX.y + 0.5, 0.0, 2.0);
	VERTEX.x += sin(TIME * 1.3 + w.x * 0.7 + w.z * 0.5) * 0.035 * h;
	VERTEX.z += cos(TIME * 1.1 + w.x * 0.4) * 0.025 * h;
}
void fragment() {
	NORMAL = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));
	ALBEDO = tint;
	ROUGHNESS = 1.0;
}
"""
		_foliage = ShaderMaterial.new()
		_foliage.shader = sh
	return _foliage


static func _place(parent: Node, mesh: Mesh, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
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


## Blocky value noise that wraps at the texture edge: 0..1 per `cell`-pixel block.
static func _patch(x: int, y: int, cell: int, salt: int) -> float:
	var n := TEX / cell
	var h := hash(Vector3i((x / cell) % n, (y / cell) % n, salt))
	return float(h % 1000) / 999.0


## A small greyscale detail texture; the material's colour tints it.
static func texture(pattern: String) -> ImageTexture:
	if _textures.has(pattern):
		return _textures[pattern]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(pattern)
	var im := Image.create(TEX, TEX, true, Image.FORMAT_RGB8)
	for y in TEX:
		for x in TEX:
			var v := 1.0
			match pattern:
				"grass":
					v = 0.93 + 0.07 * _patch(x, y, 8, 11) - 0.03 * _patch(x, y, 2, 5)
				"leaf":
					v = 0.8 + 0.2 * _patch(x, y, 4, 17)
				"asphalt":
					v = 0.9 + 0.08 * _patch(x, y, 4, 3) + 0.04 * _patch(x, y, 1, 9)
				"gravel":
					v = 0.86 + 0.14 * _patch(x, y, 2, 31)
				"carpet":
					v = rng.randf_range(0.92, 1.0)
				"concrete":
					v = 0.95 + 0.05 * _patch(x, y, 4, 21)
					if x == 0 or y == 0:
						v = 0.8
				"siding":
					v = 1.0 - 0.1 * float(y % 16) / 16.0
					if y % 16 == 15:
						v = 0.72
				"shingle":
					var row := y / 8
					v = 0.9 + 0.1 * float((row * 7 + (x + row * 5) / 10) % 3) / 2.0
					if y % 8 == 0 or (x + row * 5) % 10 == 0:
						v = 0.74
				"planks":
					var plank := x / 8
					v = 0.9 + 0.1 * float((plank * 5) % 4) / 3.0
					if x % 8 == 0 or (y + plank * 23) % 64 == 0:
						v = 0.76
				"wood":
					v = 0.92 + 0.08 * sin(float(y) * 0.9 + sin(float(x) * 0.2) * 2.0)
				"tile":
					v = 1.0 if ((x / 16) + (y / 16)) % 2 == 0 else 0.93
					if x % 16 == 0 or y % 16 == 0:
						v = 0.78
				"brick":
					var brow := y / 8
					v = 0.86 + 0.14 * float((brow * 3 + (x + (brow % 2) * 8) / 16) % 4) / 3.0
					if y % 8 == 0 or (x + (brow % 2) * 8) % 16 == 0:
						v = 0.68
			v = clampf(v, 0.0, 1.0)
			im.set_pixel(x, y, Color(v, v, v))
	im.generate_mipmaps()
	var t := ImageTexture.create_from_image(im)
	_textures[pattern] = t
	return t
