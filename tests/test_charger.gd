extends TestCase
# The charger: its line lies on the ground before it dashes, the dash hurts and runs straight, and a parry breaks it.

const ELVIS := preload("res://player/elvis.tscn")
const JACKAL := preload("res://enemy/jackal.tscn")
const CHARGER := preload("res://enemy/charger.gd")
const AT := Vector3(0.0, 0.0, 8.0)    # Elvis, facing north; the charger comes from the north

func test_the_line_comes_before_the_dash() -> void:
	var e := await _spawn()
	var j := _charger(AT + Vector3(0.0, 0.0, -4.0))
	j.wake(e)
	await _until(func() -> bool: return j.mode == Jackal.Mode.WINDUP, 1.0)
	check(j.mode == Jackal.Mode.WINDUP, "it pulls up to aim (mode %d)" % j.mode)
	check(_marked(), "a line on the ground")
	check(not j.hitbox.is_active(), "no danger yet")
	var was := j.global_position
	await _wait(CHARGER.WARN - 0.1)
	check(j.mode == Jackal.Mode.WINDUP and not j.hitbox.is_active(), "still only the warning (mode %d)" % j.mode)
	check(j.global_position.distance_to(was) < 0.01, "it hasn't moved (%s m)" % j.global_position.distance_to(was))
	check(e.health.hp == e.health.max_hp, "he isn't hurt (%s)" % e.health.hp)
	check(CHARGER.WARN - CHARGER.LINE_FORMS >= 0.5 - 0.001, "the whole line shows for half a second")
	var reach := ((j.hitbox.get_node("Shape") as CollisionShape3D).shape as SphereShape3D).radius
	check(CHARGER.LINE_WIDTH * (1.0 - 0.6 * CHARGER.STOP / (CHARGER.DASH_SPEED * CHARGER.DASH_TIME)) >= reach - 0.001, "the line is as wide as the dash where he stands (the strip tapers by 0.6: fx/ground_fire.gdshader)")
	await _until(func() -> bool: return j.mode == Jackal.Mode.BITE, 0.5)
	check(j.mode == Jackal.Mode.BITE and j.hitbox.is_active(), "then the dash (mode %d)" % j.mode)
	check(not _marked(), "the line gone")
	await _settle()

func test_the_dash_hurts_and_does_not_turn() -> void:
	var e := await _spawn()
	var j := _charger(AT + Vector3(0.0, 0.0, -4.0))
	j.wake(e)
	await _until(func() -> bool: return j.mode == Jackal.Mode.RECOVER, 3.0)
	near(e.health.hp, e.health.max_hp - CHARGER.DASH_DAMAGE, 0.01, "the dash hits him where he stood")
	j.free()
	e.free()
	await _settle()
	e = await _spawn()
	j = _charger(AT + Vector3(0.0, 0.0, -4.0))
	j.wake(e)
	await _until(func() -> bool: return j.mode == Jackal.Mode.WINDUP, 1.0)
	var from := j.global_position
	e.global_position.x += 3.0    # off the line
	e.reset_physics_interpolation()
	await _until(func() -> bool: return j.mode == Jackal.Mode.RECOVER, 3.0)
	check(j.mode == Jackal.Mode.RECOVER, "the dash ends (mode %d)" % j.mode)
	near(j.global_position.x, from.x, 0.05, "it doesn't turn after him")
	near(j.global_position.z - from.z, CHARGER.DASH_SPEED * CHARGER.DASH_TIME, 0.4, "it runs the whole line")
	check(e.health.hp == e.health.max_hp, "a step aside is safe (%s)" % e.health.hp)
	await _wait(CHARGER.OPEN - 0.2)
	check(j.mode == Jackal.Mode.RECOVER and not j.hitbox.is_active(), "it stands open (mode %d)" % j.mode)
	var info := HitInfo.new()
	info.damage = 8.0
	info.at = e.global_position
	j.hurtbox.hurt.emit(info)
	near(j.health.hp, Jackal.HP - 8.0, 0.001, "and can be hit")
	await _settle()

func test_a_parried_dash_breaks_it() -> void:
	var e := await _spawn()
	var n := _count(e)
	var j := _charger(AT + Vector3(0.0, 0.0, -2.5))    # the blow lands about 0.1 s into the dash
	j.wake(e)
	await _until(func() -> bool: return j.mode == Jackal.Mode.BITE, 2.0)
	check(j.mode == Jackal.Mode.BITE, "it dashes (mode %d)" % j.mode)
	await _tap(&"parry")
	await _wait(0.3)
	check(n[0] == 1, "parried once (%d)" % n[0])
	check(e.health.hp == e.health.max_hp, "no damage (%s)" % e.health.hp)
	check(j.broken > 0.0 and not j.hitbox.is_active(), "it's broken, its dash off (broken %s)" % j.broken)
	check(not _marked(), "no line left")
	var was := j.global_position
	await _wait(0.5)
	check(j.global_position.distance_to(was) < 0.1, "it stands (%s m)" % j.global_position.distance_to(was))
	await _settle()

func _spawn() -> Elvis:
	if not has_node("Ground"):
		var ground := StaticBody3D.new()
		ground.name = "Ground"
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
	e.reset_to(AT)
	return e

func _charger(at: Vector3) -> Jackal:
	var j := JACKAL.instantiate() as Jackal
	j.set_script(CHARGER)    # before it enters the tree, as the road does
	add_child(j)
	j.global_position = at
	j.reset_physics_interpolation()
	return j

func _marked() -> bool:
	return Fx.get_children().any(func(n: Node) -> bool: return n is FxTelegraph and not n.is_queued_for_deletion())

func _count(e: Elvis) -> Array[int]:
	var n: Array[int] = [0]
	e.parried.connect(func(_i: HitInfo) -> void: n[0] += 1)
	return n

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

func _until(cond: Callable, cap_seconds: float) -> void:
	var t := 0.0
	while not cond.call() and t < cap_seconds:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()

# The hit-stops run out (real time) and the effects go, so the next test starts at full speed.
func _settle() -> void:
	await get_tree().create_timer(0.2, true, false, true).timeout
	Fx.clear_all()

func _exit_tree() -> void:
	Input.action_release(&"parry")
