class_name ProceduralVisuals
extends RefCounted

## C8 资产化共享几何库：运行时与烘焙器（tools/bake_assets.gd）共用同一套构建函数。
## 运行时优先加载 res://assets/generated/props/ 下已烘焙的 .tscn 资产；
## 资产缺失时才用同源代码兜底重建（烘焙器无头运行也走同一代码路径）。
## 这样保证：磁盘资产 = 运行时可见 = 烘焙产物，三者同源。

const PROPS_DIR := "res://assets/generated/props"
const AUDIO_DIR := "res://assets/generated/audio"

## 优先加载烘焙资产；缺失时调用 fallback_builder 现场重建
## 烘焙场景名 -> 部件化正式模型槽位（Weaver v3，优先级最高）
const RIG_FOR_SCENE := {
	"summon_turret.tscn": "summon_turret", "summon_emp.tscn": "summon_emp", "summon_camp.tscn": "summon_camp",
	"biome_key_desert.tscn": "biome_key", "biome_key_swamp.tscn": "biome_key", "boss_crown.tscn": "boss_crown",
}

static func load_visual(scene_file: String, fallback_builder: Callable) -> Node3D:
	var slot := str(RIG_FOR_SCENE.get(scene_file, ""))
	if not slot.is_empty() and ProceduralRig.has_rig(slot):
		var holder := Node3D.new()
		holder.set_meta("authored_slot", slot)
		if ProceduralRig.attach(holder, slot) != null:
			return holder
		holder.free()
	var scene_path := "%s/%s" % [PROPS_DIR, scene_file]
	if ResourceLoader.exists(scene_path):
		var packed := load(scene_path) as PackedScene
		if packed != null:
			var instanced := packed.instantiate() as Node3D
			if instanced != null:
				return instanced
	return fallback_builder.call() as Node3D

## 为 pack() 递归设置 owner（根节点本身不设）
static func _assign_owner(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		_assign_owner(child, owner)

static func pack_to_scene(node: Node3D) -> PackedScene:
	_assign_owner(node, node)
	var packed := PackedScene.new()
	packed.pack(node)
	return packed

static func _material(color: Color, roughness: float, metallic := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	return mat

static func _mesh(mesh: Mesh, material: StandardMaterial3D, node_name: String, pos: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	return instance

## 召唤物几何（炮塔/营地：底盘+炮管；EMP：底盘+悬浮环）
static func build_summon(color: Color, is_ring: bool, label_text: String) -> Node3D:
	var root := Node3D.new()
	var base := CylinderMesh.new()
	base.top_radius = 0.42
	base.bottom_radius = 0.58
	base.height = 0.3
	base.radial_segments = 8
	root.add_child(_mesh(base, _material(color.darkened(0.25), 0.6), "SummonBase", Vector3(0, 0.15, 0)))
	if is_ring:
		var ring := TorusMesh.new()
		ring.inner_radius = 0.7
		ring.outer_radius = 0.95
		root.add_child(_mesh(ring, _material(color.darkened(0.25), 0.6), "SummonRing", Vector3(0, 0.35, 0)))
	else:
		var barrel := BoxMesh.new()
		barrel.size = Vector3(0.16, 0.16, 0.9)
		root.add_child(_mesh(barrel, _material(color, 0.55), "SummonBarrel", Vector3(0, 0.5, -0.3)))
	var label := Label3D.new()
	label.name = "SummonLabel"
	label.text = label_text
	label.font_size = 40
	label.pixel_size = 0.01
	label.outline_size = 4
	label.position = Vector3(0, 1.15, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	root.add_child(label)
	return root

## 群系锁门几何（仅视觉；碰撞由 BiomeGate 代码构建以便动态禁用）
static func build_gate(bar_color: Color, title: String) -> Node3D:
	var root := Node3D.new()
	var frame_mat := _material(bar_color.darkened(0.45), 0.7)
	var frame := BoxMesh.new()
	frame.size = Vector3(4.4, 2.4, 0.5)
	root.add_child(_mesh(frame, frame_mat, "GateFrame", Vector3(0, 1.2, 0)))
	for x in [-1.85, 1.85]:
		var post := BoxMesh.new()
		post.size = Vector3(0.4, 2.8, 0.55)
		root.add_child(_mesh(post, frame_mat, "GatePost", Vector3(x, 1.4, 0)))
	var plate := BoxMesh.new()
	plate.size = Vector3(1.5, 0.7, 0.12)
	root.add_child(_mesh(plate, _material(bar_color, 0.5), "GatePlate", Vector3(0, 1.75, -0.32)))
	var label := Label3D.new()
	label.name = "GateLabel"
	label.text = title
	label.font_size = 52
	label.pixel_size = 0.011
	label.outline_size = 5
	label.position = Vector3(0, 3.15, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	root.add_child(label)
	return root

## 群系钥匙几何（杆+环+双齿+光柱）
static func build_key(color: Color) -> Node3D:
	var root := Node3D.new()
	var mat := _material(color, 0.35, 0.55)
	var shaft := BoxMesh.new()
	shaft.size = Vector3(0.16, 0.16, 0.85)
	root.add_child(_mesh(shaft, mat, "KeyShaft", Vector3(0, 0.9, 0)))
	var ring := TorusMesh.new()
	ring.inner_radius = 0.2
	ring.outer_radius = 0.34
	root.add_child(_mesh(ring, mat, "KeyRing", Vector3(0, 1.28, 0)))
	for x in [-0.2, 0.2]:
		var tooth := BoxMesh.new()
		tooth.size = Vector3(0.09, 0.22, 0.09)
		root.add_child(_mesh(tooth, mat, "KeyTooth", Vector3(x, 0.68, 0)))
	var beam := CylinderMesh.new()
	beam.top_radius = 0.34
	beam.bottom_radius = 0.5
	beam.height = 2.2
	beam.radial_segments = 10
	var beam_mat := _material(Color(color, 0.16), 1.0)
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	root.add_child(_mesh(beam, beam_mat, "KeyBeam", Vector3(0, 1.1, 0)))
	return root

## Boss 王冠几何（底座+四尖刺，y 为相对头顶偏移；BossEntity 挂载时抬到 height_for_kind()）
static func build_crown() -> Node3D:
	var root := Node3D.new()
	var base := CylinderMesh.new()
	base.top_radius = 0.34
	base.bottom_radius = 0.34
	base.height = 0.14
	root.add_child(_mesh(base, _material(Color("#f2c85c"), 0.5), "CrownBase", Vector3(0, 0.28, 0)))
	for index in range(4):
		var spike := CylinderMesh.new()
		spike.top_radius = 0.07
		spike.bottom_radius = 0.07
		spike.height = 0.3
		var spike_node := _mesh(spike, _material(Color("#df604e"), 0.5), "CrownSpike%d" % index, Vector3((float(index) - 1.5) * 0.22, 0.5, 0))
		spike_node.rotation_degrees.z = (float(index) - 1.5) * 10.0
		root.add_child(spike_node)
	return root
