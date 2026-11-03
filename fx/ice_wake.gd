class_name FxIceWake extends FxEffect
# The aura behind a giant ice spear: a stamp of frost left every physics frame at its butt, each cooling and shrinking away where it was left, so the wake curves with the flight and is still there a moment after the spear has hit. It hits nothing. Its look is art/pixelfx/ice_wake.png, from art/tools/pixelfx_sheets.py. Fx.spawn() makes it bare; follow() starts it.

const SHEET := "res://art/pixelfx/ice_wake.png"
const FRAMES := 11
const FPS := 20.0

var _spear: FxIceSpear
var _stamps: Array[Sprite3D] = []    # the pool: a hidden one is free
var _born: Array[float] = []

static var _material: StandardMaterial3D    # the one, so the hundred or so stamps in the air stay cheap

func _build() -> void:
	life = 12.0    # its spear's flight is three seconds at most

func follow(spear: FxIceSpear) -> void:
	_spear = spear

func _step(_delta: float) -> void:
	var live := 0
	for i in _stamps.size():
		var s := _stamps[i]
		if s.visible:
			var f := int((age - _born[i]) * FPS)
			s.visible = f < FRAMES
			if s.visible:
				s.frame = f
				live += 1
	if not is_instance_valid(_spear) or _spear.is_queued_for_deletion():
		if live == 0:
			end()
		return
	_stamp(_spear.butt())

# As the spear's own, so people stand in front of it, and under the spear.
static func _look(tex: Texture2D) -> StandardMaterial3D:
	if _material == null:
		_material = FxHammerAura.behind_people(tex)
		_material.render_priority = -3
	return _material

func _stamp(at: Vector3) -> void:
	var i := 0
	while i < _stamps.size() and _stamps[i].visible:
		i += 1
	if i == _stamps.size():
		_stamps.append(_pixelfx(SHEET, FRAMES))
		_born.append(0.0)
		_stamps[i].material_override = _look(_stamps[i].texture)
	var s := _stamps[i]
	s.visible = true
	s.frame = 0
	s.flip_h = i % 2 == 0    # the one stamp, so a run of them doesn't repeat
	s.global_position = snap3(at)
	_born[i] = age
