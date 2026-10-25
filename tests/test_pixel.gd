extends TestCase

func test_snap_x() -> void:
	check(Pixel.snap(Vector3(0.017, 0, 0)).x == 0.03125, "x snaps to 1/32 m")

func test_snap_z() -> void:
	near(Pixel.snap(Vector3(0, 0, 0.03)).z, 1.0 / 24.0, 1e-6, "z snaps to 1/24 m")

func test_scale_y() -> void:
	near(Pixel.sprite_scale_y(), 1.5126, 0.001, "sprite scale y = 1/cos(pitch)")

func test_project_settings() -> void:
	check(ProjectSettings.get_setting("display/window/size/viewport_width") == 640, "viewport width 640")
	check(ProjectSettings.get_setting("display/window/size/viewport_height") == 360, "viewport height 360")
	check(ProjectSettings.get_setting("display/window/stretch/mode") == "viewport", "stretch mode viewport")
	check(ProjectSettings.get_setting("display/window/stretch/scale_mode") == "integer", "scale mode integer")
	check(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter") == 0, "nearest texture filter")
