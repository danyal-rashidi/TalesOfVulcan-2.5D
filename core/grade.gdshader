shader_type canvas_item;
// The light and colour of the whole picture, on the 640x360 image before it is scaled up (Grade). The darks lean towards a cool colour at the
// brightness they have, unless they are vivid or already cool (a floor warning, the carriage's red, Elvis's blue, the water: the game's own colours), and a pool of light falls from the middle of the screen out to a tinted edge, in hard rings with a dithered lip so it stays pixel art.

uniform sampler2D screen : hint_screen_texture, filter_nearest, repeat_disable;
uniform vec3 shadow = vec3(0.34, 0.27, 0.5);
uniform float shadow_amount = 0.0;
uniform vec3 pool = vec3(1.0);
uniform vec3 edge = vec3(1.0);
uniform float reach = 0.75;
uniform float saturation = 1.0;

const vec3 LUMA = vec3(0.3, 0.59, 0.11);
const float RINGS = 7.0;    // Claude's call: few enough to be drawn steps, not a soft glow
const float LIP = 0.25;     // of a ring: how wide the dither at its lip is. Wider weaves across the calm sand, narrower shows the ring. Claude's call
const float SHADE_TOP = 0.62;    // as bright as this and up, a colour keeps its own hue. Claude's call
const float VIVID = 0.55;        // as saturated as this and up, too, fading in over the 0.35 below: sand and its shadows are about 0.3, brown hair and clothes 0.4 and up, so the ground cools and the characters keep their colours. Claude's call
const float WHITE = 0.98;        // as bright as this in every channel, a colour is left out of the grade. Claude's call

float bayer(vec2 at) {
	ivec2 p = ivec2(mod(floor(at), 4.0));
	int b = (p.x ^ p.y) & 1;
	int c = p.y & 1;
	int d = ((p.x ^ p.y) >> 1) & 1;
	int e = (p.y >> 1) & 1;
	return float(b * 8 + c * 4 + d * 2 + e) / 16.0 + 0.03125;
}

void fragment() {
	vec3 s = textureLod(screen, SCREEN_UV, 0.0).rgb;
	float white = step(WHITE, min(s.r, min(s.g, s.b)));    // a hit flash: the sprite shader writes pure white, and it stays white wherever on the screen he stands
	float l = dot(s, LUMA);
	s = mix(vec3(l), s, saturation);
	float hi = max(s.r, max(s.g, s.b));
	float vivid = (hi - min(s.r, min(s.g, s.b))) / max(hi, 0.01);
	s = mix(s, shadow * l / dot(shadow, LUMA), shadow_amount * smoothstep(SHADE_TOP, 0.0, l) * smoothstep(VIVID, VIVID - 0.35, vivid) * smoothstep(-0.01, 0.06, s.r - s.b));
	float out_ = length((SCREEN_UV - 0.5) * vec2(16.0 / 9.0, 1.0)) / reach;    // 0 in the middle, 1 at the pool's reach
	float ring = floor(clamp(1.0 - out_, 0.0, 1.0) * RINGS + 0.5 + (bayer(FRAGCOORD.xy) - 0.5) * LIP) / RINGS;
	COLOR = vec4(mix(s * mix(edge, pool, ring), vec3(1.0), white), 1.0);
}
