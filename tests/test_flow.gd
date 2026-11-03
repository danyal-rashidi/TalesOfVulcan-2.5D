extends TestCase
# The whole game, run fast (every cutscene wait x0.05): C1 at 12 m, the phase-two line, the restart after a death at a bad moment,
# the kneel that stops every attack, and the run from the kneel to the title card.

const GAME := preload("res://game/game.tscn")

func test_c1_within_12m() -> void:
	var g := _game()
	g.elvis.global_position = Vector3(12.5, 0.0, 0.0)    # beyond 12 m (outside the wall): the statue sleeps
	for i in 5:
		await get_tree().physics_frame
	check(g.flow == Game.Flow.ENTER and not g.vulcan.awake, "beyond 12 m nothing happens (flow %d)" % g.flow)
	near(g.vulcan.global_position.y, Arena.PLINTH_H, 0.01, "the statue stands on the plinth, not over it")
	g.elvis.global_position = Vector3(0.0, 0.0, 11.5)
	check(await _until(g, Game.Flow.FIGHT, 3.0), "FIGHT within 3 s of coming within 12 m (flow %d)" % g.flow)
	check(g.vulcan.awake and g.vulcan.armed, "Vulcan awake and armed (awake %s, armed %s)" % [g.vulcan.awake, g.vulcan.armed])
	check(g.elvis.input_enabled, "Elvis has control again")

func test_phase_two_line() -> void:
	var g := _game()
	check(await _until(g, Game.Flow.FIGHT, 3.0), "the fight starts")
	g.vulcan.health.take(g.vulcan.health.max_hp * 0.5)
	check(g.hud.last_line == "Strike the crown.", "the phase-two line (got '%s')" % g.hud.last_line)
	await get_tree().physics_frame
	check(g.flow == Game.Flow.FIGHT, "the fight doesn't pause (flow %d)" % g.flow)
	Fx.clear_all()

func test_death_restart_resets_everything() -> void:
	var g := _game()
	check(await _until(g, Game.Flow.FIGHT, 3.0), "the fight starts")
	for i in 3:
		Fx.spawn(&"fireball", Vector3(-6.0 + i, 1.2, -6.0), Vector3.RIGHT)    # in flight, far from Elvis
	g.arena.crack(Vector3(2.0, 0.0, 2.0), 1.0)
	g.arena.crack(Vector3(-2.0, 0.0, 2.0), 1.0)
	g.elvis.flasks.drink_red(g.elvis.health)
	g.vulcan.health.take(g.vulcan.health.max_hp * 0.3)
	g.arena.set_mood(&"storm", 0.0)    # not the fight's blood, so the mood check below proves the reset
	g.hud.fast = false                 # a line that would still be showing long after the restart
	g.hud.say("Vulcan", "Strike the crown.")
	await _tap(&"flask_red")           # he dies mid-drink, mid-line, with the fireballs in flight
	check(Fx.count() >= 3 and g.arena.crack_count() == 2 and g.elvis.flasks.red == 3 and g.elvis.state == Elvis.State.DRINK, "set up (fx %d, cracks %d, red %d, state %d)" % [Fx.count(), g.arena.crack_count(), g.elvis.flasks.red, g.elvis.state])
	var flows: Array[int] = []
	g.flow_changed.connect(func(f: int) -> void: flows.append(f))
	await _die(g)
	check(g.restarts == 1, "restarted once (restarts %d)" % g.restarts)
	var e := g.elvis
	check(e.health.hp == e.health.max_hp and e.stamina.value == e.stamina.max_value and e.state == Elvis.State.MOVE, "Elvis full and standing (hp %s, stamina %s, state %d)" % [e.health.hp, e.stamina.value, e.state])
	check(e.global_position.distance_to(g.arena.entrance()) < 0.05, "Elvis at the entrance (%s)" % e.global_position)
	check(e.flasks.red == 4 and e.flasks.green == 2, "flasks 4/2 (%d/%d)" % [e.flasks.red, e.flasks.green])
	var v := g.vulcan
	check(v.health.hp == v.health.max_hp and v.awake and v.armed and v.phase == 1 and not v.kneeling, "Vulcan full, awake, armed, phase 1 (hp %s, phase %d)" % [v.health.hp, v.phase])
	check(Fx.count() == 0 and g.arena.crack_count() == 0, "no effects, no cracks (fx %d, cracks %d)" % [Fx.count(), g.arena.crack_count()])
	check(g.arena.sun.light_color.r > 1.5 * g.arena.sun.light_color.g, "the blood sun (%s)" % g.arena.sun.light_color)
	check(g.flow == Game.Flow.FIGHT, "back in the fight (flow %d)" % g.flow)
	check(not g.hud._line_on and g.hud._boss_on and g.hud._trail == [1.0, 1.0], "HUD rebound: no line, the boss bar, full trails (line %s, bar %s, trails %s)" % [g.hud._line_on, g.hud._boss_on, g.hud._trail])
	for i in 30:    # the fade back, and nothing restarts twice
		await get_tree().physics_frame
	check(g.restarts == 1 and not flows.has(Game.Flow.WAKE), "once, and C1 doesn't play again (restarts %d, flows %s)" % [g.restarts, flows])
	check(e.input_enabled and e.state == Elvis.State.MOVE, "Elvis has control, the drink gone (state %d)" % e.state)
	Fx.clear_all()

# Dying mid-swing while Vulcan winds up: both moves are gone after the restart, and it happens once.
func test_death_mid_move_restarts_once() -> void:
	var g := _game()
	check(await _until(g, Game.Flow.FIGHT, 3.0), "the fight starts")
	var until := Time.get_ticks_msec() + 5000
	while g.vulcan.mode != Vulcan.Mode.WINDUP and Time.get_ticks_msec() < until:
		await get_tree().physics_frame
	await _tap(&"attack_light")
	check(g.vulcan.mode == Vulcan.Mode.WINDUP and g.elvis.state == Elvis.State.LIGHT, "both mid-move (Vulcan %d, Elvis %d)" % [g.vulcan.mode, g.elvis.state])
	await _die(g)
	check(g.restarts == 1, "restarted once (restarts %d)" % g.restarts)
	check(g.elvis.state == Elvis.State.MOVE and not g.elvis.hitbox.is_active(), "Elvis standing, no blow of his (state %d)" % g.elvis.state)
	check(g.vulcan.mode != Vulcan.Mode.WINDUP and g.vulcan.mode != Vulcan.Mode.ACTIVE and not g.vulcan.hitbox.is_active(), "Vulcan's move dropped (mode %d)" % g.vulcan.mode)
	for i in 30:
		await get_tree().physics_frame
	check(g.restarts == 1 and g.elvis.input_enabled, "once, and Elvis has control (restarts %d)" % g.restarts)
	Fx.clear_all()

func test_kneel_stops_attacks() -> void:
	var g := _game()
	check(await _until(g, Game.Flow.FIGHT, 3.0), "the fight starts")
	var until := Time.get_ticks_msec() + 5000
	while g.vulcan.mode != Vulcan.Mode.ACTIVE and Time.get_ticks_msec() < until:    # kneel him mid-blow
		await get_tree().physics_frame
	check(g.vulcan.mode == Vulcan.Mode.ACTIVE, "he was striking (mode %d)" % g.vulcan.mode)
	g.vulcan.health.take(g.vulcan.health.max_hp)
	var hp := g.elvis.health.hp
	var bad := 0
	for i in 120:
		await get_tree().physics_frame
		if g.vulcan.hitbox.is_active() or Fx.count() > 0:
			bad += 1
	check(g.vulcan.kneeling and bad == 0, "for 2 s no blow of his is active and no effect alive (bad frames %d, fx %d)" % [bad, Fx.count()])
	check(g.elvis.health.hp == hp, "Elvis isn't hurt (%s -> %s)" % [hp, g.elvis.health.hp])
	check(g.flow == Game.Flow.FIGHT, "waiting for the crown (flow %d)" % g.flow)

func test_full_run_reaches_end() -> void:
	var g := _game()
	var flows: Array[int] = []
	g.flow_changed.connect(func(f: int) -> void: flows.append(f))
	check(await _until(g, Game.Flow.FIGHT, 3.0), "the fight starts")
	g.vulcan.health.take(g.vulcan.health.max_hp)
	await get_tree().physics_frame
	var heavy := HitInfo.new()
	heavy.damage = 30.0
	heavy.heavy = true
	heavy.source = g.elvis
	heavy.at = g.vulcan.global_position + Vector3.UP
	check(g.hud._pop == g.vulcan and g.hud._pop_title == "Strike the Crown", "kneeling, a pop-up says what to do")
	check(g.hud._pop_t < 0.0, "once the number of the blow that felled him has gone (%s)" % g.hud._pop_t)
	g.vulcan.take_hit(heavy)
	check(g.hud._pop == null, "the pop-up has gone once the crown is struck")
	var lines: Array[String] = []
	var until := Time.get_ticks_msec() + 10000
	while g.flow != Game.Flow.END and Time.get_ticks_msec() < until:    # a fast line shows for 0.1 s, several physics frames
		await get_tree().physics_frame
		if not (g.hud.last_line in ["", "Strike the crown."] or g.hud.last_line in lines):
			lines.append(g.hud.last_line)
	check(g.flow == Game.Flow.END, "END within 10 s (flow %d)" % g.flow)
	check(flows.has(Game.Flow.UNMASK) and flows.has(Game.Flow.END), "through UNMASK to END (%s)" % [flows])
	check(g.vulcan.sprite.character == "vulcan_human", "Vulcan is a man (%s)" % g.vulcan.sprite.character)
	check(lines == ["Who... am I?", "I don't know who you were... but it doesn't matter now."], "the two lines in order (got %s)" % [lines])
	check(not g.hud._player_on and not g.hud._boss_on, "no fight HUD in C3")
	check(not g.elvis.visible, "Elvis has walked out")
	check(g.vulcan.global_position.z > Arena.RADIUS, "and so has the man (%s)" % g.vulcan.global_position)
	check(g.hud._black >= 0.99, "the screen has gone black")
	var swords := g.find_children("*", "SwordProp", true, false)
	check(swords.is_empty() or swords[0].is_queued_for_deletion(), "his greatsword has gone into thin air")
	Fx.clear_all()

# Task 6: locked on, the camera leans toward the target, eased, in whole pixels, at most LEAD_MAX.
func test_camera_leads_to_lock_target() -> void:
	var g := _game()
	check(await _until(g, Game.Flow.FIGHT, 3.0), "the fight starts")
	g.elvis.lock_target = g.vulcan
	for i in 60:
		await get_tree().physics_frame
	var to := g.vulcan.global_position - g.elvis.global_position
	var lead := g.camera.lead
	check(lead.length() > 0.5 and lead.normalized().dot(Vector3(to.x, 0.0, to.z).normalized()) > 0.8, "toward him (lead %s, to %s)" % [lead, to])
	check(lead.length() <= Game.LEAD_MAX + 0.05 and lead.is_equal_approx(Pixel.snap(lead)), "snapped, at most LEAD_MAX (%s)" % lead)
	Fx.clear_all()

# A fast game; Elvis can still be moved before its first physics frame.
func _game() -> Game:
	var g := GAME.instantiate() as Game
	g.fast = true
	add_child(g)
	return g

# Kills Elvis and waits up to 3 s for the restart.
func _die(g: Game) -> void:
	g.elvis.health.take(1000.0)
	var until := Time.get_ticks_msec() + 3000
	while g.restarts == 0 and Time.get_ticks_msec() < until:
		await get_tree().physics_frame

func _tap(action: StringName) -> void:
	Input.action_press(action)
	await get_tree().physics_frame
	Input.action_release(action)
	await get_tree().physics_frame

func _until(g: Game, f: Game.Flow, seconds: float) -> bool:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while g.flow != f and Time.get_ticks_msec() < until:
		await get_tree().physics_frame
	return g.flow == f
