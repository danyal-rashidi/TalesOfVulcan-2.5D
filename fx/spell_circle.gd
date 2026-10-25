extends FxEffect
# The spell's magic circle on the floor behind him: it draws itself in 0.25 s, turns in steps, and is gone after 1.6 s.

const RADIUS := 1.25    # Unreal BossVulcan.h SpellCircleSize 250 cm across

var _mat: ShaderMaterial

func _build() -> void:
	life = 1.6
	_mat = _ground(3, RADIUS, 0.07, [FIRE[1], FIRE[2], CROWN[2], CROWN[3]], Vector2.ONE * (RADIUS * 2.0 + 0.4), Vector3.ZERO)
	_light(CROWN[1], 1.5, 3.5)

func _step(_delta: float) -> void:
	var heat := clampf((life - age) / 0.3, 0.0, 1.0)
	_mat.set_shader_parameter(&"grow", minf(age / 0.25, 1.0))
	_mat.set_shader_parameter(&"spin", floorf(age * 8.0) * 0.07)
	_mat.set_shader_parameter(&"heat", heat)
	_dim(heat)
