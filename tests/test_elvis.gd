extends TestCase
# Elvis on a flat StaticBody floor, run on real physics frames and driven through Input like a player.

const ELVIS := preload("res://player/elvis.tscn")
const DUMMY := preload("res://combat/dummy.tscn")
const ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down", &"attack_light", &"attack_heavy", &"roll", &"lock_on", &"flask_red", &"flask_green"]

func test_roll_distance() -> void:
	var e: Elvis = await _spawn()
	var start := e.global_position
	await _tap(&"roll")
	await _wait(1.0)
	near((e.global_position - start).length(), 3.5, 0.15, "a roll carries him 3.5 m")
	check(e.state == Elvis.State.MOVE, "back to MOVE after the roll")

func test_roll_iframes() -> void:
	var e: Elvis = await _spawn()
	await _tap(&"roll")
	await _wait(0.2)
	check(e.state == Elvis.State.ROLL and e.hurtbox.invulnerable, "invulnerable 0.2 s into the roll")
	await _wait(0.3)
	check(not e.hurtbox.invulnerable, "not invulnerable 0.5 s into the roll")

func test_accel_smooth() -> void:
	var e: Elvis = await _spawn()
	Input.action_press(&"move_right")
	await get_tree().physics_frame
	check(_speed(e) > 0.0 and _speed(e) < Elvis.RUN_SPEED, "after 1 frame he is still speeding up (got %s)" % _speed(e))
	await _wait(0.5)
	near(_speed(e), Elvis.RUN_SPEED, 0.1, "at run speed after 0.5 s")
	_release_all()

# 20 presses in 1 s. With no regen, three swings (45) empty the bar and the fourth is refused, so "stamina >= 0" is tested at 0.
func test_mash_attack() -> void:
	var e: Elvis = await _spawn()
	e.stamina.regen_per_s = 0.0
	e.stamina.value = 45.0
	var seen: Dictionary = await _taps(e, &"attack_light", 20, 2.5)
	check(seen["top"] == 3, "three swings chained, the fourth refused at 0 stamina (top combo_index %d)" % seen["top"])
	check(seen["low"] == 0.0, "stamina reached 0 and never went below (lowest %s)" % seen["low"])
	check(e.state == Elvis.State.MOVE, "back to MOVE within 2.5 s of the last press (state %s)" % e.state)

# 20 roll taps in 1 s from a bar of 30: two rolls, every later tap refused, back in MOVE once the second roll ends.
func test_mash_roll() -> void:
	var e: Elvis = await _spawn()
	e.stamina.regen_per_s = 0.0
	e.stamina.value = 30.0
	var seen: Dictionary = await _taps(e, &"roll", 20, Elvis.ROLL_TIME + Elvis.BUFFER)
	var states: Array = seen["states"]
	check(states.count(Elvis.State.ROLL) == 2, "two rolls, then refused at 0 stamina (states %s)" % [states])
	check(seen["low"] == 0.0, "stamina reached 0 and never went below (lowest %s)" % seen["low"])
	check(e.state == Elvis.State.MOVE, "back to MOVE after the last roll (state %s)" % e.state)

# At 0 stamina a roll, a light and a heavy are refused: he never leaves MOVE.
func test_zero_stamina_refuses() -> void:
	var e: Elvis = await _spawn()
	e.stamina.regen_per_s = 0.0
	e.stamina.value = 0.0
	for a: StringName in [&"roll", &"attack_light", &"attack_heavy"]:
		var seen: Dictionary = await _taps(e, a, 1, 0.5)
		check(seen["states"] == [Elvis.State.MOVE], "%s refused at 0 stamina (states %s)" % [a, seen["states"]])

# A press waits at most BUFFER s for its turn: one made as a roll starts is dropped, one made late in the roll is kept.
func test_buffer_expires() -> void:
	var e: Elvis = await _spawn()
	await _tap(&"roll")
	var early: Dictionary = await _taps(e, &"attack_light", 1, 1.0)    # waits 0.55 s for the roll to end
	var states: Array = early["states"]
	check(not states.has(Elvis.State.LIGHT) and states.back() == Elvis.State.MOVE, "an early press is dropped (states %s)" % [states])
	await _tap(&"roll")
	await _wait(0.3)
	var late: Dictionary = await _taps(e, &"attack_light", 1, 1.0)    # waits 0.25 s
	states = late["states"]
	check(states.has(Elvis.State.LIGHT), "a late press is kept (states %s)" % [states])

# Only one press is held: a heavy pressed after a light, both during a roll, replaces it.
func test_buffer_holds_one_press() -> void:
	var e: Elvis = await _spawn()
	await _tap(&"roll")
	await _wait(0.2)
	await _tap(&"attack_light")
	var seen: Dictionary = await _taps(e, &"attack_heavy", 1, 1.5)
	var states: Array = seen["states"]
	check(states.count(Elvis.State.LUNGE) == 1 and not states.has(Elvis.State.LIGHT), "one lunge and no light swing (states %s)" % [states])
	check(e.state == Elvis.State.MOVE, "back to MOVE (state %s)" % e.state)

# A sheet whose hit frames come after the cancel point (4-5 of 6): mashing must not cut a swing off before it hits.
# The manifest is faked in CharacterSprite's caches, so no art/ file is touched.
func test_mash_keeps_late_hits() -> void:
	var fake := "res://art/elvis/_test_late.png"
	CharacterSprite._textures[fake] = ImageTexture.create_from_image(Image.create_empty(48, 8, false, Image.FORMAT_RGBA8))
	var anims := {"idle_F": {"file": "_test_late.png", "frames": 1}, "idle_S": {"file": "_test_late.png", "frames": 1}}
	for i in range(1, 5):
		anims["light%d_S" % i] = {"file": "_test_late.png", "frames": 6, "loop": false, "active": [4, 5]}
	CharacterSprite._manifests["elvis"] = {"cell": [8, 8], "anims": anims}
	var e: Elvis = await _spawn()
	var d := DUMMY.instantiate() as Actor
	d.position = Vector3(1.4, 0, 0)
	add_child(d)
	e.facing = Vector2.RIGHT
	e.stamina.regen_per_s = 0.0    # so the stamina spent counts the swings
	var hits: Array[int] = [0]
	e.hitbox.landed.connect(func(_h: Hurtbox, _i: HitInfo) -> void: hits[0] += 1)
	await get_tree().physics_frame
	await _taps(e, &"attack_light", 20, 1.0)
	CharacterSprite._manifests.erase("elvis")    # the real manifest loads again
	CharacterSprite._textures.erase(fake)
	var swings := roundi((e.stamina.max_value - e.stamina.value) / Elvis.LIGHT_COST)
	check(swings >= 2, "the mash chained swings (%d)" % swings)
	check(hits[0] == swings, "every swing landed its hit (%d hits from %d swings)" % [hits[0], swings])

func test_deadzone() -> void:
	_stick(0.15)
	await get_tree().physics_frame
	@warning_ignore("static_called_on_instance")
	check(Controls.move_vector() == Vector2.ZERO, "a stick resting at 0.15 doesn't move")
	_stick(0.5)
	await get_tree().physics_frame
	@warning_ignore("static_called_on_instance")
	check(Controls.move_vector().x > 0.2, "a stick at 0.5 does (so the event reached Input)")
	_stick(0.0)

# Beyond the plan: a light hit lands on a target in front of him, once, for 8.
func test_light_hits_target() -> void:
	var e: Elvis = await _spawn()
	var d := DUMMY.instantiate() as Actor
	d.position = Vector3(1.4, 0, 0)
	add_child(d)
	e.facing = Vector2.RIGHT
	await get_tree().physics_frame
	await _tap(&"attack_light")
	await _wait(0.5)
	near(d.health.hp, d.health.max_hp - 8.0, 1e-3, "light 1 hits the target once for 8")

func _spawn() -> Elvis:
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 1, 60)
	shape.shape = box
	ground.add_child(shape)
	ground.position.y = -0.5
	add_child(ground)
	var e := ELVIS.instantiate() as Elvis
	add_child(e)
	await get_tree().physics_frame
	return e

func _tap(action: StringName) -> void:
	Input.action_press(action)
	await get_tree().physics_frame
	Input.action_release(action)
	await get_tree().physics_frame

# Taps `action` every 3rd physics frame, `taps` times (20 taps = 1 s), then watches `after` more seconds.
# Returns the states he went through in order (repeats folded), the lowest stamina and the highest combo_index seen.
func _taps(e: Elvis, action: StringName, taps: int, after: float) -> Dictionary:
	var seen := {"states": [e.state], "low": e.stamina.value, "top": e.combo_index}
	var states: Array = seen["states"]
	for f in taps * 3 + roundi(after * Engine.physics_ticks_per_second):
		if f < taps * 3 and f % 3 == 0:
			Input.action_press(action)
		elif f < taps * 3 and f % 3 == 1:
			Input.action_release(action)
		await get_tree().physics_frame
		if states.back() != e.state:
			states.append(e.state)
		seen["low"] = minf(seen["low"], e.stamina.value)
		seen["top"] = maxi(seen["top"], e.combo_index)
	return seen

func _wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds - 0.001:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()

func _speed(e: Elvis) -> float:
	return Vector2(e.velocity.x, e.velocity.z).length()

func _stick(x: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = 0
	ev.axis = JOY_AXIS_LEFT_X
	ev.axis_value = x
	Input.parse_input_event(ev)
	Input.flush_buffered_events()

func _release_all() -> void:
	for a in ACTIONS:
		Input.action_release(a)

func _exit_tree() -> void:
	_release_all()
