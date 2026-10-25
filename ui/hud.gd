class_name Hud extends CanvasLayer
# The HUD, drawn in whole pixels at 640x360: Elvis's health and stamina top left with his flasks under them; Vulcan's name and bar
# at the bottom; the spoken line above that; the fade; the title card; the pause menu (Resume / Restart fight / Quit).
# Colours are the Unreal HUD's (Source/TalesOfVulkan/GameHUDWidget.cpp, BossHud.cpp). The font has no antialiasing, so text stays
# crisp when the screen is scaled up. Pausing stops the fades and the line's timer.

signal line_done
signal fade_done
signal restart_requested

const PARCHMENT := Color8(238, 224, 192)    # Parchment: the text
const BRONZE := Color8(214, 164, 92)        # Bronze: the frames, the speaker's name
const RED := Color8(158, 24, 18)            # HealthRed: Elvis's health
const EMBER := Color8(176, 38, 14)          # BossEmberRed: Vulcan's health
const TRAIL := Color8(238, 190, 104)        # TrailGold: what a blow just took, draining behind the bar
const GREEN := Color8(124, 170, 58)         # StaminaGreen
const PLATE := Color8(5, 4, 3, 214)         # the bars' dark plate (GameHUDWidget.cpp's frame brush)
const EMPTY := Color8(150, 60, 50)          # a flask count at 0
const SHADOW := Color(0.0, 0.0, 0.0, 0.9)
const OUTLINE := Color8(20, 14, 12)
const LINE_TIME := 2.5         # a line stays this long, plus LINE_PER_CHAR a character, unless confirm moves it on (the plan)
const LINE_PER_CHAR := 0.05
const LINE_FAST := 0.1         # fast mode
const TRAIL_HOLD := 0.5        # Claude's call: the trail waits this long after a blow, then drains
const TRAIL_RATE := 0.6        # of the bar a second
const SMALL := 10              # font sizes in screen pixels: at 12 and 10 with light hinting the letters space evenly
const TEXT := 12
const BIG := 24

var fast: bool = ShotDriver.fast
var last_line := ""

var _font: FontFile
var _canvas := Control.new()
var _menu := PanelContainer.new()
var _resume := Button.new()
var _elvis: Elvis
var _vulcan: Vulcan
var _boss_on := false
var _trail: Array[float] = [1.0, 1.0]    # Elvis's, Vulcan's
var _hold: Array[float] = [0.0, 0.0]
var _speaker := ""
var _line_on := false
var _line_id := 0
var _black := 0.0
var _fading: Tween
var _title := ""
var _sub := ""

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS    # the pause menu works while the game is paused
	_font = pixel_font()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_hud)
	add_child(_canvas)
	_build_menu()

# The engine's own font with no antialiasing or subpixel placement: every glyph lands on whole pixels.
static func pixel_font() -> FontFile:
	var f := FontFile.new()
	f.data = (ThemeDB.fallback_font as FontFile).data
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_LIGHT
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.generate_mipmaps = false
	return f

# Health, stamina and flasks from `e`, the boss bar from `v`. Called again after a restart: the trails catch up and any line goes.
func bind(e: Elvis, v: Vulcan) -> void:
	_elvis = e
	_vulcan = v
	_trail = [e.health.ratio(), v.health.ratio()]
	_hold = [0.0, 0.0]
	_line_on = false
	_line_id += 1

func show_boss_bar(on: bool) -> void:
	_boss_on = on

func say(speaker: String, text: String) -> void:
	_line_id += 1
	var id := _line_id
	_speaker = speaker
	last_line = text
	_line_on = true
	var t := LINE_FAST if fast else LINE_TIME + LINE_PER_CHAR * text.length()
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP).set_ignore_time_scale(true)
	tw.tween_interval(t)
	tw.tween_callback(_end_line.bind(id))

func fade(to_black: bool, seconds: float) -> void:
	if _fading:
		_fading.kill()
	_fading = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP).set_ignore_time_scale(true)
	_fading.tween_property(self, "_black", 1.0 if to_black else 0.0, maxf(seconds, 0.0))
	_fading.tween_callback(fade_done.emit)

func title_card(title: String, sub: String) -> void:
	_title = title
	_sub = sub

func _end_line(id: int) -> void:
	if id == _line_id and _line_on:
		_line_on = false
		line_done.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		_pause(not get_tree().paused)
	elif event.is_action_pressed(&"confirm") and _line_on and not get_tree().paused:
		_end_line(_line_id)

func _pause(on: bool) -> void:
	get_tree().paused = on
	_menu.visible = on
	if on:
		_resume.grab_focus()

func _process(delta: float) -> void:
	if not get_tree().paused and _elvis and _vulcan:
		_drain(0, _elvis.health.ratio(), delta)
		_drain(1, _vulcan.health.ratio(), delta)
	_canvas.queue_redraw()

func _drain(i: int, now: float, delta: float) -> void:
	if now >= _trail[i]:
		_trail[i] = now
		_hold[i] = TRAIL_HOLD
	elif _hold[i] > 0.0:
		_hold[i] -= delta
	else:
		_trail[i] = maxf(now, _trail[i] - TRAIL_RATE * delta)

func _draw_hud() -> void:
	if _elvis and is_instance_valid(_elvis):
		_bar(Rect2(10, 10, 122, 7), _elvis.health.ratio(), _trail[0], RED)
		_bar(Rect2(10, 19, 92, 5), _elvis.stamina.value / _elvis.stamina.max_value, -1.0, GREEN)
		_flask(Vector2(10, 28), RED, _elvis.flasks.red)
		_flask(Vector2(32, 28), GREEN, _elvis.flasks.green)
	if _boss_on and _vulcan and is_instance_valid(_vulcan):
		_text(Vector2(170, 329), "Vulcan", TEXT, PARCHMENT)    # Claude's call (the plan): the bar reads "Vulcan"
		_bar(Rect2(170, 334, 300, 7), _vulcan.health.ratio(), _trail[1], EMBER)
		_canvas.draw_rect(Rect2(170 + 150, 335, 1, 5), Color(PARCHMENT, 0.55))    # the half: phase two starts here
	if _line_on:
		_text(Vector2(0, 289), _speaker, SMALL, BRONZE, true)
		_text(Vector2(0, 304), last_line, TEXT, PARCHMENT, true)
	if _black > 0.0:
		_canvas.draw_rect(Rect2(Vector2.ZERO, _canvas.size), Color(0, 0, 0, snappedf(_black, 0.125)))    # in 8 steps, like the art
	if _title != "":
		_text(Vector2(0, 172), _title, BIG, PARCHMENT, true)
		_text(Vector2(0, 192), _sub, TEXT, BRONZE, true)

# A bar in its bronze frame: the dark plate, the trail, the fill, all in whole pixels. trail < 0: none.
func _bar(r: Rect2, value: float, trail: float, fill: Color) -> void:
	_canvas.draw_rect(r.grow(1), OUTLINE)    # a dark edge round the frame, so the bar reads on the blood-red floor
	_canvas.draw_rect(r, BRONZE)
	var inner := r.grow(-1)
	_canvas.draw_rect(inner, PLATE)
	if trail > value:
		_canvas.draw_rect(Rect2(inner.position, Vector2(roundi(inner.size.x * trail), inner.size.y)), TRAIL)
	_canvas.draw_rect(Rect2(inner.position, Vector2(roundi(inner.size.x * clampf(value, 0.0, 1.0)), inner.size.y)), fill)

# A flask 5x8 px, its cork, glass and liquid, with the count beside it.
func _flask(at: Vector2, liquid: Color, count: int) -> void:
	_canvas.draw_rect(Rect2(at + Vector2(1, 0), Vector2(3, 1)), Color8(120, 82, 50))    # the cork
	_canvas.draw_rect(Rect2(at + Vector2(1, 1), Vector2(3, 2)), Color8(30, 24, 22))     # the neck's outline
	_canvas.draw_rect(Rect2(at + Vector2(2, 1), Vector2(1, 2)), Color8(150, 160, 170))  # its glass
	_canvas.draw_rect(Rect2(at + Vector2(0, 3), Vector2(5, 5)), Color8(30, 24, 22))     # the body's outline
	_canvas.draw_rect(Rect2(at + Vector2(1, 4), Vector2(3, 3)), liquid if count > 0 else Color8(60, 52, 50))
	_canvas.draw_rect(Rect2(at + Vector2(1, 4), Vector2(1, 1)), Color(1, 1, 1, 0.6))    # a glint
	_text(at + Vector2(8, 8), str(count), TEXT, PARCHMENT if count > 0 else EMPTY)

# Text with a 1 px drop shadow; `centre` centres it across the screen at `at.y` (the baseline).
func _text(at: Vector2, s: String, size: int, c: Color, centre := false) -> void:
	var align := HORIZONTAL_ALIGNMENT_CENTER if centre else HORIZONTAL_ALIGNMENT_LEFT
	var width := _canvas.size.x if centre else -1.0
	_canvas.draw_string(_font, at + Vector2.ONE, s, align, width, size, SHADOW)
	_canvas.draw_string(_font, at, s, align, width, size, c)

func _build_menu() -> void:
	var theme := Theme.new()
	theme.default_font = _font
	theme.default_font_size = TEXT
	var panel := _box(PLATE, BRONZE)
	panel.content_margin_left = 16
	panel.content_margin_right = 16
	panel.content_margin_top = 10
	panel.content_margin_bottom = 10
	theme.set_stylebox(&"panel", &"PanelContainer", panel)
	theme.set_stylebox(&"normal", &"Button", _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0)))
	theme.set_stylebox(&"pressed", &"Button", _box(Color(0, 0, 0, 0), BRONZE))
	theme.set_stylebox(&"hover", &"Button", _box(Color(0, 0, 0, 0), BRONZE))
	theme.set_stylebox(&"focus", &"Button", _box(Color(0, 0, 0, 0), BRONZE))
	for s: StringName in [&"font_color", &"font_focus_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color"]:
		theme.set_color(s, &"Button", PARCHMENT if s != &"font_color" else Color8(196, 184, 158))    # Muted until chosen
	_menu.theme = theme
	_menu.visible = false
	var list := VBoxContainer.new()
	list.add_theme_constant_override(&"separation", 4)
	_menu.add_child(list)
	for item: Array in [[_resume, "Resume", _pause.bind(false)], [Button.new(), "Restart fight", _restart], [Button.new(), "Quit", get_tree().quit]]:
		var b: Button = item[0]
		b.text = item[1]
		b.custom_minimum_size = Vector2(110, 16)
		b.pressed.connect(item[2])
		list.add_child(b)
	add_child(_menu)
	_menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)

func _restart() -> void:
	_pause(false)
	restart_requested.emit()

static func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(1)
	b.anti_aliasing = false
	b.content_margin_left = 6
	b.content_margin_right = 6
	return b
