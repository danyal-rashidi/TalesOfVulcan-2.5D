shader_type spatial;
// Character sprites. Replaces Sprite3D's own material, so it also does the fixed-Y billboard,
// the nearest filter and the alpha-cut discard. burn: dissolve to ash. cool: lava orange to grey. stone: all of it grey stone (the statue). glow: warm from within.
// Every character also goes through the palette pass (palette.gdshaderinc), but never the lava, the ash, the stone or the flash.
render_mode unshaded, cull_disabled;
stencil_mode write, 1;    // his pixels, marked: fx/hammer_aura.gd draws over everything but these, so a fist shows on the handle and the hammer never buries him

#include "res://core/palette.gdshaderinc"

uniform sampler2D tex : source_color, filter_nearest;
uniform vec4 tint : source_color = vec4(1.0);
uniform float flash = 0.0;
uniform float burn = 0.0;
uniform float cool = 0.0;
uniform float stone = 0.0;
uniform float glow = 0.0;
uniform float frost = 0.0;    // slowed (Actor._chill): his own shades, in hard steps of ice
uniform float rage = 0.0;    // Vulcan's phase two: his armour soaks to a bruised black texel by texel, the cracks stay hot, the eyes marked in his sheets (art/tools/boss_eyes.py) burn
uniform float cut = 0.0;    // the rows above this share of the picture don't show: a carriage still under an arch

global uniform float sprite_lit;    // the mood's sun on the sprites (Grade): a rim of its light round them
const vec3 SUN_RIM = vec3(0.81, 0.09, 0.025);    // linear: sRGB (232, 84, 44), the red sun on an edge. Claude's call
const float EYE_MARK = 0.99;    // art/tools/boss_eyes.py: an alpha below this is an eye (250), and below GLOW_MARK a pixel touching one (240)
const float GLOW_MARK = 0.96;
const float EYES_LIGHT = 0.15;    // his eyes light first, this far into the rage
const vec3 RAGE_EYE = vec3(1.0, 0.09, 0.05);    // sRGB
const vec3 RAGE_GLOW = vec3(0.6, 0.03, 0.04);    // sRGB
const float SUN_LIFT = 0.8;    // and what it does to the rest of him: a curve that brings dark armour up a little and leaves what's already bright, hue kept. Much more and he goes grey. Claude's call

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
	if (UV.y < cut) {
		discard;
	}
	vec4 c = texture(tex, UV) * tint;
	if (c.a < 0.5 || pal_is_line(srgb(texture(tex, UV).rgb), tex, UV)) {
		discard;
	}
	// One random value per texel, so burning eats the sprite texel by texel.
	float n = fract(sin(dot(floor(UV * vec2(textureSize(tex, 0))), vec2(12.9898, 78.233))) * 43758.5453);
	if (n < burn) {
		discard;
	}
	float ash = 0.0;
	if (burn > 0.0 && n < burn + 0.12) {
		c.rgb = vec3(0.17, 0.15, 0.14);    // an ash rim ahead of the dissolve
		ash = 1.0;
	}
	float hot = step(0.7, c.r) * step(c.b, 0.35) * step(c.g, c.r * 0.85);    // bright orange texels: the lava cracks
	c.rgb = mix(c.rgb, vec3(dot(c.rgb, vec3(0.3, 0.59, 0.11)) * 0.6), cool * hot);
	float lum = min(sqrt(dot(c.rgb, vec3(0.3, 0.59, 0.11))) * 1.2, 1.0);    // sqrt: about as bright as it looks (c is linear)
	vec3 own = palette_pass(srgb(c.rgb), tex, UV);
	float fury = rage * (1.0 - cool);    // it dies as his cracks cool
	if (n < fury) {
		own = lum > 0.5 ? vec3(0.62, 0.2, 0.62) : lum > 0.34 ? vec3(0.34, 0.09, 0.4) : lum > 0.2 ? vec3(0.17, 0.05, 0.22) : vec3(0.04, 0.02, 0.06);    // a bruised black, dark to lit, in hard steps as the frost's are: on the blood sun's red floor a red would hide him. Claude's call
	}
	float bright = dot(own, vec3(0.3, 0.59, 0.11));
	own = mix(own, own * pow(max(bright, 0.01), SUN_LIFT - 1.0), sprite_lit * smoothstep(0.045, 0.12, bright));    // the lines inside him stay dark, so his shape holds
	vec2 t = 1.0 / vec2(textureSize(tex, 0));
	vec2 above = UV - vec2(0.0, t.y);
	vec2 left = UV + vec2(dFdx(UV.x) > 0.0 ? -t.x : t.x, 0.0);
	float clear = (!pal_solid(tex, above) || pal_is_line(srgb(texture(tex, above).rgb), tex, above) || !pal_solid(tex, left) || pal_is_line(srgb(texture(tex, left).rgb), tex, left)) ? 1.0 : 0.0;    // open sky above this texel, or on its left as you see it, where the sun is: a mirrored sprite's left is still screen left. A line that isn't drawn is sky
	own = mix(lin(own), SUN_RIM, clear * sprite_lit);
	own = mix(own, c.rgb, max(hot, ash));
	float mark = texture(tex, UV).a;
	if (fury > EYES_LIGHT && mark < EYE_MARK) {
		own = lin(mark < GLOW_MARK ? RAGE_GLOW : RAGE_EYE);
	}
	c.rgb = mix(own, mix(vec3(0.03, 0.025, 0.025), vec3(0.55, 0.5, 0.47), lum), stone);    // stone, dark to lit (linear: sRGB 0.19 to 0.76)
	c.rgb = mix(c.rgb, c.rgb * vec3(1.5, 1.0, 0.55) + vec3(0.32, 0.1, 0.0), glow);    // lit from within by something he holds
	vec3 rime = lum > 0.72 ? vec3(0.84, 0.98, 1.0) : lum > 0.5 ? vec3(0.39, 0.82, 1.0) : lum > 0.3 ? vec3(0.16, 0.55, 0.95) : vec3(0.07, 0.2, 0.52);    // sRGB, whatever colour he was. Claude's call
	c.rgb = mix(c.rgb, lin(rime), frost);
	ALBEDO = mix(c.rgb, vec3(1.0), flash);
}
