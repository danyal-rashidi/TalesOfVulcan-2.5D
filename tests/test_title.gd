extends TestCase
# The title in front of the prologue, and the settings it keeps.

const TITLE := preload("res://game/title.tscn")

func _title() -> Title:
	var t := TITLE.instantiate() as Title
	add_child(t)
	await get_tree().process_frame
	return t

func _press(action: StringName) -> void:
	Input.action_press(action)
	await get_tree().process_frame
	Input.action_release(action)
	await get_tree().process_frame

func test_new_game_starts_the_prologue() -> void:
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://game/title.tscn", "the game opens on the title")
	var t: Title = await _title()
	check(t._logo != null and t._wide != null, "the logo and the desert load")
	check(t.page == 0 and t.pick == 0 and t.went_to == "", "it waits on New Game")
	await _press(&"confirm")
	check(t.went_to == Title.OPENING, "New Game goes to the prologue (%s)" % t.went_to)
	t.queue_free()
	await get_tree().process_frame

func test_down_to_settings_and_back() -> void:
	var t: Title = await _title()
	await _press(&"move_down")
	check(t.pick == 1, "down picks Settings")
	await _press(&"confirm")
	check(t.page == 1 and t.pick == 0, "it opens the settings page")
	await _press(&"pause")
	check(t.page == 0 and t.pick == 1, "Esc goes back to the title, on Settings")
	check(t.went_to == "", "and nothing started")
	t.queue_free()
	await get_tree().process_frame

# The controls table sits between the third setting and Back without touching either: a new row once ran into Back.
func test_controls_table_fits_between_settings_and_back() -> void:
	var t: Title = await _title()
	t.page = 1
	var last := Title.CONTROLS_Y + 12.0 + (Title.CONTROLS.size() - 1) * Title.CONTROL_ROW
	check(last <= t._row(3).position.y, "the last controls row (%.0f) is above Back's frame (%.0f)" % [last, t._row(3).position.y])
	check(Title.CONTROLS_Y - 4.0 - 12.0 >= t._row(2).end.y, "the header (%.0f) is below the third setting's frame (%.0f)" % [Title.CONTROLS_Y - 4.0, t._row(2).end.y])
	t.queue_free()
	await get_tree().process_frame

func test_start_and_bot_go_past_it() -> void:
	for arg: Array in [["start", "cinerea"], ["start", "colosseum"], ["bot", "fight"]]:
		ShotDriver.set(arg[0], arg[1])
		var t: Title = await _title()
		ShotDriver.set(arg[0], "")
		check(t.went_to == Title.GAME, "%s=%s goes straight to the game (%s)" % [arg[0], arg[1], t.went_to])
		t.queue_free()
	await get_tree().process_frame

func test_settings_round_trip_and_leave_tests_alone() -> void:
	check(Settings.automated(), "a test run doesn't put the player's settings on")
	var path := "user://test_settings.cfg"
	var was := [Settings.fullscreen, Settings.window_scale, Settings.zoom]
	Settings.fullscreen = true
	Settings.window_scale = 2
	Settings.zoom = -1
	Settings.save_to(path)
	Settings.fullscreen = false
	Settings.window_scale = 3
	Settings.zoom = 0
	Settings.load_from(path)
	check(Settings.fullscreen and Settings.window_scale == 2 and Settings.zoom == -1, "they come back as saved")
	var cfg := ConfigFile.new()
	cfg.set_value("display", "window_scale", 9)
	cfg.save(path)
	Settings.load_from(path)
	check(Settings.window_scale == Settings.SCALES and Settings.fullscreen, "a scale too big is cut down, and what's missing is left alone")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Settings.fullscreen = was[0]
	Settings.window_scale = was[1]
	Settings.zoom = was[2]

# Continue is there only once Cinerea has saved; New Game leaves the save alone until Cinerea's first beat.
func test_continue_only_with_a_save_and_new_game_leaves_it() -> void:
	var path := "user://test_save.cfg"
	var t := TITLE.instantiate() as Title
	t.save_path = "user://test_none.cfg"
	add_child(t)
	await get_tree().process_frame
	check(t._rows() == Title.ITEMS, "no save, no Continue (%s)" % [t._rows()])
	t.queue_free()
	Journey.reset()
	Journey.drachma = 15
	Journey.save_to({"looted": true, "met_cassia": false, "reached": false, "at": TombScene.UP_TO}, path)
	var text := FileAccess.get_file_as_string(path)
	Journey.reset()
	t = TITLE.instantiate() as Title
	t.save_path = path
	add_child(t)
	await get_tree().process_frame
	check(t._rows()[0] == "Continue" and t.pick == 0, "with a save it waits on Continue (%s)" % [t._rows()])
	await _press(&"confirm")
	check(t.went_to == Title.CINEREA, "Continue goes to Cinerea (%s)" % t.went_to)
	check(not Journey.story.is_empty() and Journey.drachma == 15, "with the save loaded")
	t.queue_free()
	Journey.reset()
	t = TITLE.instantiate() as Title
	t.save_path = path
	add_child(t)
	await get_tree().process_frame
	await _press(&"move_down")
	await _press(&"confirm")
	check(t.went_to == Title.OPENING, "New Game still starts the prologue (%s)" % t.went_to)
	check(FileAccess.get_file_as_string(path) == text, "and leaves the save as it was")
	t.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Journey.reset()

func test_four_items_fit_under_the_logo() -> void:
	var path := "user://test_save.cfg"
	Journey.save_to({}, path)
	var t := TITLE.instantiate() as Title
	t.save_path = path
	add_child(t)
	await get_tree().process_frame
	check(t._rows().size() == 4, "Continue makes four rows")
	var foot := Title.LOGO_AT.y + t._logo.get_image().get_used_rect().end.y * 2.0
	check(foot <= t._row(0).position.y, "the first row's frame (%.0f) is under the logo's foot (%.0f)" % [t._row(0).position.y, foot])
	check(t._row(3).end.y <= 360.0, "the last (%.0f) is on the screen" % t._row(3).end.y)
	t.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Journey.reset()
