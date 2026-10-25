shader_type spatial;
// A floor crack: open-crack texels (red 1) glowing by how hot their lava still is, in the fire palette's hard steps (white-hot,
// yellow, orange, dark red), then a cold dark scar; their rims (red 0.5) darken the floor under them, whatever the light.
render_mode unshaded, cull_disabled, shadows_disabled;

uniform sampler2D tex : filter_nearest;
uniform float heat = 1.0;    // 1 as the blow lands, exp(-age / 2.2 s) after

vec3 lin(vec3 c) {    // the palette below is sRGB, as Color8 is
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

void fragment() {
	vec4 t = texture(tex, UV);
	if (t.a < 0.5) {
		discard;
	}
	float h = t.r > 0.75 ? heat : 0.0;
	if (h <= 0.066) {
		ALBEDO = vec3(0.0);
		ALPHA = t.r > 0.75 ? 0.75 : 0.4;
	} else {
		vec3 c = h > 0.7 ? vec3(255.0, 246.0, 214.0) : h > 0.45 ? vec3(255.0, 214.0, 92.0) : h > 0.22 ? vec3(232.0, 104.0, 30.0) : vec3(120.0, 30.0, 18.0);
		ALBEDO = lin(c / 255.0);
		ALPHA = 1.0;
	}
}
