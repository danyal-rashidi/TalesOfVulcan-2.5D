class_name LakeScene
# After the jackals and scorpions: the dark comes down with no words, it lifts and he's walking slowly towards a lake. The camera cuts to raiders round a rich carriage with Cassia shut inside it, after her and her money (Danyal). It snaps back to him, and the fight is his to start.
# Every wait is Cinerea.scaled (x0.05 when fast); his walk is as much faster.

const WALK_FROM := Vector3(0.0, 0.0, -17.0)
const WALK_TO := Vector3(0.0, 0.0, -5.0)
const WALK := 1.6               # Claude's call: m/s, tired
const CARRIAGE_VIEW := Vector3(-5.0, 0.0, -0.5)
const RAIDERS: Array[Vector3] = [Vector3(-3.0, 0.0, 0.5), Vector3(-9.8, 0.0, 2.0), Vector3(-2.2, 0.0, 3.0)]
const RAIDER_SPEED := 3.0

static func run(c: Cinerea) -> void:
	var p := c.player
	var mask := p.collision_mask
	c._busy = true
	c._say_hint("")
	c.hud.pop_down()
	p.input_enabled = false
	p._vel = Vector2.ZERO
	c.menu.allowed = false
	c.hud.fade(true, c.scaled(1.4))
	await c.hud.fade_done
	if not c.is_inside_tree():
		return
	c.clear_desert()
	p.collision_mask = 0    # a cutscene walk must arrive
	p.global_position = WALK_FROM
	p.reset_physics_interpolation()
	p.facing = Vector2.DOWN
	c.camera.follow(p)
	c.respawn_at = WALK_TO
	var raiders: Array[Jackal] = []
	for spot in RAIDERS:
		var raider := c._foe("raider_sword", "walk", "slash", 40.0, 2.7, spot, &"raider_buckle", RAIDER_SPEED)
		var at_door := CassiaScene.DOOR_AT - spot
		raider.facing = Vector2(at_door.x, at_door.z).normalized()
		raider.dead.connect(c._raider_down)
		raiders.append(raider)
		c._raiders_left += 1
	c.set_mood(&"dark", 0.0)
	await TombScene._beat(c, 0.8)
	c.hud.fade(false, c.scaled(1.8))
	c.set_mood(&"lake", c.scaled((WALK_TO.z - WALK_FROM.z) / WALK))    # it lifts as he walks towards the water
	await TombScene._walk_at(c, WALK_TO, WALK)
	p.facing = Vector2.DOWN
	await TombScene._beat(c, 0.6)

	# The cut: there's the carriage, and what's round it.
	c.hud.show_player(false)
	c.camera.focus(CARRIAGE_VIEW, 0.01)
	await TombScene._beat(c, 0.5)
	await Talks.play(c.hud, Talks.AT_THE_CARRIAGE, "Raider")

	# The snap back: he's seen. They turn on him as he comes.
	c.camera.follow(p)
	c.hud.show_player(true)
	for raider in raiders:
		if is_instance_valid(raider):
			raider.wake(p)
	p.collision_mask = mask
	p.input_enabled = true
	c.menu.allowed = true
	c._busy = false
