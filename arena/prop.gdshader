shader_type spatial;
// A prop lying about the arena: a nearest-filtered picture, cut at its alpha, lit as the floor under it is, so it takes the moods and the
// effects' hard rings of light like everything else in the arena (Arena's lit.gdshader).
render_mode cull_disabled;

#include "res://core/palette.gdshaderinc"

uniform sampler2D tex : source_color, filter_nearest;

void fragment() {
	vec4 c = texture(tex, UV);
	if (c.a < 0.5 || pal_is_prop_line(srgb(c.rgb), tex, UV)) {
		discard;
	}
	ALBEDO = c.rgb;
	NORMAL = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	ROUGHNESS = 1.0;
}

void light() {
	float a = ATTENUATION * clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	if (!LIGHT_IS_DIRECTIONAL) {
		a = a < 0.0625 ? 0.0 : exp2(round(log2(a)));
	}
	DIFFUSE_LIGHT += LIGHT_COLOR * a / PI;
}
