class_name FxSlash extends FxEffect
# The swing's mark in the air: an arc for a light swing, a straight stab for the lunge and the thrust. It hits nothing. Fx.spawn() makes it bare; swing() shapes it.
# Drawn as a sweep flat on the air round him at chest height, so it foreshortens as the floor does and reads from the front, side and back.
# One billboard at his chest sorts itself against him: the half above his chest falls behind him, the half below in front.
# cut(): Vulcan's sheets name the way their blade's tip goes, and the mark is drawn along it, flat on the sheet, so it lies on his pixels.

const ICE: Array[Color] = [Color8(215, 252, 252), Color8(113, 222, 232), Color8(60, 134, 172)]    # the trail on his spear's own sheets
const STEEL: Array[Color] = [Color8(255, 246, 224), Color8(214, 200, 178), Color8(146, 132, 118)]    # the sword sheets' trail, warmed
const FRAME := 0.05      # s each of its three frames shows, Claude's call
const CHEST := 0.9       # m up: where his hitbox swings
const FLOOR_PX := 24.0   # screen pixels per metre of ground depth
const SIDES := 16        # facings it's drawn for: enough that a stick's angle doesn't show
const ARC := {false: Vector3(1.2, 0.36, 70.0), true: Vector3(1.6, 0.5, 85.0)}    # light 1-3, light 4: m out to its edge, m thick at its thickest, degrees to each side. Claude's call
const STAB := Vector3(0.7, 2.1, 0.14)    # m ahead it starts, m ahead it ends, m to each side at its widest. Claude's call
const CUT := 5.0         # px thick at its thickest: a light cut. A finisher 6, a heavy 8. Claude's call
const TOWARD := 0.1      # m toward the camera from his sheet, or away from it when he has his back to us: in front of him or behind, and on the same screen pixels
const SPANS: Array[Vector2] = [Vector2(0.0, 0.6), Vector2(0.1, 1.0), Vector2(0.65, 1.0)]    # the part of the sweep each frame shows: it opens, it's all there, its tail goes
const CUT_SPANS: Array[Vector2] = [Vector2(0.0, 0.3), Vector2(0.1, 1.0), Vector2(0.65, 1.0)]    # a cut's: it opens just ahead of the blade, which the next frame has at its end

static var _drawn := {}    # shape -> its three frames, so only the first swing of a kind costs anything

var sweep := 0       # +1 or -1: which way round it goes
var big := false
var stab := false
var _who: Node3D
var _on: CharacterSprite    # the sheet a cut lies on
var _off := Vector3.ZERO
var _frames: Array = []
var _spr: Sprite3D

func _build() -> void:
	life = FRAME * SPANS.size()

# `who` it stays with, as he carries on forward through the swing. `colors`: edge to inside.
func swing(who: Node3D, facing: Vector2, way: int, wide: bool, straight: bool, colors: Array[Color]) -> void:
	_who = who
	sweep = way
	big = wide
	stab = straight
	var side := posmod(roundi(facing.angle() / TAU * SIDES), SIDES)
	var key := [side, way, wide, straight, colors[0]]
	if not _drawn.has(key):
		var made := []
		for f in SPANS.size():
			made.append(ImageTexture.create_from_image(image(side * TAU / SIDES, way, wide, straight, colors, f)))
		_drawn[key] = made
	_frames = _drawn[key]
	_spr = _sprite_of(_frames[0], straight and facing.y > 0.0)    # toward the camera a stab's tip runs on past where this billboard goes under the floor, and that half is in front of him anyway
	_process(0.0)

# Along the playing sheet's own "arc". Behind him when he faces away, as the blade is, in front otherwise.
func cut(on: CharacterSprite, way: int, last: bool, heavy: bool, colors: Array[Color]) -> void:
	_on = on
	process_priority = 1    # after his sprite has moved this frame, or a step toward the camera carries him through it
	sweep = way
	big = last
	stab = heavy
	var arc := on.cut_arc()
	var key := [arc, colors[0]]
	if not _drawn.has(key):
		var made := []
		for f in SPANS.size():
			made.append(ImageTexture.create_from_image(cut_image(on.frame_size(), arc, CUT + (3.0 if heavy else 1.0 if last else 0.0), colors, f)))
		_drawn[key] = made
	_frames = _drawn[key]
	_spr = _sprite_of(_frames[0])
	_spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y    # as the sheet stands, and as it's stretched
	_spr.scale.y = Pixel.sprite_scale_y()
	age = get_physics_process_delta_time()    # his sheet turned over a tick ago, and its next frame has the blade at the end of the opening part
	_off = Vector3(0.0, sin(deg_to_rad(Pixel.PITCH_DEG)), cos(deg_to_rad(Pixel.PITCH_DEG))) * (-TOWARD if on.current_key.ends_with("_B") else TOWARD)
	_process(0.0)

func _step(_delta: float) -> void:
	if _spr:
		_spr.texture = _frames[mini(int(age / FRAME), _frames.size() - 1)]

func _process(_delta: float) -> void:
	if _spr and is_instance_valid(_on):
		_spr.global_position = _on.drawn_at() + _off
	elif _spr and is_instance_valid(_who):
		_spr.global_position = snap3(_who.get_global_transform_interpolated().origin + Vector3.UP * CHEST)    # where he's drawn this frame

# Hard pixels in colors' few steps. Even sizes, so with the sprite on the grid every texel is one screen pixel.
static func image(angle: float, way: int, wide: bool, straight: bool, colors: Array[Color], frame: int) -> Image:
	var shape: Vector3 = STAB if straight else ARC[wide]
	var reach := shape.y if straight else shape.x
	var thick := shape.z if straight else shape.y
	var half := deg_to_rad(shape.z)
	var w := int(reach * Pixel.PX) * 2 + 4
	var h := int(reach * FLOOR_PX) * 2 + 4
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var ahead := Vector2.from_angle(angle)
	var span := SPANS[frame]
	for y in h:
		for x in w:
			var at := Vector2((x + 0.5 - w / 2.0) / Pixel.PX, (y + 0.5 - h / 2.0) / FLOOR_PX)    # the ground this pixel shows, m from his middle
			var along: float
			var depth: float
			if straight:
				along = (at.dot(ahead) - shape.x) / (shape.y - shape.x)
				depth = absf(at.cross(ahead))
			else:
				depth = reach - at.length()
				if depth < 0.0 or depth > thick:    # most pixels stop here, which keeps the first swing cheap
					continue
				along = 0.5 + way * angle_difference(angle, at.angle()) / (2.0 * half)
			if along < span.x or along > span.y:
				continue
			var d := depth / (thick * sin(PI * (along - span.x) / (span.y - span.x)))    # thin at its two tips
			if d < 1.0:
				img.set_pixel(x, y, colors[mini(int(d * colors.size()) + frame / 2, colors.size() - 1)])    # its tail in the darker steps
	return img

# The crescent along `arc`, as big as the sheet it lies on. Its outer edge is along the arc and the brightest; it thickens to its inside.
static func cut_image(size: Vector2i, arc: Array, thick: float, colors: Array[Color], frame: int) -> Image:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var span := CUT_SPANS[frame]
	var steps := arc.size() * 80
	var mid := _along(arc, 0.5)
	var chord := (_along(arc, 0.0) + _along(arc, 1.0)) / 2.0
	var inward := -1.0 if (_along(arc, 0.51) - _along(arc, 0.49)).orthogonal().dot(chord - mid) < 0.0 else 1.0
	for i in steps + 1:
		var t := float(i) / steps
		if t < span.x or t > span.y:
			continue
		var at := _along(arc, t)
		var inside := (_along(arc, t + 0.005) - _along(arc, t - 0.005)).orthogonal().normalized() * inward
		var deep := thick * sin(PI * (t - span.x) / (span.y - span.x))    # thin at its two tips
		var d := 0.0
		while d < deep:
			var p := Vector2i((at + inside * d).floor())
			if Rect2i(Vector2i.ZERO, size).has_point(p) and img.get_pixelv(p).a == 0.0:
				img.set_pixelv(p, colors[mini(int(d / deep * colors.size()) + frame / 2, colors.size() - 1)])    # its tail in the darker steps
			d += 0.5
	return img

# A smooth line through the points (Catmull-Rom), t from 0 to 1.
static func _along(arc: Array, t: float) -> Vector2:
	var n := arc.size() - 1
	var u := clampf(t, 0.0, 1.0) * n
	var i := mini(int(u), n - 1)
	var f := u - i
	var p := func(k: int) -> Vector2:
		var q: Array = arc[clampi(k, 0, n)]
		return Vector2(q[0], q[1])
	return 0.5 * (2.0 * p.call(i + 0) + (p.call(i + 1) - p.call(i - 1)) * f + (2.0 * p.call(i - 1) - 5.0 * p.call(i) + 4.0 * p.call(i + 1) - p.call(i + 2)) * f * f + (3.0 * p.call(i) - p.call(i - 1) - 3.0 * p.call(i + 1) + p.call(i + 2)) * f * f * f)
