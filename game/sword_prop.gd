class_name SwordProp extends Node3D
# Vulcan's greatsword once his hand lets it go (C3 shot 4): it stands on its point at his side, tips over and lands flat on the
# stone toward the camera with a clang (sparks, dust, a small shake). Plain unshaded boxes, which the 640x360 view draws as hard pixels.

signal fell

const BLADE := Vector3(0.14, 1.25, 0.03)    # Claude's call: about 1.6 m from point to pommel, a greatsword for a 1.9 m man
const GUARD := Vector3(0.44, 0.07, 0.06)
const GRIP := Vector3(0.05, 0.28, 0.05)
const IRON := Color8(84, 76, 84)
const DARK := Color8(40, 32, 36)
const LAVA := Color8(232, 104, 30)          # the possessed glow down the blade (FxEffect.FIRE[2])

func _ready() -> void:
	_box(BLADE, BLADE.y / 2.0, IRON)
	_box(Vector3(0.03, BLADE.y - 0.15, 0.04), BLADE.y / 2.0 + 0.05, LAVA)    # the glowing seam, proud of the blade's face
	_box(GUARD, BLADE.y, DARK)
	_box(GRIP, BLADE.y + GRIP.y / 2.0, DARK)
	_box(Vector3(0.09, 0.08, 0.08), BLADE.y + GRIP.y + 0.04, IRON)          # the pommel

# Tips over toward the camera in `seconds`, faster as it goes, and lands flat, face up, then `fell`.
func drop(seconds: float) -> void:
	var tw := create_tween()
	tw.tween_property(self, "rotation:x", PI / 2.0, maxf(seconds, 0.01)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	Fx.spawn(&"sparks", global_position + Vector3(0.0, 0.0, BLADE.y))
	Fx.spawn(&"dust", global_position + Vector3(0.0, 0.0, BLADE.y / 2.0))
	Feel.shake(2.0, 0.12)
	fell.emit()

func _box(size: Vector3, y: float, c: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = c
	var box := BoxMesh.new()
	box.size = size
	box.material = mat
	var m := MeshInstance3D.new()
	m.mesh = box
	m.position.y = y
	add_child(m)
