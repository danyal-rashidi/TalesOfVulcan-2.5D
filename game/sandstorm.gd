class_name Sandstorm extends CanvasLayer
# Dust blowing across the screen, over the world and under the words: brown haze and streaks of sand. `strength` 0 to 1.

const STREAKS := 170
const SPEED := 460.0     # px/s, at full strength
const HAZE := Color8(150, 112, 62)

var strength := 1.0
var _draw_on := Control.new()
var _time := 0.0

func _ready() -> void:
	layer = 0
	_draw_on.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw_on.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_on.draw.connect(_paint)
	add_child(_draw_on)

func fade_to(value: float, seconds: float) -> void:
	var tw := create_tween()
	tw.tween_property(self, "strength", value, maxf(seconds, 0.001))
	await tw.finished

func _process(delta: float) -> void:
	_time += delta
	_draw_on.queue_redraw()

func _paint() -> void:
	if strength <= 0.01:
		return
	var size := _draw_on.size
	_draw_on.draw_rect(Rect2(Vector2.ZERO, size), Color(HAZE, snappedf(strength * 0.5, 0.0625)))
	for i in STREAKS:
		var h := fmod(sin(i * 12.9898) * 43758.5453, 1.0)
		var h2 := fmod(sin(i * 78.233) * 12543.123, 1.0)
		var long := 6.0 + absf(h) * 26.0
		var x := fposmod(absf(h2) * size.x * 2.0 + _time * SPEED * (0.6 + absf(h) * 0.8), size.x + long) - long
		var y := roundf(fposmod(absf(h) * size.y + sin(_time * 1.3 + i) * 6.0, size.y))
		var c := Color8(226, 198, 148) if i % 3 == 0 else Color8(196, 160, 108)
		if float(i) / STREAKS < strength:    # fewer as it dies down
			_draw_on.draw_rect(Rect2(roundf(x), y, roundf(long), 1.0), Color(c, 0.75))
