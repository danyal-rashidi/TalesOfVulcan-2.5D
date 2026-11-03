class_name MemoryVision extends CanvasLayer
# A memory (STORY.md "The Hammer"): a picture of what he remembers, held for a moment between two flashes of white-orange. Each memory is one picture (Danyal), from art/memories/.

signal _over

const PICTURE := "res://art/memories/hammer.png"
const HOLD := 4.0        # Claude's call: s the picture stays
const VEIL := Color(1.0, 0.72, 0.42)           # STORY.md: the screen flashes white-orange

var _time := 1.0         # seconds of real time for one of the scene's
var _view: TextureRect
var _veil: ColorRect

func _ready() -> void:
	_view = TextureRect.new()
	_view.texture = ImageTexture.create_from_image(Image.load_from_file(PICTURE))
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.stretch_mode = TextureRect.STRETCH_SCALE
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.visible = false
	add_child(_view)
	_veil = ColorRect.new()
	_veil.color = Color(VEIL, 0.0)
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)

# Flashes up over the world, holds the picture, and ends on a full white-orange. `time`: how long one second of it lasts.
func play(time: float) -> void:
	_time = maxf(time, 0.001)
	var tw := create_tween()
	tw.tween_property(_veil, "color:a", 1.0, 0.35 * _time)
	await tw.finished
	_view.visible = true
	tw = create_tween()
	tw.tween_property(_veil, "color:a", 0.0, 0.5 * _time)
	tw.tween_interval(HOLD * _time)
	tw.tween_property(_veil, "color:a", 1.0, 0.8 * _time)
	await tw.finished
	_view.visible = false

func fade_out(seconds: float) -> void:
	var tw := create_tween()
	tw.tween_property(_veil, "color:a", 0.0, seconds)
	await tw.finished
	queue_free()
