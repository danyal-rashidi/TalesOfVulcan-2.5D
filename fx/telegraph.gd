class_name FxTelegraph extends FxEffect
# Where one of Vulcan's blows will land, dim on the floor and forming while he winds up: Unreal's slam strip, breath wedge and
# dive mark (BossVulcanMoves.cpp ShowStrip and ShowWedge, BossVulcanBrain.cpp TickDiveMark). Fx.spawn() makes it bare; mark() shapes it.
# The spawner moves and turns it with him, and ends it when the blow comes.

const EMBER: Array[Color] = [CROWN[1], CROWN[2], Color8(150, 14, 26), Color8(40, 6, 12)]    # its two low tones, one above the blood mood's floor and one below: never the floor's own. Claude's call
const HEAT := 0.5    # half the fire's: its embers, not its flames

var _mat: ShaderMaterial
var _form := 1.0

func _build() -> void:
	life = 10.0    # the spawner ends it; this only stops a forgotten one

# shape as ground_fire.gdshader's: 0 a strip `size` long and `width` to each side, 1 a wedge `size` long and `width` radians to each side,
# 2 a ring of radius `size`. It grows to its full size over `seconds`.
func mark(shape: int, size: float, width: float, seconds: float) -> void:
	var extent := Vector2.ONE * (size + width) * 2.0
	var centre := Vector3.ZERO
	if shape == 0:
		extent = Vector2(width * 2.0, size)
	elif shape == 1:
		extent = Vector2(size * sin(width) * 2.0 + 0.2, size)
	if shape != 2:
		centre.z = -size / 2.0
	_mat = _ground(shape, size, width, EMBER, extent, centre)
	_mat.set_shader_parameter(&"heat", HEAT)
	_form = maxf(seconds, 0.01)
	_step(0.0)

func _step(_delta: float) -> void:
	if _mat:
		_mat.set_shader_parameter(&"grow", minf(age / _form, 1.0))
