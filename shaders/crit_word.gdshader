shader_type spatial;
// Crit popup glyphs: pre-rendered gold-gradient pictures of "-", the digits and the crit word,
// laid out side by side, always facing the camera, in one even solid gold.
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
	// one even gold for the whole row (the sweeping glint lit up one glyph at a time)
	ALBEDO = c.rgb;
	ALPHA = c.a * fade;
}
