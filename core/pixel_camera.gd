class_name PixelCamera extends Camera3D
# Orthographic camera looking down at Pixel.PITCH_DEG, snapped to the pixel grid every frame. Zoom changes how many screen pixels make one
# art pixel, always a whole number, so the art stays crisp; the game draws more or fewer of them and the HUD stays the same size on screen.

signal focus_done

const BACK := 30.0    # metres back along the view direction
const VIEW := Vector2i(640, 360)    # the game's own size: Hud and GameMenu draw in it
const MOST_VIEW := 720      # zoomed out: art pixels high at most, Claude's call
const LEAST_VIEW := 180     # zoomed in

static var zoom := 0        # whole steps of screen pixels per art pixel away from the default; lasts past a restart
static var view_scale := 1.0    # what Hud and GameMenu, which lay themselves out at 640x360, multiply by to stay the same size on screen

var lead := Vector3.ZERO    # added to the followed target, so the view can run ahead of it

var _target: Node3D
var _look := Vector3.ZERO    # the ground point at the screen centre, before snapping
var _focus: Tween
var _shake_px := 0
var _shake_until := 0

func _init() -> void:
	projection = PROJECTION_ORTHOGONAL
	size = 360.0 / Pixel.PX
	rotation_degrees.x = -Pixel.PITCH_DEG
	far = 200.0
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF    # _process() puts it on the grid every frame itself

func _ready() -> void:
	get_window().size_changed.connect(_apply_zoom)
	_apply_zoom()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"zoom_in"):
		zoom += 1
		_apply_zoom()
	elif event.is_action_pressed(&"zoom_out"):
		zoom -= 1
		_apply_zoom()

# The nearest allowed step: `step` screen pixels per art pixel away from the default, in a window this big.
static func allowed_step(win: Vector2i, step: int) -> int:
	var base := maxi(floori(win.y / float(VIEW.y)), 1)
	var least := maxi(ceili(win.y / float(MOST_VIEW)), 1)
	var most := maxi(floori(win.y / float(LEAST_VIEW)), least)
	return clampi(base + step, least, most) - base

static func view_for(win: Vector2i, step: int) -> Vector2i:
	if step == 0:
		return VIEW
	var k := maxi(floori(win.y / float(VIEW.y)), 1) + step
	return Vector2i(win.x / k, win.y / k)

func _apply_zoom() -> void:
	var win := get_window().size
	zoom = allowed_step(win, zoom)
	var view := view_for(win, zoom)
	get_window().content_scale_size = view
	size = view.y / Pixel.PX
	view_scale = view.y / float(VIEW.y)

func follow(t: Node3D) -> void:
	if _focus:
		_focus.kill()
	_target = t

# Glide to `at` and hold there (focus_done) until follow() is called again.
func focus(at: Vector3, seconds: float) -> void:
	if _focus:
		_focus.kill()
	_target = null
	_focus = create_tween()
	_focus.tween_property(self, "_look", at, seconds)
	_focus.tween_callback(focus_done.emit)

# Real-time seconds, so it still shakes during a hit-stop.
func shake(px: float, seconds: float) -> void:
	_shake_px = maxi(_shake_px if Time.get_ticks_msec() < _shake_until else 0, roundi(px))
	_shake_until = maxi(_shake_until, Time.get_ticks_msec() + roundi(seconds * 1000.0))

func _process(_delta: float) -> void:
	if is_instance_valid(_target):
		_look = _target.get_global_transform_interpolated().origin + lead    # where the target is drawn this frame
	var p := _shake_px if Time.get_ticks_msec() < _shake_until else 0
	# 1/PX m in camera space is exactly one screen pixel, so the shake stays on the grid.
	h_offset = randi_range(-p, p) / Pixel.PX
	v_offset = randi_range(-p, p) / Pixel.PX
	var a := deg_to_rad(Pixel.PITCH_DEG)
	global_position = Pixel.snap(_look) + Vector3(0.0, sin(a), cos(a)) * BACK
