extends TestCase
# What Vulcan carries and remembers, the menu over it, and the road into Cinerea.

const CINEREA := preload("res://game/cinerea.tscn")
const JACKAL := preload("res://enemy/jackal.tscn")

func _before() -> void:
	Journey.reset()

func test_equip_and_take_off() -> void:
	_before()
	check(not Journey.toggle_equip(&"iron_sword"), "what he hasn't got can't be equipped")
	Journey.add_item(&"iron_sword")
	check(Journey.toggle_equip(&"iron_sword") and Journey.has_weapon(), "it goes in his hand")
	Journey.toggle_equip(&"iron_sword")
	check(not Journey.has_weapon(), "and comes off")
	check(not Journey.toggle_equip(&"hammer_head"), "a key item can't be worn")

func test_a_memory_opens_a_path_with_its_first_skill() -> void:
	_before()
	check(not Journey.is_learned(0, 0), "nothing is learned at first")
	Journey.remember(&"hammer")
	check(Journey.is_learned(0, 0), "The Hammer's first skill comes with the memory")
	check(not Journey.is_learned(0, 1), "the next is forged")
	check(not Journey.is_learned(1, 0), "other paths stay closed")
	check(Journey.PATHS.size() == 6, "six paths (STORY.md)")
	for p: Dictionary in Journey.PATHS:
		check((p["skills"] as Array).size() == Journey.COSTS.size(), "%s has five skills" % p["name"])

func test_map_shows_only_where_he_has_been() -> void:
	_before()
	var regions := Image.load_from_file("res://art/ui/map_regions.png")
	var art := Image.load_from_file("res://art/ui/map.png")
	check(regions.get_size() == art.get_size(), "the regions match the map")
	var menu := GameMenu.new()
	add_child(menu)
	var none: Array[StringName] = []
	var seen: Array[StringName] = [&"cinerea"]
	var hidden := menu._reveal(none).get_image()
	var part := menu._reveal(seen).get_image()
	var at := Vector2i(roundi(art.get_width() * 0.8), roundi(art.get_height() * 0.85))
	var far := Vector2i(roundi(art.get_width() * 0.15), roundi(art.get_height() * 0.45))
	check(hidden.get_pixelv(at) != art.get_pixelv(at), "an unvisited Cinerea is hidden")
	check(part.get_pixelv(at).is_equal_approx(art.get_pixelv(at)), "a visited one shows")
	check(not part.get_pixelv(far).is_equal_approx(art.get_pixelv(far)), "and Boreas stays hidden")
	menu.queue_free()

func test_menu_equips_the_sword() -> void:
	_before()
	Journey.add_item(&"iron_sword")
	var menu := GameMenu.new()
	add_child(menu)
	menu.open()
	check(get_tree().paused, "it pauses the game")
	check(menu.item_at_cursor() == &"iron_sword", "the cursor starts on the first item (%s)" % menu.item_at_cursor())
	menu.use()
	check(Journey.has_weapon(), "E equips it")
	menu.turn_page()
	menu.turn_page()
	check(menu.page == 2, "Tab reaches the map")
	menu.close()
	check(not get_tree().paused, "closing it unpauses")
	menu.queue_free()

func test_the_road_from_the_tomb() -> void:
	var c := await _town()
	check(not c.player.has_weapon, "he wakes with nothing in his hand")
	check(c.player.global_position.distance_to(c._first.global_position) > Cinerea.SHY_AT, "he starts clear of the jackal")
	check(c._tomb.frame == 0, "the tomb starts shut")
	check(c._first.is_in_group(&"enemies"), "the jackal gets a health bar")
	check(&"cinerea" in Journey.visited and &"desert" in Journey.visited and &"boreas" not in Journey.visited, "the map knows the desert and Cinerea only (%s)" % [Journey.visited])
	var stamina := c.player.stamina.value
	Input.action_press(&"attack_light")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(&"attack_light")
	await get_tree().create_timer(0.1).timeout
	check(c.player.state != Elvis.State.LIGHT and c.player.stamina.value >= stamina, "he can't attack with no weapon")
	c.loot()
	check(Journey.bag.has(&"iron_sword") and Journey.drachma == 5, "the tomb's loot, as in STORY.md but with no shield (Danyal)")
	check(not Journey.ITEMS.has(&"worn_shield") and not &"shield" in Journey.SLOTS, "there are no shields at all")
	check(c.player.scripted and not c.player.input_enabled, "the scene takes him")
	var until := Time.get_ticks_msec() + 6000
	while c._busy and Time.get_ticks_msec() < until:
		await get_tree().physics_frame
	check(not c._busy, "the scene ends")
	check(not c.player.scripted and c.player.input_enabled and c.player.collision_mask != 0, "and gives him back")
	check(Vector2(c.player.global_position.x - Cinerea.TOMB_AT.x, c.player.global_position.z - Cinerea.TOMB_AT.y).length() > 1.5, "clear of the tomb")
	check(&"hammer" in Journey.memories, "the tomb brings back The Hammer")
	check(c._tomb.frame == c._tomb.hframes - 1, "its slab has slid off the pit (frame %d)" % c._tomb.frame)
	check(c._first.mode != Jackal.Mode.SLEEP, "the jackal has turned on him")
	Journey.toggle_equip(&"iron_sword")
	await get_tree().physics_frame
	check(c.player.has_weapon and c.player.spear_out, "equipping it puts it in his hand")
	c._first.scripted = true    # so a bite doesn't interrupt the check below
	await get_tree().create_timer(Elvis.HURT_TIME + 0.1).timeout
	Input.action_press(&"attack_light")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(&"attack_light")
	await get_tree().create_timer(0.1).timeout
	check(c.player.state == Elvis.State.LIGHT, "and now he can attack (state %s)" % c.player.state)
	c.queue_free()
	await get_tree().process_frame

func test_tab_opens_the_menu_and_turns_its_pages() -> void:
	_before()
	var menu := GameMenu.new()
	add_child(menu)
	var tab := InputEventAction.new()
	tab.action = &"menu_next"
	tab.pressed = true
	menu._unhandled_input(tab)
	check(menu.visible and menu.page == 0, "Tab opens it")
	menu._unhandled_input(tab)
	check(menu.page == 1, "and turns the page (%d)" % menu.page)
	menu.close()
	menu.queue_free()

func test_jackal_backs_off_the_tomb() -> void:
	var c := await _town()
	var was := c._first.global_position
	c.player.global_position = was + Vector3(3.0, 0.0, 0.0)
	await get_tree().create_timer(0.4).timeout
	check(c._first.global_position.distance_to(was) > 0.5, "it moves off as he comes near")
	check(c._first.mode == Jackal.Mode.SLEEP, "and leaves him alone until the tomb is open")
	c.queue_free()
	await get_tree().process_frame

func test_jackal_bites_and_dies() -> void:
	var ground := StaticBody3D.new()
	add_child(ground)
	var j := JACKAL.instantiate() as Jackal
	var bait := Node3D.new()
	add_child(bait)
	add_child(j)
	bait.global_position = Vector3(5.0, 0, 0)
	check(j.mode == Jackal.Mode.SLEEP, "it sleeps until woken")
	j.wake(bait)
	var from := j.global_position
	await get_tree().create_timer(0.3).timeout
	check(j.global_position.x > from.x + 0.5, "it runs at him (%s)" % j.global_position)
	var fell := [false]
	j.dead.connect(func() -> void: fell[0] = true)
	j.health.take(Jackal.HP)
	check(fell[0], "it dies at no health")
	await get_tree().create_timer(Jackal.BURN_TIME + 0.2).timeout
	check(not is_instance_valid(j), "and burns away")
	ground.queue_free()
	bait.queue_free()

func _hud() -> Hud:
	var hud := (load("res://ui/hud.tscn") as PackedScene).instantiate() as Hud
	hud.fast = true
	add_child(hud)
	return hud

func _until_asked(hud: Hud) -> void:
	for i in 300:
		if not hud._choices.is_empty():
			return
		await get_tree().process_frame
	check(false, "the choices came up")

func test_answers_move_trust_and_coin() -> void:
	_before()
	var hud := _hud()
	Talks.play(hud, Talks.LIVIA, "Livia")
	await _until_asked(hud)
	check(Array(hud._choices) == ["Show me where.", "What will you pay me?"], "Vulcan picks his line from DIALOGUE.md's choices")
	hud.pick(1)
	await get_tree().process_frame
	await _until_asked(hud)
	check(Journey.trust["Livia"] == -5, "asking to be paid costs her trust")
	hud.pick(0)
	for i in 120:
		await get_tree().process_frame
	check(Journey.trust["Livia"] == -15 and Journey.drachma == 4, "taking her coins costs more, and pays")
	hud.queue_free()

func test_cassia_greets_by_trust() -> void:
	check(Talks.stall_greeting(-5) == "You again. Coin first, chat later.", "wary")
	check(Talks.stall_greeting(10).begins_with("Ignotus."), "neutral")
	check(Talks.stall_greeting(30).begins_with("There's my favourite ghost."), "friendly")
	check(Talks.stall_greeting(60).begins_with("Sit, sit."), "trusted")

func test_zoom_stays_on_whole_pixels() -> void:
	const HD := Vector2i(1920, 1080)
	const QHD := Vector2i(2560, 1440)
	check(PixelCamera.view_for(HD, 0) == PixelCamera.VIEW and PixelCamera.view_for(QHD, 0) == PixelCamera.VIEW, "the default view is the game's own size")
	check(PixelCamera.view_for(HD, -1) == Vector2i(960, 540), "1080p zoomed out: 2 screen pixels an art pixel")
	check(PixelCamera.view_for(HD, 1) == Vector2i(480, 270), "1080p zoomed in: 4 screen pixels an art pixel")
	check(PixelCamera.view_for(QHD, -2) == Vector2i(1280, 720), "1440p zoomed out twice: 2 screen pixels an art pixel")
	check(PixelCamera.allowed_step(HD, -50) == -1 and PixelCamera.allowed_step(QHD, -50) == -2, "it stops at the farthest view")
	check(PixelCamera.allowed_step(HD, 50) == 3 and PixelCamera.view_for(HD, 3).y == 180, "and at the closest")
	var cam := PixelCamera.new()
	add_child(cam)
	check(is_equal_approx(cam.size, get_window().content_scale_size.y / Pixel.PX), "one art pixel stays one drawn pixel")
	cam.queue_free()

func test_towers_stand_clear_of_the_wall_they_cover() -> void:
	for z: float in [Cinerea.NORTH, Cinerea.NORTH + Cinerea.CORNER, Cinerea.SOUTH - Cinerea.CORNER, Cinerea.SOUTH]:
		check(Pixel.snap(Vector3(0.0, 0.0, z + Cinerea.IN_FRONT)).z > Pixel.snap(Vector3(0.0, 0.0, z)).z, "a tower at z %s doesn't snap back level with its wall" % z)

func test_structures_stop_him() -> void:
	_before()
	var c := CINEREA.instantiate() as Cinerea
	c.fast = true
	add_child(c)
	await get_physics_frame_twice()
	var space := c.get_world_3d().direct_space_state
	for p: Array in Cinerea.VILLAGE:
		if p[0] in Cinerea.WALK_OVER:
			continue
		var q := PhysicsPointQueryParameters3D.new()
		var tex := ImageTexture.create_from_image(Image.load_from_file("res://art/props/%s.png" % p[0]))
		q.position = Vector3(p[1] + Cinerea.foot_x(tex), 1.0, p[2] - 0.15)    # where its picture meets the ground
		check(not space.intersect_point(q).is_empty(), "%s at %s stops him" % [p[0], p[1]])
	for hit: Vector2 in [Vector2(0.0, -0.2), Vector2(3.2, -1.5), Vector2(-3.2, -1.5), Vector2(0.0, -3.0)]:
		var q := PhysicsPointQueryParameters3D.new()
		q.position = Vector3(Cinerea.FOUNTAIN_AT.x + hit.x, 1.0, Cinerea.FOUNTAIN_AT.y + hit.y)
		check(not space.intersect_point(q).is_empty(), "the fountain's rim stops him at %s" % hit)
	for hit: Vector3 in [Vector3(20.0, 1.0, Cinerea.NORTH - 0.5), Vector3(Cinerea.SIDE_X - 0.2, 1.0, 60.0), Vector3(52.0, 1.0, 32.0), Vector3(-52.0, 1.0, 90.0), Vector3(0.0, 1.0, Cinerea.SOUTH - 0.5)]:
		var q := PhysicsPointQueryParameters3D.new()
		q.position = hit
		check(not space.intersect_point(q).is_empty(), "the town wall stops him at %s" % hit)
	var gate := PhysicsPointQueryParameters3D.new()
	gate.position = Vector3(0.0, 1.0, Cinerea.NORTH - 0.5)
	check(space.intersect_point(gate).is_empty(), "the north gate lets him in")
	c.queue_free()

func test_nothing_stands_on_the_streets() -> void:
	var streets := Image.load_from_file("res://art/floors/town_streets.png")
	const FLOOR_AT := Cinerea.FLOOR
	for p: Array in Cinerea.VILLAGE:
		if p[0] in Cinerea.ON_STONES:
			continue
		var tex := Arena.prop_sprite(p[0], 0.0, 0.0).texture
		var size := Cinerea.footprint(p[0], tex)
		if size == Vector2.ZERO:
			size = Vector2(tex.get_width() / Pixel.PX, 0.4)
		var worst := 0.0
		for i in 5:
			for j in 3:
				var x: float = p[1] + size.x * (i / 4.0 - 0.5)
				var z: float = p[2] - size.y * (j / 2.0)
				var u := roundi((x - FLOOR_AT.position.x) * 4.0)
				var v := roundi((z - FLOOR_AT.position.y) * 4.0)
				if u >= 0 and v >= 0 and u < streets.get_width() and v < streets.get_height():
					worst = maxf(worst, streets.get_pixel(u, v).r)
		check(worst < 0.6, "%s at (%s, %s) stands on a street" % [p[0], p[1], p[2]])

# A real E: through Input, so the game's polling and Hud's input both see it, as they do in play.
func _press_e() -> void:
	await _press(&"confirm")

func _press(action: StringName) -> void:
	await get_tree().process_frame    # between physics ticks, where a real key press arrives
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	Input.flush_buffered_events()
	await get_physics_frame_twice()
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	await get_physics_frame_twice()

func test_goodbye_ends_the_talk_and_its_press_doesnt_start_another() -> void:
	_before()
	var c := CINEREA.instantiate() as Cinerea
	c.fast = true
	add_child(c)
	for i in 3000:
		if not c._busy:
			break
		await get_tree().process_frame
	c.hud.fast = false    # a line waits for E, as in play
	c.hud.letters = false    # and shows whole: test_a_line_fades_in has the fade
	c.player.global_position = c._cassia.position + Vector3.RIGHT
	c._cassia.set_shown(true)
	c._talk(c._cassia)
	await get_physics_frame_twice()
	check(c.hud._line_on, "she greets him")
	await _press_e()
	await _until_asked(c.hud)
	check("Goodbye." in c.hud._choices, "she offers a goodbye (%s)" % [c.hud._choices])
	check(c.hud.portrait == null, "his face doesn't show while you choose his answer")
	c.hud.pick(c.hud._choices.find("Goodbye."))
	await get_physics_frame_twice()
	check(c.hud._line_on, "she answers the goodbye")
	await _press_e()      # closes her last line, and she is still in reach
	check(not c._busy and not c.hud._line_on and c.hud._choices.is_empty(), "the talk is over and stays over")
	await _press_e()      # a new press, on purpose, does start one
	check(c._busy, "pressing E again talks to her again")
	c.queue_free()
	await get_physics_frame_twice()

func _town() -> Cinerea:
	_before()
	var c := CINEREA.instantiate() as Cinerea
	c.fast = true
	add_child(c)
	for i in 3000:
		if not c._busy:
			break
		await get_tree().process_frame
	return c

# Every brazier, the fire altar and every lantern throws a small warm light, low by day, with no shadow.
func test_the_town_fires_light_the_ground_round_them() -> void:
	var c := await _town()
	var lights: Array = c.get_children().filter(func(n: Node) -> bool: return n is OmniLight3D)
	var fires := 0
	for p: Array in Cinerea.VILLAGE:
		if Cinerea.FIRES.has(p[0]):
			fires += 1
			var lit := lights.any(func(l: OmniLight3D) -> bool: return Vector2(l.position.x - p[1], l.position.z - p[2]).length() < 0.5)
			check(lit, "%s at %s, %s has its light" % [p[0], p[1], p[2]])
	check(fires >= 7 and lights.size() == fires, "%d fires, %d lights" % [fires, lights.size()])
	for l: OmniLight3D in lights:
		check(not l.shadow_enabled and l.omni_range <= 4.0 and l.light_energy <= 1.0 and l.light_color.r > l.light_color.b, "small, low, warm and without a shadow")
	c.queue_free()
	await get_physics_frame_twice()

func test_the_shop_sells_what_he_can_pay_for() -> void:
	var c := await _town()
	var shop := c.shop
	Journey.add_item(&"iron_sword")
	Journey.toggle_equip(&"iron_sword")
	Journey.drachma = 5
	shop.open()
	check(get_tree().paused, "it pauses the game")
	check(not shop._him.visible and c.menu._him.visible, "the inventory's figure of him isn't drawn over her list")
	check(shop.rows() == [&"red_flask", &"green_flask", &"new_sword", &"copper_ring", &"bronze_amulet"], "she has flasks, gear and a new sword (%s)" % [shop.rows()])
	shop.row = 3
	shop.use()
	check(shop.said == Talks.BROKE and Journey.drachma == 5 and not Journey.bag.has(&"copper_ring"), "no coin, no ring")
	Journey.drachma = 100
	shop.row = 0
	shop.use()
	check(shop.said == Talks.NO_ROOM and Journey.drachma == 100, "full flasks can't take another, and he isn't charged")
	c.player.flasks.red = 1
	shop.use()
	check(c.player.flasks.red == 2 and Journey.drachma == 94, "a red flask for 6 (%d, %d)" % [c.player.flasks.red, Journey.drachma])
	shop.row = 3
	shop.use()
	check(Journey.bag.has(&"copper_ring") and Journey.drachma == 74, "the ring goes in the bag")
	check(&"copper_ring" not in shop.rows(), "and off the shelf")
	shop.row = 2
	shop.use()
	check(Journey.drachma == 49 and Journey.equipped[&"weapon"] == &"new_sword" and c.player.has_weapon, "the new sword goes straight into his hand")
	check(Journey.bag.has(&"iron_sword") and &"new_sword" not in shop.rows(), "he keeps the old one, and she has no more new ones")
	shop.turn_page()
	check(&"iron_sword" in shop.rows() and &"new_sword" not in shop.rows(), "she'll buy the old one, not the one in his hand (%s)" % [shop.rows()])
	shop.row = shop.rows().find(&"iron_sword")
	shop.use()
	check(Journey.drachma == 54 and not Journey.bag.has(&"iron_sword"), "the old sword sells for 5")
	Journey.toggle_equip(&"new_sword")
	check(&"new_sword" not in shop.rows(), "she won't take his last sword, in his hand or not, or he could never fight again")
	shop.close()
	check(not get_tree().paused, "leaving unpauses")
	c.queue_free()

func test_the_shop_buys_loot_and_prices_follow_trust() -> void:
	var c := await _town()
	var shop := c.shop
	Journey.add_item(&"jackal_pelt", 2)
	Journey.add_item(&"hammer_head")
	Journey.add_item(&"iron_sword")
	Journey.add_item(&"copper_ring")
	Journey.toggle_equip(&"copper_ring")
	shop.open()
	shop.turn_page()
	check(shop.rows() == [&"jackal_pelt"], "she won't take his sword, the hammer head or what he has on (%s)" % [shop.rows()])
	shop.use()
	check(Journey.drachma == 3 and Journey.bag[&"jackal_pelt"] == 1, "one pelt for 3")
	shop.use()
	check(Journey.drachma == 6 and shop.rows().is_empty(), "and the last")
	shop.use()
	check(Journey.drachma == 6, "an empty list sells nothing")
	shop.close()
	Journey.trust["Cassia"] = -5
	check(Journey.buy_price(&"copper_ring") == 25 and Journey.sell_price(&"raider_buckle") == 6, "dearer when she's wary")
	Journey.trust["Cassia"] = 30
	check(Journey.buy_price(&"copper_ring") == 18 and Journey.sell_price(&"raider_buckle") == 9, "a small discount when she's friendly")
	Journey.trust["Cassia"] = 60
	check(Journey.buy_price(&"copper_ring") == 16 and Journey.sell_price(&"raider_buckle") == 10, "the best when she trusts him")
	c.queue_free()

func test_what_he_wears_changes_him() -> void:
	var c := await _town()
	var p := c.player
	Journey.add_item(&"copper_ring")
	Journey.add_item(&"bronze_amulet")
	Journey.toggle_equip(&"copper_ring")
	Journey.toggle_equip(&"bronze_amulet")
	check(p.stamina.max_value == Elvis.MAX_STAMINA + 30.0 and p.stamina.value == p.stamina.max_value, "the ring gives stamina (%s)" % p.stamina.max_value)
	check(p.health.max_hp == Elvis.MAX_HEALTH + 25.0 and p.health.hp == p.health.max_hp, "the amulet gives health (%s)" % p.health.max_hp)
	Journey.toggle_equip(&"copper_ring")
	Journey.toggle_equip(&"bronze_amulet")
	check(p.stamina.max_value == Elvis.MAX_STAMINA and p.health.max_hp == Elvis.MAX_HEALTH and p.health.hp == p.health.max_hp, "taking them off takes it back")
	p._attack = Elvis.ATTACKS["light1"]
	Journey.add_item(&"iron_sword")
	Journey.toggle_equip(&"iron_sword")
	var dull := p._blow().damage
	Journey.add_item(&"new_sword")
	Journey.toggle_equip(&"new_sword")
	check(is_equal_approx(p._blow().damage, dull * 1.25), "the new sword bites a quarter harder")
	c.queue_free()

# The HUD draws over the world: the sign holds back until the killing blow's number has gone, then stays its whole time.
func test_the_loot_sign_waits_for_the_number() -> void:
	var c := await _town()
	c.fast = false
	c.looted = true    # or the tomb's hint takes the sign down
	c._first.health.take(1000.0)
	check(is_instance_valid(c.hud._pop) and c.hud._pop_t < 0.0, "not yet (%s)" % c.hud._pop_t)
	await get_tree().create_timer(FxNumber.LIFE + 0.1).timeout
	check(is_instance_valid(c.hud._pop) and c.hud._pop_t >= 0.0, "it shows once the number has gone (%s)" % c.hud._pop_t)
	await get_tree().create_timer(Cinerea.LOOT_SIGN - 0.3).timeout
	check(is_instance_valid(c.hud._pop), "and it still has its time")
	await get_tree().create_timer(0.4).timeout
	check(not is_instance_valid(c.hud._pop), "then it goes")
	c.queue_free()

func test_foes_leave_loot() -> void:
	var c := await _town()
	c._first.health.take(1000.0)
	check(Journey.bag.get(&"jackal_pelt") == 1, "a jackal leaves a pelt in his bag")
	check(c.hud._pop_title == "+ Jackal Pelt" and is_instance_valid(c.hud._pop), "and a sign says so")
	await get_tree().create_timer(Cinerea.LOOT_SIGN * 0.05 + 0.1).timeout
	check(not is_instance_valid(c.hud._pop), "the sign goes")
	c._foe("raider_sword", "walk", "slash", 40.0, 2.7, Vector3.ZERO, &"raider_buckle").health.take(1000.0)
	check(Journey.bag.get(&"raider_buckle") == 1, "a raider leaves a buckle")
	c.queue_free()

func test_her_answers_open_the_shop_and_leaving_ends_the_talk() -> void:
	var c := await _town()
	c.hud.fast = false    # a line waits for E, as in play
	c.hud.letters = false    # and shows whole: test_a_line_fades_in has the fade
	c.player.global_position = c._cassia.position + Vector3.RIGHT
	c._cassia.set_shown(true)
	c._talk(c._cassia)
	await get_physics_frame_twice()
	await _press_e()
	await _until_asked(c.hud)
	check(c.hud._choices[0] == "I'm buying." and c.hud._choices[1] == "I'm selling.", "buying and selling come first (%s)" % [c.hud._choices])
	Journey.drachma = 50
	c.player.flasks.red = 1
	await _press_e()
	check(c.shop.visible and get_tree().paused, "the shop opens")
	check(Journey.drachma == 50 and c.player.flasks.red == 1, "the press that opened it doesn't buy anything")
	await _press_e()
	check(Journey.drachma == 44 and c.player.flasks.red == 2, "the next one buys the row it's on")
	await _press(&"menu_next")
	check(c.shop.selling and c.shop.visible and not c.menu.visible, "Tab turns to selling, and doesn't open his things")
	await _press(&"move_left")
	check(not c.shop.selling, "left turns back")
	var i_key := InputEventKey.new()
	i_key.physical_keycode = KEY_I
	i_key.pressed = true
	Input.parse_input_event(i_key)
	await get_physics_frame_twice()
	i_key = i_key.duplicate()
	i_key.pressed = false
	Input.parse_input_event(i_key)
	await get_physics_frame_twice()
	check(not c.shop.visible and not get_tree().paused and not c.menu.visible, "I leaves it, and doesn't open his things")
	check(c.hud._line_on and c.hud.last_line == "Mind the jackals.", "she sees him off (%s)" % c.hud.last_line)
	await _press_e()
	check(not c._busy and not c.hud._line_on, "the talk is over and stays over")
	await _press_e()
	await _press_e()
	await _until_asked(c.hud)
	c.hud.pick(1)
	await get_physics_frame_twice()
	check(c.shop.visible and c.shop.selling, "I'm selling opens it on her Sell page")
	c.shop.close()
	c.queue_free()
	await get_physics_frame_twice()

func test_the_new_sword_shows_on_him_and_he_breathes_in_the_inventory() -> void:
	var c := await _town()
	var p := c.player
	Journey.add_item(&"iron_sword")
	Journey.add_item(&"new_sword")
	Journey.toggle_equip(&"iron_sword")
	check(p.sprite.character == "vulcan_human", "the old sword, the old look (%s)" % p.sprite.character)
	check(p.combo_max == 2, "his light string is his own two slashes (%d)" % p.combo_max)
	Journey.toggle_equip(&"new_sword")
	check(p.sprite.character == "vulcan_new_sword" and p.has_weapon, "the new sword has its own (%s)" % p.sprite.character)
	var armed: Rect2 = p.sprite.looped_frame("idle_spear_F", 0.0)["region"]
	check(p.sprite.looped_frame("idle_spear_F", 0.8)["region"] != armed, "his breath moves on with time")
	check(p.sprite.looped_frame("idle_spear_F", 1.4)["region"] == armed, "and loops, 0.7 s in and 0.6 s out")
	check(p.sprite.looped_frame("idle_F", 0.0)["tex"] != null and p.sprite.looped_frame("no such move", 0.0).is_empty(), "the empty-handed idle is there, and a missing one is no crash")
	Journey.toggle_equip(&"new_sword")
	check(p.sprite.character == "vulcan_human" and not p.has_weapon, "and back without it")
	c.menu.open()
	var before := c.menu._idle_time
	await get_tree().process_frame
	await get_tree().process_frame
	check(c.menu._idle_time > before, "his idle plays while the game is paused behind the inventory")
	c.menu.close()
	c.queue_free()

func test_she_cant_be_stopped_on_her_way_to_the_stall() -> void:
	_before()
	var c := CINEREA.instantiate() as Cinerea
	c.fast = true
	add_child(c)
	await get_physics_frame_twice()
	c._cassia.set_shown(true)
	c._cassia.walk_to([Cinerea.STALL_AT])
	var at := c._cassia.position
	check(c._nearest(Vector2(at.x, at.z) + Vector2.RIGHT) != c._cassia, "no talking to her while she walks to her stall")
	c.queue_free()
	await get_physics_frame_twice()

func test_choosing_an_answer_goes_straight_to_their_reply() -> void:
	_before()
	var hud := _hud()
	var said := PackedStringArray()
	hud.line_done.connect(func() -> void: said.append(hud.last_line))
	Talks.play(hud, Talks.BOY, "A boy")
	await _until_asked(hud)
	hud.pick(0)
	for i in 120:
		await get_tree().process_frame
	check(said.size() == 2 and not "I lost it." in said, "he doesn't say the answer you chose (%s)" % [said])
	hud.queue_free()

func test_a_long_line_wraps() -> void:
	var hud := _hud()
	for row in hud._wrap("My stall's by the fountain, and the job board's next to it. Come find me when you want work. Or a bath. Mostly a bath."):
		check(Hud.text_w(row, Hud.TEXT) <= Hud.LINE_WIDTH, "%s fits" % row)
	hud.queue_free()

func test_cassia_scene_plays_through() -> void:
	var c := await _town()
	check(not c._cassia.shown(), "she stays under the cart while the raiders live")
	var at_first := Journey.drachma
	c._raiders_left = 1
	c._raider_down()
	var shown_where := Vector3.ZERO
	for i in 3000:
		if c.met_cassia:
			break
		if c._cassia.shown() and shown_where == Vector3.ZERO:
			await get_tree().process_frame
			await get_tree().process_frame
			shown_where = c._cassia.sprite._sprite.global_position
		if not c.hud._choices.is_empty():
			c.hud.pick(0)
		await get_tree().process_frame
	check(c.met_cassia, "the scene ends")
	check(shown_where.distance_to(CassiaScene.DOOR_AT) < 6.0, "she is drawn at the cart, not somewhere else (%s)" % shown_where)
	check(Journey.drachma >= at_first + CassiaScene.PURSE, "he has his pay")
	check(c.player.input_enabled and not c._busy, "he has control again")
	check(not c._cassia.shown(), "she's in the carriage")
	check(c.pull.walking(), "it sets off")
	c.queue_free()
	await get_physics_frame_twice()

# The whole scene as far as the carriage setting off.
func _to_setting_off(c: Cinerea) -> void:
	c._raiders_left = 1
	c._raider_down()
	for i in 6000:
		if c.met_cassia:
			return
		if not c.hud._choices.is_empty():
			c.hud.pick(0)
		await get_tree().process_frame

func _solid_at(c: Cinerea, at: Vector3) -> bool:
	var q := PhysicsPointQueryParameters3D.new()
	q.position = at + Vector3.UP
	q.exclude = [c.player.get_rid()]
	return not c.get_world_3d().direct_space_state.intersect_point(q).is_empty()

func test_she_gets_in_and_the_camel_pulls_it_through_the_gate_to_her_stall() -> void:
	var c := await _town()
	check(_solid_at(c, Vector3(-6.5, 0.0, 0.0)), "the carriage stops him where it stands")
	await _to_setting_off(c)
	check(c.met_cassia and c.cart_door().frame == 0, "the door shut behind her")
	check(not c._cassia.shown() and not c.cart_sprite().visible, "she's inside, and the harnessed picture has taken over from the carriage")
	check(not c._fortuna.shown(), "and from the camel")
	await get_physics_frame_twice()
	check(not _solid_at(c, Vector3(-6.5, 0.0, 0.0)), "what stopped him at the carriage has gone with it")
	var through := false
	var cut := 0.0
	for i in 2000:
		await get_tree().physics_frame
		if c.pull.walking():
			check(c.pull.find_children("*", "CollisionShape3D", true, false).is_empty() and not _solid_at(c, c.pull.position), "it stops nobody on its way (%s)" % c.pull.position)
		if absf(c.pull.position.z - Cinerea.NORTH) < 1.0:
			through = true
			check(absf(c.pull.position.x) < Cinerea.GATE_HALF, "the road goes through the arch")
			cut = maxf(cut, c.pull.sprite._mat.get_shader_parameter(&"cut"))
		if not c.pull.walking():
			break
	check(through and c.pull.position.is_equal_approx(CassiaScene.PARK), "it reaches where it parks (%s)" % c.pull.position)
	check(cut > 0.0, "in the arch the top of its picture is still behind the wall")
	await get_physics_frame_twice()
	check(c.pull.sprite._mat.get_shader_parameter(&"cut") == 0.0 and c.pull.sprite.front_of == -INF, "and when it's parked it's whole")
	check(c._cassia.shown() and c._cassia.walking(), "she gets out and goes on to her stall")
	check(c._nearest(Vector2(c._cassia.position.x, c._cassia.position.z) + Vector2.RIGHT) != c._cassia, "not to be talked to on the way")
	check(_solid_at(c, CassiaScene.PARK + Vector3(-1.05, 0.0, -1.24)) and _solid_at(c, CassiaScene.PARK + Vector3(1.75, 0.0, 1.2)), "parked, it stops him at the wagon and the camel")
	var streets := Image.load_from_file("res://art/floors/town_streets.png")
	for b: Array in CarriagePull.BOXES:
		for k: float in [-0.5, 0.5]:
			var on := Vector2(CassiaScene.PARK.x + b[0], CassiaScene.PARK.z + b[1]) + Vector2(b[2] * k, 0.0).rotated(CarriagePull.HEADING)
			check(streets.get_pixel(roundi((on.x - Cinerea.FLOOR.position.x) * 4.0), roundi((on.y - Cinerea.FLOOR.position.y) * 4.0)).r < 0.6, "where it parks isn't on a street (%s)" % on)
	var camel := CassiaScene.PARK + CassiaScene.CAMEL_AT
	check(c._nearest(Vector2(camel.x, camel.z) + Vector2(0.0, 0.6)) == c._fortuna, "Fortuna can still be talked to in her harness")
	for i in 2000:
		if not c._cassia.walking():
			break
		await get_tree().physics_frame
	check(c._cassia.position.is_equal_approx(Cinerea.STALL_AT), "she reaches her stall")
	check(c._nearest(Vector2(Cinerea.STALL_AT.x, Cinerea.STALL_AT.z) + Vector2(0.0, 1.0)) == c._cassia, "and can be talked to there")
	c.queue_free()
	await get_physics_frame_twice()

func test_her_way_to_the_stall_goes_round_what_stands_on_it() -> void:
	var c := await _town()
	await get_physics_frame_twice()
	var from := CassiaScene.PARK + CassiaScene.GETS_OUT_AT
	for to: Vector3 in CassiaScene.TO_THE_STALL:
		for i in ceili(from.distance_to(to) * 10.0):
			var at := from.move_toward(to, i * 0.1)
			for side: float in [-0.45, 0.0, 0.45]:    # her picture's half width
				check(not _solid_at(c, at + Vector3(side, 0.0, 0.0)), "nothing's in her way at %s" % (at + Vector3(side, 0.0, 0.0)))
		from = to
	c.queue_free()
	await get_physics_frame_twice()

func test_parked_fortuna_breathes_and_chews_and_nothing_else_moves() -> void:
	var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/carriage_pull/manifest.json"))
	var idle: Dictionary = m["anims"]["idle_S"]
	check(idle["file"] != m["anims"]["walk_S"]["file"] and idle["frames"] > 1, "she has an idle of her own, not a frozen step")
	var sheet := Image.load_from_file("res://art/carriage_pull/%s" % idle["file"])
	var cell := Vector2i(m["cell"][0], m["cell"][1])
	var part := func(i: int, r: Rect2i) -> PackedByteArray: return sheet.get_region(Rect2i(r.position + Vector2i(i * cell.x, 0), r.size)).get_data()
	var wagon := Rect2i(0, 0, 150, cell.y)
	var feet := Rect2i(0, 149, cell.x, cell.y - 149)
	var whole := Rect2i(Vector2i.ZERO, cell)
	var different := {}
	for i in int(idle["frames"]):
		check(part.call(i, wagon) == part.call(0, wagon), "frame %d: the wagon, the shafts and her haunch stay" % i)
		check(part.call(i, feet) == part.call(0, feet), "frame %d: her feet stay" % i)
		different[part.call(i, whole)] = true
	check(different.size() >= 4, "breath and jaw each go up and down (%d pictures)" % different.size())
	var c := await _town()
	await _to_setting_off(c)
	for i in 2000:
		if not c.pull.walking():
			break
		await get_tree().physics_frame
	await get_physics_frame_twice()
	check(c.pull.sprite.current_key == "idle_S", "parked it plays her idle (%s)" % c.pull.sprite.current_key)
	var parts := c.find_children("*", "Sprite3D", false, false).filter(func(s: Sprite3D) -> bool: return s.texture == c.pull.sprite._sprite.texture)
	check(not parts.is_empty(), "the columns are cut from her idle")
	for i in 120:
		if c.pull.sprite.frame != 0:
			break
		await get_tree().physics_frame
	check(c.pull.sprite.frame != 0, "it goes on playing")
	for s: Sprite3D in parts:
		check(int(s.region_rect.position.x) / cell.x == c.pull.sprite.frame, "and what stands there shows the same frame")
	c.queue_free()
	await get_physics_frame_twice()

func test_a_ground_shadow_lies_over_its_picture_with_its_ground_line_on_the_floor() -> void:
	var tex := ImageTexture.create_from_image(Image.create(40, 60, false, Image.FORMAT_RGBA8))
	var s := Arena.ground_shadow(tex, Rect2(10, 5, 20, 50), Vector2(12, 40), 0.5, Vector2(20, 30))
	for at: Vector2 in [Vector2(12, 40), Vector2(28, 49), Vector2(14, 10)]:
		var w: Vector3 = s.transform * (Vector3((at.x - 20.0) / Pixel.PX, (30.0 - at.y) / Pixel.PX, 0.0))    # the part's middle is at 20, 30
		check(is_equal_approx(w.x * Pixel.PX, at.x - 20.0) and absf(w.z * 24.0 - w.y * Pixel.PX * cos(deg_to_rad(Pixel.PITCH_DEG)) - (at.y - 30.0)) < 0.01, "%s shows where the picture has it (%s)" % [at, w])
		if at.y == 40.0 + (at.x - 12.0) * 0.5:
			check(absf(w.y) < 0.001, "%s is on the floor (%s)" % [at, w.y])

func test_the_carriages_hooves_and_wheels_meet_the_line_its_shadow_stands_on() -> void:
	var low := func(sheet: Image, frame: int, x: int) -> int:
		for y in range(191, -1, -1):
			if sheet.get_pixel(frame * 232 + x, y).a > 0.5:
				return y
		return -1
	for at: Array in [["walk_S", 20, "S"], ["idle_S", 12, "S"], ["walk_F", 13, "F"]]:
		var sheet := Image.load_from_file("res://art/carriage_pull/%s.png" % at[0])
		var t: Array = CarriagePull.THROWS[at[2]]
		for f: int in at[1]:
			var over := -INF    # how far the hoof nearest the camera comes past the camel's line: too far above it and her shadow leaves her feet
			for x in range(int(t[1][0].position.x), int(t[1][0].end.x)):
				over = maxf(over, low.call(sheet, f, x) - (t[1][1].y + (x - t[1][1].x) * t[1][2]))
			check(absf(over) <= 6.0, "%s %d: her hooves are on the line (%.1f rows)" % [at[0], f, over])
			if at[2] == "S":
				for x: int in [35, 88]:
					check(absf(low.call(sheet, f, x) - (t[0][1].y + (x - t[0][1].x) * t[0][2])) <= 2.0, "%s %d: so are its near wheels" % [at[0], f])

func test_the_carriages_shadow_goes_with_it_all_the_way() -> void:
	var c := await _town()
	var prop_shadow := c.cart_sprite().get_child(1) as Sprite3D
	check(c.cart_sprite().cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and prop_shadow.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY and prop_shadow.is_visible_in_tree(), "the still prop's stands on its wheels too")
	await _to_setting_off(c)
	check(not prop_shadow.is_visible_in_tree(), "and goes with it")
	var p := c.pull
	var views := {}
	var was := p.position.x
	var follows := func() -> bool:
		var view := p.sprite.current_key.right(1)
		views[view] = true
		var right := true
		for v: String in p._throws:
			for s: Sprite3D in p._throws[v]:
				right = right and s.visible == (v == view) and s.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
				if s.visible:
					right = right and s.texture == p.sprite._sprite.texture and int(s.region_rect.position.x) / 232 == p.sprite.frame
		return right
	check(p.sprite._sprite.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "the upright picture throws none, or it'd throw the old one too")
	for i in 2000:
		await get_tree().physics_frame
		check(follows.call(), "its shadow shows the view and frame it's on (%s %d)" % [p.sprite.current_key, p.sprite.frame])
		check(p.position.x >= was and not p.sprite._sprite.flip_h, "it never heads west, so its picture is never mirrored (%s)" % p.position)
		was = p.position.x
		for corner: Vector2 in [Vector2(-3.7, -1.5), Vector2(3.7, 1.8)]:
			var at := Vector2(p.position.x, p.position.z) + corner
			check(Hills.height_at(at.x, at.y) == 0.0 and Hills.lean(at.x, at.y) == Vector3.ZERO, "no slope under it, so its shadow's line stays on the floor (%s)" % at)
		if not p.walking():
			break
	check(views.has("S") and views.has("F"), "both views came up (%s)" % views)
	await get_physics_frame_twice()
	check(not p.sprite._sprite.visible, "parked its columns are all that show")
	for i in 120:
		await get_tree().physics_frame
		check(follows.call(), "and its shadow goes on with her idle (%d)" % p.sprite.frame)
		if p.sprite.frame != 0:
			break
	check(p.sprite.frame != 0, "which plays")
	c.queue_free()
	await get_physics_frame_twice()

func test_the_carriage_never_traps_him_where_it_parks() -> void:
	var c := await _town()
	await _to_setting_off(c)
	var on_the_spot := CassiaScene.PARK + Vector3(-1.05, 0.0, -1.24)
	c.player.collision_mask = 0
	c.player.global_position = on_the_spot
	c.player.reset_physics_interpolation()
	for i in 2000:
		if not c.pull.walking():
			break
		await get_tree().physics_frame
	await get_physics_frame_twice()
	check(not _solid_at(c, on_the_spot), "he's standing where it stopped: it doesn't turn solid on him")
	c.player.global_position = CassiaScene.PARK + Vector3(0.0, 0.0, 6.0)
	await get_physics_frame_twice()
	await get_physics_frame_twice()
	check(_solid_at(c, on_the_spot), "and does when he's stepped clear")
	c.queue_free()
	await get_physics_frame_twice()

func test_the_gap_in_the_wall_matches_the_arch() -> void:
	var c := await _town()
	var tex := Arena.prop_sprite("gatehouse", 0.0, 0.0).texture
	var img := tex.get_image()
	check(img.get_width() % 2 == 0, "the arch is the picture's middle, so the road runs through it")
	var row := img.get_height() - 60    # the dark of the arch, under the spikes
	var half := 0
	while img.get_pixel(img.get_width() / 2 + half, row).get_luminance() < 0.2:
		half += 1
	near(half / Pixel.PX, Cinerea.GATE_HALF, 0.1, "the wall's gap is as wide as the arch")
	near(tex.get_width() / Pixel.PX / 2.0, Cinerea.GATEHOUSE_HALF, 0.05, "and the wall meets the gatehouse's sides")
	check(_solid_at(c, Vector3(Cinerea.GATE_HALF + 0.1, 0.0, Cinerea.NORTH - 1.0)) and not _solid_at(c, Vector3(Cinerea.GATE_HALF - 0.1, 0.0, Cinerea.NORTH - 1.0)), "the box stops him at the arch's edge")
	check(not _solid_at(c, Vector3(2.5, 0.0, Cinerea.NORTH - 0.3)) and _solid_at(c, Vector3(3.5, 0.0, Cinerea.NORTH - 0.3)), "and between the pillars' feet only at the pillars")
	c.player.global_position = Vector3(6.0, 0.0, Cinerea.NORTH - 13.0)    # behind the gatehouse's tower, higher than the wall
	await get_physics_frame_twice()
	var hole := false
	for h: Array in c._holes:
		if h[4] and absf(h[1] - Cinerea.NORTH) < 0.1 and h[2] == 0.0:
			hole = true
	check(hole, "behind its taller picture he still opens a hole")
	c.queue_free()
	await get_physics_frame_twice()

func get_physics_frame_twice() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame

func test_a_line_fades_in_and_enter_finishes_the_fade_first() -> void:
	_before()
	var hud := _hud()
	hud.fast = false
	hud.letters = true
	hud.say("Cassia", "Mind the jackals, love.")
	await get_tree().process_frame
	check(hud._shown < hud.last_line.length(), "its letters are still coming up")
	var e := InputEventAction.new()
	e.action = &"confirm"
	e.pressed = true
	hud._unhandled_input(e)
	check(hud._line_on and hud._shown == INF, "Enter finishes the fade and leaves the line up")
	hud._unhandled_input(e)
	check(not hud._line_on, "and the next one moves on")
	hud.queue_free()

func test_clicking_an_enemy_locks_on_to_it() -> void:
	var c := await _town()
	var foe := c._first
	var at := c.camera.unproject_position(foe.global_position + Vector3.UP * 0.7)
	c.player._lock_at(at + Vector2(200.0, 0.0))
	check(c.player.lock_target == null, "a click on nothing locks nothing")
	c.player._lock_at(at + Vector2(4.0, 2.0))
	check(c.player.lock_target == foe, "a click on it locks on to it")
	foe.health.take(1000.0)
	await get_tree().process_frame
	check(not c.player._locked(), "and the lock lets go when it falls")
	c.queue_free()

func test_hammer_blow_on_its_key() -> void:
	var c := await _town()
	var p := c.player
	Journey.add_item(&"iron_sword")
	Journey.toggle_equip(&"iron_sword")
	p._use_ability(&"ability_f")
	check(p.state == Elvis.State.MOVE, "not until he's learned it")
	Journey.remember(&"hammer")
	check(Journey.ability_slots[&"ability_f"] == "Hammer Blow", "what he learns goes on F")
	Journey.cycle_ability("Hammer Blow")
	check(Journey.ability_slots[&"ability_f"] == "" and Journey.ability_slots[&"ability_q"] == "Hammer Blow", "E in the Memory Paths moves it to Q")
	var foe := c._first
	var target := p.global_position + Vector3(5.0, 0.0, 2.0)
	foe.global_position = target + Vector3(1.0, 0.0, 0.0)
	var hp := foe.health.hp
	var stamina := p.stamina.value
	p._mouse_aims = false
	Input.action_press(&"ability_q")
	p._use_ability(&"ability_q")
	check(p.state == Elvis.State.AIM, "holding it, he chooses where (state %s)" % p.state)
	p._aim_at = target
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(p.state == Elvis.State.AIM and p._aim_mark.visible, "there's a mark on the ground while it's held")
	check(p.stamina.value >= stamina - 0.01, "and it costs nothing until he goes")
	p._aim_at = p.global_position + Vector3(40.0, 0.0, 0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(p._aim_at.distance_to(p.global_position) <= 8.01, "it reaches only so far")
	p._aim_at = target
	Input.action_release(&"ability_q")
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(p.state == Elvis.State.ABILITY and p.stamina.value < stamina, "let go, he goes, and it costs him")
	check(not p._aim_mark.visible, "the mark goes")
	check(p.sprite.current_key == "hammer_blow_S", "he leaps with it (%s)" % p.sprite.current_key)
	check(p.collision_mask == 0, "over whatever's in the way")
	await get_tree().create_timer(0.3).timeout
	check(p.sprite.position.y > 0.1, "up in the air (%s)" % p.sprite.position.y)
	for i in 120:
		await get_tree().physics_frame
		if p.state != Elvis.State.ABILITY:
			break
	check(Vector2(p._head_at.x - target.x, p._head_at.z - target.z).length() < 0.3, "the hammer's head comes down where he chose (%s)" % p._head_at)
	check(p.global_position.x < target.x - 2.8, "and he isn't under it (%s)" % p.global_position)
	check(p.sprite.position.y == 0.0 and p.collision_mask != 0, "on the ground again")
	check(foe.health.hp < hp, "the blow lands on what's there")
	check(p.state == Elvis.State.MOVE and p.ability_wait(&"ability_q") > 0.0, "and it has to cool before he can again")
	p._use_ability(&"ability_q")
	check(p.state == Elvis.State.MOVE, "so it won't go twice")
	c.queue_free()
	await get_physics_frame_twice()
	Fx.clear_all()

func test_everyone_leaves_footprints() -> void:
	var c := await _town()
	var count := func(w: Node) -> int: return w.get_children().filter(func(n: Node) -> bool: return n is Steps.FootPrint).size()
	var before: int = count.call(c)
	c.player.move_to(c.player.global_position + Vector3(6.0, 0.0, 0.0), 3.0)
	for i in 150:
		await get_tree().physics_frame
	var after: int = count.call(c)
	check(after >= before + 3, "he leaves a print each step (%d, %d)" % [before, after])
	check(Steps.WHO["jackal"][0] != Steps.WHO["vulcan_human"][0] and Steps.WHO["fortuna"][0] != Steps.WHO["cassia"][0], "and not everyone's are the same")
	check(c._on_stone(0.0, -20.0) and not c._on_stone(10.0, -20.0), "no sand flies off the road")
	c.queue_free()

func test_grass_bends_for_whoever_walks_into_it() -> void:
	var c := await _town()
	var grass: Grass = c.find_children("*", "Grass", true, false)[0]
	check(grass.tufts() > 100, "the desert has grass (%d)" % grass.tufts())
	var at := grass._at[0]
	await get_physics_frame_twice()
	check(grass.bend_of(0) == 0.0, "standing alone it only sways with the wind")
	c.player.global_position = Vector3(at.x - 0.4, 0.0, at.y)
	await get_physics_frame_twice()
	check(grass.bend_of(0) > 0.0, "he shoves it away from him")
	c.player.global_position = Vector3(at.x + 30.0, 0.0, at.y)
	for i in 60:
		await get_physics_frame_twice()
	check(absf(grass.bend_of(0)) < 0.01, "and it springs back")
	c.queue_free()

func test_he_can_walk_right_up_to_the_walls() -> void:
	var c := await _town()
	var space := c.get_world_3d().direct_space_state
	var q := PhysicsPointQueryParameters3D.new()
	q.position = Vector3(20.0, 1.0, Cinerea.SOUTH - 1.7)
	check(space.intersect_point(q).is_empty(), "there's room right up against the south wall")
	c.player.global_position = q.position - Vector3(0.0, 1.0, 0.0)
	await get_physics_frame_twice()
	var south: ShaderMaterial = null
	for h: Array in c._holes:
		if h[1] == Cinerea.SOUTH and absf(20.0 - h[2]) < h[3]:
			south = h[0]
	check(float(south.get_shader_parameter(&"hole_r")) > 0.0, "and the wall opens round him")
	c.player.global_position = Vector3(20.0, 0.0, 60.0)
	await get_physics_frame_twice()
	check(float(south.get_shader_parameter(&"hole_r")) == 0.0, "and shuts when he's away from it")
	c.queue_free()

func test_the_fountain_stands_in_columns() -> void:
	var c := await _town()
	var middle := c._fountain[c._fountain.size() / 2]
	var edge := c._fountain[0]
	check(edge.position.z < middle.position.z - 1.0, "its sides stand further back than its front (%s, %s)" % [edge.position.z, middle.position.z])
	var space := c.get_world_3d().direct_space_state
	var q := PhysicsPointQueryParameters3D.new()
	q.position = Vector3(Cinerea.FOUNTAIN_AT.x + 3.17, 1.0, Cinerea.FOUNTAIN_AT.y - 0.2)
	check(space.intersect_point(q).is_empty() and q.position.z > edge.position.z, "where you found him in it he's on open ground, in front of that side")
	c.queue_free()

# Each stretch has its own light, and walking from one to the next takes it there. While a scene plays the scene's mood stands.
func test_the_light_follows_him_down_the_road() -> void:
	var c := await _town()
	var p := c.player
	for spot: Array in [[-30.0, &"grave"], [-10.0, &"clear"], [5.0, &"lake"], [60.0, &"town"]]:
		p.global_position = Vector3(0.0, 0.0, spot[0])
		p.reset_physics_interpolation()
		await get_physics_frame_twice()
		check(c.mood == spot[1], "at z %s it is %s (got %s)" % [spot[0], spot[1], c.mood])
	c._busy = true
	c.set_mood(&"hush", 0.0)
	await get_physics_frame_twice()
	check(c.mood == &"hush", "a scene's mood stands while it plays (%s)" % c.mood)
	c._busy = false
	await get_physics_frame_twice()
	check(c.mood == &"town", "and the stretch's comes back after it (%s)" % c.mood)
	c.queue_free()

func test_the_lake_and_the_raiders() -> void:
	var c := await _town()
	c.loot()
	while c._busy:
		await get_tree().process_frame
	check(c._sleepers.size() > 0 or true, "")
	await get_physics_frame_twice()
	check(c._sleepers.size() >= 8, "the jackals and scorpions are scattered about (%d)" % c._sleepers.size())
	check(c._raiders_left == 0, "and no raiders yet")
	c.player.global_position = Vector3(0.0, 0.0, Cinerea.LAKE_FROM + 0.5)
	await get_physics_frame_twice()
	check(c._busy, "the dark comes down")
	var lines: Array[String] = []
	c.hud.line_done.connect(func() -> void: lines.append(c.hud.last_line))
	var until := Time.get_ticks_msec() + 8000
	while c._busy and Time.get_ticks_msec() < until:
		await get_tree().process_frame
	check(not c._busy, "and he has the road again")
	check(c._raiders_left == 3, "three raiders at the carriage (%d)" % c._raiders_left)
	check(lines.size() == Talks.AT_THE_CARRIAGE.size(), "they say their piece (%s)" % [lines])
	check(not "saffron" in " ".join(lines).to_lower(), "it's her they're after")
	check(c._sleepers.is_empty(), "the desert's foes are gone")
	var awake := 0
	for j in c.get_children():
		if j is Jackal and j.mode != Jackal.Mode.SLEEP:
			awake += 1
	check(awake == 3, "and they turn on him (%d)" % awake)
	check(c.player.input_enabled and c.player.collision_mask != 0, "and it's his fight")
	c.queue_free()
	await get_physics_frame_twice()

# Leaping over the line: the dark waits until he's down, or LakeScene would save the leap's mask of 0 and give it back, and he'd walk through everything.
func test_a_leap_across_the_lake_line_lands_before_the_scene() -> void:
	var c := await _town()
	c.loot()
	while c._busy:
		await get_tree().process_frame
	await get_physics_frame_twice()
	var p := c.player
	var mask := p.collision_mask
	check(mask != 0, "he starts solid")
	p.hurtbox.invulnerable = true
	p.global_position = Vector3(0.0, 0.0, Cinerea.LAKE_FROM - 0.5)
	p.reset_physics_interpolation()
	p._ability = Journey.ABILITIES["Hammer Blow"]
	p._aim_at = Vector3(0.0, 0.0, Cinerea.LAKE_FROM + 3.0)
	p._enter(Elvis.State.ABILITY)
	var crossed := false
	while p.state == Elvis.State.ABILITY:
		crossed = crossed or p.global_position.z > Cinerea.LAKE_FROM
		check(not c._busy, "no scene while he's leaping")
		await get_tree().physics_frame
	check(crossed, "he went over the line in the air")
	await get_physics_frame_twice()
	check(c._busy, "the dark comes down once he's landed")
	var until := Time.get_ticks_msec() + 8000
	while c._busy and Time.get_ticks_msec() < until:
		await get_tree().process_frame
	check(not c._busy, "and he has the road again")
	check(p.collision_mask == mask, "solid again (%d)" % p.collision_mask)
	c.queue_free()
	await get_physics_frame_twice()

func test_his_sword_stays_in_the_same_hand_facing_left() -> void:
	var c := await _town()
	Journey.add_item(&"iron_sword")
	Journey.toggle_equip(&"iron_sword")
	var p := c.player
	for anim: String in ["idle", "run", "sprint"]:
		p.sprite.play(p._look(anim), Vector2.LEFT)
		check(p.sprite.current_key.ends_with("_L"), "%s has its own left-facing sheet (%s)" % [anim, p.sprite.current_key])
		check(not p.sprite._sprite.flip_h, "not a mirror")
	p.sprite.play(p._look("sprint"), Vector2.DOWN)
	check(p.sprite.current_key == "sprint_spear_F", "holding Space is a real run (%s)" % p.sprite.current_key)
	c.queue_free()

func test_he_lands_clear_of_walls_when_he_aims_at_one() -> void:
	var c := await _town()
	var p := c.player
	p.global_position = Vector3(20.0, 0.0, Cinerea.NORTH + 4.0)
	await get_physics_frame_twice()
	var at := p._landing(Vector3(20.0, 0.0, Cinerea.NORTH - 0.5))
	check(at.z > Cinerea.NORTH + 0.3, "aimed into the wall, he comes down short of it (%s)" % at)
	c.queue_free()

func test_the_carriage_door_opens_and_she_walks_out() -> void:
	var c := await _town()
	check(c.cart_door().frame == 0, "it's shut")
	c._raiders_left = 1
	c._raider_down()
	var lifted := false
	var opened := false
	var came_down := false
	var climbed_back := false
	for i in 6000:
		if c._cassia.lift > 0.5 and c._cassia.shown():
			lifted = true
			climbed_back = came_down
		if c.cart_door().frame == c.cart_door().hframes - 1:
			opened = true
		if c._cassia.shown() and c._cassia.lift == 0.0 and opened and c._cassia.sprite.position.y == 0.0:
			came_down = true
		if c.met_cassia:
			break
		if not c.hud._choices.is_empty():
			c.hud.pick(0)
		await get_tree().process_frame
	check(lifted, "she stands in the doorway, up on the sill")
	check(opened, "the door has opened")
	check(came_down and not c._cassia.bobs, "and she's come down, with her feet on the ground, and they stay there")
	check(climbed_back, "and goes back up onto the sill to get in")
	c.queue_free()
	await get_physics_frame_twice()

func test_a_scene_starting_stops_his_aim() -> void:
	var c := await _town()
	var p := c.player
	Journey.add_item(&"iron_sword")
	Journey.toggle_equip(&"iron_sword")
	Journey.remember(&"hammer")
	var stamina := p.stamina.value
	Input.action_press(&"ability_f")
	p._use_ability(&"ability_f")
	check(p.state == Elvis.State.AIM, "he's choosing where")
	p.input_enabled = false
	await get_physics_frame_twice()
	Input.action_release(&"ability_f")
	check(p.state == Elvis.State.MOVE and p.stamina.value >= stamina - 0.01, "a scene starts: he stays put and it costs nothing")
	c.queue_free()
	await get_physics_frame_twice()
