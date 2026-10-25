extends Node
# Autoload ShotDriver: reads the user args after `--`: shot=<dir> frames=a,b,c saves shot_<frame>.png
# at those frames and quits after the last; `fast` and bot=<name> are read by the game.

var fast := false
var bot := ""

var _dir := ""
var _frames: Array[int] = []
var _frame := 0

# In _init: autoloads are built before the main scene, whose member initializers read `fast` and `bot`, but get _ready after it.
func _init() -> void:
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

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	set_process(_dir != "" and not _frames.is_empty())

func _process(_delta: float) -> void:
	_frame += 1
	if _frame in _frames:
		get_viewport().get_texture().get_image().save_png("%s/shot_%d.png" % [_dir, _frame])
	if _frame >= _frames.max():
		get_tree().quit()
