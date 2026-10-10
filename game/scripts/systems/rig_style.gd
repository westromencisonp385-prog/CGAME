class_name RigStyle
extends RefCounted

## C15/C25 3D 资产风格层：让 Weaver 资产在游戏镜头里与主视觉 / UI v2 一致。
## 主视觉要求：哑光色块、硬边明暗、一圈细墨线、无写实高光；C25 加边缘光做轮廓分离。
## 每个 MeshInstance3D 三个 pass：
##   1. 主材质：保留 Weaver 贴图（albedo），去掉金属度/法线高光；diffuse TOON，
##      粗糙度 0.32 → 明暗交界是一条清楚的硬边（之前 1.0 会把交界拉成大渐变，物体没体积）
##   2. 边缘光 pass：加色叠加，按视线掠射角（fresnel）取轮廓，主光一侧更亮、朝下的面不亮；
##      颜色按阵营：自己人暖骨白 / 敌人番茄红 / 场景冷色弱光（RenderProfile.RIM）
##   3. 描边 pass：反向外扩墨线（颜色 #1B1B1D，宽度按模型尺寸自适应）

const INK := Color("#1B1B1D")
const TOON_ROUGHNESS := 0.32
const OUTLINE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled, fog_disabled;
uniform vec4 ink : source_color = vec4(0.106, 0.106, 0.114, 1.0);
uniform float width = 0.018;
void vertex() {
	VERTEX += NORMAL * width;
}
void fragment() {
	ALBEDO = ink.rgb;
}
"""
const RIM_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;
uniform vec4 rim_color : source_color = vec4(1.0, 0.9, 0.75, 1.0);
uniform float strength = 0.8;
uniform float power = 2.6;
uniform float push = 0.002;
uniform vec3 key_dir = vec3(0.3, 0.8, 0.5);
uniform float edge0 = 0.30;
uniform float edge1 = 0.46;
varying vec3 n_world;
void vertex() {
	VERTEX += NORMAL * push;
	n_world = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	vec3 n = normalize(NORMAL);
	float ndv = clamp(dot(n, VIEW), 0.0, 1.0);
	// 俯视 45°：顶面 ndv≈0.7 不亮；侧面/轮廓 ndv 越小越亮。用硬边带（P5 式色块光，不是柔光）
	float f = smoothstep(edge0, edge1, pow(1.0 - ndv, power * 0.4));
	vec3 nw = normalize(n_world);
	// 只在朝主光一侧亮 → 读起来是“逆光勾边”，同时标出光的方向
	float lit = smoothstep(-0.1, 0.55, dot(nw, normalize(key_dir)));
	float up = smoothstep(-0.35, 0.2, nw.y);
	ALBEDO = rim_color.rgb * (f * strength * (0.2 + 0.8 * lit) * up);
}
"""

static var _outline_shader: Shader
static var _rim_shader: Shader
static var _xray_shader: Shader
static var _cache: Dictionary = {}

## C26 剪影：只在“被别的东西挡住”的像素上画（读取不透明深度，比自己更靠近镜头超过 margin 才算挡）。
## margin 0.45m：避免角色自身部件互相遮挡时（腿在身后）也冒剪影。
const XRAY_SHADER := """
shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_back, blend_mix, shadows_disabled, fog_disabled;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec4 xray_color : source_color = vec4(1.0, 0.9, 0.7, 0.55);
uniform float margin = 0.45;
void fragment() {
	float raw = texture(depth_tex, SCREEN_UV).r;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw, 1.0);
	float scene_z = v.z / v.w;
	// 视空间 z 为负，越大越靠近镜头
	if (scene_z < VERTEX.z + margin) {
		discard;
	}
	float ndv = clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0);
	ALBEDO = xray_color.rgb;
	ALPHA = xray_color.a * mix(1.0, 0.55, ndv);
}
"""
const XRAY := {
	"hero": Color(1.0, 0.86, 0.55, 0.62),
	"foe": Color(1.0, 0.36, 0.24, 0.55),
}

static func _xray_material(rim_class: String) -> ShaderMaterial:
	var key := "x" + rim_class
	if _cache.has(key):
		return _cache[key]
	if _xray_shader == null:
		_xray_shader = Shader.new()
		_xray_shader.code = XRAY_SHADER
	var m := ShaderMaterial.new()
	m.shader = _xray_shader
	m.set_shader_parameter("xray_color", XRAY[rim_class])
	m.render_priority = 2
	_cache[key] = m
	return m

static func _outline_material(width: float) -> ShaderMaterial:
	var key := "o%.4f" % snappedf(width, 0.0005)
	if _cache.has(key):
		return _cache[key]
	if _outline_shader == null:
		_outline_shader = Shader.new()
		_outline_shader.code = OUTLINE_SHADER
	var m := ShaderMaterial.new()
	m.shader = _outline_shader
	m.set_shader_parameter("width", snappedf(width, 0.0005))
	m.set_shader_parameter("ink", INK)
	_cache[key] = m
	return m

## 边缘光 pass（next_pass 链到描边）
static func _rim_material(rim_class: String, width: float) -> ShaderMaterial:
	var key := "r%s%.4f" % [rim_class, snappedf(width, 0.0005)]
	if _cache.has(key):
		return _cache[key]
	if _rim_shader == null:
		_rim_shader = Shader.new()
		_rim_shader.code = RIM_SHADER
	var spec: Dictionary = RenderProfile.RIM.get(rim_class, RenderProfile.RIM["world"])
	var m := ShaderMaterial.new()
	m.shader = _rim_shader
	m.set_shader_parameter("rim_color", spec["color"])
	m.set_shader_parameter("strength", float(spec["strength"]))
	m.set_shader_parameter("power", float(spec["power"]))
	m.set_shader_parameter("push", snappedf(width, 0.0005) * 0.08)
	m.set_shader_parameter("key_dir", RenderProfile.key_dir())
	var outline := _outline_material(width)
	if XRAY.has(rim_class):
		var okey := "ox%s%.4f" % [rim_class, snappedf(width, 0.0005)]
		if not _cache.has(okey):
			var o2 := outline.duplicate() as ShaderMaterial
			o2.next_pass = _xray_material(rim_class)
			_cache[okey] = o2
		outline = _cache[okey]
	m.next_pass = outline
	m.render_priority = 1
	_cache[key] = m
	return m

## 对 root 下全部网格应用风格；height = 模型高度（米，世界尺度），决定描边宽度；
## rim_class = hero / foe / world（见 RenderProfile.RIM）
static func apply(root: Node, height: float, rim_class := "world") -> int:
	var world_width := clampf(height * 0.028, 0.02, 0.09)
	var n := 0
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var sc := 1.0
		if mi.is_inside_tree():
			sc = maxf(mi.global_transform.basis.get_scale().x, 1e-4)
		else:
			var t := Transform3D.IDENTITY
			var p: Node = mi
			while p != null and p != root.get_parent():
				if p is Node3D:
					t = (p as Node3D).transform * t
				p = p.get_parent()
			sc = maxf(t.basis.get_scale().x, 1e-4)
		var width := world_width / sc
		for s in mi.mesh.get_surface_count():
			var src: Material = mi.get_active_material(s)
			var mat: StandardMaterial3D
			if src is StandardMaterial3D:
				mat = (src as StandardMaterial3D).duplicate() as StandardMaterial3D
			else:
				mat = StandardMaterial3D.new()
				mat.albedo_color = Color("#2F4B5C")
			mat.metallic = 0.0
			mat.metallic_texture = null
			mat.roughness = TOON_ROUGHNESS
			mat.roughness_texture = null
			mat.normal_enabled = false
			mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
			mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			mat.next_pass = _rim_material(rim_class, width)
			mi.set_surface_override_material(s, mat)
			n += 1
	return n
