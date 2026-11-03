class_name Grade extends CanvasLayer
# The light and colour of the whole world, from the current mood (Arena.MOODS holds every value; Arena.set_mood tweens them). A screen shader under
# every other 2D layer, so the sandstorm, a memory, the HUD and the menus all draw over it, ungraded, and the prologue, which has no Arena, never meets it.

const SHADER := preload("res://core/grade.gdshader")
const UNIFORMS: Array[StringName] = [&"shadow", &"shadow_amount", &"pool", &"edge", &"reach", &"saturation"]    # in the order of their columns in Arena.MOODS

var material := ShaderMaterial.new()
var sprite_lit := 0.0:    # how much the mood's sun lights the sprites, which are unshaded: core/sprite.gdshader reads it
	set(v):
		sprite_lit = v
		RenderingServer.global_shader_parameter_set(&"sprite_lit", v)

func _init() -> void:
	layer = -1
	material.shader = SHADER
	var view := ColorRect.new()
	view.material = material
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
