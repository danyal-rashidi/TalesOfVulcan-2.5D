extends TestCase
# Elvis's F: the slow on anyone, its colour, what it slows and how it ends; the cast, its timing, cooldown and interruption; F the only icon.

const ELVIS := preload("res://player/elvis.tscn")
const DUMMY := preload("res://combat/dummy.tscn")
const JACKAL := preload("res://enemy/jackal.tscn")
const VULCAN := preload("res://boss/vulcan.tscn")
const HUD := preload("res://ui/hud.tscn")

func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _seconds(s: float) -> void:
	await _ticks(roundi(s * Engine.physics_ticks_per_second))

func _frost(a: Actor) -> float:
	var f: Variant = a.sprite._mat.get_shader_parameter(&"frost")
	return 0.0 if f == null else f

func _chill(a: Actor, seconds := 4.0) -> void:
	var info := HitInfo.new()
	info.slow = seconds
	a.hurtbox.hurt.emit(info)

func _jackal(at: Vector3) -> Jackal:
	var j: Jackal = JACKAL.instantiate()
	add_child(j)
	j.global_position = at
	return j

func _vulcan(at: Vector3) -> Vulcan:
	var v: Vulcan = VULCAN.instantiate()
	add_child(v)
	v.set_statue(false)
	v.global_position = at
	return v

func test_the_slow_lasts_four_seconds_and_shows_as_long() -> void:
	var j := _jackal(Vector3.ZERO)
	await _ticks(1)
	check(_frost(j) == 0.0, "its own colour to begin with")
	_chill(j)
	check(_frost(j) == 1.0 and j.pace == Actor.SLOW_PACE and j.sprite.pace == Actor.SLOW_PACE, "slowed, and blue")
	await _seconds(3.9)
	check(_frost(j) == 1.0 and j.pace < 1.0, "still at 3.9 s")
	await _seconds(0.15)
	check(_frost(j) == 0.0 and j.pace == 1.0 and j.sprite.pace == 1.0 and j.slow_left == 0.0, "gone by 4.05 s (%s left)" % j.slow_left)
	j.queue_free()

func test_another_hit_refreshes_it_and_does_not_stack() -> void:
	var j := _jackal(Vector3.ZERO)
	await _ticks(1)
	_chill(j)
	await _seconds(3.0)
	_chill(j)
	near(j.slow_left, 4.0, 0.001, "back to 4 s, not 5")
	check(j.pace == Actor.SLOW_PACE, "and not slower")
	await _seconds(3.9)
	check(_frost(j) == 1.0, "counted from the second")
	await _seconds(0.15)
	check(_frost(j) == 0.0, "and it ends")
	j.queue_free()

func test_it_slows_the_legs_the_bite_and_the_sheet_together() -> void:
	var prey := Node3D.new()
	add_child(prey)
	prey.global_position = Vector3(20.0, 0.0, 0.0)
	var free := _jackal(Vector3(0.0, 0.0, 5.0))
	var slow := _jackal(Vector3(0.0, 0.0, -5.0))
	await _ticks(1)
	free.wake(prey)
	slow.wake(prey)
	_chill(slow)
	await _seconds(1.0)
	near(free.global_position.x, Jackal.SPEED, 0.3, "at its speed")
	near(slow.global_position.x, Jackal.SPEED * Actor.SLOW_PACE, 0.2, "half its speed")
	# the bite's wind-up takes twice as long, and its sheet stays with it
	prey.global_position = slow.global_position + Vector3(1.0, 0.0, 0.0)
	var t := 0
	while slow.mode != Jackal.Mode.BITE and t < 300:
		await _ticks(1)
		t += 1
	near(t / float(Engine.physics_ticks_per_second), Jackal.WINDUP / Actor.SLOW_PACE, 0.1, "the wind-up in time")
	var f := slow.sprite.frame
	check(slow.sprite.seconds_to_frame(f) <= Jackal.WINDUP + 0.1 and slow.sprite.seconds_to_frame(f + 1) >= Jackal.WINDUP - 0.1, "and the sheet has played only as far as the wind-up (frame %d)" % f)
	free.queue_free()
	slow.queue_free()
	prey.queue_free()

func test_vulcans_attack_runs_at_half_speed_and_a_push_still_slides_as_far() -> void:
	var prey := Node3D.new()
	add_child(prey)
	var v := _vulcan(Vector3(0.0, 0.0, -3.0))
	prey.global_position = Vector3(0.0, 0.0, 0.0)
	await _ticks(1)
	v.target = prey
	v._begin(&"slash")
	_chill(v)
	var t := 0
	while v.mode == Vulcan.Mode.WINDUP and t < 300:
		await _ticks(1)
		t += 1
	var want: float = VulcanMoves.MOVES[&"slash"]["windup"]
	check(t / float(Engine.physics_ticks_per_second) >= want / Actor.SLOW_PACE * 0.7, "slowed, the blow comes late (%d ticks)" % t)
	var j := _jackal(Vector3(10.0, 0.0, 10.0))
	await _ticks(1)
	_chill(j)
	var info := HitInfo.new()
	info.knockback = 1.0
	info.at = Vector3(9.0, 0.0, 10.0)
	info.blast = true
	j.take_hit(info)
	await _seconds(0.6)
	near(j.global_position.x, 11.0, 0.1, "1 m of push is 1 m")
	v.queue_free()
	j.queue_free()
	prey.queue_free()

func test_it_ends_cleanly_on_death_stun_phase_and_restart() -> void:
	var j := _jackal(Vector3.ZERO)
	await _ticks(1)
	_chill(j)
	j.health.take(j.health.max_hp)
	check(_frost(j) == 0.0 and j.pace == 1.0, "dead: its own colour to burn in")
	_chill(j)
	check(_frost(j) == 0.0, "the dead aren't slowed")
	var v := _vulcan(Vector3(5.0, 0.0, 0.0))
	await _ticks(1)
	_chill(v)
	v._flinch()
	check(v.pace < 1.0, "a stun doesn't end it")
	await _seconds(4.1)
	check(_frost(v) == 0.0 and v.pace == 1.0, "but it still ends in its own time")
	_chill(v)
	var blow := HitInfo.new()
	blow.damage = v.health.max_hp * 0.6
	blow.slow = 4.0
	v.hurtbox.hurt.emit(blow)
	check(v.phase == 2 and v.mode == Vulcan.Mode.ROAR and _frost(v) == 0.0 and v.pace == 1.0, "a blow into phase two: the roar throws it off")
	near(v.sprite.pace, 1.0, 0.0, "and his sheets are at his speed")
	check(v.sprite.speed_scale > 1.0, "phase two's own speed is still there")
	v.hurtbox.invulnerable = false
	_chill(v)
	v.reset_fight(Vector3(5.0, 0.0, 0.0))
	check(_frost(v) == 0.0 and v.pace == 1.0, "a restart clears it")
	_chill(v)
	v.health.take(v.health.max_hp)
	check(v.kneeling and _frost(v) == 0.0, "kneeling: clear")
	_chill(v)
	check(_frost(v) == 0.0, "and it can't be put on him kneeling")
	v.queue_free()

func _elvis(at := Vector3.ZERO) -> Elvis:
	var e: Elvis = ELVIS.instantiate()
	add_child(e)
	e.global_position = at
	return e

func _foe(at: Vector3) -> Actor:
	var d: Actor = DUMMY.instantiate()
	add_child(d)
	d.global_position = at
	return d

func test_f_casts_launches_at_two_seconds_and_cools_for_thirty() -> void:
	Journey.reset()
	var e := _elvis()
	var d := _foe(Vector3(6.0, 0.0, 0.0))
	d.health.max_hp = 1000.0
	d.health.reset()
	await _ticks(2)
	var stamina := e.stamina.value
	check(e.skill_on(&"ability_f") == Elvis.ICE_SKILL and e.skill_on(&"ability_q") == "", "only F, and it's the ice")
	e._use_ability(&"ability_f")
	check(e.state == Elvis.State.CAST, "F starts it at once")
	check(e.facing.x > 0.9, "he turns to whoever it's for")
	check(e.sprite.current_key == "ice_snap_S", "his own sheet (%s)" % e.sprite.current_key)
	near(e.sprite.seconds_to_frame(4), 1.7, 0.02, "the snap comes just before the launch")
	near(e.sprite.seconds_to_frame(12), float(Journey.ABILITIES[Elvis.ICE_SKILL]["time"]), 0.02, "the sheet fills the cast")
	check(e.ability_left(&"ability_f") == 0.0, "no cooling yet")
	await _seconds(1.0)
	var v := e._volley
	check(v._circles.size() == 6, "the big circle and 5 small (%d)" % v._circles.size())
	check(v._spears.size() == 5, "5 spears (%d)" % v._spears.size())
	check(v._spears[0]._spr.frame / FxIceSpear.ANGLES == FxIceSpear.FROST, "in frost")
	await _seconds(0.98)
	check(not e._launched and v._snapped_at > 0.0, "he's snapped it, they haven't gone")
	check(v._spears[0]._lit_at >= 0.0, "and the icicles have reached the first")
	await _seconds(0.05)
	check(e._launched, "launched by 2.03 s")
	near(e.ability_left(&"ability_f"), 30.0, 0.1, "30 s of cooling")
	near(e.stamina.value, stamina - 30.0, 3.0, "and it's paid for now")
	var hp := d.health.hp
	await _seconds(2.0)
	near(hp - d.health.hp, 40.0, 0.01, "all five land, for Hammer Blow's 40")
	check(d.pace == Actor.SLOW_PACE and _frost(d) == 1.0, "and slow it")
	check(e.state == Elvis.State.MOVE, "his sheet is done and he's back")
	check(e.sprite.current_key.begins_with("idle_spear") or e.sprite.current_key.begins_with("run_spear"), "with his spear whole (%s)" % e.sprite.current_key)
	e._use_ability(&"ability_f")
	check(e.state == Elvis.State.MOVE, "not while it cools")
	e._clock += 30.0
	e._use_ability(&"ability_f")
	check(e.state == Elvis.State.CAST, "ready again")
	e._enter(Elvis.State.MOVE)
	e.queue_free()
	d.queue_free()
	Fx.clear_all()

func test_nobody_to_hit_costs_nothing() -> void:
	var e := _elvis()
	var v := _vulcan(Vector3(4.0, 0.0, 0.0))
	await _ticks(2)
	v.set_statue(true)
	e._use_ability(&"ability_f")
	check(e.state == Elvis.State.MOVE and e.ability_left(&"ability_f") == 0.0, "the statue can't be hit")
	var far := _foe(Vector3(Elvis.LOCK_RANGE + 2.0, 0.0, 0.0))
	await _ticks(2)
	e._use_ability(&"ability_f")
	check(e.state == Elvis.State.MOVE, "nor anything out of reach")
	e.queue_free()
	v.queue_free()
	far.queue_free()

func test_a_hit_or_a_roll_stops_the_cast_and_breaks_the_spears_for_free() -> void:
	var e := _elvis()
	var d := _foe(Vector3(6.0, 0.0, 0.0))
	await _ticks(2)
	var stamina := e.stamina.value
	e._use_ability(&"ability_f")
	await _seconds(1.0)
	var spears := e._volley._spears.duplicate()
	var blow := HitInfo.new()
	blow.damage = 1.0
	blow.knockback = 0.5
	blow.at = Vector3(1.0, 0.0, 0.0)
	blow.source = d
	e.take_hit(blow)
	check(e.state == Elvis.State.HURT, "knocked out of it")
	await _ticks(2)
	check(spears.all(func(s: Variant) -> bool: return not is_instance_valid(s) or s.is_queued_for_deletion()), "they break")
	check(e.ability_left(&"ability_f") == 0.0, "no cooldown")
	near(e.stamina.value, stamina, 0.01, "no stamina")
	check(d.health.ratio() == 1.0, "and no harm")
	await _seconds(0.45)
	e._use_ability(&"ability_f")
	check(e.state == Elvis.State.CAST, "he can start again")
	e._press(&"roll")
	await _ticks(2)
	check(e.state == Elvis.State.ROLL, "a roll gets him out")
	e._enter(Elvis.State.MOVE)
	await _ticks(2)
	e.queue_free()
	d.queue_free()
	Fx.clear_all()

func test_spears_go_after_a_moving_target_and_splash_if_it_cannot_be_hit() -> void:
	var e := _elvis()
	var d := _foe(Vector3(6.0, 0.0, 0.0))
	await _ticks(2)
	var at := Vector3(0.0, FxIceVolley.STAND_AT, 2.0)
	var info := HitInfo.new()
	info.slow = 4.0
	info.damage = 8.0
	var s := Fx.spawn(&"ice_spear", at, Vector3.ZERO, Hitbox.TEAM_PLAYER, info) as FxIceSpear
	s.stands_for(e, 0.0)
	s.launch(d, 0.0)
	await _ticks(10)
	d.global_position = Vector3(-6.0, 0.0, 6.0)    # right round the other side
	var t := 0
	while is_instance_valid(s) and t < 180:
		await _ticks(1)
		t += 1
	check(not is_instance_valid(s), "it reached it (%d ticks)" % t)
	check(d.health.hp == d.health.max_hp - 8.0 and d.pace < 1.0, "it hit it where it went")
	d.hurtbox.invulnerable = true
	d.health.reset()
	var ghost := Fx.spawn(&"ice_spear", at, Vector3.ZERO, Hitbox.TEAM_PLAYER, info) as FxIceSpear
	ghost.stands_for(e, 0.0)
	ghost.launch(d, 0.0)
	t = 0
	while is_instance_valid(ghost) and t < 180:
		await _ticks(1)
		t += 1
	check(not is_instance_valid(ghost), "untouchable, it still ends")
	check(d.health.ratio() == 1.0, "harmlessly")
	e.queue_free()
	d.queue_free()
	Fx.clear_all()

func test_f_is_the_only_icon_for_elvis_and_vulcans_stay_his() -> void:
	Journey.reset()
	var hud: Hud = HUD.instantiate()
	add_child(hud)
	var e := _elvis()
	await _ticks(1)
	hud.bind(e, null)
	check(str(hud.ability_keys()) == str([&"ability_f"]), "as Elvis, F alone (%s)" % str(hud.ability_keys()))
	hud.show_journey = true
	check(str(hud.ability_keys()) == str([&"ability_f"]), "whatever else the HUD is showing")
	var man: Elvis = ELVIS.instantiate()
	man.character = "vulcan_human"
	add_child(man)
	await _ticks(1)
	hud.bind(man, null)
	check(str(hud.ability_keys()) == str([&"ability_f", &"ability_q"]), "as Vulcan in town, his two")
	check(man.skill_on(&"ability_f") == "", "and no ice on his F")
	man._use_ability(&"ability_f")
	check(man.state == Elvis.State.MOVE, "so it does nothing")
	hud.show_journey = false
	check(hud.ability_keys().is_empty(), "before Cinerea, none")
	hud.queue_free()
	e.queue_free()
	man.queue_free()

func test_his_snap_has_every_view_and_nothing_cropped() -> void:
	var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/elvis_blue/manifest.json"))
	var cell: Array = m["cell"]
	for view: String in ["F", "S", "B", "L"]:
		var a: Dictionary = m["anims"]["ice_snap_" + view]
		check(int(a["active"][0]) == 4 and int(a["active"][1]) == 8, view + " names its snap and its seal")
		var img := Image.load_from_file("res://art/elvis_blue/ice_snap_%s.png" % view)
		check(img.get_width() == int(a["frames"]) * int(cell[0]), view + " is as wide as its frames")
		for f in int(a["frames"]):
			var r := img.get_region(Rect2i(f * int(cell[0]), 0, int(cell[0]), int(cell[1]))).get_used_rect()
			check(r.position.x > 0 and r.position.y > 0 and r.end.x < int(cell[0]) and r.end.y < int(cell[1]), "%s frame %d stays in its cell (%s)" % [view, f, r])
		var snapped := img.get_region(Rect2i(4 * int(cell[0]), 0, int(cell[0]), int(cell[1]))).get_used_rect().size.x
		for f in range(5, 8):
			var w := img.get_region(Rect2i(f * int(cell[0]), 0, int(cell[0]), int(cell[1]))).get_used_rect().size.x
			check(absi(w - snapped) <= 6, "%s keeps both halves in frame %d: %d px wide, %d at the snap" % [view, f, w, snapped])

func test_the_spear_sheet_is_whole_at_every_angle() -> void:
	var img := Image.load_from_file(FxIceSpear.SHEET)
	var cell := img.get_width() / FxIceSpear.ANGLES
	check(img.get_height() == cell * (FxIceSpear.FLASH + 1), "a row for each look")
	for col in FxIceSpear.ANGLES:
		var r := img.get_region(Rect2i(col * cell, 0, cell, cell)).get_used_rect()
		check(r.position.x > 0 and r.position.y > 0 and r.end.x < cell and r.end.y < cell, "column %d isn't cut off (%s)" % [col, r])
	var up := img.get_region(Rect2i(FxIceSpear.UPRIGHT * cell, 0, cell, cell)).get_used_rect()
	check(up.end.y <= cell / 2 + FxIceSpear.LENGTH as int + 4 and up.position.y >= cell / 2 - 4 - FxIceSpear.LENGTH, "upright is tall (%s)" % up)
	check(up.size.y >= FxIceSpear.LENGTH - 2.0 and up.size.x < 40, "and points up the screen, %s" % up)
	check(absf(FxIceSpear.on_screen(Vector3.UP).angle() + PI / 2.0) < 0.01, "straight up the world is straight up the screen")
