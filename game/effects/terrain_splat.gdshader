shader_type spatial;
render_mode diffuse_toon, specular_disabled;

// RECLAIMER 地表：四层贴图按世界坐标遮罩混合（草地 / 泥土 / 土路 / 河床）。
// 遮罩来自关卡布局（中央工地椭圆、两块草甸、河道）+ 值噪声抖动边缘，不需要手绘 splat 图。
uniform sampler2D tex_grass : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_dirt : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_path : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_bed : source_color, filter_linear_mipmap, repeat_enable;
uniform float tile = 0.16;            // 每米多少个贴图周期
uniform vec2 yard_center = vec2(0.0, 0.5);
uniform vec2 yard_radius = vec2(9.5, 13.0);
uniform vec4 meadow_a = vec4(-7.0, -4.5, 6.4, 6.8);  // xz 中心 + 半径
uniform vec4 meadow_b = vec4(6.8, -7.2, 5.2, 4.5);
uniform vec2 river_x = vec2(9.0, 5.3);  // 河道中心 x、半宽
uniform float edge_grass = 13.5;       // |x| 超过这个开始变草地
uniform vec3 tint = vec3(1.0);

varying vec3 world_pos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) { return vnoise(p) * 0.6 + vnoise(p * 2.3) * 0.3 + vnoise(p * 5.1) * 0.1; }

// 两个尺度、错开旋转的采样，掩盖 AI 贴图接缝与重复感
vec3 sample_tex(sampler2D t, vec2 xz) {
	vec2 uv = xz * tile;
	mat2 r = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8));
	vec3 a = texture(t, uv).rgb;
	vec3 b = texture(t, r * uv * 0.47 + 0.31).rgb;
	return mix(a, b, 0.35);
}

float ellipse(vec2 p, vec2 c, vec2 r) { vec2 d = (p - c) / r; return dot(d, d); }

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float n = fbm(p * 0.35);
	float wobble = (n - 0.5) * 0.55;
	float path_w = 1.0 - smoothstep(0.75, 1.05, ellipse(p, yard_center, yard_radius) + wobble);
	float grass_w = max(1.0 - smoothstep(0.7, 1.0, ellipse(p, meadow_a.xy, meadow_a.zw) + wobble),
						1.0 - smoothstep(0.7, 1.0, ellipse(p, meadow_b.xy, meadow_b.zw) + wobble));
	grass_w = max(grass_w, smoothstep(edge_grass - 1.5, edge_grass + 1.0, abs(p.x) + wobble * 3.0));
	grass_w = max(grass_w, smoothstep(12.0, 14.5, abs(p.y) + wobble * 3.0));
	float bed_w = 1.0 - smoothstep(river_x.y - 1.2, river_x.y + 0.4, abs(p.x - river_x.x) + wobble * 1.6);
	vec3 col = sample_tex(tex_dirt, p);
	col = mix(col, sample_tex(tex_path, p), path_w);
	col = mix(col, sample_tex(tex_grass, p), grass_w * (1.0 - bed_w));
	col = mix(col, sample_tex(tex_bed, p), bed_w);
	// 低频明暗起伏，避免大面积平涂
	col *= 0.9 + 0.2 * fbm(p * 0.08 + 7.0);
	ALBEDO = col * tint;
	ROUGHNESS = 1.0;
}
