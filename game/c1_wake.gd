class_name C1Wake
# C1, the statue wakes (STORY.md C1, in Danyal's 24 Oct version: no sword until the flame forms it). Elvis stops, the camera goes to
# the stone Vulcan, the crown glows, the storm rolls in and the sun turns red, lightning bursts the stone, he rises and the flame
# forms his sword; then the camera comes back, the boss bar shows and Elvis has control. Every wait is Game.wait (x0.05 when fast).

const LOOK := 1.5     # Claude's call: s for the camera to reach the statue (C1 shots 1-2: Elvis stops, the crown is dull)
const STORM := 2.0    # the plan: the storm rolls in
const BLOOD := 1.5    # the plan: the sun turns red
const AFTER := 0.6    # Claude's call: a beat with the sword formed before the camera goes back
const BACK := 0.8     # Claude's call: s for the camera to return to Elvis

static func run(g: Game) -> void:
	var v := g.vulcan
	g.elvis.input_enabled = false
	# Both in frame: the crown at the top, Elvis's feet at the bottom. A height h shows as high on screen as h / tan(pitch) of ground depth.
	var e := g.elvis.global_position
	var top := v.global_position.z - (v.global_position.y + Vulcan.HEAD) / tan(deg_to_rad(Pixel.PITCH_DEG))
	g.camera.focus(Vector3((v.global_position.x + e.x) / 2.0, 0.0, (top + e.z) / 2.0), g.scaled(LOOK))
	await g.camera.focus_done
	Fx.spawn(&"crown_glow", v.global_position + Vector3.UP * Vulcan.HEAD)
	g.arena.set_mood(&"storm", g.scaled(STORM))
	await g.wait(STORM)
	g.arena.set_mood(&"blood", g.scaled(BLOOD))
	await g.wait(BLOOD)
	Fx.spawn(&"lightning", v.global_position)
	g.arena.lightning_flash()
	Fx.spawn(&"statue_burst", v.global_position)
	Feel.shake(3.0, 0.3)
	await v.wake_scripted()
	await g.wait(AFTER)
	g.camera.focus(g.elvis.global_position, g.scaled(BACK))
	await g.camera.focus_done
	g.camera.follow(g.elvis)
	g.hud.show_boss_bar(true)
	g.elvis.input_enabled = true
