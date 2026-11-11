extends Node
# Autoload Controls: every action, bound in code for keyboard and mouse and for a controller.

const DEADZONE := 0.2

func _ready() -> void:
	_add(&"move_left", [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)])
	_add(&"move_right", [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)])
	_add(&"move_up", [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0)])
	_add(&"move_down", [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0)])
	_add(&"attack_light", [_mouse(MOUSE_BUTTON_LEFT), _key(KEY_J), _joy(JOY_BUTTON_X)])            # joy 2
	_add(&"attack_heavy", [_mouse(MOUSE_BUTTON_RIGHT), _key(KEY_K), _joy(JOY_BUTTON_Y)])           # joy 3
	_add(&"roll", [_key(KEY_SPACE), _joy(JOY_BUTTON_B)])                                          # joy 1; tap rolls, held 0.25 s sprints
	_add(&"parry", [_key(KEY_SHIFT), _key(KEY_C), _joy(JOY_BUTTON_RIGHT_SHOULDER)])                            # joy 10, shared with menu_next, which only turns the menu's pages (ui/menu.gd); just before a blow lands (Batch 2). C too: five quick Shifts open Windows' Sticky Keys box
	_add(&"lock_on", [_mouse(MOUSE_BUTTON_MIDDLE), _joy(JOY_BUTTON_RIGHT_STICK)])                  # joy 8; with the mouse, click an enemy (Elvis._lock_at)
	_add(&"ability_f", [_key(KEY_F), _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)])                          # the skills he has on (Danyal, 1 Nov)
	_add(&"ability_q", [_key(KEY_Q), _axis(JOY_AXIS_TRIGGER_LEFT, 1.0)])
	_add(&"flask_red", [_key(KEY_1), _joy(JOY_BUTTON_DPAD_UP)])                                   # joy 11
	_add(&"flask_green", [_key(KEY_2), _joy(JOY_BUTTON_DPAD_DOWN)])                               # joy 12
	_add(&"equip", [_key(KEY_R), _joy(JOY_BUTTON_DPAD_RIGHT)])                                    # joy 14; draws or puts away the spear (Danyal, 31 Oct)
	_add(&"menu", [_key(KEY_I), _joy(JOY_BUTTON_BACK)])                                           # joy 4; the inventory, skills and map
	_add(&"menu_next", [_key(KEY_TAB), _joy(JOY_BUTTON_RIGHT_SHOULDER)])                          # joy 10; the menu's next page
	_add(&"pause", [_key(KEY_ESCAPE), _joy(JOY_BUTTON_START)])                                    # joy 6
	_add(&"confirm", [_key(KEY_ENTER), _key(KEY_E), _joy(JOY_BUTTON_A)])                          # joy 0
	_add(&"zoom_in", [_mouse(MOUSE_BUTTON_WHEEL_UP), _key(KEY_EQUAL), _key(KEY_KP_ADD), _joy(JOY_BUTTON_LEFT_SHOULDER)])       # joy 9
	_add(&"zoom_out", [_mouse(MOUSE_BUTTON_WHEEL_DOWN), _key(KEY_MINUS), _key(KEY_KP_SUBTRACT), _joy(JOY_BUTTON_DPAD_LEFT)])   # joy 13
	_add(&"dev", [_key(KEY_F1)])                                                                 # the dev panel (core/dev.gd), in every build (Danyal)
	var alt_enter := _key(KEY_ENTER) as InputEventKey
	alt_enter.alt_pressed = true
	_add(&"fullscreen", [_key(KEY_F11), alt_enter])                                               # Claude's call (Task 6)

func move_vector() -> Vector2:    # not static: it's called on the autoload
	return Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down", DEADZONE)

func _add(action: StringName, events: Array[InputEvent]) -> void:
	InputMap.add_action(action, DEADZONE)
	for e in events:
		e.device = -1    # any device
		InputMap.action_add_event(action, e)

static func _key(k: Key) -> InputEvent:
	var e := InputEventKey.new()
	e.physical_keycode = k    # by position, so WASD works on any keyboard layout
	return e

static func _mouse(b: MouseButton) -> InputEvent:
	var e := InputEventMouseButton.new()
	e.button_index = b
	return e

static func _joy(b: JoyButton) -> InputEvent:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	return e

static func _axis(a: JoyAxis, v: float) -> InputEvent:
	var e := InputEventJoypadMotion.new()
	e.axis = a
	e.axis_value = v
	return e
