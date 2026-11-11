class_name CharacterSprite extends Node3D
# A character drawn from res://art/<folder>/manifest.json as a pixel-exact billboard.
# Missing art never crashes: anim_dir → anim_F → (walk/sprint → run_dir → run_F) → (the stand-in only: run/walk/sprint → walk_F) →
# idle_dir → idle_F → stand-in idle_F, warning once per key.
# Manifest: {"cell": [w, h], "anims": {"idle_F": {"file": "idle_F.png", "frames": 6, "fps": 8, "loop": true, "holds": {"3": 0.1}}}}
# frames run left to right in one row; holds add seconds to a frame; an optional "start" skips cells (the stand-in shares one sheet);
# an optional "active": [first, last] names an attack's hit frames (active_window); an optional "below": N says the cell's bottom N
# rows are drawn below the feet line (a front thrust's spear): the sprite moves N px toward the camera, so those rows stand over the
# floor instead of under it and the feet stay on the same screen pixel. An optional "trail": true says the sheet draws its own swing trail, so
# the game's slash arc doesn't draw a second one over it (Elvis._mark_swing). A sheet can be taller than the cell, its feet stay on the feet line, and an optional
# "w" makes its frames wider, for a blade that reaches further: both grow from his middle. An optional "arc": [[x, y], ...] names the way its blade's tip cuts (FxSlash.cut).

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
var front_of := -INF     # z: its picture stands in front of whatever stands there, on the same screen pixels
var speed_scale := 1.0   # multiplies the art's own playback speed (play, restart); play_timed's time is the caller's and ignores it
var pace := 1.0          # slowed (Actor.pace): every sheet, play_timed's too

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
	_sprite.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF    # _place() puts it on the grid every frame itself
	add_child(_sprite)

static func dir_suffix(facing: Vector2) -> String:
	if absf(facing.x) > absf(facing.y):
		return "S"
	return "B" if facing.y < 0.0 else "F"

# Side sheets face right; facing left mirrors them, unless the move has its own "_L" sheet.
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

# Seconds from the start of the playing key to the start of frame `f`, at the speed it plays now.
func seconds_to_frame(f: int) -> float:
	var s := 0.0
	for i in mini(f, _count):
		s += _base_hold(i)
	return s * (_stretch if _stretch > 0.0 else 1.0)

# Another sheet for a play_timed one-shot, at the same point of it: a drink that starts walking keeps its flask where it is.
func swap_timed(anim: String, facing: Vector2, seconds: float) -> void:
	var at := _resolve(anim, facing)
	if at.is_empty():
		return
	if at[0] == _key_src and at[1] == current_key:
		_sprite.flip_h = at[1].ends_with("_S") and facing.x < 0.0
		return
	var done := (seconds_to_frame(frame) + _time) / maxf(seconds_to_frame(_count), 1e-6)
	play_timed(anim, facing, seconds)
	var left := minf(done, 1.0) * seconds
	while frame + 1 < _count and left >= _hold():
		left -= _hold()
		_set_frame(frame + 1)
	_time = left

func frames_left() -> int:
	return _count - 1 - frame

# An attack's hit frames, from the manifest's optional "active": [first, last]; (-1, -1) when the key has none.
func active_window(key: String) -> Vector2i:
	var anims: Dictionary = _manifest(_key_src if key == current_key else _src).get("anims", {})
	var a: Variant = anims.get(key)
	var w: Variant = a.get("active") if a is Dictionary else null
	if w is Array and w.size() == 2 and typeof(w[0]) in [TYPE_INT, TYPE_FLOAT] and typeof(w[1]) in [TYPE_INT, TYPE_FLOAT]:
		return Vector2i(int(w[0]), int(w[1]))
	return Vector2i(-1, -1)

func draws_trail() -> bool:
	return _anim.get("trail", false)

func cut_arc() -> Array:
	return _anim.get("arc", [])

# A frame of the playing sheet, and where it's drawn this frame: FxSlash.cut lays its drawing exactly over it.
func frame_size() -> Vector2i:
	return Vector2i(_sprite.texture.get_width() / _sprite.hframes, _sprite.texture.get_height())

func drawn_at() -> Vector3:
	return _sprite.global_position

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
	# A loop that only turns (run_F to run_S) goes on at the same point of its stride instead of starting over
	var turning := not again and anim == _want and not _done and bool(_anim.get("loop", false))
	var stride := (frame + _time / maxf(_hold(), 1e-6)) / _count if turning else 0.0
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
	_sprite.hframes = maxi(1, floori(tex.get_width() / float(_anim.get("w", cell[0]))))
	_first = clampi(int(_anim.get("start", 0)), 0, _sprite.hframes - 1)
	_count = clampi(int(_anim.get("frames", 1)), 1, _sprite.hframes - _first)
	_mat.set_shader_parameter(&"tex", tex)
	var nrm := _texture(_key_src, {"file": str(_anim.get("file", "")).trim_suffix(".png") + "_n.png"})    # its normals, baked beside it; none, or not the sheet's size, and it's lit flat
	_mat.set_shader_parameter(&"nrm", nrm if nrm and nrm.get_size() == tex.get_size() else null)
	_mat.set_shader_parameter(&"tint", _tint if _key_src == STANDIN else Color.WHITE)
	# Feet at the origin; an odd width moves half a texel so texel edges stay on pixel edges. "below" rows: N ground pixels toward the
	# camera show N px lower on screen, so the feet line, N rows up the cell, lands where the feet are.
	var below := float(_anim.get("below", 0))
	_lift = Vector3((int(cell[0]) % 2) * 0.5 / Pixel.PX, tex.get_height() / Pixel.PX / 2.0 * _sprite.scale.y,
		below / (Pixel.PX * sin(deg_to_rad(Pixel.PITCH_DEG))))
	_time = 0.0
	_done = false
	_stretch = 0.0
	_once = false
	_set_frame(0)
	if turning and _anim.get("loop", false):
		var at_ := stride * _count
		_set_frame(mini(floori(at_), _count - 1))
		_time = (at_ - frame) * _hold()
	_place()

func _resolve(anim: String, facing: Vector2) -> PackedStringArray:
	var wanted := "%s_%s" % [anim, dir_suffix(facing)]
	if flipped(facing) and _has(_src, anim + "_L"):    # his own left-facing sheet: a mirror would change the hand he holds the spear in
		wanted = anim + "_L"
	var tries: Array[PackedStringArray] = [PackedStringArray([_src, wanted]), PackedStringArray([_src, anim + "_F"])]
	if anim in ["walk", "sprint"]:    # his own run before the stand-in's walk, so he stays himself (Task 5)
		tries.append(PackedStringArray([_src, "run_" + dir_suffix(facing)]))
		tries.append(PackedStringArray([_src, "run_F"]))
	if anim in ["run", "walk", "sprint"] and _src == STANDIN:    # a real character glides in its own idle rather than turn into the stand-in (Task 6)
		tries.append(PackedStringArray([STANDIN, "walk_F"]))
	tries.append(PackedStringArray([_src, "idle_" + dir_suffix(facing)]))    # a move with no sheet keeps the way he faces
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
	return _hold_of(_anim, i)

static func _hold_of(anim: Dictionary, i: int) -> float:
	var holds: Dictionary = anim.get("holds", {})
	return 1.0 / maxf(float(anim.get("fps", 8.0)), 0.1) + float(holds.get(str(i), 0.0))

# What a looping sheet of his shows `seconds` in, for drawing him outside the world (the inventory): {"tex", "region"}, or {} if he has no such sheet.
func looped_frame(key: String, seconds: float) -> Dictionary:
	if not _has(character, key):
		return {}
	var m := _manifest(character)
	var anim: Dictionary = m["anims"][key]
	var frames := int(anim.get("frames", 1))
	var whole := 0.0
	for i in frames:
		whole += _hold_of(anim, i)
	var t := fmod(seconds, whole)
	var at := 0
	while at < frames - 1 and t >= _hold_of(anim, at):
		t -= _hold_of(anim, at)
		at += 1
	var cell := Vector2(m["cell"][0], m["cell"][1])
	return {"tex": _texture(character, anim), "region": Rect2(Vector2(at * cell.x, 0.0), cell)}

func _hold() -> float:
	return _base_hold(frame) * (_stretch if _stretch > 0.0 else 1.0)

func _physics_process(delta: float) -> void:
	if _anim.is_empty() or _done:
		return
	_time += delta * pace * (1.0 if _stretch > 0.0 else speed_scale)
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
		# where the owner is drawn this frame: between physics ticks when physics interpolation is on, so a 144 Hz screen moves smoothly
		var origin := get_global_transform_interpolated().origin
		var at := Pixel.snap(origin) + _lift + Hills.lean(origin.x, origin.z)
		if at.z < front_of:    # towards the camera along its line of sight, so only what's in front of what changes
			at += Vector3(0.0, (front_of - at.z) * tan(deg_to_rad(Pixel.PITCH_DEG)), front_of - at.z)
		_sprite.global_position = at
