shader_type spatial;
// A tuft of dry grass, bending smoothly: its picture is 4 times the game's pixels and each pixel on screen looks up where that blade has bent to, so there are no frames to count and each blade moves a little differently. It sways on its own (phase: each tuft its own moment) and bends when something walks into it (push). The outline is drawn here, one screen pixel wide, so it stays whole as it bends.
render_mode cull_disabled;

#include "res://core/palette.gdshaderinc"

uniform sampler2D tex : source_color, filter_nearest;
uniform float phase = 0.0;
uniform float push = 0.0;
const float HI = 4.0;      // art/tools/round2_props.py
const float ROOM = 6.0;    // px of the game's: it leaves 7 empty columns each side
const vec3 LINE = vec3(0.006, 0.004, 0.004);
const float EDGE = 0.4;    // linear, so about 0.65 of its brightness on screen: dark enough to read on sand, and still grass, not a line. Claude's call

void fragment() {
	vec2 size = vec2(textureSize(tex, 0));
	float tall = 1.0 - UV.y;
	float blade = UV.x * 11.0;
	float wind = sin(TIME * 1.5 + phase + blade) * 0.32 + sin(TIME * 0.52 + phase * 2.3) * 0.75 + sin(TIME * 3.4 + phase + blade * 2.1) * 0.1;
	float lean = clamp((wind + push) * pow(tall, 1.6) * 4.0, -ROOM, ROOM);
	vec2 uv = vec2(UV.x - lean * HI / size.x, UV.y);
	vec4 c = texture(tex, uv);
	if (c.a < 0.5) {
		vec2 step_uv = HI / size;
		float near = texture(tex, uv + vec2(step_uv.x, 0.0)).a + texture(tex, uv - vec2(step_uv.x, 0.0)).a + texture(tex, uv + vec2(0.0, step_uv.y)).a + texture(tex, uv - vec2(0.0, step_uv.y)).a;
		if (near < 0.5 || !PAL_LINE_ON) {
			discard;
		}
		c.rgb = LINE;
	} else if (!PAL_LINE_ON) {    // no line to hold the tuft's shape on sand: a blade's own lower and side edges go a darker tone of itself
		vec2 step_uv = HI / size;
		if (texture(tex, uv + vec2(0.0, step_uv.y)).a < 0.5 || texture(tex, uv + vec2(step_uv.x, 0.0)).a < 0.5 || texture(tex, uv - vec2(step_uv.x, 0.0)).a < 0.5) {
			c.rgb *= EDGE;
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
