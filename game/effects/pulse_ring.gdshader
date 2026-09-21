shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.45, 0.65, 1.0, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.6;
uniform float phase = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float radius = length(p);
	float edge = exp(-pow((radius - 0.80) * 40.0, 2.0));
	float sweep = 0.45 + 0.55 * pow(abs(sin(atan(p.y, p.x) * 5.0 + phase)), 3.0);
	float inner = exp(-pow((radius - 0.48) * 75.0, 2.0)) * 0.16;
	ALBEDO = tint.rgb * 1.3;
	ALPHA = (edge * sweep + inner) * strength * tint.a;
}
