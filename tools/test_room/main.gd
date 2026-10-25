extends Node3D
# Test room: pixel blocks seen from above at a slant (Alabaster Dawn style), Vulcan's Gemini sprite walking on them.
# Everything is built here in code, so this one file is the whole room. Arrows or WASD to walk.

const PX := 32.0                        # texels per metre on the ground, and screen pixels per metre
const PITCH := 48.59                    # camera looks down this many degrees; sin = 0.75, so a 1 m tile top is exactly 24 px tall on screen
const STEP := 0.75                      # one block level; its front face is 16 px tall on screen
const SPEED := 4.0
const CELL := Vector2i(46, 81)          # sprite sheet cell; frame 0 idle, 1..12 walk
const MAP := [
	"####################",
	"#..................#",
	"#..PP.......##.....#",
	"#..PP.......##..P..#",
	"#..........###.....#",
	"#..~~~~~...........#",
	"#..~~~~~.....S.....#",
	"#..~~~~~...........#",
	"#...........P......#",
	"#.....##...........#",
	"#.....##.......~~~.#",
	"#..............~~~.#",
	"#..................#",
	"####################",
]
const HEIGHT := {".": 0.0, "S": 0.0, "#": STEP, "P": STEP * 3.0, "~": -0.25}

var player: CharacterBody3D
var sprite: AnimatedSprite3D
var blob: MeshInstance3D
var cam: Camera3D
var lava_mat: StandardMaterial3D
var mats := {}
var shot_dir := ""
var frame := 0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("shot="):
			shot_dir = a.substr(5)
	_environment()
	_build_room()
	_make_player()

func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color8(18, 14, 20)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color8(110, 96, 130)
	env.ambient_light_energy = 0.55
	env.glow_enabled = true
	env.glow_intensity = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_color = Color(1.0, 0.86, 0.72)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 360.0 / PX
	cam.rotation_degrees.x = -PITCH
	cam.far = 200.0
	add_child(cam)

# --- textures: posterized noise in a few tones of one colour, so they read as pixel art ---

func _tex(w: int, h: int, base: Color, seed_: int, kind: String) -> ImageTexture:
	var n := FastNoiseLite.new()
	n.seed = seed_
	n.frequency = 0.18
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var v := n.get_noise_2d(x, y)
			var c := base
			if v > 0.22: c = base.lightened(0.10)
			elif v < -0.28: c = base.darkened(0.16)
			match kind:
				"slab":   # stone slab: light top and left edge, dark grout right and bottom
					if x == w - 1 or y == h - 1: c = base.darkened(0.45)
					elif x == 0 or y == 0: c = base.lightened(0.18)
				"brick":  # bricks 8 px tall, offset every other row
					var row: int = y / 8
					if y % 8 == 7 or (x + (row % 2) * 8) % 16 == 15: c = base.darkened(0.5)
					elif y % 8 == 0: c = c.lightened(0.08)
				"lava":
					if v > 0.35: c = Color8(255, 214, 92)
					elif v < -0.35: c = Color8(120, 30, 18)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)

func _mat(key: String, w: int, h: int, base: Color, seed_: int, kind: String) -> StandardMaterial3D:
	if mats.has(key):
		return mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = _tex(w, h, base, seed_, kind)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.roughness = 1.0
	if kind == "lava":
		m.emission_enabled = true
		m.emission_texture = m.albedo_texture
		m.emission_energy_multiplier = 1.6
		lava_mat = m
	mats[key] = m
	return m

# --- the room: a top for every cell, a front face wherever the cell in front is lower ---

func _cell_pos(col: int, row: int) -> Vector3:
	return Vector3(col - MAP[0].length() / 2.0 + 0.5, 0, row - MAP.size() / 2.0 + 0.5)

func _height(col: int, row: int) -> float:
	if row < 0 or row >= MAP.size():
		return -10.0
	return HEIGHT[MAP[row][col]]

func _build_room() -> void:
	var side_px_per_m := cos(deg_to_rad(PITCH)) * PX
	for row in MAP.size():
		for col in MAP[row].length():
			var ch: String = MAP[row][col]
			var h := _height(col, row)
			var p := _cell_pos(col, row)
			var top := MeshInstance3D.new()
			var plane := PlaneMesh.new()
			plane.size = Vector2.ONE
			top.mesh = plane
			match ch:
				"~": top.material_override = _mat("lava", 32, 24, Color8(232, 104, 30), 7, "lava")
				"#", "P": top.material_override = _mat("top", 32, 24, Color8(104, 94, 92), 3, "slab")
				_:
					var v: int = (col * 7 + row * 13) % 4    # four floor variants so the tiling doesn't show
					top.material_override = _mat("floor%d" % v, 32, 24, Color8(64, 57, 62), 11 + v, "slab")
			top.position = p + Vector3(0, h, 0)
			add_child(top)
			var front := _height(col, row + 1)
			if front < h and front > -5.0:
				var fh := h - front
				var px := maxi(1, roundi(fh * side_px_per_m))
				var side := MeshInstance3D.new()
				var quad := QuadMesh.new()
				quad.size = Vector2(1, fh)
				side.mesh = quad
				side.material_override = _mat("side%d" % px, 32, px, Color8(70, 60, 62), 5, "brick")
				side.position = p + Vector3(0, front + fh / 2.0, 0.5)
				add_child(side)
			if ch == "~":
				var glow := OmniLight3D.new()
				glow.light_color = Color(1.0, 0.45, 0.15)
				glow.light_energy = 0.5
				glow.omni_range = 2.5
				glow.position = p + Vector3(0, 0.6, 0)
				add_child(glow)
			if ch in ["#", "P", "~"]:
				var body := StaticBody3D.new()
				var shape := CollisionShape3D.new()
				var box := BoxShape3D.new()
				box.size = Vector3(1, 3, 1)
				shape.shape = box
				body.position = p + Vector3(0, 1.5, 0)
				body.add_child(shape)
				add_child(body)

# --- Vulcan ---

func _make_player() -> void:
	player = CharacterBody3D.new()
	player.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING    # flat room: no gravity, walls only
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.6
	shape.shape = cap
	shape.position.y = 0.8
	player.add_child(shape)
	for row in MAP.size():
		var col: int = MAP[row].find("S")
		if col >= 0:
			player.position = _cell_pos(col, row)
	add_child(player)

	# loaded straight from the PNG so Godot's import can't compress or smooth it (shortcut: breaks on export; import it properly then)
	var sheet := ImageTexture.create_from_image(Image.load_from_file("res://art/vulcan_sheet.png"))
	var frames := SpriteFrames.new()
	frames.add_animation("idle")
	frames.add_animation("walk")
	frames.set_animation_speed("walk", 10.0)
	for i in 13:
		var at := AtlasTexture.new()
		at.atlas = sheet
		at.region = Rect2(i * CELL.x, 0, CELL.x, CELL.y)
		frames.add_frame("idle" if i == 0 else "walk", at)
	sprite = AnimatedSprite3D.new()
	sprite.sprite_frames = frames
	sprite.pixel_size = 1.0 / PX
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.scale.y = 1.0 / cos(deg_to_rad(PITCH))    # stand upright yet show every texel as exactly one screen pixel
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.top_level = true
	sprite.play("idle")
	add_child(sprite)

	var img := Image.create(32, 12, false, Image.FORMAT_RGBA8)    # oval shadow under his feet
	for y in 12:
		for x in 32:
			if pow((x - 15.5) / 14.0, 2) + pow((y - 5.5) / 5.0, 2) <= 1.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0.45))
	var sm := StandardMaterial3D.new()
	sm.albedo_texture = ImageTexture.create_from_image(img)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.0, 0.5)
	blob = MeshInstance3D.new()
	blob.mesh = plane
	blob.material_override = sm
	blob.top_level = true
	add_child(blob)

# Snap to whole screen pixels so nothing swims between texels: x in 1/32 m, ground z in 1/24 m.
func _snap(p: Vector3) -> Vector3:
	return Vector3(snappedf(p.x, 1.0 / PX), p.y, snappedf(p.z, 1.0 / (PX * sin(deg_to_rad(PITCH)))))

func _physics_process(delta: float) -> void:
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if dir == Vector2.ZERO:
		dir = Vector2(
			float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
			float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))).limit_length(1.0)
	if shot_dir != "" and frame > 30:
		dir = Vector2(1, 0.4).normalized()    # screenshot run: walk right and a little toward the camera
	player.velocity = Vector3(dir.x, 0, dir.y) * SPEED
	player.move_and_slide()
	sprite.play("walk" if dir != Vector2.ZERO else "idle")

	var at := _snap(player.global_position)
	sprite.global_position = at + Vector3(0, CELL.y / PX / 2.0 * sprite.scale.y, 0)
	blob.global_position = at + Vector3(0, 0.02, 0)
	var a := deg_to_rad(PITCH)
	cam.global_position = at + Vector3(0, sin(a), cos(a)) * 30.0
	if lava_mat:
		lava_mat.uv1_offset.x = floorf(Time.get_ticks_msec() / 150.0) / 32.0    # lava creeps one texel at a time

func _process(_delta: float) -> void:
	if shot_dir == "":
		return
	frame += 1
	if frame in [25, 70, 76]:
		get_viewport().get_texture().get_image().save_png("%s/shot_%d.png" % [shot_dir, frame])
	if frame > 76:
		get_tree().quit()
