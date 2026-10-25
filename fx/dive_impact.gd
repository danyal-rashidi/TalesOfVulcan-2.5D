extends FxEffect
# The magma dive's landing: a ring of fire racing out to RADIUS m, the blow over the whole disc for HIT_TIME s, dust and embers.

const RADIUS := 3.0      # the plan (Unreal BossVulcan.h DiveRadius 330 cm)
const HIT_TIME := 0.2    # Claude's call

var _mat: ShaderMaterial

func _build() -> void:
	life = 0.8
	_mat = _ground(2, RADIUS, 0.22, FIRE, Vector2.ONE * (RADIUS * 2.0 + 0.6), Vector3.ZERO)
	var disc := CylinderShape3D.new()
	disc.radius = RADIUS
	disc.height = 2.0
	_hit(disc, Vector3(0.0, 1.0, 0.0), 30.0, 7.5, true, HIT_TIME)    # Dive.Damage 30, Push 750 cm/s (BossVulcan.cpp)
	var dust := _particles(32, 0.6, SAND, 3)
	dust.position.y = 0.15
	dust.direction = Vector3.RIGHT
	dust.spread = 180.0
	dust.flatness = 1.0
	dust.initial_velocity_min = 4.0
	dust.initial_velocity_max = 6.5
	dust.damping_min = 7.0
	dust.damping_max = 9.0
	dust.scale_amount_max = 2.0
	var embers := _particles(20, 0.7, FIRE, 2)
	embers.direction = Vector3.UP
	embers.spread = 60.0
	embers.initial_velocity_min = 2.0
	embers.initial_velocity_max = 4.0
	embers.gravity = Vector3(0.0, -6.0, 0.0)
	_light(FIRE[2], 3.5, 6.0)

func _step(_delta: float) -> void:
	var heat := clampf((life - age) / 0.5, 0.0, 1.0)
	_mat.set_shader_parameter(&"grow", 1.0 - pow(1.0 - minf(age / 0.3, 1.0), 2.0))    # races out, then slows
	_mat.set_shader_parameter(&"heat", heat)
	_dim(heat)
