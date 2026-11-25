// Paints simple everyday clothes onto a Universal Base Character body (original code, MIT).
// UV2 holds two fields baked from the bind pose by FamilyFigure3D:
//   UV2.x = height on the torso scale: 0 at the hips, 1 at the neck (knees about -0.8, ankles -1.5)
//   UV2.y > 0: distance along the arm (0 at the shoulder, 1 at the wrist)
//   UV2.y <= 0: minus the distance from the body's centre line (same scale), for the torso and legs
// so sleeve, hem, neckline and trouser lengths are plain thresholds.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D body_tex : source_color, filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform vec3 skin_color = vec3(0.92, 0.76, 0.61);
uniform float skin_lum = 0.509;   // average luminance of the body texture
uniform vec4 top_color : source_color = vec4(0.24, 0.48, 0.54, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.23, 0.30, 0.42, 1.0);
uniform vec4 shoe_color : source_color = vec4(0.16, 0.15, 0.14, 1.0);
uniform float sleeve = 0.35;     // fraction of the arm covered by the top
uniform float hem = -0.08;       // where the top ends below the hips
uniform float collar = 0.90;     // neckline height at the centre of the body
uniform float trouser = -1.40;   // where the trousers end above the ankle
uniform float shoe = -1.43;      // below this: shoes
uniform float dress = 0.0;       // 1: the top continues as a skirt to `skirt`
uniform float skirt = -0.70;
uniform float tint_flash = 0.0;  // brief highlight when aimed at

varying vec2 reg;

void vertex() {
	reg = UV2;
}

float band(float x, float lo, float hi, float soft) {
	return smoothstep(lo - soft, lo + soft, x) * (1.0 - smoothstep(hi - soft, hi + soft, x));
}

void fragment() {
	float h = reg.x;
	float arm = max(reg.y, 0.0);
	float lat = max(-reg.y, 0.0);
	float is_arm = step(0.002, reg.y);
	// The neckline rises toward the shoulders, so tops cover them (no bare shoulders).
	float neck = collar + smoothstep(0.10, 0.22, lat) * 0.35 + is_arm * 0.35;
	float top_lo = mix(hem, skirt, dress);
	float top = band(h, top_lo, neck, 0.012) * (1.0 - smoothstep(sleeve - 0.015, sleeve + 0.015, arm));
	float bottom = band(h, trouser, hem + 0.02, 0.012) * (1.0 - is_arm) * (1.0 - dress);
	float shoes = (1.0 - smoothstep(shoe - 0.01, shoe + 0.01, h)) * (1.0 - is_arm);
	bottom *= (1.0 - shoes);
	top *= (1.0 - shoes);
	vec3 tex = texture(body_tex, UV).rgb;
	float l = dot(tex, vec3(0.299, 0.587, 0.114)) / skin_lum;
	vec3 skin = skin_color * 0.93 * clamp(l, 0.6, 1.08);
	// Fabric: a fine weave and darker edges at hems, cuffs and the neckline read as cloth.
	float weave = 0.95 + 0.05 * sin(UV.x * 900.0) * sin(UV.y * 900.0);
	float edge_top = 1.0 - 0.28 * (band(h, top_lo, top_lo + 0.05, 0.01) + band(h, neck - 0.04, neck, 0.01)
		+ band(arm, sleeve - 0.05, sleeve, 0.01) * is_arm);
	float edge_bot = 1.0 - 0.3 * band(h, hem - 0.06, hem + 0.02, 0.01) - 0.2 * band(h, trouser, trouser + 0.05, 0.01);
	vec3 col = skin;
	col = mix(col, top_color.rgb * weave * clamp(edge_top, 0.6, 1.0), top);
	col = mix(col, bottom_color.rgb * weave * clamp(edge_bot, 0.6, 1.0), bottom);
	col = mix(col, shoe_color.rgb, shoes);
	float cloth = clamp(top + bottom + shoes, 0.0, 1.0);
	ALBEDO = col + vec3(tint_flash * 0.12, tint_flash * 0.08, 0.0);
	NORMAL_MAP = mix(texture(normal_tex, UV).rgb, vec3(0.5, 0.5, 1.0), cloth * 0.92);
	ROUGHNESS = mix(0.55, 0.9, cloth);
	SPECULAR = mix(0.45, 0.15, cloth);
}
