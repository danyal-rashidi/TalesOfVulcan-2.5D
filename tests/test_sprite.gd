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
