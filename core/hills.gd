class_name Hills
# How high the ground is, for everything that stands on it or lies on it. Hills you walk up and down, either side of the road into Cinerea: art/tools/hills.py bakes their heights and the picture that shades them. Everywhere else, and in every other scene, the ground is at 0.

const X0 := -46.0            # art/tools/hills.py: the table's corner, its size and the top of its picture
const Z0 := -62.0
const WIDE := 369
const DEEP := 313
const PER_M := 4.0
const V0 := -67.0
const PICTURE_SIZE := Vector2(92.0, 83.0)    # m the picture covers: x, then z as it shows on screen
const HIGHEST := 4.0         # m, over any of them
const STANCE := 0.4          # m either side of its middle that something standing has feet. Claude's call

static var on: bool:
	get:
		return _users > 0
static var _users := 0
static var _table := PackedFloat32Array()
static var _mesh: ArrayMesh

# A scene with hills turns them on while it's there. Counted: a test's next town can start before the last has gone.
static func start() -> void:
	if _table.is_empty():    # shortcut: read straight from the file, as the floors' pictures are: an export has to include it
		_table = FileAccess.get_file_as_bytes("res://art/floors/hills_height.bin").to_float32_array()
	_users += 1

static func stop() -> void:
	_users -= 1

static func height_at(x: float, z: float) -> float:
	if _users <= 0:
		return 0.0
	var fx := (x - X0) * PER_M
	var fz := (z - Z0) * PER_M
	var i := floori(fx)
	var j := floori(fz)
	if i < 0 or j < 0 or i >= WIDE - 1 or j >= DEEP - 1:
		return 0.0
	var at := j * WIDE + i
	var a := fx - i
	return lerpf(lerpf(_table[at], _table[at + 1], a), lerpf(_table[at + WIDE], _table[at + WIDE + 1], a), fz - j)

# How much the ground rises per metre, going +x and going +z.
static func slope(x: float, z: float) -> Vector2:
	const E := 0.125
	return Vector2(height_at(x + E, z) - height_at(x - E, z), height_at(x, z + E) - height_at(x, z - E)) / (2.0 * E)

# 1 m up shows on screen as this many m of ground depth.
static func _back() -> float:
	var a := deg_to_rad(Pixel.PITCH_DEG)
	return cos(a) / sin(a)

# How much higher the ground is `by` (x, z) from `from`, whose feet are on it: a blow lands at the height of the ground it lands on.
static func rise(from: Vector3, by: Vector2) -> float:
	return height_at(from.x + by.x, from.z + by.y) - from.y if _users > 0 else 0.0

# How far toward the camera something standing here is drawn. It changes nothing on screen, but across a slope the ground would otherwise cut off its uphill foot.
static func lean(x: float, z: float) -> Vector3:
	if _users <= 0:
		return Vector3.ZERO
	var d := slope(x, z)
	if d.x == 0.0:
		return Vector3.ZERO
	var a := deg_to_rad(Pixel.PITCH_DEG)
	return Vector3(0.0, sin(a), cos(a)) * STANCE * absf(d.x) / (sin(a) - cos(a) * maxf(d.y, 0.0))

# Lays a flat picture on the ground at x, z, `up` m above it. `depth`: its scale.z on flat ground. On a slope it tilts with the ground and is sheared so that it shows on screen exactly as it does on the flat, so each texel stays one screen pixel.
static func lay(s: Node3D, x: float, z: float, up: float, depth := 4.0 / 3.0) -> void:
	var d := slope(x, z)
	var k := 1.0 / (1.0 - _back() * d.y)
	var along := _back() * d.x * k
	s.global_transform = Transform3D(Basis(Vector3(1.0, d.x + d.y * along, along), Vector3.UP, Vector3(0.0, d.y * k * depth, k * depth)), Pixel.snap(Vector3(x, height_at(x, z), z)) + Vector3.UP * up)

# A plane `size` m across under `m`, lifted onto the ground so that a mark on it lies over the hills instead of through them. Its UVs are a PlaneMesh's.
static func drape(m: MeshInstance3D, size: Vector2, up: float) -> void:
	const STEP := 0.5
	var across := ceili(size.x / STEP)
	var deep := ceili(size.y / STEP)
	var there := m.global_transform
	var back := there.affine_inverse()
	var at := PackedVector3Array()
	var uv := PackedVector2Array()
	var normal := PackedVector3Array()
	var tri := PackedInt32Array()
	for j in deep + 1:
		for i in across + 1:
			var p := there * Vector3((float(i) / across - 0.5) * size.x, 0.0, (float(j) / deep - 0.5) * size.y)
			at.append(back * Vector3(p.x, height_at(p.x, p.z) + up, p.z))
			uv.append(Vector2(float(i) / across, float(j) / deep))
			normal.append(Vector3.UP)
			if i < across and j < deep:
				var c := j * (across + 1) + i
				tri.append_array([c, c + 1, c + across + 1, c + 1, c + across + 2, c + across + 1])
	m.mesh = _built(at, uv, normal, tri)

# Where a line from the camera first meets the ground.
static func on_ray(from: Vector3, dir: Vector3) -> Vector3:
	var at := from + dir * ((HIGHEST - from.y) / dir.y)
	var down := dir * 0.05 / -dir.y
	while at.y > 0.0 and at.y > height_at(at.x, at.z):
		at += down
	return Vector3(at.x, height_at(at.x, at.z), at.z)

# The ground of the hills, only where there are any: the flat sand lies under the rest. Its normals all point up, as the flat ground's do, because the picture has the light on it. Each point shows the part of the picture that's at its place on screen.
static func mesh() -> ArrayMesh:
	if _mesh:
		return _mesh
	var at := PackedVector3Array()
	var uv := PackedVector2Array()
	var normal := PackedVector3Array()
	var tri := PackedInt32Array()
	var ids := PackedInt32Array()
	ids.resize(WIDE * DEEP)
	ids.fill(-1)
	for j in DEEP - 1:
		for i in WIDE - 1:
			var c := j * WIDE + i
			if _table[c] == 0.0 and _table[c + 1] == 0.0 and _table[c + WIDE] == 0.0 and _table[c + WIDE + 1] == 0.0:
				continue
			for k: int in [c, c + 1, c + WIDE, c + WIDE + 1]:
				if ids[k] < 0:
					ids[k] = at.size()
					var p := Vector3(X0 + (k % WIDE) / PER_M, _table[k], Z0 + floorf(float(k) / WIDE) / PER_M)
					at.append(p)
					uv.append(Vector2((p.x - X0) / PICTURE_SIZE.x, (p.z - p.y * _back() - V0) / PICTURE_SIZE.y))
					normal.append(Vector3.UP)
			tri.append_array([ids[c], ids[c + 1], ids[c + WIDE], ids[c + 1], ids[c + WIDE + 1], ids[c + WIDE]])
	_mesh = _built(at, uv, normal, tri)
	return _mesh

static func _built(at: PackedVector3Array, uv: PackedVector2Array, normal: PackedVector3Array, tri: PackedInt32Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = at
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_NORMAL] = normal
	arrays[Mesh.ARRAY_INDEX] = tri
	var made := ArrayMesh.new()
	made.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return made
