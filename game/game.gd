extends Node3D
# Placeholder until the arena (Task 3) and Elvis (Task 2): a flat stone floor and the stand-in Elvis
# walking with Controls.move_vector(), followed by the PixelCamera. bot=walk walks him for screenshots.

const SPEED := 4.0
const FLOOR_M := 40

var _elvis := Node3D.new()
var _sprite := CharacterSprite.new()
var _facing := Vector2.DOWN

func _ready() -> void:
	_environment()
	_floor()
	add_child(_elvis)
	_elvis.add_child(_sprite)
	_sprite.set_tint(Color(0.55, 0.7, 1.0))    # blue, so the stand-in reads as Elvis
	_sprite.load_character("elvis")
	var cam := PixelCamera.new()
	add_child(cam)
	cam.follow(_elvis)

func _physics_process(delta: float) -> void:
	var dir := Controls.move_vector()
	if ShotDriver.bot == "walk":
		dir = Vector2(1, 0.4).normalized()
	_elvis.position += Pixel.ground(dir) * SPEED * delta
	if dir != Vector2.ZERO:
		_facing = dir
	_sprite.play("walk" if dir != Vector2.ZERO else "idle", _facing)

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
