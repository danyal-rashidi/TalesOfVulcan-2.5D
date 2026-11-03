class_name CassiaScene
# Meeting Cassia (DIALOGUE.md), played out like the tomb: with the raiders dead the carriage's door opens and she walks out and down onto the sand, goes to her strongbox before herself, sizes him up, names him and throws him
# his pay; he catches it; her camel comes to her. Then she climbs back in, the camel is hitched, and it pulls the carriage down the road, through the gate and into town, where she gets out and goes to her stall. Every wait is Cinerea.scaled (x0.05 when fast), and every walk as much faster.

const STAND_AT := Vector3(-5.6, 0.0, 6.2)     # where he comes to, clear of the cart, looking at it, and out of the way it leaves
const DOOR_AT := Vector3(-7.16, 0.0, 1.06)     # in the doorway: x under the door in art/props/carriage.png, mirrored; just in front of the carriage's picture, behind its door's
const SILL_UP := 2.15       # m above the sand her feet are drawn on the door's sill: 46 px up the picture, at Pixel.PX * cos(pitch) px a metre
const STEP_DOWN := 2.0      # s walking out and down to the sand
const DOOR_OPENS := 0.7     # s
const OUT_TO := Vector3(-7.8, 0.0, 2.3)        # clear of the carriage
const STRONGBOX := Vector3(-9.6, 0.0, 3.5)     # where the raiders dropped it
const FORTUNA_FROM := Vector3(5.0, 0.0, 2.0)   # off the screen to the right, and clear of the lake
const FORTUNA_TO := Vector3(-6.4, 0.0, 3.6)    # on her way to the front of it she needn't walk through him
const CHECK := 2.0
const TOSS := 1.0
const THROW_AT := 0.45      # of the toss: the purse leaves her hand
const FLIGHT := 0.6
const ARC := 1.4            # m above the straight line
const PURSE := 10           # drachma: "Ten drachma for the carriage you just saved"
const HAND := Vector3.UP * 1.2
const HITCH := Vector3(-3.8, 0.0, 2.2)         # the front of the carriage: where the harnessed picture has the camel's feet
const HITCH_FADE := 0.35    # s each way. Claude's call: the harnessed picture's camel is 1.42x her sprite and its wagon 0.7x the prop's (art/tools/carriage_pull.py), so she's hitched up in a moment's dark rather than in front of you
const PULL := 1.0           # m/s, what art/tools/carriage_pull.py times the sheets for, so nothing slides on the ground
const PULL_FROM := Vector3(-5.57, 0.0, 0.97)   # its wagon where the prop's stood
const ON_ROAD := Vector3(0.0, 0.0, 4.87)       # 0.7 m down for 1 m across: the way the diagonal sheet goes (CarriagePull.HEADING)
const PARK := Vector3(10.5, 0.0, 43.6)         # the sand between the north lane and the tavern's back: no street, door or stall, and room to walk round
const TURN := Vector3(0.0, 0.0, 43.6 - 10.5 * 0.7)    # where the road leaves for it
const CAMEL_AT := Vector3(1.75, 0.0, 1.5)      # from where it's parked: who you talk to
const GETS_OUT_AT := Vector3(-1.05, 0.0, -2.65)    # from where it's parked: she climbs down on the far side, hidden by the wagon. Its door is too small for her at this scale, so we don't see that one
# Round the back of it and down the main street's edge to the stall, on the street's side of the lantern at (3.9, 47): its post stands left of its middle.
const TO_THE_STALL: Array[Vector3] = [Vector3(6.3, 0.0, 40.95), Vector3(2.5, 0.0, 42.0), Vector3(2.5, 0.0, 58.6), Cinerea.STALL_AT]

static func run(c: Cinerea) -> void:
	var p := c.player
	var cassia := c._cassia
	var mask := p.collision_mask
	c._busy = true
	c.hud.pop_down()
	c._say_hint("")
	p.input_enabled = false
	p.scripted = true
	p.collision_mask = 0    # a cutscene walk must arrive
	p._vel = Vector2.ZERO
	c.menu.allowed = false
	c.hud.show_player(false)
	cassia.speed = Townsperson.SPEED / c.scaled(1.0)
	c._fortuna.speed = Townsperson.SPEED / c.scaled(1.0)
	await TombScene._beat(c, 0.6)
	c.camera.focus(Vector3(-6.6, 0.0, 3.0), c.scaled(1.0))
	await TombScene._walk(c, STAND_AT)
	TombScene._face(p, DOOR_AT)

	# 1. The carriage's door swings open, and she's standing in it.
	cassia.position = DOOR_AT
	cassia.lift = SILL_UP
	cassia.sprite.position.y = SILL_UP    # now, or she shows on the sand for a frame
	cassia.reset_physics_interpolation()
	cassia.set_shown(true)
	cassia.hold(Vector2.DOWN)
	await TombScene._beat(c, 0.5)
	var door := c.cart_door()
	var opens := c.create_tween()
	opens.tween_property(door, "frame", door.hframes - 1, c.scaled(DOOR_OPENS))
	await opens.finished
	await TombScene._beat(c, 0.4)

	# 2. She walks out and down onto the sand, her feet on the sill, then the step, then the ground.
	cassia.sprite.play("walk", Vector2.DOWN)
	var down := c.create_tween()
	down.tween_property(cassia, "lift", 0.0, c.scaled(STEP_DOWN))
	await down.finished
	cassia.release()
	cassia.walk_to([OUT_TO])
	while cassia.walking():
		await c.get_tree().process_frame

	# 3. Her money before herself.
	cassia.release()
	cassia.walk_to([STRONGBOX])
	while cassia.walking():
		await c.get_tree().process_frame
	cassia.hold(Vector2.LEFT)
	cassia.sprite.play_timed("check", Vector2.LEFT, c.scaled(CHECK))
	await TombScene._beat(c, CHECK * 0.5)
	await Talks.say(c.hud, "Cassia", "Och, the strongbox is fine. The strongbox is fine.")
	await TombScene._beat(c, 0.2)

	# 4. She looks up at him at last.
	var to_him := p.global_position - cassia.position
	cassia.hold(Vector2(to_him.x, to_him.z).normalized())
	TombScene._face(p, cassia.position)
	await Talks.play(c.hud, Talks.FIRST_LOOK, cassia.who)

	# 5. She throws him his pay; he catches it.
	cassia.sprite.play_timed("toss", Vector2.RIGHT, c.scaled(TOSS))
	await TombScene._beat(c, TOSS * THROW_AT)
	await _throw(c, cassia.position + HAND, p.global_position + HAND)
	Journey.drachma += PURSE
	p.sprite.flash(c.scaled(0.2))
	Fx.spawn(&"sparks", p.global_position + HAND)
	await TombScene._beat(c, 0.3)
	cassia.hold(Vector2(to_him.x, to_him.z).normalized())
	await Talks.play(c.hud, Talks.AFTER_PURSE, cassia.who)

	# 6. Her camel comes to her; she gentles it, and tells him where to find her.
	var fortuna := c._fortuna
	fortuna.set_shown(true)
	fortuna.walk_to([FORTUNA_TO])
	while fortuna.walking():
		await c.get_tree().process_frame
	cassia.hold(Vector2.RIGHT)
	await Talks.say(c.hud, "Cassia", "Easy, Fortuna, easy. The big ghost's on our side.")
	cassia.hold(Vector2(to_him.x, to_him.z).normalized())
	await Talks.say(c.hud, "Cassia", "My stall's by the fountain, and the job board's next to it. Come find me when you want work. Or a bath. Mostly a bath.")

	# 7. She goes back to the door and up onto the sill, and it shuts behind her.
	cassia.release()
	cassia.walk_to([OUT_TO, DOOR_AT])
	while cassia.walking():
		await c.get_tree().process_frame
	cassia.sprite.play("walk", Vector2.UP)
	var up := c.create_tween()
	up.tween_property(cassia, "lift", SILL_UP, c.scaled(STEP_DOWN))
	await up.finished
	cassia.sprite.play("idle", Vector2.UP)
	var shuts := c.create_tween()
	shuts.tween_property(door, "frame", 0, c.scaled(DOOR_OPENS))
	await shuts.finished
	cassia.set_shown(false)
	cassia.lift = 0.0

	# 8. Fortuna comes round to the front of it and she's hitched up.
	fortuna.release()
	fortuna.walk_to([HITCH])
	while fortuna.walking():
		await c.get_tree().process_frame
	c.hud.fade(true, c.scaled(HITCH_FADE))
	await c.hud.fade_done
	c._cart.visible = false
	c._cart_body.queue_free()
	fortuna.set_shown(false)
	c.pull = CarriagePull.new()
	c.add_child(c.pull)
	c.pull.setup("carriage_pull", "", PULL_FROM, PULL_FROM, [], PackedStringArray())
	c.pull.bobs = false
	c.pull.sprite.play("idle", Vector2(1.0, 0.7))
	c.hud.fade(false, c.scaled(HITCH_FADE))
	await c.hud.fade_done

	# 9. They set off; he has the road again, and it stops nobody on the way.
	c.met_cassia = true
	p.collision_mask = mask
	p.scripted = false
	p.input_enabled = true
	c.menu.allowed = true
	c.hud.show_player(true)
	c.camera.follow(p)
	c._busy = false
	c.pull.speed = PULL / c.scaled(1.0)
	c.pull.sprite.play("walk", Vector2(1.0, 0.7))
	c.pull.sprite._set_frame(CarriagePull.STANDS_ON + 1)    # her legs go on from where they stood
	c.pull.walk_to([ON_ROAD, TURN, PARK])
	await c.pull.arrived

	# 10. It parks; she gets out on the far side and walks round to her stall. Fortuna stays in harness, and can still be talked to there.
	c.pull.park()
	fortuna.position = PARK + CAMEL_AT
	fortuna.reset_physics_interpolation()
	fortuna.hitched = true
	cassia.position = PARK + GETS_OUT_AT
	cassia.reset_physics_interpolation()
	cassia.set_shown(true)
	cassia.walk_to(TO_THE_STALL)
	await cassia.arrived
	cassia.sprite.play("idle", Vector2.DOWN)    # her last leg was sideways: she stands at her stall facing the street

# A purse on its arc, from her hand to his.
static func _throw(c: Cinerea, from: Vector3, to: Vector3) -> void:
	var purse := Arena.texture_sprite(ImageTexture.create_from_image(_purse_image()), from.x, from.z)
	c.add_child(purse)
	var flight := c.scaled(FLIGHT)
	var tw := c.create_tween()
	tw.tween_method(func(t: float) -> void: purse.position = from.lerp(to, t) + Vector3.UP * ARC * 4.0 * t * (1.0 - t), 0.0, 1.0, flight)
	await tw.finished
	purse.queue_free()

# A little leather purse, tied at the neck, as the game's other small things are drawn.
static func _purse_image() -> Image:
	const ROWS: Array[String] = ["..ddd...", "...b....", "..bbbb..", ".bLLbbb.", ".bLbbbb.", ".bbbbbb.", "..bbbb.."]
	var colours := {"d": Color8(60, 34, 22), "b": Color8(150, 96, 52), "L": Color8(205, 150, 90)}
	var img := Image.create(8, ROWS.size(), false, Image.FORMAT_RGBA8)
	for y in ROWS.size():
		for x in 8:
			if colours.has(ROWS[y][x]):
				img.set_pixel(x, y, colours[ROWS[y][x]])
	return img
