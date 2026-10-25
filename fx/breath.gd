extends FxEffect
# The molten breath: a wedge of fire HALF_ANGLE to each side of dir and LENGTH m long, burning SECONDS; its hitbox hits anew every TICK.

const LENGTH := 5.0         # the plan (Unreal BossVulcan.h BreathLength 700 cm)
const HALF_ANGLE := 30.0    # degrees: the plan's 60° cone (Unreal BreathHalfAngle 24)
const SECONDS := 1.2        # the plan (Unreal BreathSeconds 2.4)
const TICK := 0.3           # the plan (Unreal BreathTickSeconds 0.9, the first at 0.4)
const HEIGHT := 2.3         # Unreal BossVulcan.h BreathHeight 230 cm

var _mat: ShaderMaterial
var _flames: CPUParticles3D
var _next := 0.0

func _build() -> void:
	life = SECONDS
	var a := deg_to_rad(HALF_ANGLE)
	_mat = _ground(1, LENGTH, a, FIRE, Vector2(LENGTH * sin(a) * 2.0 + 0.2, LENGTH), Vector3(0.0, 0.0, -LENGTH / 2.0))
	var pts := PackedVector3Array([Vector3.ZERO, Vector3.UP * HEIGHT])
	for i in 7:
		var p := Vector3(sin(lerpf(-a, a, i / 6.0)), 0.0, -cos(lerpf(-a, a, i / 6.0))) * LENGTH
		pts.append(p)
		pts.append(p + Vector3.UP * HEIGHT)
	var wedge := ConvexPolygonShape3D.new()
	wedge.points = pts
	_hit(wedge, Vector3.ZERO, 9.0, 0.0, false, 0.0)    # Breath.Damage 9 a burn, Push 0 (BossVulcan.cpp)
	_flames = _particles(60, 0.9, FIRE, 3, false)
	_flames.position.y = 0.4
	_flames.direction = Vector3.FORWARD
	_flames.spread = HALF_ANGLE
	_flames.flatness = 0.8
	_flames.initial_velocity_min = 4.0
	_flames.initial_velocity_max = 5.5
	_flames.gravity = Vector3(0.0, 0.6, 0.0)
	_light(FIRE[2], 2.5, 5.0).position.z = -LENGTH / 2.0

func _step(_delta: float) -> void:
	if age >= _next:
		_next += TICK
		hitbox.activate(info, TICK)
	var heat := clampf((life - age) / 0.25, 0.0, 1.0)
	_mat.set_shader_parameter(&"grow", minf(age / 0.15, 1.0))
	_mat.set_shader_parameter(&"heat", heat)
	_flames.emitting = life - age > 0.35
	_dim(heat)
