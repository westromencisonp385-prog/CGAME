shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
uniform vec4 water_color : source_color = vec4(0.17, 0.64, 0.65, 1.0);
uniform float flow_time = 0.0;
void fragment() {
	// Two authored scales keep the repaired channel readable at the gameplay
	// camera: broad current bands plus short foam glints. This remains a cheap
	// fragment-only cue on the Mobile renderer.
	float current = sin(UV.y * 42.0 + flow_time * 1.6 + sin(UV.x * 11.0) * 1.4);
	float ripple = sin(UV.y * 112.0 - flow_time * 2.7 + UV.x * 19.0);
	float foam = smoothstep(0.84, 1.0, current) * 0.11;
	float glint = smoothstep(0.94, 1.0, ripple) * 0.08;
	float bank_fade = smoothstep(0.02, 0.16, UV.x) * smoothstep(0.02, 0.16, 1.0 - UV.x);
	ALBEDO = water_color.rgb + vec3(foam + glint) * (0.72 + bank_fade * 0.28);
	ROUGHNESS = 0.27;
	METALLIC = 0.08;
}
