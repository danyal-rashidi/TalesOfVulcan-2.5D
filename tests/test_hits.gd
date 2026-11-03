extends TestCase
# What a swing looks like: slash arcs, damage numbers, the kick and the speed lines, with Elvis driven through Input like a player.

const ELVIS := preload("res://player/elvis.tscn")
const DUMMY := preload("res://combat/dummy.tscn")
const VULCAN := preload("res://boss/vulcan.tscn")
const JACKAL := preload("res://enemy/jackal.tscn")
const LIGHT_GAP := 0.45    # s from one light press to the next that keeps the string going

# Not when the button goes down: only when the hit window opens. And it can't hurt anyone.
func test_arc_waits_for_the_hit_window() -> void:
	var e: Elvis = await _spawn()
	e.facing = Vector2.RIGHT
	await _tap(&"attack_light")
	check(_slashes().is_empty(), "nothing yet on the press")
	var marks := await _marks(0.3)
	check(marks.size() == 1, "one arc as the window opens (%d)" % marks.size())
	check(not marks[0]["stab"], "an arc, not a stab")
	check(not marks[0]["hits"], "it has no hitbox")

func test_no_arc_for_a_refused_swing() -> void:
	var e: Elvis = await _spawn()
	e.facing = Vector2.RIGHT
	e.stamina.regen_per_s = 0.0
	e.stamina.value = 0.0
	check(await _marks_after(&"attack_light") == 0, "no stamina")
	check(await _marks_after(&"attack_heavy") == 0, "no stamina for a heavy")
	e.stamina.refill()
	e.spear_out = false
	check(await _marks_after(&"attack_light") == 0, "the weapon away")
	e.spear_out = true
	e.input_enabled = false
	check(await _marks_after(&"attack_light") == 0, "a scene playing")

# Elvis's string of four: his side light 2 draws its own trail, so three arcs, each light sweeping the other way and the last the big one.
func test_lights_alternate_and_the_fourth_is_big() -> void:
	var e: Elvis = await _spawn()
	e.facing = Vector2.RIGHT
	var ways: Array[int] = []
	var bigs: Array[bool] = []
	for i in e.combo_max:
		await _tap(&"attack_light")
		for m: Dictionary in await _marks(LIGHT_GAP):
			ways.append(m["sweep"])
			bigs.append(m["big"])
	check(ways == [1, 1, -1], "they go by turns (%s)" % [ways])
	check(bigs == [false, false, true], "light 4 is the big one (%s)" % [bigs])

# Vulcan's string is his own two slashes, different sheets in every direction, then round again; the second is the finisher.
func test_vulcan_string_is_two_and_wraps() -> void:
	var e: Elvis = await _vulcan()
	Fx.clear_all()    # the last test's marks
	for way: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
		e.reset_to(Vector3.ZERO)
		e.facing = way
		var seen: Array[String] = []
		var bigs: Array[bool] = []
		for i in 3:
			await _tap(&"attack_light")
			seen.append(e.sprite.current_key)
			for m: Dictionary in await _marks(LIGHT_GAP):
				bigs.append(m["big"])
		var view := CharacterSprite.dir_suffix(way) if way != Vector2.LEFT else "L"
		check(seen[0] == "light1_" + view and seen[2].begins_with("light1") and seen[2].ends_with("_" + view) and seen[1].begins_with("light2_late") and seen[1].ends_with("_" + view), "one, two, one, the second pressed as the first comes back up (%s)" % [seen])
		check(bigs == [false, true, false], "the second is the finisher (%s)" % [bigs])
		check(not (e.sprite.get_node("Sprite3D") as Sprite3D).flip_h, "his own sheet, no mirror (%s)" % view)
		await _wait(0.7)
	check(e.combo_max < Elvis.COMBO_MAX, "shorter than Elvis's")

# The average stays what it was, and the second carries light 4's push.
func test_vulcan_string_numbers() -> void:
	var one: Dictionary = Elvis.VULCAN_ATTACKS["light1"]
	var two: Dictionary = Elvis.VULCAN_ATTACKS["light2"]
	near((one["damage"] + two["damage"]) / 2.0, 10.0, 0.001, "ten a swing")
	check(two["push"] == Elvis.ATTACKS["light4"]["push"], "light 2 pushes as light 4 did")
	check(Elvis.ATTACKS["light2"]["damage"] == 8.0 and Elvis.ATTACKS["light4"]["damage"] == 14.0, "Elvis keeps his table")
	var e: Elvis = await _vulcan()
	e.facing = Vector2.RIGHT
	var d := _dummy(Vector3(1.9, 0, 0))
	await get_tree().physics_frame
	e.global_position = Vector3.ZERO
	var full := d.health.hp
	await _tap(&"attack_light")
	await _wait(0.3)
	near(full - d.health.hp, 8.0, 0.001, "light 1 hits for 8")
	e.global_position = Vector3.ZERO
	d.global_position = Vector3(1.9, 0, 0)
	full = d.health.hp
	await _tap(&"attack_light")
	check(await _lines_within(0.4) == 1, "the finisher gets the speed lines")
	near(full - d.health.hp, 12.0, 0.001, "light 2 hits for 12")
	Fx.clear_all()

# Light 1 cancelled at its low pose goes on from that very picture, and once he's back on his feet the string starts over.
func test_vulcan_flows_from_one_into_two() -> void:
	var e: Elvis = await _vulcan()
	e.facing = Vector2.RIGHT
	await _tap(&"attack_light")
	await _tap(&"attack_light")    # waits in the buffer for the cancel
	var t := 0.0
	while t < 0.5:
		if e.sprite.current_key == "light1_S":
			check(e._t <= Elvis.VULCAN_ATTACKS["light1"]["cancel"] + 0.04, "light 1 gives way at its cancel (%s)" % e._t)
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	check(e.sprite.current_key == "light2_S", "the second press was light 2 (%s)" % e.sprite.current_key)
	await _wait(0.8)
	check(e.state == Elvis.State.MOVE and e.combo_index == 0, "back on his feet the string starts over (%d)" % e.combo_index)
	await _tap(&"attack_light")
	check(e.sprite.current_key == "light1_S", "so the next is light 1 (%s)" % e.sprite.current_key)
	await _wait(0.8)
	await _tap(&"attack_light")
	check(e.sprite.current_key == "light1_S", "even so soon after (%s)" % e.sprite.current_key)
	Fx.clear_all()

# Tap or hold, the same heavy sheet; his hit lands where the lunge's did, the hold only hits harder, and the stance shows only once it's a hold.
func test_vulcan_heavy() -> void:
	var e: Elvis = await _vulcan()
	e.facing = Vector2.RIGHT
	var hit_at := -1.0
	await _tap(&"attack_heavy")
	check(e.sprite.current_key == "idle_spear_S" or e.state == Elvis.State.LUNGE, "a tap shows no stance (%s)" % e.sprite.current_key)
	var t := 0.0
	while t < 0.6:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if hit_at < 0.0 and e.hitbox.is_active():
			hit_at = t
	check(hit_at >= 0.2 and hit_at <= 0.4, "the tap's hit lands about where the lunge's did (%s s)" % hit_at)
	await _wait(0.5)
	var file := func() -> String: return e.sprite._anim.get("file", "")
	Input.action_press(&"attack_heavy")
	await _wait(Elvis.HOLD * 0.5)
	check(e.state == Elvis.State.CHARGE and e.sprite.current_key == "idle_spear_S", "not yet a hold: he stands (%s)" % e.sprite.current_key)
	await _wait(Elvis.HOLD)
	check(e.sprite.current_key == "charge_S" and file.call() == "heavy_S.png", "a hold raises the sword (%s)" % e.sprite.current_key)
	await _wait(0.5)
	check(e.sprite.frame == int(e.sprite._anim["frames"]) - 1, "and holds it overhead (%d)" % e.sprite.frame)
	Input.action_release(&"attack_heavy")
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(e.state == Elvis.State.THRUST and e.sprite.current_key == "thrust_S" and file.call() == "heavy_S.png", "let go, the same chop (%s)" % e.sprite.current_key)
	await _wait(0.8)
	Fx.clear_all()

# His clips step within the sheet with the other foot planted, so he swings where he stands: moving him at all slides that foot, and what he ran in with stops as he plants them.
func test_vulcan_swings_where_he_stands() -> void:
	var e: Elvis = await _vulcan()
	for look: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
		for press: StringName in [&"attack_light", &"attack_heavy"]:
			e.facing = look
			e._vel = look * e.walk_speed
			await _tap(press)
			await get_tree().physics_frame
			var from := e.global_position
			await _wait(0.2)
			if press == &"attack_light":
				await _tap(press)    # on into light 2
			while e.state != Elvis.State.MOVE:
				await get_tree().physics_frame
				check(e.global_position.distance_to(from) < 0.001, "%s %s: %s m at %s" % [look, press, e.global_position.distance_to(from), e.sprite.current_key])
	Fx.clear_all()

# His string wraps: pressed with light 2's sword still high, light 1 starts on its raised frame, not his stand, or the sword goes high, low, high in 3 ticks and his feet pop. Pressed once he's lowered it, it starts from the stand. And its own late press still finds the right frame, though its key has one frame fewer.
func test_vulcan_string_wraps_without_a_snap() -> void:
	var e: Elvis = await _vulcan()
	for look: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
		e.facing = look
		e.stamina.refill()
		await _tap(&"attack_light")
		await _wait(0.2)
		await _tap(&"attack_light")
		await _wait(0.2)    # light 2 opens at light 1's cancel, 0.35 s in
		await _wait(0.36)   # at its own, with the sword up
		await _tap(&"attack_light")
		check(e.sprite.current_key.begins_with("light1_on_") and e.combo_index == 1, "%s: high, it starts raised (%s)" % [look, e.sprite.current_key])
		while e.sprite.frames_left() >= Elvis.VULCAN_LATE:
			await get_tree().physics_frame
		var left := e.sprite.frames_left()
		await _tap(&"attack_light")
		check(e.sprite.current_key.begins_with("light2_late%d_" % (Elvis.VULCAN_LIGHT1_END - left)) or e.sprite.current_key.begins_with("light2_late%d_" % (Elvis.VULCAN_LIGHT1_END - left + 1)), "%s: light 2 late from there (%s, %d left)" % [look, e.sprite.current_key, left])
		while e.sprite.frames_left() > 0:
			await get_tree().physics_frame
		await _tap(&"attack_light")
		check(e.sprite.current_key.begins_with("light1_") and not e.sprite.current_key.begins_with("light1_on"), "%s: lowered, from his stand (%s)" % [look, e.sprite.current_key])
		await _wait(0.8)
	Fx.clear_all()

# Pressed once he's on his way back up from the low pose, light 2 starts on the frame he's on and goes down to it: the picture doesn't jump on the press. Pressed in time, it starts on it.
func test_vulcan_late_press_doesnt_snap() -> void:
	var e: Elvis = await _vulcan()
	for look: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
		e.facing = look
		e.stamina.refill()
		await _tap(&"attack_light")
		while e.sprite.frames_left() >= Elvis.VULCAN_LATE:
			await get_tree().physics_frame
		var was := e.sprite.frame
		await _tap(&"attack_light")
		check(e.sprite.current_key.begins_with("light2_late%d_" % was) or e.sprite.current_key.begins_with("light2_late%d_" % (was + 1)), "%s: late, it starts from the frame he's on, %d (%s)" % [look, was, e.sprite.current_key])
		check(e.state == Elvis.State.LIGHT and e.combo_index == 2, "%s: and it's still his second slash" % look)
		await _wait(0.9)
		await _tap(&"attack_light")
		await _wait(0.2)
		await _tap(&"attack_light")
		await _wait(0.2)
		check(e.sprite.current_key.begins_with("light2_") and not e.sprite.current_key.begins_with("light2_late"), "%s: in time, it starts on it (%s)" % [look, e.sprite.current_key])
		await _wait(0.8)
	Fx.clear_all()

# The mark starts on the frame with the blade on its way, a frame before the hit: its tail on the blade, and the blade at its head as the hit lands.
func test_vulcan_mark_starts_with_the_blade() -> void:
	var e: Elvis = await _vulcan()
	e.facing = Vector2.RIGHT
	await _tap(&"attack_light")
	var a := e.sprite.active_window(e.sprite.current_key).x
	while e.sprite.frame < a - 1:
		await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(_slashes().size() == 1 and not e.hitbox.is_active(), "out a frame before the hit (%d marks, frame %d)" % [_slashes().size(), e.sprite.frame])
	await _wait(0.6)
	Fx.clear_all()

# (metres, peak m/s) he moves in the next second.
# The mark lies on the sheet it follows, in hard pixels, one drawing for each attack.
func test_vulcan_marks_follow_their_blades() -> void:
	var e: Elvis = await _vulcan()
	e.facing = Vector2.RIGHT
	await _tap(&"attack_light")
	var drawn: Array[Image] = []
	await _wait(0.25)
	var marks := _slashes()
	check(marks.size() == 1 and marks[0]._on == e.sprite, "it lies on his sheet (%d)" % marks.size())
	marks[0]._process(0.0)
	near((marks[0]._spr.global_position - e.sprite.drawn_at()).x, 0.0, 0.001, "right over it")
	var arcs := {}
	for key: String in ["light1_S", "light2_S", "lunge_S"]:
		arcs[e.sprite._manifest("vulcan_human")["anims"][key]["arc"]] = true
		for frame in FxSlash.SPANS.size():
			drawn.append(FxSlash.cut_image(Vector2i(104, 64), e.sprite._manifest("vulcan_human")["anims"][key]["arc"], FxSlash.CUT, FxSlash.STEEL, frame))
	check(arcs.size() == 3, "each attack has its own way")
	for img: Image in drawn:
		var used := 0
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a > 0.0:
					used += 1
					check(c.a == 1.0 and c in FxSlash.STEEL, "hard pixels in the weapon's own colours (%s)" % c)
		check(used > 20, "it draws something (%d)" % used)
	Fx.clear_all()

func test_lunge_and_thrust_stab() -> void:
	var e: Elvis = await _spawn()
	e.facing = Vector2.RIGHT
	await _tap(&"attack_heavy")
	var marks := await _marks(0.7)
	check(e.state == Elvis.State.MOVE or e.state == Elvis.State.LUNGE, "it was the lunge (state %s)" % e.state)
	check(marks.size() == 1 and marks[0]["stab"], "the lunge is a stab (%s)" % [marks])
	await _wait(0.5)
	Input.action_press(&"attack_heavy")
	await _wait(Elvis.HOLD + 0.2)
	Input.action_release(&"attack_heavy")
	await get_tree().physics_frame
	marks = await _marks(0.5)
	check(marks.size() == 1 and marks[0]["stab"], "the thrust is a stab (%s)" % [marks])

# Toward the camera the stab's tip goes past where its billboard meets the floor, so nothing may cut it. Going away it still falls behind him, and an arc still sorts against him.
func test_only_a_stab_toward_the_camera_ignores_depth() -> void:
	for way: Array in [[Vector2.DOWN, true, true], [Vector2(0.7, 0.7), true, true], [Vector2.UP, true, false], [Vector2.RIGHT, true, false], [Vector2.DOWN, false, false]]:
		var mark := Fx.spawn(&"slash", Vector3.ZERO) as FxSlash
		mark.swing(null, way[0], 1, false, way[1], FxSlash.ICE)
		check(mark._spr.no_depth_test == way[2], "facing %s, stab %s" % [way[0], way[1]])
	check(FxSlash.STAB.y * FxSlash.FLOOR_PX > FxSlash.CHEST * Pixel.sprite_scale_y() * Pixel.PX, "the stab does reach past the floor: if it no longer does, this can go")
	Fx.clear_all()

# A sheet that draws its own crescent gets no second one over it: Elvis's front light 2. Only light 4's bigger arc goes round its own.
func test_a_drawn_trail_is_not_doubled() -> void:
	var e: Elvis = await _spawn()
	Fx.clear_all()    # the last test's marks
	e.facing = Vector2.DOWN
	var seen: Array[int] = []
	var trails: Array[bool] = []
	for i in e.combo_max:
		await _tap(&"attack_light")
		seen.append((await _marks(LIGHT_GAP)).size())
		trails.append(e.sprite.draws_trail())
	check(trails == [false, true, false, false], "his front light 2 draws one (%s)" % [trails])
	check(seen == [1, 0, 1, 1], "and no mark over it (%s)" % [seen])

# Hard pixels: no ramps of alpha, only the weapon's own few colours, and even sizes so it lands on the grid.
func test_arc_images_are_hard_pixels() -> void:
	for colors: Array[Color] in [FxSlash.ICE, FxSlash.STEEL]:
		for straight: bool in [false, true]:
			for frame in FxSlash.SPANS.size():
				var img := FxSlash.image(0.7, -1, false, straight, colors, frame)
				check(img.get_width() % 2 == 0 and img.get_height() % 2 == 0, "even size (%s)" % img.get_size())
				var used := 0
				for y in img.get_height():
					for x in img.get_width():
						var c := img.get_pixel(x, y)
						if c.a > 0.0:
							used += 1
							check(c.a == 1.0 and colors.any(func(p: Color) -> bool: return p.is_equal_approx(c)), "one of its colours (%s)" % c)
				check(used > 0, "frame %d draws something" % frame)

# Spawned often: the same shape keeps its pictures.
func test_arc_pictures_are_cached() -> void:
	var a := Fx.spawn(&"slash", Vector3.ZERO) as FxSlash
	var b := Fx.spawn(&"slash", Vector3.ZERO) as FxSlash
	a.swing(null, Vector2.LEFT, 1, false, false, FxSlash.ICE)
	b.swing(null, Vector2.LEFT, 1, false, false, FxSlash.ICE)
	check(a._frames[0] == b._frames[0], "one set of textures")
	Fx.clear_all()

func test_number_for_real_damage() -> void:
	var e: Elvis = await _spawn()
	var d := _dummy(Vector3(1.4, 0, 0))
	e.facing = Vector2.RIGHT
	await get_tree().physics_frame
	await _tap(&"attack_light")
	await _wait(0.3)
	var numbers := _numbers()
	check(numbers.size() == 1 and numbers[0].text == "8", "a whole 8 over him (%s)" % [numbers.map(func(n: FxNumber) -> String: return n.text)])
	check(_label(numbers[0]).font == Hud.pixel_font(), "in the pixel font")
	check(_label(numbers[0]).modulate == Hud.PARCHMENT, "parchment on a light blow")
	check(numbers[0].global_position.y > d.global_position.y + 2.0, "over his head")
	Fx.clear_all()
	check(Fx.count() == 0, "clear_all takes it with the rest")

func test_no_number_when_nothing_was_lost() -> void:
	var e: Elvis = await _spawn()
	var d := _dummy(Vector3(1.4, 0, 0))
	d.hurtbox.invulnerable = true
	e.facing = Vector2.RIGHT
	await get_tree().physics_frame
	await _tap(&"attack_light")
	await _wait(0.3)
	check(_numbers().is_empty(), "invulnerable")
	check(d.health.hp == d.health.max_hp, "and unhurt (%s)" % d.health.hp)
	d.take_hit(_blow(0.0, false))
	check(_numbers().is_empty(), "zero damage")
	d.health.take(d.health.max_hp)
	d.take_hit(_blow(5.0, false))
	check(_numbers().is_empty(), "already dead")
	Fx.clear_all()

func test_heavy_is_gold_and_larger_and_his_own_is_red() -> void:
	var d := _dummy(Vector3.ZERO)
	await get_tree().physics_frame
	d.take_hit(_blow(4.0, false))
	d.take_hit(_blow(30.0, true))
	var numbers := _numbers()
	check(_label(numbers[1]).modulate == FxNumber.GOLD, "gold")
	check(_label(numbers[1]).font_size == _label(numbers[0]).font_size * 2, "and twice the size, the only larger size that stays crisp")
	var e: Elvis = await _spawn()
	e.take_hit(_blow(7.0, false))
	check(_label(_numbers()[2]).modulate == FxNumber.HURT, "his own hurt is red")
	Fx.clear_all()

func test_boss_shows_numbers_only_when_hurt() -> void:
	var v := VULCAN.instantiate() as Vulcan
	add_child(v)
	await get_tree().physics_frame
	v.take_hit(_blow(9.0, false))
	check(_numbers().is_empty(), "the stone statue takes nothing")
	v.reset_fight(Vector3.ZERO)
	v.take_hit(_blow(9.0, false))
	check(_numbers().size() == 1, "awake he does")
	v.health.take(v.health.max_hp)
	Fx.clear_all()
	v.take_hit(_blow(9.0, false))
	check(_numbers().is_empty(), "kneeling he takes no more")
	Fx.clear_all()

# Quick hits on one spot, and a striker standing right there: no two numbers ever share a pixel, however they rise, and none sits on him.
func test_numbers_do_not_stack() -> void:
	var d := _dummy(Vector3.ZERO)
	var striker := _dummy(Vector3(0.0, 0.0, -1.5))
	await get_tree().physics_frame
	for i in 5:
		var blow := _blow(8.0, i == 2)
		blow.source = striker
		d.take_hit(blow)
	var numbers := _numbers()
	check(numbers.size() == 5, "five numbers (%d)" % numbers.size())
	var body := Rect2(FxNumber._on_screen(striker.global_position) - Vector2(FxNumber.BODY.x / 2.0, FxNumber.BODY.y), FxNumber.BODY)
	for i in numbers.size():
		check(not numbers[i].lane.intersects(body), "number %d is off the striker (%s, %s)" % [i, numbers[i].lane, body])
		for j in i:
			check(not numbers[i].lane.intersects(numbers[j].lane), "numbers %d and %d apart (%s, %s)" % [j, i, numbers[j].lane, numbers[i].lane])
	Fx.clear_all()

# Whoever struck may be gone by now: it still rises over whoever took it.
func test_number_for_a_blow_whose_striker_has_gone() -> void:
	var d := _dummy(Vector3(3.0, 0.0, 0.0))
	await get_tree().physics_frame
	var blow := _blow(8.0, false)
	var gone := Node3D.new()
	blow.source = gone
	gone.free()
	d.take_hit(blow)
	var numbers := _numbers()
	check(numbers.size() == 1 and absf(numbers[0].global_position.x - 3.0) < 0.5, "over him, not at the origin")
	Fx.clear_all()

# The HUD draws a foe's bar over all of the 3D, so a Hammer Blow's slide north mustn't carry it up across the number, for the number's whole life.
func test_number_stays_clear_of_the_bar_of_a_foe_slid_north() -> void:
	var foe := await _foe_struck(Vector3(0.0, 0.0, 1.5))
	var n := _numbers()[0] as FxNumber
	var start := foe.global_position.z
	while is_instance_valid(n) and not n.is_queued_for_deletion():
		var bar := FxNumber._on_screen(foe.global_position + Vector3.UP * foe.bar_up).y - 1.0    # the top of its dark edge
		var foot := FxNumber._on_screen(n.global_position).y
		check(foot <= bar, "the number's foot %s stays over the bar %s" % [foot, bar])
		await get_tree().physics_frame
	near(foe.global_position.z - start, -1.225, 0.1, "it really slid north")

# A push any other way carries the bar off on its own, and a killing blow leaves no bar: the number stays where it always rose.
func test_number_keeps_its_place_for_other_pushes_and_kills() -> void:
	for from: Vector3 in [Vector3(0.0, 0.0, -1.5), Vector3(1.5, 0.0, 0.0), Vector3(-1.5, 0.0, 0.0)]:
		var foe := await _foe_struck(from)
		near(_numbers()[0].global_position.z, foe.global_position.z, 0.05, "pushed from %s" % from)
		foe.queue_free()
		Fx.clear_all()
	var kill := await _foe_struck(Vector3(0.0, 0.0, 1.5), 500.0)
	near(_numbers()[0].global_position.z, kill.global_position.z, 0.05, "a kill")
	Fx.clear_all()

# It really moves, and only in whole pixels.
func test_number_rises_in_whole_pixels() -> void:
	var n := Fx.spawn(&"number", Vector3(0.0, 2.0, 0.0)) as FxNumber
	var px := Pixel.PX / Pixel.sprite_scale_y()
	for i in 20:
		await get_tree().physics_frame
		var y := n.global_position.y * px
		near(y, roundf(y), 0.001, "on the pixel grid at tick %d" % i)
	check(n.global_position.y > 2.0 + float(FxNumber.POP_PX) / px - 0.05, "it popped up (%s)" % n.global_position.y)
	Fx.clear_all()

func test_speed_lines_only_when_a_finisher_lands() -> void:
	var e: Elvis = await _spawn()
	e.facing = Vector2.RIGHT
	await _tap(&"attack_heavy")
	check(await _lines_within(0.7) == 0, "a lunge at nothing")
	var d := _dummy(Vector3(1.9, 0, 0))
	await get_tree().physics_frame
	e.global_position = Vector3.ZERO
	await _tap(&"attack_light")
	check(await _lines_within(0.3) == 0, "light 1 on him")
	await _wait(0.3)
	e.global_position = Vector3.ZERO
	d.global_position = Vector3(1.9, 0, 0)
	await _tap(&"attack_heavy")
	check(await _lines_within(0.7) == 1, "the lunge landing")
	Fx.clear_all()

func test_speed_lines_on_light_four_and_the_thrust() -> void:
	var e: Elvis = await _spawn()
	e.facing = Vector2.RIGHT
	var d := _dummy(Vector3(1.9, 0, 0))
	await get_tree().physics_frame
	e.global_position = Vector3.ZERO
	e.combo_index = Elvis.COMBO_MAX - 1
	e._last_light = e._clock    # as if he'd just swung light 3
	await _tap(&"attack_light")
	check(e.combo_index == Elvis.COMBO_MAX, "it's light 4 (%d)" % e.combo_index)
	check(await _lines_within(0.5) == 1, "light 4 landing")
	await _wait(0.5)
	e.global_position = Vector3.ZERO
	d.global_position = Vector3(1.9, 0, 0)
	Input.action_press(&"attack_heavy")
	await _wait(Elvis.HOLD + 0.2)
	Input.action_release(&"attack_heavy")
	check(await _lines_within(0.5) == 1, "the charged thrust landing")
	Fx.clear_all()

# One burst for one blow, however many it catches.
func test_two_targets_get_one_burst() -> void:
	var e: Elvis = await _spawn()
	e.facing = Vector2.RIGHT
	_dummy(Vector3(1.9, 0, 0.2))
	_dummy(Vector3(1.9, 0, -0.2))
	await get_tree().physics_frame
	e.global_position = Vector3.ZERO
	await _tap(&"attack_heavy")
	check(await _lines_within(0.7) == 1, "one burst")
	Fx.clear_all()

func test_speed_lines_on_the_hammer_only_when_it_lands() -> void:
	var e: Elvis = await _spawn()
	e._ability = Journey.ABILITIES["Hammer Blow"]
	e._aim_at = Vector3(3.0, 0, 0)
	e._enter(Elvis.State.ABILITY)
	check(await _lines_within(1.0) == 0, "coming down on nothing")
	_dummy(Vector3(6.0, 0, 0))
	await get_tree().physics_frame
	e._aim_at = Vector3(6.0, 0, 0)
	e._enter(Elvis.State.ABILITY)
	check(await _lines_within(1.0) == 1, "coming down on him")
	Fx.clear_all()

# They run on real seconds: through a hit-stop and a pause, then they're gone with nothing left behind.
func test_speed_lines_clean_up_by_themselves() -> void:
	Engine.time_scale = Feel.STOP_SCALE
	Fx.spawn(&"speed_lines", Vector3.ZERO)
	check(_lines().size() == 1, "there in a hit-stop")
	await get_tree().create_timer(0.2, true, false, true).timeout
	check(_lines().is_empty(), "and gone in 0.2 real seconds, through it")
	Engine.time_scale = 1.0
	Fx.spawn(&"speed_lines", Vector3.ZERO)
	get_tree().paused = true
	await get_tree().create_timer(0.2, true, false, true).timeout
	get_tree().paused = false
	check(_lines().is_empty(), "gone through a pause too")

# His light hit is felt past the hit-stop, a kill harder, and nothing normal goes over 2 px.
func test_kick() -> void:
	var cam := PixelCamera.new()
	add_child(cam)
	cam.make_current()
	var e: Elvis = await _spawn()
	e.facing = Vector2.RIGHT
	var d := _dummy(Vector3(1.4, 0, 0))
	await get_tree().physics_frame
	var hit: Array[int] = [0, 0]
	e.hitbox.landed.connect(func(_h: Hurtbox, _i: HitInfo) -> void:
		hit[0] = cam._shake_px
		hit[1] = cam._shake_until - Time.get_ticks_msec())
	await _tap(&"attack_light")
	await _wait(0.25)
	check(hit[0] == 1, "a light hit kicks 1 px (%d)" % hit[0])
	check(hit[1] > 70 + 50, "and runs on well past the 0.07 s hit-stop (%d ms)" % hit[1])
	await _wait(0.5)
	e.global_position = Vector3.ZERO
	d.global_position = Vector3(1.4, 0, 0)
	d.health.hp = 1.0
	await _tap(&"attack_light")
	await _wait(0.25)
	check(hit[0] == 2, "a kill kicks 2 px (%d)" % hit[0])
	Fx.clear_all()

func _slashes() -> Array:
	return Fx.get_children().filter(func(c: Node) -> bool: return c is FxSlash and not c.is_queued_for_deletion())

func _numbers() -> Array:
	return Fx.get_children().filter(func(c: Node) -> bool: return c is FxNumber and not c.is_queued_for_deletion())

func _lines() -> Array:
	return Fx.get_children().filter(func(c: Node) -> bool: return c.get_script() == Fx.KINDS[&"speed_lines"] and not c.is_queued_for_deletion())

func _label(n: FxNumber) -> Label3D:
	return n.get_child(0) as Label3D

# What every swing's mark that shows in the next `seconds` looks like. A mark is watched by its id, as it may be gone by the next tick.
func _marks(seconds: float) -> Array[Dictionary]:
	var seen := {}
	await _each_tick(seconds, func() -> void:
		for s: FxSlash in _slashes():
			seen[s.get_instance_id()] = {"sweep": s.sweep, "big": s.big, "stab": s.stab, "hits": s.hitbox != null})
	var out: Array[Dictionary] = []
	out.assign(seen.values())
	return out

func _marks_after(press: StringName) -> int:
	await _tap(press)
	return (await _marks(0.6)).size()

func _lines_within(seconds: float) -> int:
	var seen := {}
	await _each_tick(seconds, func() -> void:
		for l: Node in _lines():
			seen[l.get_instance_id()] = true)
	return seen.size()

func _each_tick(seconds: float, what: Callable) -> void:
	what.call()
	var until := Time.get_ticks_msec() + roundi(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
		what.call()

func _blow(damage: float, heavy: bool) -> HitInfo:
	var info := HitInfo.new()
	info.damage = damage
	info.heavy = heavy
	return info

# A real foe taking a Hammer Blow's push from `from`, and standing to take all of it.
func _foe_struck(from: Vector3, damage := 8.0) -> Jackal:
	var foe := JACKAL.instantiate() as Jackal
	add_child(foe)
	foe.scripted = true
	await get_tree().physics_frame
	var blow := _blow(damage, true)
	blow.knockback = 7.0 * 7.0 / (2.0 * Actor.KNOCK_DECEL)
	blow.at = from
	foe.take_hit(blow)
	return foe

func _dummy(at: Vector3) -> Actor:
	var d := DUMMY.instantiate() as Actor
	d.position = at
	add_child(d)
	return d

# As game/cinerea.gd sets him up.
func _vulcan() -> Elvis:
	var e: Elvis = await _spawn("vulcan_human")
	e.combo_max = 2
	return e

func _spawn(character := "elvis_blue") -> Elvis:
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 1, 60)
	shape.shape = box
	ground.add_child(shape)
	ground.position.y = -0.5
	add_child(ground)
	var e := ELVIS.instantiate() as Elvis
	e.character = character
	add_child(e)
	await get_tree().physics_frame
	return e

func _tap(action: StringName) -> void:
	Input.action_press(action)
	await get_tree().physics_frame
	Input.action_release(action)
	await get_tree().physics_frame

func _wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds - 0.001:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()

func _exit_tree() -> void:
	Input.action_release(&"attack_light")
	Input.action_release(&"attack_heavy")
