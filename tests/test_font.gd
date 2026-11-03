extends TestCase
# The game's own pixel fonts, whole pixels at every zoom the camera allows.

const LONG := "Does it matter? Your carriage is still standing."
const WINDOWS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(1920, 1200), Vector2i(2560, 1440), Vector2i(3840, 2160)]    # 900p, 1200p and 4K land on views between the 1080p ones
const STAT_ROOM := 82.0    # the narrower of the inventory stats box's two columns
const TAB_W := 78.0        # draw_string clips a tab's name at its box

func test_the_fonts_are_real_pixel_fonts() -> void:
	for path: String in [Hud.JERSEY, Hud.TINY]:
		var f := Hud.pixel_font(path)
		check(f.data.size() > 0, "%s loads" % path)
		check(f.antialiasing == TextServer.FONT_ANTIALIASING_NONE, "%s has no antialiasing" % path)
		check(f.data != (ThemeDB.fallback_font as FontFile).data, "%s isn't the engine's fallback font" % path)
		for c in "azAZ09-'?\"":
			check(f.has_char(c.unicode_at(0)), "%s has %s" % [path, c])

# Letters drift apart if the em isn't a whole number of the font's pixels, whatever the hinting.
func test_jersey_letters_space_evenly() -> void:
	var f := Hud.pixel_font()
	var sum := 0.0
	for c in LONG:
		sum += f.get_string_size(c, HORIZONTAL_ALIGNMENT_LEFT, -1, Hud.JERSEY_EM).x
	check(f.get_string_size(LONG, HORIZONTAL_ALIGNMENT_LEFT, -1, Hud.JERSEY_EM).x == sum, "the row is its letters added up")

func test_text_is_whole_pixels_and_fits_at_every_zoom() -> void:
	var was := PixelCamera.view_scale
	for win: Vector2i in WINDOWS:
		for step in range(-8, 9):
			if PixelCamera.allowed_step(win, step) != step:
				continue
			PixelCamera.view_scale = PixelCamera.view_for(win, step).y / float(PixelCamera.VIEW.y)
			for size: int in [Hud.SMALL, Hud.TEXT, Hud.TEXT + 4, Hud.BIG]:
				var em := Hud.TINY_EM if Hud.font(size) == Hud.pixel_font(Hud.TINY) else Hud.JERSEY_EM
				check(Hud.font_px(size) % em == 0, "size %d at %s step %d is a whole multiple of the font's pixel" % [size, win, step])
			check(Hud.text_w(LONG, Hud.TEXT) + 34.0 <= PixelCamera.VIEW.x, "the longest answer fits the screen at %s step %d" % [win, step])
			for size: int in [Hud.TEXT, 14, Hud.TEXT + 4]:
				check(Hud.font(size) == Hud.font(Hud.SMALL) and Hud.font_px(size) == Hud.font_px(Hud.SMALL), "size %d matches the small text at %s step %d" % [size, win, step])
			for label: String in ["Embers", "Drachma", "Health", "Stamina"]:
				check(Hud.text_w(label, Hud.TEXT) <= STAT_ROOM, "%s fits its column at %s step %d" % [label, win, step])
			for tab: String in Journey.TABS:
				check(Hud.text_w(tab, Hud.SMALL) <= TAB_W, "%s fits its tab at %s step %d" % [tab, win, step])
			for i in Journey.PATHS.size():
				var w := Hud.text_w(Journey.PATHS[i]["name"], Hud.SMALL)
				check(w <= GameMenu.PATH_NAME_W, "%s isn't clipped at %s step %d" % [Journey.PATHS[i]["name"], win, step])
				if i > 0:
					check((w + Hud.text_w(Journey.PATHS[i - 1]["name"], Hud.SMALL)) / 2.0 + 2.0 < GameMenu.SKILL_STEP.x, "%s keeps clear of the path before it at %s step %d" % [Journey.PATHS[i]["name"], win, step])
	PixelCamera.view_scale = was
