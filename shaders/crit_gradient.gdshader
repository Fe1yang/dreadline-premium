shader_type canvas_item;
// Crit word fill.
//   0 = brushed metal gold (default)   1 = rainbow   2 = pale rainbow
// Metal is faked with a hard dark rim, a blown-out specular band and a dark reflection band, which
// keeps the contrast at small sizes where a soft gradient reads as flat yellow.
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
		g = hsv(t * 0.85, 0.92, 1.0);
	} else if (mode == 2) {
		g = mix(hsv(t * 0.85, 0.50, 1.0), vec3(1.0), 0.45);
	} else {
		vec3 dark   = vec3(0.30, 0.17, 0.01);
		vec3 white  = vec3(1.00, 0.99, 0.90);
		vec3 gold   = vec3(1.00, 0.78, 0.18);
		vec3 amber  = vec3(0.72, 0.42, 0.03);
		vec3 bounce = vec3(1.00, 0.88, 0.42);
		if (t < 0.08) {
			g = mix(dark, white, t / 0.08);
		} else if (t < 0.26) {
			g = mix(white, gold, (t - 0.08) / 0.18);
		} else if (t < 0.52) {
			g = mix(gold, amber, (t - 0.26) / 0.26);
		} else if (t < 0.74) {
			g = mix(amber, gold, (t - 0.52) / 0.22);
		} else if (t < 0.90) {
			g = mix(gold, bounce, (t - 0.74) / 0.16);
		} else {
			g = mix(bounce, dark, (t - 0.90) / 0.10);
		}
		// a narrow highlight running across the stroke, like a lit edge
		float sheen = clamp(1.0 - abs(fract(UV.x * 0.9 + t * 0.5) - 0.30) * 3.2, 0.0, 1.0);
		g = mix(g, white, sheen * 0.55);
	}
	COLOR.rgb = g;
}
