extends TestCase
# Elvis on a flat StaticBody floor, run on real physics frames and driven through Input like a player.

const ELVIS := preload("res://player/elvis.tscn")
const DUMMY := preload("res://combat/dummy.tscn")
const ACTIONS: Array[StringName] = [&"equip", &"move_left", &"move_right", &"move_up", &"move_down", &"attack_light", &"attack_heavy", &"roll", &"lock_on", &"flask_red", &"flask_green"]

func test_roll_distance() -> void:
	var e: Elvis = await _spawn()
	var start := e.global_position
	await _tap(&"roll")
	await _wait(1.0)
	near((e.global_position - start).length(), 3.5, 0.15, "a roll carries him 3.5 m")
	check(e.state == Elvis.State.MOVE, "back to MOVE after the roll")

# With the spear put away he can't attack and pays nothing; R draws it again and he can.
func test_no_attacks_with_the_spear_away() -> void:
	var e: Elvis = await _spawn()
	check(e.spear_out, "he starts with it out")
	await _tap(&"equip")
	check(e.state == Elvis.State.EQUIP, "putting it away takes a moment (state %s)" % e.state)
	await _wait(Elvis.EQUIP_TIME + 0.1)
	check(not e.spear_out and e.state == Elvis.State.MOVE, "it's away, and he's free to move")
	var full := e.stamina.value
	for a: StringName in [&"attack_light", &"attack_heavy"]:
		await _tap(a)
		await _wait(0.3)
		check(e.state == Elvis.State.MOVE, "%s is refused (state %s)" % [a, e.state])
	check(e.stamina.value >= full, "and costs nothing (%s of %s)" % [e.stamina.value, full])
	await _tap(&"equip")
	await _wait(Elvis.EQUIP_TIME + 0.1)
	check(e.spear_out, "it's out again")
	await _tap(&"attack_light")
	await _wait(0.05)
	check(e.state == Elvis.State.LIGHT, "and he can attack (state %s)" % e.state)

# Moving while he drinks shows the walking drink at the same point of the drink; stopping brings the standing one back.
func test_drink_walks_when_he_moves() -> void:
	var e: Elvis = await _spawn()
	var tex := ImageTexture.create_from_image(Image.create(32, 4, false, Image.FORMAT_RGBA8))
	var anims := {"idle_spear_F": {"file": "_t.png", "frames": 1}}
	for k in ["drink_spear_F", "drink_walk_spear_F"]:
		anims[k] = {"file": "_t.png", "frames": 8, "fps": 12.0, "loop": false}
	CharacterSprite._textures["res://art/elvis_blue/_t.png"] = tex
	CharacterSprite._manifests["elvis_blue"] = {"cell": [4, 4], "anims": anims}
	e.sprite.load_character("elvis_blue")
	e.facing = Vector2.DOWN
	await _tap(&"flask_red")
	await _wait(0.6)
	check(e.sprite.current_key == "drink_spear_F", "standing still he drinks standing (%s)" % e.sprite.current_key)
	var at := e.sprite.frame
	Input.action_press(&"move_down")
	await _wait(0.1)
	check(e.sprite.current_key == "drink_walk_spear_F", "moving he drinks walking (%s)" % e.sprite.current_key)
	check(absi(e.sprite.frame - at) <= 1, "at the same point of the drink (frame %d, was %d)" % [e.sprite.frame, at])
	Input.action_release(&"move_down")
	await _wait(0.1)
	check(e.sprite.current_key == "drink_spear_F", "stopping brings it back (%s)" % e.sprite.current_key)
	CharacterSprite._manifests.erase("elvis_blue")
	CharacterSprite._textures.erase("res://art/elvis_blue/_t.png")

# Every spear attack carries him forward, whether the sheet names its hit frames or not.
func test_spear_attacks_lunge_forward() -> void:
	for a: String in Elvis.ATTACKS:
		check(float(Elvis.ATTACKS[a]["step"]) >= 1.0, "%s lunges at least 1 m" % a)
	var e: Elvis = await _spawn()
	e.facing = Vector2.RIGHT
	var start := e.global_position
	await _tap(&"attack_light")
	await _wait(0.8)
	near(e.global_position.x - start.x, float(Elvis.ATTACKS["light1"]["step"]) + 0.2, 0.25, "a swing with hit frames, side on, carries him forward (the step, then he brakes)")
	check(e.sprite.active_window("light1_S") != Vector2i(-1, -1), "the side swing names its hit frames")
	e.facing = Vector2.DOWN
	start = e.global_position
	await _tap(&"attack_light")
	await _wait(0.8)
	near(e.global_position.z - start.z, float(Elvis.ATTACKS["light1"]["step"]) + 0.2, 0.25, "a swing with no sheet for this view carries him forward too")

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

# 20 presses in 1 s. With no regen, three swings empty the bar and the fourth is refused, so "stamina >= 0" is tested at 0.
func test_mash_attack() -> void:
	var e: Elvis = await _spawn()
	e.stamina.regen_per_s = 0.0
	e.stamina.value = 3.0 * Elvis.LIGHT_COST
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
	var fake := "res://art/elvis_blue/_test_late.png"
	CharacterSprite._textures[fake] = ImageTexture.create_from_image(Image.create_empty(48, 8, false, Image.FORMAT_RGBA8))
	var anims := {"idle_F": {"file": "_test_late.png", "frames": 1}, "idle_S": {"file": "_test_late.png", "frames": 1}}
	for i in range(1, 5):
		anims["light%d_S" % i] = {"file": "_test_late.png", "frames": 6, "loop": false, "active": [4, 5]}
	CharacterSprite._manifests["elvis_blue"] = {"cell": [8, 8], "anims": anims}
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
	CharacterSprite._manifests.erase("elvis_blue")    # the real manifest loads again
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

# The lowest rubble is under his capsule's round bottom: it stops him as any block does, on the ground, so his footprints go on.
func test_a_low_block_stops_him_on_the_ground() -> void:
	var e: Elvis = await _spawn()
	var h := Pixel.STEP * 0.25
	var block := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, h, 0.6)
	shape.shape = box
	shape.position = Vector3(2.0, h / 2.0, 0.0)
	block.add_child(shape)
	add_child(block)
	Input.action_press(&"move_right")
	await _wait(1.5)
	Input.action_release(&"move_right")
	check(e.global_position.x < 1.7, "it stops him at its face (x %s)" % e.global_position.x)
	near(e.global_position.y, 0.0, 0.001, "and he hasn't ridden up it")
	var was := _prints()
	Input.action_press(&"move_left")
	await _wait(1.0)
	Input.action_release(&"move_left")
	check(_prints() >= was + 3, "walking off it he still leaves prints (%d, then %d)" % [was, _prints()])
	e.global_position.y = 1.0    # what the boss's dive and hop do, and hills will
	await get_tree().physics_frame
	near(e.global_position.y, 1.0, 0.001, "setting his height still moves him")

func _prints() -> int:
	return get_children().filter(func(n: Node) -> bool: return n is Steps.FootPrint).size()

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
