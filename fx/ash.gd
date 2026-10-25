extends FxEffect
# The armour burning to ash: flakes lift off his body for SECONDS, glowing first and then grey, drifting up and away.

const SECONDS := 3.0    # the burn in the unmasking's shot 3 (the plan)

var _flakes: CPUParticles3D

func _build() -> void:
	life = SECONDS + 1.6
	_flakes = _particles(60, 1.6, ASH, 2, false)
	_flakes.position.y = 0.95
	_flakes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_flakes.emission_box_extents = Vector3(0.35, 0.8, 0.15)
	_flakes.direction = Vector3.UP
	_flakes.spread = 35.0
	_flakes.initial_velocity_min = 0.3
	_flakes.initial_velocity_max = 0.9
	_flakes.gravity = Vector3(0.4, 0.5, 0.0)
	_flakes.scale_amount_max = 2.0

func _step(_delta: float) -> void:
	_flakes.emitting = age < SECONDS
