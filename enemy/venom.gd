extends FxEffect
# A spitter's venom: lobbed from `position` to `to`, with a ring on the ground where it will land for the whole flight, then a
# splash that hurts whoever still stands in the ring. No blade or teeth, so it can't be parried (HitInfo.parryable stays false):
# roll it, or walk out of the ring. An invulnerable hurtbox isn't hit (Hitbox).

const FLIGHT := 0.8    # s in the air: the ring's whole warning. Claude's call
const RADIUS := 0.9    # m: the ring, and the splash that hurts. Claude's call
const ARC := 2.0       # m: how high it lobs. Claude's call
const DAMAGE := 9.0    # Claude's call: a little more than a bite (Jackal.DAMAGE 7), as it is easier to avoid
const PUSH := 2.0      # m/s
const SPLASH := 0.15   # s the splash hurts for, as a bite's Jackal.ACTIVE
const GREEN: Array[Color] = [Color8(226, 255, 170), Color8(140, 214, 60), Color8(60, 140, 40), Color8(24, 70, 30)]    # Claude's call

var to := Vector3.ZERO    # where it lands; set before it is added

var _from := Vector3.ZERO
var _ball: Sprite3D
var _mark: FxTelegraph

func _build() -> void:
	life = FLIGHT + SPLASH
	_from = position
	var ball := SphereShape3D.new()
	ball.radius = RADIUS
	_hit(ball, Vector3.UP * 0.5, DAMAGE, PUSH, false, 0.0)    # _step starts it, on landing
	_ball = _sprite(ball_image(8, GREEN, 0))
	_mark = Fx.spawn(&"telegraph", to) as FxTelegraph
	_mark.mark(2, RADIUS, 0.12, 0.2)    # a ring, as the boss's dive mark

func _step(_delta: float) -> void:
	var u := minf(age / FLIGHT, 1.0)
	global_position = _from.lerp(to, u)
	_ball.global_position = snap3(global_position + Vector3.UP * ARC * 4.0 * u * (1.0 - u))
	if u >= 1.0 and _ball.visible:
		_ball.visible = false
		_mark.end()
		hitbox.activate(info, SPLASH)
		Fx.spawn(&"dust", to)

# Fx.clear_all() or its time running out takes the ring too.
func end() -> void:
	if is_instance_valid(_mark):
		_mark.end()
	super()
