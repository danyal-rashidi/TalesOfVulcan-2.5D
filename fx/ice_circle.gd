class_name FxIceCircle extends FxEffect
# Elvis's magic in ice on the floor, drawn by the fire's own shader: the big circle and its five small ones, turning in steps, or the ring of a splash. Fx.spawn() makes it bare; draw_out() shapes it, and it stays until fade().

const FADE := 0.3    # s

var _mat: ShaderMaterial
var _form := 0.01
var _turn := 0.0
var _out := INF      # age it started to fade

func _build() -> void:
	life = 12.0    # its spawner fades it; this only stops a forgotten one

# shape as ground_fire.gdshader's: 2 a ring, 3 a magic circle. It forms in `seconds`, turning `turn` a step.
func draw_out(shape: int, radius: float, width: float, seconds: float, turn := 0.07) -> void:
	_mat = _ground(shape, radius, width, ICY, Vector2.ONE * (radius * 2.0 + 0.4), Vector3.ZERO)
	_form = maxf(seconds, 0.01)
	_turn = turn
	_step(0.0)

func fade() -> void:
	if _out == INF:
		_out = age
		life = age + FADE

func _step(_delta: float) -> void:
	if _mat:
		_mat.set_shader_parameter(&"grow", minf(age / _form, 1.0))
		_mat.set_shader_parameter(&"spin", floorf(age * 8.0) * _turn)
		_mat.set_shader_parameter(&"heat", clampf(1.0 - (age - _out) / FADE, 0.0, 1.0))
