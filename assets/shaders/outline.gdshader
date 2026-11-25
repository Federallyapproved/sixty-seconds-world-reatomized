// Inverted-hull outline drawn as a material overlay (original code, MIT like the rest of the repo).
// mode 0: push the hull out along the normals (smooth meshes such as the family).
// mode 1: scale the hull about `center` (flat-shaded props, where normals would split at corners).
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.86, 0.55, 1.0);
uniform float width = 0.012;
uniform int mode = 1;
uniform vec3 center = vec3(0.0, 0.15, 0.0);
uniform float pulse = 0.0;

void vertex() {
	float w = width * (1.0 + pulse * 0.35 * sin(TIME * 6.0));
	if (mode == 0) {
		VERTEX += NORMAL * w;
	} else {
		vec3 d = VERTEX - center;
		float len = max(length(d), 0.001);
		VERTEX = center + d * (1.0 + w / len);
	}
}

void fragment() {
	ALBEDO = color.rgb;
}
