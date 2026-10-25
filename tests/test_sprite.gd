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
