extends FxEffect
# The slam's blade of fire landing along the floor: LENGTH m along dir from where it's spawned, out in 0.12 s, then burning down.

const LENGTH := 6.0         # the plan (Unreal BossVulcan.h StripLength 540 cm)
const HALF_WIDTH := 0.75    # Unreal BossVulcan.h AuraBladeWidth 150 cm
const GROW := 0.12
const HIT_TIME := 0.25      # Claude's call: it hurts as it lands, then it is only fire

var _mat: ShaderMaterial

func _build() -> void:
	life = 1.0
	_mat = _ground(0, LENGTH, HALF_WIDTH, FIRE, Vector2(HALF_WIDTH * 2.0, LENGTH), Vector3(0.0, 0.0, -LENGTH / 2.0))
	var box := BoxShape3D.new()
	box.size = Vector3(HALF_WIDTH * 2.0, 1.2, LENGTH)
	_hit(box, Vector3(0.0, 0.6, -LENGTH / 2.0), 28.0, 6.5, true, HIT_TIME)    # Slam.Damage 28, Push 650 cm/s (BossVulcan.cpp)
	var p := _particles(28, 0.8, FIRE, 2)
	p.position = Vector3(0.0, 0.15, -LENGTH / 2.0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(HALF_WIDTH * 0.6, 0.1, LENGTH / 2.0)
	p.direction = Vector3.UP
	p.spread = 20.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 2.0
	p.gravity = Vector3(0.0, 1.5, 0.0)
	_light(FIRE[2], 2.5, 5.0).position.z = -LENGTH / 2.0

func _step(_delta: float) -> void:
	var heat := clampf((life - age) / 0.6, 0.0, 1.0)
	_mat.set_shader_parameter(&"grow", minf(age / GROW, 1.0))
	_mat.set_shader_parameter(&"heat", heat)
	_dim(heat)
