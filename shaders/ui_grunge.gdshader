shader_type canvas_item;
// Distressed "painted" look for the HUD: bright strokes (text, icons, outlines) get
// worn-through flecks and slight tone variation; dark panels are left untouched.

uniform sampler2D grunge : repeat_enable, filter_linear;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float tile_px = 300.0;

void fragment() {
	vec4 c = COLOR;
	float lum = max(c.r, max(c.g, c.b));
	float bright = smoothstep(0.30, 0.70, lum) * strength;
	float g = texture(grunge, FRAGCOORD.xy / tile_px).r;
	float worn = smoothstep(0.33, 0.43, g);
	c.a *= mix(1.0, worn, bright);
	c.rgb *= mix(1.0, 0.84 + 0.16 * smoothstep(0.35, 0.75, g), bright);
	COLOR = c;
}
