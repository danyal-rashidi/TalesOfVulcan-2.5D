extends TestCase
# The hills beside the road into Cinerea: where the ground is flat and where it isn't, and that everything on it stays on it.

const CINEREA := preload("res://game/cinerea.tscn")
const ON_THE_HILL := Vector3(-24.0, 0.0, -21.0)    # the south side of the big hill west of the tomb

func _town() -> Cinerea:
	Journey.reset()
	var c := CINEREA.instantiate() as Cinerea
	c.fast = true
	add_child(c)
	for i in 3000:
		if not c._busy:
			break
		await get_tree().process_frame
	return c

# Stands someone on the ground there, as the scene would.
func _put(a: Actor, at: Vector3) -> void:
	a.global_position = Vector3(at.x, Hills.height_at(at.x, at.z), at.z)
	a.reset_physics_interpolation()

func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func test_no_scene_but_cinerea_has_hills() -> void:
	await get_tree().process_frame    # the last test's town goes at the end of its frame
	check(not Hills.on, "off to begin with")
	check(Hills.height_at(ON_THE_HILL.x, ON_THE_HILL.z) == 0.0, "the colosseum's floor is flat, at the same x and z")
	check(Hills.lean(ON_THE_HILL.x, ON_THE_HILL.z) == Vector3.ZERO, "and nothing leans")

func test_where_the_ground_stays_flat() -> void:
	Hills.start()
	check(Hills.height_at(ON_THE_HILL.x, ON_THE_HILL.z) > 1.0, "there is a hill here (%s)" % Hills.height_at(ON_THE_HILL.x, ON_THE_HILL.z))
	var flat: Array[Rect2] = [Rect2(-5.0, -46.0, 10.0, 70.0),    # the road corridor
		Rect2(-70.0, 16.0, 140.0, 94.0),    # the town and its walls
		Rect2(-10.0, -2.0, 15.0, 7.0),      # Cassia's carriage, rolling from x -6.5, z 1 to the road
		Rect2(-17.0, 3.0, 12.0, 3.0),       # Fortuna coming from x -16
		Rect2(-9.0, -29.0, 6.0, 7.0)]       # the tomb's pit, and the jackal backing off from it
	for r in flat:
		for i in 60:
			for j in 60:
				var x := r.position.x + r.size.x * i / 59.0
				var z := r.position.y + r.size.y * j / 59.0
				if Hills.height_at(x, z) != 0.0:
					failures.append("%s isn't flat at %s, %s" % [r, x, z])
					Hills.stop()
					return
	for i in 48:    # the lake's shore
		var a := TAU * i / 48.0
		for grow: float in [1.0, 1.1, 1.2, 1.26]:
			near(Hills.height_at(Cinerea.LAKE_AT.x + cos(a) * Cinerea.LAKE_HALF.x * grow, Cinerea.LAKE_AT.y + sin(a) * Cinerea.LAKE_HALF.y * grow), 0.0, 0.0, "the lake's shore")
	var story: Array[Vector3] = [Cinerea.WAKE_AT, Cinerea.STORM_FROM, Cinerea.SHY_TO, TombScene.UP_TO, TombScene.KNEEL_AT, TombScene.PIT, LakeScene.WALK_FROM, LakeScene.WALK_TO, LakeScene.CARRIAGE_VIEW,
		CassiaScene.STAND_AT, CassiaScene.DOOR_AT, CassiaScene.OUT_TO, CassiaScene.STRONGBOX, CassiaScene.FORTUNA_FROM, CassiaScene.FORTUNA_TO]
	story.append_array(LakeScene.RAIDERS)
	for at in story:
		near(Hills.height_at(at.x, at.z), 0.0, 0.0, "the story's spot at %s" % at)
	Hills.stop()

func test_every_slope_can_be_walked() -> void:
	Hills.start()
	var steepest := 0.0
	var x := Hills.X0
	while x < -Hills.X0:
		var z := Hills.Z0
		while z < 16.0:
			steepest = maxf(steepest, Hills.slope(x, z).length())
			z += 0.25
		x += 0.25
	Hills.stop()
	check(steepest < tan(deg_to_rad(35.0)), "steepest is %.1f degrees" % rad_to_deg(atan(steepest)))
	check(steepest > tan(deg_to_rad(25.0)), "and they're real hills: %.1f degrees" % rad_to_deg(atan(steepest)))

func test_he_walks_over_a_hill_and_ends_on_the_ground() -> void:
	var c := await _town()
	var p := c.player
	_put(p, Vector3(-16.0, 0.0, -19.0))
	await _ticks(2)
	near(p.global_position.y, 0.0, 0.0, "on the flat")
	p.move_to(Vector3(-24.0, 0.0, -34.0), 6.0)
	var highest := 0.0
	while p._goal_speed > 0.0:
		await get_tree().physics_frame
		highest = maxf(highest, p.global_position.y)
		near(p.global_position.y, Hills.height_at(p.global_position.x, p.global_position.z), 0.001, "his feet stay on it")
	check(highest > 2.0, "it took him up (%s)" % highest)
	near(p.global_position.x, -24.0, 0.01, "he got there, x")
	near(p.global_position.z, -34.0, 0.01, "he got there, z")
	near(p.global_position.y, Hills.height_at(-24.0, -34.0), 0.001, "standing on the ground")
	p.move_to(Vector3(-16.0, 0.0, -19.0), 6.0)
	await p.arrived
	near(p.global_position.y, 0.0, 0.0, "back on the flat, exactly")
	near(p.global_position.x, -16.0, 0.01, "no drift, x")
	near(p.global_position.z, -19.0, 0.01, "no drift, z")
	c.queue_free()

func test_he_cant_walk_through_a_steep_face() -> void:
	var c := await _town()
	var p := c.player
	p.input_enabled = false
	for rock: Array in Cinerea.CRAGS:
		var inside: Vector2 = {"plateau2": Vector2(0.0, -1.7), "plateau": Vector2(0.0, -2.0), "rock_wall": Vector2(-0.8, -3.0)}[rock[0]]
		var mid := Vector3(rock[1] + inside.x, 0.0, rock[2] + inside.y)
		for a: float in [PI / 2.0, 0.0, PI]:    # from the south, the east and the west
			var from: Vector3 = mid + Vector3(cos(a), 0.0, sin(a)) * 9.0
			_put(p, from)
			await _ticks(1)
			p._goal = mid
			p._goal_speed = 8.0
			await _ticks(80)
			p._goal_speed = 0.0
			var q := PhysicsPointQueryParameters3D.new()
			q.position = mid + Vector3.UP
			check(not p.get_world_3d().direct_space_state.intersect_point(q, 1).is_empty(), "%s is solid in the middle" % rock[0])
			check(Vector2(p.global_position.x - mid.x, p.global_position.z - mid.z).length() > 0.5, "%s stopped him short of its middle, from %s" % [rock[0], from])
	c.queue_free()

# He hits it and it hits him: side on, it up the slope from him and it down the slope.
func test_blows_connect_on_a_slope() -> void:
	var c := await _town()
	var p := c.player
	p.set_weapon(true)
	Journey.add_item(&"iron_sword")
	Journey.toggle_equip(&"iron_sword")
	for way: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:    # the slope falls south here
		_put(p, ON_THE_HILL)
		var foe := c._jackal(Vector3.ZERO)
		_put(foe, ON_THE_HILL + Pixel.ground(way * 1.25))
		await _ticks(2)
		check(absf(Hills.slope(ON_THE_HILL.x, ON_THE_HILL.z).length()) > 0.25, "it really is a slope")
		p.facing = way
		p.spear_out = true
		var was := foe.health.hp
		p._press(&"attack_light")
		await _ticks(40)
		check(foe.health.hp < was, "his blow lands going %s" % way)
		var hurt := p.health.hp
		_put(foe, ON_THE_HILL + Pixel.ground(way * 1.2))
		foe.wake(p)
		await _ticks(90)
		check(p.health.hp < hurt or p.state == Elvis.State.HURT, "its bite lands, from the way he was facing %s" % way)
		p.health.reset()
		p._enter(Elvis.State.MOVE)
		foe.queue_free()
		await _ticks(2)
	c.queue_free()

func test_hammer_blow_reaches_down_the_slope() -> void:
	var c := await _town()
	var foe := c._jackal(Vector3.ZERO)
	_put(foe, ON_THE_HILL + Vector3(0.0, 0.0, 2.4))
	await _ticks(2)
	var was := foe.health.hp
	var info := HitInfo.new()
	info.damage = 5.0
	Fx.spawn(&"hammer_blow", Vector3(ON_THE_HILL.x, Hills.height_at(ON_THE_HILL.x, ON_THE_HILL.z), ON_THE_HILL.z), Vector3.ZERO, Hitbox.TEAM_PLAYER, info)
	await _ticks(4)
	check(foe.health.hp < was, "the blow hit it, at %s m lower" % (Hills.height_at(ON_THE_HILL.x, ON_THE_HILL.z) - foe.global_position.y))
	c.queue_free()

# On a slope too the hammer's head shows on screen just where it does on the flat, from his feet, and the blow is on the ground there.
func test_hammer_head_lands_on_the_slope() -> void:
	var c := await _town()
	var p := c.player
	_put(p, ON_THE_HILL)
	await _ticks(2)
	var pitch := deg_to_rad(Pixel.PITCH_DEG)
	for side: float in [1.0, -1.0]:
		var aim := Vector3(ON_THE_HILL.x + side * 1.0, 0.0, ON_THE_HILL.z - 0.5)
		var feet := FxHammerAura.feet_for(aim, side)
		var head := FxHammerAura.head_from(feet, side)
		near(head.x, aim.x, 0.06, "head on the aim, x")
		near(head.z, aim.z, 0.1, "head on the aim, z")
		near(head.y, Hills.height_at(head.x, head.z), 0.001, "on the ground")
		near((head.x - feet.x) * Pixel.PX, side * FxHammerAura.HIT.x, 1.0, "across the screen")
		var down := ((head.z - feet.z) * sin(pitch) - (head.y - feet.y) * cos(pitch)) * Pixel.PX
		near(down, FxHammerAura.HIT.y, 2.0, "down the screen, %s m of slope" % (head.y - feet.y))
	c.queue_free()

# Each texel of a print is one screen pixel on any slope: going along its x doesn't move it up or down the screen, and going along its z moves it one row a texel.
func test_prints_sit_on_the_ground() -> void:
	var c := await _town()
	var p := c.player
	_put(p, Vector3(-16.0, 0.0, -19.0))
	await _ticks(2)
	p.move_to(Vector3(-24.0, 0.0, -34.0), 3.0)
	await p.arrived
	var found := 0
	var pitch := deg_to_rad(Pixel.PITCH_DEG)
	for n in c.get_children():
		if n is Steps.FootPrint:
			var s := n as Steps.FootPrint
			var at := s.global_position
			if at.y > 0.5:
				found += 1
			near(at.y, Hills.height_at(at.x, at.z) + Steps.GROUND, 0.02, "a print lies just over the ground at %s" % at)
			var b := s.global_transform.basis
			near(b.x.z * sin(pitch) - b.x.y * cos(pitch), 0.0, 1e-4, "along its x it stays on one row")
			near((b.z.z * sin(pitch) - b.z.y * cos(pitch)) * 32.0, 32.0 * sin(pitch) * 4.0 / 3.0, 1e-3, "along its z, a row a texel")
	check(found >= 3, "he left prints up on the hill, though his body is high (%d)" % found)
	c.queue_free()

func test_what_stands_by_the_road_stands_on_the_ground() -> void:
	var c := await _town()
	var solid := c.player.get_world_3d().direct_space_state
	await _ticks(1)
	for at: Vector2 in Cinerea.JACKALS + Cinerea.SCORPIONS:
		var q := PhysicsPointQueryParameters3D.new()
		q.position = Vector3(at.x, Hills.height_at(at.x, at.y) + 0.5, at.y)
		check(solid.intersect_point(q, 1).is_empty(), "a foe sleeps inside something at %s" % at)
	var y := 0.0
	for p: Array in Cinerea.ROADSIDE + Cinerea.CRAGS:
		var tex := Arena.prop_sprite(p[0], 0.0, 0.0)
		y = Hills.height_at(p[1], p[2])
		var half: float = tex.texture.get_width() / Pixel.PX / 2.0
		if p[0] not in Cinerea.THIN and p[0] not in Cinerea.WALK_OVER and p[0] != "rock_tan":
			for k: float in [-1.0, 0.0, 1.0]:
				near(Hills.height_at(p[1] + half * k, p[2]), 0.0, 0.0, "%s is wide: it needs flat ground" % p[0])
		var stood := Arena.prop_sprite(p[0], p[1], p[2])
		near(stood.position.y - tex.position.y - Hills.lean(p[1], p[2]).y, y, 1e-5, "%s stands on the ground, however high" % p[0])
		tex.free()
		stood.free()
	c._scatter()
	await _ticks(2)
	for f in c._sleepers:
		near(f.global_position.y, Hills.height_at(f.global_position.x, f.global_position.z), 0.001, "%s stands on the ground" % f.name)
	c.queue_free()

func test_aiming_and_landing_go_by_the_ground() -> void:
	var c := await _town()
	var p := c.player
	var a := deg_to_rad(Pixel.PITCH_DEG)
	var h := Hills.height_at(ON_THE_HILL.x, ON_THE_HILL.z)
	var spot := Vector3(ON_THE_HILL.x, h, ON_THE_HILL.z)
	var back := Vector3(0.0, sin(a), cos(a))
	var hit := Hills.on_ray(spot + back * 30.0, -back)
	near(hit.x, spot.x, 0.01, "the line from the camera finds the ground it shows, x")
	near(hit.z, spot.z, 0.1, "z")
	near(hit.y, h, 0.1, "height")
	_put(p, Vector3(-20.0, 0.0, -18.0))
	await _ticks(2)
	var at := p._landing(ON_THE_HILL)
	near(at.y, h, 0.05, "he comes down on the ground up there")
	var rock: Array = Cinerea.CRAGS[3]
	_put(p, Vector3(rock[1], 0.0, rock[2] + 3.0))
	await _ticks(2)
	at = p._landing(Vector3(rock[1], 0.0, rock[2] - 1.5))
	check(at.z > rock[2] - 0.5, "aimed into the rock, he comes down short of it (%s)" % at)
	c.queue_free()

func test_a_mark_lies_over_the_hill() -> void:
	var c := await _town()
	var m := MeshInstance3D.new()
	c.add_child(m)
	m.global_position = ON_THE_HILL
	Hills.drape(m, Vector2(6.0, 6.0), 0.03)
	var faces := m.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
	check(faces.size() > 100, "it's a grid")
	for v in faces:
		var w := m.global_transform * v
		near(w.y, Hills.height_at(w.x, w.z) + 0.03, 1e-3, "each point on the ground")
	c.queue_free()

func test_something_up_a_hill_is_still_on_the_screen_grid() -> void:
	var a := deg_to_rad(Pixel.PITCH_DEG)
	for p: Vector3 in [Vector3(0.0, 0.0, 0.03), Vector3(1.01, 1.37, -4.2), Vector3(-7.7, 3.61, 12.34)]:
		var q := Pixel.snap(p)
		var row := (q.z * sin(a) - q.y * cos(a)) * Pixel.PX
		near(fposmod(row + 0.5, 1.0), 0.5, 1e-3, "%s lands on a whole row" % p)
		check(q.is_equal_approx(Pixel.snap(q)), "and stays put when snapped again")
