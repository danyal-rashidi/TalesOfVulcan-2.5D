extends TestCase
# Saving (docs/ALABASTER_STUDY.md item 10): what a save keeps, Cinerea rebuilt from it, and the beats that write it. Never his real save.

const CINEREA := preload("res://game/cinerea.tscn")
const PATH := "user://test_save.cfg"

func _done() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	Journey.reset()

func test_the_save_round_trips() -> void:
	Journey.reset()
	Journey.add_item(&"iron_sword")
	Journey.add_item(&"jackal_pelt", 3)
	Journey.toggle_equip(&"iron_sword")
	Journey.drachma = 15
	Journey.embers = 2
	Journey.remember(&"hammer")
	Journey.visit(&"desert")
	Journey.visit(&"cinerea")
	Journey.add_trust("Cassia", 30)
	var beats := {"looted": true, "met_cassia": true, "reached": false, "at": CassiaScene.STAND_AT}
	Journey.save_to(beats, PATH)
	Journey.reset()
	check(Journey.load_from(PATH), "it loads")
	check(Journey.bag == {&"iron_sword": 1, &"jackal_pelt": 3}, "the bag comes back (%s)" % Journey.bag)
	check(Journey.equipped.get(&"weapon") == &"iron_sword" and Journey.has_weapon(), "the sword is in his hand")
	check(Journey.drachma == 15 and Journey.embers == 2, "his money and embers")
	check(Journey.memories == [&"hammer"] and Journey.memories.get_typed_builtin() == TYPE_STRING_NAME, "his memory, still a list of names")
	check(Journey.visited == [&"desert", &"cinerea"] and Journey.here == &"cinerea", "where he's been and is")
	check(int(Journey.trust.get("Cassia", 0)) == 30, "Cassia's trust")
	check(Journey.ability_slots[&"ability_f"] == "Hammer Blow", "Hammer Blow on F (%s)" % Journey.ability_slots)
	check(Journey.story == beats and Journey.story["at"] is Vector3, "the beats, with where he picks up (%s)" % Journey.story)
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	var bag: Dictionary = cfg.get_value("journey", "bag")
	bag[&"no_such_item"] = 1
	cfg.set_value("journey", "bag", bag)
	var on: Dictionary = cfg.get_value("journey", "equipped")
	on[&"ring"] = &"no_such_item"
	cfg.set_value("journey", "equipped", on)
	cfg.save(PATH)
	Journey.reset()
	Journey.load_from(PATH)
	check(not Journey.bag.has(&"no_such_item") and not Journey.equipped.has(&"ring"), "what a newer build doesn't know is dropped")
	check(Journey.has_weapon(), "and the rest kept")
	Journey.reset()
	check(not Journey.load_from("user://test_none.cfg") and Journey.bag.is_empty() and Journey.story.is_empty(), "no save loads nothing")
	_done()

func _two_ticks() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame

func _continue(beats: Dictionary) -> Cinerea:
	Journey.story = beats
	var c := CINEREA.instantiate() as Cinerea
	c.fast = true
	add_child(c)
	await _two_ticks()
	return c

func test_continue_rebuilds_the_road_after_the_tomb() -> void:
	Journey.reset()
	var c := await _continue({"looted": true, "met_cassia": false, "reached": false, "at": TombScene.UP_TO})
	check(not c._busy and c.player.input_enabled, "no storm walk: he has control")
	check(Vector2(c.player.global_position.x, c.player.global_position.z).distance_to(Vector2(TombScene.UP_TO.x, TombScene.UP_TO.z)) < 0.1, "he's at the tomb (%s)" % c.player.global_position)
	check(c.looted and c._tomb.frame == Cinerea.TOMB_FRAMES - 1, "the tomb is open")
	check(not is_instance_valid(c._first), "the tomb's jackal is gone")
	check(c._sleepers.size() >= 8, "the road's foes are out (%d)" % c._sleepers.size())
	check(not c._raiders, "the lake is still to come")
	check(Journey.story.is_empty(), "the beats are taken once")
	c.queue_free()
	await _two_ticks()
	_done()

func test_continue_rebuilds_the_town_after_cassia() -> void:
	Journey.reset()
	Journey.add_item(&"iron_sword")
	Journey.toggle_equip(&"iron_sword")
	var c := await _continue({"looted": true, "met_cassia": true, "reached": false, "at": CassiaScene.STAND_AT})
	for i in 2:
		await get_tree().physics_frame
	check(not c._busy, "the lake scene doesn't play, though he stands where it starts")
	check(c.get_children().filter(func(n: Node) -> bool: return n is Jackal).is_empty(), "no foes on the road")
	check(not c.cart_sprite().visible, "the carriage has gone from the road")
	check(c.pull and c.pull.position.is_equal_approx(CassiaScene.PARK) and not c.pull.walking(), "it's parked in town")
	var stall := Vector2(Cinerea.STALL_AT.x, Cinerea.STALL_AT.z)
	check(c._cassia.shown() and c._cassia.position.is_equal_approx(Cinerea.STALL_AT) and not c._cassia.walking(), "she's at her stall")
	check(c._nearest(stall + Vector2(0.0, 1.0)) == c._cassia, "and can be talked to there")
	check(c._fortuna.hitched, "Fortuna is in harness")
	check(c.respawn_at == LakeScene.WALK_TO, "he comes back by the lake")
	check(c.player.has_weapon, "with the sword in his hand")
	c.queue_free()
	await _two_ticks()
	_done()

func test_beats_autosave_and_tests_dont() -> void:
	Journey.reset()
	var plain := CINEREA.instantiate() as Cinerea
	check(plain.save_path == "", "a test's Cinerea never writes his save")
	plain.free()
	var c := CINEREA.instantiate() as Cinerea
	c.fast = true
	c.save_path = PATH
	add_child(c)
	for i in 3000:
		if not c._busy:
			break
		await get_tree().process_frame
	var cfg := ConfigFile.new()
	check(cfg.load(PATH) == OK, "the walk in saves")
	var story: Dictionary = cfg.get_value("cinerea", "story", {})
	check(not story.get("looted", true) and story.get("at") == Cinerea.WAKE_AT, "before the tomb, at the road (%s)" % story)
	c.loot()
	for i in 3000:
		if not c._busy:
			break
		await get_tree().process_frame
	cfg.load(PATH)
	story = cfg.get_value("cinerea", "story", {})
	check(story.get("looted", false) and story.get("at") == TombScene.UP_TO, "the tomb saves, at the tomb (%s)" % story)
	Dev.no_save = true
	c.autosave(Cinerea.WAKE_AT)
	cfg.load(PATH)
	story = cfg.get_value("cinerea", "story", {})
	check(story.get("at") == TombScene.UP_TO, "after a Dev jump nothing saves (%s)" % story)
	Dev.no_save = false
	c.queue_free()
	await _two_ticks()
	_done()
