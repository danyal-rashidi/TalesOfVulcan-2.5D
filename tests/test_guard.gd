extends TestCase
# The guard (a raider): blows from the front spark off him and fill his break bar; he bleeds from behind, after his own slash, and broken by a parry.

const ELVIS := preload("res://player/elvis.tscn")
const JACKAL := preload("res://enemy/jackal.tscn")
const GUARD := preload("res://enemy/guard.gd")
const AT := Vector3(0.0, 0.0, 8.0)    # Elvis; the guard stands 1 m in front of him (north)

func test_a_blow_from_the_front_bounces_off() -> void:
	var g := await _still_guard()
	g.hurtbox.hurt.emit(_hit(g, 1.0))
	check(g.health.hp == 40.0, "no damage (%s)" % g.health.hp)
	near(g.poise, GUARD.GUARD_POISE - 4.0, 0.001, "half the blow's poise goes on his break bar")
	check(g.poise_shown, "the bar shows")
	check(_fx(&"sparks") == 1, "sparks off his guard (%d)" % _fx(&"sparks"))
	check(_fx(&"number") == 0, "no number (%d)" % _fx(&"number"))
	await _settle()

func test_from_behind_he_bleeds() -> void:
	var g := await _still_guard()
	g.hurtbox.hurt.emit(_hit(g, -1.0))
	check(g.health.hp == 32.0, "the blow lands (%s)" % g.health.hp)
	check(_fx(&"number") == 1, "with its number (%d)" % _fx(&"number"))
	check(_fx(&"sparks") == 0, "and no sparks (%d)" % _fx(&"sparks"))
	await _settle()

func test_his_slash_warns_then_leaves_him_open() -> void:
	var g := await _guard(AT)
	var bait := Node3D.new()
	bait.position = AT + Vector3(0.0, 0.0, 1.0)
	add_child(bait)
	g.wake(bait)
	await _until(g, Jackal.Mode.WINDUP)
	check(g.mode == Jackal.Mode.WINDUP, "he goes to slash")
	g.hurtbox.hurt.emit(_hit(g, 1.0))
	check(g.health.hp == 40.0, "his guard is still up in the wind-up (%s)" % g.health.hp)
	var elapsed := 0.0
	while not g.hitbox.is_active() and elapsed < 2.0:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
	near(elapsed, GUARD.SLASH_WINDUP, 0.05, "the wind-up before the blow")
	check(GUARD.SLASH_WINDUP >= 0.5, "long enough to read (%s)" % GUARD.SLASH_WINDUP)
	await _until(g, Jackal.Mode.RECOVER)
	check(g.mode == Jackal.Mode.RECOVER, "then he recovers")
	g.hurtbox.hurt.emit(_hit(g, 1.0))
	check(g.health.hp == 32.0, "open from the front after his slash (%s)" % g.health.hp)
	await _settle()

func test_a_parry_of_his_slash_breaks_him() -> void:
	var e := await _spawn()
	var g := await _guard(AT + Vector3(0.0, 0.0, -1.0))
	var n: Array[int] = [0]
	e.parried.connect(func(_i: HitInfo) -> void: n[0] += 1)
	g.wake(e)
	await _until(g, Jackal.Mode.WINDUP)
	check(g.mode == Jackal.Mode.WINDUP, "he goes to slash")
	await _wait(GUARD.SLASH_WINDUP - 0.12)
	await _tap(&"parry")
	await _wait(0.3)
	check(n[0] == 1, "parried once (%d)" % n[0])
	check(e.health.hp == e.health.max_hp, "no damage (%s)" % e.health.hp)
	check(g.broken > 0.0 and not g.hitbox.is_active(), "he's broken, his slash off (broken %s)" % g.broken)
	var info := _hit(g, 1.0)
	info.source = e
	g.hurtbox.hurt.emit(info)
	near(g.health.hp, 40.0 - 8.0 * Actor.BREAK_DAMAGE, 0.001, "broken, a blow from the front lands, and harder")
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

func _guard(at: Vector3) -> Jackal:
	var g := JACKAL.instantiate() as Jackal
	g.set_script(GUARD)
	g.position = at
	add_child(g)
	await get_tree().physics_frame
	return g

# Awake, facing south (+z) and standing still, for blows fed by hand.
func _still_guard() -> Jackal:
	var g := await _guard(AT)
	var bait := Node3D.new()
	add_child(bait)
	g.facing = Vector2.DOWN
	g.wake(bait)
	g.scripted = true
	return g

# A light blow from 1 m off: side 1 in front of a guard facing south, -1 behind him.
func _hit(g: Jackal, side: float) -> HitInfo:
	var from := Node3D.new()
	from.position = g.position + Vector3(0.0, 0.0, side)
	add_child(from)
	var info := HitInfo.new()
	info.damage = 8.0
	info.poise = 8.0
	info.source = from
	info.at = from.position
	return info

func _fx(kind: StringName) -> int:
	return Fx.get_children().filter(func(c: Node) -> bool: return c.get_script() == Fx.KINDS[kind] and not c.is_queued_for_deletion()).size()

func _until(g: Jackal, mode: Jackal.Mode) -> void:
	for i in 120:
		if g.mode == mode:
			return
		await get_tree().physics_frame

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
	Input.action_release(&"parry")
