extends FxEffect
# Embers drifting up from fire.

func _build() -> void:
	life = 1.4
	var p := _particles(12, 1.1, [FIRE[1], FIRE[2], FIRE[3]], 2)
	p.explosiveness = 0.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.3
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.4
	p.gravity = Vector3(0.0, 0.8, 0.0)
