class_name Pixel
# The pixel grid shared by the camera and every sprite (settled in tools/test_room/main.gd).

const PX := 32.0            # texels per metre on the ground, and screen pixels per metre
const PITCH_DEG := 48.59    # the camera looks down this many degrees; sin = 0.75, so 1 m of ground depth is 24 px on screen
const STEP := 0.75          # one block level; its front face is 16 px tall on screen

# Snap to whole screen pixels so nothing swims between texels: x in 1/32 m, ground z in 1/24 m. Height shows on screen as ground depth, so something up a hill lands on the same grid as the ground.
static func snap(p: Vector3) -> Vector3:
	var a := deg_to_rad(PITCH_DEG)
	var back := p.y * cos(a) / sin(a)
	return Vector3(snappedf(p.x, 1.0 / PX), p.y, snappedf(p.z - back, 1.0 / (PX * sin(a))) + back)

# Sprites stand upright yet show every texel as exactly one screen pixel.
static func sprite_scale_y() -> float:
	return 1.0 / cos(deg_to_rad(PITCH_DEG))

static func ground(v: Vector2) -> Vector3:
	return Vector3(v.x, 0.0, v.y)
