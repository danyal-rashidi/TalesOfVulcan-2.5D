extends Node
# Autoload Settings: full screen, the window's size and the camera's starting zoom, kept in user://settings.cfg and put on at startup.
# Tests, bots and shot runs leave the window and the camera as project.godot has them, so they look the same every run. Claude's call

const PATH := "user://settings.cfg"
const SCALES := 4                 # the window is 1x to 4x of the game's 640x360
const ZOOM_FROM := -2             # PixelCamera.zoom steps to choose from; the camera still keeps them inside what the window allows
const ZOOM_TO := 4

var fullscreen := false
var window_scale := 3             # 1920x1080, the window project.godot opens
var zoom := 0                     # PixelCamera.zoom each run starts at; the mouse wheel still changes it for the run

func _ready() -> void:
	load_from()
	if not automated():
		apply()

static func automated() -> bool:
	if "res://tests/run_tests.tscn" in OS.get_cmdline_args():
		return true
	for a in OS.get_cmdline_user_args():
		if a == "fast" or a.begins_with("shot=") or a.begins_with("bot="):
			return true
	return false

# A missing or hand-broken file leaves what's already set.
func load_from(path := PATH) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	fullscreen = bool(cfg.get_value("display", "fullscreen", fullscreen))
	window_scale = clampi(int(cfg.get_value("display", "window_scale", window_scale)), 1, SCALES)
	zoom = clampi(int(cfg.get_value("camera", "zoom", zoom)), ZOOM_FROM, ZOOM_TO)

func save_to(path := PATH) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "window_scale", window_scale)
	cfg.set_value("camera", "zoom", zoom)
	cfg.save(path)

func apply() -> void:
	PixelCamera.zoom = zoom
	_apply_window()

func set_fullscreen(on: bool) -> void:
	fullscreen = on
	_apply_window()
	save_to()

# F11 and Alt+Enter, from the title or the game.
func toggle_fullscreen() -> void:
	set_fullscreen(DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

func set_window_scale(k: int) -> void:
	window_scale = clampi(k, 1, SCALES)
	_apply_window()
	save_to()

func set_zoom(z: int) -> void:
	zoom = clampi(z, ZOOM_FROM, ZOOM_TO)
	PixelCamera.zoom = zoom
	save_to()

# The window size counts only out of full screen, and shrinks to the biggest whole scale the screen has room for.
func _apply_window() -> void:
	if fullscreen:
		# exclusive: Windows' borderless full screen is 2 px short (2560x1438), which drops a 1440p screen from 4x to 3x
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	get_window().size = PixelCamera.VIEW * fitted_scale()
	get_window().move_to_center()

# The scale the window really gets: the chosen one, or less if the screen has no room for it.
func fitted_scale() -> int:
	var room := DisplayServer.screen_get_usable_rect().size / PixelCamera.VIEW
	return clampi(window_scale, 1, maxi(mini(room.x, room.y), 1))
