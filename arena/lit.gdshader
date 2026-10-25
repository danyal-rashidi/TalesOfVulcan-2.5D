shader_type spatial;
// The arena's floor, walls and plinth: a nearest-filtered texture, lit like StandardMaterial3D's Lambert, except that a point light
// (an effect's glow) lands in hard rings, each twice as bright as the one outside it, and none beyond the faintest: pixel art, with
// no smooth falloff across the posterized floor. The sun and the lightning flash are directional, so a flat face takes them evenly.
render_mode cull_disabled;

uniform sampler2D tex : source_color, filter_nearest, repeat_enable;
uniform vec2 tiles = vec2(1.0);

void fragment() {
	ALBEDO = texture(tex, UV * tiles).rgb;
	ROUGHNESS = 1.0;
}

void light() {
	float a = ATTENUATION * clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	if (!LIGHT_IS_DIRECTIONAL) {
		a = a < 0.0625 ? 0.0 : exp2(round(log2(a)));
	}
	DIFFUSE_LIGHT += LIGHT_COLOR * a / PI;
}
