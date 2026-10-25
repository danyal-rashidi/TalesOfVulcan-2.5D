extends FxEffect
# Lightning bursts the stone statue: chunks flung up and out and falling, dust rolling low, a white flash.

func _build() -> void:
	life = 1.6
	var chunks := _particles(40, 1.2, STONE, 3)
	chunks.position.y = 0.9
	chunks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	chunks.emission_box_extents = Vector3(0.4, 0.8, 0.3)
	chunks.direction = Vector3.UP
	chunks.spread = 75.0
	chunks.initial_velocity_min = 2.5
	chunks.initial_velocity_max = 5.5
	chunks.gravity = Vector3(0.0, -12.0, 0.0)
	chunks.scale_amount_max = 2.0
	var dust := _particles(24, 0.9, SAND, 3)
	dust.position.y = 0.15
	dust.direction = Vector3.RIGHT
	dust.spread = 180.0
	dust.flatness = 1.0
	dust.initial_velocity_min = 1.5
	dust.initial_velocity_max = 3.0
	dust.damping_min = 2.5
	dust.damping_max = 3.5
	dust.scale_amount_max = 2.0
	_light(Color(0.9, 0.95, 1.0), 5.0, 6.0).position.y = 1.2

func _step(_delta: float) -> void:
	_dim(clampf(1.0 - age / 0.4, 0.0, 1.0))
