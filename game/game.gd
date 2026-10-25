extends Node3D
# Placeholder until the arena (Task 3), Vulcan (Task 4) and the game flow (Task 5): a flat stone floor, Elvis and a training
# dummy, followed by the PixelCamera. bot=moves plays a fixed sequence for screenshots: lock on, the light combo, a charged
# thrust, a roll.

const ELVIS := preload("res://player/elvis.tscn")
const DUMMY := preload("res://combat/dummy.tscn")
const FLOOR_M := 40
const MOVES := [    # [physics frame, action, pressed]
	[5, &"lock_on", true], [6, &"lock_on", false],
	[20, &"attack_light", true], [21, &"attack_light", false], [40, &"attack_light", true], [41, &"attack_light", false],
	[60, &"attack_light", true], [61, &"attack_light", false], [80, &"attack_light", true], [81, &"attack_light", false],
	[125, &"attack_heavy", true], [175, &"attack_heavy", false],
	[214, &"move_left", true], [215, &"roll", true], [216, &"roll", false], [240, &"move_left", false],
]

var _frame := 0

func _ready() -> void:
	_environment()
	_floor()
	var elvis := ELVIS.instantiate() as Elvis
	add_child(elvis)
	var dummy := DUMMY.instantiate() as Node3D
	dummy.position = Vector3(1.6, 0, 0)
	add_child(dummy)
	var cam := PixelCamera.new()
	add_child(cam)
	cam.follow(elvis)

func _physics_process(_delta: float) -> void:
	if ShotDriver.bot != "moves":
		return
	_frame += 1
	for m: Array in MOVES:
		if m[0] == _frame:
			if m[2]:
				Input.action_press(m[1])
			else:
				Input.action_release(m[1])

func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color8(18, 14, 20)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color8(110, 96, 130)
	env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_color = Color(1.0, 0.86, 0.72)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)

# Stone slabs 1 m square: 32x24 texels each, one texel per screen pixel. Posterized noise as in the test room.
func _floor() -> void:
	var w := 32 * 4
	var h := 24 * 4
	var n := FastNoiseLite.new()
	n.seed = 11
	n.frequency = 0.18
	var base := Color8(64, 57, 62)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var v := n.get_noise_2d(x, y)
			var c := base
			if v > 0.22:
				c = base.lightened(0.10)
			elif v < -0.28:
				c = base.darkened(0.16)
			if x % 32 == 31 or y % 24 == 23:
				c = base.darkened(0.45)
			elif x % 32 == 0 or y % 24 == 0:
				c = base.lightened(0.18)
			img.set_pixel(x, y, c)
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.roughness = 1.0
	m.uv1_scale = Vector3(FLOOR_M / 4.0, FLOOR_M / 4.0, 1.0)
	var plane := PlaneMesh.new()
	plane.size = Vector2(FLOOR_M, FLOOR_M)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = plane
	floor_mesh.material_override = m
	add_child(floor_mesh)
