class_name FxHammerAura extends FxEffect
# Hammer Blow's star: a giant ghostly hammer that forms out of his hand along the sword as he leaps, follows the sword frame by frame, and strikes the ground in front of him the moment he lands, its handle still in his hand, then fades there.
# It hits nothing: fx/hammer_blow.gd is the blow. Its look is art/hammer_aura/, from art/tools/hammer_aura.py; burning once Journey.hammer_upgraded. Fx.spawn() makes it bare; follow() starts it.

const GOLD := "res://art/hammer_aura/plain.png"
const BURNING := "res://art/hammer_aura/fire.png"
const ANGLES := 8          # columns of the sheet: one for each frame of hammer_blow_S up to the strike, which is the last
const HANDS: Array[Vector2i] = [Vector2i(6, -18), Vector2i(7, -20), Vector2i(7, -20), Vector2i(18, -15), Vector2i(24, -6), Vector2i(24, -6), Vector2i(23, 3), Vector2i(23, 14)]    # his fists on the sword in those frames, px from the middle of his frame, facing right, y down. Both swords share them
const HIT := Vector2(108.0, 25.0)    # screen px from his feet to where the head's face meets the floor at the strike, facing right, y down (tests/test_hammer_aura.gd measures the sheet)
const APPEAR := 0.1        # s to come up to full strength
const FLASH := 0.03        # s it shows white as it strikes
const LINGER := 0.24       # s from the strike until it's gone: over before his sheet leaves the strike's frame (its hold in the manifest), so the hand never lets go of it. Claude's call
const FADE_STEPS := 3.0    # it fades in hard steps, not smoothly, like the rest of the pixel art
const FLICKER := 12.0      # flames redrawn a second: fx/ground_fire.gdshader's rate

static var _sheets := {}    # path -> its texture, straight from the PNG as CharacterSprite's are, so only the first leap of a look costs anything

var _who: Elvis
var _struck := false
var _struck_age := 0.0
var _spr: Sprite3D

func _build() -> void:
	process_priority = 1    # after his sprite has placed itself this frame, or it trails his hand through the leap
	var path: String = BURNING if Journey.hammer_upgraded else GOLD
	if not _sheets.has(path):
		_sheets[path] = ImageTexture.create_from_image(Image.load_from_file(path))
	_spr = _sprite_of(_sheets[path], true)
	_spr.material_override = behind_people(_sheets[path])
	_spr.hframes = ANGLES
	_spr.vframes = 4 if Journey.hammer_upgraded else 2

# What Sprite3D draws by itself, see-through, plus the one thing it can't be asked for: the stencil.
static func behind_people(tex: Texture2D) -> StandardMaterial3D:
	var look := StandardMaterial3D.new()
	look.albedo_texture = tex
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.no_depth_test = true
	look.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	look.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	look.vertex_color_use_as_albedo = true    # the sprite's modulate, its fade
	look.vertex_color_is_srgb = true
	look.render_priority = -2    # under a damage number and its dark edge (-1): the first 55 is the proof of the upgrade
	look.stencil_mode = BaseMaterial3D.STENCIL_MODE_CUSTOM    # not on the pixels core/sprite.gdshader marks: every character stands in front of it, so his fist is on the handle and his face is never under the flames. Claude's call
	look.stencil_flags = BaseMaterial3D.STENCIL_FLAG_READ
	look.stencil_compare = BaseMaterial3D.STENCIL_COMPARE_NOT_EQUAL
	look.stencil_reference = 1
	return look

# `who` has just leapt, and lands `land` s from now.
func follow(who: Elvis, land: float) -> void:
	_who = who
	life = land + LINGER
	_spr.flip_h = who.facing.x < 0.0
	_process(0.0)

# He's landed: it strikes the ground this instant.
func strike() -> void:
	_struck = true
	_struck_age = age
	_process(0.0)

# Where the head comes down for someone standing at `feet`, swinging toward `side` (1 right, -1 left): the ground that shows at HIT on screen, so on a slope too it's the ground the picture touches.
static func head_from(feet: Vector3, side: float) -> Vector3:
	return _ground_at(feet, Vector2(side * HIT.x, HIT.y))

# Where he has to stand for the head to come down at `head`.
static func feet_for(head: Vector3, side: float) -> Vector3:
	return _ground_at(Vector3(head.x, Hills.height_at(head.x, head.z) if Hills.on else head.y, head.z), Vector2(-side * HIT.x, -HIT.y))

static func _ground_at(from: Vector3, px: Vector2) -> Vector3:
	var pitch := deg_to_rad(Pixel.PITCH_DEG)
	var at := from + Vector3(px.x / Pixel.PX, 0.0, px.y / (Pixel.PX * sin(pitch)))
	return Hills.on_ray(at, Vector3(0.0, -sin(pitch), -cos(pitch))) if Hills.on else at

# The column for the frame his sheet is on.
func _column() -> int:
	return ANGLES - 1 if _struck else mini(_who.sprite.frame, ANGLES - 1)

func _step(_delta: float) -> void:
	if not is_instance_valid(_who) or _who.state != Elvis.State.ABILITY or (not _struck and (_who.scripted or not _who.input_enabled)):
		end()    # the leap was cut off (he died in the air, a scene started, the scene he was in went) or he's been hit out of the swing: it never stays behind out of his hand. Once struck only a change of his state ends it: the blow that drops the last raider starts her scene at once
		return

func _show() -> void:
	var since := age - _struck_age
	var flames := _spr.vframes - 1
	var row := flames if _struck and since < FLASH else int(age * FLICKER) % flames
	_spr.frame = row * ANGLES + _column()
	var a := minf((floorf(age / APPEAR * FADE_STEPS) + 1.0) / FADE_STEPS, 1.0)
	if _struck:
		a = minf(ceilf((LINGER - since) / (LINGER - FLASH * 2.0) * FADE_STEPS) / FADE_STEPS, 1.0)
	_spr.modulate.a = a

func _process(_delta: float) -> void:
	if not is_instance_valid(_who):
		return
	_show()    # here, not in _step: his sheet turns over later in the same physics step, and its picture and its place must agree
	var hand := HANDS[_column()]
	_spr.global_position = _who.sprite.drawn_at() + Vector3((-1.0 if _spr.flip_h else 1.0) * hand.x, -hand.y * Pixel.sprite_scale_y(), 0.0) / Pixel.PX    # on his own pixels: he's on the grid already
