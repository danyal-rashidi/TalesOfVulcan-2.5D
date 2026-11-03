extends FxEffect
# Lines bursting out from where a finisher struck, over the world and under the HUD. Timed in real seconds, so they show through the hit-stop, and they run
# through a pause too: whatever is playing, they're gone in LIFE and nothing has to clean up after them.

const LIFE := 120        # ms
const COUNT := 14
const FROM: Array[int] = [14, 22, 34]    # px from the middle each frame's lines start, Claude's call
const LONG: Array[int] = [16, 20, 10]    # px long, Claude's call
const SIZE := 104        # px across: every line fits, and even so it stays on the grid
const TONES: Array[Color] = [Color8(255, 255, 255), Hud.PARCHMENT, Color8(196, 180, 150)]

static var _drawn: Array[ImageTexture] = []

var _born := 0
var _spr: Sprite3D

func _build() -> void:
	life = 10.0    # end() is _process's to call; this only stops a forgotten one
	process_mode = PROCESS_MODE_ALWAYS
	_born = Time.get_ticks_msec()
	if _drawn.is_empty():
		for f in FROM.size():
			_drawn.append(ImageTexture.create_from_image(image(f)))
	_spr = _sprite_of(_drawn[0], true)

func _process(_delta: float) -> void:
	var f := (Time.get_ticks_msec() - _born) * FROM.size() / LIFE
	if f >= FROM.size():
		end()
	else:
		_spr.texture = _drawn[f]

# One pixel wide. The same lines in every frame, from a fixed seed, moving outward and thinning out.
static func image(frame: int) -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in COUNT:
		var way := Vector2.from_angle((i + rng.randf_range(-0.3, 0.3)) * TAU / COUNT)
		var start := FROM[frame] + rng.randi_range(-3, 3)
		var tone := TONES[mini(i % 2 + frame, TONES.size() - 1)]
		for r in LONG[frame] + rng.randi_range(-3, 3):
			img.set_pixelv(Vector2i((way * (start + r)).round()) + Vector2i.ONE * SIZE / 2, tone)
	return img
