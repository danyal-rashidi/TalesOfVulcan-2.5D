shader_type spatial;
// Fire on the floor for the effects, worked out per screen pixel: every texel is one cell of the floor's pixel grid (x 1/32 m,
// z 1/24 m) whichever way the shape points, so it stays crisp. Colours step through c0 (hottest) to c3, with no blending.
// shape 0: a strip `size` long and `width` to each side, tapering to its tip (the fire blade); 1: a wedge `size` long, `width`
// radians to each side (the breath); 2: a ring of radius `size`, `width` thick (the dive); 3: a magic circle (the spell).
render_mode unshaded, cull_disabled, shadows_disabled;

uniform int shape = 0;
uniform vec2 origin;                      // world x, z of the shape's start or centre
uniform vec2 axis = vec2(0.0, 1.0);       // world x, z it points along
uniform float size = 1.0;
uniform float width = 0.5;
uniform float grow = 1.0;                 // 0 to 1: how much of it has formed
uniform float heat = 1.0;                 // 1 burning, 0 out
uniform float spin = 0.0;                 // radians the circle has turned
uniform vec4 c0 : source_color = vec4(1.0);
uniform vec4 c1 : source_color = vec4(1.0);
uniform vec4 c2 : source_color = vec4(1.0);
uniform vec4 c3 : source_color = vec4(1.0);

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 cell = floor(world.xz * vec2(32.0, 24.0));
	vec2 p = (cell + 0.5) / vec2(32.0, 24.0) - origin;
	float along = dot(p, axis);
	float across = dot(p, vec2(-axis.y, axis.x));
	float r = length(p);
	float f = 0.0;    // 1 at the fire's heart, 0 at its edge
	if (shape == 0) {
		float hw = width * (1.0 - 0.6 * clamp(along / size, 0.0, 1.0));
		f = (along < 0.0 || along > size * grow) ? 0.0 : 1.0 - abs(across) / hw;
	} else if (shape == 1) {
		float ang = abs(atan(across, along));
		f = (along <= 0.0 || r > size * grow) ? 0.0 : min(1.0 - ang / width, 1.0 - 0.7 * r / size);
	} else if (shape == 2) {
		f = 1.0 - abs(r - size * grow) / width;
	} else {
		float a = atan(p.y, p.x) + spin;
		float rings = max(1.0 - abs(r - size) / width, 1.0 - abs(r - size * 0.7) / width);
		float runes = step(0.55, fract(a * 8.0 / 6.2832)) * step(abs(r - size * 0.85), width * 1.2);
		f = r > size * grow + width ? 0.0 : max(rings, 0.6 * runes);
	}
	if (f <= 0.0) {
		discard;
	}
	// Tongues of fire flowing outward, redrawn 12 times a second like hand-drawn frames; the circle holds still.
	float t = floor(TIME * 12.0) / 12.0;
	vec2 q = shape == 2 ? vec2(r, atan(p.y, p.x) * size) : vec2(along, across);
	float n = 0.65 * vnoise(vec2(q.x * 5.0 - t * 9.0, q.y * 5.0)) + 0.35 * vnoise(vec2(q.x * 11.0 - t * 15.0, q.y * 11.0));
	f = f * heat + (shape == 3 ? 0.0 : (n - 0.5) * 0.8);
	if (f < 0.1) {
		discard;
	}
	ALBEDO = f > 0.75 ? c0.rgb : f > 0.5 ? c1.rgb : f > 0.28 ? c2.rgb : c3.rgb;
}
