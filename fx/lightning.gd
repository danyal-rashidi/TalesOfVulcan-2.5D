extends FxEffect
# A bolt from the sky striking `at`: two strokes in 0.26 s, each with a flash where it strikes and lighting the ground blue-white.
# Arena.lightning_flash() lights the sky.

const HEIGHT_PX := 240    # the bolt on screen; it starts above the top of the view
const WIDTH_PX := 40

var _bolt: Sprite3D
var _strike: Sprite3D

func _build() -> void:
	life = 0.45
	_bolt = _sprite(_bolt_image())
	_bolt.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y    # it stands upright, like the characters
	_bolt.scale.y = Pixel.sprite_scale_y()
	_bolt.global_position = Pixel.snap(global_position) + Vector3(0.0, HEIGHT_PX / Pixel.PX / 2.0 * _bolt.scale.y, 0.0)
	_strike = _sprite(star_image(28, BOLT), true)
	_light(BOLT[1], 6.0, 8.0).position.y = 1.5
	var sparks := _particles(16, 0.3, BOLT, 2)
	sparks.direction = Vector3.UP
	sparks.spread = 80.0
	sparks.initial_velocity_min = 2.0
	sparks.initial_velocity_max = 4.5
	sparks.gravity = Vector3(0.0, -12.0, 0.0)

func _step(_delta: float) -> void:
	var on := age < 0.07 or (age > 0.14 and age < 0.26)
	_bolt.visible = on
	_strike.visible = on
	_dim(1.0 if on else 0.15)

# A jagged line down the middle, three texels of white with two of blue each side, and a thinner fork part-way down.
func _bolt_image() -> Image:
	var img := Image.create(WIDTH_PX, HEIGHT_PX, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var x := floori(WIDTH_PX / 2.0)
	var fork_at := rng.randi_range(70, 130)
	var fx := 0
	var fork_dir := 1 if rng.randf() < 0.5 else -1
	for y in HEIGHT_PX:
		if y % 3 == 0:
			x = clampi(x + rng.randi_range(-2, 2), 6, WIDTH_PX - 9)
		_stroke(img, x, y, 3)
		if y == fork_at:
			fx = x
		if y > fork_at and y < fork_at + 50:
			if y % 2 == 0:
				fx = clampi(fx + fork_dir + rng.randi_range(-1, 1), 2, WIDTH_PX - 4)
			_stroke(img, fx, y, 1)
	return img

func _stroke(img: Image, x: int, y: int, core: int) -> void:
	for i in range(-2, core + 2):
		img.set_pixel(x + i, y, BOLT[0] if i >= 0 and i < core else BOLT[1])
