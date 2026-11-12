shader_type canvas_item;
// Fill of the crit word: pale gold at the top, rich gold in the middle, deep amber at the bottom.
uniform float top_y = 20.0;
uniform float bottom_y = 100.0;
varying float vy;
void vertex() { vy = VERTEX.y; }
void fragment() {
	float t = clamp((vy - top_y) / (bottom_y - top_y), 0.0, 1.0);
	vec3 a = vec3(1.0, 0.98, 0.80);
	vec3 b = vec3(1.0, 0.80, 0.22);
	vec3 c = vec3(0.86, 0.42, 0.04);
	vec3 g = t < 0.5 ? mix(a, b, t * 2.0) : mix(b, c, (t - 0.5) * 2.0);
	COLOR.rgb = g;
}
