shader_type canvas_item;
// Fill for the crit word. Three palettes, picked with `mode`:
//   0 = gold (default)   1 = rainbow   2 = pale rainbow
// `end_y` is the height in canvas units that the gradient spans.
uniform int mode = 0;
uniform float end_y = 100.0;

varying float vy;

vec3 hsv(float h, float s, float v) {
	vec3 k = abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0);
	return v - v * s * clamp(k - 1.0, 0.0, 1.0);
}

void vertex() {
	vy = VERTEX.y;
}

void fragment() {
	float t = clamp(vy / max(end_y, 1.0), 0.0, 1.0);
	vec3 g;
	if (mode == 1) {
		// full-saturation rainbow, top to bottom
		g = hsv(t * 0.85, 0.92, 1.0);
	} else if (mode == 2) {
		// pale rainbow: same sweep, washed out so it reads on dark ground
		g = mix(hsv(t * 0.85, 0.55, 1.0), vec3(1.0), 0.35);
	} else {
		// gold: light highlight at the top edge, warm body, deep amber at the bottom
		vec3 a = vec3(1.00, 0.99, 0.86);
		vec3 b = vec3(1.00, 0.85, 0.35);
		vec3 c = vec3(0.91, 0.55, 0.06);
		g = t < 0.45 ? mix(a, b, t / 0.45) : mix(b, c, (t - 0.45) / 0.55);
	}
	COLOR.rgb = g;
}
