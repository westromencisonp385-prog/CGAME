class_name VfxKit
extends RefCounted

## C21 特效工具库（只表现，不判定）。所有节点名带 Vfx 前缀，挂在 GameFeel.world_parent 下。
## 贴图全部程序生成（软点 / 火花 / 星 / 烟 / 火苗 / 加号 / 裂纹 / 焦痕），无外部资源依赖。
##   burst()      通用一次性粒子（预设：sparks / embers / smoke / debris / frost / shock / heal / dust / water）
##   explosion()  爆炸：白闪球 + 火团 + 烟 + 火花 + 碎块 + 冲击环 + 焦痕
##   beam()       光束：白芯 + 外辉 + 两端光点，收细淡出
##   lightning()  闪电：折线 + 分叉，闪两下
##   muzzle()     枪口火：锥形闪 + 火花
##   cone_spray() 扇形喷射（火 / 冰 / 水）
##   vortex()     吸力漩涡：旋转螺旋盘 + 向心粒子
##   pillar()     光柱（治疗 / 传送 / 召唤）
##   afterimage() 残影：复制源节点网格成半透明幽灵
##   decal()      地面焦痕 / 裂纹
##   callout()    角色头顶短字（技能名）

const BONE := Color("#EFE3C8")
const RED := Color("#D9412B")
const OCHRE := Color("#E3A52B")
const INK := Color("#1B1B1D")
const VIOLET := Color("#8C7BA8")
const FROST := Color("#7FD3E0")
const HEAL := Color("#8FD694")
const SAND := Color("#d8c49a")
const MAX_LIVE := 90

static var _tex: Dictionary = {}
static var _mats: Dictionary = {}
static var _curves: Dictionary = {}
static var live := 0
static var stats := {"bursts": 0, "explosions": 0, "beams": 0, "bolts": 0, "afterimages": 0, "decals": 0, "callouts": 0, "dropped": 0}

# ------------------------------------------------------------ 基础

static func parent() -> Node3D:
	if GameFeel.instance == null or not is_instance_valid(GameFeel.instance) or not GameFeel.instance.enabled:
		return null
	var p := GameFeel.instance.world_parent
	return p if p != null and is_instance_valid(p) and p.is_inside_tree() else null

static func _track(n: Node, life: float) -> bool:
	if live >= MAX_LIVE:
		stats["dropped"] += 1
		n.free()
		return false
	live += 1
	n.tree_exited.connect(func(): live -= 1)
	var t := n.get_tree().create_timer(life, true, false, true) if n.is_inside_tree() else null
	if t != null:
		t.timeout.connect(func():
			if is_instance_valid(n):
				n.queue_free())
	return true

static func _add(n: Node3D, at: Vector3, life: float) -> bool:
	var p := parent()
	if p == null:
		n.free()
		return false
	p.add_child(n, true)
	n.global_position = at
	return _track(n, life)

# ------------------------------------------------------------ 程序贴图

static func tex(kind: String) -> Texture2D:
	if _tex.has(kind):
		return _tex[kind]
	var s := 128 if kind in ["crack", "splat"] else 64
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	var c := Vector2(s, s) * 0.5
	var noise := FastNoiseLite.new()
	noise.seed = hash(kind)
	noise.frequency = 0.09
	var cracks := []
	if kind == "crack":
		for i in 9:
			var a := TAU * i / 9.0 + rng.randf_range(-0.25, 0.25)
			var pts := [c]
			var p := c
			var steps := rng.randi_range(4, 7)
			for k in steps:
				a += rng.randf_range(-0.5, 0.5)
				p += Vector2(cos(a), sin(a)) * rng.randf_range(6.0, 11.0)
				pts.append(p)
			cracks.append(pts)
	for y in s:
		for x in s:
			var uv := (Vector2(x, y) + Vector2(0.5, 0.5) - c) / (s * 0.5)
			var r := uv.length()
			var a := 0.0
			match kind:
				"dot":
					a = pow(clampf(1.0 - r, 0.0, 1.0), 1.8)
				"spark":
					a = pow(clampf(1.0 - absf(uv.x) * 4.0, 0.0, 1.0), 1.5) * pow(clampf(1.0 - absf(uv.y), 0.0, 1.0), 0.7)
				"star":
					var ang := atan2(uv.y, uv.x)
					var arm := pow(absf(cos(ang * 2.0)), 18.0)
					a = clampf((1.0 - r) * (0.25 + arm * 1.6), 0.0, 1.0) + pow(clampf(1.0 - r * 3.0, 0.0, 1.0), 2.0)
				"smoke":
					var nz := noise.get_noise_2d(x, y) * 0.5 + 0.5
					a = clampf((1.0 - r * 1.15) * (0.55 + nz * 0.9), 0.0, 1.0)
				"flame":
					var q := Vector2(uv.x * (1.6 + uv.y * 0.9), uv.y)
					a = clampf(1.0 - q.length() * (1.25 if uv.y < 0.0 else 1.0), 0.0, 1.0)
					a = pow(a, 0.8)
				"plus":
					a = 1.0 if (absf(uv.x) < 0.22 and absf(uv.y) < 0.75) or (absf(uv.y) < 0.22 and absf(uv.x) < 0.75) else 0.0
				"ring":
					a = pow(clampf(1.0 - absf(r - 0.8) * 7.0, 0.0, 1.0), 1.5)
				"splat":
					var ang2 := atan2(uv.y, uv.x)
					var edge := 0.62 + noise.get_noise_2d(cos(ang2) * 30.0, sin(ang2) * 30.0) * 0.5
					a = clampf((edge - r) * 6.0, 0.0, 1.0) * (0.55 + 0.45 * clampf(1.0 - r, 0.0, 1.0))
				"crack":
					var best := 99.0
					var pt := Vector2(x, y)
					for pts in cracks:
						for k in range(pts.size() - 1):
							best = minf(best, Geometry2D.get_closest_point_to_segment(pt, pts[k], pts[k + 1]).distance_to(pt) / maxf(1.0 - float(k) / pts.size(), 0.35))
					a = clampf(1.6 - best * 0.75, 0.0, 1.0) + clampf(0.35 - r, 0.0, 0.35)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	var t := ImageTexture.create_from_image(img)
	_tex[kind] = t
	return t

static func _curve(kind: String) -> CurveTexture:
	if _curves.has(kind):
		return _curves[kind]
	var cv := Curve.new()
	match kind:
		"grow":
			cv.add_point(Vector2(0, 0.35))
			cv.add_point(Vector2(1, 1))
		"pop":
			cv.add_point(Vector2(0, 0.2))
			cv.add_point(Vector2(0.15, 1))
			cv.add_point(Vector2(1, 0))
		_:
			cv.add_point(Vector2(0, 1))
			cv.add_point(Vector2(1, 0))
	var ct := CurveTexture.new()
	ct.curve = cv
	_curves[kind] = ct
	return ct

static func _pmat(texture: String, additive: bool, aligned := false) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [texture, additive, aligned]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex(texture)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED if aligned else BaseMaterial3D.BILLBOARD_PARTICLES
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_mats[key] = m
	return m

static func flat_mat(color: Color, additive := false, texture := "") -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = color
	if not texture.is_empty():
		m.albedo_texture = tex(texture)
	return m

# ------------------------------------------------------------ 粒子

## 预设表：tex, add, aligned, amount, life, vel[min,max], spread, gravity_y, size[min,max], curve, damp, up_bias
const PRESETS := {
	"sparks": ["spark", true, true, 14, 0.38, [5.0, 11.0], 80.0, -9.0, [0.25, 0.5], "shrink", 4.0, 0.35],
	"embers": ["dot", true, false, 12, 0.9, [1.5, 4.0], 60.0, 2.0, [0.12, 0.26], "shrink", 2.0, 0.8],
	"smoke": ["smoke", false, false, 8, 1.1, [0.8, 2.2], 70.0, 1.6, [0.9, 1.6], "grow", 2.5, 0.6],
	"debris": ["splat", false, false, 10, 0.75, [4.0, 8.0], 55.0, -18.0, [0.18, 0.36], "shrink", 0.5, 0.8],
	"frost": ["star", true, false, 16, 0.7, [2.0, 6.0], 85.0, -2.0, [0.2, 0.42], "shrink", 3.0, 0.3],
	"shock": ["spark", true, true, 16, 0.25, [7.0, 14.0], 180.0, 0.0, [0.25, 0.5], "shrink", 6.0, 0.0],
	"heal": ["plus", false, false, 10, 1.0, [1.2, 2.6], 30.0, 1.2, [0.22, 0.38], "pop", 1.0, 1.0],
	"dust": ["smoke", false, false, 9, 0.6, [1.5, 3.6], 85.0, 0.5, [0.5, 0.95], "grow", 4.0, 0.1],
	"water": ["dot", false, false, 14, 0.6, [3.0, 7.0], 50.0, -14.0, [0.18, 0.32], "shrink", 1.0, 0.7],
	"stars": ["star", true, false, 6, 0.55, [1.0, 2.5], 180.0, 0.0, [0.3, 0.5], "pop", 2.0, 0.5],
}

## 通用一次性粒子。dir 为主喷射方向（默认向上）；scale 同时放大速度和尺寸
static func burst(at: Vector3, preset: String, color: Color, scale := 1.0, amount_mult := 1.0, dir := Vector3.UP, color_end := Color(0, 0, 0, 0)) -> GPUParticles3D:
	var cfg: Array = PRESETS.get(preset, PRESETS["sparks"])
	var p := GPUParticles3D.new()
	p.name = "VfxBurst_" + preset
	p.amount = maxi(1, int(round(float(cfg[3]) * amount_mult)))
	p.lifetime = float(cfg[4])
	p.one_shot = true
	p.explosiveness = 0.92
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-8, -4, -8), Vector3(16, 12, 16))
	if bool(cfg[2]):
		p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	var pm := ParticleProcessMaterial.new()
	var d := dir.normalized() if dir.length() > 0.01 else Vector3.UP
	pm.direction = (d + Vector3.UP * float(cfg[11])).normalized()
	pm.spread = float(cfg[6])
	var vel: Array = cfg[5]
	pm.initial_velocity_min = float(vel[0]) * scale
	pm.initial_velocity_max = float(vel[1]) * scale
	pm.gravity = Vector3(0, float(cfg[7]), 0)
	pm.damping_min = float(cfg[10])
	pm.damping_max = float(cfg[10]) * 1.4
	var sz: Array = cfg[8]
	pm.scale_min = float(sz[0]) * scale
	pm.scale_max = float(sz[1]) * scale
	pm.scale_curve = _curve(str(cfg[9]))
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.25 * scale
	var g := Gradient.new()
	var end := color_end if color_end.a > 0.0 else Color(color, 0.0)
	g.set_color(0, Color(color, 1.0))
	g.set_color(1, Color(end, 0.0))
	g.add_point(0.6, Color(color.lerp(end, 0.5), 0.8))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(1, 1) if not bool(cfg[2]) else Vector2(0.35, 1.6)
	q.material = _pmat(str(cfg[0]), bool(cfg[1]), bool(cfg[2]))
	p.draw_pass_1 = q
	if not _add(p, at, p.lifetime + 0.3):
		return null
	p.emitting = true
	stats["bursts"] += 1
	return p

## 持续发射的粒子（状态 / 拖尾）；由调用方负责释放
static func emitter(preset: String, color: Color, scale := 1.0, rate_mult := 1.0, dir := Vector3.UP) -> GPUParticles3D:
	var cfg: Array = PRESETS.get(preset, PRESETS["embers"])
	var p := GPUParticles3D.new()
	p.name = "VfxEmitter_" + preset
	p.amount = maxi(2, int(round(float(cfg[3]) * rate_mult)))
	p.lifetime = float(cfg[4])
	p.explosiveness = 0.0
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-6, -3, -6), Vector3(12, 10, 12))
	if bool(cfg[2]):
		p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	var pm := ParticleProcessMaterial.new()
	pm.direction = (dir.normalized() + Vector3.UP * float(cfg[11])).normalized()
	pm.spread = float(cfg[6]) * 0.6
	var vel: Array = cfg[5]
	pm.initial_velocity_min = float(vel[0]) * scale * 0.6
	pm.initial_velocity_max = float(vel[1]) * scale * 0.6
	pm.gravity = Vector3(0, float(cfg[7]), 0)
	pm.damping_min = float(cfg[10])
	pm.damping_max = float(cfg[10])
	var sz: Array = cfg[8]
	pm.scale_min = float(sz[0]) * scale
	pm.scale_max = float(sz[1]) * scale
	pm.scale_curve = _curve(str(cfg[9]))
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.3 * scale
	var g := Gradient.new()
	g.set_color(0, Color(color, 1.0))
	g.set_color(1, Color(color, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(1, 1) if not bool(cfg[2]) else Vector2(0.35, 1.6)
	q.material = _pmat(str(cfg[0]), bool(cfg[1]), bool(cfg[2]))
	p.draw_pass_1 = q
	p.emitting = true
	return p

# ------------------------------------------------------------ 组合特效

static func _sphere_flash(at: Vector3, radius: float, color: Color, dur := 0.16) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "VfxFlash"
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 14
	sm.rings = 7
	mi.mesh = sm
	var m := flat_mat(Color(color, 0.95), true)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3.ONE * radius * 0.3
	if not _add(mi, at, dur + 0.1):
		return
	var tw := mi.create_tween()
	tw.set_ignore_time_scale(true)
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * radius, dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

static func explosion(at: Vector3, radius := 2.0, color := OCHRE, scorch := true) -> void:
	if parent() == null:
		return
	stats["explosions"] += 1
	var s := clampf(radius / 2.0, 0.5, 3.0)
	var c := Vector3(at.x, 0.6, at.z)
	_sphere_flash(c, radius * 0.75, Color(1, 0.96, 0.85))
	burst(c, "embers", color, s, 1.6, Vector3.UP, RED)
	burst(c, "sparks", color.lerp(Color.WHITE, 0.4), s, 1.4)
	burst(c + Vector3(0, 0.3, 0), "smoke", Color(0.25, 0.23, 0.22, 0.85), s, 1.0, Vector3.UP)
	burst(c, "debris", INK, s, 1.0)
	if GameFeel.instance != null:
		GameFeel.instance.impact_ring(at, radius * 1.2, color, 0.32)
		GameFeel.instance.impact_ring(at, radius * 0.7, BONE, 0.22)
	if scorch:
		decal(at, radius * 0.9, "splat", Color(0.1, 0.09, 0.08, 0.55), 2.6)

static func impact(at: Vector3, color: Color, size := 1.0) -> void:
	if parent() == null:
		return
	_sphere_flash(at, 0.55 * size, color.lerp(Color.WHITE, 0.5), 0.1)
	burst(at, "sparks", color, size * 0.8, 0.7)
	if GameFeel.instance != null:
		GameFeel.instance.impact_ring(at, 1.1 * size, color, 0.2)

static func decal(at: Vector3, radius: float, kind: String, color: Color, life := 2.0) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "VfxDecal_" + kind
	var q := QuadMesh.new()
	q.size = Vector2(radius * 2.0, radius * 2.0)
	q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	var m := flat_mat(color, false, kind)
	m.render_priority = -1
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.rotation.y = randf() * TAU
	if not _add(mi, Vector3(at.x, 0.05, at.z), life + 0.1):
		return
	stats["decals"] += 1
	var tw := mi.create_tween()
	tw.tween_interval(life * 0.6)
	tw.tween_property(m, "albedo_color:a", 0.0, life * 0.4)

## 光束：白芯 + 外辉，沿 a→b
static func beam(a: Vector3, b: Vector3, color: Color, width := 0.5, life := 0.22) -> void:
	var len := a.distance_to(b)
	if len < 0.05:
		return
	var root := Node3D.new()
	root.name = "VfxBeam"
	if not _add(root, (a + b) * 0.5, life + 0.15):
		return
	stats["beams"] += 1
	root.look_at_from_position((a + b) * 0.5, b, Vector3.UP if absf((b - a).normalized().y) < 0.95 else Vector3.RIGHT)
	var layers := [[width, Color(color, 0.55)], [width * 0.38, Color(1, 1, 1, 0.95)]]
	for L in layers:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = float(L[0])
		cm.bottom_radius = float(L[0])
		cm.height = len
		cm.radial_segments = 10
		cm.rings = 1
		mi.mesh = cm
		mi.rotation.x = PI * 0.5
		var m := flat_mat(L[1], true)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		var tw := mi.create_tween()
		tw.set_ignore_time_scale(true)
		tw.set_parallel(true)
		tw.tween_property(mi, "scale", Vector3(0.05, 1, 0.05), life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(m, "albedo_color:a", 0.0, life)
	_sphere_flash(a, width * 1.6, color, 0.12)
	_sphere_flash(b, width * 2.2, color, 0.16)
	burst(b, "sparks", color, 0.8, 0.6)

## 闪电：折线 + 1~2 根分叉，闪烁两下后淡出
static func lightning(a: Vector3, b: Vector3, color := Color("#C9B8F0"), width := 0.09) -> void:
	var root := Node3D.new()
	root.name = "VfxBolt"
	if not _add(root, Vector3.ZERO, 0.4):
		return
	stats["bolts"] += 1
	root.global_position = Vector3.ZERO
	var pts := _jag(a, b, 7, 0.55)
	_polyline(root, pts, color, width)
	for k in 2:
		var i := randi_range(2, pts.size() - 3)
		var dir: Vector3 = (pts[i + 1] - pts[i]).normalized().rotated(Vector3.UP, randf_range(-1.0, 1.0))
		_polyline(root, _jag(pts[i], pts[i] + dir * a.distance_to(b) * 0.25, 3, 0.3), color, width * 0.6)
	_sphere_flash(b, 0.7, color, 0.12)
	var tw := root.create_tween()
	tw.set_ignore_time_scale(true)
	for k in 2:
		tw.tween_callback(func(): root.visible = false).set_delay(0.05)
		tw.tween_callback(func(): root.visible = true).set_delay(0.03)
	tw.tween_property(root, "scale", Vector3(1, 1, 1), 0.08)
	tw.tween_callback(func(): root.visible = false)

static func _jag(a: Vector3, b: Vector3, n: int, amp: float) -> Array:
	var pts := [a]
	var side := (b - a).cross(Vector3.UP).normalized()
	for i in range(1, n):
		var t := float(i) / n
		pts.append(a.lerp(b, t) + side * randf_range(-amp, amp) + Vector3(0, randf_range(-0.2, 0.2), 0))
	pts.append(b)
	return pts

static func _polyline(root: Node3D, pts: Array, color: Color, width: float) -> void:
	var core := flat_mat(Color(1, 1, 1, 1), true)
	var glow := flat_mat(Color(color, 0.6), true)
	for i in range(pts.size() - 1):
		var p0: Vector3 = pts[i]
		var p1: Vector3 = pts[i + 1]
		var len := p0.distance_to(p1)
		if len < 0.01:
			continue
		for L in [[width * 3.0, glow], [width, core]]:
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(float(L[0]), float(L[0]), len)
			mi.mesh = bm
			mi.material_override = L[1]
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(mi)
			mi.look_at_from_position((p0 + p1) * 0.5, p1, Vector3.UP if absf((p1 - p0).normalized().y) < 0.95 else Vector3.RIGHT)

static func muzzle(at: Vector3, dir: Vector3, color: Color, size := 1.0) -> void:
	if parent() == null:
		return
	var d := Vector3(dir.x, 0, dir.z).normalized()
	var c := Vector3(at.x, 0.9, at.z) + d * 0.6 * size
	_sphere_flash(c, 0.6 * size, color.lerp(Color.WHITE, 0.5), 0.08)
	burst(c, "sparks", color, 0.7 * size, 0.6, d)
	burst(c, "smoke", Color(0.6, 0.58, 0.55, 0.5), 0.4 * size, 0.4, d)
