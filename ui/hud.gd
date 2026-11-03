class_name Hud extends CanvasLayer
# The HUD, drawn in whole pixels at 640x360: Elvis's health and stamina top left with his flasks under them; Vulcan's name and bar
# at the bottom; the spoken line above that; the fade; the title card; the pause menu (Resume / Restart fight / Quit).
# Colours are the Unreal HUD's (Source/TalesOfVulkan/GameHUDWidget.cpp, BossHud.cpp). The font has no antialiasing, so text stays
# crisp when the screen is scaled up. Pausing stops the fades and the line's timer.

signal line_done
signal fade_done
signal restart_requested
signal _picked(index: int)
signal card_shown

const PARCHMENT := Color8(238, 224, 192)    # Parchment: the text
const BRONZE := Color8(214, 164, 92)        # Bronze: the frames, the speaker's name
const RED := Color8(158, 24, 18)            # HealthRed: Elvis's health
const EMBER := Color8(176, 38, 14)          # BossEmberRed: Vulcan's health
const TRAIL := Color8(238, 190, 104)        # TrailGold: what a blow just took, draining behind the bar
const GREEN := Color8(124, 170, 58)         # StaminaGreen
const PLATE := Color8(5, 4, 3, 214)         # the bars' dark plate (GameHUDWidget.cpp's frame brush)
const EMPTY := Color8(150, 60, 50)          # a flask count at 0
const AROUND: Array[Vector2] = [Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(0, 1), Vector2(1, 1)]    # a dark edge on every side, so words read on any ground with no box behind them (Danyal)
const OUTLINE := Color8(20, 14, 12)
const LINE_TIME := 2.5         # a line stays this long, plus LINE_PER_CHAR a character, unless confirm moves it on (the plan)
const LINE_PER_CHAR := 0.05
const LINE_FAST := 0.1         # fast mode
const CHOICE_H := 16.0         # a line of what Vulcan can say
const LINE_WIDTH := 460.0      # a spoken line wraps at this
const HINT_WIDTH := 620.0      # what to press wraps at this
const LINE_ROW := 14.0
const TRAIL_HOLD := 0.5        # Claude's call: the trail waits this long after a blow, then drains
const TRAIL_RATE := 0.6        # of the bar a second
const SMALL := 10              # text sizes on the 640x360 layout: font() and font_px() turn them into whole font pixels for this zoom
const TEXT := 12
const BIG := 24
const JERSEY := "res://art/ui/fonts/Jersey10-Em20.ttf"    # both SIL OFL: art/ui/fonts/README.txt says where from and what changed
const JERSEY_EM := 20          # one font pixel is one view pixel at this size
const TINY := "res://art/ui/fonts/Tiny5.ttf"
const TINY_EM := 8             # its pixel is 128 of 1024 units
const LETTER := 0.03           # s a letter takes to start showing after the one before (Danyal: every text fades in as you read, Enter skips the fade)
const LETTER_FADE := 6.0       # letters' worth of time each one takes to come up
const CARD_LETTER := 0.09      # a title's letters come up slowly
const ABILITY_AT: Array[Vector2] = [Vector2(597, 120), Vector2(597, 206)]    # F, then Q: docs/refs/ui/2026-11-01_hud.png
const BAR_W := 143.0

var fast: bool = ShotDriver.fast
var last_line := ""
var portrait: Texture2D    # beside the line, while someone with a face speaks

static var _fonts := {}    # loaded once, and kept: a font freed before its text is drawn shows solid white blocks

var _canvas := Control.new()
var _menu := PanelContainer.new()
var _resume := Button.new()
var _elvis: Elvis
var _vulcan: Vulcan
var _boss_on := false
var _player_on := true
var _trail: Array[float] = [1.0, 1.0]    # Elvis's, Vulcan's
var _hold: Array[float] = [0.0, 0.0]
var _speaker := ""
var _line_on := false
var _line_id := 0
var _black := 0.0
var _fading: Tween
var _title := ""
var _pop: Node3D = null       # who the pop-up stands over (pop_up)
var _pop_up := 0.0
var _pop_title := ""
var _pop_sub := ""
var _pop_t := 0.0
var _hint := ""
var _choices := PackedStringArray()    # what Vulcan can say, while choose() waits
var _choice := 0
var _sub := ""
var letters := true        # false: lines show whole at once
var show_journey := false  # embers, drachma and the skills: from Cinerea on, not for Elvis
var _shown := 0.0          # letters of the line that have started showing
var _letter := LETTER
var _title_shown := 0.0
var _card := PackedStringArray()    # rows of words on a card, centred, or at _card_at
var _card_shown := 0.0
var _card_letter := CARD_LETTER
var _card_at := Vector2(-1.0, 172.0)
var _card_size := TEXT + 4
var _card_alpha := 1.0
var _card_told := true
var _items: Texture2D
var _skills: Texture2D
var _ice_icon: Texture2D

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS    # the pause menu works while the game is paused
	_items = GameMenu._tex("res://art/ui/items.png")
	_skills = GameMenu._tex("res://art/ui/skills.png")
	_ice_icon = GameMenu._tex("res://art/ice_spear/icon.png")
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_hud)
	add_child(_canvas)
	_build_menu()

# A pixel font with no antialiasing, hinting or subpixel placement: every glyph lands on whole pixels. Read raw, like the UI's pictures.
static func pixel_font(path := JERSEY) -> FontFile:
	if not _fonts.has(path):
		var f := FontFile.new()
		f.load_dynamic_font(path)
		f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		f.hinting = TextServer.HINTING_NONE
		f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		f.generate_mipmaps = false
		f.allow_system_fallback = false
		_fonts[path] = f
	return _fonts[path]

# Whole Jersey pixels for a text size at this zoom. From the zoom alone, so words on one screen never mix: a BIG title is twice everything else.
# 0: the layout has shrunk past 1x, and Jersey can't, so Tiny5 takes over at half its height.
static func _times(size: int) -> int:
	var body := floori(PixelCamera.view_scale)
	return maxi(body * 2, 1) if size >= BIG else body

static func font(size: int) -> FontFile:
	return pixel_font(JERSEY if _times(size) > 0 else TINY)

# A pixel font is only crisp at whole multiples of its own pixel, so this is the one size to draw any text at.
static func font_px(size: int) -> int:
	return JERSEY_EM * _times(size) if _times(size) > 0 else TINY_EM

# How wide text is in the 640x360 layout's units, which the zoom scales by view_scale and the letters no longer follow exactly.
static func text_w(s: String, size: int) -> float:
	return font(size).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px(size)).x / PixelCamera.view_scale

# Health, stamina and flasks from `e`, the boss bar from `v`. Called again after a restart: the trails catch up and any line goes.
func bind(e: Elvis, v: Vulcan) -> void:
	_elvis = e
	_vulcan = v
	_trail = [e.health.ratio(), v.health.ratio() if v else 1.0]
	_hold = [0.0, 0.0]
	_line_on = false
	_line_id += 1

# A line at the bottom of the screen saying what to do next; "" clears it.
func hint(text: String) -> void:
	_hint = text

# A little sign over `who`, `up` metres above its feet, until pop_down(). It rises into place and bobs.
# It shows after `wait` s: the HUD draws over the world, so a sign a blow earned mustn't sit on that blow's number.
func pop_up(who: Node3D, up: float, title: String, sub: String, wait := 0.0) -> void:
	_pop = who
	_pop_up = up
	_pop_title = title
	_pop_sub = sub
	_pop_t = -wait

func pop_down() -> void:
	_pop = null

func show_boss_bar(on: bool) -> void:
	_boss_on = on

# Elvis's bars and flasks (C3 hides them).
func show_player(on: bool) -> void:
	_player_on = on

# `letter`: seconds between its letters coming up, slower for a line that wants it.
func say(speaker: String, text: String, letter := LETTER) -> void:
	_line_id += 1
	var id := _line_id
	_speaker = speaker
	last_line = text
	_line_on = true
	_letter = letter
	_shown = INF if fast or not letters else 0.0
	var t := LINE_FAST if fast else maxf(LINE_TIME + LINE_PER_CHAR * text.length(), letter * text.length() + 1.8)
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
	_title_shown = INF if fast or not letters else 0.0

# Rows of words alone on the screen, each letter fading in (the prologue's opening, its credits). at.x < 0: centred. Goes with card_off().
func card(rows: PackedStringArray, at := Vector2(-1.0, 172.0), letter := CARD_LETTER, size := TEXT + 4) -> void:
	_card = rows
	_card_at = at
	_card_letter = letter
	_card_size = size
	_card_alpha = 1.0
	_card_shown = INF if fast or not letters else 0.0
	_card_told = false

func card_off(seconds := 0.0) -> void:
	if seconds <= 0.0 or fast:
		_card = PackedStringArray()
		return
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	tw.tween_property(self, "_card_alpha", 0.0, seconds)
	tw.tween_callback(func() -> void: _card = PackedStringArray())

func _end_line(id: int) -> void:
	if id == _line_id and _line_on:
		_line_on = false
		line_done.emit()

# Vulcan picks his line (DIALOGUE.md). Waits for the choice and gives its index. W/S or the stick move, E, Enter or a click take it, 1-4 take one at once.
func choose(options: PackedStringArray) -> int:
	_choices = options
	_choice = 0
	var i: int = await _picked
	_choices = PackedStringArray()
	return i

func pick(index: int) -> void:
	_picked.emit(index)

func _row(i: int) -> Rect2:
	var w := 0.0
	for c in _choices:
		w = maxf(w, text_w(c, TEXT))
	w = roundf(w) + 34.0
	return Rect2(roundf((PixelCamera.VIEW.x - w) / 2.0), 310.0 - CHOICE_H * (_choices.size() - i), w, CHOICE_H)

func _choice_input(event: InputEvent) -> bool:
	if event.is_action_pressed(&"move_up"):
		_choice = wrapi(_choice - 1, 0, _choices.size())
	elif event.is_action_pressed(&"move_down"):
		_choice = wrapi(_choice + 1, 0, _choices.size())
	elif event.is_action_pressed(&"confirm") or event.is_action_pressed(&"attack_light"):
		pick(_choice)
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode >= KEY_1 and event.keycode < KEY_1 + _choices.size():
		pick(event.keycode - KEY_1)
	elif event is InputEventMouseMotion:
		for i in _choices.size():
			if _row(i).has_point(event.position / PixelCamera.view_scale):
				_choice = i
	else:
		return false
	get_viewport().set_input_as_handled()
	return true

func _unhandled_input(event: InputEvent) -> void:
	if not _choices.is_empty() and not get_tree().paused and _choice_input(event):
		return
	if event.is_action_pressed(&"pause"):
		_pause(not get_tree().paused)
	elif event.is_action_pressed(&"fullscreen"):
		# exclusive: Windows' borderless full screen is 2 px short (2560x1438), which drops a 1440p screen from 4x to 3x
		var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	elif event.is_action_pressed(&"confirm") and not get_tree().paused:
		if _title != "" and _title_shown < _letters_in(_title):
			_title_shown = INF
		elif not _card.is_empty() and _card_shown < _letters_in("".join(_card)):
			_card_shown = INF
		elif _line_on:
			if _shown < _letters_in(last_line):    # the first press only finishes the fade
				_shown = INF
			else:
				_end_line(_line_id)

func _pause(on: bool) -> void:
	get_tree().paused = on
	_menu.theme.default_font_size = JERSEY_EM * maxi(_times(TEXT), 1)    # it's laid out on the view, not the shrunken layout, so it never needs Tiny5
	_menu.visible = on
	if on:
		_resume.grab_focus()

func _letters_in(s: String) -> float:
	return s.length() + LETTER_FADE

func _process(delta: float) -> void:
	if not get_tree().paused:
		_shown += delta / _letter
		_title_shown += delta / CARD_LETTER
		_card_shown += delta / _card_letter
		if not _card_told and _card_shown >= _letters_in("".join(_card)):
			_card_told = true
			card_shown.emit()
	if not get_tree().paused and _elvis:
		_drain(0, _elvis.health.ratio(), delta)
		if _vulcan:
			_drain(1, _vulcan.health.ratio(), delta)
	_pop_t += delta
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
	_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * PixelCamera.view_scale)
	if _player_on and _elvis and is_instance_valid(_elvis):
		_plain_bar(Rect2(5, 5, BAR_W, 8), _elvis.health.ratio(), _trail[0], RED)
		_plain_bar(Rect2(5, 17, BAR_W, 8), _elvis.stamina.value / _elvis.stamina.max_value, -1.0, GREEN)
		_flask(Vector2(3, 29), 2, _elvis.flasks.red)
		_flask(Vector2(48, 29), 3, _elvis.flasks.green)
		if show_journey:
			_journey()
		for key in ability_keys():
			_ability_slot(key)
		if is_instance_valid(_elvis.lock_target) and cam_ok():
			_lock_mark(_elvis.lock_target)
	if _boss_on and _vulcan and is_instance_valid(_vulcan):
		_text(Vector2(170, 329), "Vulcan", TEXT, PARCHMENT)    # Claude's call (the plan): the bar reads "Vulcan"
		_bar(Rect2(170, 334, 300, 7), _vulcan.health.ratio(), _trail[1], EMBER)
		_canvas.draw_rect(Rect2(170 + 150, 335, 1, 5), Color(PARCHMENT, 0.55))    # the half: phase two starts here
	var cam := get_viewport().get_camera_3d()
	for a in get_tree().get_nodes_in_group(&"enemies"):
		if _player_on and cam and a.health.ratio() > 0.0:    # a small bar over its head, on the pixel grid as it is
			var at := (1.0 / PixelCamera.view_scale) * cam.unproject_position(Pixel.snap(a.get_global_transform_interpolated().origin) + Vector3.UP * a.bar_up)
			_bar(Rect2(roundf(at.x) - 12.0, roundf(at.y), 24.0, 4.0), a.health.ratio(), -1.0, RED)
	if cam and is_instance_valid(_pop) and _pop_t >= 0.0:
		var over := (1.0 / PixelCamera.view_scale) * cam.unproject_position(Pixel.snap(_pop.get_global_transform_interpolated().origin) + Vector3.UP * _pop_up)
		var w := maxf(text_w(_pop_title, TEXT), text_w(_pop_sub, SMALL)) + 16.0
		var rise := floorf(maxf(1.0 - _pop_t / 0.2, 0.0) * 10.0) + roundf(sin(_pop_t * 3.0))    # rises into place, then bobs a pixel
		var tall := 31.0 if _pop_sub != "" else 18.0
		var plate := Rect2(clampf(roundf(over.x - w / 2.0), 4.0, 636.0 - roundf(w)), maxf(roundf(over.y) - tall - 5.0 + rise, 4.0), roundf(w), tall)
		_canvas.draw_rect(plate.grow(1), BRONZE)
		_canvas.draw_rect(plate, PLATE)
		var tip := plate.position + Vector2(plate.size.x / 2.0, plate.size.y + 1.0)
		_canvas.draw_colored_polygon(PackedVector2Array([tip + Vector2(-4, 0), tip + Vector2(4, 0), tip + Vector2(0, 4)]), BRONZE)
		_text(plate.position + Vector2(8.0, 13.0), _pop_title, TEXT, PARCHMENT)
		if _pop_sub != "":
			_text(plate.position + Vector2(8.0, 26.0), _pop_sub, SMALL, BRONZE)
	if _line_on:
		var shown := _shown
		var rows := _wrap(last_line)
		var w := text_w(_speaker, SMALL)
		for r in rows:
			w = maxf(w, text_w(r, TEXT))
		w += 16.0
		var h := 18.0 + LINE_ROW * rows.size()
		var left := roundf((PixelCamera.VIEW.x - w) / 2.0)
		if portrait:
			var face := Rect2(left - 50.0, 262.0, 48.0, 48.0)
			_canvas.draw_rect(face.grow(1), BRONZE)
			_canvas.draw_texture_rect(portrait, face, false)
		_text(Vector2(0, 322.0 - h), _speaker, SMALL, BRONZE, true)
		var first := 0
		for i in rows.size():
			_faded(Vector2(-1.0, 304.0 - LINE_ROW * (rows.size() - 1 - i)), rows[i], TEXT, PARCHMENT, shown - first)
			first += rows[i].length() + 1
	if not _choices.is_empty():
		for i in _choices.size():
			var row := _row(i)
			_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * PixelCamera.view_scale)
			_canvas.draw_rect(row, PLATE)
			_text(row.position + Vector2(8.0, 12.0), "%d" % (i + 1), SMALL, BRONZE if i == _choice else EMPTY)
			_text(row.position + Vector2(22.0, 12.0), _choices[i], TEXT, PARCHMENT if i == _choice else Color8(170, 158, 134))
			if i == _choice:
				_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * PixelCamera.view_scale)
				_canvas.draw_rect(row, BRONZE, false)
	if _black > 0.0:
		_canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(PixelCamera.VIEW)), Color(0, 0, 0, snappedf(_black, 0.125)))    # in 8 steps, like the art
	if _title != "":
		_faded(Vector2(-1.0, 172.0), _title, BIG, PARCHMENT, _title_shown)
		_faded(Vector2(-1.0, 192.0), _sub, TEXT, BRONZE, _title_shown - _title.length())
	if not _card.is_empty():
		var first := 0
		for i in _card.size():
			_faded(_card_at + Vector2(0.0, i * (_card_size + 6.0)), _card[i], _card_size, Color(PARCHMENT, _card_alpha), _card_shown - first)
			first += _card[i].length()
	if _hint != "":    # last, or a fade to black hides what to press
		var rows := _wrap(_hint, HINT_WIDTH)
		for i in rows.size():
			_text(Vector2(0, 352.0 - LINE_ROW * (rows.size() - 1 - i)), rows[i], SMALL, Color(0.9, 0.86, 0.78), true)

# A bar in its bronze frame: the dark plate, the trail, the fill, all in whole pixels. trail < 0: none.
func _bar(r: Rect2, value: float, trail: float, fill: Color) -> void:
	_canvas.draw_rect(r.grow(1), OUTLINE)    # a dark edge round the frame, so the bar reads on the blood-red floor
	_canvas.draw_rect(r, BRONZE)
	var inner := r.grow(-1)
	_canvas.draw_rect(inner, PLATE)
	if trail > value:
		_canvas.draw_rect(Rect2(inner.position, Vector2(roundi(inner.size.x * trail), inner.size.y)), TRAIL)
	_canvas.draw_rect(Rect2(inner.position, Vector2(roundi(inner.size.x * clampf(value, 0.0, 1.0)), inner.size.y)), fill)

# As Danyal's picture of the HUD: a plain dark bar, no frame.
func _plain_bar(r: Rect2, value: float, trail: float, fill: Color) -> void:
	_canvas.draw_rect(r, Color8(40, 30, 24, 230))
	if trail > value:
		_canvas.draw_rect(Rect2(r.position, Vector2(roundi(r.size.x * trail), r.size.y)), TRAIL)
	_canvas.draw_rect(Rect2(r.position, Vector2(roundi(r.size.x * clampf(value, 0.0, 1.0)), r.size.y)), fill)

# A flask's icon from the menu's atlas, with the count beside it.
func _flask(at: Vector2, icon: int, count: int) -> void:
	_atlas(_items, 22, icon, 4, at, Color.WHITE if count > 0 else Color(0.45, 0.42, 0.42))
	_text(at + Vector2(23, 16), "x%d" % count, TEXT, PARCHMENT if count > 0 else EMPTY)

func _atlas(tex: Texture2D, size: int, index: int, cols: int, at: Vector2, tint := Color.WHITE) -> void:
	if tex:
		_canvas.draw_texture_rect_region(tex, Rect2(at, Vector2(size, size)), Rect2((index % cols) * size, (index / cols) * size, size, size), tint)

# Top right: the numbers alone (Danyal). Down the right: the skills on F and Q, dark as they cool.
func _journey() -> void:
	_atlas(_items, 22, 5, 4, Vector2(581, 4))
	_text(Vector2(606, 20), str(Journey.embers), TEXT, PARCHMENT)
	_atlas(_items, 22, 4, 4, Vector2(581, 27))
	_text(Vector2(606, 43), str(Journey.drachma), TEXT, PARCHMENT)

# The keys with a place on the HUD: Vulcan's two from Cinerea on; as Elvis, only F, his one skill (Danyal).
func ability_keys() -> Array[StringName]:
	if not _elvis._is_vulcan():
		return [&"ability_f"]
	return [&"ability_f", &"ability_q"] if show_journey else []

func _ability_slot(key: StringName) -> void:
	var f := key == &"ability_f"
	var at: Vector2 = ABILITY_AT[0 if f else 1]
	var skill := _elvis.skill_on(key)
	_canvas.draw_rect(Rect2(at - Vector2.ONE, Vector2(28, 28)), Color8(20, 14, 16, 170))
	if skill != "":
		_ability_icon(at, skill, key)
	_text(at + Vector2(10, 39), "F" if f else "Q", TEXT, PARCHMENT)

# A skill's icon. While it cools it's dark from the top down, the light rising from below as it charges, with the whole seconds left over it: the HUD's own size, as BIG would hide the icon and its charging.
func _ability_icon(at: Vector2, skill: String, key: StringName) -> void:
	if skill == Elvis.ICE_SKILL:
		_atlas(_ice_icon, 26, 0, 1, at)
	else:
		_atlas(_skills, 26, Journey.skill_icon(skill), 6, at)
	var wait := _elvis.ability_wait(key)
	if wait > 0.0:
		_canvas.draw_rect(Rect2(at, Vector2(26, roundf(26.0 * wait))), Color8(10, 6, 8, 200))
		var left := str(ceili(_elvis.ability_left(key)))
		_text(at + Vector2(roundf((26.0 - text_w(left, TEXT)) / 2.0), 18), left, TEXT, PARCHMENT)

func cam_ok() -> bool:
	return get_viewport().get_camera_3d() != null

# A bronze mark over whoever he's locked on to.
func _lock_mark(who: Node3D) -> void:
	var up: float = who.get("bar_up") if who.get("bar_up") != null else 2.6
	var over := (1.0 / PixelCamera.view_scale) * get_viewport().get_camera_3d().unproject_position(Pixel.snap(who.get_global_transform_interpolated().origin) + Vector3.UP * up)
	var tip := Vector2(roundf(over.x), roundf(over.y) - 3.0)
	_canvas.draw_colored_polygon(PackedVector2Array([tip + Vector2(-5, -6), tip + Vector2(5, -6), tip]), BRONZE)
	_canvas.draw_colored_polygon(PackedVector2Array([tip + Vector2(-3, -5), tip + Vector2(3, -5), tip + Vector2(0, -2)]), RED)

# Words whose letters come up one after another, each fading in. shown: letters that have started; at.x < 0 centres it on the screen.
func _faded(at: Vector2, s: String, size: int, c: Color, shown: float) -> void:
	if s == "" or shown <= 0.0:
		return
	if shown >= s.length() + LETTER_FADE:
		_text(Vector2(0.0 if at.x < 0.0 else at.x, at.y), s, size, c, at.x < 0.0)
		return
	var k := PixelCamera.view_scale
	var f := font(size)
	var px := font_px(size)
	var unit := maxi(_times(size), 1)    # one font pixel
	var whole := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var left := roundf((PixelCamera.VIEW.x * k - whole) / 2.0) if at.x < 0.0 else roundf(at.x * k)
	var y := roundf(at.y * k)
	_canvas.draw_set_transform(Vector2.ZERO)
	for edge: bool in [true, false]:    # the edges first, or a letter's edge cuts into the letter before it
		for i in s.length():
			var a := clampf((shown - i) / LETTER_FADE, 0.0, 1.0)
			if a <= 0.0:
				break
			a = snappedf(a, 0.125) * c.a    # in 8 steps, like the art
			var x := left + f.get_string_size(s.substr(0, i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, px).x - f.get_string_size(s[i], HORIZONTAL_ALIGNMENT_LEFT, -1, px).x    # with s[i], so the kern before it counts
			if edge:
				for d in AROUND:
					_canvas.draw_string(f, Vector2(x, y) + d * unit, s[i], HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(OUTLINE, a))
			else:
				_canvas.draw_string(f, Vector2(x, y), s[i], HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(c, a))
	_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * k)

# Text with a dark edge one font pixel wide; `centre` centres it across the screen at `at.y` (the baseline).
# Letters are drawn at a whole font size for this zoom, not scaled from a smaller one, so they stay sharp.
func _text(at: Vector2, s: String, size: int, c: Color, centre := false) -> void:
	var k := PixelCamera.view_scale
	var pos := (at * k).round()
	var f := font(size)
	var px := font_px(size)
	if centre:    # rounded as _faded rounds it, or the letters jump a pixel when a fade finishes
		pos.x = roundf((PixelCamera.VIEW.x * k - f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x) / 2.0)
	_canvas.draw_set_transform(Vector2.ZERO)
	for d in AROUND:
		_canvas.draw_string(f, pos + d * maxi(_times(size), 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(OUTLINE, c.a))
	_canvas.draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, c)
	_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * k)

# A spoken line broken to fit the screen.
func _wrap(line: String, width := LINE_WIDTH) -> PackedStringArray:
	var rows := PackedStringArray()
	var row := ""
	for word in line.split(" "):
		var next := word if row == "" else row + " " + word
		if text_w(next, TEXT) > width and row != "":
			rows.append(row)
			row = word
		else:
			row = next
	rows.append(row)
	return rows

func _build_menu() -> void:
	var theme := Theme.new()
	theme.default_font = pixel_font()
	theme.default_font_size = JERSEY_EM
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
	_canvas.add_child(_menu)    # so it stays centred on the 640x360 HUD when the camera zooms
	_menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_menu.grow_horizontal = Control.GROW_DIRECTION_BOTH    # bigger letters at a far zoom must not push it off centre
	_menu.grow_vertical = Control.GROW_DIRECTION_BOTH

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
