extends CanvasLayer
# Autoload Dev: F1 opens a panel of tools for building and testing quests, in every build (Danyal): jump anywhere, cheats, the Journey's state,
# and an info overlay that stays up with the panel shut. While it's open it has the mouse and he stands still (Elvis._read_input); Ctrl+left click
# on the ground puts him there. The cheats are checks in the real code: god (Hitbox), one_hit (Actor._lose_health), no_cooldowns (Elvis.ability_left),
# stamina (Stamina.spend), fast_walk (Elvis._tick_move), noclip (Actor._slide). dev=open on the command line opens the panel and the overlay at once.

const GAME := "res://game/game.tscn"
const CINEREA := "res://game/cinerea.tscn"
const FAST_WALK := 2.5     # x his walk and sprint. Claude's call
const NEAR := 15.0         # m: whom the overlay lists. Claude's call
const NEAREST := 5         # of them, the closest: the town would push the rest off the screen. Claude's call
const PANEL_W := 236.0     # px of the 640x360 view
const INFO_W := 230.0
const TRUSTED: Array[String] = ["Cassia", "Old Tullus", "Livia"]    # whose talks have trust in their answers (game/talks.gd)
# Name, scene, where he stands. Cinerea's are its own named spots; _ready adds its people.
const PLACES: Array[Array] = [
	["Colosseum: the fight's start", GAME, Vector3(0.0, 0.0, Arena.RADIUS - 1.5)],    # Arena.entrance()
	["Road: where he wakes", CINEREA, Cinerea.WAKE_AT],
	["Road: the legionary's tomb", CINEREA, TombScene.UP_TO],
	["Road: Cassia's cart, the raiders", CINEREA, CassiaScene.STAND_AT],
	["Road: the lake's west shore", CINEREA, Vector3(Cinerea.LAKE_AT.x - Cinerea.LAKE_HALF.x - 1.0, 0.0, Cinerea.LAKE_AT.y)],
	["Town: inside the north gate", CINEREA, Vector3(0.0, 0.0, Cinerea.NORTH + 3.0)],
	["Town: the fountain", CINEREA, Vector3(Cinerea.FOUNTAIN_AT.x, 0.0, Cinerea.FOUNTAIN_AT.y + 3.0)],
	["Town: Cassia's stall", CINEREA, Cinerea.STALL_AT],
	["Town: the job board", CINEREA, Vector3(15.6, 0.0, 63.5)],    # in front of it (Cinerea.VILLAGE)
	["Town: the temple's fire altar", CINEREA, Vector3(50.0, 0.0, 80.0)],
]

var open := false
var god := false
var one_hit := false
var no_cooldowns := false
var stamina := false
var fast_walk := false
var noclip := false
var info := false
var no_save := false          # a jump or a Ctrl+click has moved him past the story: nothing writes his save for the rest of this run (Cinerea.autosave)
var landing := Vector3.INF    # where a jump to another scene puts him once it's up; Cinerea skips its walk in while it's set
var places: Array[Array] = []

var _theme := Theme.new()
var _panel := PanelContainer.new()
var _overlay := PanelContainer.new()
var _info := Label.new()
var _count := SpinBox.new()
var _trust := {}    # who -> their SpinBox
var _upgraded := CheckBox.new()

func _ready() -> void:
	layer = 30    # over the HUD and the menus
	process_mode = PROCESS_MODE_ALWAYS
	places = PLACES.duplicate()
	info = "dev=open" in OS.get_cmdline_user_args()    # before its box is made, so the box shows it ticked
	for p: Array in Cinerea.PEOPLE:
		places.append(["Town: %s (%d, %d)" % [p[1], p[4], p[5]], CINEREA, Vector3(p[4] + 1.2, 0.0, p[5])])    # beside where they stand, or walk to
	_theme.set_stylebox(&"panel", &"PanelContainer", Hud._box(Hud.PLATE, Hud.BRONZE))
	for s: StringName in [&"normal", &"hover", &"pressed", &"focus"]:
		_theme.set_stylebox(s, &"Button", Hud._box(GameMenu.CELL_BG, GameMenu.LINE if s == &"normal" else Hud.BRONZE))
	_theme.set_color(&"font_color", &"Label", Hud.PARCHMENT)
	_panel.theme = _theme
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 4.0
	_panel.offset_top = 4.0
	_panel.offset_right = 4.0 + PANEL_W
	_panel.offset_bottom = -4.0
	var tabs := TabContainer.new()
	tabs.add_child(_page("Jump", _jump_rows()))
	tabs.add_child(_page("Cheats", _cheat_rows()))
	tabs.add_child(_page("Journey", _journey_rows()))
	_panel.add_child(tabs)
	_overlay.theme = _theme
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.anchor_left = 1.0
	_overlay.anchor_right = 1.0
	_overlay.offset_left = -4.0 - INFO_W
	_overlay.offset_right = -4.0
	_overlay.offset_top = 4.0
	_info.custom_minimum_size.x = INFO_W - 12.0
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS    # with max_lines_visible (_fit): what won't fit is cut, not drawn off the screen
	_overlay.add_child(_info)
	add_child(_overlay)
	add_child(_panel)
	_panel.visible = false
	_overlay.visible = false
	get_tree().scene_changed.connect(_land)
	if info:
		cheat(true, &"info")
		toggle()

func toggle() -> void:
	open = not open
	_panel.visible = open
	if open:
		_fit()
		_refresh()

# What a talk or a reset changed since.
func _refresh() -> void:
	for who: String in _trust:
		(_trust[who] as SpinBox).set_value_no_signal(int(Journey.trust.get(who, 0)))
	_upgraded.set_pressed_no_signal(Journey.hammer_upgraded)

# The game's own font, at the size the HUD's text is at this zoom.
func _fit() -> void:
	_theme.default_font = Hud.font(Hud.TEXT)
	_theme.default_font_size = Hud.font_px(Hud.TEXT)
	# The overlay in Tiny5, half Jersey's height, so the Journey fits beside the game; and never taller than the screen.
	var px := Hud.TINY_EM * maxi(floori(PixelCamera.view_scale), 1)
	var tiny := Hud.pixel_font(Hud.TINY)
	_info.add_theme_font_override(&"font", tiny)
	_info.add_theme_font_size_override(&"font_size", px)
	_info.max_lines_visible = maxi(floori((get_viewport().get_visible_rect().size.y - 24.0) / tiny.get_height(px)), 1)

# Before the game sees anything: F1 always, and Esc and Ctrl+click while it's open.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"dev"):
		toggle()
	elif not open:
		return
	elif event.is_action_pressed(&"pause"):
		toggle()    # Esc shuts this, not the game behind it
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and event.ctrl_pressed and not _panel.get_global_rect().has_point(event.position):
		var p := player()
		var at := p._ground_under_mouse() if p else Vector3.INF
		if at != Vector3.INF:
			teleport(at)
	else:
		return
	get_viewport().set_input_as_handled()

func player() -> Elvis:
	for n in get_tree().get_nodes_in_group(&"actors"):
		if n is Elvis:
			return n
	return null

# There at once, in this scene, or in the place's own once it's up (_land).
func jump(i: int) -> void:
	var place: Array = places[i]
	var p := player()
	if p and p.get_parent().scene_file_path == place[1]:
		teleport(place[2])
		return
	landing = place[2]
	no_save = true    # before the place's own scene is up, so not even its first beat saves
	ShotDriver.start = ""    # or the colosseum would send him straight on to Cinerea
	get_tree().paused = false
	get_tree().change_scene_to_file(place[1])

func _land() -> void:
	if landing != Vector3.INF:
		teleport(landing)
		landing = Vector3.INF

func teleport(at: Vector3) -> void:
	var p := player()
	if p == null:
		return
	no_save = true
	p.global_position = Vector3(at.x, Hills.height_at(at.x, at.z) if Hills.on else 0.0, at.z)
	p.velocity = Vector3.ZERO
	p._vel = Vector2.ZERO
	p.reset_physics_interpolation()

func cheat(on: bool, what: StringName) -> void:
	set(what, on)
	if what == &"stamina" and on and player():
		player().stamina.refill()
	elif what == &"info":
		_fit()
		_overlay.visible = on

func give(id: StringName, count: int) -> void:
	Journey.add_item(id, count)

func add_money(drachma: int, embers: int) -> void:
	Journey.drachma += drachma
	Journey.embers += embers
	Journey.changed.emit()

func set_trust(who: String, to: int) -> void:
	Journey.add_trust(who, to - int(Journey.trust.get(who, 0)))
	Journey.changed.emit()    # add_trust doesn't say

func set_upgraded(on: bool) -> void:
	Journey.hammer_upgraded = on
	Journey.changed.emit()

func reset_journey() -> void:
	Journey.reset()
	Journey.changed.emit()
	_refresh()

func _jump_rows() -> Array[Control]:
	var rows: Array[Control] = [_label("Ctrl+click the ground: go there")]
	for i in places.size():
		rows.append(_button(places[i][0], jump.bind(i)))
	return rows

func _cheat_rows() -> Array[Control]:
	var rows: Array[Control] = []
	for c: Array in [["God mode: no damage", &"god"], ["One-hit kills", &"one_hit"], ["No cooldowns", &"no_cooldowns"], ["Infinite stamina", &"stamina"],
			["Fast walk", &"fast_walk"], ["Noclip: through walls", &"noclip"], ["Info overlay", &"info"]]:
		var box := CheckBox.new()
		box.text = c[0]
		box.focus_mode = Control.FOCUS_NONE
		box.button_pressed = get(c[1])
		box.toggled.connect(cheat.bind(c[1]))
		rows.append(box)
	return rows

func _journey_rows() -> Array[Control]:
	_count.min_value = 1
	_count.max_value = 999
	_count.value = 1
	var rows: Array[Control] = [_row("How many", _count)]
	for id: StringName in Journey.ITEMS:
		rows.append(_button("+ " + Journey.ITEMS[id]["name"], func() -> void: give(id, int(_count.value))))
	rows.append(_button("+ drachma", func() -> void: add_money(int(_count.value), 0)))
	rows.append(_button("+ embers", func() -> void: add_money(0, int(_count.value))))
	rows.append(_label("Memories, each with its path's first skill"))
	for p: Dictionary in Journey.PATHS:
		rows.append(_button("Remember " + p["name"], Journey.remember.bind(p["id"])))
	rows.append(_label("Skills: each press moves it F, Q, off"))
	for skill: String in Journey.ABILITIES:
		rows.append(_button(skill, Journey.cycle_ability.bind(skill)))
	rows.append(_label("Trust"))
	for who in TRUSTED:
		var box := SpinBox.new()
		box.min_value = -100
		box.max_value = 100
		box.value_changed.connect(func(v: float) -> void: set_trust(who, int(v)))
		_trust[who] = box
		rows.append(_row(who, box))
	_upgraded.text = "Hammer upgraded"
	_upgraded.focus_mode = Control.FOCUS_NONE
	_upgraded.toggled.connect(set_upgraded)
	rows.append(_upgraded)
	rows.append(_button("Reset Journey", reset_journey))
	return rows

# A tab: its rows, scrolled.
func _page(title: String, rows: Array[Control]) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for r in rows:
		list.add_child(r)
	scroll.add_child(list)
	return scroll

func _button(text: String, pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE    # or Enter, which also talks, would press it again
	b.pressed.connect(pressed)
	return b

func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l

func _row(text: String, box: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := _label(text)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	row.add_child(box)
	return row

func _process(_delta: float) -> void:
	if info:
		_info.text = "\n".join(PackedStringArray(_world() + _journey() + _near()))    # sections in order: quests will add theirs before NEAR, which is cut first

func _world() -> Array[String]:
	var scene := get_tree().current_scene
	var out: Array[String] = ["FPS %d  %s  region %s" % [Engine.get_frames_per_second(), scene.scene_file_path.get_file() if scene else "-", Journey.here]]
	var p := player()
	if p:
		var at := p.global_position
		out.append("Him %.1f, %.1f, %.1f  %s" % [at.x, at.y, at.z, Elvis.State.find_key(p.state)])
		out.append("HP %d/%d  stamina %d/%d" % [p.health.hp, p.health.max_hp, p.stamina.value, p.stamina.max_value])
	if no_save:
		out.append("Saving is off: he was moved by Dev")
	return out

func _near() -> Array[String]:
	var p := player()
	if p == null:
		return []
	var near: Array[Node3D] = []
	for n: Node3D in get_tree().get_nodes_in_group(&"actors") + get_tree().get_nodes_in_group(&"walkers"):
		if n != p and n.global_position.distance_to(p.global_position) <= NEAR:
			near.append(n)
	near.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.global_position.distance_to(p.global_position) < b.global_position.distance_to(p.global_position))
	var out: Array[String] = ["NEAR"]
	for n in near.slice(0, NEAREST):
		out.append("  %s  %.1f m" % [_seen(n), n.global_position.distance_to(p.global_position)])
	return out

# Who it is and what it's doing.
func _seen(n: Node3D) -> String:
	if n is Jackal:
		var j := n as Jackal
		return "%s %s %d hp" % [j.folder, Jackal.Mode.find_key(j.mode), j.health.hp]
	if n is Vulcan:
		var v := n as Vulcan
		return "Vulcan %s %d hp" % [Vulcan.Mode.find_key(v.mode), v.health.hp]
	if n is Townsperson:
		var t := n as Townsperson
		return "%s %s" % [t.who, "hidden" if not t.shown() else ("talking" if t._busy else t.sprite.current_key)]
	return n.name

func _journey() -> Array[String]:
	return ["JOURNEY",
		"  drachma %d  embers %d  hammer %s" % [Journey.drachma, Journey.embers, "fire" if Journey.hammer_upgraded else "plain"],
		"  bag: " + _list(Journey.bag),
		"  worn: " + _list(Journey.equipped),
		"  memories: " + _list(Journey.memories),
		"  F: %s  Q: %s" % [Journey.ability_slots[&"ability_f"], Journey.ability_slots[&"ability_q"]],
		"  trust: " + _list(Journey.trust),
		"  visited: " + _list(Journey.visited)]

static func _list(things: Variant) -> String:
	var out := PackedStringArray()
	for k: Variant in things:
		out.append("%s %s" % [k, things[k]] if things is Dictionary else str(k))
	return ", ".join(out) if not out.is_empty() else "-"
