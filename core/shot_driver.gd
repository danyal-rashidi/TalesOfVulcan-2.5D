extends Node
# Autoload ShotDriver: reads the user args after `--`: shot=<dir> frames=a,b,c saves shot_<frame>.png
# at those frames and quits after the last; `fast` and bot=<name> are read by the game.

var fast := false
var bot := ""

var _dir := ""
var _frames: Array[int] = []
var _frame := 0

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a == "fast":
			fast = true
		elif a.begins_with("bot="):
			bot = a.substr(4)
		elif a.begins_with("shot="):
			_dir = a.substr(5)
		elif a.begins_with("frames="):
			for f in a.substr(7).split(",", false):
				_frames.append(f.to_int())
	set_process(_dir != "" and not _frames.is_empty())

func _process(_delta: float) -> void:
	_frame += 1
	if _frame in _frames:
		get_viewport().get_texture().get_image().save_png("%s/shot_%d.png" % [_dir, _frame])
	if _frame >= _frames.max():
		get_tree().quit()
