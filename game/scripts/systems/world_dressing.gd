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
## C25：地表比角色低一档明度（前景 / 背景分离，角色更“跳”）
const BIOME_TINT := {"river": Color(0.86, 0.86, 0.88), "desert": Color(0.9, 0.85, 0.79), "swamp": Color(0.76, 0.83, 0.77)}

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

## C26 世界尺度规则（对照 Wanderburg：正交 45° 俯视里，玩家载具 / 敌人是画面主体，
## 树、墙、杆这类景物都比载具矮或相当；高物件只出现在远离镜头的一侧）。
## 值 = 该资产在游戏里的目标高度（米）。玩家车约 1.2m 高，敌人 0.35~0.7m。
const WORLD_HEIGHT := {
	"prop_tree_round": 1.25, "prop_tree_poplar": 1.45, "prop_bush": 0.45,
	"prop_broken_wall": 0.5, "prop_fence": 0.6, "prop_rock_large": 0.65, "prop_rock_cluster": 0.3,
	"prop_lamp_post": 0.95, "prop_pennant": 0.9, "prop_sign": 0.6, "prop_stone_arch": 0.95,
	"prop_reeds": 0.45, "prop_grass_tuft": 0.28, "prop_flowers": 0.22,
	"prop_bridge_stub": 0.6, "prop_pipe": 0.5, "prop_roadblock": 0.55, "prop_barrier": 0.45,
	"wind_turbine": 1.6, "mountain_air_pump": 1.0, "repair_pump_c04": 0.9, "camp_board": 0.85,
}

## 这些只压高度（占地要保持，否则边界 / 路障会出缝）；其余整体等比缩小，保持造型比例
const SQUASH_ONLY := ["prop_broken_wall", "prop_fence", "prop_bridge_stub", "prop_pipe", "prop_roadblock", "prop_barrier"]

static var _native_h: Dictionary = {}

## 资产在游戏里的原生高度（米，已含 PROP_FIT）：取已缓存的可见网格包围盒
static func native_height(slot: String) -> float:
	if _native_h.has(slot):
		return _native_h[slot]
	var lo := INF
	var hi := -INF
	var fit := Transform3D(_fit_basis(slot), Vector3.ZERO)
	for pair in _meshes(slot):
		var b: AABB = fit * (pair[1] as Transform3D) * (pair[0] as Mesh).get_aabb()
		lo = minf(lo, b.position.y)
		hi = maxf(hi, b.end.y)
	var h := hi - lo if hi > lo else 0.0
	_native_h[slot] = h
	return h

## 世界高度规则的缩放倍率（<=1，只缩不放）
static func height_fix(slot: String, measured := -1.0) -> float:
	if not WORLD_HEIGHT.has(slot):
		return 1.0
	var native := measured if measured > 0.0 else native_height(slot)
	if native <= 0.01:
		return 1.0
	return clampf(float(WORLD_HEIGHT[slot]) / native, 0.2, 1.0)

static func height_scale(slot: String, measured := -1.0) -> Vector3:
	var k := height_fix(slot, measured)
	return Vector3(1.0, k, 1.0) if SQUASH_ONLY.has(slot) else Vector3.ONE * k

static func _fit_basis(slot: String) -> Basis:
	if not PROP_FIT.has(slot):
		return Basis.IDENTITY
	var f: Dictionary = PROP_FIT[slot]
	return Basis(Vector3.UP, deg_to_rad(float(f.get("yaw", 0.0)))).scaled(f.get("scale", Vector3.ONE))

## 把已挂好 rig 的 fit 节点按世界高度规则缩放（实测可见网格高度，最准）
static func apply_world_height(fit: Node3D, slot: String) -> void:
	if not WORLD_HEIGHT.has(slot) or not fit.is_inside_tree():
		return
	var lo := INF
	var hi := -INF
	for n in fit.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var b := mi.global_transform * mi.get_aabb()
		lo = minf(lo, b.position.y)
		hi = maxf(hi, b.end.y)
	if hi <= lo:
		return
	var parent_sy := absf(fit.get_parent_node_3d().global_transform.basis.get_scale().y) if fit.get_parent_node_3d() else 1.0
	var h := (hi - lo) / maxf(parent_sy, 0.001)
	var k := height_scale(slot, h)
	fit.transform = Transform3D(fit.transform.basis.scaled(k), fit.transform.origin)

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
	apply_world_height(fit, slot)
	return holder

static func _visible_in(n: Node, stop: Node) -> bool:
	var p: Node = n
	while p != null:
		if p is Node3D and not (p as Node3D).visible:
			return false
		if p == stop:
			break
		p = p.get_parent()
	return true

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
				# 隐藏的网格（LOD / 碰撞代理 / 备用部件）不进散布，否则 MultiMesh 会把它们画出来
				if mi.mesh == null or not _visible_in(mi, model):
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
				t = model.transform * t
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
		var local: Transform3D = Transform3D(_fit_basis(slot).scaled(height_scale(slot)), Vector3.ZERO) * (pair[1] as Transform3D)
		for i in transforms.size():
			mm.set_instance_transform(i, (transforms[i] as Transform3D) * local)
		var mmi := MultiMeshInstance3D.new()
		mmi.set_meta("slot", slot)
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
