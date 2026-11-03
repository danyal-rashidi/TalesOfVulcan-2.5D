extends TestCase
# The effects from pixelfx (art/tools/pixelfx_sheets.py): whole sheets of hard pixels, and the spear's wake that stays where it was left.

const ELVIS := preload("res://player/elvis.tscn")
const SHEETS := {
	"res://art/pixelfx/ice_splash.png": preload("res://fx/ice_splash.gd").FRAMES,
	"res://art/pixelfx/ice_wake.png": FxIceWake.FRAMES,
	"res://art/pixelfx/hammer_impact.png": preload("res://fx/hammer_blow.gd").FRAMES,
	"res://art/pixelfx/hammer_impact_fire.png": preload("res://fx/hammer_blow.gd").FRAMES,
}

func test_the_sheets_are_whole_and_hard() -> void:
	for path: String in SHEETS:
		var img := Image.load_from_file(path)
		var frames: int = SHEETS[path]
		check(img.get_width() % frames == 0, "%s divides into %d frames" % [path, frames])
		var cell := img.get_width() / frames
		var soft := 0
		var cut := 0
		for x in img.get_width():
			for y in img.get_height():
				var a := img.get_pixel(x, y).a
				if a > 0.0 and a < 1.0:
					soft += 1
				if a > 0.0 and (x % cell == 0 or x % cell == cell - 1 or y == 0 or y == img.get_height() - 1):
					cut += 1
		check(soft == 0, "%s has no soft pixels (%d)" % [path, soft])
		check(cut == 0, "%s reaches no cell's edge, so nothing is cut and the frame count is right (%d)" % [path, cut])

func test_the_ring_reaches_the_edge_of_the_blow() -> void:
	var img := Image.load_from_file("res://art/pixelfx/hammer_impact.png")
	var cell := img.get_width() / preload("res://fx/hammer_blow.gd").FRAMES
	var reach := preload("res://fx/hammer_blow.gd").RADIUS * Pixel.PX
	check(cell / 2.0 >= reach, "wide enough for the disc (%d px against %s)" % [cell, reach])

func test_only_the_upgraded_hammer_has_fire() -> void:
	check(not _has(Image.load_from_file("res://art/pixelfx/hammer_impact.png"), Color8(232, 104, 30)), "plain: no fire")
	check(_has(Image.load_from_file("res://art/pixelfx/hammer_impact_fire.png"), Color8(232, 104, 30)), "upgraded: fire")

# Its fire was once only in the first few frames, and from then on it was the plain blow with red cracks.
func test_the_upgraded_blow_still_burns_late_on() -> void:
	var img := Image.load_from_file("res://art/pixelfx/hammer_impact_fire.png")
	var cell := img.get_width() / preload("res://fx/hammer_blow.gd").FRAMES
	for frame: int in [6, 10, 14]:
		var drawn := 0
		var fire := 0
		for x in range(frame * cell, (frame + 1) * cell):
			for y in img.get_height():
				var c := img.get_pixel(x, y)
				if c.a > 0.0:
					drawn += 1
					if c.r > 0.75 and c.g < 0.88 and c.b < 0.43:    # bright orange, red and yellow, not soot or sand
						fire += 1
		check(fire * 2 > drawn, "frame %d is mostly fire (%d of %d)" % [frame, fire, drawn])

func _has(img: Image, c: Color) -> bool:
	for x in img.get_width():
		for y in img.get_height():
			if img.get_pixel(x, y).a > 0.0 and img.get_pixel(x, y).is_equal_approx(c):
				return true
	return false

func test_the_wake_stays_where_it_was_left_and_goes_after_its_spear() -> void:
	Journey.reset()
	var e := ELVIS.instantiate() as Elvis
	add_child(e)
	await get_tree().physics_frame
	var spear := Fx.spawn(&"ice_spear", Vector3(0.0, 2.0, 0.0), Vector3.ZERO, Hitbox.TEAM_PLAYER, HitInfo.new()) as FxIceSpear
	spear.stands_for(e, 0.0)
	var wake := Fx.spawn(&"ice_wake", Vector3.ZERO) as FxIceWake
	wake.follow(spear)
	for i in 3:
		await get_tree().physics_frame
	check(wake._stamps.size() >= 3 and wake._stamps[0].visible, "one a physics frame (%d)" % wake._stamps.size())
	var left := wake._stamps[0].global_position
	spear.global_position += Vector3(1.0, 0.0, 0.0)
	await get_tree().physics_frame
	check(wake._stamps[0].global_position == left, "a stamp doesn't follow the spear")
	check(wake._stamps[wake._stamps.size() - 1].global_position != left, "a new one does")
	spear.end()
	await get_tree().physics_frame
	check(is_instance_valid(wake) and not wake.is_queued_for_deletion(), "it stays a moment after the spear has hit")
	for i in 60:
		await get_tree().physics_frame
	check(not is_instance_valid(wake) or wake.is_queued_for_deletion(), "then it goes")
	e.queue_free()
	Fx.clear_all()
