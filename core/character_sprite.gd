class_name CharacterSprite extends Node3D
# A character drawn from res://art/<folder>/manifest.json as a pixel-exact billboard.
# Missing art never crashes: anim_dir → anim_F → (walk/sprint → run_dir → run_F) → (run/walk/sprint → stand-in walk_F) → idle_F →
# stand-in idle_F, warning once per key.
# Manifest: {"cell": [w, h], "anims": {"idle_F": {"file": "idle_F.png", "frames": 6, "fps": 8, "loop": true, "holds": {"3": 0.1}}}}
# frames run left to right in one row; holds add seconds to a frame; an optional "start" skips cells (the stand-in shares one sheet);
# an optional "active": [first, last] names an attack's hit frames (active_window).

signal frame_changed(key: String, frame: int)
signal finished(key: String)    # non-looping animations only

const STANDIN := "standin"
const SHADER := preload("res://core/sprite.gdshader")

static var _manifests := {}    # folder -> its manifest, or {} when missing or broken
static var _textures := {}     # path -> Texture2D, or null when missing
static var _warned := {}

var character := ""      # the folder asked for, even when it fell back to the stand-in
var current_key := ""    # the key actually playing, e.g. "run_S"
var frame := 0
var speed_scale := 1.0   # multiplies the art's own playback speed (play, restart); play_timed's time is the caller's and ignores it

var _sprite := Sprite3D.new()
var _mat := ShaderMaterial.new()
var _src := STANDIN      # folder the character's frames come from
var _key_src := ""       # folder of the playing key
var _anim := {}
var _first := 0
var _count := 1
var _time := 0.0
var _done := false
var _lift := Vector3.ZERO
var _tint := Color.WHITE
var _want := "idle"
var _facing := Vector2.DOWN
var _flash_id := 0
var _stretch := 0.0      # > 0 while a play_timed one-shot plays: each frame's time is multiplied by it
var _once := false       # play_timed: one pass then `finished`, even when the key loops (a fallback can)

func _init() -> void:
	_mat.shader = SHADER
	_sprite.name = "Sprite3D"
	_sprite.material_override = _mat
	_sprite.pixel_size = 1.0 / Pixel.PX
	_sprite.scale.y = Pixel.sprite_scale_y()
	_sprite.top_level = true
	add_child(_sprite)

static func dir_suffix(facing: Vector2) -> String:
	if absf(facing.x) > absf(facing.y):
		return "S"
	return "B" if facing.y < 0.0 else "F"

# Side sheets face right.
static func flipped(facing: Vector2) -> bool:
	return dir_suffix(facing) == "S" and facing.x < 0.0

func load_character(folder: String) -> void:
	character = folder
	_src = folder if _manifest(folder).has("anims") else STANDIN
	if _src != folder:
		_warn(folder, "manifest.json", "using the stand-in")
	restart(_want, _facing)

func set_tint(c: Color) -> void:
	_tint = c
	if _key_src == STANDIN:
		_mat.set_shader_parameter(&"tint", c)

func play(anim: String, facing: Vector2) -> void:
	_go(anim, facing, false)

func restart(anim: String, facing: Vector2) -> void:
	_go(anim, facing, true)

# Plays `anim` once from the start, stretched so the whole of it lasts `seconds`: gameplay timing stays in code and the art follows it.
# seconds <= 0 keeps the art's own speed (times speed_scale). Ends with `finished`, also when the key that plays is a looping fallback.
func play_timed(anim: String, facing: Vector2, seconds: float) -> void:
	restart(anim, facing)
	_once = true
	if seconds > 0.0:
		var natural := 0.0
		for i in _count:
			natural += _base_hold(i)
		_stretch = seconds / natural

# An attack's hit frames, from the manifest's optional "active": [first, last]; (-1, -1) when the key has none.
func active_window(key: String) -> Vector2i:
	var anims: Dictionary = _manifest(_key_src if key == current_key else _src).get("anims", {})
	var a: Variant = anims.get(key)
	var w: Variant = a.get("active") if a is Dictionary else null
	if w is Array and w.size() == 2 and typeof(w[0]) in [TYPE_INT, TYPE_FLOAT] and typeof(w[1]) in [TYPE_INT, TYPE_FLOAT]:
		return Vector2i(int(w[0]), int(w[1]))
	return Vector2i(-1, -1)

func flash(seconds: float) -> void:
	_flash_id += 1
	_mat.set_shader_parameter(&"flash", 1.0)
	get_tree().create_timer(seconds, true, false, true).timeout.connect(_unflash.bind(_flash_id))

func set_param(param: StringName, value: float) -> void:
	_mat.set_shader_parameter(param, value)

func _unflash(id: int) -> void:
	if id == _flash_id:
		_mat.set_shader_parameter(&"flash", 0.0)

func _go(anim: String, facing: Vector2, again: bool) -> void:
	_want = anim
	_facing = facing
	var at := _resolve(anim, facing)
	if at.is_empty():
		return
	_sprite.flip_h = at[1].ends_with("_S") and facing.x < 0.0
	if not again and not _done and at[0] == _key_src and at[1] == current_key:
		return
	_key_src = at[0]
	current_key = at[1]
	var m: Dictionary = _manifest(_key_src)
	var anims: Dictionary = m["anims"]
	_anim = anims[current_key]
	var cell: Array = m["cell"]
	var tex: Texture2D = _texture(_key_src, _anim)
	_sprite.frame = 0    # before hframes changes, so the old frame index is never out of range
	_sprite.texture = tex
	_sprite.hframes = maxi(1, tex.get_width() / int(cell[0]))
	_first = clampi(int(_anim.get("start", 0)), 0, _sprite.hframes - 1)
	_count = clampi(int(_anim.get("frames", 1)), 1, _sprite.hframes - _first)
	_mat.set_shader_parameter(&"tex", tex)
	_mat.set_shader_parameter(&"tint", _tint if _key_src == STANDIN else Color.WHITE)
	# Feet at the origin; an odd width moves half a texel so texel edges stay on pixel edges.
	_lift = Vector3((int(cell[0]) % 2) * 0.5 / Pixel.PX, tex.get_height() / Pixel.PX / 2.0 * _sprite.scale.y, 0.0)
	_time = 0.0
	_done = false
	_stretch = 0.0
	_once = false
	_set_frame(0)
	_place()

func _resolve(anim: String, facing: Vector2) -> PackedStringArray:
	var wanted := "%s_%s" % [anim, dir_suffix(facing)]
	var tries: Array[PackedStringArray] = [PackedStringArray([_src, wanted]), PackedStringArray([_src, anim + "_F"])]
	if anim in ["walk", "sprint"]:    # his own run before the stand-in's walk, so he stays himself (Task 5)
		tries.append(PackedStringArray([_src, "run_" + dir_suffix(facing)]))
		tries.append(PackedStringArray([_src, "run_F"]))
	if anim in ["run", "walk", "sprint"]:
		tries.append(PackedStringArray([STANDIN, "walk_F"]))
	tries.append(PackedStringArray([_src, "idle_F"]))
	tries.append(PackedStringArray([STANDIN, "idle_F"]))
	for t in tries:
		if _has(t[0], t[1]):
			if t != tries[0]:
				_warn(character, wanted, "using %s/%s" % [t[0], t[1]])
			return t
	_warn(character, wanted, "no stand-in either")
	return PackedStringArray()

func _has(folder: String, key: String) -> bool:
	var anims: Dictionary = _manifest(folder).get("anims", {})
	return anims.has(key) and anims[key] is Dictionary and _texture(folder, anims[key]) != null

func _manifest(folder: String) -> Dictionary:
	if not _manifests.has(folder):
		var path := "res://art/%s/manifest.json" % folder
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		var ok := false
		if data is Dictionary and data.get("anims") is Dictionary and data.get("cell") is Array:
			var cell: Array = data["cell"]
			ok = cell.size() == 2 and typeof(cell[0]) in [TYPE_INT, TYPE_FLOAT] and typeof(cell[1]) in [TYPE_INT, TYPE_FLOAT] and cell[0] >= 1 and cell[1] >= 1
		if FileAccess.file_exists(path) and not ok:
			_warn(folder, "manifest.json", "unreadable")
		_manifests[folder] = data if ok else {}
	return _manifests[folder]

func _texture(folder: String, anim: Dictionary) -> Texture2D:
	var path := "res://art/%s/%s" % [folder, anim.get("file", "")]
	if not _textures.has(path):
		var tex: Texture2D = null
		if FileAccess.file_exists(path):
			# loaded straight from the PNG so Godot's import can't compress or smooth it (shortcut: breaks on export; import it properly then)
			var img := Image.load_from_file(path)
			if img:
				tex = ImageTexture.create_from_image(img)
		_textures[path] = tex
	return _textures[path]

func _warn(folder: String, key: String, what: String) -> void:
	var id := folder + "/" + key
	if not _warned.has(id):
		_warned[id] = true
		push_warning("CharacterSprite: %s has no %s, %s" % [folder, key, what])

func _set_frame(i: int) -> void:
	frame = i
	_sprite.frame = _first + i
	frame_changed.emit(current_key, i)

func _base_hold(i: int) -> float:
	var holds: Dictionary = _anim.get("holds", {})
	return 1.0 / maxf(float(_anim.get("fps", 8.0)), 0.1) + float(holds.get(str(i), 0.0))

func _hold() -> float:
	return _base_hold(frame) * (_stretch if _stretch > 0.0 else 1.0)

func _physics_process(delta: float) -> void:
	if _anim.is_empty() or _done:
		return
	_time += delta * (1.0 if _stretch > 0.0 else speed_scale)
	while _time >= _hold():
		_time -= _hold()
		if frame + 1 < _count:
			_set_frame(frame + 1)
		elif _anim.get("loop", true) and not _once:
			_set_frame(0)
		else:
			_done = true
			finished.emit(current_key)
			return

func _process(_delta: float) -> void:
	_place()

func _place() -> void:
	if is_inside_tree():
		_sprite.global_position = Pixel.snap(global_position) + _lift
