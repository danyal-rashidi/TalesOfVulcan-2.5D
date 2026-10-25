extends TestCase

func test_dir_suffix() -> void:
	check(CharacterSprite.dir_suffix(Vector2(0, 1)) == "F", "(0,1) is F")
	check(CharacterSprite.dir_suffix(Vector2(0, -1)) == "B", "(0,-1) is B")
	check(CharacterSprite.dir_suffix(Vector2(1, 0)) == "S" and not CharacterSprite.flipped(Vector2(1, 0)), "(1,0) is S, not flipped")
	check(CharacterSprite.dir_suffix(Vector2(-1, 0)) == "S" and CharacterSprite.flipped(Vector2(-1, 0)), "(-1,0) is S, flipped")
	check(CharacterSprite.dir_suffix(Vector2(0.6, 0.8)) == "F", "(0.6,0.8) is F")

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
