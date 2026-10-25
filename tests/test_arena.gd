extends TestCase

const ARENA := preload("res://arena/arena.tscn")

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

# Walking at the breach, the wall and the plinth for 2 s each: the breach is closed (rubble), and nobody walks through the plinth.
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

func _arena() -> Arena:
	var a := ARENA.instantiate() as Arena
	add_child(a)
	return a
