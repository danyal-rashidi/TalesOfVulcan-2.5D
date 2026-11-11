extends TestCase
# The dev panel (core/dev.gd): F1, its cheats where the real code applies them, the Journey edits and the jumps.

const CINEREA := preload("res://game/cinerea.tscn")
const ELVIS := preload("res://player/elvis.tscn")
const JACKAL := preload("res://enemy/jackal.tscn")

# Dev is an autoload: whatever a test turns on would go on into the next one.
func _off() -> void:
	if Dev.open:
		Dev.toggle()
	for what: StringName in [&"god", &"one_hit", &"no_cooldowns", &"stamina", &"fast_walk", &"noclip", &"info"]:
		Dev.cheat(false, what)
	Dev.no_save = false

func _f1() -> void:
	for down: bool in [true, false]:
		var key := InputEventKey.new()
		key.physical_keycode = KEY_F1
		key.pressed = down
		Input.parse_input_event(key)
		await get_tree().process_frame    # input is flushed once a frame, and two physics ticks can share one
		await get_tree().process_frame

func test_f1_opens_and_shuts_the_panel() -> void:
	_off()
	await _f1()
	check(Dev.open and Dev._panel.visible, "F1 opens it")
	await _f1()
	check(not Dev.open and not Dev._panel.visible, "and shuts it")
	_off()

func test_god_mode_stops_every_blow() -> void:
	_off()
	var e := ELVIS.instantiate() as Elvis
	add_child(e)
	var hit := Hitbox.new()
	hit.team = Hitbox.TEAM_BOSS
	var c := CollisionShape3D.new()
	c.shape = SphereShape3D.new()
	hit.add_child(c)
	add_child(hit)
	hit.global_position = e.hurtbox.global_position
	for i in 2:
		await get_tree().physics_frame    # let the overlap register
	Dev.cheat(true, &"god")
	var info := HitInfo.new()
	info.damage = 30.0
	hit.activate(info, 1.0)
	for i in 3:
		await get_tree().physics_frame
	check(e.health.hp == e.health.max_hp, "nothing lands with god mode on (hp %s)" % e.health.hp)
	Dev.cheat(false, &"god")
	hit.activate(info, 1.0)
	for i in 3:
		await get_tree().physics_frame
	check(e.health.hp < e.health.max_hp, "and the same blow lands with it off")
	_off()

func test_one_hit_kills_kill() -> void:
	_off()
	var j := JACKAL.instantiate() as Jackal
	add_child(j)
	var info := HitInfo.new()
	info.damage = 1.0
	j.hurtbox.hurt.emit(info)
	check(j.health.hp > 0.0, "a scratch doesn't kill it")
	Dev.cheat(true, &"one_hit")
	j.hurtbox.hurt.emit(info)
	check(j.health.hp == 0.0, "with one-hit kills it does")
	_off()

func test_giving_an_item_goes_through_journey() -> void:
	_off()
	Journey.reset()
	var told: Array[int] = [0]
	var heard := func() -> void: told[0] += 1
	Journey.changed.connect(heard)
	Dev.give(&"jackal_pelt", 3)
	Dev.add_money(7, 2)
	Dev.set_trust("Cassia", 40)
	Journey.changed.disconnect(heard)
	check(Journey.bag.get(&"jackal_pelt") == 3, "three pelts in the bag (%s)" % [Journey.bag])
	check(Journey.drachma == 7 and Journey.embers == 2, "the drachma and embers")
	check(Journey.trust.get("Cassia") == 40, "Cassia's trust is set, not added to")
	check(told[0] == 3, "Journey says so each time, so the HUD redraws (%d)" % told[0])
	Journey.reset()
	_off()

func test_a_jump_in_cinerea_puts_him_there() -> void:
	_off()
	Journey.reset()
	var c := CINEREA.instantiate() as Cinerea
	c.fast = true
	add_child(c)
	for i in 3000:
		if not c._busy:
			break
		await get_tree().process_frame
	var at := -1
	for i in Dev.places.size():
		if Dev.places[i][0] == "Town: Cassia's stall":
			at = i
	check(at >= 0, "the stall is a place")
	Dev.jump(at)
	await get_tree().physics_frame
	var p := c.player.global_position
	check(Vector2(p.x, p.z).distance_to(Vector2(Cinerea.STALL_AT.x, Cinerea.STALL_AT.z)) < 0.2, "he's at the stall (%s)" % p)
	check(c.is_inside_tree() and Dev.landing == Vector3.INF, "in the same scene, with no scene change")
	check(Dev.no_save, "and nothing saves for the rest of the run")
	c.queue_free()
	Journey.reset()
	_off()

func test_the_overlay_never_runs_off_the_screen() -> void:
	_off()
	Dev.cheat(true, &"info")
	Dev._info.text = "\n".join(PackedStringArray(range(200).map(func(i: int) -> String: return "line %d" % i)))    # far more than a town and a full bag
	await get_tree().process_frame
	await get_tree().process_frame
	var r := Dev._overlay.get_global_rect()
	check(r.end.y <= Dev.get_viewport().get_visible_rect().size.y, "it ends on the screen (%s)" % r)
	_off()
