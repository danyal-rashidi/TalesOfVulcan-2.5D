shader_type spatial;
// Tilt-shift, the HD-2D diorama look (the idea from the Lumina engine's post pass, our own code): a wide sharp band across the middle of the
// screen, where he stands, and the far ground at the top and the near ground at the bottom a little soft. A quad over the whole screen (Arena adds
// it when Arena.TILT_SHIFT is on), drawn first of the see-through things, so effects stay sharp over it. Soft by whole screen pixels only: each
// pixel takes the 3x3 round it, so the 640x360 grid stays hard. It never touches a character (the pixels core/sprite.gdshader marks), and it
// gathers nothing that stands in front of the pixel (the depth buffer), so a character's colour never bleeds onto the ground beside him.
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
stencil_mode read, compare_not_equal, 1;

uniform sampler2D screen : hint_screen_texture, filter_nearest, repeat_disable;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;

const float BAND = 0.3;     // half the sharp band, a share of the screen's height: 108 of the 180 px each side of the middle stay sharp. Claude's call
const float SOFT = 0.17;    // and how far past it the blur takes to come in fully, just inside the screen's edge. Claude's call
const float IN_FRONT = 0.3;    // m: a neighbour this much nearer than the pixel stands in front of it, and is left out. Claude's call

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);    // the 2x2 quad covers the screen, wherever the camera is
}

float view_depth(ivec2 p, vec2 size, mat4 inv_projection) {
	vec4 v = inv_projection * vec4((vec2(p) + 0.5) / size * 2.0 - 1.0, texelFetch(depth_texture, p, 0).r, 1.0);
	return -v.z / v.w;
}

void fragment() {
	float amount = smoothstep(BAND, BAND + SOFT, abs(SCREEN_UV.y - 0.5));
	if (amount <= 0.0) {
		discard;
	}
	ivec2 size = textureSize(screen, 0);
	ivec2 at = ivec2(FRAGCOORD.xy);
	float here = view_depth(at, vec2(size), INV_PROJECTION_MATRIX);
	vec3 sum = vec3(0.0);
	float n = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			ivec2 p = clamp(at + ivec2(x, y), ivec2(0), size - ivec2(1));
			if (view_depth(p, vec2(size), INV_PROJECTION_MATRIX) > here - IN_FRONT) {
				sum += texelFetch(screen, p, 0).rgb;
				n += 1.0;
			}
		}
	}
	ALBEDO = sum / max(n, 1.0);    // the pixel itself always counts, so n is at least 1
	ALPHA = amount;
}
