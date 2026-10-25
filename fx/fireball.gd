extends FxEffect
# A fireball from the spell: SPEED m/s along dir, bursting into sparks on the first hurtbox it hits, on a wall or after 3 s.
# A roll goes through it: an invulnerable hurtbox isn't hit (Hitbox).

const SPEED := 7.0     # the plan (Unreal BossVulcan.h SpellSpeed 760 cm/s)
const RADIUS := 0.3    # Unreal BossVulcan.h SpellBallRadius 30 cm

var _ball: Sprite3D
var _frames: Array[ImageTexture] = []

func _build() -> void:
	life = 3.0
	var ball := SphereShape3D.new()
	ball.radius = RADIUS
	_hit(ball, Vector3.ZERO, 10.0, 3.0, false, life)    # Spell.Damage 10 a fireball, Push 300 cm/s (BossVulcan.cpp)
	hitbox.collision_mask |= 1    # the walls and the plinth (layer 1) burst it too
	hitbox.landed.connect(_burst.unbind(2))
	for s in 2:
		_frames.append(ImageTexture.create_from_image(ball_image(16, FIRE, s)))
	_ball = _sprite(_frames[0].get_image())
	var trail := _particles(24, 0.35, [FIRE[1], FIRE[2], FIRE[3]], 2, false)
	trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	trail.emission_sphere_radius = 0.12
	trail.initial_velocity_max = 0.3
	_light(FIRE[2], 1.5, 3.0).position.y = 0.0

func _step(delta: float) -> void:
	position += dir * SPEED * delta
	_ball.global_position = snap3(global_position)
	_ball.texture = _frames[int(age * 12.0) % 2]
	for b in hitbox.get_overlapping_bodies():
		if b is StaticBody3D:
			_burst()
			return

func _burst() -> void:
	if not is_queued_for_deletion():
		Fx.spawn(&"sparks", global_position)
		end()
