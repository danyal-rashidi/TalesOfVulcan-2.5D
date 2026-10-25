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

func test_mash_attack() -> void:
	var e: Elvis = await _spawn()
	var top := 0
	var low := e.stamina.value
	for i in 20:    # 20 presses in 60 frames = 1 s
		Input.action_press(&"attack_light")
		for f in 3:
			await get_tree().physics_frame
			if f == 0:
				Input.action_release(&"attack_light")
			top = maxi(top, e.combo_index)
			low = minf(low, e.stamina.value)
	check(top >= 2, "the presses chained into a combo (top combo_index %d)" % top)
	var t := 0.0
	while e.state != Elvis.State.MOVE and t < 2.5:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		top = maxi(top, e.combo_index)
		low = minf(low, e.stamina.value)
	check(top <= Elvis.COMBO_MAX, "combo_index never above 4 (got %d)" % top)
	check(low >= 0.0, "stamina never below 0 (got %s)" % low)
	check(e.state == Elvis.State.MOVE, "back to MOVE within 2.5 s of the last press (state %s after %.2f s)" % [e.state, t])

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
