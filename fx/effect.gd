class_name FxEffect extends Node3D
# One effect from Fx.spawn(). A kind extends this: it builds itself in _build(), acts in _step() every physics frame, and frees itself
# after `life` game seconds (so a hit-stop holds it too). Its -Z points along `dir`; rotating the node turns its drawing and hitbox together.
# Pixel art: unshaded, nearest-filtered, colours in a few hard steps from the test room's palette.

const FIRE: Array[Color] = [Color8(255, 246, 214), Color8(255, 214, 92), Color8(232, 104, 30), Color8(120, 30, 18)]    # the test room's lava, white-hot to dark red
const CROWN: Array[Color] = [Color8(255, 206, 196), Color8(255, 72, 54), Color8(196, 24, 30), Color8(96, 10, 20)]       # the Ember Crown's red
const STONE: Array[Color] = [Color8(186, 176, 170), Color8(132, 122, 118), Color8(84, 74, 76)]                        # the room's stone, lit and in shade
const ASH: Array[Color] = [Color8(232, 104, 30), Color8(96, 88, 84), Color8(58, 52, 50), Color8(43, 38, 36)]           # burning, then grey (the sprite shader's ash rim)
const SAND: Array[Color] = [Color8(226, 212, 186), Color8(202, 184, 156), Color8(176, 158, 132)]    # dust: paler than the sand it rises from
const BOLT: Array[Color] = [Color8(244, 248, 255), Color8(140, 184, 255)]    # Unreal PrologueStorm.h LightningColor (0.55, 0.72, 1)
const ICY: Array[Color] = [Color8(215, 252, 252), Color8(64, 214, 255), Color8(42, 170, 255), Color8(24, 92, 226)]    # Elvis's ice: white on the edge, then the shining blues (art/tools/ice_spear.py)
const GROUND := preload("res://fx/ground_fire.gdshader")

var dir := Vector3.BACK    # toward the camera, as an Actor faces by default
var team := Hitbox.TEAM_BOSS
var info: HitInfo
var hitbox: Hitbox
var life := 1.0
var age := 0.0

static var _dot: StandardMaterial3D    # every particle: a flat square of one colour, facing the camera
static var _pixelfx_sheets := {}       # path -> its texture
var _grounds: Array[ShaderMaterial] = []
var _lights: Array[OmniLight3D] = []
var _energy: Array[float] = []

func _ready() -> void:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() > 0.001:
		basis = Basis.looking_at(flat)
	_build()
	for c in get_children():
		if c is CPUParticles3D:
			(c as CPUParticles3D).restart()    # only now: spawned in a physics frame, a burst started before its set-up fires every particle the same

func _build() -> void:
	pass

func _step(_delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	age += delta
	for m in _grounds:
		_place_ground(m)
	_step(delta)
	if age >= life and not is_queued_for_deletion():
		end()

# Gone at once: its hitbox stops, it stops acting, and it's freed at the end of the frame.
func end() -> void:
	if hitbox:
		hitbox.deactivate()
	process_mode = PROCESS_MODE_DISABLED
	queue_free()

# Whole screen pixels in every axis, for what flies above the floor: x in 1/32 m, z in 1/24 m, height in 1/21.1 m.
static func snap3(p: Vector3) -> Vector3:
	var q := Pixel.snap(Vector3(p.x, 0.0, p.z))
	q.y = snappedf(p.y, 1.0 / (Pixel.PX * cos(deg_to_rad(Pixel.PITCH_DEG))))
	return q

# The blow, made from the Unreal attack's numbers unless the spawner passed its own `info`; active for `seconds` (0: _step activates it).
func _hit(shape: Shape3D, at: Vector3, damage: float, push: float, heavy: bool, seconds: float) -> void:
	if info == null:
		info = HitInfo.new()
		info.damage = damage
		info.poise = damage * (2.0 if heavy else 1.0)    # Unreal BossVulcan.h HeavyPoiseScale, as Elvis's blows
		info.knockback = push * push / (2.0 * Actor.KNOCK_DECEL)    # how far Unreal's push (m/s) slides at Unreal's braking
		info.heavy = heavy
		info.source = self
		info.at = global_position
	hitbox = Hitbox.new()
	hitbox.team = team
	var c := CollisionShape3D.new()
	c.shape = shape
	c.position = at
	hitbox.add_child(c)
	add_child(hitbox)
	if seconds > 0.0:
		hitbox.activate(info, seconds)

# Fire drawn on the floor by ground_fire.gdshader, on a plane `extent` m across (x, z) centred at `centre`.
func _ground(shape: int, size: float, width: float, colors: Array[Color], extent: Vector2, centre: Vector3) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = GROUND
	mat.set_shader_parameter(&"shape", shape)
	mat.set_shader_parameter(&"size", size)
	mat.set_shader_parameter(&"width", width)
	for i in 4:
		mat.set_shader_parameter(StringName("c%d" % i), colors[mini(i, colors.size() - 1)])
	var plane := PlaneMesh.new()
	plane.size = extent
	var m := MeshInstance3D.new()
	m.mesh = plane
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = centre + Vector3(0.0, 0.03, 0.0)    # over the floor and its cracks
	add_child(m)
	if Hills.on:
		Hills.drape(m, extent, 0.03)
	_grounds.append(mat)
	_place_ground(mat)
	return mat

func _place_ground(m: ShaderMaterial) -> void:
	var f := -global_basis.z
	m.set_shader_parameter(&"origin", Vector2(global_position.x, global_position.z))
	m.set_shader_parameter(&"axis", Vector2(f.x, f.z).normalized())

# Square particles `px` screen pixels across (times scale_amount), stepping through `colors` over their life. A burst unless `burst` is false.
func _particles(amount: int, lifetime: float, colors: Array[Color], px: int, burst := true) -> CPUParticles3D:
	if _dot == null:
		_dot = StandardMaterial3D.new()
		_dot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_dot.vertex_color_use_as_albedo = true
		_dot.vertex_color_is_srgb = true
		_dot.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_dot.billboard_keep_scale = true    # so scale_amount_min/max give each particle its own size
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * px / Pixel.PX
	quad.material = _dot
	var ramp := Gradient.new()
	ramp.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var at := PackedFloat32Array()
	for i in colors.size():
		at.append(float(i) / colors.size())
	ramp.offsets = at
	ramp.colors = PackedColorArray(colors)
	var p := CPUParticles3D.new()
	p.mesh = quad
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = burst
	p.explosiveness = 1.0 if burst else 0.0
	p.local_coords = false
	p.color_ramp = ramp
	p.gravity = Vector3.ZERO
	p.emitting = false    # _ready starts it once _build has set it up
	add_child(p)
	return p

# A glow on the arena's faces, which arena/lit.gdshader draws in hard rings (sprites and effects are unshaded).
func _light(c: Color, energy: float, reach: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = energy
	l.omni_range = reach
	l.position.y = 0.6
	add_child(l)
	_lights.append(l)
	_energy.append(energy)
	return l

# Every light at `f` of its own energy.
func _dim(f: float) -> void:
	for i in _lights.size():
		_lights[i].light_energy = _energy[i] * f

# A sprite facing the camera, one texel per screen pixel, placed on the pixel grid. `over` draws it over everything.
func _sprite(img: Image, over := false) -> Sprite3D:
	return _sprite_of(ImageTexture.create_from_image(img), over)

# The same from a texture the kind keeps, for one spawned often.
func _sprite_of(tex: Texture2D, over := false) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = tex
	s.pixel_size = 1.0 / Pixel.PX
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.no_depth_test = over
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.top_level = true
	add_child(s)
	s.global_position = snap3(global_position)
	return s

# One of art/tools/pixelfx_sheets.py's effects: `frames` cells in a row, its origin at the middle of each. Straight from the PNG as CharacterSprite's are, and kept, so only the first of a kind costs anything. Over the floor and whoever's on it, under a damage number.
func _pixelfx(path: String, frames: int) -> Sprite3D:
	if not _pixelfx_sheets.has(path):
		_pixelfx_sheets[path] = ImageTexture.create_from_image(Image.load_from_file(path))
	var tex: Texture2D = _pixelfx_sheets[path]
	var s := _sprite_of(tex, true)
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	s.render_priority = -2    # as fx/hammer_aura.gd: the first 55 is the proof of the upgrade
	s.hframes = frames
	return s

# A ball of fire `px` across (even), in `colors` from the core out; `seed_` ruffles its edge, so two seeds flicker.
static func ball_image(px: int, colors: Array[Color], seed_: int) -> Image:
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var r := px / 2.0
	for y in px:
		for x in px:
			var d := Vector2(x + 0.5 - r, y + 0.5 - r).length() / r + rng.randf_range(-0.12, 0.12)
			if d < 1.0:
				img.set_pixel(x, y, colors[mini(int(d * colors.size()), colors.size() - 1)])
	return img

# A four-point star `px` across (even): the arms in `colors[1..]`, the heart in colors[0].
static func star_image(px: int, colors: Array[Color]) -> Image:
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	var r := px / 2.0
	for y in px:
		for x in px:
			var dx := absf(x + 0.5 - r) / r
			var dy := absf(y + 0.5 - r) / r
			var arm := minf(dx, dy) * 6.0 + maxf(dx, dy)    # thin along the axes, round in the middle
			if arm < 1.0:
				img.set_pixel(x, y, colors[mini(int(arm * colors.size()), colors.size() - 1)])
	return img
