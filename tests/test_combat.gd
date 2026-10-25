extends TestCase

const DUMMY := preload("res://combat/dummy.tscn")

func test_health_clamps_and_dies_once() -> void:
	var h := Health.new()
	add_child(h)
	var deaths: Array[int] = [0]
	h.died.connect(func() -> void: deaths[0] += 1)
	h.take(150.0)
	check(h.hp == 0.0, "hp clamps at 0 (got %s)" % h.hp)
	check(deaths[0] == 1, "died once (got %d)" % deaths[0])
	h.take(10.0)
	check(deaths[0] == 1, "a second take doesn't die again (got %d)" % deaths[0])

func test_stamina_refuses_at_zero() -> void:
	var s := Stamina.new()
	add_child(s)
	check(s.spend(100.0), "spend(100) of 100 is allowed")
	check(s.value == 0.0, "value 0 (got %s)" % s.value)
	check(not s.spend(1.0), "spend(1) at 0 is refused")
	check(s.value == 0.0, "value stays 0 (got %s)" % s.value)

# 1.6 s ticked by hand (no engine frames pass): the 0.6 s delay, then 1 s of regen.
func test_stamina_regen_triple_out_of_combat() -> void:
	for in_combat: bool in [true, false]:
		var s := Stamina.new()
		add_child(s)
		s.in_combat = in_combat
		s.spend(100.0)
		for i in 16:
			s._physics_process(0.1)
		near(s.value, 30.0 if in_combat else 90.0, 0.5, "regen in_combat=%s" % in_combat)

func test_flasks() -> void:
	var h := Health.new()
	add_child(h)
	h.take(60.0)
	var f := Flasks.new()
	add_child(f)
	check(f.drink_red(h), "a red flask is drunk")
	near(h.hp, 80.0, 1e-4, "red heals 40 of 100")
	check(f.red == 3, "3 red left (got %d)" % f.red)
	f.red = 0
	check(not f.drink_red(h), "no red left: refused")
	var s := Stamina.new()
	add_child(s)
	s.spend(70.0)
	check(f.drink_green(s) and s.value == s.max_value and f.green == 1, "green refills stamina")

func test_hitbox_hits_once_per_activation() -> void:
	var hit := Hitbox.new()
	hit.team = Hitbox.TEAM_PLAYER
	hit.add_child(_sphere(0.5))
	add_child(hit)
	var hurt := Hurtbox.new()
	hurt.team = Hitbox.TEAM_BOSS
	hurt.add_child(_sphere(0.5))
	add_child(hurt)
	var landed: Array[int] = [0]
	var hurts: Array[int] = [0]
	hit.landed.connect(func(_t: Hurtbox, _i: HitInfo) -> void: landed[0] += 1)
	hurt.hurt.connect(func(_i: HitInfo) -> void: hurts[0] += 1)
	for i in 2:
		await get_tree().physics_frame    # let the overlap register
	hit.activate(HitInfo.new(), 1.0)
	for i in 3:
		await get_tree().physics_frame
	check(landed[0] == 1, "landed once over 3 overlapping frames (got %d)" % landed[0])
	check(hurts[0] == 1, "the hurtbox heard it once (got %d)" % hurts[0])
	hit.activate(HitInfo.new(), 1.0)
	await get_tree().physics_frame
	check(landed[0] == 2, "a new activation hits again (got %d)" % landed[0])
	hit.deactivate()
	check(not hit.is_active(), "deactivated")

# Not scripted, the dummy's own _tick() plays "idle" every frame; play_once("walk") must still return (Task 2 review: it hung).
func test_play_once_returns_unscripted() -> void:
	var d := DUMMY.instantiate() as Actor
	add_child(d)
	await get_tree().physics_frame
	var done: Array[bool] = [false]
	var run := func() -> void:
		await d.play_once("walk")
		done[0] = true
	run.call()
	for i in 240:
		if done[0]:
			break
		await get_tree().physics_frame
	check(done[0], "play_once returned within 4 s")
	check(not d.scripted, "scripted is left as the caller had it")

func _sphere(r: float) -> CollisionShape3D:
	var c := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = r
	c.shape = s
	return c
