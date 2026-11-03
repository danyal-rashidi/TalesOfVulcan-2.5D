extends TestCase
# The prologue's opening, and the crossing it leads to.

const OPENING := preload("res://game/opening.tscn")
const GAME := preload("res://game/game.tscn")

func test_the_opening_plays_through_to_the_crossing() -> void:
	Game.crossing = false
	var o := OPENING.instantiate() as Opening
	o.fast = true
	add_child(o)
	var said: Array[String] = []
	var until := Time.get_ticks_msec() + 15000
	while not Game.crossing and Time.get_ticks_msec() < until:
		await get_tree().process_frame
		if o.hud and o.hud.last_line != "" and not o.hud.last_line in said:
			said.append(o.hud.last_line)
	check(Game.crossing, "it ends by sending him out to walk")
	check(said.size() == 1 + Opening.LINES_WALK.size() + Opening.LINES_FAR.size(), "his voice says all of it (%s)" % [said])
	check(said[0] == "Three days since the last well." and said[-1] == "But somebody has to wake him.", "first and last")
	Game.crossing = false
	o.queue_free()
	await get_tree().process_frame

func test_the_crossing_comes_before_the_fight() -> void:
	Game.crossing = true
	var g := GAME.instantiate() as Game
	g.fast = true
	add_child(g)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(not Game.crossing, "only the once")
	check(g.elvis.global_position.z > Arena.RADIUS + 20.0, "he starts out in the desert (%s)" % g.elvis.global_position)
	check(g.flow == Game.Flow.ENTER and not g.elvis.spear_out, "nothing has woken, and his spear's on his back")
	check(g.hud._hint.contains("walk"), "it says how to walk (%s)" % g.hud._hint)
	check(g.find_children("*", "Grass", true, false).size() == 1, "there's grass in the wind")
	g.queue_free()
	await get_tree().process_frame

# From the crossing's start with nothing but the keys: the breach takes him in, the statue wakes, and the wall holds him in for the fight.
func test_he_walks_in_by_the_breach_and_the_statue_wakes() -> void:
	var g := _crossing()
	await get_tree().physics_frame
	Input.action_press(&"move_up")
	var until := Time.get_ticks_msec() + 15000
	while g.flow != Game.Flow.FIGHT and Time.get_ticks_msec() < until:
		await get_tree().physics_frame
	Input.action_release(&"move_up")
	check(g.flow == Game.Flow.FIGHT, "the fight starts (flow %d, at %s)" % [g.flow, g.elvis.global_position])
	check(g.elvis.global_position.distance_to(g.arena.entrance()) < 0.5, "he's inside, where the fight starts (%s)" % g.elvis.global_position)
	check(g.elvis.input_enabled and g.elvis.spear_out, "he has control, and his spear")
	g.elvis.hurtbox.invulnerable = true
	Input.action_press(&"move_down")
	for i in 90:
		await get_tree().physics_frame
	Input.action_release(&"move_down")
	check(Vector2(g.elvis.global_position.x, g.elvis.global_position.z).length() < Arena.RADIUS, "and the wall stops him again (%s)" % g.elvis.global_position)
	Fx.clear_all()
	g.queue_free()
	await get_tree().process_frame

# Only the breach is a way in: the wall beside it stops him, and following it brings him round to the breach.
func test_the_wall_beside_the_breach_is_still_a_wall() -> void:
	var g := _crossing()
	await get_tree().physics_frame
	g.elvis.global_position = Vector3(6.0, 0.0, 13.0)
	Input.action_press(&"move_up")
	for i in 60:
		await get_tree().physics_frame
	check(g.flow == Game.Flow.ENTER, "the wall is only a wall (flow %d, at %s)" % [g.flow, g.elvis.global_position])
	Input.action_release(&"move_up")
	Input.action_press(&"move_down")    # a step out from it, round the blocks that fell from it
	while g.elvis.global_position.z < 12.2:    # he coasts on to about 12.8: past them, and short of the south end of the strip
		await get_tree().physics_frame
	Input.action_release(&"move_down")
	Input.action_press(&"move_left")
	var until := Time.get_ticks_msec() + 5000
	while g.flow == Game.Flow.ENTER and Time.get_ticks_msec() < until:
		await get_tree().physics_frame
	check(g.flow != Game.Flow.ENTER, "along it to the breach (at %s)" % g.elvis.global_position)
	Input.action_release(&"move_left")
	g.queue_free()
	await get_tree().process_frame

# Objects stop him where they stand in the picture: all of the gap the wall is drawn down over takes him in, and either side of it he stops.
func test_the_breach_is_the_whole_gap_in_the_picture() -> void:
	var g := _crossing()
	await get_tree().physics_frame
	for i in Arena.SEGMENTS:
		var a := TAU * (i + 0.5) / Arena.SEGMENTS
		if absf(wrapf(a, -PI, PI)) > deg_to_rad(159.0):    # the south wall, up to the first piece standing on each side
			var x := sin(a) * (Arena.RADIUS + Arena.WALL)
			check((g.arena._wall_height(i) == 0.0) == (x > Game.BREACH.position.x and x < Game.BREACH.end.x), "piece %d at x %.2f, drawn %.2f high" % [i, x, g.arena._wall_height(i)])
	g.queue_free()
	await get_tree().process_frame
	for x: float in [-3.85, -3.0, -2.4, 2.3]:
		check(await _walks_up_at(x) != Game.Flow.ENTER, "the wall's down at x %.2f: he goes in" % x)
	for x: float in [-4.2, 2.6]:
		check(await _walks_up_at(x) == Game.Flow.ENTER, "the wall stands at x %.2f: he stops" % x)

# W held at x from just outside, long enough to reach the ring: what the flow is then.
func _walks_up_at(x: float) -> Game.Flow:
	var g := _crossing()
	await get_tree().physics_frame
	g.elvis.global_position = Vector3(x, 0.0, 14.0)
	Input.action_press(&"move_up")
	for i in 90:
		await get_tree().physics_frame
	Input.action_release(&"move_up")
	var flow := g.flow
	Fx.clear_all()
	g.queue_free()
	await get_tree().process_frame
	return flow

# Objects stop him where they stand in the picture, and the breach is full of them: from wherever it takes him, the walk in goes round every one, and gets there.
func test_the_walk_in_goes_round_the_rubble() -> void:
	var x := Game.BREACH.position.x + 0.05
	while x < Game.BREACH.end.x:
		await _walks_in_from(Vector3(x, 0.0, Game.BREACH.end.y - 0.13))    # up to the strip: as far in as the fastest tick, a roll's, takes him
		x += 0.25
	for z: float in [12.45, 12.7, 13.0]:    # along the wall from the west: the first, just south of the block that stops him further in
		await _walks_in_from(Vector3(Game.BREACH.position.x + 0.01, 0.0, z))
	for z: float in [12.08, 12.5, 13.0]:          # and from the east
		await _walks_in_from(Vector3(Game.BREACH.end.x - 0.01, 0.0, z))

const BLADE_REACH := 1.25    # m: how far his blade reaches from his middle, on his walk's sheets

# The real walk from there. Fast mode only speeds it along the same lines, so between ticks he's somewhere on the line from where he was.
func _walks_in_from(from: Vector3) -> void:
	var g := _crossing()
	await get_tree().physics_frame
	var e := g.elvis
	var feet: float = ((e.get_node("Body") as CollisionShape3D).shape as CapsuleShape3D).radius    # what stops him anywhere else
	e.global_position = from
	var blocks := _everything_standing(g.arena)
	var was := from
	var hit := ""
	var ticks := 0
	while e.global_position.distance_to(g.arena.entrance()) > 0.01 and ticks < 300:
		ticks += 1
		await get_tree().physics_frame
		for s in 14:
			var p := was.lerp(e.global_position, s / 13.0)
			for b: Vector4 in blocks:
				if hit == "" and _gap(p, b) < feet:
					hit = "from %s his feet go in the block at (%.2f, %.2f) at %s" % [from, b.x, b.y, p]
			var r := Vector2(p.x, p.z).length()
			if hit == "" and r > Arena.RADIUS and r < Arena.RADIUS + Arena.WALL and g.arena._wall_height(_piece(p)) > 0.0:
				hit = "from %s he goes through the drawn wall at %s" % [from, p]
			for side: float in [-BLADE_REACH, BLADE_REACH]:    # nor does his blade, held out to the side
				var tip := p + Vector3(side, 0.0, 0.0)
				var tip_r := Vector2(tip.x, tip.z).length()
				if hit == "" and p.z < Arena.RADIUS + Arena.WALL and tip_r > Arena.RADIUS and tip_r < Arena.RADIUS + Arena.WALL and g.arena._wall_height(_piece(tip)) > 0.0:
					hit = "from %s his blade goes in the drawn wall at %s, with him at %s" % [from, tip, p]
		was = e.global_position
	check(hit == "", hit)
	check(e.global_position.distance_to(g.arena.entrance()) <= 0.01, "from %s he gets there (at %s, flow %d)" % [from, e.global_position, g.flow])
	await get_tree().physics_frame
	await get_tree().physics_frame    # his own tick has drawn him standing
	check(e.sprite.current_key.ends_with("_B"), "from %s he stands with his back to us, at the statue (%s)" % [from, e.sprite.current_key])
	Fx.clear_all()
	g.queue_free()
	await get_tree().process_frame

# He doesn't walk into the blocks outside the wall either, on the way to the breach. They stop him where they stand.
func test_the_blocks_outside_the_wall_stop_him() -> void:
	var g := _crossing()
	await get_tree().physics_frame
	var e := g.elvis
	var feet: float = ((e.get_node("Body") as CollisionShape3D).shape as CapsuleShape3D).radius
	var blocks := _everything_standing(g.arena)
	var tried := 0
	Input.action_press(&"move_up")
	for b: Vector4 in g.arena._rubble():
		var from := Vector3(b.x, 0.0, b.y + b.z + feet + 0.3)
		if b.y < 0.0 or Vector2(from.x, from.z).length() < Arena.RADIUS + Arena.WALL + feet or from.x > Game.BREACH.position.x - 0.5 and from.x < Game.BREACH.end.x + 0.5 or blocks.any(func(o: Vector4) -> bool: return _gap(from, o) < feet):
			continue    # the side of it he could come up from on foot, beside the breach
		tried += 1
		e.global_position = from
		e.reset_physics_interpolation()
		for i in 20:
			await get_tree().physics_frame
			for o: Vector4 in blocks:
				check(_gap(e.global_position, o) > feet - 0.03, "from %s his feet stay out of the block at (%.2f, %.2f), at %s" % [from, o.x, o.y, e.global_position])
	Input.action_release(&"move_up")
	check(tried >= 4, "blocks to walk into (%d)" % tried)
	check(g.flow == Game.Flow.ENTER, "beside the breach all the time (flow %d)" % g.flow)
	g.queue_free()
	await get_tree().process_frame

# From anywhere on the floor, the two ways out in the C3 keep their feet off everything, and inside the gaps of the drawn wall.
func test_the_ways_out_go_round_everything() -> void:
	var g := _crossing()
	await get_tree().physics_frame
	var a := g.arena
	var blocks := _everything_standing(a)
	var out_by := {"breach": [[a.entrance(), Vector3(0.0, 0.0, Arena.RADIUS + 6.0)], ((g.vulcan.get_node("Body") as CollisionShape3D).shape as CapsuleShape3D).radius],
		"gate": [[a.gate(), a.gate() - Vector3(0.0, 0.0, 4.0)], ((g.elvis.get_node("Body") as CollisionShape3D).shape as CapsuleShape3D).radius]}
	for x in range(-10, 11):
		for z in range(-10, 11):
			var from := Vector3(x, 0.0, z)
			if from.length() > Arena.RADIUS - 0.5:
				continue
			for by: String in out_by:
				var points: Array[Vector3] = []
				points.assign(out_by[by][0])
				var feet: float = out_by[by][1]
				var way := a.way(from, points, feet)
				check(way[-1].is_equal_approx(points[-1]), "from %s out by the %s he gets there (%s)" % [from, by, way[-1]])
				var starts_near: Array[Vector4] = blocks.filter(func(b: Vector4) -> bool: return _gap(from, b) < feet * 1.5)    # way() lets him out of a block's margin, square at the corners
				var was := from
				for p: Vector3 in way:
					for s in 41:
						var q := was.lerp(p, s / 40.0)
						for b: Vector4 in blocks:
							if not b in starts_near and _gap(q, b) < feet - 0.001:
								check(false, "from %s out by the %s his feet go in the block at (%.2f, %.2f) at %s" % [from, by, b.x, b.y, q])
						var r := Vector2(q.x, q.z).length()
						if by == "breach" and r > Arena.RADIUS and r < Arena.RADIUS + Arena.WALL:
							check(a._wall_height(_piece(q)) == 0.0, "from %s out by the breach he crosses the wall where it's down, not at %s" % [from, q])
					was = p
	g.queue_free()
	await get_tree().process_frame

# The real C3 from where the review saw it go wrong: north of the plinth, beside the rubble, south of the plinth for Elvis. Neither walks through anything.
func test_the_exits_walk_round_everything() -> void:
	for kneel: Vector3 in [Vector3(0.5, 0.0, -4.5), Vector3(-2.0, 0.0, 8.0), Vector3(0.0, 0.0, 7.0), Vector3(1.0, 0.0, 6.0)]:
		var g := GAME.instantiate() as Game
		g.fast = true
		add_child(g)
		var until := Time.get_ticks_msec() + 5000
		while g.flow != Game.Flow.FIGHT and Time.get_ticks_msec() < until:
			await get_tree().physics_frame
		g.vulcan.global_position = kneel
		g.elvis.global_position = kneel + Vector3(-1.0, 0.0, 0.6)
		g.vulcan.health.take(g.vulcan.health.max_hp)
		await get_tree().physics_frame
		var heavy := HitInfo.new()
		heavy.damage = 30.0
		heavy.heavy = true
		heavy.source = g.elvis
		heavy.at = g.vulcan.global_position + Vector3.UP
		g.vulcan.take_hit(heavy)
		var blocks := _everything_standing(g.arena)
		var hit := ""
		var walked := {}
		var was := {g.elvis: g.elvis.global_position, g.vulcan: g.vulcan.global_position}
		until = Time.get_ticks_msec() + 15000
		while g.flow != Game.Flow.END and Time.get_ticks_msec() < until:
			await get_tree().physics_frame
			for who: Actor in was:
				var feet: float = ((who.get_node("Body") as CollisionShape3D).shape as CapsuleShape3D).radius
				if who._goal_speed > 0.0:    # a walk, not the recoil
					walked[who] = true
					for s in 14:
						var p: Vector3 = was[who].lerp(who.global_position, s / 13.0)
						for b: Vector4 in blocks:
							if hit == "" and _gap(p, b) < feet - 0.05 and _gap(kneel, b) >= feet:
								hit = "kneeling at %s, %s goes in the block at (%.2f, %.2f) at %s" % [kneel, who.name, b.x, b.y, p]
				was[who] = who.global_position
		check(hit == "", hit)
		check(g.flow == Game.Flow.END and walked.size() == 2, "kneeling at %s the C3 ends with both of them walked (flow %d, %d)" % [kneel, g.flow, walked.size()])
		Fx.clear_all()
		g.queue_free()
		await get_tree().process_frame

# All a cutscene walk has to go round, as way() takes it.
func _everything_standing(a: Arena) -> Array[Vector4]:
	var out := a._rubble()
	out.append_array(Arena.STUMPS)
	out.append(Vector4(0.0, 0.0, Arena.PLINTH, Arena.PLINTH_H))
	return out

# The wall piece a point on the ground is at.
func _piece(p: Vector3) -> int:
	return posmod(floori(fposmod(atan2(p.x, -p.z), TAU) / TAU * Arena.SEGMENTS), Arena.SEGMENTS)

# How far a point on the ground is from a block's footprint: 0 inside it.
func _gap(p: Vector3, b: Vector4) -> float:
	return Vector2(maxf(absf(p.x - b.x) - b.z, 0.0), maxf(absf(p.z - b.y) - b.z, 0.0)).length()

# The hint there teaches the roll, so he may well roll into the breach: it ends there, and doesn't carry him on after the walk.
func test_rolling_into_the_breach() -> void:
	var g := _crossing()
	await get_tree().physics_frame
	g.elvis.global_position = Vector3(0.0, 0.0, 14.0)
	Input.action_press(&"move_up")
	await get_tree().physics_frame
	Input.action_press(&"roll")
	await get_tree().physics_frame
	Input.action_release(&"roll")
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(g.elvis.state == Elvis.State.ROLL, "he's rolling (state %d)" % g.elvis.state)
	Input.action_release(&"move_up")
	var until := Time.get_ticks_msec() + 5000
	while g.flow != Game.Flow.FIGHT and Time.get_ticks_msec() < until:
		await get_tree().physics_frame
	check(g.flow == Game.Flow.FIGHT, "the fight starts (flow %d, at %s)" % [g.flow, g.elvis.global_position])
	check(g.elvis.global_position.distance_to(g.arena.entrance()) < 0.05 and g.elvis.state == Elvis.State.MOVE, "he ends where the walk does, on his feet (%s, state %d)" % [g.elvis.global_position, g.elvis.state])
	Fx.clear_all()
	g.queue_free()
	await get_tree().process_frame

func _crossing() -> Game:
	Game.crossing = true
	var g := GAME.instantiate() as Game
	g.fast = true
	add_child(g)
	return g
