extends TestCase

func test_dir_suffix() -> void:
	check(CharacterSprite.dir_suffix(Vector2(0, 1)) == "F", "(0,1) is F")
	check(CharacterSprite.dir_suffix(Vector2(0, -1)) == "B", "(0,-1) is B")
	check(CharacterSprite.dir_suffix(Vector2(1, 0)) == "S" and not CharacterSprite.flipped(Vector2(1, 0)), "(1,0) is S, not flipped")
	check(CharacterSprite.dir_suffix(Vector2(-1, 0)) == "S" and CharacterSprite.flipped(Vector2(-1, 0)), "(-1,0) is S, flipped")
	check(CharacterSprite.dir_suffix(Vector2(0.6, 0.8)) == "F", "(0.6,0.8) is F")

# A headless run draws nothing, so this reads the shader itself: stone is worked out from the sheet's colours before the palette pass, and the flash is the last thing written.
# (The same results were compared by eye and pixel by pixel in a real window, before and after the pass was added.)
func test_the_palette_pass_leaves_stone_and_flash_alone() -> void:
	var code := (load("res://core/sprite.gdshader") as Shader).code
	var lum := code.find("float lum = min(sqrt(dot(c.rgb, vec3(0.3, 0.59, 0.11))) * 1.2, 1.0);")
	var pass_ := code.find("palette_pass(")
	var stone := code.find("mix(vec3(0.03, 0.025, 0.025), vec3(0.55, 0.5, 0.47), lum), stone);")
	check(lum > 0 and lum < pass_ and pass_ < stone, "stone comes from the sheet's own brightness (%d %d %d)" % [lum, pass_, stone])
	check(code.contains("c.rgb = mix(own, mix(vec3(0.03"), "at full stone none of the pass is left")
	check(code.contains("own = mix(own, c.rgb, max(hot, ash));"), "the lava and the ash rim keep their colours")
	check(code.strip_edges().ends_with("ALBEDO = mix(c.rgb, vec3(1.0), flash);\n}"), "the flash is written last, white")

# A shadow leans cool, a thing's own colour doesn't: the lean's amount worked out from the shader's own values, on real colours off the sheets.
func test_the_palette_pass_keeps_local_colours() -> void:
	var code := (load("res://core/palette.gdshaderinc") as ShaderInclude).code
	check(code.contains("PAL_SHADE * smoothstep(PAL_SHADE_TOP, 0.04, l) * smoothstep(PAL_VIVID, PAL_VIVID - 0.3, vivid)"), "the lean has both guards")
	var top := _shader_const(code, "PAL_SHADE_TOP")
	var vivid := _shader_const(code, "PAL_VIVID")
	var lean := func(c: Color) -> float:
		var l := 0.3 * c.r + 0.59 * c.g + 0.11 * c.b
		return smoothstep(top, 0.04, l) * smoothstep(vivid, vivid - 0.3, c.s)
	for own: String in ["5a351b", "5a4733", "712c20", "8c2829", "794126", "913031", "423127"]:    # hair, hood, scarf, leather, robe, trousers
		check(lean.call(Color(own)) == 0.0, "%s keeps its own hue" % own)
	check(lean.call(Color("1c1412")) > 0.5, "a true shadow still leans")

# Every shader that draws the world answers to the one switch, and nothing keeps a second one. A headless run draws nothing, so this reads them (the look was compared by eye in a real window, both ways).
func test_the_world_has_one_line_switch() -> void:
	var shared := (load("res://core/palette.gdshaderinc") as ShaderInclude).code
	check(shared.count("const bool PAL_LINE_ON = ") == 1, "the switch is in the palette include, once")
	for path: String in ["res://core/sprite.gdshader", "res://ui/him.gdshader"]:
		check((load(path) as Shader).code.contains("pal_is_line("), "%s trims the line" % path)
	for path: String in ["res://arena/prop.gdshader", "res://arena/prop_unshadowed.gdshader", "res://arena/wall.gdshader"]:
		check((load(path) as Shader).code.contains("pal_is_prop_line("), "%s trims a prop's line" % path)
	check((load("res://core/grass.gdshader") as Shader).code.contains("near < 0.5 || !PAL_LINE_ON"), "the grass draws its own line only with the switch on")
	check((load("res://core/grass.gdshader") as Shader).code.contains("else if (!PAL_LINE_ON)"), "and its own darker edge only with it off")

# The navy ink goes warm, and only that: the rule worked out from the shader's own values on real colours off the sheets.
func test_no_blue_ink_is_left_and_nothing_else_changes() -> void:
	var code := (load("res://core/palette.gdshaderinc") as ShaderInclude).code
	var dark := _shader_const(code, "PAL_BLUE_L")
	var vivid := _shader_const(code, "PAL_BLUE_VIVID")
	var green := _shader_const(code, "PAL_GREEN_VIVID")
	var inked := func(hex: String) -> bool:
		var c := Color(hex)
		var hi := maxf(c.r, maxf(c.g, c.b))
		var how := (hi - minf(c.r, minf(c.g, c.b))) / maxf(hi, 0.01)
		return 0.3 * c.r + 0.59 * c.g + 0.11 * c.b < dark and ((c.b >= hi and c.b > c.r and how >= vivid) or (c.g >= hi and c.g > c.r and how >= green))
	for ink: String in ["0e1628", "0d0d14", "0e0e15", "0e0d13", "201722", "1d1624", "0a2209", "062407"]:    # the sheets' navy, the camel's and the scorpion's, the carriage's green fringe
		check(inked.call(ink), "%s goes warm" % ink)
	for own: String in ["121118", "1e2a3d", "243b57", "171b1f", "222224", "0c180e", "1a0e10", "140e10", "804e2e", "5a351b"]:    # his beard, Elvis's cloak, the boss's armour, a villager's green, warm darks, his nose, his hair
		check(not inked.call(own), "%s keeps its colour" % own)

# Trimming the line takes dark on the very edge, and no more: pal_is_line's rule, on a little picture.
func test_the_line_rule_leaves_what_is_not_line() -> void:
	var rows: Array[String] = [
		"..#.......",    # 0: the end of a dark run one wide, which stays
		"..#.......",
		"..#..##...",    # 2: a bump on the line, which goes
		".#########",
		".#ooooooo#",
		".#oo#oooon",    # 5: an eye inside it stays, and a brown nose on the edge stays
		".#ooooooo#",
		".#########"]
	var img := Image.create(10, 8, false, Image.FORMAT_RGBA8)
	for y in rows.size():
		for x in 10:
			var ch := rows[y][x]
			if ch != ".":
				img.set_pixel(x, y, {"#": Color("0e1628"), "o": Color("ba7446"), "n": Color("804e2e")}[ch])
	var limit := _shader_const((load("res://core/palette.gdshaderinc") as ShaderInclude).code, "PAL_LINE_L")
	var ink := _shader_const((load("res://core/palette.gdshaderinc") as ShaderInclude).code, "PAL_INK_L")
	var is_line := func(x: int, y: int) -> bool: return _line_rule(img, x, y, limit, ink)
	check(not is_line.call(2, 0) and not is_line.call(2, 1) and not is_line.call(2, 2), "a dark run one wide is all there is of that thing: it stays")
	check(is_line.call(1, 4) and is_line.call(5, 7) and is_line.call(9, 4) and is_line.call(1, 3), "the line goes, down its sides and round its corners")
	check(is_line.call(5, 2) and is_line.call(6, 2), "a bump on the line goes")
	check(not is_line.call(4, 5), "an eye inside the line stays")
	check(not is_line.call(9, 5), "a nose in the line stays: it's brown")
	check(not is_line.call(3, 4), "the art inside stays")
	var brown := Color("804e2e")
	check(0.3 * brown.r + 0.59 * brown.g + 0.11 * brown.b >= limit, "his nose is brighter than the line")

# The black line just inside the rim goes only with lit art right behind it, so his body loses it and nothing else does.
func test_the_black_line_goes_only_in_front_of_lit_art() -> void:
	var rows: Array[String] = [
		"#####.####",
		"KKKKK.KKo#",    # 1: black with 3 lit texels behind it, and on the right black with only one
		"ooooo.##.#",
		"ooooo.....",
		"ooooo.....",
		"hKhKh.....",    # 5: his beard over a mouth: black, with no rim beside it
		"hhhhh.....",
		"#####....."]
	var img := Image.create(10, 8, false, Image.FORMAT_RGBA8)
	for y in rows.size():
		for x in 10:
			var ch := rows[y][x]
			if ch != ".":
				img.set_pixel(x, y, {"#": Color("121118"), "K": Color("030101"), "o": Color("ba7446"), "h": Color("262226")}[ch])
	var code := (load("res://core/palette.gdshaderinc") as ShaderInclude).code
	var limit := _shader_const(code, "PAL_LINE_L")
	var ink := _shader_const(code, "PAL_INK_L")
	check(_line_rule(img, 2, 1, limit, ink), "black in front of art goes")
	check(not _line_rule(img, 7, 1, limit, ink), "on something thin it stays")
	check(not _line_rule(img, 2, 2, limit, ink), "the art stays")
	check(not _line_rule(img, 1, 5, limit, ink), "a mouth stays")

# Every colour of his approved face stays on his own idle sheets, whichever view: only his line goes.
func test_his_face_stays() -> void:
	var limit := _shader_const((load("res://core/palette.gdshaderinc") as ShaderInclude).code, "PAL_LINE_L")
	var ink := _shader_const((load("res://core/palette.gdshaderinc") as ShaderInclude).code, "PAL_INK_L")
	for sheet: String in ["idle_F", "idle_S"]:
		var img := Image.load_from_file("res://art/vulcan_human/%s.png" % sheet).get_region(Rect2i(0, 0, 96, 62))
		var kept := {"pupil": 0, "white": 0, "nose": 0}
		var lost := {"pupil": 0, "white": 0, "nose": 0}
		for y in 62:
			for x in 96:
				var c := img.get_pixel(x, y)
				if c.a < 0.5:
					continue
				var what: String = {"1a1416": "pupil", "ece4d0": "white", "804e2e": "nose"}.get(c.to_html(false), "")
				if what != "":
					if _line_rule(img, x, y, limit, ink):
						lost[what] += 1
					else:
						kept[what] += 1
		check(kept["pupil"] > 0 and kept["white"] > 0, "%s has its eyes (%s)" % [sheet, kept])
		check(lost["pupil"] == 0 and lost["white"] == 0 and lost["nose"] == 0, "%s keeps every one of them (%s)" % [sheet, lost])

# A prop's ring is its one exact colour on the edge, one texel, and the art's dark edge goes with it wherever lit art is close behind, at any size. The art inside stays, however thin or dark, and so does the crease where two rings met and a dark thing with no lit art by it.
func test_a_prop_loses_its_ring_and_not_its_art() -> void:
	var rows: Array[String] = [
		"..RRR.....",
		".RsdsR....",    # 1-3: a thin blade with dark art of its own down its middle
		".RsdsR....",
		".RsdsR....",
		"..RRR.....",
		"RRRRRRR...",
		"RoooooR...",
		"RRRRRRR...",    # 7: two rings met here, between two pieces of art
		"RoooooR...",
		"RRRRRRR..."]
	var img := Image.create(10, 10, false, Image.FORMAT_RGBA8)
	for y in rows.size():
		for x in 10:
			if rows[y][x] != ".":
				img.set_pixel(x, y, {"R": Color("140e10"), "s": Color("888e9a"), "d": Color("231a1d"), "o": Color("ba7446")}[rows[y][x]])
	var limit := _shader_const((load("res://core/palette.gdshaderinc") as ShaderInclude).code, "PAL_PROP_LINE_L")
	check(_prop_rule(img, 1, 1, limit) and _prop_rule(img, 3, 0, limit), "the ring goes")
	check(not _prop_rule(img, 3, 7, limit), "where two met, the crease stays")
	check(not _prop_rule(img, 3, 2, limit), "dark art inside stays")
	check(not _prop_rule(img, 2, 2, limit), "lit art on the edge stays")
	var art := Image.create(30, 30, false, Image.FORMAT_RGBA8)
	art.fill_rect(Rect2i(5, 5, 12, 12), Color("ba7446"))
	art.fill_rect(Rect2i(5, 5, 1, 12), Color("0f1911"))    # the art's near-black edge (tomb_small's) on a small picture
	art.fill_rect(Rect2i(16, 5, 1, 12), Color("2a2122"))    # and its lighter one (house_mud's), on a picture of any size
	art.fill_rect(Rect2i(17, 8, 1, 1), Color("2a2122"))    # a step on the line, with only dark straight behind it
	art.fill_rect(Rect2i(24, 5, 2, 20), Color("231a1d"))    # a dark post, 2 wide, nothing lit by it
	check(_prop_rule(art, 5, 10, limit), "the art's near-black edge goes")
	check(_prop_rule(art, 16, 10, limit), "and its lighter one")
	check(_prop_rule(art, 17, 8, limit), "and a step on it, or it would be left as a speck")
	check(not _prop_rule(art, 24, 10, limit) and not _prop_rule(art, 25, 10, limit), "a dark post stays")
	var wheel := Image.create(30, 30, false, Image.FORMAT_RGBA8)
	wheel.fill_rect(Rect2i(2, 2, 26, 26), Color("ba7446"))
	wheel.fill_rect(Rect2i(12, 12, 4, 4), Color(0, 0, 0, 0))    # a hole between its spokes
	wheel.fill_rect(Rect2i(11, 12, 1, 4), Color("2a2122"))
	check(not _prop_rule(wheel, 11, 13, limit), "a hole's dark edge stays, or the spokes go")

# pal_is_line in core/palette.gdshaderinc, for the tests above.
func _line_rule(img: Image, x: int, y: int, limit: float, ink: float) -> bool:
	var lum := func(px: int, py: int) -> float:
		var c := img.get_pixel(px, py)
		return 0.3 * c.r + 0.59 * c.g + 0.11 * c.b
	var solid := func(px: int, py: int) -> bool: return px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height() and img.get_pixel(px, py).a >= 0.5
	var lit := func(px: int, py: int) -> bool: return solid.call(px, py) and lum.call(px, py) >= limit
	var thin := func(px: int, py: int, dx: int, dy: int) -> bool: return solid.call(px, py) and not solid.call(px + dx, py + dy) and not solid.call(px - dx, py - dy)
	var rim := func(px: int, py: int) -> bool:
		if not solid.call(px, py) or lum.call(px, py) >= limit:
			return false
		if solid.call(px + 1, py) and solid.call(px - 1, py) and solid.call(px, py + 1) and solid.call(px, py - 1):
			return false
		if thin.call(px, py, 1, 0) and (thin.call(px, py + 1, 1, 0) or thin.call(px, py - 1, 1, 0)):
			return false
		return not (thin.call(px, py, 0, 1) and (thin.call(px + 1, py, 0, 1) or thin.call(px - 1, py, 0, 1)))
	if rim.call(x, y):
		return true
	if not solid.call(x, y) or lum.call(x, y) >= ink:
		return false
	for d: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		if lit.call(x - d.x, y - d.y) and lit.call(x - 2 * d.x, y - 2 * d.y) and lit.call(x - 3 * d.x, y - 3 * d.y) and solid.call(x + d.x, y + d.y) and rim.call(x + d.x, y + d.y):
			return true
	return false

# pal_is_prop_line in core/palette.gdshaderinc.
func _prop_rule(img: Image, x: int, y: int, limit: float) -> bool:
	var solid := func(px: int, py: int) -> bool: return px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height() and img.get_pixel(px, py).a >= 0.5
	var exact := func(px: int, py: int) -> bool: return solid.call(px, py) and img.get_pixel(px, py).to_html(false) in ["140e10", "0e1628"]
	var ring := func(px: int, py: int) -> bool: return exact.call(px, py) and not (solid.call(px + 1, py) and solid.call(px - 1, py) and solid.call(px, py + 1) and solid.call(px, py - 1))
	var lum := func(px: int, py: int) -> float:
		var c := img.get_pixel(px, py)
		return 0.3 * c.r + 0.59 * c.g + 0.11 * c.b
	if not solid.call(x, y) or lum.call(x, y) >= limit:
		return false
	if ring.call(x, y):
		return true
	var off := func(px: int, py: int) -> bool: return not solid.call(px, py) or ring.call(px, py)
	var edge := false
	for d: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		if off.call(x + d.x, y + d.y):
			var gap := false
			for k in range(2, 7):
				gap = gap or not off.call(x + k * d.x, y + k * d.y)
			edge = edge or not gap
	if not edge:
		return false
	var lit := 0
	for py in range(y - 2, y + 3):
		for px in range(x - 2, x + 3):
			if solid.call(px, py) and lum.call(px, py) >= limit:
				lit += 1
	return lit >= 3

func _shader_const(code: String, const_name: String) -> float:
	var at := code.find("const float %s = " % const_name)
	check(at >= 0, "%s is in the shader" % const_name)
	return code.substr(at).get_slice("=", 1).get_slice(";", 0).to_float()

func test_missing_character_falls_back() -> void:
	var s := CharacterSprite.new()
	add_child(s)
	s.load_character("nope")
	s.play("roll", Vector2.DOWN)
	check(s.character == "nope", "character keeps the requested name")
	check(s.current_key != "", "a key is playing")
	check((s.get_node("Sprite3D") as Sprite3D).texture != null, "a texture is set")

func test_missing_direction_falls_back() -> void:
	var s := CharacterSprite.new()
	add_child(s)
	s.load_character("standin")
	s.play("idle", Vector2.UP)
	check(s.current_key == "idle_F", "idle_B falls back to idle_F (got %s)" % s.current_key)

# play_timed stretches the art to the code's time, and ends with `finished` even on a looping fallback.
func test_play_timed_lasts_the_asked_time() -> void:
	var s := CharacterSprite.new()
	add_child(s)
	s.load_character("nope")
	var done: Array[bool] = [false]
	s.finished.connect(func(_k: String) -> void: done[0] = true)
	s.play_timed("roll", Vector2.DOWN, 0.5)
	var t := 0.0
	while not done[0] and t < 2.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	near(t, 0.5, 0.05, "the one-shot lasts 0.5 s")
	check(s.active_window(s.current_key) == Vector2i(-1, -1), "the stand-in has no hit frames")

# Task 5: a walk or sprint with no sheet of its own plays the character's own run (then the stand-in's walk), so he stays himself.
# A made-up character in the sprite's caches, so the test doesn't depend on which sheets the art lane has made.
func test_walk_falls_back_to_own_run() -> void:
	var tex := ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))
	CharacterSprite._manifests["_runner"] = {"cell": [4, 4], "anims": {"run_F": {"file": "run_F.png"}, "run_S": {"file": "run_S.png"}, "idle_F": {"file": "idle_F.png"}}}
	for f in ["run_F", "run_S", "idle_F"]:
		CharacterSprite._textures["res://art/_runner/%s.png" % f] = tex
	var s := CharacterSprite.new()
	add_child(s)
	s.load_character("_runner")
	s.play("walk", Vector2.RIGHT)
	check(s.current_key == "run_S", "walk_S falls back to run_S (got %s)" % s.current_key)
	s.play("sprint", Vector2.UP)
	check(s.current_key == "run_F", "sprint_B falls back to run_F (got %s)" % s.current_key)
	s.load_character("standin")
	s.play("walk", Vector2.DOWN)
	check(s.current_key == "walk_F", "the stand-in's own walk (got %s)" % s.current_key)
	CharacterSprite._manifests.erase("_runner")
	# Task 6: with no run at all, a real character glides in its own idle rather than turn into the stand-in.
	CharacterSprite._manifests["_still"] = {"cell": [4, 4], "anims": {"idle_F": {"file": "idle_F.png"}}}
	CharacterSprite._textures["res://art/_still/idle_F.png"] = tex
	s.load_character("_still")
	s.play("run", Vector2.DOWN)
	check(s.current_key == "idle_F" and s._key_src == "_still", "no run: its own idle (got %s/%s)" % [s._key_src, s.current_key])
	CharacterSprite._manifests.erase("_still")
	# Task 6 review: a move with no sheet shows the idle of the way he faces, not the front one.
	CharacterSprite._manifests["_turner"] = {"cell": [4, 4], "anims": {"idle_F": {"file": "idle_F.png"}, "idle_B": {"file": "idle_B.png"}, "idle_S": {"file": "idle_S.png"}}}
	for f in ["idle_F", "idle_B", "idle_S"]:
		CharacterSprite._textures["res://art/_turner/%s.png" % f] = tex
	s.load_character("_turner")
	s.play("lunge", Vector2.UP)
	check(s.current_key == "idle_B", "lunge_B with no sheet: idle_B (got %s)" % s.current_key)
	s.play("roll", Vector2.LEFT)
	check(s.current_key == "idle_S" and (s.get_node("Sprite3D") as Sprite3D).flip_h, "roll left with no sheet: idle_S flipped (got %s)" % s.current_key)
	CharacterSprite._manifests.erase("_turner")

# Task 6: a key with "below": N draws its bottom N rows over the floor, and the feet line stays on the feet's screen pixel.
func test_below_keeps_feet_on_their_pixel() -> void:
	var tex := ImageTexture.create_from_image(Image.create(4, 40, false, Image.FORMAT_RGBA8))
	CharacterSprite._manifests["_thrust"] = {"cell": [4, 40], "anims": {"idle_F": {"file": "idle_F.png"}, "thrust_F": {"file": "thrust_F.png", "below": 12}}}
	for f in ["idle_F", "thrust_F"]:
		CharacterSprite._textures["res://art/_thrust/%s.png" % f] = tex
	var s := CharacterSprite.new()
	add_child(s)
	s.load_character("_thrust")
	var s3 := s.get_node("Sprite3D") as Sprite3D
	var a := deg_to_rad(Pixel.PITCH_DEG)
	var up := Vector3(0.0, cos(a), -sin(a)) * Pixel.PX    # screen pixels up, per metre
	var half := 20.0 / Pixel.PX * Pixel.sprite_scale_y()  # half the cell, in metres
	var feet := s3.global_position - Vector3.UP * half    # idle: the feet are the cell's bottom
	s.play("thrust", Vector2.DOWN)
	check(s.current_key == "thrust_F", "thrust_F plays (got %s)" % s.current_key)
	var bottom := s3.global_position - Vector3.UP * half
	var line := bottom + Vector3.UP * 12.0 / Pixel.PX * Pixel.sprite_scale_y()
	near(line.dot(up), feet.dot(up), 0.001, "the feet line on the feet's screen row")
	near(line.x, feet.x, 0.0001, "and the same column")
	near(bottom.y, 0.0, 0.0001, "the cell's bottom on the floor, not under it")
	near(s3.global_position.z * Pixel.PX * sin(a), 12.0, 0.001, "12 ground pixels toward the camera, on the grid")
	CharacterSprite._manifests.erase("_thrust")

# Facing left his right hand is the front one. He has his own spear sheets: a mirror would put it in his other hand.
func test_left_sheet_keeps_his_hand() -> void:
	var s := CharacterSprite.new()
	add_child(s)
	s.load_character("elvis_blue")
	var pic := s.get_node("Sprite3D") as Sprite3D
	s.play("idle_spear", Vector2.LEFT)
	check(s.current_key == "idle_spear_L" and not pic.flip_h, "with the spear, facing left plays his own sheet (%s)" % s.current_key)
	s.play("idle_spear", Vector2.RIGHT)
	check(s.current_key == "idle_spear_S" and not pic.flip_h, "facing right plays the side sheet (%s)" % s.current_key)
	s.play("idle", Vector2.LEFT)
	check(s.current_key == "idle_S" and pic.flip_h, "empty-handed there is no hand to keep: the mirror (%s)" % s.current_key)
	for a in ["light1", "light2", "light3", "light4", "lunge", "thrust"]:
		check(s.active_window(a + "_L") == s.active_window(a + "_S") and s.active_window(a + "_L") != Vector2i(-1, -1), "%s hits on the same frames either way" % a)
	var left := Image.load_from_file("res://art/elvis_blue/idle_spear_L.png")
	var empty := Image.load_from_file("res://art/elvis_blue/idle_S.png").get_region(Rect2i(0, 0, 128, 76))
	empty.flip_x()
	var spear := 0
	var changed := 0
	for y in 76:
		for x in 128:
			var want := empty.get_pixel(x, y)
			if want.a > 0.0:
				changed += int(left.get_pixel(x, y) != want)
			else:
				spear += int(left.get_pixel(x, y).a > 0.0)
	check(changed == 0, "standing, his body is the empty-handed one, back hand free (%d px off)" % changed)
	check(spear > 40, "the spear shows either side of him (%d px)" % spear)
	s.queue_free()
