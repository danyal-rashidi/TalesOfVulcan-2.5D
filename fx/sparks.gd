extends FxEffect
# A quick spray of sparks: a light blow on the kneeling Vulcan, a fireball bursting.

func _build() -> void:
	life = 0.5
	var p := _particles(16, 0.35, FIRE, 2)
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 5.5
	p.gravity = Vector3(0.0, -14.0, 0.0)
