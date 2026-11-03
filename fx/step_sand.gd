extends FxEffect
# A little sand kicked up by a footstep, thrown back from the way he's going. `amount` grains: few at a walk, more at a run (Danyal).

var amount := 3

func _build() -> void:
	life = 0.55
	var grains: Array[Color] = [Color8(232, 200, 128), Color8(206, 170, 104), Color8(178, 142, 84)]
	var p := _particles(amount, 0.45, grains, 1)
	p.position.y = 0.06
	p.direction = (basis.inverse() * (dir + Vector3.UP * 0.8)).normalized()
	p.spread = 38.0
	p.initial_velocity_min = 0.5 + amount * 0.08
	p.initial_velocity_max = 1.1 + amount * 0.14
	p.damping_min = 2.0
	p.damping_max = 3.5
	p.gravity = Vector3(0.0, -5.0, 0.0)
	p.scale_amount_max = 1.0
