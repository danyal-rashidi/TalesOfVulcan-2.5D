shader_type canvas_item;
// Someone drawn outside the world, his idle in the inventory or Elvis in the opening: the same palette pass as in the world (core/sprite.gdshader), so he's the same man here. A sheet's colours are sRGB values on a canvas.

#define PAL_RAW_SHEET
#include "res://core/palette.gdshaderinc"

uniform sampler2D sheet : filter_nearest;    // the sheet he's drawn from: the engine won't pass its own TEXTURE on to a function

void fragment() {
	if (pal_is_line(COLOR.rgb, sheet, UV)) {
		discard;
	}
	COLOR.rgb = palette_pass(COLOR.rgb, sheet, UV);
}
