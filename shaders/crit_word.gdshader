shader_type spatial;
// Crit popup glyphs: pre-rendered gold-gradient pictures of "-", the digits and the crit word,
// laid out side by side, always facing the camera, with a glint sweeping across the whole row.
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;
uniform sampler2D word_tex : source_color, filter_linear_mipmap;
instance uniform float fade = 1.0;
instance uniform float row_w = 1.0;
varying float rx;
void vertex() {
	rx = VERTEX.x / max(row_w, 0.01) + 0.5;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec4 c = texture(word_tex, UV);
	float sweep = fract(TIME * 1.1) * 2.6 - 0.8;
	float band = smoothstep(0.12, 0.0, abs(rx - sweep - (UV.y - 0.5) * 0.25));
	ALBEDO = c.rgb + vec3(1.0, 0.96, 0.78) * band * 0.9 * step(0.5, c.a) * (c.r + c.g) * 0.5;
	ALPHA = c.a * fade;
}
