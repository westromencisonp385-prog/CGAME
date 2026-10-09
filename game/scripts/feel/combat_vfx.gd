class_name CombatVfx
extends RefCounted

## 近战 / 投掷的表现层（只表现，不判定）。全部挂在 GameFeel.world_parent 下，时间不受顿帧影响。
##   swipe()      咬合扫弧：扇形月牙沿方向扫过，前缘亮、后缘透明；连击交替方向，收尾更大更红
##   spark()      命中火花：放射状短线向外炸开再收缩
##   projectile() 抛物线投掷物：飞行中自旋，落地回调
##   dust()       落空 / 落地扬尘小环

const BONE := Color("#EFE3C8")
const RED := Color("#D9412B")
const OCHRE := Color("#E3A52B")

static func _parent() -> Node3D:
	if GameFeel.instance == null or GameFeel.instance.world_parent == null or not is_instance_valid(GameFeel.instance.world_parent):
		return null
	return GameFeel.instance.world_parent

static func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = true
	m.render_priority = 3
	m.albedo_color = color
	return m

## 扇形月牙网格：角度 [-half, +half]，从后缘（透明）到前缘（不透明）；内外半径
static func _crescent(inner: float, outer: float, half_deg: float, segments := 18) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := deg_to_rad(half_deg)
	for i in segments:
		var a0 := lerpf(-half, half, float(i) / segments)
		var a1 := lerpf(-half, half, float(i + 1) / segments)
		var t0 := float(i) / segments
		var t1 := float(i + 1) / segments
		# 月牙：中段最厚
		var w0 := sin(t0 * PI) * 0.75 + 0.25
		var w1 := sin(t1 * PI) * 0.75 + 0.25
		var in0 := lerpf(outer, inner, w0)
		var in1 := lerpf(outer, inner, w1)
		var c0 := Color(1, 1, 1, pow(t0, 1.6))
		var c1 := Color(1, 1, 1, pow(t1, 1.6))
		var p_o0 := Vector3(sin(a0), 0, -cos(a0)) * outer
		var p_o1 := Vector3(sin(a1), 0, -cos(a1)) * outer
		var p_i0 := Vector3(sin(a0), 0, -cos(a0)) * in0
		var p_i1 := Vector3(sin(a1), 0, -cos(a1)) * in1
		for pc in [[p_i0, c0], [p_o0, c0], [p_o1, c1], [p_i0, c0], [p_o1, c1], [p_i1, c1]]:
			st.set_color(pc[1])
			st.add_vertex(pc[0])
	return st.commit()

## origin 地面点；dir 平面方向；reach 半径；step 0/1/2（2 = 收尾）
static func swipe(origin: Vector3, dir: Vector3, reach: float, step: int) -> void:
	var parent := _parent()
	if parent == null or dir.length() < 0.01:
		return
	var heavy := step >= 2
	var mirror := -1.0 if step == 1 else 1.0
	var mi := MeshInstance3D.new()
	mi.name = "VfxBiteSwipe"
	mi.mesh = _crescent(reach * 0.35, reach * (1.15 if heavy else 1.0), 62.0 if heavy else 52.0)
	var mat := _mat(RED if heavy else BONE)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi, true)
	var yaw := atan2(-dir.x, -dir.z)
	mi.global_position = Vector3(origin.x, 0.25, origin.z)
	# 镜像：连击第二下从另一侧扫
	mi.scale = Vector3(mirror, 1, 1) * 0.75
	mi.rotation.y = yaw - mirror * deg_to_rad(38.0)
	var tw := mi.create_tween()
	tw.set_ignore_time_scale(true)
	tw.set_parallel(true)
	var sweep := 0.07 if not heavy else 0.09
	tw.tween_property(mi, "rotation:y", yaw + mirror * deg_to_rad(10.0), sweep).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "scale", Vector3(mirror, 1, 1) * (1.12 if heavy else 1.0), sweep).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.16).set_delay(sweep * 0.7)
	tw.chain().tween_callback(mi.queue_free)
	if heavy:
		# 收尾再叠一层骨白内弧
		var inner := MeshInstance3D.new()
		inner.mesh = _crescent(reach * 0.3, reach * 0.8, 48.0)
		var m2 := _mat(BONE)
		inner.material_override = m2
		inner.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.add_child(inner)
		inner.position.y = 0.02

## 放射火花
static func spark(at: Vector3, color := BONE, size := 1.0, count := 7) -> void:
	var parent := _parent()
	if parent == null:
		return
	var root := Node3D.new()
	root.name = "VfxSpark"
	parent.add_child(root, true)
	root.global_position = at + Vector3(0, 0.9, 0)
	var mat := _mat(color)
	mat.vertex_color_use_as_albedo = false
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.09, 0.09, 1.0)
	var off := randf() * TAU
	for i in count:
		var ray := MeshInstance3D.new()
		ray.mesh = mesh
		ray.material_override = mat
		ray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := off + TAU * float(i) / count + randf_range(-0.2, 0.2)
		var d := Vector3(cos(a), randf_range(-0.15, 0.35), sin(a)).normalized()
		root.add_child(ray, true)
		ray.look_at_from_position(Vector3.ZERO, d, Vector3.UP if absf(d.y) < 0.95 else Vector3.FORWARD)
		ray.position = d * 0.2 * size
		ray.scale = Vector3(1, 1, 0.2) * size
		var tw := ray.create_tween()
		tw.set_ignore_time_scale(true)
		tw.set_parallel(true)
		var len := randf_range(0.9, 1.5) * size
		tw.tween_property(ray, "position", d * len, 0.13).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(ray, "scale", Vector3(1, 1, len * 0.9), 0.06)
		tw.chain().tween_property(ray, "scale", Vector3(0.2, 0.2, 0.05), 0.09)
	# 中心白闪
	var core := MeshInstance3D.new()
	core.name = "VfxSparkCore"
	var sm := SphereMesh.new()
	sm.radius = 0.35 * size
	sm.height = 0.7 * size
	sm.radial_segments = 12
	sm.rings = 6
	core.mesh = sm
	var cm := _mat(Color(1, 1, 1, 0.95))
	cm.vertex_color_use_as_albedo = false
	core.material_override = cm
	root.add_child(core, true)
	var ct := core.create_tween()
	ct.set_ignore_time_scale(true)
	ct.set_parallel(true)
	ct.tween_property(core, "scale", Vector3.ONE * 1.6, 0.08).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	ct.tween_property(cm, "albedo_color:a", 0.0, 0.1).set_delay(0.03)
	var life := root.create_tween()
	life.set_ignore_time_scale(true)
	life.tween_interval(0.26)
	life.tween_callback(root.queue_free)

## 抛物线投掷物。on_land 在落地瞬间调用（游戏时间，受顿帧影响，保证判定与画面同步）
static func projectile(from: Vector3, to: Vector3, duration: float, on_land: Callable, scene_path := "res://assets/models/rigged/prop_cargo_crate_rig.glb") -> Node3D:
	var parent := _parent()
	if parent == null:
		if on_land.is_valid():
			on_land.call()
		return null
	var node: Node3D
	if ResourceLoader.exists(scene_path):
		node = (load(scene_path) as PackedScene).instantiate() as Node3D
		node.scale = Vector3.ONE * 0.55
	else:
		var box := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE * 0.6
		box.mesh = bm
		node = box
	node.name = "VfxThrown"
	parent.add_child(node, true)
	var holder := {"t": 0.0}
	var start := from + Vector3(0, 1.0, 0)
	var end := to + Vector3(0, 0.4, 0)
	var arc := clampf(from.distance_to(to) * 0.28, 0.8, 2.6)
	var spin_axis := Vector3(randf_range(-1, 1), 0.3, randf_range(-1, 1)).normalized()
	var base_scale := node.scale
	var tw := node.create_tween()
	tw.tween_method(func(t: float):
		if not is_instance_valid(node):
			return
		var p := start.lerp(end, t)
		p.y += sin(t * PI) * arc
		node.global_position = p
		node.basis = Basis(spin_axis, t * TAU * 1.25).scaled(base_scale * (1.0 + sin(t * PI) * 0.25)), 0.0, 1.0, duration)
	tw.tween_callback(func():
		if on_land.is_valid():
			on_land.call()
		node.queue_free())
	return node

static func dust(at: Vector3, radius := 1.2, color := Color("#d8c49a")) -> void:
	if GameFeel.instance != null:
		GameFeel.instance.impact_ring(at, radius, color, 0.22)

static var _puff_mesh: SphereMesh

## 行驶 / 落脚扬尘：低多边形小团，膨胀上飘后淡出
static func puff(at: Vector3, size := 0.45, color := Color("#d8c49a")) -> void:
	var parent := _parent()
	if parent == null:
		return
	if _puff_mesh == null:
		_puff_mesh = SphereMesh.new()
		_puff_mesh.radius = 0.5
		_puff_mesh.height = 0.8
		_puff_mesh.radial_segments = 7
		_puff_mesh.rings = 3
	var mi := MeshInstance3D.new()
	mi.name = "VfxPuff"
	mi.mesh = _puff_mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(color, 0.7)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi, true)
	mi.global_position = at + Vector3(randf_range(-0.15, 0.15), 0.2, randf_range(-0.15, 0.15))
	mi.scale = Vector3.ONE * size * 0.5
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * size * 1.4, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "position:y", mi.position.y + 0.5, 0.42)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)
