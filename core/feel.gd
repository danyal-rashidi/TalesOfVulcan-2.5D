extends Node
# Autoload Feel: hit-stop, screen shake and slow motion. All durations are real seconds.

const STOP_SCALE := 0.05

var _stops := 0       # hit-stops running; time scale returns to _base when the last ends
var _base := 1.0      # time scale outside hit-stops (slow motion changes it)
var _slow_id := 0

func hit_stop(seconds: float) -> void:
	_stops += 1
	Engine.time_scale = STOP_SCALE
	await get_tree().create_timer(seconds, true, false, true).timeout
	_stops -= 1
	if _stops == 0:
		Engine.time_scale = _base

func shake(px: float, seconds: float) -> void:
	var cam := get_viewport().get_camera_3d() as PixelCamera
	if cam:
		cam.shake(px, seconds)

func slow_motion(scale: float, seconds: float) -> void:
	_slow_id += 1
	var id := _slow_id
	_base = scale
	if _stops == 0:
		Engine.time_scale = scale
	await get_tree().create_timer(seconds, true, false, true).timeout
	if id == _slow_id:
		_base = 1.0
		if _stops == 0:
			Engine.time_scale = 1.0
