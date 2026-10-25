extends FxEffect
# The crown's red light fleeing: a red-white core streaking along dir and rising for 2 s, trailing red sparks.

const SPEED := 9.0    # m/s, Claude's call: out over the wall and off the screen in 2 s
const RISE := 1.5     # m/s upward as it goes

var _core: Sprite3D
var _trail: CPUParticles3D

func _build() -> void:
	life = 2.0
	_core = _sprite(ball_image(8, CROWN, 1), true)
	_trail = _particles(40, 0.5, CROWN, 2, false)
	_trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_trail.emission_sphere_radius = 0.1
	_trail.initial_velocity_max = 0.4
	_light(CROWN[1], 2.5, 4.0).position.y = 0.0

func _step(delta: float) -> void:
	position += (dir * SPEED + Vector3.UP * RISE) * delta
	_core.global_position = snap3(global_position)
	_trail.emitting = life - age > 0.5
	_core.visible = life - age > 0.15
	_dim(clampf((life - age) / 0.5, 0.0, 1.0))
