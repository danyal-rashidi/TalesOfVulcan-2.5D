class_name Opening extends Node
# The prologue's opening (STORY.md C0): words on black as sand blows across them, then a man walking across the desert with the credits going by and his voice over it, then the colosseum far off under its red haze, and a low rumble. Then the walk in is yours.
# Enter finishes the fade of what's being written and moves a line on. Esc skips it all. Every wait is x0.05 when fast.

const HUD := preload("res://ui/hud.tscn")
const WHO_ELVIS: String = Steps.WHO["elvis_blue"][0]
const VOICE := 0.045        # s between the letters of his voice: slow, tired
const CARD: Array[String] = ["A colosseum stands alone in the desert.", "Inside, the god of fire sleeps in stone,", "wearing a crown that is not his."]
const CREDITS: Array = [["Tales of Vulcan"], ["A game by", "Danyal Rashidi"], ["Nathan", "dabiost"], ["Music", "\"Wrath of Vulkan\""]]
const CREDIT_AT := Vector2(392.0, 92.0)
const LINES_WALK: Array[String] = ["They say a god sleeps out here. Vulcan. Father of fire. The smith of the heavens.", "A year ago the sky over this desert turned red. It hasn't cleared since."]
const LINES_FAR: Array[String] = ["Every one of them walked to that wall. Soldiers, priests, men who wanted his fire for themselves.", "I've passed their bones for a day now.", "I don't owe this land anything.", "But somebody has to wake him."]
const SKY_END := 130        # rows of art/story/dunes.png: the still sky, the far dunes, the sand he walks on
const DUNES_END := 220
const RUN_LOOP := 0.55      # s for a loop of his run: art/elvis_blue/manifest.json
const STEP_PX := 36.0       # his foot sweeps 18 px of the sheet a step, drawn twice over here. Whole pixels, so prints and ground move together
const WALK_SPEED := STEP_PX * 2.0 / RUN_LOOP    # px/s the ground goes by: his feet don't slide on it
const FOOT_X := 281.0       # where a foot is planted on screen: frame 0 of the sheet, and again a step later
const SIDE_PX := 2.0        # the near foot this much lower than his line, the far foot higher. Claude's call
const GRAINS := 9           # sand a step kicks up: fx/step_sand.gd at a run, in his 2x pixels. Claude's call
const GRAIN_LIFE := 0.55    # s, fx/step_sand.gd's too
const GRAIN_COLOURS: Array[Color] = [Color8(232, 200, 128), Color8(206, 170, 104), Color8(178, 142, 84)]
const FAR_WALK := 3.0       # px/s he goes, far off
const FAR_FROM := Vector2(250.0, 338.0)
const FAR_WAY := Vector2(0.62, -1.0)    # towards the colosseum in art/story/crossing_wide.png
const FAR_STEP := 5.0       # px between his prints, far off: real strides would run together at this size. Claude's call
const FAR_SIDE := 1.0       # px either side of his line, far off. Claude's call
const FAR_SIZE := 0.5       # as he's drawn out there
const FEET := 322.0         # y on the screen of his feet as he walks

var fast: bool = ShotDriver.fast
var hud: Hud

var _layer := CanvasLayer.new()
var _view := Control.new()
var _elvis := Control.new()    # him alone, over _view: through ui/him.gdshader, so he's the same man as in the world
var _storm: Sandstorm
var _mode := &"black"
var _scroll := 0.0
var _time := 0.0
var _dunes: Texture2D
var _wide: Texture2D
var _run_s: Texture2D
var _run_b: Texture2D
var _run_s_frames := 1
var _run_b_frames := 1
var _cell := Vector2.ONE
var _haze := 0.0
var _leaving := false
var _grains := RandomNumberGenerator.new()

func _ready() -> void:
	if ShotDriver.start == "cinerea" or ShotDriver.start == "colosseum" or ShotDriver.bot != "":
		get_tree().change_scene_to_file.call_deferred("res://game/game.tscn")
		return
	_layer.layer = -1
	add_child(_layer)
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.draw.connect(_paint)
	_layer.add_child(_view)
	var palette := ShaderMaterial.new()
	palette.shader = preload("res://ui/him.gdshader")
	_elvis.material = palette
	_elvis.set_anchors_preset(Control.PRESET_FULL_RECT)
	_elvis.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_elvis.draw.connect(_paint_elvis)
	_view.add_child(_elvis)
	_dunes = GameMenu._tex("res://art/story/dunes.png")
	_wide = GameMenu._tex("res://art/story/crossing_wide.png")
	var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/elvis_blue/manifest.json"))
	_cell = Vector2(m["cell"][0], m["cell"][1])
	_run_s = GameMenu._tex("res://art/elvis_blue/%s" % m["anims"]["run_S"]["file"])
	_run_b = GameMenu._tex("res://art/elvis_blue/%s" % m["anims"]["run_B"]["file"])
	_run_s_frames = int(m["anims"]["run_S"]["frames"])
	_run_b_frames = int(m["anims"]["run_B"]["frames"])
	_storm = Sandstorm.new()
	_storm.strength = 0.0
	add_child(_storm)
	hud = HUD.instantiate() as Hud
	hud.fast = fast
	add_child(hud)
	hud.show_player(false)
	_play()

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds * (0.05 if fast else 1.0)).timeout

func _voice(line: String) -> void:
	hud.say("", line, VOICE)
	await hud.line_done

func _play() -> void:
	# Part 1: words on black, and sand blows them away.
	await _wait(1.0)
	hud.card(PackedStringArray(CARD), Vector2(-1.0, 150.0))
	await hud.card_shown
	await _wait(1.6)
	_storm.fade_to(0.5, 1.2 * (0.05 if fast else 1.0))
	hud.card_off(1.4)
	await _wait(1.8)
	_storm.fade_to(0.0, 1.0 * (0.05 if fast else 1.0))
	await _voice("Three days since the last well.")
	if not is_inside_tree():
		return

	# Part 2: the side shot, with the credits going by.
	hud.fade(true, 0.0)
	_mode = &"walk"
	_storm.strength = 0.12
	hud.fade(false, 2.0 * (0.05 if fast else 1.0))
	await _wait(2.0)
	_credits()
	for line in LINES_WALK:
		await _voice(line)
		await _wait(0.8)
	await _wait(3.0)
	hud.fade(true, 1.2 * (0.05 if fast else 1.0))
	await hud.fade_done

	# Part 3: the colosseum, far off, and him a small figure walking to it.
	hud.card_off()
	_mode = &"far"
	_storm.strength = 0.0
	hud.fade(false, 1.6 * (0.05 if fast else 1.0))
	await _wait(1.8)
	for line in LINES_FAR:
		await _voice(line)
		await _wait(0.6)
	# On the last line a low rumble, and the haze over it pulses once.
	Feel.shake(2.0, 0.8)
	var tw := create_tween()
	tw.tween_property(self, "_haze", 0.55, 0.5 * (0.05 if fast else 1.0))
	tw.tween_property(self, "_haze", 0.0, 1.1 * (0.05 if fast else 1.0))
	await tw.finished
	_on()

func _credits() -> void:
	for rows: Array in CREDITS:
		if not is_inside_tree() or _mode != &"walk":
			return
		hud.card(PackedStringArray(rows), CREDIT_AT, 0.05, 12)
		await _wait(4.2)
		if _mode == &"walk":
			hud.card_off(0.8)
		await _wait(1.0)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		_on()

# On to the walk in, in the dark.
func _on() -> void:
	if _leaving:
		return
	_leaving = true
	hud.fade(true, 0.8 * (0.05 if fast else 1.0))
	await hud.fade_done
	Game.crossing = true
	if get_tree().current_scene == self:
		get_tree().change_scene_to_file("res://game/game.tscn")

func _process(delta: float) -> void:
	_time += delta
	_scroll += WALK_SPEED * delta
	_view.queue_redraw()
	_elvis.queue_redraw()

func _band(y0: int, y1: int, speed: float) -> void:
	if _dunes == null:
		return
	var w := _dunes.get_width()
	var x := fposmod(_scroll * speed, float(w))
	var first := minf(float(w) - x, 640.0)
	_view.draw_texture_rect_region(_dunes, Rect2(0, y0, first, y1 - y0), Rect2(x, y0, first, y1 - y0))
	if first < 640.0:
		_view.draw_texture_rect_region(_dunes, Rect2(first, y0, 640.0 - first, y1 - y0), Rect2(0, y0, 640.0 - first, y1 - y0))

func _paint() -> void:
	_view.draw_rect(Rect2(0, 0, 640, 360), Color.BLACK)
	if _mode == &"walk":
		_band(0, SKY_END, 0.0)
		_band(SKY_END, DUNES_END, 0.35)
		_band(DUNES_END, 360, 1.0)
		# prints trailing away behind him out of frame, the newest under the foot that's just come down
		var steps := floori(_scroll / STEP_PX)
		var x := FOOT_X - fposmod(_scroll, STEP_PX)
		while x > -32.0:
			var foot := 1.0 if steps % 2 == 0 else -1.0
			var tex := Steps.stamp(WHO_ELVIS, Vector2.RIGHT, foot)
			var at := Vector2(roundf(x), FEET + SIDE_PX * foot)
			_view.draw_texture_rect(tex, Rect2(at - tex.get_size(), tex.get_size() * 2.0), false)
			_kick(at, (FOOT_X - x) / WALK_SPEED, steps)
			x -= STEP_PX
			steps -= 1
	elif _mode == &"far":
		if _wide:
			_view.draw_texture(_wide, Vector2.ZERO)
		if _haze > 0.0:
			_view.draw_rect(Rect2(250, 40, 330, 150), Color(0.75, 0.1, 0.06, snappedf(_haze, 0.0625)))
		var way := FAR_WAY.normalized()
		var along := FAR_WALK * _time_far()
		var ground_way := Vector2(FAR_WAY.x / Arena.TPM.x, FAR_WAY.y / Arena.TPM.y)    # its way over the ground, for the print to point along
		var n := floori(along / FAR_STEP)
		while true:    # a thin line of prints back to the edge of the frame, each staying where it fell
			var p := FAR_FROM + way * n * FAR_STEP + Vector2(-way.y, way.x) * (FAR_SIDE if n % 2 == 0 else -FAR_SIDE)
			if p.y > 368.0:
				break
			var tex := Steps.stamp(WHO_ELVIS, ground_way, 1.0 if n % 2 == 0 else -1.0, FAR_SIZE)
			_view.draw_texture(tex, (p - tex.get_size() / 2.0).round())
			n -= 1

func _paint_elvis() -> void:
	if _mode == &"walk" and _run_s:
		var f := int(fposmod(_scroll, STEP_PX * 2.0) / (STEP_PX * 2.0) * _run_s_frames)    # one clock with the ground, so they can't drift apart
		var size := _cell * 2.0
		(_elvis.material as ShaderMaterial).set_shader_parameter(&"sheet", _run_s)
		_elvis.draw_texture_rect_region(_run_s, Rect2(Vector2(270.0 - size.x / 2.0, FEET + 6.0 - size.y), size), Rect2(Vector2(f * _cell.x, 0.0), _cell))
	elif _mode == &"far" and _run_b:
		var f := int(_time * _run_b_frames / 0.7) % _run_b_frames
		var size := _cell / 2.0
		var at := FAR_FROM + FAR_WAY.normalized() * FAR_WALK * _time_far()
		(_elvis.material as ShaderMaterial).set_shader_parameter(&"sheet", _run_b)
		_elvis.draw_texture_rect_region(_run_b, Rect2(at - Vector2(size.x / 2.0, size.y), size), Rect2(Vector2(f * _cell.x, 0.0), _cell))

# The sand one step kicks up, thrown back from his way and falling: drawn from the print's own number, so the same each frame.
func _kick(at: Vector2, age: float, step: int) -> void:
	if age >= GRAIN_LIFE:
		return
	_grains.seed = step
	for i in GRAINS:
		var v := Vector2(_grains.randf_range(-150.0, -40.0), _grains.randf_range(-150.0, -60.0))
		var c: Color = GRAIN_COLOURS[_grains.randi() % GRAIN_COLOURS.size()]
		var p := at + v * age + Vector2(0.0, 420.0) * age * age
		if p.y <= at.y:
			_view.draw_rect(Rect2(p.snappedf(2.0), Vector2(2.0, 2.0)), c)

var _far_since := -1.0
func _time_far() -> float:
	if _far_since < 0.0:
		_far_since = _time
	return _time - _far_since
