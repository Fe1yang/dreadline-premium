shader_type spatial;
// The pursuer's skin. Its texture is deep red; under the orange sunset sun, saturated by the
// picture look, it came out burnt orange, and at night murky. A softer, partly desaturated skin
// with a wrapped light falloff (no hard bright/black edge) reads like it does on a grey rainy day
// in every light.
render_mode cull_disabled, diffuse_lambert_wrap, specular_schlick_ggx;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool use_normal = false;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float saturation = 0.62;
uniform float brightness = 1.12;
void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb * albedo_color.rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	ALBEDO = clamp(mix(vec3(l), c, saturation) * brightness, 0.0, 1.0);
	METALLIC = 0.0;
	ROUGHNESS = 0.94;
	SPECULAR = 0.12;
	if (use_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
		NORMAL_MAP_DEPTH = 0.8;
	}
	RIM = 0.16;
	RIM_TINT = 0.5;
}
