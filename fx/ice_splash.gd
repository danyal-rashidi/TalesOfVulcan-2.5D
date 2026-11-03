extends FxEffect
# Ice thrown off: where a spear hits, where his spear breaks, where it seals. A burst of hard shards away from the blow, `dir`, some falling. Its look is art/pixelfx/ice_splash.png, from art/tools/pixelfx_sheets.py.

const SHEET := "res://art/pixelfx/ice_splash.png"
const FRAMES := 13
const FPS := 20.0

var _spr: Sprite3D

func _build() -> void:
	life = FRAMES / FPS
	_spr = _pixelfx(SHEET, FRAMES)
	_spr.flip_h = dir.x < 0.0

func _step(_delta: float) -> void:
	_spr.frame = mini(int(age * FPS), FRAMES - 1)
