shader_type spatial;
// A flat mark on the ground in one colour: where a held skill will land (fx/aim_mark.gd).
render_mode unshaded, cull_disabled;

uniform sampler2D tex : source_color, filter_nearest;
uniform vec3 colour : source_color = vec3(0.4, 0.3, 0.2);

void fragment() {
	if (texture(tex, UV).a < 0.5) {
		discard;
	}
	ALBEDO = colour;
}
