class_name WorldDressing
extends RefCounted

## 场景美术层：地表 splat + 正式道具摆放 + 大量散布（MultiMesh）。
## 所有资产来自 game/assets/models/rigged/<slot>_rig.glb（Weaver v3）与 game/assets/textures/ground/*.png（TiMi）。
## 资产缺失时返回 null / false，宿主（ArenaVisual）回落旧几何，保证任何时刻都能跑。

const TERRAIN_SHADER := preload("res://effects/terrain_splat.gdshader")
const TEX_DIR := "res://assets/textures/ground"

## 群系 -> 地表四层（草 / 泥 / 路 / 河床）
const BIOME_LAYERS := {
	"river": ["grass", "dirt", "path", "riverbed"],
	"desert": ["sand", "sand", "path", "dirt"],
	"swamp": ["mud", "mud", "grass", "riverbed"],
}
const BIOME_TINT := {"river": Color(1, 1, 1), "desert": Color(1.04, 0.98, 0.9), "swamp": Color(0.86, 0.95, 0.86)}

static var _tex_cache: Dictionary = {}
static var _mesh_cache: Dictionary = {}   # slot -> Array[[Mesh, Transform3D]]

static func texture(name: String) -> Texture2D:
	if _tex_cache.has(name):
		return _tex_cache[name]
	var path := "%s/%s.png" % [TEX_DIR, name]
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path)
	elif FileAccess.file_exists(path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null:
			img.generate_mipmaps()
			t = ImageTexture.create_from_image(img)
	_tex_cache[name] = t
	return t

static func has_terrain() -> bool:
	for n in BIOME_LAYERS["river"]:
		if texture(n) == null:
			return false
	return true

## 地表网格（视觉），碰撞仍由宿主的隐形地面盒负责
static func build_terrain(parent: Node3D, size: Vector2) -> MeshInstance3D:
	if not has_terrain():
		return null
	var plane := PlaneMesh.new()
	plane.size = size
	plane.subdivide_width = 8
	plane.subdivide_depth = 8
	var mi := MeshInstance3D.new()
	mi.name = "TerrainSplat"
	mi.mesh = plane
	mi.position.y = 0.0
	var mat := ShaderMaterial.new()
	mat.shader = TERRAIN_SHADER
	mi.material_override = mat
	parent.add_child(mi)
	apply_biome(mi, "river")
	return mi

static func apply_biome(terrain: MeshInstance3D, biome: String) -> void:
	if terrain == null:
		return
	var mat := terrain.material_override as ShaderMaterial
	var layers: Array = BIOME_LAYERS.get(biome, BIOME_LAYERS["river"])
	var keys := ["tex_grass", "tex_dirt", "tex_path", "tex_bed"]
	for i in 4:
		var t := texture(str(layers[i]))
		if t == null:
			t = texture(str(BIOME_LAYERS["river"][i]))
		mat.set_shader_parameter(keys[i], t)
	var c: Color = BIOME_TINT.get(biome, Color(1, 1, 1))
	mat.set_shader_parameter("tint", Vector3(c.r, c.g, c.b))

## 单资产校正：Weaver 资产按最大边归一，个别细长件需要转向（长轴对齐 X）或压低高度（Vector3 为 x/高/z 倍率）
const PROP_FIT := {
	"prop_bridge": {"yaw": 90.0, "scale": Vector3(1.0, 0.3, 0.45)},
	"prop_pipe": {"yaw": 0.0, "scale": Vector3(1.0, 0.45, 0.8)},
	"prop_roadblock": {"yaw": 0.0, "scale": Vector3(0.55, 0.42, 0.55)},
	"prop_sign": {"yaw": 90.0, "scale": Vector3.ONE},
	"prop_broken_wall": {"yaw": 0.0, "scale": Vector3(1.0, 0.8, 1.0)},
}

static func _fit_basis(slot: String) -> Basis:
	if not PROP_FIT.has(slot):
		return Basis.IDENTITY
	var f: Dictionary = PROP_FIT[slot]
	return Basis(Vector3.UP, deg_to_rad(float(f.get("yaw", 0.0)))).scaled(f.get("scale", Vector3.ONE))

## 单个道具（带风格层）。scale 为相对资产标准尺寸的倍率。
static func prop(parent: Node3D, slot: String, at: Vector3, yaw_deg := 0.0, scale := 1.0) -> Node3D:
	if not ProceduralRig.has_rig(slot):
		return null
	var holder := Node3D.new()
	holder.name = "Prop_" + slot
	holder.position = at
	holder.rotation_degrees.y = yaw_deg
	holder.scale = Vector3.ONE * scale
	parent.add_child(holder)
	var fit := Node3D.new()
	fit.name = "Fit"
	fit.transform = Transform3D(_fit_basis(slot), Vector3.ZERO)
	holder.add_child(fit)
	var rig := ProceduralRig.attach(fit, slot)
	if rig == null:
		holder.queue_free()
		return null
	rig.set_meta("static_prop", true)
	return holder

## 已风格化的网格清单（从资产实例上取一次，缓存）
static func _meshes(slot: String) -> Array:
	if _mesh_cache.has(slot):
		return _mesh_cache[slot]
	var out: Array = []
	if ProceduralRig.has_rig(slot):
		var entry: Dictionary = ProceduralRig.load_manifest()[slot]
		var packed := load(str(entry["file"])) as PackedScene
		if packed != null:
			var model := packed.instantiate() as Node3D
			var dims: Array = entry.get("dims", [1.0, 1.0, 1.0])
			RigStyle.apply(model, float(dims[2]) if dims.size() > 2 else 1.0)
			for node in model.find_children("*", "MeshInstance3D", true, false):
				var mi := node as MeshInstance3D
				if mi.mesh == null:
					continue
				var mesh := mi.mesh.duplicate() as Mesh
				if mesh is ArrayMesh:
					for s in mesh.get_surface_count():
						var m := mi.get_surface_override_material(s)
						if m != null:
							(mesh as ArrayMesh).surface_set_material(s, m)
				var t := Transform3D.IDENTITY
				var p: Node = mi
				while p != null and p != model:
					if p is Node3D:
						t = (p as Node3D).transform * t
					p = p.get_parent()
				out.append([mesh, t])
			model.free()
	_mesh_cache[slot] = out
	return out

## 轻量实例：复用缓存的已风格化网格，不重新实例化 GLB 场景（掉落物等高频对象用）
static func instance_meshes(parent: Node3D, slot: String) -> Node3D:
	var meshes := _meshes(slot)
	if meshes.is_empty():
		return null
	var root := Node3D.new()
	root.name = "Mesh_" + slot
	for pair in meshes:
		var mi := MeshInstance3D.new()
		mi.mesh = pair[0]
		mi.transform = pair[1]
		root.add_child(mi)
	parent.add_child(root)
	return root

## 大量散布：每个部件网格一个 MultiMesh。transforms 为世界（parent 局部）变换。
static func scatter(parent: Node3D, slot: String, transforms: Array) -> bool:
	var meshes := _meshes(slot)
	if meshes.is_empty() or transforms.is_empty():
		return false
	var group := Node3D.new()
	group.name = "Scatter_" + slot
	parent.add_child(group)
	for pair in meshes:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = pair[0]
		mm.instance_count = transforms.size()
		var local: Transform3D = Transform3D(_fit_basis(slot), Vector3.ZERO) * (pair[1] as Transform3D)
		for i in transforms.size():
			mm.set_instance_transform(i, (transforms[i] as Transform3D) * local)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		group.add_child(mmi)
	return true

## 在矩形区域内按规则随机生成变换；reject(Vector2)->bool 返回 true 表示该点不放
static func scatter_points(rng: RandomNumberGenerator, count: int, area: Rect2, scale_range: Vector2, reject: Callable) -> Array:
	var out: Array = []
	var tries := 0
	while out.size() < count and tries < count * 12:
		tries += 1
		var p := Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
		if reject.is_valid() and bool(reject.call(p)):
			continue
		var s := rng.randf_range(scale_range.x, scale_range.y)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s)
		out.append(Transform3D(basis, Vector3(p.x, 0.0, p.y)))
	return out
