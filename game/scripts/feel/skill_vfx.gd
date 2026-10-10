class_name SkillVfx
extends RefCounted

## C21 组合特效：技能形状 / 状态光环 / 残影 / 漩涡 / 光柱 / 头顶字。只表现，不判定。

const BONE := VfxKit.BONE
const RED := VfxKit.RED
const OCHRE := VfxKit.OCHRE
const VIOLET := VfxKit.VIOLET
const FROST := VfxKit.FROST
const HEAL := VfxKit.HEAL

## 技能形状 → 主色
const SHAPE_COLORS := {
	"fireball": OCHRE, "flame_cone": OCHRE, "firewall": OCHRE, "mortar": OCHRE, "mortar_line": OCHRE, "barrage": BONE,
	"frost_cone": FROST, "frost_nova": FROST, "tide_wave": Color("#5FB7C9"), "shield": Color("#5FB7C9"),
	"chain": Color("#C9B8F0"), "emp": Color("#C9B8F0"), "tesla": Color("#C9B8F0"), "blink": Color("#C9B8F0"),
	"void_lance": VIOLET, "gravity_well": VIOLET, "magnet_pull": VIOLET,
	"repair": HEAL, "medic": HEAL, "soup": HEAL, "drone_heal": HEAL,
	"ram": RED, "roar": RED, "cannon": RED, "overclock": RED, "dash": OCHRE,
}

static func color_of(shape: String) -> Color:
	return SHAPE_COLORS.get(shape, BONE)

# ------------------------------------------------------------ 施法起手（所有技能共用）

## 车身脚下施法环 + 向上的能量 + 技能名
static func cast_flourish(at: Vector3, shape: String, title: String) -> void:
	if VfxKit.parent() == null:
		return
	var c := color_of(shape)
	_ground_ring(at, 2.2, c, 0.35, true)
	VfxKit.burst(Vector3(at.x, 0.3, at.z), "embers", c, 0.9, 0.9)
	if not title.is_empty():
		callout(at + Vector3(0, 3.2, 0), title, c)

## 地面发光圈：从小到大展开，内亮外淡
static func _ground_ring(at: Vector3, radius: float, color: Color, dur: float, additive := false) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "VfxCastRing"
	var q := QuadMesh.new()
	q.size = Vector2(2, 2)
	q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	var m := VfxKit.flat_mat(Color(color, 0.9), additive, "ring")
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3.ONE * radius * 0.3
	if not VfxKit._add(mi, Vector3(at.x, 0.08, at.z), dur + 0.1):
		return
	var tw := mi.create_tween()
	tw.set_ignore_time_scale(true)
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * radius, dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "rotation:y", PI * 0.5, dur)
	tw.tween_property(m, "albedo_color:a", 0.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

## 头顶短字（技能名 / 状态名），P5 字体，弹出后上飘
static func callout(at: Vector3, text: String, color: Color, size := 64) -> void:
	var lbl := Label3D.new()
	lbl.name = "VfxCallout"
	lbl.text = text
	lbl.font = P5Theme.title_font()
	lbl.font_size = size
	lbl.outline_size = 16
	lbl.modulate = color.lerp(Color.WHITE, 0.2)
	lbl.outline_modulate = VfxKit.INK
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.pixel_size = 0.011
	lbl.scale = Vector3.ONE * 0.3
	if not VfxKit._add(lbl, at, 0.9):
		return
	VfxKit.stats["callouts"] += 1
	var tw := lbl.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(lbl, "scale", Vector3.ONE * 1.15, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "scale", Vector3.ONE, 0.06)
	tw.tween_property(lbl, "position:y", lbl.position.y + 0.8, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.3).set_delay(0.25)
	tw.parallel().tween_property(lbl, "outline_modulate:a", 0.0, 0.3).set_delay(0.25)

# ------------------------------------------------------------ 形状特效

## 扇形喷射：粒子流 + 扇面
static func cone_spray(origin: Vector3, dir: Vector3, r: float, half_deg: float, kind: String) -> void:
	if VfxKit.parent() == null:
		return
	var d := Vector3(dir.x, 0, dir.z).normalized()
	var c := Vector3(origin.x, 0.7, origin.z) + d * 0.8
	var preset := "embers"
	var color := OCHRE
	match kind:
		"frost_cone":
			preset = "frost"
			color = FROST
		"tide_wave":
			preset = "water"
			color = Color("#5FB7C9")
	var p := VfxKit.burst(c, preset, color, clampf(r / 4.0, 0.8, 2.2), 2.4, d)
	if p != null:
		var pm := p.process_material as ParticleProcessMaterial
		pm.direction = d
		pm.spread = half_deg
		pm.gravity = Vector3(0, -1.0 if kind != "tide_wave" else -8.0, 0)
	if kind == "flame_cone":
		VfxKit.burst(c, "smoke", Color(0.3, 0.27, 0.25, 0.7), clampf(r / 5.0, 0.6, 1.8), 1.0, d)
	if kind == "tide_wave":
		VfxKit.burst(c, "dust", Color(0.9, 0.97, 1.0, 0.7), 1.2, 1.4, d)
	_fan(origin, d, r, half_deg, color)

static func _fan(origin: Vector3, d: Vector3, r: float, half_deg: float, color: Color) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 16
	var base := atan2(d.x, d.z)
	for i in steps:
		var a0 := base + deg_to_rad(lerpf(-half_deg, half_deg, float(i) / steps))
		var a1 := base + deg_to_rad(lerpf(-half_deg, half_deg, float(i + 1) / steps))
		st.set_color(Color(1, 1, 1, 0.0))
		st.add_vertex(Vector3.ZERO)
		st.set_color(Color(1, 1, 1, 1))
		st.add_vertex(Vector3(sin(a0), 0, cos(a0)) * r)
		st.add_vertex(Vector3(sin(a1), 0, cos(a1)) * r)
	var mi := MeshInstance3D.new()
	mi.name = "VfxFan"
	mi.mesh = st.commit()
	var m := VfxKit.flat_mat(Color(color, 0.55), true)
	m.vertex_color_use_as_albedo = true
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3(0.15, 1, 0.15)
	if not VfxKit._add(mi, Vector3(origin.x, 0.15, origin.z), 0.45):
		return
	var tw := mi.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(mi, "scale", Vector3.ONE, 0.14).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.25)

## 吸力漩涡：旋转的螺旋盘 + 向心粒子
static func vortex(at: Vector3, radius: float, color: Color, dur := 0.8) -> void:
	var root := Node3D.new()
	root.name = "VfxVortex"
	if not VfxKit._add(root, Vector3(at.x, 0.1, at.z), dur + 0.2):
		return
	for k in 3:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(2, 2)
		q.orientation = PlaneMesh.FACE_Y
		mi.mesh = q
		var m := VfxKit.flat_mat(Color(color, 0.7 - k * 0.15), true, "ring")
		mi.material_override = m
		mi.position.y = k * 0.04
		root.add_child(mi)
		var s0 := radius * (1.0 - k * 0.25)
		mi.scale = Vector3.ONE * s0
		var tw := mi.create_tween()
		tw.set_ignore_time_scale(true)
		tw.set_parallel(true)
		tw.tween_property(mi, "scale", Vector3.ONE * 0.15, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_delay(k * 0.08)
		tw.tween_property(mi, "rotation:y", -TAU * 1.5, dur)
		tw.tween_property(m, "albedo_color:a", 0.0, dur * 0.4).set_delay(dur * 0.6)
	# 向心粒子：发射在外圈，速度朝内
	var p := VfxKit.emitter("dust", color, 0.6, 2.0)
	var pm := p.process_material as ParticleProcessMaterial
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = radius
	pm.emission_ring_inner_radius = radius * 0.8
	pm.emission_ring_height = 0.2
	pm.radial_velocity_min = -radius * 2.2
	pm.radial_velocity_max = -radius * 1.6
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.3
	pm.orbit_velocity_min = 0.6
	pm.orbit_velocity_max = 1.0
	pm.gravity = Vector3.ZERO
	p.lifetime = 0.45
	root.add_child(p)
	var stop := root.create_tween()
	stop.tween_interval(dur * 0.8)
	stop.tween_callback(func(): p.emitting = false)

## 光柱：竖直的发光圆柱，快速升起后收细
static func pillar(at: Vector3, radius: float, height: float, color: Color, dur := 0.5) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "VfxPillar"
	var cm := CylinderMesh.new()
	cm.top_radius = radius * 0.6
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 16
	cm.cap_top = false
	cm.cap_bottom = false
	mi.mesh = cm
	var m := VfxKit.flat_mat(Color(color, 0.55), true)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3(1, 0.05, 1)
	if not VfxKit._add(mi, Vector3(at.x, height * 0.5, at.z), dur + 0.1):
		return
	var tw := mi.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(mi, "scale", Vector3(1, 1, 1), dur * 0.25).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "scale", Vector3(0.1, 1.1, 0.1), dur * 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, dur * 0.75)

## 冲击波墙：贴地扩散的竖环
static func shock_wall(at: Vector3, radius: float, color: Color, dur := 0.45, height := 1.2) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "VfxShockWall"
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = height
	cm.radial_segments = 32
	cm.cap_top = false
	cm.cap_bottom = false
	mi.mesh = cm
	var m := VfxKit.flat_mat(Color(color, 0.6), true)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3(0.2, 1, 0.2)
	if not VfxKit._add(mi, Vector3(at.x, height * 0.5, at.z), dur + 0.1):
		return
	var tw := mi.create_tween()
	tw.set_ignore_time_scale(true)
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, 0.25, radius), dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

## 地面一圈扬尘（冲击波 / 落地）
static func dust_ring(at: Vector3, radius: float, color := VfxKit.SAND) -> void:
	var p := VfxKit.burst(Vector3(at.x, 0.2, at.z), "dust", color, clampf(radius / 3.0, 0.6, 2.4), clampf(radius, 1.0, 3.0))
	if p == null:
		return
	var pm := p.process_material as ParticleProcessMaterial
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = radius * 0.3
	pm.emission_ring_inner_radius = 0.0
	pm.emission_ring_height = 0.1
	pm.radial_velocity_min = radius * 2.0
	pm.radial_velocity_max = radius * 3.0
	pm.direction = Vector3.UP
	pm.spread = 15.0

## 残影：复制 source 下所有网格（共享网格资源，开销小），半透明淡出
static func afterimage(source: Node3D, color: Color, life := 0.28) -> void:
	if source == null or not is_instance_valid(source) or not source.is_inside_tree():
		return
	var root := Node3D.new()
	root.name = "VfxAfterimage"
	if not VfxKit._add(root, Vector3.ZERO, life + 0.1):
		return
	VfxKit.stats["afterimages"] += 1
	root.global_transform = Transform3D.IDENTITY
	var m := VfxKit.flat_mat(Color(color, 0.3), false)
	m.no_depth_test = false
	m.render_priority = -2
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var n := 0
	for node in source.find_children("*", "MeshInstance3D", true, false):
		var src := node as MeshInstance3D
		if not src.visible or src.mesh == null or str(src.name).begins_with("Vfx") or str(src.name) == "ContactShadow":
			continue
		var g := MeshInstance3D.new()
		g.mesh = src.mesh
		g.material_override = m
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(g)
		g.global_transform = src.global_transform
		n += 1
		if n >= 24:
			break
	var tw := root.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(m, "albedo_color:a", 0.0, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

## 冲刺拖尾：duration 内每 0.045s 留一个残影，并在车尾冒尘
static func dash_trail(host: Node3D, color: Color, duration := 0.35) -> void:
	if host == null or not is_instance_valid(host) or not host.is_inside_tree() or VfxKit.parent() == null:
		return
	var src: Node3D = host.get("visual_root") if host.get("visual_root") != null else host
	var n := int(duration / 0.05)
	var tw := host.create_tween()
	tw.tween_interval(0.05)
	for i in n:
		tw.tween_callback(func():
			if is_instance_valid(src) and src.is_inside_tree():
				afterimage(src, color, 0.2))
		tw.tween_interval(0.05)

## 速度线：车身两侧向后飞的细线
static func speed_lines(at: Vector3, dir: Vector3, color := VfxKit.BONE) -> void:
	var d := Vector3(dir.x, 0, dir.z).normalized()
	var p := VfxKit.burst(Vector3(at.x, 0.8, at.z) + d * 1.5, "shock", color, 1.0, 0.9, -d)
	if p != null:
		var pm := p.process_material as ParticleProcessMaterial
		pm.spread = 12.0
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(1.4, 0.6, 0.4)

## 碎块飞散（敌人死亡）：用小号焦痕贴图做翻滚碎片
static func scrap_burst(at: Vector3, size := 1.0, tint := VfxKit.INK) -> void:
	VfxKit.burst(Vector3(at.x, 0.7, at.z), "debris", tint, size, 1.3)
	VfxKit.burst(Vector3(at.x, 0.7, at.z), "sparks", OCHRE, size * 0.9, 1.0)
	VfxKit.burst(Vector3(at.x, 0.9, at.z), "smoke", Color(0.3, 0.28, 0.27, 0.75), size * 0.9, 0.9)

# ------------------------------------------------------------ 状态光环

## 挂在实体下，监听 StatusEffects 的 applied / expired，显示持续特效
class StatusAura extends Node3D:
	var height := 1.6
	var radius := 0.8
	var show_callouts := false
	var fx: Dictionary = {}
	var _t := 0.0

	func setup(status: StatusEffects, h: float, r: float) -> void:
		name = "VfxStatusAura"
		height = h
		radius = r
		status.applied.connect(_on_applied)
		status.expired.connect(_on_expired)
		for k in status.active_list():
			_on_applied(k, status.remaining(k))

	func _on_applied(kind: String, d: float) -> void:
		if fx.has(kind) or not is_inside_tree() or VfxKit.parent() == null:
			return
		# 冲刺 / 受击无敌帧太短，交给残影和闪白表现，不挂光环
		if kind in ["invincible", "nitro"] and d < 0.6:
			return
		var n: Node3D = null
		match kind:
			"burning":
				n = VfxKit.emitter("embers", VfxKit.OCHRE, clampf(radius, 0.6, 1.6), 1.6)
				n.position = Vector3(0, height * 0.45, 0)
				(n as GPUParticles3D).process_material.emission_sphere_radius = radius * 0.7
			"stun":
				n = _stars()
			"slow":
				n = VfxKit.emitter("frost", VfxKit.FROST, 0.6, 0.6)
				n.position = Vector3(0, height * 0.4, 0)
			"fear":
				n = _icon("!", VfxKit.VIOLET)
			"shield":
				n = _bubble(Color("#5FB7C9"))
			"invincible":
				n = _bubble(VfxKit.BONE, 0.18)
			"nitro":
				n = VfxKit.emitter("embers", VfxKit.RED, 0.7, 1.8, Vector3.BACK)
				n.position = Vector3(0, height * 0.3, radius * 0.9)
			"overheat":
				n = VfxKit.emitter("smoke", Color(0.25, 0.23, 0.22, 0.8), 0.7, 0.8)
				n.position = Vector3(0, height * 0.8, 0)
		if n != null:
			add_child(n)
			fx[kind] = n
			if show_callouts:
				SkillVfx.callout(global_position + Vector3(0, height + 0.8, 0), StatusEffects.LABELS.get(kind, kind), StatusEffects.COLORS.get(kind, VfxKit.BONE), 44)

	func _on_expired(kind: String) -> void:
		if not fx.has(kind):
			return
		var n: Node3D = fx[kind]
		fx.erase(kind)
		if not is_instance_valid(n):
			return
		if n is GPUParticles3D:
			(n as GPUParticles3D).emitting = false
			var t := get_tree().create_timer(1.2)
			t.timeout.connect(func():
				if is_instance_valid(n):
					n.queue_free())
		else:
			n.queue_free()

	func _process(delta: float) -> void:
		_t += delta
		if fx.has("stun"):
			(fx["stun"] as Node3D).rotation.y += delta * 6.0
		if fx.has("fear"):
			(fx["fear"] as Node3D).position.y = height + 0.5 + absf(sin(_t * 6.0)) * 0.25
		for k in ["shield", "invincible"]:
			if fx.has(k):
				var b := fx[k] as Node3D
				var s := 1.0 + sin(_t * 5.0) * 0.04
				b.scale = Vector3.ONE * s

	func _stars() -> Node3D:
		var root := Node3D.new()
		root.position = Vector3(0, height + 0.35, 0)
		var m := VfxKit.flat_mat(Color("#F2D35B"), true, "star")
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		for i in 3:
			var mi := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(0.45, 0.45)
			mi.mesh = q
			mi.material_override = m
			var a := TAU * i / 3.0
			mi.position = Vector3(cos(a), 0, sin(a)) * maxf(radius * 0.6, 0.45)
			root.add_child(mi)
		return root

	func _icon(text: String, color: Color) -> Node3D:
		var lbl := Label3D.new()
		lbl.text = text
		lbl.font = P5Theme.title_font()
		lbl.font_size = 96
		lbl.outline_size = 18
		lbl.modulate = color.lerp(Color.WHITE, 0.3)
		lbl.outline_modulate = VfxKit.INK
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = true
		lbl.pixel_size = 0.01
		lbl.position = Vector3(0, height + 0.5, 0)
		return lbl

	func _bubble(color: Color, alpha := 0.28) -> Node3D:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = maxf(radius, height * 0.6) * 1.15
		sm.height = sm.radius * 2.0
		sm.radial_segments = 24
		sm.rings = 12
		mi.mesh = sm
		var m := VfxKit.flat_mat(Color(color, alpha), true, "")
		m.cull_mode = BaseMaterial3D.CULL_BACK
		m.rim_enabled = false
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(0, height * 0.45, 0)
		return mi

static func attach_status_aura(host: Node3D, status: StatusEffects, height: float, radius: float) -> Node3D:
	if host == null or status == null:
		return null
	var existing := host.get_node_or_null("VfxStatusAura")
	if existing != null:
		return existing
	var a := StatusAura.new()
	host.add_child(a)
	a.setup(status, height, radius)
	return a

## 抛射炮弹：从 from 沿弧线落到 to，用时 dur（与地面预警同步），带烟尾；落地由预警回调负责爆炸
static func lob(from: Vector3, to: Vector3, dur: float, color := OCHRE, size := 0.35) -> void:
	var root := Node3D.new()
	root.name = "VfxLob"
	if not VfxKit._add(root, from + Vector3(0, 1.0, 0), dur + 0.3):
		return
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = size
	sm.height = size * 2.0
	sm.radial_segments = 10
	sm.rings = 5
	mi.mesh = sm
	mi.material_override = VfxKit.flat_mat(color.lerp(Color.WHITE, 0.3), true)
	root.add_child(mi)
	var trail := VfxKit.emitter("smoke", Color(0.35, 0.32, 0.3, 0.6), 0.45, 1.2)
	trail.lifetime = 0.5
	root.add_child(trail)
	var start := from + Vector3(0, 1.0, 0)
	var end := Vector3(to.x, 0.3, to.z)
	var arc := clampf(from.distance_to(to) * 0.6, 3.0, 9.0)
	var tw := root.create_tween()
	tw.tween_method(func(t: float):
		if is_instance_valid(root):
			var p := start.lerp(end, t)
			p.y += sin(t * PI) * arc
			root.global_position = p, 0.0, 1.0, dur).set_trans(Tween.TRANS_LINEAR)
	tw.tween_callback(func():
		mi.visible = false
		trail.emitting = false)
