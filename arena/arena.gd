class_name Arena extends Node3D
# The colosseum, built in code the way tools/test_room/main.gd builds its room: a round floor of sand and stone, walls of arches seen
# from above (tall to the north round the gate, in ruins round the sides, broken down to the south where the breach lets Elvis in) and the plinth at the centre
# where the statue kneels. Blows crack the floor, glowing and cooling; set_mood() turns the sun and the air. It stays at the origin.

const RADIUS := 11.0               # the floor's radius, to the wall's inner face (m)
const WALL := 1.0                  # the wall's thickness
const TALL := Pixel.STEP * 4.0     # the north wall, 3 m: 64 px of arches on screen
const PLINTH := 1.5                # half the plinth's side: a 3 m square block
const PLINTH_H := Pixel.STEP       # 0.75 m, a 16 px front face; plinth() is the middle of its top
const SEGMENTS := 96               # wall pieces round the circle
const MAX_CRACKS := 24             # the plan (Unreal BossCracks.h MaxMarks is 10)
const COOL_TAU := 2.2              # s: a crack's lava cools with this time constant, out by 6 s (Unreal BossCracks.h CoolSeconds)
const WAY_REACH := 3.5              # m: way() only looks at blocks this near the straight line, enough to go round the plinth. Shortcut: a wall of blocks wider than this could be cut through; there isn't one. Claude's call
const SOLID_TOP := 0.875           # m: a block stops you to this height however low it's drawn, so a capsule (round to 0.45 m) always meets its side, and one landing on it is pushed aside, not up (the widest block and the boss need 0.87). Under the fireballs, at 0.9 and up. Claude's call
const FLOOR_M := 26.0              # the painted floor's side; plain sand beyond it
const TPM := Vector2(32.0, 24.0)   # floor texels per metre in x and z: one texel per screen pixel
const FACE_TPM := 21.17            # wall-face texels per metre of height: Pixel.PX * cos(Pixel.PITCH_DEG)
const CRACK := preload("res://arena/crack.gdshader")
const PROP := preload("res://arena/prop.gdshader")
const LIT := preload("res://arena/lit.gdshader")    # every face: the effects' lights land on it in hard steps
const SAND := Color8(192, 170, 98)    # desert, the same inside the wall and out and as Cinerea's, so no line shows where one sand meets another (Danyal)
const STONE := Color8(112, 102, 98)        # a little warmer than the test room's stone top (104, 94, 92)
const SLAB := Color8(150, 138, 114)        # the floor's stone: warm like the desert, so the old paving doesn't shout, but duller than the sand, or tests/test_steps.gd takes it for sand. Claude's call
const BRICK := Color8(146, 124, 102)       # sandstone
const DARK := Color8(30, 22, 26)           # inside the arches
const IRON := Color8(66, 60, 70)
const RUBBLE: Array[Vector4] = [Vector4(-1.4, 11.3, 0.4, 0.75), Vector4(-2.5, 11.9, 0.3, 0.375), Vector4(0.4, 11.2, 0.45, 0.5625),    # x, z, half size, height. A lane stays clear of them at x -0.6 to -0.45, wide enough for the boss's feet: way() needs one, tests/test_opening.gd walks it
	Vector4(1.3, 11.7, 0.35, 0.75), Vector4(0.9, 12.4, 0.25, 0.375), Vector4(-1.3, 12.5, 0.3, 0.1875)]
# Broken columns standing in from the wall: x, z, half size, height.
const STUMPS: Array[Vector4] = [Vector4(-4.1, -8.6, 0.32, 2.25), Vector4(4.3, -8.5, 0.32, 1.5), Vector4(-7.6, -5.6, 0.32, 1.5), Vector4(7.9, -5.2, 0.32, 2.25),
	Vector4(-9.4, -1.2, 0.32, 0.75), Vector4(9.3, -1.6, 0.32, 1.5), Vector4(-8.8, 3.6, 0.32, 1.5), Vector4(8.9, 3.3, 0.32, 0.75), Vector4(-5.9, 7.6, 0.32, 0.75), Vector4(6.2, 7.3, 0.32, 1.5)]
# What the old fights left lying about, in small groups near the wall (art/props/<name>.png; you walk through them): name, x, z.
const PROPS: Array[Array] = [["shield_rect_a", -5.0, -8.2], ["spear_a", -3.4, -8.2], ["skull_a", -4.6, -7.6], ["banner_a", 5.2, -8.0], ["bones_a", 3.6, -7.7],
	["wheel_a", -8.6, -4.9], ["amphora_a", -7.0, -4.6], ["shards_a", -6.4, -5.2], ["shield_round_a", 6.9, -4.6], ["sword_a", 8.8, -4.2], ["helmet_a", 7.6, -3.9],
	["ribs_a", -8.7, -0.3], ["skulls_a", -9.6, 0.6], ["breastplate_a", 8.3, -0.8], ["sword_broken_a", 9.3, -0.1], ["skull_b", -6.2, 1.0], ["shield_half_a", -5.4, 2.2],
	["bones_b", 5.6, 1.4], ["spear_b", 6.6, 2.0], ["banner_b", -8.0, 4.6], ["skulls_b", -9.0, 5.0], ["helmet_b", -7.2, 5.2], ["wheel_b", 8.2, 4.6],
	["shield_rect_b", 7.4, 5.3], ["shards_b", 8.8, 5.6], ["ribs_b", -4.8, 7.6], ["breastplate_b", -6.3, 6.7], ["amphora_b", -3.6, 8.6], ["sword_b", 5.0, 7.4],
	["shield_round_b", 6.6, 8.0], ["sword_broken_b", 3.8, 8.4], ["shield_half_b", 4.4, 6.6]]
# How many steps of wall stand at each angle from the gate, on each side (Danyal, 31 Oct: heavily ruined sides, the north gate whole).
const RUIN_EAST: Array[Vector2] = [Vector2(30, 4), Vector2(42, 3), Vector2(52, 1), Vector2(66, 0), Vector2(74, 1), Vector2(84, 3), Vector2(92, 3), Vector2(102, 1), Vector2(125, 1), Vector2(150, 2), Vector2(170, 1)]
const RUIN_WEST: Array[Vector2] = [Vector2(30, 4), Vector2(48, 3), Vector2(66, 3), Vector2(78, 1), Vector2(96, 0), Vector2(104, 2), Vector2(122, 2), Vector2(136, 0), Vector2(150, 1), Vector2(170, 0)]
# The one table of light and colour, a row a mood. [sun colour, sun energy, ambient colour (the shadows' colour on the ground), ambient energy, background,
# then the grade (core/grade.gd, in the order of Grade.UNIFORMS): what the darks lean to, how far, the light at the middle of the screen, at the edge, how far the pool reaches, saturation; then how much the sun lights the sprites]
# Keep pool and edge close, and reach past the screen's corners (1.02): further apart a flat stretch of sand shows a bullseye that travels with him. A mood's feeling comes from the two colours together, not from the difference. By day pool and edge keep blue at or under green, and only the darks lean cool: tinted further, the whole road turned lilac and the town's cobbles salmon, and old stone is warm (Danyal). Claude's call
const MOODS := {
	&"calm": [Color(1.0, 0.93, 0.84), 1.1, Color(0.8, 0.86, 1.0), 0.5, Color8(58, 48, 44), Color(0.36, 0.3, 0.42), 0.4, Color(0.97, 0.96, 0.95), Color(0.9, 0.89, 0.88), 1.05, 0.95, 0.0],    # sun about 5600 K, sky light: Unreal PrologueStorm.h DaySunTemperature, DaySkyLightColor
	&"storm": [Color(0.62, 0.58, 0.78), 0.55, Color(0.7, 0.7, 0.8), 0.4, Color8(26, 22, 34), Color(0.3, 0.25, 0.46), 0.5, Color(0.87, 0.86, 0.97), Color(0.79, 0.78, 0.91), 1.05, 0.9, 0.0],   # ambient: Unreal PrologueStorm.h storm SkyLightColor
	&"blood": [Color(1.0, 0.24, 0.1), 0.3, Color(0.45, 0.2, 0.38), 0.24, Color8(24, 6, 8), Color(0.32, 0.1, 0.2), 0.5, Color(0.96, 0.84, 0.86), Color(0.8, 0.7, 0.72), 1.05, 1.0, 1.0],   # Unreal PrologueStorm.h storm SunColor. The ground dark, so what stands on it and what glows on it read
	&"hush": [Color(0.8, 0.62, 0.55), 0.42, Color(0.72, 0.64, 0.62), 0.28, Color8(30, 24, 22), Color(0.3, 0.26, 0.36), 0.35, Color(0.8, 0.78, 0.78), Color(0.73, 0.71, 0.7), 1.05, 0.85, 0.0],   # Claude's call: the day dims round the tomb's light
	&"clear": [Color(1.0, 0.83, 0.64), 1.3, Color(0.84, 0.8, 0.92), 0.5, Color8(70, 56, 46), Color(0.36, 0.28, 0.42), 0.35, Color(0.99, 0.97, 0.94), Color(0.92, 0.9, 0.88), 1.05, 1.0, 0.0],     # Unreal PrologueStorm.h FillGoldColor
	# Claude's calls: the rest of the walk, each with its own feeling.
	&"dust": [Color(0.8, 0.62, 0.55), 0.42, Color(0.72, 0.64, 0.62), 0.28, Color8(30, 24, 22), Color(0.42, 0.28, 0.32), 0.5, Color(0.94, 0.89, 0.85), Color(0.86, 0.81, 0.79), 1.05, 0.8, 0.0],    # the sandstorm: everything one brown, nothing far off
	&"grave": [Color(1.0, 0.83, 0.64), 1.15, Color(0.86, 0.82, 0.84), 0.48, Color8(50, 46, 50), Color(0.4, 0.3, 0.3), 0.1, Color(0.96, 0.95, 0.93), Color(0.89, 0.88, 0.87), 1.05, 0.92, 0.0],    # the graves: a dimmer, stiller day than the road's on south. Its old paving stays warm: a cooler sun, sky or shadow read it grey
	&"dark": [Color(0.5, 0.5, 0.8), 0.36, Color(0.5, 0.5, 0.85), 0.3, Color8(14, 14, 26), Color(0.22, 0.22, 0.42), 0.7, Color(0.56, 0.56, 0.72), Color(0.51, 0.51, 0.66), 1.05, 0.7, 0.0],    # the dark stretch: no words, hardly any light
	&"lake": [Color(1.0, 0.84, 0.66), 1.28, Color(0.76, 0.8, 0.94), 0.5, Color8(60, 60, 56), Color(0.22, 0.34, 0.42), 0.4, Color(0.99, 0.98, 0.95), Color(0.92, 0.91, 0.9), 1.05, 1.02, 0.0],    # the lake: the shadows teal off the water
	&"town": [Color(1.0, 0.82, 0.64), 1.28, Color(0.86, 0.76, 0.84), 0.52, Color8(66, 50, 46), Color(0.42, 0.28, 0.38), 0.3, Color(0.99, 0.96, 0.92), Color(0.92, 0.89, 0.86), 1.05, 1.0, 0.0],    # the town: late sun, plum in the shade
}
const FLASH := Color(0.55, 0.72, 1.0)    # Unreal PrologueStorm.h LightningColor

var sun: DirectionalLight3D

static var _tex := {}    # name -> texture, painted once a run (the floor takes a moment)
static var _floor_keys := PackedInt32Array()    # what each floor texel was painted as, kept with it: a slab, or below 0 sand
var mood := &""                    # what set_mood was last asked for
var _env: Environment
var _grade: Grade
var _flash: DirectionalLight3D
var _mood: Tween
var _flashing: Tween
var _cracks: Array[Dictionary] = []    # {node, mat, age}, oldest first

func _ready() -> void:
	_lights()
	_floor()
	_walls()
	_plinth()
	_props()
	set_mood(&"calm", 0.0)
	Steps.surface = _on_stone

# On a slab, for footsteps: no sand flies off stone, and a print barely shows. Cinerea has its own.
func _on_stone(x: float, z: float) -> bool:
	var w := roundi(FLOOR_M * TPM.x)
	var i := floori((x + FLOOR_M / 2.0) * TPM.x)
	var j := floori((z + FLOOR_M / 2.0) * TPM.y)
	return i >= 0 and i < w and j >= 0 and j < roundi(FLOOR_M * TPM.y) and _floor_keys[j * w + i] >= 0

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
func set_mood(to_mood: StringName, seconds: float) -> void:
	if not MOODS.has(to_mood):
		push_warning("Arena: no mood called %s" % to_mood)
		return
	mood = to_mood
	var m: Array = MOODS[to_mood]
	var to := [[sun, "light_color", m[0]], [sun, "light_energy", m[1]], [_env, "ambient_light_color", m[2]],
		[_env, "ambient_light_energy", m[3]], [_env, "background_color", m[4]], [_grade, "sprite_lit", m[5 + Grade.UNIFORMS.size()]]]
	for i in Grade.UNIFORMS.size():
		to.append([_grade.material, "shader_parameter/%s" % Grade.UNIFORMS[i], m[5 + i]])
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
	_grade = Grade.new()
	add_child(_grade)
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
	around.size = Vector2(200.0, 200.0)
	var out := MeshInstance3D.new()
	out.mesh = around
	out.material_override = _mat(_texture(&"outside"), Vector2(50.0, 50.0))
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
	var fallen := _rubble()
	for b: Vector4 in fallen:    # x, z, half size, height: tumbled blocks that fill the breach and the wall's gaps
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
	var body := StaticBody3D.new()    # the round wall, closed all the way round (rubble fills the breach and the gaps)
	_columns(body)
	for b: Vector4 in fallen:    # inside the wall or out: objects stop him where they stand in the picture
		_solid(body, b)
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

# Whole round the gate, in ruins round the sides, low to the south and nothing at the breach. Every piece is a whole number of steps.
func _wall_height(i: int) -> float:
	var deg := rad_to_deg(wrapf(TAU * (i + 0.5) / SEGMENTS, -PI, PI))    # 0 north, 180 south, east positive
	if absf(deg) > 170.0:
		return 0.0
	if absf(deg) <= 30.0:
		return TALL
	var ruin := RUIN_EAST if deg > 0.0 else RUIN_WEST
	var steps := 0.0
	for k in ruin.size() - 1:
		if absf(deg) <= ruin[k + 1].x:
			steps = lerpf(ruin[k].y, ruin[k + 1].y, (absf(deg) - ruin[k].x) / (ruin[k + 1].x - ruin[k].x))
			break
	return Pixel.STEP * clampf(floorf(steps + _hash(i, 1) * 1.2), 0.0, 4.0)

# The breach's blocks, and heaps under every stretch of wall that fell: on both sides of it, as x, z, half size, height.
func _rubble() -> Array[Vector4]:
	var out: Array[Vector4] = RUBBLE.duplicate()
	for i in SEGMENTS:
		var a := TAU * (i + 0.5) / SEGMENTS
		if absf(wrapf(a, -PI, PI)) > deg_to_rad(165.0) or _wall_height(i) > Pixel.STEP:
			continue
		for n in 2:
			var r := RADIUS + WALL / 2.0 + (_hash(i, 20 + n) - 0.5) * 2.4
			var hs := 0.14 + _hash(i, 30 + n) * 0.28
			var y := Pixel.STEP * (0.25 + floorf(_hash(i, 40 + n) * 3.0) * 0.25)
			out.append(Vector4(sin(a) * r, -cos(a) * r, hs, y))
	return out

# The shortest way on foot from `from` through each of `points`, keeping `feet` off the blocks, the stumps and the plinth, for a cutscene walk: its collision is off, but they still stand in the picture. It doesn't know the wall: send him by entrance() or gate(), and a way between two points inside it stays inside it.
func way(from: Vector3, points: Array[Vector3], feet: float) -> Array[Vector3]:
	var blocks := _rubble()
	blocks.append_array(STUMPS)
	blocks.append(Vector4(0.0, 0.0, PLINTH, PLINTH_H))
	var out: Array[Vector3] = []
	for to in points:
		out.append_array(_leg(Vector3(from.x, 0.0, from.z), Vector3(to.x, 0.0, to.z), blocks, feet))
		from = to
	return out

# One leg of way(): round the corners of what's near the straight line, shortest first.
func _leg(a: Vector3, b: Vector3, blocks: Array[Vector4], feet: float) -> Array[Vector3]:
	var path := AStar3D.new()
	path.add_point(0, a)
	path.add_point(1, b)
	var boxes: Array[AABB] = []
	for s in blocks:
		if Vector3(s.x, 0.0, s.y).distance_to(Geometry3D.get_closest_point_to_segment(Vector3(s.x, 0.0, s.y), a, b)) > WAY_REACH:
			continue
		var box := _footprint(s, feet)
		if box.has_point(a) or box.has_point(b):    # already against it (a round capsule fits in the square's corner): he needn't keep off it, only not cross it
			box = _footprint(s, 0.0)
		if not box.has_point(a) and not box.has_point(b):    # standing in it, the only way is out
			boxes.append(box)
		var r := s.z + feet + 0.01
		for c: Vector2 in [Vector2(-r, -r), Vector2(r, -r), Vector2(r, r), Vector2(-r, r)]:
			path.add_point(path.get_point_count(), Vector3(s.x + c.x, 0.0, s.y + c.y))
	for i in path.get_point_count():
		for j in range(i + 1, path.get_point_count()):
			var clear := true
			for box in boxes:
				if box.intersects_segment(path.get_point_position(i), path.get_point_position(j)) != null:
					clear = false
					break
			if clear:
				path.connect_points(i, j)
	var out: Array[Vector3] = []
	for p in path.get_point_path(0, 1).slice(1):
		out.append(p)
	if out.is_empty():    # walled in: a cutscene walk must arrive
		out.append(b)
	return out

func _footprint(s: Vector4, feet: float) -> AABB:
	var r := s.z + feet
	return AABB(Vector3(s.x - r, -1.0, s.y - r), Vector3(2.0 * r, 2.0, 2.0 * r))

func _columns(body: StaticBody3D) -> void:
	var st := SurfaceTool.new()
	var tops := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	tops.begin(Mesh.PRIMITIVE_TRIANGLES)
	for b: Vector4 in STUMPS:
		var hs := b.z
		var y := b.w
		_quad(st, [Vector3(b.x - hs, 0, b.y + hs), Vector3(b.x + hs, 0, b.y + hs), Vector3(b.x + hs, y, b.y + hs), Vector3(b.x - hs, y, b.y + hs)],
			[Vector2(0, 1), Vector2(1, 1), Vector2(1, 1.0 - y / TALL), Vector2(0, 1.0 - y / TALL)], Vector3.BACK)
		var c := [Vector3(b.x - hs, y, b.y - hs), Vector3(b.x + hs, y, b.y - hs), Vector3(b.x + hs, y, b.y + hs), Vector3(b.x - hs, y, b.y + hs)]
		var uvs := []
		for p: Vector3 in c:
			uvs.append(Vector2(p.x, p.z) / 4.0)
		_quad(tops, c, uvs, Vector3.UP)
		_solid(body, b)
	for pair: Array in [[st, &"column"], [tops, &"top"]]:
		var m := MeshInstance3D.new()
		m.mesh = (pair[0] as SurfaceTool).commit()
		m.material_override = _mat(_texture(pair[1]))
		add_child(m)

func _props() -> void:
	for p: Array in PROPS:
		add_child(prop_sprite(p[0], p[1], p[2]))

# A picture from art/props/ standing on the ground at x, z, lit as the ground is. Its bottom row is on the ground.
static func prop_sprite(prop: String, x: float, z: float) -> Sprite3D:
	var s := Sprite3D.new()
	var key := StringName("prop_" + prop)
	if not _tex.has(key):    # a town stands the same picture about many times
		var loaded := Image.load_from_file("res://art/props/%s.png" % prop)
		if loaded == null or loaded.is_empty():
			push_warning("Arena: no art/props/%s.png" % prop)
			return s
		_tex[key] = ImageTexture.create_from_image(loaded)
	return texture_sprite(_tex[key], x, z)

# The same from a picture already made.
static func texture_sprite(tex: ImageTexture, x: float, z: float) -> Sprite3D:
	var s := Sprite3D.new()
	var img := tex.get_image()
	var m := ShaderMaterial.new()
	m.shader = PROP
	m.set_shader_parameter(&"tex", tex)
	s.texture = tex
	s.material_override = m
	s.pixel_size = 1.0 / Pixel.PX
	s.scale.y = Pixel.sprite_scale_y()
	s.position = Pixel.snap(Vector3(x, Hills.height_at(x, z), z)) + Vector3((img.get_width() % 2) * 0.5 / Pixel.PX, img.get_height() / Pixel.PX / 2.0 * s.scale.y, 0.0) + Hills.lean(x, z)
	return s

func _solid(body: StaticBody3D, b: Vector4) -> void:
	var box := BoxShape3D.new()
	var h := maxf(b.w, SOLID_TOP)
	box.size = Vector3(b.z * 2.0, h, b.z * 2.0)
	var c := CollisionShape3D.new()
	c.shape = box
	c.position = Vector3(b.x, h / 2.0, b.y)
	body.add_child(c)

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

func _mat(tex: Texture2D, tiles := Vector2.ONE) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = LIT
	m.set_shader_parameter(&"tex", tex)
	m.set_shader_parameter(&"tiles", tiles)
	return m

# --- textures: posterized noise in a few tones of one colour, so they read as pixel art (the test room's way) ---

func _texture(key: StringName) -> ImageTexture:
	if not _tex.has(key):
		var img: Image
		match key:
			&"floor": img = _paint_floor()
			&"outside": img = _paint(128, 96, SAND, 9, "sand")
			&"arches": img = _weather(_paint_arches(), 21)
			&"brick": img = _weather(_paint(128, 64, BRICK.darkened(0.12), 5, "brick"), 22)
			&"column": img = _paint_column()
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
					c = _quiet(n, x, y, base)
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
# Cracks and missing bricks over a painted wall.
func _weather(img: Image, seed_: int) -> Image:
	var crack := _noise(seed_)
	crack.frequency = 0.035
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if absf(crack.get_noise_2d(x, y)) < 0.012:
				c = c.darkened(0.5)
			elif _hash(floori(x / 8.0) + floori(y / 4.0) * 37, seed_) < 0.05:
				c = c.darkened(0.3)
			img.set_pixel(x, y, c)
	return img

# A fluted column, lit from the left.
func _paint_column() -> Image:
	var n := _noise(23)
	var img := Image.create(21, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 21:
			var c := _tone(n, x, y, BRICK.lightened(0.14 - 0.32 * x / 20.0))
			if x % 5 == 2:
				c = c.darkened(0.3)
			if x == 0 or x == 20:
				c = STONE.darkened(0.6)
			img.set_pixel(x, y, c)
	return img

func _paint_floor() -> Image:
	var w := roundi(FLOOR_M * TPM.x)
	var h := roundi(FLOOR_M * TPM.y)
	var keys := PackedInt32Array()
	keys.resize(w * h)
	var edge_n := roundi(TAU * RADIUS / 1.2)
	var pave := _noise(13)
	pave.frequency = 0.011
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
				if _hash(k, 7) < 0.1:
					k = -1    # a slab gone, the sand showing
			elif r > RADIUS - 0.9 and r < RADIUS + WALL + 0.3:
				k = 10000 + floori(turn * edge_n)
				if _hash(k, 7) < 0.3:
					k = -1
			elif r >= RADIUS + WALL + 0.3:
				k = -2    # outside the wall
			elif pave.get_noise_2d(i, j * TPM.x / TPM.y) > 0.16:    # the old paving, showing through the sand
				k = 20000 + floori((x + 20.0) / 1.2) * 100 + floori((z + 20.0) / 0.9)
				if _hash(k, 7) < 0.28:
					k = -1
			keys[j * w + i] = k
	_floor_keys = keys
	var n := _noise(11)
	var crack := _noise(14)
	crack.frequency = 0.022
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for j in h:
		for i in w:
			var k := keys[j * w + i]
			var c: Color
			if k < 0:
				c = _quiet(n, i, j, SAND)
			elif k != keys[j * w + mini(i + 1, w - 1)] or k != keys[mini(j + 1, h - 1) * w + i]:
				c = SLAB.darkened(0.3)    # grout, right and below each slab: any fainter and the old paving reads as a stain, not as slabs
			else:
				c = _quiet(n, i, j, SLAB.darkened(0.05 * _hash(k, 3)))
				if k != keys[j * w + maxi(i - 1, 0)] or k != keys[maxi(j - 1, 0) * w + i]:
					c = c.lightened(0.1)    # the lit edge, left and above
				if absf(crack.get_noise_2d(i, j * TPM.x / TPM.y)) < 0.012:
					c = SLAB.darkened(0.3)    # broken across
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
			var is_gate := k == 0.0
			var hw := 28.0 if is_gate else 17.0
			var spring := 32.0 if is_gate else 38.0    # where the round top begins
			var d := dx if y >= spring else Vector2(dx, spring - y - 0.5).length()
			if absf(dx - period / 2.0) < 3.0:
				c = BRICK.lightened(0.1) if dx < period / 2.0 + 1.0 else BRICK.darkened(0.3)    # a pilaster between arches
			if y < 4:
				c = BRICK.lightened(0.22 if y == 0 else 0.12)    # the cornice
			elif y == 4:
				c = BRICK.darkened(0.45)
			if d < hw:
				c = DARK if y < h - 5 else DARK.lightened(0.15)    # the arcade's floor shows at the bottom
				if is_gate and (int(dx) % 6 == 0 or y % 8 == 0):
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
	var crack := _noise(16)
	crack.frequency = 0.03
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var c := _tone(n, x, y, STONE.lightened(0.06))
			if absf(crack.get_noise_2d(x, y)) < 0.016 or x + (h - 1 - y) * 1.3 < 11.0 or (w - 1 - x) + y * 1.3 < 8.0:
				c = STONE.darkened(0.4)    # cracked, and two corners broken off
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

func _tone(n: FastNoiseLite, x: int, y: int, base: Color, light := 0.10, dark := 0.16) -> Color:
	var v := n.get_noise_2d(x, y)
	if v > 0.22:
		return base.lightened(light)
	if v < -0.28:
		return base.darkened(dark)
	return base

# The ground's tone: barely a shade either way, so it isn't a dead fill and characters and props stand clear of it (Danyal). Claude's call.
func _quiet(n: FastNoiseLite, x: int, y: int, base: Color) -> Color:
	return _tone(n, x, y, base, 0.012, 0.02)

func _noise(seed_: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_
	n.frequency = 0.18
	return n

func _hash(a: float, b: float) -> float:
	return fposmod(sin(a * 12.9898 + b * 78.233) * 43758.5453, 1.0)
