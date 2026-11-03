class_name TombScene
# The legionary's tomb (STORY.md "The Hammer"): he goes to it, the slab grinds off the pit and the day dims, a light comes up out of the dark, he kneels,
# the broken hammer head rises into his hands, he lifts his head to look at it, it blazes and he glows with it, and the memory takes him.
# Every wait is Cinerea.scaled (x0.05 when fast); his walks are as much faster.

const WALK := 3.0           # Claude's call: his cutscene walk, m/s
const UP_TO := Vector3(-4.4, 0.0, -24.5)      # where he stands to see the slab go, clear of the tomb's collision
const KNEEL_AT := Vector3(-5.4, 0.0, -25.6)   # at the pit's side: the kneel is only drawn facing the camera, so beside it, not in front of it
const PIT := Vector3(-6.3, 0.0, -26.2)        # the pit's middle, on the ground
const HANDS := 1.0          # m above his feet: his hands in the kneel
const SLIDE := 1.1          # the slab grinding aside
const LIGHT_UP := 1.3       # the light coming up out of the pit
const RISE := 1.2           # the head rising to his hands
const LOOK := 2.6           # lifting his head to look at it, as it builds

static func run(c: Cinerea) -> void:
	var p := c.player
	var mask := p.collision_mask
	p.input_enabled = false
	p.scripted = true
	p.collision_mask = 0    # a cutscene walk must arrive; he ends clear of the tomb
	p._vel = Vector2.ZERO
	c.menu.allowed = false
	c.hud.show_player(false)
	c.camera.focus(Vector3(PIT.x + 1.2, 0.0, PIT.z + 1.4), c.scaled(1.0))

	# 1. He goes to the tomb and looks at it; the slab grinds aside.
	await _walk(c, UP_TO)
	_face(p, Vector3(PIT.x, 0.0, PIT.z))
	await _beat(c, 0.35)
	Feel.shake(1.0, c.scaled(SLIDE))
	Fx.spawn(&"dust", PIT + Vector3(0.9, 0.0, 0.3))
	var slab := c.create_tween()
	slab.tween_property(c._tomb, "frame", Cinerea.TOMB_FRAMES - 1, c.scaled(SLIDE))
	await slab.finished
	Fx.spawn(&"dust", PIT + Vector3(1.5, 0.0, 0.6))
	Feel.shake(2.0, 0.12)
	await _beat(c, 0.3)

	# 2. The day dims and a light comes up out of the pit.
	c.set_mood(&"hush", c.scaled(LIGHT_UP))
	var head := HammerHead.new()
	c.add_child(head)
	head.global_position = PIT
	_heat(c, head, 1.0, LIGHT_UP)
	Fx.spawn(&"embers", PIT)
	await _beat(c, LIGHT_UP)

	# 3. He goes to it and kneels, head bowed.
	await _walk(c, KNEEL_AT)
	p.facing = Vector2.DOWN
	p.sprite.play_timed("kneel", p.facing, 0.0)
	await _beat(c, 0.5)

	# 4. It rises out of the pit and into his hands.
	Fx.spawn(&"embers", PIT)
	await head.rise(KNEEL_AT + Vector3.UP * HANDS, c.scaled(RISE))
	Fx.spawn(&"sparks", head.global_position)
	await _beat(c, 0.25)

	# 5. He lifts his head to look at it. It builds, and he glows with it.
	p.sprite.play_timed("look_hands", p.facing, c.scaled(LOOK))
	_heat(c, head, 2.0, LOOK)
	var glow := c.create_tween()
	glow.tween_method(func(x: float) -> void: p.sprite.set_param(&"glow", x), 0.0, 0.75, c.scaled(LOOK))
	for i in 3:
		await _beat(c, LOOK / 3.0)
		Fx.spawn(&"embers", head.global_position)
		Fx.spawn(&"sparks", head.global_position)
		Feel.shake(float(i + 1), c.scaled(0.2))
	Feel.shake(4.0, c.scaled(0.4))
	p.sprite.flash(c.scaled(0.25))

	# 6. The memory takes him. It ends white-orange; the world comes back out of that, with the head gone into his things and the light gone from him.
	var memory := MemoryVision.new()
	memory.layer = c.hud.layer - 1    # under the HUD, so the line after it stays readable
	c.add_child(memory)
	await memory.play(c.scaled(1.0))
	head.queue_free()
	p.sprite.set_param(&"glow", 0.0)
	Journey.remember(&"hammer")
	c.set_mood(c.mood_here(), c.scaled(1.0))
	await memory.fade_out(c.scaled(0.8))

	# 7. He gets up as the line comes, kneels again to gather the rest from the pit, and walks clear. He is never still for long.
	await _beat(c, 0.5)
	p.sprite.play("idle", p.facing)
	c.hud.say("", "A memory: The Hammer. Hammer Blow is learned. Hold F to aim it.")
	await c.hud.line_done
	p.sprite.play_timed("kneel", p.facing, 0.0)
	Fx.spawn(&"dust", PIT + Vector3(0.4, 0.0, 0.3))
	c.hud.say("", "In the tomb: an iron sword and 5 drachma.")
	await c.hud.line_done
	await _walk(c, UP_TO)
	_face(p, Vector3(PIT.x, 0.0, PIT.z))
	p.collision_mask = mask
	p.scripted = false
	p.input_enabled = true
	c.menu.allowed = true
	c.hud.show_player(true)
	c.camera.follow(p)

static func _beat(c: Cinerea, seconds: float) -> void:
	await c.get_tree().create_timer(c.scaled(seconds)).timeout

static func _walk(c: Cinerea, at: Vector3) -> void:
	c.player.move_to(at, WALK / c.scaled(1.0))
	await c.player.arrived

static func _walk_at(c: Cinerea, at: Vector3, speed: float) -> void:
	c.player.move_to(at, speed / c.scaled(1.0))
	await c.player.arrived

static func _face(p: Elvis, at: Vector3) -> void:
	var d := at - p.global_position
	p.facing = Vector2(d.x, d.z).normalized()
	p.sprite.play(p._look("idle"), p.facing)

static func _heat(c: Cinerea, head: HammerHead, to: float, seconds: float) -> void:
	c.create_tween().tween_property(head, "hot", to, c.scaled(seconds))
