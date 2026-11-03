class_name FxNumber extends FxEffect
# What a blow really cost, over whoever took it: from `info` and `team`, as Fx.spawn() is given them. It hits nothing.
# In the world on the pixel grid, in the pixel font at a whole multiple of its own pixel, so every font pixel is one art pixel at every zoom.
# It pops up, then rises slowly, in whole pixels; a hit-stop holds it. Each keeps to a lane of its own, so quick hits never land on one another.

const HURT := Color8(255, 88, 66)    # brighter than the HUD's HealthRed, to read on the sand. Claude's call
const GOLD := Color8(255, 232, 112)  # brighter than the HUD's TrailGold, which is the sand's own colour. Claude's call
const LIFE := 0.7            # s, Claude's call
const POP_PX := 8            # it jumps this far first...
const POP_TIME := 0.08       # ...in this long, Claude's call
const DRIFT := 12.0          # px/s after that, Claude's call
const GAP := 2.0             # px between two lanes
const BODY := Vector2(32.0, 52.0)    # px, a man from his feet up. Claude's call

var text := ""
var lane := Rect2()          # the screen pixels it will cross, in world pixels
var _base := Vector3.ZERO

func _build() -> void:
	life = LIFE
	var blow := info if info else HitInfo.new()
	text = str(maxi(roundi(blow.damage), 1))
	var font := Hud.pixel_font()
	var px := Hud.JERSEY_EM * (2 if blow.heavy else 1)
	var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px)
	var l := Label3D.new()
	l.font = font
	l.font_size = px
	l.text = text
	l.pixel_size = 1.0 / Pixel.PX
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	l.no_depth_test = true    # over the world and whoever took it; the HUD draws over all of the 3D
	l.shaded = false
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	l.offset = Vector2(-floorf(size.x / 2.0), 0.0)    # whole pixels: centred text can land on half a one
	l.modulate = HURT if team == Hitbox.TEAM_PLAYER else (GOLD if blow.heavy else Hud.PARCHMENT)
	l.outline_modulate = Hud.OUTLINE
	l.outline_size = px / 10    # Hud's dark edge. The font has no antialiasing, so alpha stays all or nothing; it's blended only so the edge can sort under the letters
	add_child(l)
	_take_lane(size, blow.source if is_instance_valid(blow.source) else null)
	_base = position
	_step(0.0)

# The first spot by `position` clear of every number still up, whatever heights they've reached by then, and of whoever struck: it mustn't sit on his face.
func _take_lane(size: Vector2, striker: Node3D) -> void:
	var taken: Array[Rect2] = []
	for c in get_parent().get_children():
		if c != self and c is FxNumber and not c.is_queued_for_deletion():
			taken.append((c as FxNumber).lane)
	if striker is Actor:
		taken.append(Rect2(_on_screen(striker.global_position) - Vector2(BODY.x / 2.0, BODY.y), BODY))
	var fly := POP_PX + DRIFT * LIFE
	var wide := size.x + GAP
	var home := position.x
	var at := _on_screen(position) - Vector2(wide / 2.0, size.y + fly)
	for i in 9:
		var step := (i + 1) / 2 * (1 if i % 2 == 1 else -1)    # 0, 1, -1, 2, -2...
		lane = Rect2(at + Vector2(step * wide, 0.0), Vector2(wide, size.y + fly))
		position.x = home + step * wide / Pixel.PX
		if taken.all(func(r: Rect2) -> bool: return not lane.intersects(r)):
			return

# Where a point in the world falls, in whole art pixels up to the camera's own place.
static func _on_screen(p: Vector3) -> Vector2:
	return Vector2(p.x * Pixel.PX, p.z * FxSlash.FLOOR_PX - p.y * Pixel.PX / Pixel.sprite_scale_y())

func _step(_delta: float) -> void:
	var up := floorf(POP_PX * minf(age / POP_TIME, 1.0) + DRIFT * maxf(age - POP_TIME, 0.0))
	position = snap3(_base + Vector3.UP * up * Pixel.sprite_scale_y() / Pixel.PX)
