extends TestCase
# Footprints: every stamp fits the pixel grid, steps are even at any speed and as long as the sheets' strides, a diagonal walk leaves diagonal prints, left and right mirror.

class Walker extends Node3D:
	var sprite: CharacterSprite

var _puffs := 0

# Drives one Steps along a straight line, a tick at a time, and returns what it left, oldest first: {at, tex, scale, start}. The sand it kicked up is counted in _puffs.
func _walk(character: String, way: Vector3, speed: float, metres: float, high := 0.0) -> Array[Dictionary]:
	var body := Walker.new()
	body.sprite = CharacterSprite.new()
	body.add_child(body.sprite)
	add_child(body)
	body.position.y = high
	body.sprite.load_character(character)
	var steps := Steps.new()
	body.add_child(steps)
	steps.set_physics_process(false)
	var dt := 1.0 / 60.0
	steps._physics_process(dt)    # standing, to begin with
	for i in ceili(metres / (speed * dt)):
		body.global_position += way * speed * dt
		steps._physics_process(dt)
	var out: Array[Dictionary] = []
	for n in get_children():
		if n is Steps.FootPrint:
			out.append({"at": n.global_position, "tex": n.texture, "scale": n.scale, "start": n.start})
		_puffs += 1 if n is FxEffect else 0
		if n is Steps.FootPrint or n is FxEffect:
			n.free()
	body.free()
	return out

func test_every_stamp_is_even_so_it_sits_on_the_grid() -> void:
	for shape: String in Steps.SHAPES:
		for size: float in [1.0, 0.5]:
			for i in Steps.DIRS:
				for foot: float in [1.0, -1.0]:
					var t := Steps.stamp(shape, Vector2.from_angle(i * TAU / Steps.DIRS), foot, size)
					check(t.get_width() % 2 == 0 and t.get_height() % 2 == 0, "%s %d is %dx%d" % [shape, i, t.get_width(), t.get_height()])

func test_a_stamp_is_painted_once() -> void:
	check(Steps.stamp("boot", Vector2.RIGHT, 1.0) == Steps.stamp("boot", Vector2.RIGHT * 3.0 + Vector2.UP * 0.1, 1.0), "the same way gives the same picture")
	check(Steps.stamp("boot", Vector2.RIGHT, 1.0) != Steps.stamp("boot", Vector2.RIGHT, -1.0), "not across feet")

func test_steps_are_even_at_any_speed() -> void:
	var ways: Array[Vector3] = [Vector3.RIGHT, Vector3.FORWARD, Vector3(1.0, 0.0, 1.0).normalized(), Vector3(0.6, 0.0, -0.8)]
	for speed: float in [1.6, 3.0, 4.37, 6.0, 7.5]:
		for way in ways:
			var prints := _walk("vulcan_human", way, speed, 30.0)
			check(prints.size() == 25, "%.1f m/s: a step each 1.2 m (%d)" % [speed, prints.size()])
			var grid := absf(way.x) / Pixel.PX + absf(way.z) / 24.0    # each end is snapped, half a pixel at most
			for i in range(1, prints.size()):
				near((prints[i]["at"] - prints[i - 1]["at"]).dot(way), 1.2, grid + 0.001, "%.1f m/s going %s, step %d" % [speed, way, i])

func test_left_and_right_alternate_either_side_of_his_line() -> void:
	var prints := _walk("vulcan_human", Vector3.RIGHT, 3.0, 12.0)
	for i in range(1, prints.size()):
		check(signf(prints[i]["at"].z) == -signf(prints[i - 1]["at"].z), "step %d crosses over" % i)
		check(prints[i]["tex"] != prints[i - 1]["tex"], "and is the other foot")

func _hollow(tex: Texture2D, x: int, y: int) -> bool:
	var a := tex.get_image().get_pixel(x, y).a
	return a > Steps.LIP_COLOUR.a + 0.05

func test_left_and_right_mirror() -> void:
	for shape: String in Steps.SHAPES:
		for way: Vector2 in [Vector2.RIGHT, Vector2.LEFT]:
			var a := Steps.stamp(shape, way, 1.0)
			var b := Steps.stamp(shape, way, -1.0)
			var same := a.get_size() == b.get_size()
			for y in a.get_height():
				for x in a.get_width():
					same = same and _hollow(a, x, y) == _hollow(b, x, a.get_height() - 1 - y)
			check(same, "%s: one foot is the other flipped over his line" % shape)

# The long axis of the hollow, measured in metres on the ground.
func _axis(tex: Texture2D) -> float:
	var at := PackedVector2Array()
	var mid := Vector2.ZERO
	for y in tex.get_height():
		for x in tex.get_width():
			if _hollow(tex, x, y):
				at.append(Vector2(x / Arena.TPM.x, y / Arena.TPM.y))
				mid += at[-1]
	mid /= at.size()
	var xx := 0.0
	var zz := 0.0
	var xz := 0.0
	for p in at:
		xx += (p.x - mid.x) ** 2
		zz += (p.y - mid.y) ** 2
		xz += (p.x - mid.x) * (p.y - mid.y)
	return 0.5 * atan2(2.0 * xz, xx - zz)

func test_a_print_points_the_way_it_went() -> void:
	for shape: String in ["sandal", "boot", "big_boot", "shoe"]:
		for i in Steps.DIRS:
			var a := i * TAU / Steps.DIRS
			var off := absf(angle_difference(2.0 * _axis(Steps.stamp(shape, Vector2.from_angle(a), 1.0)), 2.0 * a)) / 2.0
			check(off < 0.35, "%s going %d is off by %.2f rad" % [shape, i, off])

func test_it_lands_on_the_grid_at_one_screen_pixel_a_texel() -> void:
	var prints := _walk("elvis_blue", Vector3(0.6, 0.0, 0.8), 5.0, 8.0)
	check(prints.size() >= 5, "it left prints")
	for s in prints:
		near(s["scale"].z, 4.0 / 3.0, 1e-5, "24 px a metre that way")
		var p: Vector3 = s["at"]
		near(fposmod(p.x * Pixel.PX + 0.5, 1.0), 0.5, 1e-3, "x on a screen pixel")
		near(fposmod(p.z * 24.0 + 0.5, 1.0), 0.5, 1e-2, "z on a screen pixel")

# Seconds for one loop of a sheet, from its manifest.
func _loop(character: String, key: String) -> float:
	var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/%s/manifest.json" % character))
	return float(m["anims"][key]["frames"]) / float(m["anims"][key]["fps"])

func test_strides_are_the_sheets_own() -> void:
	# character, its moving sheet, the speed it plays at, feet to a loop (a run on four legs lands four)
	for w: Array in [["vulcan_human", "run_S", 3.0, 2], ["elvis_blue", "run_S", 5.0, 2], ["jackal", "run_S", Jackal.SPEED, 4], ["scorpion", "walk_S", 2.4, 2],
			["raider_sword", "walk_S", 3.0, 2], ["varro", "walk_S", 3.0, 2], ["cassia", "walk_S", Townsperson.SPEED, 2], ["livia", "walk_S", Townsperson.SPEED, 2],
			["livia_boy", "walk_S", Townsperson.SPEED, 2], ["tullus", "walk_S", Townsperson.SPEED, 2], ["fortuna", "walk_S", Townsperson.SPEED, 2], ["carriage_pull", "walk_S", CassiaScene.PULL, 2]]:
		near(Steps.WHO[w[0]][1], w[2] * _loop(w[0], w[1]) / w[3], 0.011, w[0])
	near(Steps.WHO["vulcan_human"][1] * Steps.RUN_STRIDE, 6.0 * _loop("vulcan_human", "sprint_S") / 2.0, 0.011, "his sprint")
	var boss: float = Steps.WHO["vulcan_boss"][1]
	check(boss > Vulcan.PACE_SPEED * _loop("vulcan_boss", "run_S") / 2.0 - 0.1 and boss < Vulcan.APPROACH_SPEED * _loop("vulcan_boss", "run_S") / 2.0 + 0.1, "the boss, between his two paces (%s)" % boss)

func test_nothing_prints_while_he_is_in_the_air() -> void:
	var body := Walker.new()
	body.sprite = CharacterSprite.new()
	body.add_child(body.sprite)
	add_child(body)
	body.sprite.load_character("vulcan_human")
	body.sprite.position.y = 1.0
	var steps := Steps.new()
	body.add_child(steps)
	steps.set_physics_process(false)
	for i in 60:
		body.global_position += Vector3.RIGHT * 0.1
		steps._physics_process(1.0 / 60.0)
	check(get_children().filter(func(n: Node) -> bool: return n is Steps.FootPrint).is_empty(), "a leap leaves none")
	body.free()

func test_nothing_prints_while_his_body_is_in_the_air() -> void:
	check(_walk("vulcan_boss", Vector3.RIGHT, 6.0, 8.0, 2.4).is_empty(), "the boss's dive raises his body, not his sprite")
	check(_walk("vulcan_boss", Vector3.RIGHT, 6.0, 8.0, 0.6).is_empty(), "as his hop off the plinth does")
	check(not _walk("vulcan_boss", Vector3.RIGHT, 6.0, 8.0).is_empty(), "on the ground he does print")

func test_the_arena_floor_is_stone_where_slabs_are_painted() -> void:
	var a: Arena = load("res://arena/arena.tscn").instantiate()
	add_child(a)
	var painted: Image = Arena._tex[&"floor"].get_image()
	var agree := 0
	var seen := 0
	for j in range(0, painted.get_height(), 5):
		for i in range(0, painted.get_width(), 5):
			var c := painted.get_pixel(i, j)
			var grey := maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b)) < 0.2    # stone is duller than the sand, and the sand is well over this
			agree += 1 if grey == a._on_stone((i + 0.5) / Arena.TPM.x - Arena.FLOOR_M / 2.0, (j + 0.5) / Arena.TPM.y - Arena.FLOOR_M / 2.0) else 0
			seen += 1
	check(agree > seen * 0.97, "the test agrees with the painted floor (%d of %d)" % [agree, seen])
	check(not a._on_stone(Arena.FLOOR_M, 0.0) and not a._on_stone(0.0, -Arena.FLOOR_M), "past the painted floor it's sand")
	var prints := _walk("elvis_blue", Vector3.RIGHT, 5.0, 11.0)    # out from the plinth's ring over the sand
	var faint := prints.filter(func(s: Dictionary) -> bool: return s["start"] < 1.0).size()
	check(faint > 0 and faint < prints.size(), "he crossed both (%d of %d on stone)" % [faint, prints.size()])
	check(_puffs == prints.size() - faint, "sand flies off the sand only (%d puffs)" % _puffs)
	a.free()

func test_a_sprint_takes_longer_steps_only_on_its_own_sheet() -> void:
	var body := Walker.new()
	body.sprite = CharacterSprite.new()
	body.add_child(body.sprite)
	add_child(body)
	body.sprite.load_character("vulcan_human")
	body.sprite.play("sprint", Vector2.RIGHT)
	var steps := Steps.new()
	body.add_child(steps)
	steps.set_physics_process(false)
	for i in 120:
		body.global_position += Vector3.RIGHT * 0.1
		steps._physics_process(1.0 / 60.0)
	var prints := get_children().filter(func(n: Node) -> bool: return n is Steps.FootPrint)
	near((prints[1].global_position - prints[0].global_position).x, 1.2 * Steps.RUN_STRIDE, 0.04, "the sprint sheet's step")
	body.free()

func test_the_opening_runs_him_at_his_own_stride() -> void:
	near(Opening.RUN_LOOP, _loop("elvis_blue", "run_S"), 0.001, "it plays his sheet at the sheet's own speed")
	near(Opening.WALK_SPEED * Opening.RUN_LOOP / 2.0, Opening.STEP_PX, 1e-3, "the ground goes by a step's length in half a loop")
	check(Opening.STEP_PX == roundf(Opening.STEP_PX), "whole pixels, so prints stay locked to the sand")
