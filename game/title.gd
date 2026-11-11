class_name Title extends Node
# The title: the logo over the prologue's desert, the colosseum far off under its red haze and sand blowing across (Danyal: New Game,
# Settings, Quit; the logo over the desert). New Game starts the prologue, as the game always began. start= and bot= go past it as they
# go past the prologue; start=settings opens it on the settings page, for a shot of it. Continue, over New Game once Cinerea has saved, picks up
# from the save (docs/ALABASTER_STUDY.md item 10).
# W/S or arrows (stick, d-pad) choose, A/D change a setting, Enter or E (A) picks, Esc (B) goes back; the mouse points and clicks.

const OPENING := "res://game/opening.tscn"
const GAME := "res://game/game.tscn"
const CINEREA := "res://game/cinerea.tscn"
const ITEMS: Array[String] = ["New Game", "Settings", "Quit"]
const SETTINGS: Array[String] = ["Full screen", "Window size", "Camera zoom", "Back"]
const LOGO_AT := Vector2(137, 174)    # at 2x, centred under the colosseum and clear of its haze. Claude's call
const ITEMS_Y := 304.0    # the first item's baseline: four rows fit between the logo's foot (290) and the screen's
const ROW := 17.0
const ROW_W := 110.0      # the pause menu's button width
const PAGE := Rect2(40, 18, 560, 324)    # the settings page's plate
const SET_Y := 70.0
const VALUE_X := 300.0
const CONTROLS_Y := 127.0    # the table's header baseline; its last row must stay clear of Back
const CONTROL_ROW := 13.0
const COLUMNS: Array[float] = [60.0, 250.0, 440.0]
# docs/NEXT.md's "Play it first", the bindings in core/controls.gd
const CONTROLS: Array = [
	["Move", "WASD or arrows", "left stick"],
	["Light attack", "left click or J", "X"],
	["Heavy; hold to charge", "right click or K", "Y"],
	["Roll; hold to sprint", "Space", "B"],
	["Parry, just before a blow", "Shift or C", "RB"],
	["Lock on", "click an enemy", "right stick click"],
	["Skills, from Cinerea on", "F, Q", "right, left trigger"],
	["Spear out or away", "R", "d-pad right"],
	["Inventory, skills, map", "I, Tab next page", "Back, RB next page"],
	["Red flask / green flask", "1 / 2", "d-pad up / down"],
	["Pause", "Esc", "Start"],
	["Next line, pick, use", "Enter or E", "A"],
	["Zoom the camera", "mouse wheel, + and -", "LB in, d-pad left out"],
	["Full screen", "F11 or Alt+Enter", ""],
]
const MUTED := Color8(196, 184, 158)    # the pause menu's words until chosen

var went_to := ""    # where it last went; a test's title isn't the current scene, so there it only says so
var page := 0        # 0 the title, 1 the settings
var pick := 0
var save_path := "" if Settings.automated() else Journey.SAVE    # tests and shots never see his save
var _items: Array[String] = []    # ITEMS, with Continue first when there's a save

var _back := Control.new()    # the desert, under the sand blowing across
var _front := Control.new()   # the logo and the words, over it
var _storm: Sandstorm
var _wide: Texture2D
var _logo: Texture2D

func _ready() -> void:
	if Opening.skips():
		_back.free()    # never joined the tree, so nothing else would free them
		_front.free()
		set_process(false)
		set_process_input(false)
		_go.call_deferred(GAME)
		return
	var under := CanvasLayer.new()
	under.layer = -1
	add_child(under)
	for c: Control in [_back, _front]:
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back.draw.connect(_paint_back)
	under.add_child(_back)
	_storm = Sandstorm.new()
	_storm.strength = 0.12    # the prologue's walk
	add_child(_storm)
	var over := CanvasLayer.new()
	over.layer = 1
	add_child(over)
	_front.draw.connect(_paint_front)
	over.add_child(_front)
	_wide = GameMenu._tex("res://art/story/crossing_wide.png")
	_logo = GameMenu._tex("res://art/ui/logo/logo_tales_of_vulcan.png")
	_items = ITEMS.duplicate()
	if FileAccess.file_exists(save_path):
		_items.push_front("Continue")
	if ShotDriver.start == "settings":
		page = 1

func _rows() -> Array[String]:
	return _items if page == 0 else SETTINGS

func _process(_delta: float) -> void:
	_back.queue_redraw()
	_front.queue_redraw()
	# Polled, not read from events: a held stick sends a stream of them, and this steps once a push.
	if Input.is_action_just_pressed(&"fullscreen"):    # before confirm, which Alt+Enter also presses
		Settings.toggle_fullscreen()
	elif Input.is_action_just_pressed(&"move_up"):
		pick = wrapi(pick - 1, 0, _rows().size())
	elif Input.is_action_just_pressed(&"move_down"):
		pick = wrapi(pick + 1, 0, _rows().size())
	elif page == 1 and Input.is_action_just_pressed(&"move_left"):
		change(-1)
	elif page == 1 and Input.is_action_just_pressed(&"move_right"):
		change(1)
	elif Input.is_action_just_pressed(&"confirm"):
		use()
	elif Input.is_action_just_pressed(&"pause"):
		back()

# The pad's d-pad and B aren't in move_up, move_down or pause, and the mouse points at rows.
func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_DPAD_UP: pick = wrapi(pick - 1, 0, _rows().size())
			JOY_BUTTON_DPAD_DOWN: pick = wrapi(pick + 1, 0, _rows().size())
			JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT:    # in the game they zoom and equip, so they aren't move_left or move_right
				if page != 1:
					return
				change(-1 if event.button_index == JOY_BUTTON_DPAD_LEFT else 1)
			JOY_BUTTON_B: back()
			_: return
	elif event is InputEventMouse:
		var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
		var p: Vector2 = event.position
		var at: int = range(_rows().size()).find_custom(func(i: int) -> bool: return _row(i).has_point(p))
		if at < 0 or not (click or event is InputEventMouseMotion):
			return
		pick = at
		if click:
			use()
	else:
		return
	get_viewport().set_input_as_handled()

func use() -> void:
	if page == 0:
		match _rows()[pick]:
			"Continue":
				_go(CINEREA if Journey.load_from(save_path) else OPENING)    # an unreadable save starts the story over rather than an empty bag in Cinerea: Claude's call
			"New Game": _go(OPENING)    # the save stays until Cinerea's first beat replaces it
			"Settings":
				page = 1
				pick = 0
			"Quit": _go("quit")
	else:
		change(1)

func back() -> void:
	if page == 1:
		page = 0
		pick = _items.find("Settings")

# A setting on the settings page one step along; Back goes back.
func change(d: int) -> void:
	match pick:
		0: Settings.set_fullscreen(not Settings.fullscreen)
		1: Settings.set_window_scale(wrapi(Settings.window_scale + d, 1, Settings.SCALES + 1))
		2: Settings.set_zoom(wrapi(Settings.zoom + d, Settings.ZOOM_FROM, Settings.ZOOM_TO + 1))
		3: back()

func _go(where: String) -> void:
	went_to = where
	if get_tree().current_scene != self:
		return
	if where == "quit":
		get_tree().quit()
	else:
		get_tree().change_scene_to_file(where)

# The row the mouse can point at, round a row's words.
func _row(i: int) -> Rect2:
	if page == 0:
		return Rect2(320.0 - ROW_W / 2.0, ITEMS_Y + i * ROW - 13.0, ROW_W, ROW)
	var y := SET_Y + i * ROW if i < 3 else PAGE.end.y - 14.0
	return Rect2(COLUMNS[0] - 6.0, y - 13.0, PAGE.size.x - 2.0 * (COLUMNS[0] - PAGE.position.x) + 12.0, ROW)

func _paint_back() -> void:
	_back.draw_rect(Rect2(0, 0, 640, 360), Color.BLACK)
	if _wide:
		_back.draw_texture(_wide, Vector2.ZERO)

func _paint_front() -> void:
	if page == 0:
		if _logo:
			_front.draw_texture_rect(_logo, Rect2(LOGO_AT, _logo.get_size() * 2.0), false)
		for i in _items.size():
			_choice(i, _items[i], 320.0)
		return
	_front.draw_rect(PAGE, Hud.PLATE)
	_edge(PAGE.grow(-2.0))
	_text(Vector2(320.0, 40.0), "SETTINGS", Hud.BRONZE, true)
	var values: Array[String] = [
		"On" if Settings.fullscreen else "Off",
		"%dx  %dx%d%s" % [Settings.window_scale, 640 * Settings.window_scale, 360 * Settings.window_scale, "  (not in full screen)" if Settings.fullscreen else ("  (screen fits %dx)" % Settings.fitted_scale() if Settings.fitted_scale() < Settings.window_scale else "")],
		"Normal" if Settings.zoom == 0 else ("%d closer" % Settings.zoom if Settings.zoom > 0 else "%d farther" % -Settings.zoom),
	]
	for i in values.size():
		_choice(i, SETTINGS[i], -1.0)
		_text(Vector2(VALUE_X, SET_Y + i * ROW), ("< %s >" if pick == i else "%s") % values[i], Hud.PARCHMENT if pick == i else MUTED)
	_text(Vector2(COLUMNS[0], CONTROLS_Y - 4.0), "CONTROLS", Hud.BRONZE)
	_text(Vector2(COLUMNS[1], CONTROLS_Y - 4.0), "Keyboard and mouse", Hud.BRONZE)
	_text(Vector2(COLUMNS[2], CONTROLS_Y - 4.0), "Controller", Hud.BRONZE)
	for r in CONTROLS.size():
		for c in 3:
			_text(Vector2(COLUMNS[c], CONTROLS_Y + 12.0 + r * CONTROL_ROW), CONTROLS[r][c], Hud.PARCHMENT if c == 0 else MUTED)
	_choice(3, SETTINGS[3], -1.0)

# A row's words, framed in bronze while chosen as the pause menu's buttons are; x < 0 is the settings page's left column.
func _choice(i: int, s: String, x: float) -> void:
	var r := _row(i)
	if pick == i:
		_edge(r)
	_text(Vector2(x if x >= 0.0 else COLUMNS[0], r.position.y + 13.0), s, Hud.PARCHMENT if pick == i else MUTED, x >= 0.0)

# A one-pixel frame, in whole pixels.
func _edge(r: Rect2) -> void:
	for side: Rect2 in [Rect2(r.position, Vector2(r.size.x, 1)), Rect2(r.position.x, r.end.y - 1, r.size.x, 1), Rect2(r.position, Vector2(1, r.size.y)), Rect2(r.end.x - 1, r.position.y, 1, r.size.y)]:
		_front.draw_rect(side, Hud.BRONZE)

# Hud._text's dark-edged words at 1x, the title's only scale; `centre` centres them on at.x.
func _text(at: Vector2, s: String, c: Color, centre := false) -> void:
	var f := Hud.font(Hud.TEXT)
	var px := Hud.font_px(Hud.TEXT)
	var pos := at.round()
	if centre:
		pos.x = roundf(at.x - f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x / 2.0)
	for d in Hud.AROUND:
		_front.draw_string(f, pos + d, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(Hud.OUTLINE, c.a))
	_front.draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, c)
