extends TestCase
# Vulcan on his own (no arena: his cracks are skipped), driven by Health and HitInfo like Elvis's blows.

const VULCAN := preload("res://boss/vulcan.tscn")

func test_phase_two_at_half() -> void:
	var v: Vulcan = await _spawn()
	var count := _count(v.phase_two)
	v.health.take(v.health.max_hp * 0.5)
	check(count[0] == 1 and v.phase == 2, "phase_two once at 50%% (count %d, phase %d)" % [count[0], v.phase])
	v.health.take(10.0)
	check(count[0] == 1, "not again below half (count %d)" % count[0])
	check(v.sprite.speed_scale > 1.0, "his animations run faster (%s)" % v.sprite.speed_scale)

func test_kneel_not_die() -> void:
	var v: Vulcan = await _spawn()
	var count := _count(v.knelt)
	v.health.take(v.health.max_hp)
	await get_tree().physics_frame
	check(v.kneeling and count[0] == 1, "he kneels at 0 hp, knelt once (kneeling %s, count %d)" % [v.kneeling, count[0]])
	check(is_instance_valid(v) and not v.is_queued_for_deletion(), "and is still there")
	v.health.take(10.0)
	check(count[0] == 1, "knelt only once (count %d)" % count[0])

func test_light_on_kneel_does_nothing() -> void:
	var v: Vulcan = await _spawn()
	var count := _count(v.crown_struck)
	v.health.take(v.health.max_hp)
	for i in 3:
		v.take_hit(_blow(false))
	check(count[0] == 0, "light blows don't strike the crown (count %d)" % count[0])
	check(v.kneeling, "he still kneels")
	Fx.clear_all()    # the sparks

func test_heavy_on_kneel_strikes_crown_once() -> void:
	var v: Vulcan = await _spawn()
	var count := _count(v.crown_struck)
	v.health.take(v.health.max_hp)
	v.take_hit(_blow(true))
	v.take_hit(_blow(true))
	check(count[0] == 1, "crown_struck once from two heavy blows (count %d)" % count[0])

func test_reset_fight() -> void:
	var v: Vulcan = await _spawn()
	v.health.take(v.health.max_hp)
	v.reset_fight(Vector3(1.0, 0.0, 4.0))
	check(v.health.hp == v.health.max_hp and v.phase == 1 and v.brain.phase == 1, "full hp, phase 1 (hp %s, phase %d)" % [v.health.hp, v.phase])
	check(not v.kneeling and v.armed and v.awake, "not kneeling, awake, armed")
	check(v.global_position.is_equal_approx(Vector3(1.0, 0.0, 4.0)), "where he was put (%s)" % v.global_position)
	var count := _count(v.crown_struck)
	v.health.take(v.health.max_hp)
	v.take_hit(_blow(true))
	check(count[0] == 1, "the crown can be struck again after a reset (count %d)" % count[0])

# Beyond the plan: C1 awaits wake_scripted(); it must return with him off the plinth, awake and armed.
func test_wake_arms_him() -> void:
	var v: Vulcan = await _spawn()
	v.global_position = Vector3(0.0, Arena.PLINTH_H, 0.0)    # kneeling on the plinth
	v.set_statue(true)
	check(not v.awake and not v.armed, "the statue is asleep and unarmed")
	var woke := _count(v.woke)
	v.fast = true
	await v.wake_scripted()
	check(v.awake and v.armed and woke[0] == 1, "awake, armed, woke once (woke %d)" % woke[0])
	check(v.global_position.y == 0.0 and Vector2(v.global_position.x, v.global_position.z).length() > Arena.PLINTH, "down on the floor, off the plinth (%s)" % v.global_position)
	Fx.clear_all()

# Beyond the plan: with a foe 4 m off, the fight opens with the slam, whose fire blade hits him.
func test_opens_with_slam() -> void:
	var v: Vulcan = await _spawn()
	var foe := _foe(Vector3(0.0, 0.0, 4.0))
	v.start_fight(foe[0])
	var moves := {}
	for i in 240:
		await get_tree().physics_frame
		moves[v.move] = true
		if foe[1] > 0:
			break
	check(moves.has(&"slam") and not moves.has(&"spell"), "the slam first (moves %s)" % [moves.keys()])
	check(foe[1] == 1, "its blow landed once (%d)" % foe[1])
	Fx.clear_all()

# Beyond the plan: a sheet's "active" frames end his sword's hit, and a first frame past the sheet's end can't stall him in the wind-up.
func test_hit_frames() -> void:
	var v: Vulcan = await _spawn()
	v._begin(&"slash")
	v._window = Vector2i(0, 0)
	await get_tree().physics_frame
	check(v.mode == Vulcan.Mode.ACTIVE and v.hitbox.is_active(), "frame 0 is a hit frame: he strikes (mode %d)" % v.mode)
	v.sprite.frame = 1
	await get_tree().physics_frame
	check(v.mode == Vulcan.Mode.ACTIVE and not v.hitbox.is_active(), "past the last hit frame the sword stops hitting, the blow goes on (mode %d)" % v.mode)
	v._begin(&"slash")
	v._window = Vector2i(99, 99)
	var struck := false
	for i in 180:
		await get_tree().physics_frame
		struck = struck or v.mode == Vulcan.Mode.ACTIVE
		if v.move == &"":
			break
	check(struck and v.move == &"", "a first frame past the sheet still strikes, and the slash ends (mode %d)" % v.mode)

func _spawn() -> Vulcan:
	var v := VULCAN.instantiate() as Vulcan
	add_child(v)
	await get_tree().physics_frame
	v.reset_fight(Vector3.ZERO)
	return v

# A player-team target with a hurtbox at `at`: [node, hits].
func _foe(at: Vector3) -> Array:
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
	var out: Array = [hurt, 0]
	hurt.hurt.connect(func(_i: HitInfo) -> void: out[1] += 1)
	return out

func _blow(heavy: bool) -> HitInfo:
	var info := HitInfo.new()
	info.damage = 30.0 if heavy else 8.0
	info.poise = info.damage * (2.0 if heavy else 1.0)
	info.heavy = heavy
	info.at = Vector3(0.0, 0.9, 1.0)
	return info

func _count(s: Signal) -> Array[int]:
	var n: Array[int] = [0]
	s.connect(func() -> void: n[0] += 1)
	return n
