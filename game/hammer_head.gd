class_name HammerHead extends FxEffect
# The broken hammer head from the legionary's tomb, in its own light: it comes up out of the pit and into his hands. hot: 0 dark, 1 glowing, 2 blazing.
# An FxEffect for its sprite and light helpers, but a child of the scene, not of Fx, as Crown is.

const SIZE := 44       # the picture: the head with a star of light behind it
const STARS: Array[int] = [0, 16, 26, 36, 44]    # the star's size as it heats
const HEAD: Array[String] = [".########.", "#ooooooo##", "#oiiiiioo#", "#oi..iioo#", "#oiiiiioo#", ".########."]    # the block, its socket and hot edge

var hot := 0.0

var _frames: Array[ImageTexture] = []
var _pic: Sprite3D
var _embers: CPUParticles3D

func _build() -> void:
	life = INF
	for px: int in STARS:
		_frames.append(ImageTexture.create_from_image(_image(px)))
	_pic = _sprite(_frames[0].get_image(), true)
	_light(FIRE[2], 2.2, 5.0).position.y = 0.3
	_embers = _particles(18, 1.1, [FIRE[1], FIRE[2], FIRE[3]], 1, false)
	_embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_embers.emission_sphere_radius = 0.25
	_embers.direction = Vector3.UP
	_embers.spread = 30.0
	_embers.initial_velocity_min = 0.4
	_embers.initial_velocity_max = 1.2
	_embers.gravity = Vector3(0.0, 0.6, 0.0)
	_embers.emitting = false
	_dim(0.0)

# Up out of the pit and over to `to`, in `seconds`.
func rise(to: Vector3, seconds: float) -> void:
	var from := global_position
	var tw := create_tween()
	tw.tween_method(func(x: float) -> void: global_position = from.lerp(to, x) + Vector3.UP * sin(x * PI) * 0.7, 0.0, 1.0, seconds).set_trans(Tween.TRANS_SINE)
	await tw.finished

func _step(_delta: float) -> void:
	_embers.emitting = hot > 0.2
	var flicker := int(fmod(age * 9.0, 2.0)) if hot > 0.2 else 0
	_pic.texture = _frames[clampi(int(hot * 1.5) + flicker, 0, _frames.size() - 1)]
	_dim(hot)
	_pic.global_position = snap3(global_position)

static func _image(star: int) -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	if star > 0:
		img.blit_rect(star_image(star, [FIRE[0], FIRE[1], FIRE[2]]), Rect2i(0, 0, star, star), Vector2i.ONE * int((SIZE - star) / 2.0))
		var core := int(star * 0.25) * 2    # even, as ball_image wants: the blaze behind the block
		img.blend_rect(ball_image(core, [FIRE[0], FIRE[1], FIRE[2]], star), Rect2i(0, 0, core, core), Vector2i.ONE * int((SIZE - core) / 2.0))
	var at := Vector2i(int((SIZE - HEAD[0].length()) / 2.0), int((SIZE - HEAD.size()) / 2.0))
	for y in HEAD.size():
		for x in HEAD[y].length():
			var ch := HEAD[y][x]
			if ch != ".":
				img.set_pixelv(at + Vector2i(x, y), {"#": Color8(20, 14, 16), "o": FIRE[2], "i": Color8(58, 52, 58)}[ch])
	return img
