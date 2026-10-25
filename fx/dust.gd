extends FxEffect
# Dust kicked up off the sand: low puffs rolling out and settling.

func _build() -> void:
	life = 0.9
	var p := _particles(16, 0.7, SAND, 3)
	p.position.y = 0.1
	p.direction = Vector3.RIGHT
	p.spread = 180.0
	p.flatness = 1.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.8
	p.damping_min = 1.5
	p.damping_max = 2.5
	p.gravity = Vector3(0.0, 0.4, 0.0)
	p.scale_amount_max = 2.0
