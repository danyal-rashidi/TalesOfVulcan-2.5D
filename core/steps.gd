class_name Steps extends Node
# Every character's footsteps: a child of anything with a `sprite` that walks. Each step leaves a print on the ground that thins out and goes, its shape from who made it (Danyal: "ofcourse some have different footsteps"), and on sand kicks up a little of it, more the faster he goes.

const LIFE := 7.0          # s a print stays
const MAX_PRINTS := 140    # the oldest go past this
const WIDE := 0.14         # m either side of his line that a foot lands
const NARROW := {"paw": 0.05, "legs": 0.0}    # its stamp already spans its feet, or its legs are close under it. Claude's call
const RUN_FROM := 4.6      # m/s: faster than this the most sand flies
const RUN_STRIDE := 1.4    # a sprint sheet's step against his run sheet's: 6 m/s for 0.56 s, 3 m/s for 0.8 s
const FIRST := 0.6         # a walk from standing starts this far into a stride: its sheet starts over too, and the first foot is under him 0.3 to 0.6 of a stride in
const GROUND := 0.03       # m up that a print lies. A body higher than this over the ground under it is off the ground: the boss's dive and his hop raise the body itself, Elvis's leap only his sprite
const SAND := preload("res://fx/step_sand.gd")
const SHADER := preload("res://core/footprint.gdshader")
# Who leaves what, and metres between steps: half of what a loop of their sheet covers at the speed it's drawn for (a four-footed run: a quarter).
const WHO := {
	"vulcan_human": ["sandal", 1.2], "vulcan_new_sword": ["sandal", 1.2], "elvis_blue": ["boot", 1.375], "vulcan_boss": ["big_boot", 1.6], "jackal": ["paw", 0.7], "scorpion": ["legs", 0.54],
	"raider_sword": ["boot", 1.2], "varro": ["boot", 1.2], "cassia": ["shoe", 0.75], "livia": ["shoe", 0.75], "livia_boy": ["small", 0.6], "tullus": ["shoe", 0.75], "fortuna": ["hoof", 0.9], "carriage_pull": ["hoof", 0.63],
}
# A print's shape on the ground, in metres, as ellipses: [ahead, outwards from his line, half long, half wide]. Half long 0 is a single texel: a toe, a leg's point. Claude's call, all of them.
const SHAPES := {
	"sandal": [[0.07, -0.006, 0.09, 0.075], [-0.09, 0.0, 0.07, 0.055]],
	"boot": [[0.075, 0.0, 0.105, 0.075], [-0.13, 0.0, 0.05, 0.065]],
	"big_boot": [[0.24, 0.0, 0.05, 0.13], [0.12, 0.0, 0.035, 0.13], [0.02, 0.0, 0.035, 0.12], [-0.19, 0.0, 0.09, 0.105]],
	"paw": [[-0.04, 0.0, 0.06, 0.07], [0.06, 0.075, 0.0, 0.0], [0.105, 0.028, 0.0, 0.0], [0.105, -0.028, 0.0, 0.0], [0.06, -0.075, 0.0, 0.0]],
	"legs": [[0.22, 0.13, 0.05, 0.03], [0.04, 0.15, 0.05, 0.03], [-0.14, 0.13, 0.05, 0.03], [0.13, -0.13, 0.05, 0.03], [-0.05, -0.15, 0.05, 0.03], [-0.23, -0.13, 0.05, 0.03]],
	"shoe": [[0.045, 0.0, 0.075, 0.06], [-0.075, 0.0, 0.05, 0.05]],
	"small": [[0.03, 0.0, 0.06, 0.052], [-0.05, 0.0, 0.045, 0.044]],
	"hoof": [[0.02, 0.07, 0.11, 0.06], [0.02, -0.07, 0.11, 0.06], [-0.07, 0.0, 0.06, 0.12]],
}
const DIRS := 16           # the ways a print can point: all its pixels are painted, not turned, so each stays one screen pixel
const SPLAY := 0.14        # rad a foot turns out. Claude's call
const LIT := Vector2i(1, -1)    # the sun is low behind the camera's left (Arena's sun): shadows fall up and right, so that's the wall it lights
# The stamp's parts, as straight colours for a flat picture (game/opening.gd). On the ground footprint.gdshader only reads the alpha. Claude's call.
const LIP_COLOUR := Color(1.0, 0.92, 0.72, 0.2)
const HOLLOW_COLOUR := Color(0.32, 0.17, 0.05, 0.32)
const DEEP_COLOUR := Color(0.25, 0.12, 0.03, 0.5)

static var surface := Callable()    # (x, z) -> true on stone, set by a scene that has any; no sand flies off that
static var _textures := {}
static var _live: Array = []    # the prints still out there, oldest first

var _body: Node3D
var _sprite: CharacterSprite
var _last := Vector3.ZERO
var _moved := 0.0
var _foot := 1.0

func _ready() -> void:
	_body = get_parent() as Node3D
	_sprite = _body.get("sprite") as CharacterSprite
	_last = _body.global_position
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF

func _physics_process(delta: float) -> void:
	var at := _body.global_position
	var step := at - _last
	step.y = 0.0
	_last = at
	var d := step.length()
	if d > 1.0 or _sprite == null or not _sprite.visible or _sprite.position.y > 0.0 or at.y - Hills.height_at(at.x, at.z) > GROUND or delta <= 0.0:    # put somewhere by a scene, or in the air
		return
	var who: Array = WHO.get(_sprite.character, ["shoe", 0.75])
	var stride := float(who[1]) * (RUN_STRIDE if _sprite.current_key.begins_with("sprint") else 1.0)
	if d < 0.0005:    # standing: his sheet starts over when he walks, so the steps do too
		_moved = stride * FIRST
		return
	_moved += d
	if _moved >= stride:
		_moved -= stride    # what's left carries over, so steps stay even at any speed
		_foot = -_foot
		_step(at - step / d * _moved, step / d, d / delta, who[0])    # where the step fell between two physics ticks

func _step(at: Vector3, way: Vector3, speed: float, shape: String) -> void:
	var side := Vector3(-way.z, 0.0, way.x) * float(NARROW.get(shape, WIDE)) * _foot
	var spot := at + side
	var stone: bool = surface.is_valid() and surface.call(spot.x, spot.z)
	_print(spot, way, shape, stone)
	if not stone:
		var puff: FxEffect = SAND.new()
		puff.amount = 5 if speed < 3.6 else (9 if speed <= RUN_FROM + 1.0 else 18)
		puff.position = Vector3(spot.x, Hills.height_at(spot.x, spot.z), spot.z)
		puff.dir = -way
		_body.get_parent().add_child(puff)

func _print(spot: Vector3, way: Vector3, shape: String, stone: bool) -> void:
	var s := FootPrint.new()
	s.axis = Vector3.AXIS_Y
	s.pixel_size = 1.0 / Pixel.PX
	s.scale.z = 4.0 / 3.0    # the ground is 24 px a metre that way: each texel is one screen pixel
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tex := stamp(shape, Vector2(way.x, way.z), _foot)
	s.texture = tex
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter(&"tex", tex)
	m.set_shader_parameter(&"lip", not stone)
	m.set_shader_parameter(&"fade", 0.5 if stone else 1.0)
	s.material_override = m
	s.start = 0.5 if stone else 1.0
	_body.get_parent().add_child(s)
	Hills.lay(s, spot.x, spot.z, GROUND)
	s.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	while not _live.is_empty() and not is_instance_valid(_live[0]):
		_live.pop_front()
	_live.append(s)
	if _live.size() > MAX_PRINTS:
		var oldest: Variant = _live.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()

# One print: the shape going `way` over the ground (x, z), for that foot (+1 lands on his way's +90 side, -1 its mirror), `size` times life size. Painted once, then kept.
static func stamp(shape: String, way: Vector2, foot: float, size := 1.0) -> ImageTexture:
	var dir := posmod(roundi(way.angle() / TAU * DIRS), DIRS)
	var key := [shape, dir, foot, size]
	if not _textures.has(key):
		_textures[key] = ImageTexture.create_from_image(_paint(SHAPES[shape], dir * TAU / DIRS, foot, size))
	return _textures[key]

# Sampled at the ground's own 32 x 24 texels a metre from a shape in metres, so a diagonal print is really diagonal and foreshortened as the ground is.
static func _paint(parts: Array, angle: float, foot: float, size: float) -> Image:
	var ahead := Vector2.from_angle(angle + foot * SPLAY)
	var out := Vector2(-ahead.y, ahead.x) * foot
	var reach := 0.0
	for p: Array in parts:
		reach = maxf(reach, Vector2(p[0], p[1]).length() + maxf(p[2], p[3]))
	var half := Vector2i(ceili(reach * size * Arena.TPM.x), ceili(reach * size * Arena.TPM.y)) + Vector2i.ONE    # twice that is always even, so it sits on the grid; one spare for the lip
	var w := half.x * 2
	var h := half.y * 2
	var dent := PackedByteArray()
	dent.resize(w * h)
	for y in h:
		for x in w:
			var hits := 0
			for i in 9:    # three by three inside the texel
				var at := Vector2((x - half.x + (i % 3 + 0.5) / 3.0) / Arena.TPM.x, (y - half.y + (i / 3 + 0.5) / 3.0) / Arena.TPM.y) / size
				var local := Vector2(at.dot(ahead), at.dot(out))
				for p: Array in parts:
					if p[2] > 0.0 and ((local.x - p[0]) / p[2]) ** 2 + ((local.y - p[1]) / p[3]) ** 2 <= 1.0:
						hits += 1
						break
			dent[y * w + x] = 1 if hits >= 5 else 0
	for p: Array in parts:
		if p[2] == 0.0:
			var at: Vector2 = (ahead * p[0] + out * p[1]) * size
			dent[(floori(at.y * Arena.TPM.y) + half.y) * w + floori(at.x * Arena.TPM.x) + half.x] = 1
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			var here := dent[y * w + x] == 1
			var near := dent[y * w + x - LIT.x] == 1 and dent[(y - LIT.y) * w + x] == 1    # both texels toward the sun are hollow too
			if here:
				img.set_pixel(x, y, HOLLOW_COLOUR if near else DEEP_COLOUR)
			elif dent[y * w + x - LIT.x] == 1 or dent[(y - LIT.y) * w + x] == 1:
				img.set_pixel(x, y, LIP_COLOUR)
	return img


class FootPrint extends Sprite3D:
	var start := 1.0
	var _age := 0.0

	func _process(delta: float) -> void:
		_age += delta
		var left := 1.0 - _age / LIFE
		if left <= 0.0:
			queue_free()
		elif _age > LIFE * 0.4:    # plain for a while, then going
			(material_override as ShaderMaterial).set_shader_parameter(&"fade", start * left / 0.6)
