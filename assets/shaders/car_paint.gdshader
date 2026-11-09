// Car paint + tinted glass for the black saloon.
//
// The model is one Tripo mesh with a single baked atlas: the windows, chrome and lamps are
// the bright neutral patches of that atlas. Reading them with a luminance/saturation test
// lets the whole car stay one material while the bright panels become dark glass.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D paint_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float gloss : hint_range(0.0, 1.0) = 0.34;   // body paint roughness
uniform float glass_gloss : hint_range(0.0, 1.0) = 0.05;

void fragment() {
	vec3 c = texture(paint_tex, UV).rgb;
	float lum = dot(c, vec3(0.2126, 0.7152, 0.0722));
	float sat = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
	// bright and near-neutral = window glass, chrome trim or a lamp lens
	float glass = smoothstep(0.40, 0.55, lum) * (1.0 - smoothstep(0.05, 0.16, sat));
	// the paint itself is very dark; lift it a touch so the panels keep their shape
	vec3 paint = c * 1.05;
	vec3 tinted = vec3(0.045, 0.058, 0.075);
	ALBEDO = mix(paint, tinted, glass);
	ROUGHNESS = mix(gloss, glass_gloss, glass);
	METALLIC = mix(0.25, 0.0, glass);
	SPECULAR = 0.62;
	// grazing-angle sheen: what makes glass read as glass rather than as plastic
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	EMISSION = vec3(0.09, 0.11, 0.14) * glass * fres * 1.6;
}
