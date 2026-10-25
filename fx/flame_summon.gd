extends FxEffect
# The flame that bursts from his raised hand and forms the greatsword: a white-hot star, then fire licking upward.

var _star: Sprite3D

func _build() -> void:
	life = 1.0
	_star = _sprite(star_image(16, FIRE))
	var flames := _particles(36, 0.6, FIRE, 2)
	flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	flames.emission_sphere_radius = 0.2
	flames.direction = Vector3.UP
	flames.spread = 40.0
	flames.initial_velocity_min = 1.0
	flames.initial_velocity_max = 2.6
	flames.gravity = Vector3(0.0, 3.0, 0.0)
	_light(FIRE[1], 4.0, 5.0).position.y = 0.0

func _step(_delta: float) -> void:
	_star.visible = age < 0.25
	_dim(clampf(1.0 - age / life, 0.0, 1.0))
