class_name Grass extends Node3D
# The desert's grass (docs/refs/town_gate_example.png): tufts that sway on their own with the wind (core/grass.gdshader) and bend away from whoever walks into them, springing back after.

const KINDS: Array[String] = ["tuft_a_hi", "tuft_b_hi", "tuft_c_hi", "tuft_d_hi", "tuft_e_hi"]
const HI := 4.0            # their pictures are this many times the game's pixels: core/grass.gdshader
const REACH := 0.85        # m: closer than this it's shoved
const SHOVE := 1.6         # how hard, in the shader's units
const SPRING := 5.0        # 1/s: how fast it comes back
const NEAR := Vector2(13.0, 10.0)    # m round `watch`: only there is the grass on screen, so only there is it worth checking

var watch: Node3D          # who the screen is on
var _mats: Array[ShaderMaterial] = []
var _at: PackedVector2Array = []
var _bend: PackedFloat32Array = []

func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF

func add_tuft(kind: String, x: float, z: float) -> void:
	var s := Arena.prop_sprite(kind, x, z)
	s.pixel_size = 1.0 / (Pixel.PX * HI)
	s.position.y += s.texture.get_height() * (1.0 / HI - 1.0) / Pixel.PX / 2.0 * s.scale.y    # prop_sprite stood it on the ground at the game's pixels
	var m := s.material_override as ShaderMaterial
	m.shader = preload("res://core/grass.gdshader")
	m.set_shader_parameter(&"phase", fmod(x * 12.9898 + z * 78.233, TAU))
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(s)
	_mats.append(m)
	_at.append(Vector2(x, z))
	_bend.append(0.0)

# Strews `count` tufts over `area`, leaving out what `keep_off` says no to: (x, z) -> true. The same every time.
func strew(count: int, area: Rect2, seed_: int, keep_off := Callable()) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var tries := count * 6
	var placed := 0
	while placed < count and tries > 0:
		tries -= 1
		var x := rng.randf_range(area.position.x, area.end.x)
		var z := rng.randf_range(area.position.y, area.end.y)
		if keep_off.is_valid() and keep_off.call(x, z):
			continue
		add_tuft(KINDS[rng.randi() % KINDS.size()], x, z)
		placed += 1

func tufts() -> int:
	return _mats.size()

func bend_of(i: int) -> float:
	return _bend[i]

func _physics_process(delta: float) -> void:
	var centre := Vector2(watch.global_position.x, watch.global_position.z) if is_instance_valid(watch) else Vector2.ZERO
	var movers: Array[Vector2] = []
	for group: StringName in [&"actors", &"walkers"]:
		for n in get_tree().get_nodes_in_group(group):
			var a := n as Node3D
			var at := Vector2(a.global_position.x, a.global_position.z)
			if not is_instance_valid(watch) or (absf(at.x - centre.x) < NEAR.x + REACH and absf(at.y - centre.y) < NEAR.y + REACH):
				movers.append(at)
	for i in _mats.size():
		if is_instance_valid(watch) and _bend[i] == 0.0 and (absf(_at[i].x - centre.x) > NEAR.x or absf(_at[i].y - centre.y) > NEAR.y):
			continue
		var want := 0.0
		for m in movers:
			var d := _at[i] - m
			if absf(d.x) < REACH and absf(d.y) < REACH and d.length() < REACH:
				want = (1.0 if d.x >= 0.0 else -1.0) * SHOVE
				break
		var was := _bend[i]
		_bend[i] = want if want != 0.0 else move_toward(was, 0.0, SPRING * delta * maxf(absf(was), 0.3))
		if _bend[i] != was:
			_mats[i].set_shader_parameter(&"push", _bend[i])
