extends TestCase
# The spitter (a scorpion): a ring on the ground before its venom lands, the venom can't be parried, a roll clears it, and up close it still stings.

const ELVIS := preload("res://player/elvis.tscn")
const JACKAL := preload("res://enemy/jackal.tscn")
const SPITTER := preload("res://enemy/spitter.gd")
const VENOM := preload("res://enemy/venom.gd")
const AT := Vector3(0.0, 0.0, 8.0)    # Elvis; the spitter stands north of him

func test_the_ring_comes_before_the_glob_lands() -> void:
	var e := await _spawn()
	var s := await _spitter(e, 4.0)
	var ring := await _until_ring()
	check(ring != null, "a ring marks the landing")
	if ring == null:
		return
	check(ring.global_position.distance_to(e.global_position) < 0.1, "where he stands (%s m off)" % ring.global_position.distance_to(e.global_position))
	check(e.health.hp == e.health.max_hp, "and nothing has hurt him yet (%s)" % e.health.hp)
	check(VENOM.FLIGHT >= 0.5, "the warning lasts half a second or more (%s)" % VENOM.FLIGHT)
	await _wait(VENOM.FLIGHT - 0.15)
	check(e.health.hp == e.health.max_hp and _ring() != null, "still only the ring just before it lands (hp %s)" % e.health.hp)
	await _wait(0.4)
	near(e.health.hp, e.health.max_hp - VENOM.DAMAGE, 0.01, "then it lands on him")
	check(_ring() == null, "and the ring goes")
	near(s.global_position.distance_to(AT), 4.0, 0.2, "the spitter kept its distance")
	s.queue_free()
	await _settle()

func test_it_cannot_be_parried() -> void:
	var e := await _spawn()
	e.facing = Vector2.UP    # toward it: only the venom itself refuses the parry
	var s := await _spitter(e, 4.0)
	var n: Array[int] = [0]
	e.parried.connect(func(_i: HitInfo) -> void: n[0] += 1)
	check(await _until_ring() != null, "it spits")
	await _wait(VENOM.FLIGHT - 0.1)
	await _tap(&"parry")
	check(e.state == Elvis.State.PARRY, "he braces (state %d)" % e.state)
	await _wait(0.4)
	check(n[0] == 0, "no parry (%d)" % n[0])
	near(e.health.hp, e.health.max_hp - VENOM.DAMAGE, 0.01, "it lands all the same")
	s.queue_free()
	await _settle()

func test_a_roll_clears_it() -> void:
	var e := await _spawn()
	var s := await _spitter(e, 4.0)
	check(await _until_ring() != null, "it spits")
	await _wait(VENOM.FLIGHT - 0.3)
	await _tap(&"roll")    # no direction held: along his facing, south, away from it
	check(e.state == Elvis.State.ROLL, "he rolls (state %d)" % e.state)
	await _wait(0.6)
	check(_ring() == null, "it has landed")
	check(e.health.hp == e.health.max_hp, "and missed him (%s)" % e.health.hp)
	s.queue_free()
	await _settle()

func test_up_close_it_still_stings() -> void:
	var e := await _spawn()
	var s := await _spitter(e, 1.0)
	for i in 60:
		if s.mode == Jackal.Mode.WINDUP:
			break
		await get_tree().physics_frame
	check(s.mode == Jackal.Mode.WINDUP, "it goes to sting (mode %d)" % s.mode)
	await _wait(Jackal.WINDUP + Jackal.ACTIVE + 0.1)
	check(_ring() == null, "no venom this close")
	near(e.health.hp, e.health.max_hp - Jackal.DAMAGE, 0.01, "the sting lands")
	s.queue_free()
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

# Awake and after him, `north` m north of where he stands.
func _spitter(e: Elvis, north: float) -> Jackal:
	var s := JACKAL.instantiate() as Jackal
	s.set_script(SPITTER)
	s.position = AT + Vector3(0.0, 0.0, -north)
	add_child(s)
	await get_tree().physics_frame
	s.wake(e)
	return s

# The landing mark on the ground, while there is one.
func _ring() -> FxTelegraph:
	for c in Fx.get_children():
		if c is FxTelegraph and not c.is_queued_for_deletion():
			return c
	return null

func _until_ring() -> FxTelegraph:
	for i in 60:
		if _ring() != null:
			break
		await get_tree().physics_frame
	return _ring()

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

# The hit-stops run out (real time) and the effects go, so the next test starts at full speed.
func _settle() -> void:
	await get_tree().create_timer(0.2, true, false, true).timeout
	Fx.clear_all()

func _exit_tree() -> void:
	for a: StringName in [&"parry", &"roll"]:
		Input.action_release(a)
