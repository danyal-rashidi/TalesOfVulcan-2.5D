shader_type spatial;
// Character sprites. Replaces Sprite3D's own material, so it also does the fixed-Y billboard,
// the nearest filter and the alpha-cut discard. burn: dissolve to ash. cool: lava orange to grey. stone: all of it grey stone (the statue). glow: warm from within.
// Every character also goes through the palette pass (palette.gdshaderinc), but never the lava, the ash, the stone or the flash.
// Lit: the sun in three hard steps and the effects' lights in hard rings, on the normals baked beside his sheet (<sheet>_n.png, CharacterSprite);
// a sheet with none is flat, facing the camera. No sky light: SELF_LIT is his floor. No shadows on him: in the shadow pass the billboard turns to the sun and would shade half of itself.
render_mode cull_disabled, shadows_disabled, ambient_light_disabled;
stencil_mode write, 1;    // his pixels, marked: fx/hammer_aura.gd draws over everything but these, so a fist shows on the handle and the hammer never buries him

#include "res://core/palette.gdshaderinc"

uniform sampler2D tex : source_color, filter_nearest;
uniform sampler2D nrm : hint_normal, filter_nearest;    // unset: flat
uniform vec4 tint : source_color = vec4(1.0);
uniform float flash = 0.0;
uniform float burn = 0.0;
uniform float cool = 0.0;
uniform float stone = 0.0;
uniform float glow = 0.0;
uniform float frost = 0.0;    // slowed (Actor._chill): his own shades, in hard steps of ice
uniform float rage = 0.0;    // Vulcan's phase two: his armour soaks to a bruised black texel by texel, the cracks stay hot, the eyes marked in his sheets (art/tools/boss_eyes.py) burn
uniform float cut = 0.0;    // the rows above this share of the picture don't show: a carriage still under an arch

global uniform float sprite_lit;    // the mood's (Grade): how far a dim mood's weak sun lifts his floor from SELF_LIT to full, so he draws as bright as unshaded did
const float SELF_LIT = 0.65;    // what every texel gives by itself, in place of the sky's light, so a dark mood never loses him. With the sun's middle step on a flat sheet, a day draws him as bright as unshaded did (calm 0.65 + 1.1 x 0.35). Claude's call
const float SUN_MID = 0.35;    // the sun's three steps: none, the middle (a flat sheet faces the arena's sun, (-55, -35, 0), at 0.47) and the full
const float SUN_TOP = 0.7;
const float EYE_MARK = 0.99;    // art/tools/boss_eyes.py: an alpha below this is an eye (250), and below GLOW_MARK a pixel touching one (240)
const float GLOW_MARK = 0.96;
const float EYES_LIGHT = 0.15;    // his eyes light first, this far into the rage
const vec3 RAGE_EYE = vec3(1.0, 0.09, 0.05);    // sRGB
const vec3 RAGE_GLOW = vec3(0.6, 0.03, 0.04);    // sRGB

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

// Before fragment(), which has to end with the flash (tests/test_sprite.gd).
void light() {
	float a = dot(NORMAL, LIGHT);
	if (LIGHT_IS_DIRECTIONAL) {
		a = a < 0.35 ? 0.0 : a < 0.6 ? SUN_MID : SUN_TOP;    // a narrow middle: at 0.2 / 0.75 four fifths of him sat in it and the sun hardly showed on him; now about a third each. Claude's call
	} else {
		a = ATTENUATION * (0.5 + 0.5 * a);    // half wrapped: a fire beside him, in his own plane, still lights him. Claude's call
		a = a < 0.0625 ? 0.0 : exp2(round(log2(a)));    // hard rings, each twice the one outside it, as arena/lit.gdshader's
	}
	DIFFUSE_LIGHT += LIGHT_COLOR * a / PI;
}

void fragment() {
	if (UV.y < cut) {
		discard;
	}
	vec4 c = texture(tex, UV) * tint;
	if (c.a < 0.5 || pal_is_line(srgb(texture(tex, UV).rgb), tex, UV)) {
		discard;
	}
	vec3 nm = texture(nrm, UV).rgb;
	NORMAL_MAP = vec3(dFdx(UV.x) > 0.0 ? nm.x : 1.0 - nm.x, nm.yz);    // a mirrored sheet (flip_h runs its UVs backwards) turns its normals' x round too
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
	own = lin(own);
	own = mix(own, c.rgb, max(hot, ash));
	float mark = texture(tex, UV).a;
	float eye = 0.0;
	if (fury > EYES_LIGHT && mark < EYE_MARK) {
		own = lin(mark < GLOW_MARK ? RAGE_GLOW : RAGE_EYE);
		eye = 1.0;
	}
	c.rgb = mix(own, mix(vec3(0.03, 0.025, 0.025), vec3(0.55, 0.5, 0.47), lum), stone);    // stone, dark to lit (linear: sRGB 0.19 to 0.76)
	c.rgb = mix(c.rgb, c.rgb * vec3(1.5, 1.0, 0.55) + vec3(0.32, 0.1, 0.0), glow);    // lit from within by something he holds
	vec3 rime = lum > 0.72 ? vec3(0.84, 0.98, 1.0) : lum > 0.5 ? vec3(0.39, 0.82, 1.0) : lum > 0.3 ? vec3(0.16, 0.55, 0.95) : vec3(0.07, 0.2, 0.52);    // sRGB, whatever colour he was. Claude's call
	c.rgb = mix(c.rgb, lin(rime), frost);
	float shines = max(max(hot * (1.0 - cool), eye) * (1.0 - max(stone, frost)), max(glow, flash));    // what gives its own light whatever the mood: the lava, his rage's eyes, a glow from within, the flash
	EMISSION = mix(c.rgb, vec3(1.0), flash) * mix(mix(SELF_LIT, 1.0, sprite_lit), 1.0, shines);
	ALBEDO = mix(c.rgb, vec3(1.0), flash);
}
