// Tints Universal Base Character hair (grey textures made for tinting) to a family member's colour.
shader_type spatial;
render_mode diffuse_burley, cull_disabled;

uniform sampler2D hair_tex : source_color, filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform vec4 hair_color : source_color = vec4(0.29, 0.18, 0.11, 1.0);
uniform float avg_lum = 0.56;

void fragment() {
	vec4 t = texture(hair_tex, UV);
	float l = dot(t.rgb, vec3(0.299, 0.587, 0.114)) / avg_lum;
	ALBEDO = hair_color.rgb * mix(0.55, 1.25, clamp(l * 0.5, 0.0, 1.0));
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALPHA = t.a;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	ROUGHNESS = 0.7;
	SPECULAR = 0.35;
}
