class_name Shop extends GameMenu
# Cassia's stall, over a paused game: she buys loot and sells gear (STORY.md), with her lines from DIALOGUE.md. It draws like the inventory, in the
# frame art/tools/shop_art.py makes, and works the same: WASD or arrows move, Tab or left and right turn between buying and selling, E or Enter takes the row, I or Esc leaves.

signal closed

const STOCK: Array[StringName] = [&"red_flask", &"green_flask", &"new_sword", &"copper_ring", &"bronze_amulet"]
const FLASKS: Array[StringName] = [&"red_flask", &"green_flask"]    # kept in his belt, not the bag, and bought again and again
const LIST := Vector2(90, 104)
const LIST_W := 258.0
const ROW_H := 28.0
const SIDE_X := 358.0
const DEAR := Color8(190, 84, 66)    # a price he can't pay

var selling := false
var row := 0
var said := ""    # Cassia's last words, beside her face

var _face: Texture2D
var _bought := 0
var _sold := 0

func _ready() -> void:
	super()
	_him.visible = false    # the inventory's figure of him: here he'd stand on the list
	_frame = _tex("res://art/ui/shop.png")
	_face = _tex("res://art/portraits/cassia.png")

# At 0 buying, at 1 selling.
func open(at := 0) -> void:
	selling = at == 1
	row = 0
	said = Talks.stall_greeting(int(Journey.trust.get("Cassia", 0)))
	super()

func close() -> void:
	super()
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"menu") or event.is_action_pressed(&"pause"):
		close()
	elif event.is_action_pressed(&"menu_next") or event.is_action_pressed(&"move_left") or event.is_action_pressed(&"move_right"):
		turn_page()
	elif event.is_action_pressed(&"move_up"):
		move(Vector2i.UP)
	elif event.is_action_pressed(&"move_down"):
		move(Vector2i.DOWN)
	elif event.is_action_pressed(&"confirm"):
		use()
	else:
		return
	get_viewport().set_input_as_handled()

# Between buying and selling.
func turn_page() -> void:
	selling = not selling
	row = 0
	_canvas.queue_redraw()

func move(d: Vector2i) -> void:
	row = clampi(row + d.y, 0, maxi(rows().size() - 1, 0))
	_canvas.queue_redraw()

# Not what he has on, and never his last sword: with no weapon he couldn't earn another (DIALOGUE.md: "There's always a way forward").
func _she_takes(id: StringName) -> bool:
	var it: Dictionary = Journey.ITEMS[id]
	if not it.has("sell") or id in Journey.equipped.values():
		return false
	return it["slot"] != &"weapon" or (Journey.bag.has(&"iron_sword") and Journey.bag.has(&"new_sword"))

# What the open list holds: what she'll take off him, or what she has for him (gear only until he owns it).
func rows() -> Array[StringName]:
	var out: Array[StringName] = []
	if selling:
		for id: StringName in Journey.bag:
			if _she_takes(id):
				out.append(id)
	else:
		for id: StringName in STOCK:
			if id in FLASKS or not Journey.bag.has(id):
				out.append(id)
	return out

func chosen() -> StringName:
	var list := rows()
	return list[row] if row < list.size() else &""

func use() -> void:
	var id := chosen()
	if id != &"":
		if selling:
			_sell(id)
		else:
			_buy(id)
		row = clampi(row, 0, maxi(rows().size() - 1, 0))
	_canvas.queue_redraw()

func _buy(id: StringName) -> void:
	var cost := Journey.buy_price(id)
	if Journey.drachma < cost:
		said = Talks.BROKE
	elif id in FLASKS and not player.flasks.top_up(id):
		said = Talks.NO_ROOM
	else:
		if id not in FLASKS:
			Journey.add_item(id)
		if id == &"new_sword" and Journey.has_weapon():
			Journey.toggle_equip(id)    # straight into his hand, which frees the old one to sell
		Journey.drachma -= cost
		said = Talks.BOUGHT[_bought % Talks.BOUGHT.size()]
		_bought += 1

func _sell(id: StringName) -> void:
	Journey.drachma += Journey.sell_price(id)
	Journey.remove_item(id)
	said = Talks.SOLD[_sold % Talks.SOLD.size()]
	_sold += 1

func _draw_page() -> void:
	_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * PixelCamera.view_scale)    # the same size on screen at any zoom
	if _frame:
		_canvas.draw_texture(_frame, Vector2.ZERO)
	for t in 2:
		var r := Rect2(LIST.x + t * 82, 84, 78, 15)
		_box(r, selling == (t == 1))
		_text(r.position + Vector2(0, 12), ["Buy", "Sell"][t], 10, GOLD if selling == (t == 1) else DIM, r.size.x)
	var list := rows()
	for i in list.size():
		_draw_row(i, list[i])
	if list.is_empty():
		_wrapped(LIST + Vector2(4, 16), "Nothing she'd want. Foes on the road carry what she buys." if selling else "She's sold you all she has.", LIST_W - 8.0)
	_draw_side()
	_text(Vector2(0, 296), "W/S move    E %s    Tab buy or sell    I leave" % ("sell" if selling else "buy"), 10, DIM, 640.0)

func _draw_row(i: int, id: StringName) -> void:
	var at := LIST + Vector2(0, i * ROW_H)
	var it: Dictionary = Journey.ITEMS[id]
	_box(Rect2(at, Vector2(LIST_W, ROW_H - 2.0)), i == row)
	_icon(_items, ITEM_ICON, it["icon"], 4, at + Vector2(2, 2))
	_text(at + Vector2(28, 17), it["name"], 12, TEXT)
	if selling:
		_text(at + Vector2(LIST_W - 76, 17), "x%d" % _count(id), 10, DIM)
	elif id in FLASKS:
		_text(at + Vector2(LIST_W - 76, 17), "%d/%d" % [_count(id), Flasks.RED_MAX if id == &"red_flask" else Flasks.GREEN_MAX], 10, DIM)
	var cost := Journey.sell_price(id) if selling else Journey.buy_price(id)
	var price := str(cost)
	_text(at + Vector2(LIST_W - 28 - Hud.text_w(price, 12), 17), price, 12, GOLD if selling or cost <= Journey.drachma else DEAR)
	_icon(_items, ITEM_ICON, 4, 4, at + Vector2(LIST_W - 24, 2))

func _draw_side() -> void:
	_box(Rect2(SIDE_X, 84, 50, 50), false)
	if _face:
		_canvas.draw_texture(_face, Vector2(SIDE_X + 1, 85))
	_wrapped(Vector2(SIDE_X + 56, 96), said, 138.0)
	var side := Rect2(SIDE_X, 140, 194, 104)
	_box(side, false)
	var id := chosen()
	if id != &"":
		_text(side.position + Vector2(8, 16), Journey.ITEMS[id]["name"], 12, GOLD)
		_wrapped(side.position + Vector2(8, 32), Journey.ITEMS[id]["text"], side.size.x - 16.0)
	_icon(_items, ITEM_ICON, 4, 4, Vector2(SIDE_X, 250))
	_text(Vector2(SIDE_X + 26, 266), "Drachma  %d" % Journey.drachma, 12, TEXT)
