shader_type spatial;
// A town wall: as prop.gdshader, with a dithered hole round him when he stands behind it, so he can walk right up to it and you can still see him.
render_mode cull_disabled;

#include "res://core/palette.gdshaderinc"

uniform sampler2D tex : source_color, filter_nearest;
uniform vec2 hole_at = vec2(0.0);
uniform float hole_r = 0.0;    // px; 0: no hole

void fragment() {
	vec4 c = texture(tex, UV);
	if (c.a < 0.5 || pal_is_prop_line(srgb(c.rgb), tex, UV)) {
		discard;
	}
	if (hole_r > 0.0) {
		float d = length(FRAGCOORD.xy - hole_at);
		if (d < hole_r * 0.7 || (d < hole_r && mod(floor(FRAGCOORD.x) + floor(FRAGCOORD.y), 2.0) < 1.0)) {
			discard;
		}
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
