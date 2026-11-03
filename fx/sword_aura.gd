class_name FxSwordAura extends FxEffect
# The slam's fire along Vulcan's greatsword: it builds from the moment he starts the wind-up, follows the blade frame by frame, and goes out in hard steps as the blade lands. It hits nothing: fx/fire_blade.gd is the blow.
# Its look is art/sword_aura/, from art/tools/sword_aura.py: one cell per frame of slam_F, slam_S and slam_B, centred on his own cell. Fx.spawn() makes it bare; follow() starts it.

const SHEET := "res://art/sword_aura/aura.png"
const COLUMNS := 8      # one for each frame of his slam sheets
const VIEWS := "FSB"    # the sheet's rows, FLAMES to each
const FLAMES := 3
const APPEAR := 0.1     # s to come up to full strength
const LINGER := 0.18    # s from the blow until it's gone: the fire on the floor has taken over. Claude's call
const FADE_STEPS := 3.0    # it fades in hard steps, not smoothly, like the rest of the pixel art
const FLICKER := 12.0   # flames redrawn a second: fx/ground_fire.gdshader's rate
const NEAR := 0.05      # m toward the camera, so it isn't lost in his own picture and whoever stands nearer still stands in front of it

static var _sheet: ImageTexture    # straight from the PNG as CharacterSprite's are

var _who: Vulcan
var _row := 0
var _struck_age := -1.0
var _spr: Sprite3D

func _build() -> void:
	process_priority = 1    # after his sprite has placed itself this frame, or it trails him
	if _sheet == null:
		_sheet = ImageTexture.create_from_image(Image.load_from_file(SHEET))
	_spr = _sprite_of(_sheet)
	_spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	_spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y    # upright like his sprite, so it lies on the same screen pixels
	_spr.scale.y = Pixel.sprite_scale_y()
	_spr.hframes = COLUMNS
	_spr.vframes = VIEWS.length() * FLAMES
	life = INF    # until the blow, however long a slow makes that

# He's just started the slam's sheet.
func follow(who: Vulcan) -> void:
	_who = who
	_row = VIEWS.find(who.sprite.current_key.right(1)) * FLAMES
	_spr.flip_h = CharacterSprite.flipped(who.facing)
	_process(0.0)

func _step(_delta: float) -> void:
	if not is_instance_valid(_who) or _who.move != &"slam":
		end()    # flinched, reset or done: it's never left behind out of his hands
	elif _struck_age < 0.0 and _who.mode != Vulcan.Mode.WINDUP:
		_struck_age = age
		life = age + LINGER

func _process(_delta: float) -> void:
	if not is_instance_valid(_who):
		return
	_spr.frame = (_row + int(age * FLICKER) % FLAMES) * COLUMNS + mini(_who.sprite.frame, COLUMNS - 1)
	_spr.modulate.a = minf((floorf(age / APPEAR * FADE_STEPS) + 1.0) / FADE_STEPS, 1.0)
	if _struck_age >= 0.0:
		_spr.modulate.a = ceilf((life - age) / LINGER * FADE_STEPS) / FADE_STEPS
	var a := deg_to_rad(Pixel.PITCH_DEG)
	_spr.global_position = _who.sprite.drawn_at() + Vector3(0.0, tan(a), 1.0) * NEAR    # along the camera's line of sight: the same screen pixels
