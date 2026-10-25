class_name Crown extends FxEffect
# The Ember Crown once it is knocked off (C3 shots 1 and 5): it flies on an arc, spinning, trailing embers, lands in the sand and
# pulses red there until split() breaks it in two and its light goes out. Drawn in code, one texel per screen pixel: dark iron and
# the crown's reds (FxEffect.CROWN). An FxEffect for its sprite and light helpers, but a child of the Game, not of Fx.

signal landed

const W := 18              # the picture's size: the crown is 14 px across face on, the halves sit apart in the same frame
const H := 11
const ARC := 1.5           # Claude's call: m above the straight line at the middle of the flight
const SPIN := 2.5          # Claude's call: turns a second in the air
const EMBER_GAP := 0.08    # s between ember puffs along the way
const REST := 0.22         # m up: its picture's centre when it lies in the sand, so the floor doesn't cut its lower half
const IRON := Color8(48, 36, 40)
const OUTLINE := Color8(20, 14, 16)
const DULL: Array[Color] = [Color8(150, 140, 136), Color8(110, 100, 98), Color8(84, 74, 76), Color8(58, 52, 50)]    # its spikes once the light has left

var _spin: Array[ImageTexture] = []    # face on, three quarters, edge on, three quarters
var _halves: ImageTexture
var _pic: Sprite3D
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _time := 1.0
var _t := -1.0          # the flight, 0 to 1; -1 before fly()
var _puff := 0.0
var _broken := false

func _build() -> void:
	life = INF
	for w: int in [14, 10, 4, 10]:
		_spin.append(ImageTexture.create_from_image(crown_image(w, CROWN)))
	var dull := crown_image(14, DULL)
	var halves := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var half := int(W / 2.0)
	halves.blit_rect(dull, Rect2i(0, 0, half, H), Vector2i(-2, 0))
	halves.blit_rect(dull, Rect2i(half, 0, half, H), Vector2i(half + 2, 0))
	_halves = ImageTexture.create_from_image(halves)
	_pic = _sprite(_spin[0].get_image())
	_pic.texture = _spin[0]
	_light(CROWN[1], 1.5, 2.5).position.y = 0.0

# From `from` (his head) to `to` on the floor in `seconds` of game time, so slow motion slows it too.
func fly(from: Vector3, to: Vector3, seconds: float) -> void:
	_from = from
	_to = Vector3(to.x, REST, to.z)
	_time = maxf(seconds, 0.01)
	_t = 0.0
	global_position = from

# Two dull halves, its light gone.
func split() -> void:
	_broken = true
	_pic.texture = _halves
	_dim(0.0)

func _step(delta: float) -> void:
	if _t >= 0.0 and _t < 1.0:
		_t = minf(1.0, _t + delta / _time)
		global_position = _from.lerp(_to, _t) + Vector3.UP * ARC * 4.0 * _t * (1.0 - _t)
		_pic.texture = _spin[int(age * SPIN * 4.0) % 4]
		_puff -= delta
		if _puff <= 0.0:
			_puff = EMBER_GAP
			Fx.spawn(&"embers", global_position)
		if _t >= 1.0:
			_pic.texture = _spin[0]
			Fx.spawn(&"dust", Vector3(_to.x, 0.0, _to.z))
			Feel.shake(1.0, 0.1)
			landed.emit()
	elif _t >= 1.0 and not _broken:
		_dim(0.4 + 0.6 * pow(1.0 - fmod(age * 1.2, 1.0), 3.0))    # it still beats, as the crown glow does
	_pic.global_position = snap3(global_position)

# The crown `w` px across (14 face on, less as it turns), centred in a W x H picture: a band of dark iron with a glowing seam and
# five spikes, the middle one tallest and two wide, tipped in colors[0].
static func crown_image(w: int, colors: Array[Color]) -> Image:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var x0 := int((W - w) / 2.0)
	var top := H - 4
	for x in range(x0, x0 + w):
		for y in range(top, H):
			var edge := y == top or y == H - 1 or x == x0 or x == x0 + w - 1
			img.set_pixel(x, y, OUTLINE if edge else (colors[1] if y == top + 1 else IRON))
	var tall: Array[int] = [3, 4, 6, 4, 3]
	for i in 5:
		var wide := i == 2 and w >= 10
		var x := x0 + (int(w / 2.0) - 1 if wide else roundi(i / 4.0 * (w - 1)))    # the two-wide middle spike sits on the centre
		for dx in (2 if wide else 1):
			for y in range(top - tall[i], top):
				img.set_pixel(mini(x + dx, W - 1), y, colors[0] if y == top - tall[i] else colors[2])
	return img
