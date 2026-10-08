class_name RigStyle
extends RefCounted

## C15 3D 资产风格层：让 Weaver 资产在游戏镜头里与主视觉 / UI v2 一致。
## 主视觉要求：哑光色块、三档明暗、一圈细墨线、无写实高光。
## 做法（运行时，对 rig 的每个 MeshInstance3D）：
##   1. 材质：保留 Weaver 贴图（albedo），去掉金属度/法线带来的写实高光，roughness=1，
##      diffuse 用 TOON（三档明暗），specular 用 DISABLED；轻微提亮饱和度抵消俯视暗部。
##   2. 描边：next_pass 挂反向外扩墨线 shader（颜色 #1B1B1D，宽度按模型尺寸自适应）。

const INK := Color("#1B1B1D")
const OUTLINE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;
uniform vec4 ink : source_color = vec4(0.106, 0.106, 0.114, 1.0);
uniform float width = 0.018;
void vertex() {
	VERTEX += NORMAL * width;
}
void fragment() {
	ALBEDO = ink.rgb;
}
"""

static var _outline_shader: Shader
static var _cache: Dictionary = {}

static func _outline_material(width: float) -> ShaderMaterial:
	var key := snappedf(width, 0.0005)
	if _cache.has(key):
		return _cache[key]
	if _outline_shader == null:
		_outline_shader = Shader.new()
		_outline_shader.code = OUTLINE_SHADER
	var m := ShaderMaterial.new()
	m.shader = _outline_shader
	m.set_shader_parameter("width", key)
	m.set_shader_parameter("ink", INK)
	_cache[key] = m
	return m

## 对 root 下全部网格应用风格；height = 模型高度（米，世界尺度），决定描边宽度
static func apply(root: Node, height: float) -> int:
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
			mat.roughness = 1.0
			mat.roughness_texture = null
			mat.normal_enabled = false
			mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
			mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			mat.next_pass = _outline_material(width)
			mi.set_surface_override_material(s, mat)
			n += 1
	return n
