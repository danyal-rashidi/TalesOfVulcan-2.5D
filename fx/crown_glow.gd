extends FxEffect
# The Ember Crown flaring on the statue's head: a red star over it that beats like a heart, red embers rising, red light round it.

const BEAT := 1.2    # beats a second

var _big: ImageTexture
var _small: ImageTexture
var _star: Sprite3D

func _build() -> void:
	life = 4.0
	_big = ImageTexture.create_from_image(star_image(24, CROWN))
	_small = ImageTexture.create_from_image(star_image(14, CROWN))
	_star = _sprite(_big.get_image(), true)
	var embers := _particles(16, 1.0, CROWN, 2, false)
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	embers.emission_sphere_radius = 0.25
	embers.direction = Vector3.UP
	embers.spread = 30.0
	embers.initial_velocity_min = 0.4
	embers.initial_velocity_max = 1.0
	_light(CROWN[1], 2.5, 4.5).position.y = 0.0

func _step(_delta: float) -> void:
	var beat := pow(1.0 - fmod(age * BEAT, 1.0), 3.0)    # a sharp rise, then it dies away
	var fade := clampf((life - age) / 0.5, 0.0, 1.0)
	_star.texture = _big if beat > 0.4 else _small
	_star.visible = fade > 0.0
	_dim((0.35 + 0.65 * beat) * fade)
