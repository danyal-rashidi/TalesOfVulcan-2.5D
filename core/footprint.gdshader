shader_type spatial;
// A footprint pressed into the ground. It multiplies what's already drawn there, so it takes that ground's colour and light: sand, cobbles, shade, any mood.
// Which part of the print a texel is comes from the stamp's alpha (Steps._paint). It fades toward no change at all, in hard steps, as everything else in the game does.
render_mode unshaded, cull_disabled, blend_mul, depth_draw_never, shadows_disabled;

uniform sampler2D tex : filter_nearest;
uniform float fade = 1.0;
uniform bool lip = true;    // stone doesn't heap up round a foot

// Claude's call, these three. It multiplies light before it's turned into screen colour, so 0.5 here looks like 0.73 on screen. The picture is HDR until then, so above 1 is fine.
const vec3 DEEP = vec3(0.28, 0.19, 0.13);      // the wall nearest the sun, in its own shadow
const vec3 HOLLOW = vec3(0.48, 0.38, 0.29);
const vec3 LIP = vec3(1.3, 1.26, 1.15);

void fragment() {
	float a = texture(tex, UV).a;
	if (a < 0.1 || (a < 0.26 && !lip)) {
		discard;
	}
	ALBEDO = mix(vec3(1.0), a < 0.26 ? LIP : (a < 0.41 ? HOLLOW : DEEP), ceil(fade * 4.0) / 4.0);
}
