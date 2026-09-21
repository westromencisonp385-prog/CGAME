shader_type spatial;
render_mode cull_disabled;
uniform vec4 water_color : source_color = vec4(0.17, 0.64, 0.65, 1.0);
uniform float flow_time = 0.0;
void fragment() {
	float bands = sin(UV.y * 65.0 + flow_time * 1.4 + sin(UV.x * 16.0) * 1.7);
	float sparkle = smoothstep(0.92, 1.0, bands) * 0.16;
	ALBEDO = water_color.rgb + vec3(sparkle);
	ROUGHNESS = 0.3;
	METALLIC = 0.1;
}
