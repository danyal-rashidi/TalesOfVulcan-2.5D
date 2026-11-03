extends TestCase

const ARENA := preload("res://arena/arena.tscn")
const ELVIS := preload("res://player/elvis.tscn")

func test_entrance_inside() -> void:
	var a := _arena()
	var d := Vector2(a.entrance().x, a.entrance().z).length()
	check(Arena.RADIUS - 3.0 < d and d < Arena.RADIUS, "the entrance is inside the floor, near the wall (%s m from the centre)" % d)

func test_cracks_capped() -> void:
	var a := _arena()
	for i in 30:
		a.crack(Vector3(randf_range(-8.0, 8.0), 0.0, randf_range(-8.0, 8.0)), randf_range(0.6, 3.0))
	check(a.crack_count() <= 24, "at most 24 cracks kept (got %d)" % a.crack_count())
	a.clear_cracks()
	check(a.crack_count() == 0, "clear_cracks leaves none (got %d)" % a.crack_count())

func test_mood_blood_is_red() -> void:
	var a := _arena()
	a.set_mood(&"blood", 0.0)
	var c := a.sun.light_color
	check(c.r > 1.5 * c.g, "the blood mood's sun is red (got %s)" % c)

# The one table: every mood has all its light and grade values, with the types the shader and the lights take.
func test_every_mood_has_its_grade() -> void:
	for mood: StringName in Arena.MOODS:
		var m: Array = Arena.MOODS[mood]
		check(m.size() == 5 + Grade.UNIFORMS.size() + 1, "%s has every column (%d)" % [mood, m.size()])
		for i: int in [0, 2, 4, 5, 7, 8]:
			check(m[i] is Color, "%s column %d is a colour" % [mood, i])
		for i: int in [1, 3, 6, 9, 10, 11]:
			check(m[i] is float, "%s column %d is a number" % [mood, i])

# A pool of light on flat sand must not read as a bullseye round him: its two ends stay close, and it doesn't end inside the screen.
func test_no_mood_draws_a_bullseye() -> void:
	for mood: StringName in Arena.MOODS:
		var m: Array = Arena.MOODS[mood]
		var pool: Color = m[7]
		var edge: Color = m[8]
		var least := minf(minf(edge.r / pool.r, edge.g / pool.g), edge.b / pool.b)
		check(least > 0.83, "%s's edge is close to its pool (%.2f)" % [mood, least])
		check(m[9] > 1.02, "%s's pool reaches past the corners (%.2f)" % [mood, m[9]])

# Stone keeps its warm colour by day: the light on the whole picture never leans it blue. Only the darks do.
func test_daylight_leaves_stone_warm() -> void:
	for mood: StringName in [&"calm", &"hush", &"clear", &"dust", &"grave", &"lake", &"town"]:
		var m: Array = Arena.MOODS[mood]
		for c: Color in [m[7], m[8]]:
			check(c.b <= c.g and c.g <= c.r, "%s's light isn't blue or pink (%s)" % [mood, c])

# A headless run draws nothing, so this reads the shader: the hit flash, pure white from the sprite shader, stays white under any mood.
func test_the_grade_leaves_white_alone() -> void:
	var code := (load("res://core/grade.gdshader") as Shader).code
	check(code.contains("float white = step(WHITE, min(s.r, min(s.g, s.b)));"), "white is seen before the grade changes it")
	check(code.contains("COLOR = vec4(mix(s * mix(edge, pool, ring), vec3(1.0), white), 1.0);"), "and written back last")

# A mood change reaches the grade: at once, or through a tween with no jump.
func test_a_mood_change_reaches_the_grade() -> void:
	var a := _arena()
	a.set_mood(&"blood", 0.0)
	var blood: Array = Arena.MOODS[&"blood"]
	check(a.mood == &"blood", "it knows its mood (%s)" % a.mood)
	for i in Grade.UNIFORMS.size():
		check(a._grade.material.get_shader_parameter(Grade.UNIFORMS[i]) == blood[5 + i], "blood's %s reached the shader" % Grade.UNIFORMS[i])
	near(a._grade.sprite_lit, blood[11], 0.001, "and how much it lights the sprites")
	a.set_mood(&"dark", 0.5)
	var dark: Array = Arena.MOODS[&"dark"]
	var mid := false
	for i in 300:    # a frame can take long on a busy machine: look for the tween under way
		await get_tree().process_frame
		if a._grade.sprite_lit < 1.0:
			var amount: float = a._grade.material.get_shader_parameter(&"shadow_amount")
			mid = a._grade.sprite_lit > 0.0 and amount > minf(blood[6], dark[6]) and amount <= maxf(blood[6], dark[6])
			break
	check(mid, "under way, it is between the two moods")
	await get_tree().create_timer(0.7).timeout
	check(a._grade.material.get_shader_parameter(&"edge") == dark[8], "and it ends on the new mood's")
	near(a._grade.sprite_lit, dark[11], 0.001, "the sprites' light as well")

# Everything 2D draws over the grade: the storm's dust, a memory, the HUD and the menus.
func test_the_grade_is_under_all_that_stays_ungraded() -> void:
	var a := _arena()
	var storm := Sandstorm.new()
	a.add_child(storm)
	var hud := (preload("res://ui/hud.tscn") as PackedScene).instantiate() as Hud
	a.add_child(hud)
	check(a._grade.layer < storm.layer, "under the sandstorm (%d, %d)" % [a._grade.layer, storm.layer])
	check(a._grade.layer < hud.layer - 1, "under a memory, which is one under the HUD (TombScene) (%d, %d)" % [a._grade.layer, hud.layer])

# Walking at the breach, the wall and the plinth for 2 s each: the breach is closed (rubble), and nobody walks through the plinth.
# Every prop has its picture, and none lies on the plinth or in Elvis's way in from the breach.
func test_props_are_clear_of_the_way() -> void:
	for p: Array in Arena.PROPS:
		check(FileAccess.file_exists("res://art/props/%s.png" % p[0]), "%s has its picture" % p[0])
		var at := Vector2(p[1], p[2])
		check(absf(at.x) > Arena.PLINTH + 0.5 or absf(at.y) > Arena.PLINTH + 0.5, "%s is off the plinth" % p[0])
		check(absf(at.x) > 2.0 or at.y < 6.0, "%s leaves the way in clear" % p[0])
		check(at.length() < Arena.RADIUS, "%s is inside the wall" % p[0])

func test_walls_and_plinth_hold() -> void:
	var a := _arena()
	var body := CharacterBody3D.new()
	body.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var c := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.8
	c.shape = capsule
	c.position.y = 0.95
	body.add_child(c)
	add_child(body)
	for run: Array in [[a.entrance(), Vector3.BACK], [Vector3(-8.0, 0, 0), Vector3.LEFT], [Vector3(0, 0, 4.0), Vector3.FORWARD]]:
		body.global_position = run[0]
		var way: Vector3 = run[1]
		for i in 120:
			body.velocity = way * 6.0
			body.move_and_slide()
			await get_tree().physics_frame
		var d := Vector2(body.global_position.x, body.global_position.z).length()
		check(d < Arena.RADIUS, "walking %s stays inside the wall (%s m out)" % [way, d])
		if way == Vector3.FORWARD:
			check(body.global_position.z > Arena.PLINTH, "the plinth stops him in front of it (z %s)" % body.global_position.z)

# Real Elvis, real keys: the lowest rubble stops him where it stands, and he doesn't ride up it.
func test_the_lowest_rubble_is_a_wall_not_a_ramp() -> void:
	var a := _arena()
	var e := ELVIS.instantiate() as Elvis
	add_child(e)
	var low: Array[Vector4] = a._rubble().filter(func(b: Vector4) -> bool: return b.w < 0.2 and Vector2(b.x, b.y).length() < Arena.RADIUS)
	check(low.size() >= 3, "there are low blocks inside the wall (%d)" % low.size())
	for b: Vector4 in low.slice(0, 3):
		var home := Vector3(b.x, 0.0, b.y) * (1.0 - 2.0 / Vector2(b.x, b.y).length())    # 2 m in from it, towards the middle
		e.global_position = home
		var keys: Array[StringName] = [&"move_right" if b.x > home.x else &"move_left", &"move_down" if b.y > home.z else &"move_up"]
		for k in keys:
			Input.action_press(k)
		for i in 60:
			await get_tree().physics_frame
		for k in keys:
			Input.action_release(k)
		e._vel = Vector2.ZERO
		near(e.global_position.y, 0.0, 0.001, "he doesn't ride up the block at %s" % b)
		check(absf(e.global_position.x - b.x) > b.z or absf(e.global_position.z - b.y) > b.z, "and he isn't standing on it (%s, at %s)" % [b, e.global_position])
	e.queue_free()

# A dive can land the boss on the widest rubble there is: he's pushed off to the side, not up, and walks away. So is anyone else put there.
func test_landing_on_a_block_is_not_a_trap() -> void:
	var a := _arena()
	var body := StaticBody3D.new()
	add_child(body)
	a._solid(body, Vector4(3.0, 3.0, 0.42, Pixel.STEP * 0.25))
	for path: String in ["res://boss/vulcan.tscn", "res://player/elvis.tscn"]:
		var who := (load(path) as PackedScene).instantiate() as Actor
		add_child(who)
		await get_tree().physics_frame
		who.scripted = true
		who.global_position = Vector3(3.0, 0.0, 3.0)
		for i in 10:
			await get_tree().physics_frame
		var from := who.global_position
		check(Vector2(from.x - 3.0, from.z - 3.0).length() > 0.42, "%s is pushed off it (%s)" % [path, from])
		who.move_to(from + (from - Vector3(3.0, 0.0, 3.0)).normalized() * 9.0, 5.0)
		for i in 30:
			await get_tree().physics_frame
		near(who.global_position.y, 0.0, 0.001, "%s stays on the ground" % path)
		check(who.global_position.distance_to(from) > 1.0, "%s walks away (%s to %s)" % [path, from, who.global_position])
		who.queue_free()
		await get_tree().process_frame

# Sand and cobbles stay quiet so what stands on them is what you see, and the cobbles' lines still show. The bounds are about half and double what's painted now.
func test_the_ground_is_quiet() -> void:
	var s := _spread(_arena()._paint(128, 96, Cinerea.TOWN_SAND, 9, "sand"))
	check(s > 0.0 and s < 0.05, "the sand is barely a shade from flat (%s)" % s)
	for pic: String in ["road", "town"]:
		var d := _spread(Image.load_from_file("res://art/floors/%s.png" % pic), true, 5)    # every 5th: the town's picture is 10 million texels
		check(d > 0.06 and d < 0.25, "%s: its stones are quiet, and still drawn (%s)" % [pic, d])

# What the brightness runs over, darkest pixel to brightest, among the opaque ones or only the stones, known as Cinerea._on_stone knows them.
func _spread(img: Image, stones := false, step := 1) -> float:
	var lo := 1.0
	var hi := 0.0
	for y in range(0, img.get_height(), step):
		for x in range(0, img.get_width(), step):
			var c := img.get_pixel(x, y)
			if c.a > 0.5 and (not stones or maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b)) < 0.18):
				lo = minf(lo, c.get_luminance())
				hi = maxf(hi, c.get_luminance())
	return hi - lo

func _arena() -> Arena:
	var a := ARENA.instantiate() as Arena
	add_child(a)
	return a
