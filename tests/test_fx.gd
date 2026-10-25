extends TestCase

const KINDS: Array[StringName] = [&"fire_blade", &"fireball", &"spell_circle", &"breath", &"dive_impact", &"lightning", &"statue_burst",
	&"flame_summon", &"crown_glow", &"crown_light", &"ash", &"sparks", &"dust", &"embers"]

func test_spawn_every_kind() -> void:
	for k in KINDS:
		check(Fx.spawn(k, Vector3(0.0, 1.0, 0.0), Vector3.FORWARD) != null, "spawn(%s) returns the effect" % k)
	check(Fx.count() == KINDS.size(), "count() sees every effect (got %d)" % Fx.count())
	await get_tree().physics_frame    # each one runs a frame before it is cleared
	Fx.clear_all()
	check(Fx.count() == 0, "count() is 0 after clear_all (got %d)" % Fx.count())

func test_fireball_speed() -> void:
	var f := Fx.spawn(&"fireball", Vector3(0.0, 1.0, 0.0), Vector3.RIGHT)
	var start := f.global_position
	await _wait(0.5)
	near(f.global_position.distance_to(start), 3.5, 0.3, "a fireball flies 3.5 m in 0.5 s")
	Fx.clear_all()

# Flies into a player hurtbox 2 m away: it hurts once and bursts (the burst leaves sparks behind).
func test_fireball_bursts_on_hurtbox() -> void:
	var hurts := _target(Vector3(2.0, 1.0, 0.0))
	var f := Fx.spawn(&"fireball", Vector3(0.0, 1.0, 0.0), Vector3.RIGHT)
	await _wait(0.6)
	check(hurts[0] == 1, "the hurtbox was hit once (got %d)" % hurts[0])
	check(not is_instance_valid(f) or f.is_queued_for_deletion(), "the fireball burst")
	Fx.clear_all()

# Standing in the fire for the whole breath: a burn every 0.3 s, 4 in 1.2 s.
func test_breath_ticks() -> void:
	var hurts := _target(Vector3(0.0, 0.0, -2.5))
	Fx.spawn(&"breath", Vector3.ZERO, Vector3.FORWARD)
	await _wait(1.4)
	check(hurts[0] == 4, "4 burns (got %d)" % hurts[0])
	check(Fx.count() == 0, "the breath is gone after 1.2 s (count %d)" % Fx.count())

# clear_all stops every blow at once, before the effects are freed (Vulcan kneels: nothing may hurt Elvis any more).
func test_clear_all_stops_hitboxes() -> void:
	var blade := Fx.spawn(&"fire_blade", Vector3.ZERO, Vector3.RIGHT) as FxEffect
	check(blade.hitbox.is_active(), "the blade's blow is live")
	Fx.clear_all()
	check(not blade.hitbox.is_active(), "and stopped by clear_all")

# A player hurtbox at `at`; returns its hit count, kept up to date.
func _target(at: Vector3) -> Array[int]:
	var hurt := Hurtbox.new()
	hurt.team = Hitbox.TEAM_PLAYER
	var c := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	c.shape = capsule
	c.position.y = 0.9
	hurt.add_child(c)
	hurt.position = at
	add_child(hurt)
	var hurts: Array[int] = [0]
	hurt.hurt.connect(func(_i: HitInfo) -> void: hurts[0] += 1)
	return hurts

func _wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds - 0.001:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
