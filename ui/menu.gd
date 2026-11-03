class_name GameMenu extends CanvasLayer
# The inventory, the Memory Paths and the world map (docs/refs/ui/ are the looks they follow), over a paused game. Everything inside art/ui/frame.png is
# drawn here at 640x360 in the game's own font, so names stay readable. I (Back on a pad) opens and closes it, Tab (RB) turns the page, WASD or arrows move, E or Enter uses.

const INNER := Rect2(64, 60, 512, 266)
const ITEM_ICON := 22
const SKILL_ICON := 26
const COLS := 10
const ROWS := 3
const CELL := 24
const GRID := Vector2(72, 234)
const SKILL_FROM := Vector2(94, 68)
const SKILL_STEP := Vector2(86, 44)
const PATH_NAME_W := 100.0    # a path's name, centred under its column: draw_string clips anything wider
const GOLD := Color8(232, 196, 128)
const EMBER := Color8(255, 140, 50)
const TEXT := Color8(226, 214, 196)
const DIM := Color8(150, 136, 124)
const CELL_BG := Color8(38, 28, 30)
const LINE := Color8(70, 54, 52)
const BLANK := Color8(214, 190, 150)
const TITLES: Array[String] = ["INVENTORY", "MEMORY PATHS", "WORLD MAP"]
# Where the slots round him are, and the icon each shows faintly while it's empty, in Journey.SLOTS' order.
const SLOT_AT: Array[Vector2] = [Vector2(84, 66), Vector2(288, 66), Vector2(288, 112), Vector2(288, 158), Vector2(84, 112), Vector2(84, 158)]
const SLOT_GHOST: Array[int] = [0, 16, 17, 18, 11, 12]
const SLOT_SIZE := 32.0     # slot.png, with its outline
const GHOST := Color(0.34, 0.3, 0.3)
const HIM_AT := Vector2(202, 140)    # the medallion's middle; he stands in it at 2x
const HIM_MIDDLE := 35.0             # px down his sheets' cell to the middle of him

var player: Elvis
var allowed := true
var page := 0
var tab := 0
var cell := Vector2i.ZERO       # in the grid; y -1 is the tab bar
var skill := Vector2i.ZERO      # path, skill

var _canvas := Control.new()
var _him := Control.new()    # on an item of its own, for the sprites' palette pass: he's the same colours here as in the world
var _frame: Texture2D
var _items: Texture2D
var _skills: Texture2D
var _medallion: Texture2D
var _slot: Texture2D
var _idle_time := 0.0
var _map: Texture2D
var _map_for: Array[StringName] = []
var _was_paused := false

func _ready() -> void:
	layer = 20
	process_mode = PROCESS_MODE_ALWAYS
	visible = false
	_frame = _tex("res://art/ui/frame.png")
	_items = _tex("res://art/ui/items.png")
	_skills = _tex("res://art/ui/skills.png")
	_medallion = _tex("res://art/ui/medallion.png")
	_slot = _tex("res://art/ui/slot.png")
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_page)
	add_child(_canvas)
	var palette := ShaderMaterial.new()
	palette.shader = preload("res://ui/him.gdshader")
	_him.material = palette
	_him.set_anchors_preset(Control.PRESET_FULL_RECT)
	_him.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_him.draw.connect(_draw_him)
	_canvas.add_child(_him)

static func _tex(path: String) -> Texture2D:
	var img := Image.load_from_file(path)
	return ImageTexture.create_from_image(img) if img and not img.is_empty() else null

func open(at := 0) -> void:
	page = at
	visible = true
	_was_paused = get_tree().paused
	get_tree().paused = true
	_canvas.queue_redraw()

func close() -> void:
	visible = false
	get_tree().paused = _was_paused

func _process(delta: float) -> void:
	if visible and page == 0:    # he goes on breathing while you look at him
		_idle_time += delta
		_canvas.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"menu") or (event.is_action_pressed(&"menu_next") and not visible):    # Tab opens it as well as turning its pages
		if visible:
			close()
		elif allowed and not get_tree().paused:
			open()
		get_viewport().set_input_as_handled()
	elif not visible:
		return
	elif event.is_action_pressed(&"pause"):
		close()
	elif event.is_action_pressed(&"menu_next"):
		turn_page()
	elif event.is_action_pressed(&"move_left"):
		move(Vector2i.LEFT)
	elif event.is_action_pressed(&"move_right"):
		move(Vector2i.RIGHT)
	elif event.is_action_pressed(&"move_up"):
		move(Vector2i.UP)
	elif event.is_action_pressed(&"move_down"):
		move(Vector2i.DOWN)
	elif event.is_action_pressed(&"confirm"):
		use()
	else:
		return
	get_viewport().set_input_as_handled()

func turn_page() -> void:
	page = (page + 1) % TITLES.size()
	_canvas.queue_redraw()

func move(d: Vector2i) -> void:
	if page == 0:
		if cell.y < 0:
			if d.y > 0:
				cell.y = 0
			elif d.x != 0:
				tab = wrapi(tab + d.x, 0, Journey.TABS.size())
				cell.x = 0
		else:
			cell.x = wrapi(cell.x + d.x, 0, COLS)
			cell.y = clampi(cell.y + d.y, -1, ROWS - 1)
	elif page == 1:
		skill.x = wrapi(skill.x + d.x, 0, Journey.PATHS.size())
		skill.y = clampi(skill.y + d.y, 0, Journey.COSTS.size() - 1)
	_canvas.queue_redraw()

# What the cursor is on, or &"".
func item_at_cursor() -> StringName:
	var list := tab_items()
	var i := cell.y * COLS + cell.x
	return list[i] if cell.y >= 0 and i < list.size() else &""

func tab_items() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in Journey.ITEMS:
		if int(Journey.ITEMS[id]["tab"]) == tab and _count(id) > 0:
			out.append(id)
	return out

func _count(id: StringName) -> int:
	if is_instance_valid(player):
		if id == &"red_flask":
			return player.flasks.red
		if id == &"green_flask":
			return player.flasks.green
	return int(Journey.bag.get(id, 0))

func use() -> void:
	if page == 0:
		var id := item_at_cursor()
		if id != &"" and Journey.toggle_equip(id) and is_instance_valid(player):
			player.set_weapon(Journey.has_weapon())
	elif page == 1 and Journey.is_learned(skill.x, skill.y):
		Journey.cycle_ability(Journey.PATHS[skill.x]["skills"][skill.y])
	_canvas.queue_redraw()

func _draw_page() -> void:
	_him.queue_redraw()
	_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * PixelCamera.view_scale)    # the same size on screen at any zoom
	if _frame:
		_canvas.draw_texture(_frame, Vector2.ZERO)
	_text(Vector2(0, 41), TITLES[page], 14, GOLD, 640.0)
	match page:
		0: _draw_inventory()
		1: _draw_skills()
		2: _draw_map()
	var keys: String = ["WASD move    E equip    Tab next page    I close", "WASD move    E put on F, then Q    Tab next page    I close", "Tab next page    I close"][page]
	_text(Vector2(0, 324), keys, 10, DIM, 640.0)

# At a whole font size for this zoom, so the letters stay sharp.
func _text(at: Vector2, s: String, size: int, c: Color, width := -1.0) -> void:
	var k := PixelCamera.view_scale
	_canvas.draw_set_transform(Vector2.ZERO)
	_canvas.draw_string(Hud.font(size), (at * k).round(), s, HORIZONTAL_ALIGNMENT_CENTER if width > 0.0 else HORIZONTAL_ALIGNMENT_LEFT, width * k if width > 0.0 else -1.0, Hud.font_px(size), c)
	_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * k)

func _icon(tex: Texture2D, size: int, index: int, cols: int, at: Vector2, tint := Color.WHITE) -> void:
	if tex:
		_canvas.draw_texture_rect_region(tex, Rect2(at, Vector2(size, size)), Rect2((index % cols) * size, (index / cols) * size, size, size), tint)

# Line by line through _text, so every word stays sharp at any zoom.
func _wrapped(at: Vector2, s: String, width: float) -> void:
	var line := ""
	for word in s.split(" "):
		var next := word if line == "" else line + " " + word
		if Hud.text_w(next, 10) > width and line != "":
			_text(at, line, 10, TEXT)
			at.y += 13.0
			line = word
		else:
			line = next
	_text(at, line, 10, TEXT)

func _box(r: Rect2, on: bool) -> void:
	_canvas.draw_rect(r, CELL_BG)
	_canvas.draw_rect(r.grow(-0.5), EMBER if on else LINE, false, 1.0)

func _draw_inventory() -> void:
	if _medallion:
		_canvas.draw_texture(_medallion, HIM_AT - _medallion.get_size() / 2.0)
	for i in Journey.SLOTS.size():
		var slot: StringName = Journey.SLOTS[i]
		var at: Vector2 = SLOT_AT[i]
		var worn := Journey.equipped.has(slot)
		if _slot:
			_canvas.draw_texture(_slot, at)
		if worn:
			_canvas.draw_arc(at + Vector2.ONE * SLOT_SIZE / 2.0, SLOT_SIZE / 2.0 - 1.0, 0.0, TAU, 48, EMBER, 1.0)
		var inside := at + Vector2.ONE * (SLOT_SIZE - ITEM_ICON) / 2.0
		if worn:
			_icon(_items, ITEM_ICON, Journey.ITEMS[Journey.equipped[slot]]["icon"], 4, inside)
		else:
			_icon(_items, ITEM_ICON, SLOT_GHOST[i], 4, inside, GHOST)
		_text(at + Vector2(-16, SLOT_SIZE + 11), String(slot).capitalize(), 10, GOLD if worn else DIM, SLOT_SIZE + 32.0)
	for t in Journey.TABS.size():
		var r := Rect2(GRID.x + t * 82, GRID.y - 18, 78, 15)
		_box(r, cell.y < 0 and t == tab)
		_text(r.position + Vector2(0, 12), Journey.TABS[t], 10, GOLD if t == tab else DIM, r.size.x)
	var list := tab_items()
	for y in ROWS:
		for x in COLS:
			var at := GRID + Vector2(x * (CELL + 2), y * (CELL + 2))
			_box(Rect2(at, Vector2(CELL, CELL)), cell == Vector2i(x, y))
			var i := y * COLS + x
			if i < list.size():
				_icon(_items, ITEM_ICON, Journey.ITEMS[list[i]]["icon"], 4, at + Vector2.ONE)
				if list[i] in Journey.equipped.values() and cell != Vector2i(x, y):    # what he has on
					_canvas.draw_rect(Rect2(at, Vector2(CELL, CELL)).grow(-0.5), GOLD, false, 1.0)
				if _count(list[i]) > 1:
					_text(at + Vector2(CELL - 2 - Hud.text_w(str(_count(list[i])), 10), 23), str(_count(list[i])), 10, TEXT)
	var side := Rect2(344, 66, 224, 166)
	_box(side, false)
	var id := item_at_cursor()
	if id != &"":
		var it: Dictionary = Journey.ITEMS[id]
		_text(side.position + Vector2(10, 18), it["name"], 12, GOLD)
		_wrapped(side.position + Vector2(10, 38), it["text"], side.size.x - 20.0)
		var slot: StringName = it["slot"]
		if slot != &"":
			_text(side.position + Vector2(10, side.size.y - 10), "E: take off" if Journey.equipped.get(slot) == id else "E: equip", 10, EMBER)
	else:
		_text(side.position + Vector2(10, 18), "Nothing here", 10, DIM)
	_box(Rect2(344, 238, 224, 74), false)
	_stat(Vector2(350, 244), 5, "Embers", Journey.embers)
	_stat(Vector2(350, 280), 4, "Drachma", Journey.drachma)
	if is_instance_valid(player):
		_stat(Vector2(460, 244), 2, "Health", player.health.max_hp)
		_stat(Vector2(460, 280), 3, "Stamina", player.stamina.max_value)

# The number under its name: on one row the two columns don't both fit at the closest zoom, whatever the number.
func _stat(at: Vector2, icon: int, label: String, value: int) -> void:
	_icon(_items, ITEM_ICON, icon, 4, at)
	_text(at + Vector2(26, 10), label, 12, TEXT)
	_text(at + Vector2(26, 22), str(value), 12, TEXT)

# His real idle, in the sword he has on, from the sheets he's drawn from in the world.
func _draw_him() -> void:
	if page != 0 or not is_instance_valid(player):
		return
	_him.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * PixelCamera.view_scale)
	var shown := player.sprite.looped_frame("idle_spear_F" if Journey.has_weapon() else "idle_F", _idle_time)
	if not shown.is_empty():
		var region: Rect2 = shown["region"]
		(_him.material as ShaderMaterial).set_shader_parameter(&"sheet", shown["tex"])
		_him.draw_texture_rect_region(shown["tex"], Rect2(HIM_AT - Vector2(region.size.x, HIM_MIDDLE * 2.0), region.size * 2.0), region)

func _draw_skills() -> void:
	for p in Journey.PATHS.size():
		var path: Dictionary = Journey.PATHS[p]
		var open_path: bool = path["id"] in Journey.memories
		var names: Array = path["skills"]
		for s in names.size():
			var at := SKILL_FROM + Vector2(p * SKILL_STEP.x, s * SKILL_STEP.y)
			if s > 0:
				var lit: bool = open_path and Journey.is_learned(p, s - 1) and Journey.is_learned(p, s)
				_canvas.draw_line(at + Vector2(14, -16), at + Vector2(14, 0), EMBER if lit else LINE, 2.0)
			var learned := Journey.is_learned(p, s)
			_box(Rect2(at, Vector2(28, 28)), skill == Vector2i(p, s))
			if learned:
				_canvas.draw_rect(Rect2(at, Vector2(28, 28)).grow(-0.5), GOLD, false, 1.0)
			# reading order in the atlas: each path's five, one path after another
			_icon(_skills, SKILL_ICON, p * names.size() + s, 6, at + Vector2.ONE, Color.WHITE if learned else (Color(0.42, 0.38, 0.38) if open_path else Color(0.14, 0.12, 0.12)))
			for key: StringName in Journey.ability_slots:
				if Journey.ability_slots[key] == names[s]:    # the key it's on
					_text(at + Vector2(31, 26), "F" if key == &"ability_f" else "Q", 12, EMBER)
		_text(SKILL_FROM + Vector2(p * SKILL_STEP.x + 14.0 - PATH_NAME_W / 2.0, names.size() * SKILL_STEP.y + 2), path["name"] if open_path else "? ? ?", 10, GOLD if open_path else DIM, PATH_NAME_W)
	var chosen: Dictionary = Journey.PATHS[skill.x]
	var line: String
	if not chosen["id"] in Journey.memories:
		line = "A memory you haven't found."
	elif Journey.is_learned(skill.x, skill.y):
		line = "%s: learned with the memory. E puts it on F, then Q." % chosen["skills"][skill.y]
	else:
		line = "%s: forge it at an anvil, %d Embers." % [chosen["skills"][skill.y], Journey.COSTS[skill.y]]
	_text(Vector2(0, 308), line, 10, TEXT, 640.0)

func _draw_map() -> void:
	var seen: Array[StringName] = Journey.visited.duplicate()
	if _map == null or seen != _map_for:
		_map = _reveal(seen)
		_map_for = seen
	if _map == null:
		return
	var at := INNER.position + Vector2((INNER.size.x - _map.get_width()) / 2.0, 4.0)    # the keys go under it
	_canvas.draw_texture(_map, at)
	for r: Dictionary in Journey.REGIONS:
		if r["id"] in Journey.visited:
			var p: Vector2 = at + _map.get_size() * (r["at"] as Vector2)
			_text(p + Vector2(-60, 0), r["name"], 10, Color8(40, 26, 18), 120.0)
			if r["id"] == Journey.here:
				_canvas.draw_rect(Rect2(p + Vector2(-3, -20), Vector2(6, 6)), Color8(190, 30, 30))
				_canvas.draw_rect(Rect2(p + Vector2(-3, -20), Vector2(6, 6)), Color8(40, 26, 18), false, 1.0)

# The painted map where he's been, blank parchment everywhere else: it shows nothing of a place until he goes there.
func _reveal(seen: Array[StringName]) -> Texture2D:
	var art := Image.load_from_file("res://art/ui/map.png")
	var ids := Image.load_from_file("res://art/ui/map_regions.png")
	if art == null or ids == null or art.is_empty() or ids.is_empty():
		return null
	art.convert(Image.FORMAT_RGBA8)
	var known := {}
	for i in Journey.REGIONS.size():
		known[(i + 1) * 40] = Journey.REGIONS[i]["id"] in seen
	for y in art.get_height():
		for x in art.get_width():
			if not known.get(roundi(ids.get_pixel(x, y).r * 255.0), false):
				var fleck := fmod(sin(x * 12.9898 + y * 78.233) * 43758.5453, 1.0)
				art.set_pixel(x, y, BLANK.darkened(0.05 + 0.05 * absf(fleck)))
	return ImageTexture.create_from_image(art)
