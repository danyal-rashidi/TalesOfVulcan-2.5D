extends Node
# Autoload ShotDriver: reads the user args after `--`: shot=<dir> frames=a,b,c saves shot_<frame>.png
# at those frames and quits after the last; `fast` and bot=<name> are read by the game.
# `screen` saves what the window really shows (after scaling to the window, bars included) instead of the 640x360 picture.
# fps=<s> prints the average and worst frame after s real seconds, then quits (shots still taken on the way).

var fast := false
var bot := ""

var _dir := ""
var _frames: Array[int] = []
var _frame := 0
var _screen := false
var _fps_for := 0.0
var _start := 0       # usec at the first frame
var _last := 0
var _worst := 0       # usec, the longest frame
var _worst_at := 0

# In _init: autoloads are built before the main scene, whose member initializers read `fast` and `bot`, but get _ready after it.
func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "fast":
			fast = true
		elif a == "screen":
			_screen = true
		elif a.begins_with("bot="):
			bot = a.substr(4)
		elif a.begins_with("shot="):
			_dir = a.substr(5)
		elif a.begins_with("fps="):
			_fps_for = a.substr(4).to_float()
		elif a.begins_with("frames="):
			for f in a.substr(7).split(",", false):
				_frames.append(f.to_int())

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	set_process((_dir != "" and not _frames.is_empty()) or _fps_for > 0.0)
	if _screen:    # the capture reads the screen, so nothing else may cover the window
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
		DisplayServer.window_move_to_foreground()

func _process(_delta: float) -> void:
	_frame += 1
	if _frame in _frames:
		_picture().save_png("%s/shot_%d.png" % [_dir, _frame])
	if _fps_for <= 0.0:
		if _frame >= _frames.max():
			get_tree().quit()
		return
	var now := Time.get_ticks_usec()
	if _frame == 1:
		_start = now
	elif _frame > 30 and now - _last > _worst:    # past the start-up frames
		_worst = now - _last
		_worst_at = _frame
	_last = now
	var s := (now - _start) / 1e6
	if s >= _fps_for:
		print("FPS average %.1f over %d frames in %.1f s, worst frame %.1f ms (frame %d); window %s, screen %s at %.0f Hz; %s" % [
			(_frame - 1) / s, _frame - 1, s, _worst / 1000.0, _worst_at, DisplayServer.window_get_size(),
			DisplayServer.screen_get_size(), DisplayServer.screen_get_refresh_rate(), RenderingServer.get_video_adapter_name()])
		get_tree().quit()

func _picture() -> Image:
	if _screen:
		return DisplayServer.screen_get_image_rect(Rect2i(DisplayServer.window_get_position(), DisplayServer.window_get_size()))
	return get_viewport().get_texture().get_image()
