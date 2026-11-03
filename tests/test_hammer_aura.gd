extends TestCase
# Hammer Blow's giant hammer: it forms from his hand as he leaps, strikes in front of him as he lands and goes when the leap does. Fire and the harder hit only once upgraded.

const ELVIS := preload("res://player/elvis.tscn")
const DUMMY := preload("res://combat/dummy.tscn")

func test_it_appears_rises_with_him_and_strikes_as_he_lands() -> void:
	var e := await _leap(Vector3(5.0, 0.0, 2.0))
	var a := e._aura
	check(_auras() == [a], "one hammer, the moment he leaps (%d)" % _auras().size())
	check(a._spr.modulate.a > 0.0 and a._spr.frame == 0, "showing, wound back (frame %d)" % a._spr.frame)
	var low := a._spr.global_position.y
	var high := low
	var angle := 0
	for i in 600:
		await get_tree().physics_frame
		if e._landed:
			break
		check(not a._struck, "it doesn't strike before he lands")
		high = maxf(high, a._spr.global_position.y)
		check(a._spr.frame >= angle, "it only ever turns downward (%d after %d)" % [a._spr.frame, angle])
		angle = a._spr.frame
	check(high > low + 0.5, "it rises with him (%s to %s)" % [low, high])
	check(a._struck, "it strikes in the same physics step he lands")
	var blow := _blows()[0] as FxEffect
	near(blow.global_position.x, 5.0, 0.05, "the blow is where he aimed, x")
	near(blow.global_position.z, 2.0, 0.05, "the blow is where he aimed, z")
	check(Vector2(e.global_position.x - 5.0, e.global_position.z - 2.0).length() > 2.8, "and he's outside it (%s)" % e.global_position)
	check(a._spr.global_position.is_equal_approx(_in_hand(e, a)), "still in his hand")
	check(a._spr.frame % FxHammerAura.ANGLES == FxHammerAura.ANGLES - 1, "all the way down (%d)" % a._spr.frame)
	Fx.clear_all()

func test_it_is_gone_when_the_leap_ends() -> void:
	var e := await _leap(Vector3(3.0, 0.0, 0.0))
	var a := e._aura
	for i in 600:
		await get_tree().physics_frame
		if e.state != Elvis.State.ABILITY:
			break
	check(e.state == Elvis.State.MOVE, "he's back on his feet")
	await _wait(FxHammerAura.LINGER)
	check(_gone(a) and _auras().is_empty(), "it lingers a moment and that's all")
	Fx.clear_all()

# Aimed right beside him he jumps back to swing, and still really jumps.
func test_an_aim_beside_him_is_still_struck_there() -> void:
	var e := await _leap(Vector3(0.3, 0.0, 0.0))
	var a := e._aura
	var high := 0.0
	for i in 600:
		await get_tree().physics_frame
		if e._landed:
			break
		high = maxf(high, e.sprite.position.y)
	check(high > Elvis.LEAP_HIGH * 0.9, "up off the ground (%s)" % high)
	check(a._struck and e._head_at.distance_to(Vector3(0.3, 0.0, 0.0)) < 0.05, "it comes down there (%s)" % e._head_at)
	check(_blows()[0].global_position.is_equal_approx(e._head_at), "and so does the blow")
	Fx.clear_all()

# Frame by frame, from the first to the strike, its grip is in his fist on his own pixels, for both swords and both ways.
func test_it_stays_in_his_hand_all_through_the_leap() -> void:
	for look: String in ["vulcan_human", "vulcan_new_sword"]:
		for to: Vector3 in [Vector3(6.0, 0.0, 1.0), Vector3(-6.0, 0.0, 1.0)]:
			var e := await _leap(to, false, look)
			var a := e._aura
			var column := 0
			for i in 600:
				await get_tree().process_frame
				if e.state != Elvis.State.ABILITY or _gone(a):
					break
				check(a._spr.global_position.is_equal_approx(_in_hand(e, a)), "%s frame %d: at %s, his hand at %s" % [look, e.sprite.frame, a._spr.global_position, _in_hand(e, a)])
				check(mini(e.sprite.frame, FxHammerAura.ANGLES - 1) - a._spr.frame % FxHammerAura.ANGLES <= 1, "%s: on his frame %d (%d), or a physics step behind as this reads it before its _process" % [look, e.sprite.frame, a._spr.frame])
				column = maxi(column, a._spr.frame % FxHammerAura.ANGLES)
			check(column == FxHammerAura.ANGLES - 1, "%s: all the way to the strike (%d)" % [look, column])
			Fx.clear_all()
			e.queue_free()
			await get_tree().physics_frame
	Journey.reset()

# The hammer points where the sword points in every frame of both sheets, and starts in his fist, not past the sword.
func test_it_grows_along_the_sword() -> void:
	var hammer := Image.load_from_file(FxHammerAura.GOLD)
	var cell := hammer.get_width() / FxHammerAura.ANGLES
	for folder: String in ["vulcan_human", "vulcan_new_sword"]:
		var him := Image.load_from_file("res://art/%s/hammer_blow_S.png" % folder)
		var was := 0
		for f in FxHammerAura.ANGLES:
			var hand: Vector2i = FxHammerAura.HANDS[f] + Vector2i(48, 31)
			var tip := Vector2(hand)    # the steel furthest from his fist, in a blade's reach: his sandals' grey is further
			for y in 62:
				for x in 96:
					var c := him.get_pixel(f * 96 + x, y)
					if c.a > 0.0 and c.b >= c.r - 0.03 and c.r + c.g + c.b > 1.1 and Vector2(x, y).distance_to(hand) > tip.distance_to(hand) and Vector2(x, y).distance_to(hand) < 30.0:
						tip = Vector2(x, y)
			var way := (tip - Vector2(hand)).normalized()
			var shape := hammer.get_region(Rect2i(f * cell, cell, cell, cell))
			var along := Vector2.ZERO
			var size := 0
			for y in cell:
				for x in cell:
					if shape.get_pixel(x, y).a > 0.0:
						along += Vector2(x - cell / 2, y - cell / 2)
						size += 1
			check(absf(rad_to_deg(way.angle_to(along.normalized()))) < 20.0, "%s frame %d: sword to %s, hammer to %s" % [folder, f, way, along.normalized()])
			check(shape.get_pixel(cell / 2, cell / 2).a > 0.0, "%s frame %d: it starts in his fist" % [folder, f])
			check(size >= was, "%s frame %d: it only grows (%d after %d)" % [folder, f, size, was])
			was = size
		check(float(was) > 6500.0, "%s: whole at the strike (%d px)" % [folder, was])

# HIT is where the sheet really touches: the strike column's lowest rows, from where his fist is.
func test_the_head_meets_the_floor_where_the_blow_is() -> void:
	var img := Image.load_from_file(FxHammerAura.GOLD)
	var cell := img.get_width() / FxHammerAura.ANGLES
	var shape := img.get_region(Rect2i((FxHammerAura.ANGLES - 1) * cell, cell, cell, cell))
	var used := shape.get_used_rect()
	var bottom := used.end.y - 1
	var row := bottom - 3    # just above the corner
	var left := cell
	var right := 0
	for x in cell:
		if shape.get_pixel(x, row).a > 0.0:
			left = mini(left, x)
			right = maxi(right, x)
	var hand: Vector2i = FxHammerAura.HANDS[FxHammerAura.ANGLES - 1]
	near(FxHammerAura.HIT.y, hand.y - 31 + bottom - cell / 2, 4.0, "the face's height on screen")
	check(FxHammerAura.HIT.x > hand.x + left - cell / 2 and FxHammerAura.HIT.x < hand.x + right - cell / 2 + 30, "on the face (%s, %d to %d)" % [FxHammerAura.HIT.x, hand.x + left - cell / 2, hand.x + right - cell / 2])

# It pushes away from the impact: someone between him and the head goes back toward him.
func test_it_pushes_away_from_where_it_hit() -> void:
	var e := await _leap(Vector3(5.0, 0.0, 0.0))
	var d := DUMMY.instantiate() as Actor
	var feet := FxHammerAura.feet_for(Vector3(5.0, 0.0, 0.0), 1.0)
	d.position = Vector3(5.0 - 1.5, 0.0, feet.z)
	add_child(d)
	for i in 600:
		await get_tree().physics_frame
		if e._landed:
			break
	await _wait(0.05)
	check(d._push.x < 0.0, "back from the head, toward him (%s)" % d._push)
	Fx.clear_all()
	e.queue_free()
	d.queue_free()
	await get_tree().physics_frame

# 30 s, kept by skill and shown in whole seconds; refused until it's done, and whatever else he has on the other key isn't held up.
func test_it_cools_for_thirty_seconds() -> void:
	Journey.reset()
	check(float(Journey.ABILITIES["Hammer Blow"]["cooldown"]) == 30.0, "30 s")
	var e := await _leap(Vector3(3.0, 0.0, 0.0))
	Journey.ability_slots[&"ability_f"] = "Hammer Blow"
	e._ready_at["Hammer Blow"] = e._clock + 30.0
	check(e.ability_wait(&"ability_f") == 1.0 and ceili(e.ability_left(&"ability_f")) == 30, "just used (%s)" % e.ability_left(&"ability_f"))
	check(e.ability_wait(&"ability_q") == 0.0 and e.ability_left(&"ability_q") == 0.0, "nothing on the other key")
	for i in 600:
		await get_tree().physics_frame
		if e.state != Elvis.State.ABILITY:
			break
	e._clock += 12.5 - (30.0 - e.ability_left(&"ability_f"))
	near(e.ability_left(&"ability_f"), 17.5, 0.02, "counting down")
	check(ceili(e.ability_left(&"ability_f")) == 18, "18 on its icon")
	e._use_ability(&"ability_f")
	check(e.state == Elvis.State.MOVE, "it won't go while it cools")
	Journey.ability_slots[&"ability_f"] = ""
	Journey.ability_slots[&"ability_q"] = "Hammer Blow"
	check(e.ability_left(&"ability_q") > 17.0, "moving it to the other key doesn't cool it")
	e._use_ability(&"ability_q")
	check(e.state == Elvis.State.MOVE, "nor let it go")
	e._clock += 18.0
	check(e.ability_left(&"ability_q") == 0.0 and e.ability_wait(&"ability_q") == 0.0, "ready again")
	e._use_ability(&"ability_q")
	check(e.state == Elvis.State.AIM, "and it goes")
	e._enter(Elvis.State.MOVE)
	e._ready_at["Hammer Blow"] = e._clock + 30.0
	e.reset_to(Vector3.ZERO)
	check(e.ability_left(&"ability_q") == 0.0, "a restart starts it ready")
	Fx.clear_all()
	e.queue_free()
	Journey.reset()
	await get_tree().physics_frame

func test_it_mirrors_when_he_leaps_left() -> void:
	var right := await _leap(Vector3(4.0, 0.0, 0.0))
	check(not right._aura._spr.flip_h, "to the right, as drawn")
	Fx.clear_all()
	right.queue_free()
	var e := await _leap(Vector3(-4.0, 0.0, 0.0))
	var a := e._aura
	check(a._spr.flip_h, "to the left, mirrored")
	for i in 600:
		await get_tree().physics_frame
		if e._landed:
			break
	check(a._spr.global_position.is_equal_approx(_in_hand(e, a)), "in his hand on the other side")
	check(e._head_at.x < e.global_position.x, "and the head is in front of him, on the left")
	near(e._head_at.x, -4.0, 0.05, "where he aimed")
	Fx.clear_all()

# He's killed in the air, or a scene takes him, or the scene he was in goes: nothing is left hanging, and whatever still lands does so without an error.
func test_it_goes_if_the_leap_is_cut_off() -> void:
	var e := await _leap(Vector3(5.0, 0.0, 0.0))
	await _wait(0.2)
	var a := e._aura
	e.health.take(1000000.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(e.state == Elvis.State.DEAD and _gone(a), "killed in the air")
	e.queue_free()

	e = await _leap(Vector3(5.0, 0.0, 0.0))
	await _wait(0.2)
	a = e._aura
	e.input_enabled = false
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(_gone(a), "a scene takes the controls")
	for i in 600:
		await get_tree().physics_frame
		if e._landed:
			break
	check(e._landed, "he still comes down")
	e.input_enabled = true
	e.queue_free()

	e = await _leap(Vector3(5.0, 0.0, 0.0))
	await _wait(0.2)
	a = e._aura
	e.scripted = true
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(_gone(a), "a scene takes him over")
	e.queue_free()

	e = await _leap(Vector3(5.0, 0.0, 0.0))
	await _wait(0.2)
	a = e._aura
	e.reset_to(Vector3.ZERO)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(_gone(a), "he's put back on his feet")
	e.queue_free()

	e = await _leap(Vector3(5.0, 0.0, 0.0))
	await _wait(0.2)
	a = e._aura
	e.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(_gone(a), "the scene he was in has gone")

	e = await _leap(Vector3(5.0, 0.0, 0.0))
	await _wait(0.2)
	a = e._aura
	Fx.clear_all()
	check(_gone(a), "clear_all takes it too")
	e.queue_free()

	var bare := Fx.spawn(&"hammer_aura", Vector3.ZERO)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(_gone(bare), "with nobody to follow it just goes")

# The blow that drops the last raider starts her scene at once. He's landed: nothing was cut off, so the hammer still lingers and fades.
func test_a_scene_starting_after_the_strike_leaves_it_to_fade() -> void:
	var e := await _leap(Vector3(3.0, 0.0, 0.0))
	var a := e._aura
	for i in 600:
		await get_tree().physics_frame
		if e._landed:
			break
	e.input_enabled = false
	e.scripted = true
	await _wait(FxHammerAura.LINGER / 2.0)
	check(not _gone(a), "still there, fading")
	await _wait(FxHammerAura.LINGER)
	check(_gone(a), "and it does go")
	e.queue_free()

# Never crop through art: at the default zoom, with the camera on his feet, not a pixel of any flame leaves the top of the screen on the longest leap.
func test_its_flames_stay_on_screen_all_through_the_longest_leap() -> void:
	var e := await _leap(Vector3(8.0, 0.0, 0.0), true)
	var a := e._aura
	var sheet := a._spr.texture.get_image()
	var cell := sheet.get_width() / FxHammerAura.ANGLES
	for i in 600:
		await get_tree().physics_frame
		if e._landed:
			break
		for row in a._spr.vframes - 1:
			var top := sheet.get_region(Rect2i(a._spr.frame % FxHammerAura.ANGLES * cell, row * cell, cell, cell)).get_used_rect().position.y
			var above := (a._spr.global_position.y - e.global_position.y) * Pixel.PX / Pixel.sprite_scale_y() + cell / 2.0 - top
			check(above <= PixelCamera.VIEW.y / 2.0, "%.0f px above his feet at angle %d" % [above, a._spr.frame % FxHammerAura.ANGLES])
	Fx.clear_all()
	e.queue_free()
	Journey.reset()

# It's see-through, so a number under it would be lost: the number and its dark edge draw over it.
func test_a_damage_number_draws_over_it() -> void:
	var e := await _leap(Vector3(3.0, 0.0, 0.0))
	var number := Fx.spawn(&"number", Vector3.ZERO)
	var label: Label3D = number.get_children().filter(func(n: Node) -> bool: return n is Label3D)[0]
	var hammer: int = e._aura._spr.material_override.render_priority
	check(hammer < mini(label.render_priority, label.outline_render_priority), "hammer %d, number %d, its edge %d" % [hammer, label.render_priority, label.outline_render_priority])
	Fx.clear_all()
	e.queue_free()

func test_fire_and_the_harder_hit_only_when_upgraded() -> void:
	check(await _damage_of_a_blow(false) == [40.0, false], "plain: gold, 40, no fire")
	check(await _damage_of_a_blow(true) == [55.0, true], "upgraded: burning, 55, a fiery ring and embers")
	Journey.hammer_upgraded = true
	Journey.reset()
	check(not Journey.hammer_upgraded, "reset() takes it back")

# Never crop through art: a look's every cell has clear edges, and the flames flicker.
func test_its_sheets_are_never_cut() -> void:
	var rows := {FxHammerAura.GOLD: 2, FxHammerAura.BURNING: 4}
	for path: String in rows:
		var img := Image.load_from_file(path)
		var cell := img.get_width() / FxHammerAura.ANGLES
		check(cell % 2 == 0, "%s: an even cell, or its texels leave the screen's pixels (%d)" % [path, cell])
		check(img.get_width() == cell * FxHammerAura.ANGLES and img.get_height() == cell * rows[path], "%s: whole cells (%s)" % [path, img.get_size()])
		for y in rows[path]:
			for x in FxHammerAura.ANGLES:
				var c := img.get_region(Rect2i(x * cell, y * cell, cell, cell))
				var touching := false
				for i in cell:
					touching = touching or c.get_pixel(i, 0).a > 0.0 or c.get_pixel(i, cell - 1).a > 0.0 or c.get_pixel(0, i).a > 0.0 or c.get_pixel(cell - 1, i).a > 0.0
				check(not touching, "%s: cell %d,%d reaches its edge" % [path, x, y])
				check(not c.is_invisible(), "%s: cell %d,%d has a hammer in it" % [path, x, y])
	var fire := Image.load_from_file(FxHammerAura.BURNING)
	var size := fire.get_width() / FxHammerAura.ANGLES
	var strike := (FxHammerAura.ANGLES - 1) * size    # a column with flames: the first frames are all inside the clear circle round his fist
	check(fire.get_region(Rect2i(strike, 0, size, size)).get_data() != fire.get_region(Rect2i(strike, size, size, size)).get_data(), "its flames change between rows")

# His fist shows on the handle and the fire never buries him: characters mark their pixels and it stays off them. The pixels themselves only show in a real window (headless draws nothing).
func test_he_stands_in_front_of_it() -> void:
	var e := await _leap(Vector3(3.0, 0.0, 0.0))
	var look := e._aura._spr.material_override as StandardMaterial3D
	check(look.stencil_mode == BaseMaterial3D.STENCIL_MODE_CUSTOM and look.stencil_flags == BaseMaterial3D.STENCIL_FLAG_READ and look.stencil_compare == BaseMaterial3D.STENCIL_COMPARE_NOT_EQUAL, "it stays off marked pixels")
	check(("stencil_mode write, %d;" % look.stencil_reference) in CharacterSprite.SHADER.code, "and that's the mark every character writes")
	check(look.albedo_texture == e._aura._spr.texture, "it draws the sheet it was given")
	Fx.clear_all()
	e.queue_free()
	Journey.reset()
	await get_tree().physics_frame

# A handle a fist can close on, no thicker than his fist where he holds it, and no flame round that fist in any frame. The strike's handle lies nearly flat, so a column across it is its thickness.
func test_his_fist_is_on_a_thin_handle_clear_of_flames() -> void:
	var fire := Image.load_from_file(FxHammerAura.BURNING)
	var cell := fire.get_width() / FxHammerAura.ANGLES
	var solid := fire.get_region(Rect2i((FxHammerAura.ANGLES - 1) * cell, 3 * cell, cell, cell))    # the flash row: the shape alone
	var thick := 0
	for y in cell:
		thick += 1 if solid.get_pixel(cell / 2 + 3, y).a > 0.0 else 0
	check(thick > 0 and thick <= 12, "%d px thick at his fist" % thick)
	var strays := 0
	for f in FxHammerAura.ANGLES:
		var shape := fire.get_region(Rect2i(f * cell, 3 * cell, cell, cell))
		for row in 3:
			var burning := fire.get_region(Rect2i(f * cell, row * cell, cell, cell))
			for y in range(cell / 2 - 26, cell / 2 + 26):
				for x in range(cell / 2 - 26, cell / 2 + 26):
					if Vector2(x - cell / 2, y - cell / 2).length() < 26.0 and burning.get_pixel(x, y).a > 0.0 and shape.get_pixel(x, y).a == 0.0:
						strays += 1
	check(strays == 0, "%d px of flame round his fist" % strays)

# [damage on a foe beside the landing, particle kinds in the blow, is its ring on fire]
func _damage_of_a_blow(upgraded: bool) -> Array:
	var e := await _leap(Vector3(4.0, 0.0, 0.0), upgraded)
	var d := DUMMY.instantiate() as Actor
	d.position = Vector3(5.0, 0.0, 0.0)
	add_child(d)
	check(e._aura._spr.vframes == (4 if upgraded else 2), "the look that goes with it (%d rows)" % e._aura._spr.vframes)
	var hp := d.health.hp
	for i in 600:
		await get_tree().physics_frame
		if e._landed:
			break
	await _wait(FxHammerAura.FLASH)
	var blow := _blows()[0] as FxEffect
	var burning: bool = blow._spr.texture == FxEffect._pixelfx_sheets[blow.BURNING] if FxEffect._pixelfx_sheets.has(blow.BURNING) else false
	var out := [hp - d.health.hp, burning]
	Fx.clear_all()
	e.queue_free()
	d.queue_free()
	Journey.reset()
	await get_tree().physics_frame
	return out

# Where his fist is drawn this frame.
func _in_hand(e: Elvis, a: FxHammerAura) -> Vector3:
	var hand: Vector2i = FxHammerAura.HANDS[a._spr.frame % FxHammerAura.ANGLES]
	return e.sprite.drawn_at() + Vector3((-1.0 if e.facing.x < 0.0 else 1.0) * hand.x, -hand.y * Pixel.sprite_scale_y(), 0.0) / Pixel.PX

func _leap(to: Vector3, upgraded := false, look := "vulcan_human") -> Elvis:
	Journey.reset()
	Journey.hammer_upgraded = upgraded
	if get_child_count() == 0:
		var ground := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(60, 1, 60)
		shape.shape = box
		ground.add_child(shape)
		ground.position.y = -0.5
		add_child(ground)
	var e := ELVIS.instantiate() as Elvis
	e.character = look
	add_child(e)
	await get_tree().physics_frame
	e._ability = Journey.ABILITIES["Hammer Blow"]
	e._aim_at = to
	e._enter(Elvis.State.ABILITY)
	return e

func _auras() -> Array:
	return Fx.get_children().filter(func(n: Node) -> bool: return n is FxHammerAura and not n.is_queued_for_deletion())

func _blows() -> Array:
	return Fx.get_children().filter(func(n: Node) -> bool: return n.get_script() == Fx.KINDS[&"hammer_blow"] and not n.is_queued_for_deletion())

func _gone(n: Variant) -> bool:    # a Variant: it may already be freed
	return not is_instance_valid(n) or n.is_queued_for_deletion()

func _wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
