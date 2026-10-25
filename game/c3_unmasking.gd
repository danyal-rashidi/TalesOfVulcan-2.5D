class_name C3Unmasking
# C3, the unmasking: STORY.md "Cutscene: the unmasking" shots 1-7, in the arena with the game's sprites.
#   1. Slow motion: the crown flies off on an arc, spinning, trailing embers, and lands in the sand.
#   2. He kneels; the lava in his cracks cools to grey.  3. The armour burns to ash and the man is under it.
#   4. The greatsword falls.  5. Elvis walks to the crown and splits it; its red light flees north.
#   6. The storm clears.  7. He looks at his hands; the two lines; the fade; the title card.
# Every wait is Game.wait (x0.05 when fast); Elvis's walk is as much faster.

const SLOW := 0.25        # the plan: slow motion at 25% (STORY.md C3 shot 1 too)
const SLOW_TIME := 1.5    # the plan: real seconds of it
const FLIGHT := 1.0       # Claude's call: game seconds from his head to the sand
const THROW := 2.5        # Claude's call: m from him to where it lands
const FRAME := 0.8        # Claude's call: s for the camera to frame the two of them
const RECOIL := 3.6       # Claude's call: m from him that Elvis recoils to as the crown flies, so neither sprite hides the other
const COOL := 2.5         # the plan: shot 2
const BURN := 3.0         # the plan: shot 3
const FALL := 0.45        # Claude's call: the sword tipping over
const WALK := 2.0         # Claude's call: Elvis's cutscene walk, m/s
const STAND := 0.9        # Claude's call: he stops this far from the crown to strike it
const CLEAR := 3.0        # the plan: shot 6
const FADE := 1.5         # Claude's call
const BEAT := 0.5         # Claude's call: the pause between shots

static func run(g: Game) -> void:
	var v := g.vulcan
	var e := g.elvis
	e.input_enabled = false
	e.scripted = true
	e.lock_target = null
	v.scripted = true
	g.hud.show_boss_bar(false)
	g.hud.show_player(false)
	var away := Vector3(v.global_position.x - e.global_position.x, 0.0, v.global_position.z - e.global_position.z)
	away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	var recoil := Vulcan._floor(v.global_position - away * RECOIL)
	g.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).tween_property(e, "global_position", recoil, g.scaled(0.5)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)    # still facing him
	var mid := (recoil + v.global_position) / 2.0
	g.camera.focus(Vector3(mid.x, 0.0, mid.z), g.scaled(FRAME))

	# 1. The crown flies off to one side of him, away from Elvis, and lands on the floor (off the plinth, inside the wall).
	Feel.slow_motion(SLOW, g.scaled(SLOW_TIME))
	# Elvis will stand just north of it to split it, facing the camera as the split sheet is drawn, with the crown in front of him.
	var stand := Vulcan._floor(v.global_position + (away * 0.6 + away.cross(Vector3.UP) * 0.8).normalized() * THROW - Vector3(0.0, 0.0, STAND))
	var land := stand + Vector3(0.0, 0.0, STAND)
	var crown := Crown.new()
	g.add_child(crown)
	crown.fly(v.global_position + Vector3.UP * Vulcan.HEAD, land, g.scaled(FLIGHT))
	Fx.spawn(&"sparks", v.global_position + Vector3.UP * Vulcan.HEAD)
	await crown.landed
	await g.wait(BEAT)

	# 2. He kneels (he already is: play() would restart the finished one-shot); the cracks cool.
	await _ramp(g, v.sprite, &"cool", COOL)

	# 3. The armour burns away texel by texel with ash coming off it; the man kneels under it, one pixel row behind so the armour
	# covers him until it's gone. Then he is the man.
	var under := CharacterSprite.new()
	under.position = Vector3(0.0, 0.0, -1.0 / (Pixel.PX * sin(deg_to_rad(Pixel.PITCH_DEG))))
	v.add_child(under)
	under.load_character("vulcan_human")
	under.play("kneel", v.facing)
	Fx.spawn(&"ash", v.global_position)
	await _ramp(g, v.sprite, &"burn", BURN)
	v.sprite.load_character("vulcan_human")
	v.sprite.set_param(&"burn", 0.0)
	v.sprite.set_param(&"cool", 0.0)
	under.queue_free()

	# 4. The greatsword, at his side away from the crown, tips over toward the camera and lands flat.
	var side := -1.0 if land.x > v.global_position.x else 1.0
	var sword := SwordProp.new()
	g.add_child(sword)
	sword.global_position = Vector3(v.global_position.x + side * 0.7, 0.0, v.global_position.z - 0.3)
	await sword.drop(g.scaled(FALL))
	await g.wait(BEAT)

	# 5. Elvis walks to the crown (through anything in the way: a cutscene walk must arrive) and splits it as his split ends.
	var two := (land + v.global_position) / 2.0
	g.camera.focus(Vector3(two.x, 0.0, two.z), g.scaled(FRAME))    # the crown and the man
	var mask := e.collision_mask
	e.collision_mask = 0
	e.move_to(stand, WALK / g.scaled(1.0))
	await e.arrived
	e.collision_mask = mask
	e.facing = Vector2.DOWN
	await e.play_once("split")
	crown.split()
	Fx.spawn(&"crown_light", Vector3(land.x, 0.6, land.z), Vector3.FORWARD)    # north, over the gate
	Fx.spawn(&"sparks", Vector3(land.x, 0.2, land.z))
	Feel.shake(2.0, 0.15)
	await g.wait(BEAT)

	# 6. The storm clears.
	g.arena.set_mood(&"clear", g.scaled(CLEAR))
	await g.wait(CLEAR)

	# 7. He looks at his hands, then the two lines, the fade and the title card.
	await v.play_once("look_hands")
	g.hud.say("Vulcan", "Who... am I?")
	await g.hud.line_done
	g.hud.say("Elvis", "Whoever you were, you're free.")
	await g.hud.line_done
	g.hud.fade(true, g.scaled(FADE))
	await g.hud.fade_done
	g.hud.title_card("Tales of Vulcan", "To be continued")

# `param` of `s` from 0 to 1 over `seconds` (Game-scaled).
static func _ramp(g: Game, s: CharacterSprite, param: StringName, seconds: float) -> void:
	var tw := g.create_tween()
	tw.tween_method(func(x: float) -> void: s.set_param(param, x), 0.0, 1.0, g.scaled(seconds))
	await tw.finished
