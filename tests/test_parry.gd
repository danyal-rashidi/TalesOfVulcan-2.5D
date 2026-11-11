extends TestCase
# The parry and the break bar: Elvis turns a blow aside in a short window, a miss leaves him open, and every foe's poise shows and breaks.

const ELVIS := preload("res://player/elvis.tscn")
const VULCAN := preload("res://boss/vulcan.tscn")
const JACKAL := preload("res://enemy/jackal.tscn")
const HUD := preload("res://ui/hud.tscn")
const GAME := preload("res://game/game.tscn")
const AT := Vector3(0.0, 0.0, 8.0)    # Elvis, away from the plinth at the origin; Vulcan stands 1.4 m in front of him (north)
const FRONT := Vector3(0.0, 0.0, 6.6)

func test_parry_is_on_shift_and_rb_and_rb_no_longer_opens_the_menu() -> void:
	var key := false
	var pad := false
	for ev in InputMap.action_get_events(&"parry"):
		key = key or (ev is InputEventKey and (ev as InputEventKey).physical_keycode == KEY_SHIFT)
		pad = pad or (ev is InputEventJoypadButton and (ev as InputEventJoypadButton).button_index == JOY_BUTTON_RIGHT_SHOULDER)
	check(key and pad, "Shift and RB (key %s, pad %s)" % [key, pad])
	var c := false
	for a in InputMap.get_actions():
		for ev in InputMap.action_get_events(a):
			if ev is InputEventKey and (ev as InputEventKey).physical_keycode == KEY_C:
				check(a == &"parry", "nothing else is on C (%s)" % a)
				c = c or a == &"parry"
	check(c, "C parries too, so Shift never has to be mashed")
	for a in InputMap.get_actions():
		for ev in InputMap.action_get_events(a):
			check(a == &"parry" or not (ev is InputEventKey and (ev as InputEventKey).physical_keycode == KEY_SHIFT), "nothing else is on Shift (%s)" % a)
	var menu := GameMenu.new()
	add_child(menu)
	var rb := InputEventJoypadButton.new()
	rb.button_index = JOY_BUTTON_RIGHT_SHOULDER
	rb.pressed = true
	menu._unhandled_input(rb)
	check(not menu.visible, "RB in play doesn't open the menu")
	var tab := InputEventAction.new()
	tab.action = &"menu_next"
	tab.pressed = true
	menu._unhandled_input(tab)
	check(menu.visible, "Tab still does")
	menu.close()
	menu.queue_free()

func test_a_parry_in_the_window_takes_nothing_and_costs_his_poise() -> void:
	var e := await _spawn()
	var v := await _vulcan(FRONT)
	var n := _count(e)
	await _tap(&"parry")
	await _wait(0.05)
	check(e.state == Elvis.State.PARRY, "he braces (state %d)" % e.state)
	check(e.sprite.current_key.begins_with("parry_"), "his own parry sheet (%s)" % e.sprite.current_key)
	e.hurtbox.hurt.emit(v._blow(VulcanMoves.MOVES[&"slash"]))
	check(Engine.time_scale == Feel.STOP_SCALE, "the hit-stop (%s)" % Engine.time_scale)
	check(e.health.hp == e.health.max_hp, "no damage (%s)" % e.health.hp)
	check(e.state == Elvis.State.PARRY and e._caught, "turned aside (state %d)" % e.state)
	near(v.poise, Vulcan.POISE_MAX - Elvis.PARRY_POISE, 0.001, "his poise")
	check(n[0] == 1, "parried once (%d)" % n[0])
	check(Fx.count() > 0, "sparks")
	await _settle()

func test_vulcans_real_slash_is_parried_in_both_phases() -> void:
	for phase in [1, 2]:
		var e := await _spawn()
		var v := await _vulcan(FRONT)
		v.phase = phase
		v.brain.phase = phase
		v.target = e
		var n := _count(e)
		v._begin(&"slash")
		await _wait(float(VulcanMoves.MOVES[&"slash"]["windup"]) / v.brain.speed_scale() - 0.12)
		await _tap(&"parry")
		await _wait(0.4)
		check(e.health.hp == e.health.max_hp, "phase %d: no damage (%s)" % [phase, e.health.hp])
		check(n[0] == 1, "phase %d: parried (%d)" % [phase, n[0]])
		e.queue_free()
		v.queue_free()
		await _settle()

func test_a_jackal_bite_is_parried_and_breaks_it() -> void:
	var e := await _spawn()
	var j := JACKAL.instantiate() as Jackal
	j.position = AT + Vector3(0.0, 0.0, -1.0)
	add_child(j)
	await get_tree().physics_frame
	j.wake(e)
	for i in 60:
		if j.mode == Jackal.Mode.WINDUP:
			break
		await get_tree().physics_frame
	check(j.mode == Jackal.Mode.WINDUP, "it goes to bite")
	await _wait(Jackal.WINDUP - 0.15)
	await _tap(&"parry")
	await _wait(0.3)
	check(e.health.hp == e.health.max_hp, "no damage (%s)" % e.health.hp)
	check(j.broken > 0.0 and not j.hitbox.is_active(), "it's broken, its bite off (broken %s)" % j.broken)
	var was := j.global_position
	await _wait(0.5)
	check(j.global_position.distance_to(was) < 0.1, "it stands (%s m)" % j.global_position.distance_to(was))
	check(e.health.hp == e.health.max_hp, "and doesn't bite (%s)" % e.health.hp)
	await _settle()

func test_too_early_or_too_late_takes_the_hit_and_leaves_him_open() -> void:
	var e := await _spawn()
	var v := await _vulcan(FRONT)
	await _tap(&"parry")
	await _wait(Elvis.PARRY_WINDOW + 0.05)
	e.hurtbox.hurt.emit(v._blow(VulcanMoves.MOVES[&"slash"]))
	near(e.health.hp, e.health.max_hp - 13.0, 0.001, "too early: hit")
	check(e.state == Elvis.State.HURT, "and hurt (state %d)" % e.state)
	near(v.poise, Vulcan.POISE_MAX, 0.001, "his poise untouched")
	e.reset_to(AT)
	e.hurtbox.hurt.emit(v._blow(VulcanMoves.MOVES[&"slash"]))
	await _tap(&"parry")
	check(e.state == Elvis.State.HURT, "too late: hurt, no parry (state %d)" % e.state)
	await _wait(Elvis.HURT_TIME + 0.05)
	check(e.state == Elvis.State.MOVE, "and the press wasn't kept for later (state %d)" % e.state)
	e.reset_to(AT)
	await _tap(&"parry")
	await _wait(Elvis.PARRY_WINDOW + 0.1)
	await _tap(&"attack_light")
	await _tap(&"roll")
	check(e.state == Elvis.State.PARRY and not e._caught, "a miss: open, no swing or roll cuts it (state %d)" % e.state)
	await _wait(Elvis.PARRY_WINDOW + Elvis.PARRY_RECOVER - e._t - 0.05)
	check(e.state == Elvis.State.PARRY, "still open near its end (t %s)" % e._t)
	await _wait(0.1)
	check(e.state != Elvis.State.PARRY, "and over (state %d)" % e.state)
	await _settle()

func test_mashing_does_not_work() -> void:
	var e := await _spawn()
	var v := await _vulcan(FRONT)
	await _tap(&"parry")
	await _wait(0.1)
	await _tap(&"parry")
	await _wait(0.1)
	e.hurtbox.hurt.emit(v._blow(VulcanMoves.MOVES[&"slash"]))
	check(e.health.hp < e.health.max_hp, "a second press doesn't stretch the window")
	e.reset_to(AT)
	await _tap(&"parry")
	await _wait(Elvis.PARRY_WINDOW + 0.05)
	await _tap(&"parry")
	e.hurtbox.hurt.emit(v._blow(VulcanMoves.MOVES[&"slash"]))
	check(e.health.hp < e.health.max_hp, "nor does one in a miss's recovery open another")
	await _settle()

func test_fire_blasts_and_blows_from_behind_cant_be_parried() -> void:
	var e := await _spawn()
	var v := await _vulcan(FRONT)
	for m: StringName in VulcanMoves.MOVES:
		check(v._blow(VulcanMoves.MOVES[m]).parryable == VulcanMoves.MOVES[m].get("parry", false), "%s says so itself" % m)
	for m: StringName in [&"slam", &"breath", &"dive", &"spell"]:
		check(not v._blow(VulcanMoves.MOVES[m]).parryable, "%s can't be parried" % m)
	var blast := v._blow(VulcanMoves.MOVES[&"slash"])
	blast.blast = true
	for blow: HitInfo in [v._blow(VulcanMoves.MOVES[&"slam"]), blast]:
		e.reset_to(AT)
		await _tap(&"parry")
		e.hurtbox.hurt.emit(blow)
		check(e.health.hp < e.health.max_hp, "the fire or a blast lands")
	e.reset_to(AT)
	v.global_position = AT + Vector3(0.0, 0.0, 1.4)
	await _tap(&"parry")
	e.hurtbox.hurt.emit(v._blow(VulcanMoves.MOVES[&"slash"]))
	check(e.health.hp < e.health.max_hp, "a blow from behind lands")
	var j := JACKAL.instantiate() as Jackal
	add_child(j)
	check(j._bite().parryable, "a jackal's bite can be")
	await _settle()

func test_the_bar_fills_and_breaks_him() -> void:
	var e := await _spawn()
	var v := await _vulcan(FRONT)
	v.take_hit(_hit(8.0, 8.0))
	near(v.break_ratio(), 0.08, 0.001, "a light hit")
	for i in 3:
		await _tap(&"parry")
		await _wait(0.05)
		e.hurtbox.hurt.emit(v._blow(VulcanMoves.MOVES[&"slash"]))
		await _settle()
	check(v.broken > 0.0 and v.mode == Vulcan.Mode.FLINCH, "three parries break him (poise %s, mode %d)" % [v.poise, v.mode])
	near(v.break_ratio(), 1.0, 0.1, "the bar full")
	var w := await _vulcan(Vector3(0.0, 0.0, 3.0))    # out of reach: his own swing can't land on Elvis
	w._begin(&"slash")
	w._strike(VulcanMoves.MOVES[&"slash"])
	w.poise = 20.0
	w.take_hit(_hit(30.0, 60.0))
	check(w.poise == 1.0 and w.broken == 0.0, "mid-swing a heavy leaves a sliver (poise %s)" % w.poise)
	e.reset_to(AT)
	await _tap(&"parry")
	e.hurtbox.hurt.emit(w._blow(VulcanMoves.MOVES[&"slash"]))
	check(w.broken > 0.0, "but a parry breaks him")
	await _settle()

func test_the_broken_window_takes_extra_damage_and_ends() -> void:
	var v := await _vulcan(FRONT)
	v.wear_poise(v.poise_max)
	check(v.broken > 0.0 and v.mode == Vulcan.Mode.FLINCH, "broken, he flinches")
	var was := v.health.hp
	v.take_hit(_hit(10.0, 0.0))
	near(was - v.health.hp, 10.0 * Actor.BREAK_DAMAGE, 0.001, "broken, a blow does more")
	await _wait(Actor.BREAK_TIME + 0.1)
	check(v.broken == 0.0 and v.poise == v.poise_max, "it ends on a full bar (broken %s, poise %s)" % [v.broken, v.poise])
	check(v.mode != Vulcan.Mode.FLINCH, "and he's on his feet (mode %d)" % v.mode)
	was = v.health.hp
	v.take_hit(_hit(10.0, 0.0))
	near(was - v.health.hp, 10.0, 0.001, "then blows are as before")
	var j := JACKAL.instantiate() as Jackal
	j.position = Vector3(5.0, 0.0, 8.0)
	add_child(j)
	j.scripted = true
	await get_tree().physics_frame
	j.wear_poise(Jackal.POISE)
	check(j.broken > 0.0, "a jackal breaks")
	j.take_hit(_hit(10.0, 0.0))
	near(j.health.hp, Jackal.HP - 10.0 * Actor.BREAK_DAMAGE, 0.001, "and takes more")
	await _wait(Actor.BREAK_TIME + 0.1)
	check(j.broken == 0.0 and j.poise == j.poise_max, "and comes back")
	await _settle()

func test_the_hud_shows_his_break_bar_and_small_ones_once_hit() -> void:
	var cam := PixelCamera.new()
	add_child(cam)
	cam.make_current()
	var e := await _spawn()
	var v := await _vulcan(FRONT)
	var hud: Hud = HUD.instantiate()
	add_child(hud)
	hud.bind(e, v)
	hud.show_boss_bar(true)
	check(hud.shows_break(v) and v.break_ratio() == 0.0, "his bar, empty")
	await _tap(&"parry")
	e.hurtbox.hurt.emit(v._blow(VulcanMoves.MOVES[&"slash"]))
	near(v.break_ratio(), Elvis.PARRY_POISE / Vulcan.POISE_MAX, 0.001, "a parry fills it")
	var j := JACKAL.instantiate() as Jackal
	j.position = Vector3(3.0, 0.0, 8.0)
	add_child(j)
	await get_tree().physics_frame
	check(not hud.shows_break(j), "a fresh foe shows none")
	j.take_hit(_hit(1.0, 5.0))
	check(hud.shows_break(j), "hit once, it does")
	await get_tree().process_frame
	await get_tree().process_frame    # the draw runs the new bars
	hud.show_boss_bar(false)
	check(not hud.shows_break(v), "his goes with his health bar")
	hud.queue_free()
	await _settle()

# A player who has learned his timing: the bot parries his slash and backswing up close and wins phase two.
func test_a_parrying_bot_beats_phase_two() -> void:
	seed(1)
	var g := GAME.instantiate() as Game
	g.fast = true
	add_child(g)
	g.elvis.global_position = Vector3(0.0, 0.0, 11.5)
	var until := Time.get_ticks_msec() + 3000
	while g.flow != Game.Flow.FIGHT and Time.get_ticks_msec() < until:
		await get_tree().physics_frame
	check(g.flow == Game.Flow.FIGHT, "the fight starts")
	g.elvis.reset_to(g.arena.entrance())    # 11.5 m only wakes him: it is outside the wall
	g.add_child(Bot.new())
	var v := g.vulcan
	var n := _count(g.elvis)
	v.health.take(v.max_hp * 0.5)    # straight to the roar
	until = Time.get_ticks_msec() + 75000
	while not v.kneeling and g.restarts == 0 and Time.get_ticks_msec() < until:
		await get_tree().physics_frame
	print("parry bot: kneeling %s, restarts %d, parries %d, Elvis hp %s, red flasks %d, Vulcan hp %s" % [v.kneeling, g.restarts, n[0], g.elvis.health.hp, g.elvis.flasks.red, v.health.hp])
	check(v.kneeling and g.restarts == 0, "it beats phase two (Vulcan hp %s, restarts %d)" % [v.health.hp, g.restarts])
	check(n[0] >= 5, "by parrying (%d)" % n[0])
	g.queue_free()
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

# Standing, with no one to go for: he idles.
func _vulcan(at: Vector3) -> Vulcan:
	var v := VULCAN.instantiate() as Vulcan
	add_child(v)
	await get_tree().physics_frame
	v.reset_fight(at)
	await get_tree().physics_frame
	return v

func _hit(damage: float, poise: float) -> HitInfo:
	var info := HitInfo.new()
	info.damage = damage
	info.poise = poise
	info.at = AT
	return info

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

# The hit-stops run out (real time) and the effects go, so the next test starts at full speed.
func _settle() -> void:
	await get_tree().create_timer(0.2, true, false, true).timeout
	Fx.clear_all()

func _exit_tree() -> void:
	for a: StringName in [&"parry", &"attack_light", &"roll"]:
		Input.action_release(a)
