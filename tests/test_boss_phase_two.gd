extends TestCase
# Vulcan past half: the colour that comes in on his roar, the shake of his blows, and the fire along his sword in the slam.

const VULCAN := preload("res://boss/vulcan.tscn")

func _spawn() -> Vulcan:
	var v: Vulcan = VULCAN.instantiate()
	add_child(v)
	await get_tree().physics_frame
	v.set_statue(false)
	return v

func _rage(v: Vulcan) -> float:
	return float(v.sprite._mat.get_shader_parameter(&"rage"))

func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func test_the_colour_comes_in_on_the_roar_and_a_reset_clears_it() -> void:
	var v := await _spawn()
	v.health.take(v.health.max_hp * 0.5)
	check(v._rage_light.light_energy == 0.0, "no light before the rage")
	await _ticks(2)
	check(v.mode == Vulcan.Mode.ROAR and _rage(v) > 0.0 and _rage(v) < 0.2, "it starts as he roars, it doesn't pop (%s)" % _rage(v))
	await get_tree().create_timer(Vulcan.RAGE_IN + 0.1).timeout
	check(_rage(v) == 1.0 and v.mode == Vulcan.Mode.ROAR, "all of him before the roar ends (%s)" % _rage(v))
	near(v._rage_light.light_energy, Vulcan.RAGE_ENERGY, 0.001, "and the light it throws round him")
	check(not v._rage_light.shadow_enabled and v._rage_light.is_inside_tree(), "no shadow, on him")
	v.reset_fight(Vector3(1.0, 0.0, 4.0))
	check(_rage(v) == 0.0, "gone after a restart (%s)" % _rage(v))
	check(v._rage_light.light_energy == 0.0, "its light too")
	Fx.clear_all()

func test_c3s_sheets_play_at_their_own_speed_after_phase_two() -> void:
	var v := await _spawn()
	v.health.take(v.health.max_hp * 0.5)
	await _ticks(2)
	check(v.sprite.speed_scale == VulcanBrain.PHASE_TWO_RATE, "faster in phase two (%s)" % v.sprite.speed_scale)
	v.health.take(v.health.max_hp)
	check(v.kneeling and v.sprite.speed_scale == 1.0, "back to the art's own once he kneels (%s)" % v.sprite.speed_scale)
	Fx.clear_all()

# The shader mixes frost in last, so frost on top of rage is the slow's colour (seen in the game's own pictures); here, that the two don't clear each other.
func test_a_slow_in_phase_two_keeps_the_rage_for_after() -> void:
	var v := await _spawn()
	v.health.take(v.health.max_hp * 0.5)
	await get_tree().create_timer(Vulcan.ROAR_TIME + 0.1).timeout
	var info := HitInfo.new()
	info.slow = 0.1
	v._chill(info)
	check(float(v.sprite._mat.get_shader_parameter(&"frost")) == 1.0 and _rage(v) == 1.0, "both on while slowed")
	await get_tree().create_timer(0.2).timeout
	check(float(v.sprite._mat.get_shader_parameter(&"frost")) == 0.0 and _rage(v) == 1.0, "and only the rage after")
	Fx.clear_all()

func _strike_with_camera(move: StringName, phase_two: bool) -> Array:
	var cam := PixelCamera.new()
	add_child(cam)
	cam.make_current()
	var v := await _spawn()
	if phase_two:
		v.phase = 2
		v.brain.phase = 2
	v._begin(move)
	v._strike(VulcanMoves.MOVES[move])
	var r: Array = [v, cam, cam._shake_px]
	return r

func test_phase_two_blows_shake_more_when_heavier_and_phase_one_slashes_dont() -> void:
	var light := await _strike_with_camera(&"slash", true)
	check(light[2] > 0, "a slash shakes the camera in phase two (%d)" % light[2])
	var heavy := await _strike_with_camera(&"slam", true)
	check(heavy[2] > light[2], "a slam shakes it harder (%d, %d)" % [heavy[2], light[2]])
	(light[0] as Vulcan).queue_free()
	(heavy[0] as Vulcan).queue_free()
	(heavy[1] as PixelCamera).queue_free()
	(light[1] as PixelCamera).queue_free()
	await get_tree().process_frame
	var calm := await _strike_with_camera(&"slash", false)
	check(calm[2] == 0, "a slash doesn't in phase one (%d)" % calm[2])
	Fx.clear_all()

func test_the_shake_stays_on_the_pixel_grid_and_leaves_no_offset() -> void:
	var cam := PixelCamera.new()
	add_child(cam)
	cam.make_current()
	Feel.shake(6.0, 0.1)
	for i in 4:
		await get_tree().process_frame
		var px := cam.h_offset * Pixel.PX
		near(px, roundf(px), 0.001, "whole pixels across")
		var py := cam.v_offset * Pixel.PX
		near(py, roundf(py), 0.001, "whole pixels up and down")
		check(absf(px) <= 6.5 and absf(py) <= 6.5, "no further than asked (%s, %s)" % [px, py])
	await get_tree().create_timer(0.15, true, false, true).timeout
	await get_tree().process_frame
	check(cam.h_offset == 0.0 and cam.v_offset == 0.0, "back to rest (%s, %s)" % [cam.h_offset, cam.v_offset])

func _auras() -> Array:
	return Fx.get_children().filter(func(c: Node) -> bool: return c is FxSwordAura and not c.is_queued_for_deletion())

func test_the_sword_aura_follows_the_blade_to_the_blow_then_goes() -> void:
	var v := await _spawn()
	for way: Vector2 in [Vector2.DOWN, Vector2.RIGHT, Vector2.LEFT, Vector2.UP]:
		v.facing = way
		v._begin(&"slam")
		check(_auras().size() == 1, "one aura from the start of the wind-up (%d)" % _auras().size())
		var a: FxSwordAura = _auras()[0]
		var view := FxSwordAura.VIEWS.find(CharacterSprite.dir_suffix(way))
		check(a._spr.flip_h == (way == Vector2.LEFT), "it mirrors as he does")
		while v.mode == Vulcan.Mode.WINDUP:
			await get_tree().process_frame
			a._process(0.0)    # process_frame fires before the frame's _process: this is what it draws
			check(a._spr.frame % FxSwordAura.COLUMNS == v.sprite.frame, "on his frame (%d, %d)" % [a._spr.frame, v.sprite.frame])
			check(a._spr.frame / FxSwordAura.COLUMNS / FxSwordAura.FLAMES == view, "in his view (%d)" % a._spr.frame)
			var off: Vector3 = a._spr.global_position - v.sprite.drawn_at()
			near(off.x, 0.0, 0.001, "over him, across")
		await get_tree().create_timer(FxSwordAura.LINGER + 0.1).timeout
		check(not is_instance_valid(a) or a.is_queued_for_deletion(), "gone just after the blow")
		v._abort()
		v.mode = Vulcan.Mode.IDLE
	Fx.clear_all()

# The fire along the blade lights him and the floor, from the blade, as strong as the flames show.
func test_the_sword_aura_throws_light() -> void:
	var v := await _spawn()
	v._begin(&"slam")
	var a: FxSwordAura = _auras()[0]
	await get_tree().process_frame
	a._process(0.0)
	check(a._lights.size() == 1 and not a._lights[0].shadow_enabled, "one light, no shadow")
	check(a._lights[0].global_position.is_equal_approx(a._spr.global_position), "at the fire")
	check(a._lights[0].light_energy > 0.0, "on as it shows")
	near(a._lights[0].light_energy, a._energy[0] * a._spr.modulate.a, 0.001, "in the fire's own steps")
	Fx.clear_all()

func test_the_sword_aura_never_outlasts_a_broken_slam() -> void:
	var v := await _spawn()
	v._begin(&"slam")
	var a: FxSwordAura = _auras()[0]
	await _ticks(3)
	v._flinch()
	await _ticks(2)
	check(not is_instance_valid(a), "flinching puts it out")
	Fx.clear_all()

# art/tools/sword_aura.py: where the sheets were drawn with no sword the fire still has one down its middle, or it reads as a beam out of his helmet.
func test_the_fire_always_has_a_blade_in_it() -> void:
	var aura := Image.load_from_file(FxSwordAura.SHEET)
	var cell_w := aura.get_width() / FxSwordAura.COLUMNS
	var cell_h := aura.get_height() / (FxSwordAura.VIEWS.length() * FxSwordAura.FLAMES)
	var pad := (cell_w - 122) / 2    # his cell is in the middle of the aura's
	for s: Array in [["F", 1, 62, 40, 52], ["F", 2, 62, 20, 48], ["B", 4, 61, 44, 56], ["B", 5, 60, 66, 70]]:    # view, frame, x, the blade's y from and to above his head
		var sheet := Image.load_from_file("res://art/vulcan_boss/slam_%s.png" % s[0])
		var row := FxSwordAura.VIEWS.find(s[0]) * FxSwordAura.FLAMES
		for y: int in range(s[3], s[4]):
			check(sheet.get_pixel(s[1] * 122 + s[2], y).a > 0.0, "slam_%s %d holds a blade at y %d" % [s[0], s[1], y])
			check(aura.get_pixel(s[1] * cell_w + pad + s[2], row * cell_h + pad + y).a == 0.0, "and the fire leaves it showing at y %d" % y)

# art/tools/boss_eyes.py: his eyes are marked in every waking sheet, in pairs, on him, and only the two marks ever change a sheet's alpha.
func test_eyes_are_marked_in_every_view_and_nowhere_else() -> void:
	var anims: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/vulcan_boss/manifest.json"))["anims"]
	for key: String in anims:
		var img := Image.load_from_file("res://art/vulcan_boss/" + str(anims[key]["file"]))
		var lit := 0
		var other := 0
		for y in img.get_height():
			for x in img.get_width():
				var a := int(round(img.get_pixel(x, y).a * 255.0))
				lit += int(a == 250)
				other += int(a != 0 and a != 255 and a != 250 and a != 240)
		check(other == 0, "%s has only the marks (%d others)" % [key, other])
		var asleep: bool = key.begins_with("statue") or key.begins_with("wake") or key.begins_with("kneel")
		check((lit == 0) == asleep, "%s: %d eye pixels" % [key, lit])
