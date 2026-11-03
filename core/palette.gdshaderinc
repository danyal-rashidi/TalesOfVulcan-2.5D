// The sprite palette pass, on a sheet's own colours (sRGB values): the silhouette's near-black becomes a deep maroon line, true shadows lean to a cool
// dark at the brightness they have (a blue cloak's already are), a thing's own colour keeps its hue, lights stay warm. Only by colour and by nearness to the outside, so a face's eyes, which are near-black inside the
// head, stay as dark as they were (Danyal's approved face). Every value here is Claude's call.

const bool PAL_LINE_ON = false;    // THE SWITCH for the dark line round everything in the world, characters, carriage, props, houses and grass (Danyal: "getting rid of the black outline around everything"): false, it isn't drawn; true, it's back as the warm line below. Every shader that draws the world asks pal_is_line() or this. Words, HUD, menus and floating signs have their own edges and don't ask.
const vec3 PAL_LUMA = vec3(0.3, 0.59, 0.11);
const vec3 PAL_LINE = vec3(0.24, 0.09, 0.15);      // the outermost line: sRGB (61, 23, 38). The one colour to change: the two below follow it
const vec3 PAL_LINE_IN = PAL_LINE * 0.7;           // the near-black just inside it
const vec3 PAL_INK = PAL_LINE * 0.38;              // near-black drawn lines deeper in: only darkly coloured, so a mouth in a beard stays darker than the beard
const vec3 PAL_COOL = vec3(0.38, 0.24, 0.4);       // what a warm shadow leans to: plum, for the line's sake and because the grade cools the picture again after this
const float PAL_LINE_L = 0.14;      // this dark or darker on the very edge is the line
const float PAL_INK_L = 0.045;      // this dark or darker inside is drawn line: his hair and pupils are lighter than this
const vec3 PAL_RING = vec3(20.0, 14.0, 16.0) / 255.0;       // props_to_sprites.py's OUTLINE
const vec3 PAL_RING_NAVY = vec3(14.0, 22.0, 40.0) / 255.0;  // #0e1628
const float PAL_RING_EXACT = 0.004; // near enough to be that colour: the conversion to and from linear rounds a little
const float PAL_PROP_LINE_L = 0.22; // this dark or darker is a prop's drawn line: the art's own edge is lighter than a character's (#2a2122, #332825, #3b2a20), so at PAL_LINE_L it stayed as a dark rim. Claude's call
const int PAL_PROP_LIT = 3;         // this many brighter texels within 2 texels tell a line from a dark thing (a post, an iron band), which has no light art beside it. Claude's call
const int PAL_PROP_GAP = 6;         // a hole in a prop this many texels across or less keeps its dark edge. Claude's call
const float PAL_BLUE_L = 0.11;      // this dark or darker, and bluest, is the sheets' navy ink (#0e1628 and its kin): Elvis's cloak's darkest blue is brighter than this, so it stays his own colour
const float PAL_BLUE_VIVID = 0.3;   // and this saturated: the boss's slate armour is greyer than this, and so is his beard (#121118, 0.29): his own colours too
const float PAL_GREEN_VIVID = 0.65; // this saturated, this dark and greenest is the carriage sheet's green-screen fringe (#0a2209, #062407), just inside its line, which shows once the line's gone. A villager's dark green is greyer
const float PAL_SHADE_TOP = 0.18;   // from this bright down, shadows lean: brown hair, a red scarf and his trousers are brighter than this, so they stay their own colour
const float PAL_VIVID = 0.75;       // as saturated as this and up, a colour keeps its hue however dark it is: a dark red is still red
const float PAL_SHADE = 0.5;        // how far they lean
const vec3 PAL_WARM = vec3(0.025, 0.008, -0.02);   // added to the brightest colours

vec3 lin(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

vec3 srgb(vec3 c) {
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c));
}

// The sheets' navy ink and the carriage's green fringe as a warm dark as bright as they were. The line's own hue: it's vivid enough that the grade won't cool it blue again.
vec3 pal_no_blue(vec3 s) {
	float hi = max(s.r, max(s.g, s.b));
	float l = dot(s, PAL_LUMA);
	float vivid = (hi - min(s.r, min(s.g, s.b))) / max(hi, 0.01);
	if (l < PAL_BLUE_L && ((s.b >= hi && s.b > s.r && vivid >= PAL_BLUE_VIVID) || (s.g >= hi && s.g > s.r && vivid >= PAL_GREEN_VIVID))) {
		return PAL_LINE * l / dot(PAL_LINE, PAL_LUMA);
	}
	return s;
}

// Past the picture's edge is empty: props have their line on the picture's very last row.
bool pal_solid(sampler2D tex, vec2 uv) {
	return uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0 && texture(tex, uv).a >= 0.5;
}

// One texel across along `side`: solid, with nothing on either side of it.
bool pal_thin(sampler2D tex, vec2 uv, vec2 side) {
	return pal_solid(tex, uv) && !pal_solid(tex, uv + side) && !pal_solid(tex, uv - side);
}

// A texel's sRGB colour. A world shader's sampler has source_color, so it reads linear; a shader that defines PAL_RAW_SHEET (a canvas) reads the sheet's values as they are.
vec3 pal_at(sampler2D tex, vec2 uv) {
#ifdef PAL_RAW_SHEET
	return texture(tex, uv).rgb;
#else
	return srgb(texture(tex, uv).rgb);
#endif
}

bool pal_lit(sampler2D tex, vec2 uv) {
	return pal_solid(tex, uv) && dot(pal_at(tex, uv), PAL_LUMA) >= PAL_LINE_L;
}

// Dark on the very edge, one texel deep, so it can't reach eyes or a nose, which are inside it or not dark.
// A dark run one texel across, two or more long, is all there is of that thing there (a sword edge-on, a spear's shaft, a scorpion's leg), so it stays; a lone bump on the line doesn't.
bool pal_is_rim(vec3 s, sampler2D tex, vec2 uv) {
	if (dot(s, PAL_LUMA) >= PAL_LINE_L || !pal_solid(tex, uv)) {
		return false;
	}
	vec2 t = 1.0 / vec2(textureSize(tex, 0));
	vec2 x = vec2(t.x, 0.0);
	vec2 y = vec2(0.0, t.y);
	if (pal_solid(tex, uv + x) && pal_solid(tex, uv - x) && pal_solid(tex, uv + y) && pal_solid(tex, uv - y)) {
		return false;
	}
	bool across_x = pal_thin(tex, uv, x);
	bool across_y = pal_thin(tex, uv, y);
	if (across_x && (pal_thin(tex, uv + y, x) || pal_thin(tex, uv - y, x))) {
		return false;
	}
	if (across_y && (pal_thin(tex, uv + x, y) || pal_thin(tex, uv - x, y))) {
		return false;
	}
	if (across_x && across_y) {    // a thin diagonal: its texels only meet at their corners
		for (int i = 0; i < 4; i++) {
			vec2 d = vec2(i < 2 ? t.x : -t.x, (i % 2 == 0) ? t.y : -t.y);
			if (pal_thin(tex, uv + d, x) && pal_thin(tex, uv + d, y)) {
				return false;
			}
		}
	}
	return true;
}

// Is this texel (its sRGB colour s) a character's line, with the line off? The rim, and the sheet's black drawn line just inside it. That black is darker than his hair, beard, pupils and nose, so his face can't go. It's only a line with 3 texels of lit art right behind it: black against black is armour or a shadow, and on a sword, a strap or a foot it's most of what holds the shape.
bool pal_is_line(vec3 s, sampler2D tex, vec2 uv) {
	if (PAL_LINE_ON || dot(s, PAL_LUMA) >= PAL_LINE_L || !pal_solid(tex, uv)) {
		return false;
	}
	if (pal_is_rim(s, tex, uv)) {
		return true;
	}
	if (dot(s, PAL_LUMA) >= PAL_INK_L) {
		return false;
	}
	vec2 t = 1.0 / vec2(textureSize(tex, 0));
	for (int i = 0; i < 4; i++) {
		vec2 d = i < 2 ? vec2(i == 0 ? t.x : -t.x, 0.0) : vec2(0.0, i == 2 ? t.y : -t.y);
		if (pal_lit(tex, uv - d) && pal_lit(tex, uv - 2.0 * d) && pal_lit(tex, uv - 3.0 * d) && pal_is_rim(pal_at(tex, uv + d), tex, uv + d)) {
			return true;
		}
	}
	return false;
}

// The dark ring art/tools/props_to_sprites.py grew round a prop: exactly its one colour (the fountain's clip has the sheets' navy instead), and on the edge. Being exact is what tells it from the art, so a thin sword or a dark edge of the prop can't go with it, and no piece of ring is left floating.
bool pal_is_ring(vec3 s, sampler2D tex, vec2 uv) {
	if (distance(s, PAL_RING) > PAL_RING_EXACT && distance(s, PAL_RING_NAVY) > PAL_RING_EXACT) {
		return false;
	}
	vec2 t = 1.0 / vec2(textureSize(tex, 0));
	return !pal_solid(tex, uv + vec2(t.x, 0.0)) || !pal_solid(tex, uv - vec2(t.x, 0.0)) || !pal_solid(tex, uv + vec2(0.0, t.y)) || !pal_solid(tex, uv - vec2(0.0, t.y));
}

// Empty, or only the ring.
bool pal_off_prop(sampler2D tex, vec2 uv) {
	return !pal_solid(tex, uv) || pal_is_ring(pal_at(tex, uv), tex, uv);
}

// The same for a prop or a house (a texture with source_color), any size: its ring (one texel, so where two rings met between two rocks the crease stays), and the art's own dark edge just inside it where it faces open ground with lit art close behind. "Close", not straight behind, because the line steps round corners and a straight test leaves those steps standing out as specks.
bool pal_is_prop_line(vec3 s, sampler2D tex, vec2 uv) {
	if (PAL_LINE_ON || dot(s, PAL_LUMA) >= PAL_PROP_LINE_L || !pal_solid(tex, uv)) {
		return false;
	}
	if (pal_is_ring(s, tex, uv)) {
		return true;
	}
	vec2 t = 1.0 / vec2(textureSize(tex, 0));
	bool edge = false;
	for (int i = 0; i < 4; i++) {
		vec2 d = i < 2 ? vec2(i == 0 ? t.x : -t.x, 0.0) : vec2(0.0, i == 2 ? t.y : -t.y);
		if (pal_off_prop(tex, uv + d)) {
			bool gap = false;    // more of the prop across a few empty texels: a hole in it, such as between a wheel's spokes, which trimmed would eat the spokes
			for (int k = 2; k <= PAL_PROP_GAP; k++) {
				gap = gap || !pal_off_prop(tex, uv + float(k) * d);
			}
			edge = edge || !gap;
		}
	}
	if (!edge) {
		return false;
	}
	int lit = 0;
	for (int y = -2; y <= 2; y++) {
		for (int x = -2; x <= 2; x++) {
			vec2 p = uv + vec2(float(x), float(y)) * t;
			if (pal_solid(tex, p) && dot(pal_at(tex, p), PAL_LUMA) >= PAL_PROP_LINE_L) {
				lit++;
			}
		}
	}
	return lit >= PAL_PROP_LIT;
}

vec3 palette_pass(vec3 s, sampler2D tex, vec2 uv) {
	vec2 t = 1.0 / vec2(textureSize(tex, 0));
	float a1 = min(min(texture(tex, uv + vec2(t.x, 0.0)).a, texture(tex, uv - vec2(t.x, 0.0)).a), min(texture(tex, uv + vec2(0.0, t.y)).a, texture(tex, uv - vec2(0.0, t.y)).a));
	float a2 = min(min(texture(tex, uv + t).a, texture(tex, uv - t).a), min(texture(tex, uv + vec2(t.x, -t.y)).a, texture(tex, uv + vec2(-t.x, t.y)).a));
	a2 = min(a2, min(min(texture(tex, uv + vec2(2.0 * t.x, 0.0)).a, texture(tex, uv - vec2(2.0 * t.x, 0.0)).a), min(texture(tex, uv + vec2(0.0, 2.0 * t.y)).a, texture(tex, uv - vec2(0.0, 2.0 * t.y)).a)));
	float l = dot(s, PAL_LUMA);
	float hi = max(s.r, max(s.g, s.b));
	float vivid = (hi - min(s.r, min(s.g, s.b))) / max(hi, 0.01);
	vec3 out_ = mix(s, PAL_COOL * l / dot(PAL_COOL, PAL_LUMA), PAL_SHADE * smoothstep(PAL_SHADE_TOP, 0.04, l) * smoothstep(PAL_VIVID, PAL_VIVID - 0.3, vivid) * smoothstep(-0.01, 0.08, s.r - s.b)) + PAL_WARM * smoothstep(0.55, 0.9, l);
	out_ = pal_no_blue(out_);
	if (l < PAL_INK_L) {
		out_ = PAL_INK;
		if (a2 < 0.5) {
			out_ = PAL_LINE_IN;
		}
	}
	if (a1 < 0.5 && l < PAL_LINE_L) {
		out_ = PAL_LINE;
	}
	return out_;
}
