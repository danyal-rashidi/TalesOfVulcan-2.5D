class_name Arena extends Node3D
# The colosseum, built in code the way tools/test_room/main.gd builds its room: a round floor of sand and stone, walls of arches seen
# from above (tall to the north round the gate, broken down to the south where the breach lets Elvis in) and the plinth at the centre
# where the statue kneels. Blows crack the floor, glowing and cooling; set_mood() turns the sun and the air. It stays at the origin.

const RADIUS := 11.0               # the floor's radius, to the wall's inner face (m)
const WALL := 1.0                  # the wall's thickness
const TALL := Pixel.STEP * 4.0     # the north wall, 3 m: 64 px of arches on screen
const PLINTH := 1.5                # half the plinth's side: a 3 m square block
const PLINTH_H := Pixel.STEP       # 0.75 m, a 16 px front face; plinth() is the middle of its top
const SEGMENTS := 96               # wall pieces round the circle
const MAX_CRACKS := 24             # the plan (Unreal BossCracks.h MaxMarks is 10)
const COOL_TAU := 2.2              # s: a crack's lava cools with this time constant, out by 6 s (Unreal BossCracks.h CoolSeconds)
const FLOOR_M := 26.0              # the painted floor's side; plain sand beyond it
const TPM := Vector2(32.0, 24.0)   # floor texels per metre in x and z: one texel per screen pixel
const FACE_TPM := 21.17            # wall-face texels per metre of height: Pixel.PX * cos(Pixel.PITCH_DEG)
const CRACK := preload("res://arena/crack.gdshader")
const SAND := Color8(150, 128, 102)
const STONE := Color8(112, 102, 98)        # a little warmer than the test room's stone top (104, 94, 92)
const BRICK := Color8(146, 124, 102)       # sandstone
const DARK := Color8(30, 22, 26)           # inside the arches
const IRON := Color8(66, 60, 70)
const RUBBLE: Array[Vector4] = [Vector4(-1.4, 11.3, 0.4, 0.75), Vector4(-0.5, 11.9, 0.3, 0.375), Vector4(0.4, 11.2, 0.45, 0.5625),
	Vector4(1.3, 11.7, 0.35, 0.75), Vector4(0.9, 12.4, 0.25, 0.375), Vector4(-1.0, 12.5, 0.3, 0.1875)]
# mood: [sun colour, sun energy, ambient colour, ambient energy, background]
const MOODS := {
	&"calm": [Color(1.0, 0.93, 0.84), 1.1, Color(0.85, 0.92, 1.0), 0.5, Color8(58, 48, 44)],    # sun about 5600 K, sky light: Unreal PrologueStorm.h DaySunTemperature, DaySkyLightColor
	&"storm": [Color(0.62, 0.58, 0.78), 0.55, Color(0.7, 0.7, 0.8), 0.4, Color8(26, 22, 34)],   # ambient: Unreal PrologueStorm.h storm SkyLightColor
	&"blood": [Color(1.0, 0.22, 0.06), 0.9, Color(1.0, 0.33, 0.21), 0.3, Color8(34, 10, 9)],   # Unreal PrologueStorm.h storm SunColor; ambient its FogColor's hue
	&"clear": [Color(1.0, 0.85, 0.7), 1.25, Color(1.0, 0.9, 0.78), 0.5, Color8(70, 56, 46)],     # Unreal PrologueStorm.h FillGoldColor
}
const FLASH := Color(0.55, 0.72, 1.0)    # Unreal PrologueStorm.h LightningColor

var sun: DirectionalLight3D

static var _tex := {}    # name -> texture, painted once a run (the floor takes a moment)
var _env: Environment
var _flash: DirectionalLight3D
var _mood: Tween
var _flashing: Tween
var _cracks: Array[Dictionary] = []    # {node, mat, age}, oldest first

func _ready() -> void:
	_lights()
	_floor()
	_walls()
	_plinth()
	set_mood(&"calm", 0.0)

func entrance() -> Vector3:
	return Vector3(0.0, 0.0, RADIUS - 1.5)    # just inside the south breach

func plinth() -> Vector3:
	return Vector3(0.0, PLINTH_H, 0.0)

func gate() -> Vector3:
	return Vector3(0.0, 0.0, -(RADIUS - 1.0))

# Glowing cracks where a blow lands, a new pattern each time, cooling from white-hot to a dark scar over 6 s. The oldest go past 24.
func crack(at: Vector3, radius: float) -> void:
	var tex := _crack_texture(radius)
	var mat := ShaderMaterial.new()
	mat.shader = CRACK
	mat.set_shader_parameter(&"tex", tex)
	var plane := PlaneMesh.new()
	plane.size = Vector2(tex.get_width() / TPM.x, tex.get_height() / TPM.y)
	var m := MeshInstance3D.new()
	m.mesh = plane
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	m.global_position = Pixel.snap(at) + Vector3(0.0, 0.01, 0.0)
	_cracks.append({"node": m, "mat": mat, "age": 0.0})
	while _cracks.size() > MAX_CRACKS:
		(_cracks.pop_front()["node"] as Node).queue_free()

func clear_cracks() -> void:
	for c in _cracks:
		(c["node"] as Node).queue_free()
	_cracks.clear()

func crack_count() -> int:
	return _cracks.size()

# &"calm" a dusty day, &"storm" dark grey-purple, &"blood" the red sun, &"clear" warm sunlight; over `seconds` (0: at once).
func set_mood(mood: StringName, seconds: float) -> void:
	if not MOODS.has(mood):
		push_warning("Arena: no mood called %s" % mood)
		return
	var m: Array = MOODS[mood]
	var to := [[sun, "light_color", m[0]], [sun, "light_energy", m[1]], [_env, "ambient_light_color", m[2]],
		[_env, "ambient_light_energy", m[3]], [_env, "background_color", m[4]]]
	if _mood:
		_mood.kill()
	if seconds <= 0.0:
		for t: Array in to:
			(t[0] as Object).set(t[1], t[2])
		return
	_mood = create_tween().set_parallel()
	for t: Array in to:
		_mood.tween_property(t[0], t[1], t[2], seconds)

# The sky's flash: a blue-white light from overhead, two strokes, gone in half a second. Fx lightning draws the bolt.
func lightning_flash() -> void:
	if _flashing:
		_flashing.kill()
	_flash.light_energy = 3.0
	_flashing = create_tween()
	_flashing.tween_property(_flash, "light_energy", 0.3, 0.08)
	_flashing.tween_property(_flash, "light_energy", 2.2, 0.04)
	_flashing.tween_property(_flash, "light_energy", 0.0, 0.4)

func _process(delta: float) -> void:
	for c in _cracks:
		var age: float = c["age"]
		if age < 8.0:
			c["age"] = age + delta
			(c["mat"] as ShaderMaterial).set_shader_parameter(&"heat", exp(-(age + delta) / COOL_TAU))

func _lights() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)    # the test room's
	sun.shadow_enabled = true
	add_child(sun)
	_flash = DirectionalLight3D.new()
	_flash.rotation_degrees = Vector3(-80, 0, 0)    # from nearly overhead, as Unreal's statue strike (BossArena.cpp, bFromAbove)
	_flash.light_color = FLASH
	_flash.light_energy = 0.0
	add_child(_flash)

# --- the floor, the walls and the plinth: each face one texel per screen pixel, as in the test room ---

func _floor() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(FLOOR_M, FLOOR_M)
	var m := MeshInstance3D.new()
	m.mesh = plane
	m.material_override = _mat(_texture(&"floor"))
	add_child(m)
	var around := PlaneMesh.new()    # plain sand out to the edge of any view
	around.size = Vector2(80.0, 80.0)
	var out := MeshInstance3D.new()
	out.mesh = around
	out.material_override = _mat(_texture(&"outside"), Vector2(20.0, 20.0))
	out.position.y = -0.02
	add_child(out)

func _walls() -> void:
	var inner := SurfaceTool.new()
	var outer := SurfaceTool.new()
	var top := SurfaceTool.new()
	for st: SurfaceTool in [inner, outer, top]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ro := RADIUS + WALL
	var heights := PackedFloat32Array()
	for i in SEGMENTS:
		heights.append(_wall_height(i))
	for i in SEGMENTS:
		var h := heights[i]
		var a0 := TAU * i / SEGMENTS
		var a1 := TAU * (i + 1) / SEGMENTS
		var before := heights[(i + SEGMENTS - 1) % SEGMENTS]
		if before != h:    # the side of a step in the broken wall
			var lo := minf(before, h)
			var hi := maxf(before, h)
			var uw := WALL * TPM.x / 128.0
			_quad(outer, [_at(a0, RADIUS, lo), _at(a0, ro, lo), _at(a0, ro, hi), _at(a0, RADIUS, hi)],
				[Vector2(0, _face_v(lo)), Vector2(uw, _face_v(lo)), Vector2(uw, _face_v(hi)), Vector2(0, _face_v(hi))], Vector3(cos(a0), 0, sin(a0)))
		if h <= 0.0:
			continue
		var u0 := a0 / TAU + 0.5    # the gate (north, a = 0) is the middle of the arches' texture
		var u1 := a1 / TAU + 0.5
		var vt := (TALL - h) / TALL
		_quad(inner, [_at(a0, RADIUS, 0), _at(a1, RADIUS, 0), _at(a1, RADIUS, h), _at(a0, RADIUS, h)],
			[Vector2(u0, 1), Vector2(u1, 1), Vector2(u1, vt), Vector2(u0, vt)], Vector3(-sin(a0), 0, cos(a0)))
		var w0 := a0 * ro * TPM.x / 128.0
		var w1 := a1 * ro * TPM.x / 128.0
		_quad(outer, [_at(a0, ro, 0), _at(a1, ro, 0), _at(a1, ro, h), _at(a0, ro, h)],
			[Vector2(w0, _face_v(0)), Vector2(w1, _face_v(0)), Vector2(w1, _face_v(h)), Vector2(w0, _face_v(h))], Vector3(sin(a0), 0, -cos(a0)))
		var corners := [_at(a0, RADIUS, h), _at(a1, RADIUS, h), _at(a1, ro, h), _at(a0, ro, h)]
		var uvs := []
		for c: Vector3 in corners:
			uvs.append(Vector2(c.x, c.z) / 4.0)    # world-aligned, so the top's slabs line up with the floor's pixel grid
		_quad(top, corners, uvs, Vector3.UP)
	for b: Vector4 in RUBBLE:    # x, z, half size, height: tumbled blocks that fill the breach
		var hs := b.z
		var y := b.w
		var c := [Vector3(b.x - hs, y, b.y - hs), Vector3(b.x + hs, y, b.y - hs), Vector3(b.x + hs, y, b.y + hs), Vector3(b.x - hs, y, b.y + hs)]
		var uvs := []
		for p: Vector3 in c:
			uvs.append(Vector2(p.x, p.z) / 4.0)
		_quad(top, c, uvs, Vector3.UP)
		var u0 := (b.x - hs) * TPM.x / 128.0
		var u1 := (b.x + hs) * TPM.x / 128.0
		_quad(outer, [Vector3(b.x - hs, 0, b.y + hs), Vector3(b.x + hs, 0, b.y + hs), Vector3(b.x + hs, y, b.y + hs), Vector3(b.x - hs, y, b.y + hs)],
			[Vector2(u0, _face_v(0.0)), Vector2(u1, _face_v(0.0)), Vector2(u1, _face_v(y)), Vector2(u0, _face_v(y))], Vector3.BACK)
	for pair: Array in [[inner, &"arches"], [outer, &"brick"], [top, &"top"]]:
		var m := MeshInstance3D.new()
		m.mesh = (pair[0] as SurfaceTool).commit()
		m.material_override = _mat(_texture(pair[1]))
		add_child(m)
	var body := StaticBody3D.new()    # the round wall, closed all the way round (rubble fills the breach)
	for i in 48:
		var a := TAU * (i + 0.5) / 48.0
		var box := BoxShape3D.new()
		box.size = Vector3(2.0 * (RADIUS + WALL / 2.0) * tan(PI / 48.0) + 0.1, TALL, WALL)
		var c := CollisionShape3D.new()
		c.shape = box
		c.position = _at(a, RADIUS + WALL / 2.0, TALL / 2.0)
		c.rotation.y = -a
		body.add_child(c)
	add_child(body)

# Tall to the north, crumbling round the sides, low ruins to the south and nothing at the breach.
func _wall_height(i: int) -> float:
	var deg := rad_to_deg(absf(wrapf(TAU * (i + 0.5) / SEGMENTS, -PI, PI)))    # 0 north, 180 south
	var jag := floorf(_hash(i, 1) * 2.0)
	if deg > 170.0:
		return 0.0
	if deg > 125.0:
		return Pixel.STEP * (1.0 + jag)
	if deg > 100.0:
		return Pixel.STEP * (2.0 + jag)
	return TALL

func _plinth() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * PLINTH * 2.0
	var top := MeshInstance3D.new()
	top.mesh = plane
	top.material_override = _mat(_texture(&"plinth_top"))
	top.position.y = PLINTH_H
	add_child(top)
	var quad := QuadMesh.new()
	quad.size = Vector2(PLINTH * 2.0, PLINTH_H)
	var front := MeshInstance3D.new()
	front.mesh = quad
	front.material_override = _mat(_texture(&"plinth_front"))
	front.position = Vector3(0.0, PLINTH_H / 2.0, PLINTH)
	add_child(front)
	var box := BoxShape3D.new()
	box.size = Vector3(PLINTH * 2.0, PLINTH_H, PLINTH * 2.0)
	var c := CollisionShape3D.new()
	c.shape = box
	c.position.y = PLINTH_H / 2.0
	var body := StaticBody3D.new()
	body.add_child(c)
	add_child(body)

# The brick texture's v at `y` m up a wall face, so every face's courses line up.
func _face_v(y: float) -> float:
	return (TALL - y) * FACE_TPM / 64.0

func _at(a: float, r: float, y: float) -> Vector3:
	return Vector3(sin(a) * r, y, -cos(a) * r)

func _quad(st: SurfaceTool, p: Array, uv: Array, n: Vector3) -> void:
	for i: int in [0, 1, 2, 0, 2, 3]:
		st.set_normal(n)
		st.set_uv(uv[i])
		st.add_vertex(p[i])

func _mat(tex: Texture2D, tiles := Vector2.ONE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.uv1_scale = Vector3(tiles.x, tiles.y, 1.0)
	return m

# --- textures: posterized noise in a few tones of one colour, so they read as pixel art (the test room's way) ---

func _texture(key: StringName) -> ImageTexture:
	if not _tex.has(key):
		var img: Image
		match key:
			&"floor": img = _paint_floor()
			&"outside": img = _paint(128, 96, SAND.darkened(0.25), 9, "sand")
			&"arches": img = _paint_arches()
			&"brick": img = _paint(128, 64, BRICK.darkened(0.12), 5, "brick")
			&"top": img = _paint(128, 96, STONE, 3, "slab")
			&"plinth_top": img = _paint_plinth_top()
			&"plinth_front": img = _paint(96, 16, STONE.darkened(0.1), 4, "blocks")
		_tex[key] = ImageTexture.create_from_image(img)
	return _tex[key]

func _paint(w: int, h: int, base: Color, seed_: int, kind: String) -> Image:
	var n := _noise(seed_)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var c := _tone(n, x, y, base)
			match kind:
				"sand":
					if _hash(x, y) < 0.006:
						c = base.darkened(0.3)
				"slab":    # 1 m slabs: light top and left edge, dark grout right and bottom
					if x % 32 == 31 or y % 24 == 23:
						c = base.darkened(0.45)
					elif x % 32 == 0 or y % 24 == 0:
						c = c.lightened(0.18)
				"brick":
					c = _brick(n, x, y, base)
				"blocks":    # the plinth's face: three dressed blocks, lit along the top
					if x % 32 == 31 or y == h - 1:
						c = base.darkened(0.45)
					elif y == 0:
						c = base.lightened(0.25)
					elif x % 32 == 0:
						c = c.lightened(0.12)
			img.set_pixel(x, y, c)
	return img

# Paving round the plinth in rings of slabs, a ring of slabs along the wall, sand between. Each texel gets its slab's key first, so
# the grout is always exactly one pixel wide.
func _paint_floor() -> Image:
	var w := roundi(FLOOR_M * TPM.x)
	var h := roundi(FLOOR_M * TPM.y)
	var keys := PackedInt32Array()
	keys.resize(w * h)
	var edge_n := roundi(TAU * RADIUS / 1.2)
	for j in h:
		var z := (j + 0.5) / TPM.y - FLOOR_M / 2.0
		for i in w:
			var x := (i + 0.5) / TPM.x - FLOOR_M / 2.0
			var r := sqrt(x * x + z * z)
			var turn := atan2(x, -z) / TAU + 0.5
			var k := -1
			if r < 3.4:
				var ring := floori(r / 0.85)
				k = ring * 100 + floori(turn * maxi(1, roundi(TAU * (ring + 0.5) * 0.85 / 1.1)))
			elif r > RADIUS - 0.9 and r < RADIUS + WALL + 0.3:
				k = 10000 + floori(turn * edge_n)
			elif r >= RADIUS + WALL + 0.3:
				k = -2    # outside the wall
			keys[j * w + i] = k
	var n := _noise(11)
	var drift := _noise(12)
	drift.frequency = 0.02
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for j in h:
		for i in w:
			var k := keys[j * w + i]
			var c: Color
			if k < 0:
				var d := drift.get_noise_2d(i, j * TPM.x / TPM.y)    # drifts of paler and darker sand, round on the floor
				var base := SAND.lightened(0.07) if d > 0.25 else SAND.darkened(0.08) if d < -0.25 else SAND
				c = _tone(n, i, j, base if k == -1 else base.darkened(0.25))
				if _hash(i, j) < 0.006:
					c = c.darkened(0.3)    # pebbles
			elif k != keys[j * w + mini(i + 1, w - 1)] or k != keys[mini(j + 1, h - 1) * w + i]:
				c = STONE.darkened(0.45)    # grout, right and below each slab
			else:
				c = _tone(n, i, j, STONE.darkened(0.12 * _hash(k, 3)))
				if k != keys[j * w + maxi(i - 1, 0)] or k != keys[maxi(j - 1, 0) * w + i]:
					c = c.lightened(0.18)    # the lit edge, left and above
			img.set_pixel(i, j, c)
	return img

# Brick courses with a cornice along the top and 28 round arches, the gate the middle one: wider, taller, with a portcullis.
func _paint_arches() -> Image:
	var w := roundi(TAU * RADIUS * TPM.x)
	var h := roundi(TALL * FACE_TPM)
	var n := _noise(5)
	var period := w / 28.0
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var c := _brick(n, x, y, BRICK)
			var k := roundf((x + 0.5 - w / 2.0) / period)
			var dx := absf(x + 0.5 - (w / 2.0 + k * period))
			var gate := k == 0.0
			var hw := 28.0 if gate else 17.0
			var spring := 32.0 if gate else 38.0    # where the round top begins
			var d := dx if y >= spring else Vector2(dx, spring - y - 0.5).length()
			if absf(dx - period / 2.0) < 3.0:
				c = BRICK.lightened(0.1) if dx < period / 2.0 + 1.0 else BRICK.darkened(0.3)    # a pilaster between arches
			if y < 4:
				c = BRICK.lightened(0.22 if y == 0 else 0.12)    # the cornice
			elif y == 4:
				c = BRICK.darkened(0.45)
			if d < hw:
				c = DARK if y < h - 5 else DARK.lightened(0.15)    # the arcade's floor shows at the bottom
				if gate and (int(dx) % 6 == 0 or y % 8 == 0):
					c = IRON
			elif d < hw + 3.0:
				c = BRICK.lightened(0.16) if d < hw + 2.0 else BRICK.darkened(0.4)    # the arch stones
			img.set_pixel(x, y, c)
	return img

# One dressed slab with a carved border and a ring cut in it.
func _paint_plinth_top() -> Image:
	var w := roundi(PLINTH * 2.0 * TPM.x)
	var h := roundi(PLINTH * 2.0 * TPM.y)
	var n := _noise(8)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var c := _tone(n, x, y, STONE.lightened(0.06))
			var edge := mini(mini(x, w - 1 - x), mini(y, h - 1 - y))
			var ring := Vector2((x + 0.5) / TPM.x - PLINTH, (y + 0.5) / TPM.y - PLINTH).length()
			if edge == 0:
				c = STONE.lightened(0.25) if x == 0 or y == 0 else STONE.darkened(0.45)
			elif edge == 4:
				c = STONE.darkened(0.3)
			elif absf(ring - 0.95) < 0.035:
				c = STONE.darkened(0.3)
			img.set_pixel(x, y, c)
	return img

# Jagged cracks running out from a blow, as texels: red 1 the open crack, red 0.5 its rim. Even sizes, so they sit on the pixel grid.
func _crack_texture(radius: float) -> ImageTexture:
	var w := maxi(8, roundi(radius * TPM.x) * 2)
	var h := maxi(6, roundi(radius * TPM.y) * 2)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var mid := Vector2(w, h) / 2.0
	var todo: Array[Vector4] = []    # branches to draw: start x, y, heading, length in m
	var branches := rng.randi_range(5, 8)
	for b in branches:
		todo.append(Vector4(mid.x, mid.y, TAU * (b + rng.randf_range(-0.3, 0.3)) / branches, radius * rng.randf_range(0.55, 1.0)))
	while not todo.is_empty():
		var t: Vector4 = todo.pop_back()
		var p := Vector2(t.x, t.y)
		var bend := 0.0
		var walked := 0.0
		while walked < t.w:
			bend = clampf(bend + rng.randf_range(-0.35, 0.35), -0.6, 0.6)
			p += Vector2(cos(t.z + bend), sin(t.z + bend) * TPM.y / TPM.x)    # a step of 1/32 m on the floor
			walked += 1.0 / TPM.x
			if p.x < 1.0 or p.y < 1.0 or p.x >= w - 1 or p.y >= h - 1:
				break
			img.set_pixel(int(p.x), int(p.y), Color.WHITE)
			if walked < radius * 0.25:
				img.set_pixel(int(p.x) + 1, int(p.y), Color.WHITE)    # wider near the blow
			if t.w > radius * 0.3 and rng.randf() < 0.03:
				todo.append(Vector4(p.x, p.y, t.z + bend + rng.randf_range(0.5, 0.9) * (1.0 if rng.randf() < 0.5 else -1.0), (t.w - walked) * 0.5))
	for y in range(-2, 3):    # the crater at the heart of the blow
		for x in range(-3, 4):
			if x * x / 9.0 + y * y / 4.0 <= 1.0:
				img.set_pixel(int(mid.x) + x, int(mid.y) + y, Color.WHITE)
	var rim := Color(0.5, 0.5, 0.5)
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			if img.get_pixel(x, y).a == 0.0 and (img.get_pixel(x + 1, y).r == 1.0 or img.get_pixel(x - 1, y).r == 1.0
					or img.get_pixel(x, y + 1).r == 1.0 or img.get_pixel(x, y - 1).r == 1.0):
				img.set_pixel(x, y, rim)
	return ImageTexture.create_from_image(img)

func _brick(n: FastNoiseLite, x: int, y: int, base: Color) -> Color:
	var row := floori(y / 8.0)
	if y % 8 == 7 or (x + (row % 2) * 8) % 16 == 15:
		return base.darkened(0.5)
	var c := _tone(n, x, y, base)
	return c.lightened(0.08) if y % 8 == 0 else c

func _tone(n: FastNoiseLite, x: int, y: int, base: Color) -> Color:
	var v := n.get_noise_2d(x, y)
	if v > 0.22:
		return base.lightened(0.10)
	if v < -0.28:
		return base.darkened(0.16)
	return base

func _noise(seed_: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_
	n.frequency = 0.18
	return n

func _hash(a: float, b: float) -> float:
	return fposmod(sin(a * 12.9898 + b * 78.233) * 43758.5453, 1.0)
