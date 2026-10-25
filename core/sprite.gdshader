shader_type spatial;
// Character sprites. Replaces Sprite3D's own material, so it also does the fixed-Y billboard,
// the nearest filter and the alpha-cut discard. burn: dissolve to ash. cool: lava orange to grey.
render_mode unshaded, cull_disabled;

uniform sampler2D tex : source_color, filter_nearest;
uniform vec4 tint : source_color = vec4(1.0);
uniform float flash = 0.0;
uniform float burn = 0.0;
uniform float cool = 0.0;

void vertex() {
	// Same as StandardMaterial3D's BILLBOARD_FIXED_Y with keep-scale.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
		MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec4 c = texture(tex, UV) * tint;
	if (c.a < 0.5) {
		discard;
	}
	// One random value per texel, so burning eats the sprite texel by texel.
	float n = fract(sin(dot(floor(UV * vec2(textureSize(tex, 0))), vec2(12.9898, 78.233))) * 43758.5453);
	if (n < burn) {
		discard;
	}
	if (burn > 0.0 && n < burn + 0.12) {
		c.rgb = vec3(0.17, 0.15, 0.14);    // an ash rim ahead of the dissolve
	}
	float hot = step(0.7, c.r) * step(c.b, 0.35) * step(c.g, c.r * 0.85);    // bright orange texels: the lava cracks
	c.rgb = mix(c.rgb, vec3(dot(c.rgb, vec3(0.3, 0.59, 0.11)) * 0.6), cool * hot);
	ALBEDO = mix(c.rgb, vec3(1.0), flash);
}
