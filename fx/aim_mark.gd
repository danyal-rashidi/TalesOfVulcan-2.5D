class_name AimMark extends Node3D
# Where a held skill will land: a ring on the ground the size of the blow, a cross at its middle, and dots on the way from him to it.

const RADIUS := 2.8      # m: fx/hammer_blow.gd
const DOTS := 6
const CLEAR := 6.0       # m: more than the most a slope rises across the ring
const COLOUR := Color8(232, 58, 28)    # it has to read on sand, stone and water
const SHADER := preload("res://core/print.gdshader")

static var _ring: ImageTexture
static var _dot: ImageTexture
var _dots: Array[Sprite3D] = []
var _middle: Sprite3D

func _ready() -> void:
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if _ring == null:
		_ring = ImageTexture.create_from_image(_ring_image())
		var d := Image.create(3, 3, false, Image.FORMAT_RGBA8)
		d.fill(Color.WHITE)
		_dot = ImageTexture.create_from_image(d)
	_middle = _flat(_ring, 4.0 / 3.0)
	for i in DOTS:
		_dots.append(_flat(_dot, 1.0))

func _flat(tex: ImageTexture, depth: float) -> Sprite3D:
	var s := Sprite3D.new()
	s.axis = Vector3.AXIS_Y
	s.pixel_size = 1.0 / Pixel.PX
	s.scale.z = depth
	s.texture = tex
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter(&"tex", tex)
	m.set_shader_parameter(&"colour", COLOUR)
	s.material_override = m
	add_child(s)
	return s

# From where he stands to where it will land.
func show_from(from: Vector3, to: Vector3) -> void:
	visible = true
	_middle.global_position = Pixel.snap(Vector3(to.x, Hills.height_at(to.x, to.z), to.z)) + Vector3.UP * 0.04 + _over_hills(to)
	for i in _dots.size():
		var t := (i + 1.0) / (_dots.size() + 1.0)
		var p := from.lerp(to, t)
		Hills.lay(_dots[i], p.x, p.z, 0.04, 1.0)

# The ring is flat and wide, so a slope would bury part of it: anywhere near one it's moved toward the camera, which doesn't change where it shows, until it clears the ground.
func _over_hills(to: Vector3) -> Vector3:
	for i in 8:
		var a := TAU * i / 8.0
		if Hills.height_at(to.x + cos(a) * RADIUS, to.z + sin(a) * RADIUS) > 0.0:
			var p := deg_to_rad(Pixel.PITCH_DEG)
			return Vector3(0.0, sin(p), cos(p)) * CLEAR
	return Vector3.ZERO

static func _ring_image() -> Image:
	var r := int(RADIUS * Pixel.PX)
	var size := r * 2 + 3
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := size / 2
	for i in 1440:
		var a := TAU * i / 1440.0
		if int(i / 40.0) % 3 != 2:    # dashes, two pixels thick
			for w in 2:
				img.set_pixel(c + roundi(cos(a) * (r - w)), c + roundi(sin(a) * (r - w)), Color.WHITE)
	for d in range(-6, 7):
		for w in 2:
			img.set_pixel(c + d, c + w, Color.WHITE)
			img.set_pixel(c + w, c + d, Color.WHITE)
	return img
