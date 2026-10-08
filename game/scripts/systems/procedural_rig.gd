class_name ProceduralRig
extends Node3D

## C11 程序化动画运行时（规格对齐 Wanderburg 逆向结果，原作无骨骼动画片段，全部是程序驱动）：
## - 腿：SpiderLegController —— legGroups 分组交替迈步、legResetDuration 迈步时长、
##   legResetOverlapDuration 组间重叠、legResetYCurve 抬脚弧线、body 随步伐起伏、OnTakeStep 落地事件
## - 履带/轮：DriveFeedback.AnimateTracks/AnimateWheels —— 按速度旋转，倒车反转，刹车时车身前倾
## - 工具：CannonFeedback.MakeReadyAnim + AdditionalModuleAnimation.Fire* —— 蓄力后缩、击发前冲、弹性回位
## - 翅膀/转子/环：TrackRotator（恒速旋转轴）+ GUIFloatingAnim 式浮动
## - 受击：SimpleShaker 抖动 + 挤压回弹；死亡：DeathAnimationVehicle 位移曲线 + 旋转曲线
## 只改表现，不改玩法：位置/碰撞/伤害仍由宿主（EnemyDummy/BossEntity/玩家）决定。

signal step_taken(foot_position: Vector3)

const MANIFEST_PATH := "res://assets/models/rigged/rig_manifest.json"
static var _manifest: Dictionary = {}

var rig_type := "static"
var model: Node3D
var body: Node3D
var legs: Array[Node3D] = []
var treads: Array[Node3D] = []
var tools: Array[Node3D] = []
var wings: Array[Node3D] = []
var rotors: Array[Node3D] = []
var rings: Array[Node3D] = []
var shields: Array[Node3D] = []
var tops: Array[Node3D] = []
var rest: Dictionary = {}          # Node3D -> Transform3D

# ---- SpiderLegController 参数 ----
var leg_groups: Array = []         # Array[Array[Node3D]]
var active_group := 0
var step_timer := 0.0
var leg_reset_duration := 0.22
var leg_reset_overlap := 0.06
var step_lift := 0.16              # legResetYCurve 峰值（以模型高度归一前的米数）
var stride_angle := 0.42

# ---- 运动输入 ----
var speed := 0.0                   # 平面速度 m/s（宿主每帧喂，或由位移自动估计）
var _last_pos := Vector3.ZERO
var _auto_speed := true
var _time := 0.0
var _bob := 0.0

# ---- 动作状态 ----
var _tool_t := -1.0
var _tool_dur := 0.42
var _hit_t := -1.0
var _death_t := -1.0
var _death_dur := 0.9
var _spawn_t := 0.0
var _phase_boost := 1.0
var _model_height := 1.0
var spin_enabled := true
var _spin_amt := 1.0
var _spin_angle := 0.0

static func load_manifest() -> Dictionary:
	if _manifest.is_empty() and FileAccess.file_exists(MANIFEST_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
		if parsed is Dictionary:
			_manifest = parsed
	return _manifest

static func has_rig(slot: String) -> bool:
	var m := load_manifest()
	return m.has(slot) and ResourceLoader.exists(str(m[slot]["file"]))

## 创建并挂到 parent；无对应资产返回 null（宿主应回落旧视觉）
static func attach(parent: Node3D, slot: String) -> ProceduralRig:
	if parent == null or not has_rig(slot):
		return null
	var entry: Dictionary = load_manifest()[slot]
	var packed := load(str(entry["file"])) as PackedScene
	if packed == null:
		return null
	var rig := ProceduralRig.new()
	rig.name = "ProceduralRig"
	rig.rig_type = str(entry.get("rig", "static"))
	rig.model = packed.instantiate() as Node3D
	rig.add_child(rig.model)
	parent.add_child(rig)
	rig._index_parts()
	RigStyle.apply(rig.model, rig._model_height)
	return rig

func _index_parts() -> void:
	body = model.find_child("Body", true, false) as Node3D
	if body == null:
		body = model
	for n in model.find_children("*", "Node3D", true, false):
		var nd := n as Node3D
		var nm := str(nd.name)
		if nm.begins_with("Leg_"):
			legs.append(nd)
		elif nm.begins_with("Tread_"):
			treads.append(nd)
		elif nm.begins_with("Wing"):
			wings.append(nd)
		elif nm.begins_with("Rotor") or nm.begins_with("Drum"):
			rotors.append(nd)
		elif nm.begins_with("Ring"):
			rings.append(nd)
		elif nm.begins_with("Shield") or nm.begins_with("Door"):
			shields.append(nd)
		elif nm.begins_with("Stack") or nm == "Head" and rig_type != "walker":
			tops.append(nd)
		elif nm in ["Jaw", "Tool", "Barrel", "Boom", "Crane", "Head"] or nm.begins_with("Arm"):
			tools.append(nd)
	for nd in [body] + legs + treads + tools + wings + rotors + rings + shields + tops:
		rest[nd] = nd.transform
	var aabb := AABB()
	var first := true
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var box: AABB = m.global_transform * m.get_aabb() if m.is_inside_tree() else m.transform * m.get_aabb()
		aabb = box if first else aabb.merge(box)
		first = false
	_model_height = maxf(aabb.size.y, 0.3)
	step_lift = clampf(_model_height * 0.18, 0.06, 0.35)
	_build_leg_groups()
	_last_pos = global_position if is_inside_tree() else Vector3.ZERO
	_spawn_t = 0.0

## legsGroupsCount：按前后左右棋盘分两组（四足对角步态 / 多足三角步态近似）
func _build_leg_groups() -> void:
	leg_groups = [[], []]
	var sorted := legs.duplicate()
	sorted.sort_custom(func(a, b): return a.position.z < b.position.z)
	for i in sorted.size():
		var leg: Node3D = sorted[i]
		var left := leg.position.x < 0.0
		var g := (i + (1 if left else 0)) % 2
		leg_groups[g].append(leg)
	if leg_groups[1].is_empty() and leg_groups[0].size() > 1:
		leg_groups[1].append(leg_groups[0].pop_back())

# ---------------------------------------------------------------- 外部驱动接口

func set_speed(v: float) -> void:
	speed = v
	_auto_speed = false

func set_phase_boost(v: float) -> void:
	_phase_boost = v

## CannonFeedback：蓄力→击发→回位
func play_attack(duration := 0.42) -> void:
	_tool_dur = duration
	_tool_t = 0.0

## SimpleShaker + 挤压回弹
func play_hit() -> void:
	_hit_t = 0.0

## DeathAnimationVehicle：位移曲线 + 旋转曲线
func play_death(duration := 0.9) -> void:
	_death_dur = duration
	_death_t = 0.0

func is_dying() -> bool:
	return _death_t >= 0.0

# ---------------------------------------------------------------- 主循环

func _process(delta: float) -> void:
	if model == null:
		return
	_time += delta
	if _auto_speed and is_inside_tree():
		var gp := global_position
		var planar := Vector3(gp.x - _last_pos.x, 0, gp.z - _last_pos.z)
		speed = lerpf(speed, planar.length() / maxf(delta, 1e-4), minf(delta * 10.0, 1.0))
		_last_pos = gp
	if _death_t >= 0.0:
		_animate_death(delta)
		return
	_spawn_t = minf(_spawn_t + delta, 1.0)
	_reset_pose()
	match rig_type:
		"walker", "turret":
			_animate_legs(delta)
			_animate_treads(delta)
		"tracked":
			_animate_treads(delta)
		"flyer":
			_animate_flyer()
		"orbit":
			_animate_orbit()
		"world_spin":
			_animate_world_spin()
		"gate":
			pass
	_animate_tops()
	_animate_tool()
	_animate_hit()
	_animate_spawn()

func _reset_pose() -> void:
	for nd in rest.keys():
		if is_instance_valid(nd):
			nd.transform = rest[nd]

# ---- SpiderLegController.Simulate ----
func _animate_legs(delta: float) -> void:
	if legs.is_empty():
		_idle_breath()
		return
	var moving := speed > 0.15
	var cadence := clampf(speed / 2.2, 0.6, 2.2) * _phase_boost
	var dur := leg_reset_duration / cadence
	if moving:
		step_timer += delta
		if step_timer >= dur - leg_reset_overlap / cadence:
			step_timer = 0.0
			active_group = 1 - active_group
			for leg in leg_groups[active_group]:
				step_taken.emit(leg.global_position)
	var t := clampf(step_timer / dur, 0.0, 1.0)
	# legResetProgressCurve ≈ smoothstep；legResetYCurve ≈ sin(pi t)
	var progress := t * t * (3.0 - 2.0 * t)
	var lift := sin(PI * t)
	var amp := clampf(speed / 2.0, 0.0, 1.0) if moving else 0.0
	for g in 2:
		var swinging := g == active_group
		for leg in leg_groups[g]:
			var r: Transform3D = rest[leg]
			var swing := (progress * 2.0 - 1.0) if swinging else (1.0 - progress * 2.0)
			var basis := r.basis.rotated(Vector3.RIGHT, swing * stride_angle * amp)
			var pos := r.origin + Vector3(0, (step_lift * lift * amp) if swinging else 0.0, 0)
			leg.transform = Transform3D(basis, pos)
	# body 随步伐上下起伏 + 左右轻摆（bodyLocalDefaultPos 偏移）
	_bob = sin(PI * t) * 0.04 * amp
	var br: Transform3D = rest[body]
	var sway := (1.0 if active_group == 0 else -1.0) * 0.035 * amp
	body.transform = Transform3D(br.basis.rotated(Vector3.FORWARD, sway), br.origin + Vector3(0, _bob, 0))
	if not moving:
		_idle_breath()

# ---- DriveFeedback.AnimateTracks / AnimateEngine ----
func _animate_treads(_delta: float) -> void:
	var moving := speed > 0.1
	for tr in treads:
		var r: Transform3D = rest[tr]
		# 履带本体无独立轮，用高频小幅抖动 + 沿行进方向滚动感表现发动机震动
		var buzz := sin(_time * (30.0 + speed * 12.0)) * (0.012 if moving else 0.004)
		tr.transform = Transform3D(r.basis, r.origin + Vector3(0, buzz, 0))
	if rig_type == "tracked" or legs.is_empty():
		var br: Transform3D = rest[body]
		var engine := sin(_time * 22.0) * 0.006 + sin(_time * 3.1) * 0.01
		var lean := -clampf(speed / 6.0, 0.0, 1.0) * 0.05
		body.transform = Transform3D(br.basis.rotated(Vector3.RIGHT, lean), br.origin + Vector3(0, engine, 0))

func _animate_flyer() -> void:
	var flap_speed := 14.0 if speed > 0.2 else 9.0
	var flap := sin(_time * flap_speed) * 0.7
	for w in wings:
		var r: Transform3D = rest[w]
		var side := -1.0 if w.position.x < 0.0 else 1.0
		w.transform = Transform3D(r.basis.rotated(Vector3.FORWARD, flap * side), r.origin)
	var br: Transform3D = rest[body]
	var hover := 0.45 + sin(_time * 2.4) * 0.08
	var bank := clampf(speed / 4.0, 0.0, 1.0) * 0.18
	body.transform = Transform3D(br.basis.rotated(Vector3.RIGHT, -bank), br.origin + Vector3(0, hover - (cos(_time * flap_speed) * 0.03), 0))
	for tr in treads:  # 停驻时的脚：飞行中收起
		var r2: Transform3D = rest[tr]
		tr.transform = Transform3D(r2.basis.scaled(Vector3.ONE * 0.85), r2.origin + Vector3(0, 0.05, 0))

func _animate_orbit() -> void:
	var br: Transform3D = rest[body]
	body.transform = Transform3D(br.basis, br.origin + Vector3(0, 0.25 + sin(_time * 1.6) * 0.12, 0))
	for i in rings.size():
		var ring := rings[i]
		var r: Transform3D = rest[ring]
		var side := -1.0 if ring.position.x < 0.0 else 1.0
		var ang := _time * 1.8 * _phase_boost * side
		var orbit := Vector3(cos(ang) * 0.12, sin(_time * 2.2 + i) * 0.15, sin(ang) * 0.12)
		ring.transform = Transform3D(r.basis.rotated(Vector3.UP, ang).rotated(Vector3.RIGHT, sin(_time + i) * 0.3), r.origin + orbit)

func _animate_world_spin() -> void:
	_spin_amt = move_toward(_spin_amt, 1.0 if spin_enabled else 0.0, get_process_delta_time() * 0.8)
	_spin_angle += get_process_delta_time() * 2.4 * _spin_amt
	for ro in rotors:
		var r: Transform3D = rest[ro]
		var axis := Vector3.FORWARD if str(model.get_parent().name).contains("turbine") or rig_type == "world_spin" else Vector3.UP
		ro.transform = Transform3D(r.basis.rotated(axis, _spin_angle), r.origin)

func _animate_tops() -> void:
	for tp in tops:
		var r: Transform3D = rest[tp]
		var puff := 1.0 + maxf(0.0, sin(_time * 5.0)) * 0.05
		tp.transform = Transform3D(r.basis.scaled(Vector3(1.0, puff, 1.0)), r.origin)
	if rig_type == "turret":
		for ro in rotors:
			var r2: Transform3D = rest[ro]
			ro.transform = Transform3D(r2.basis.rotated(Vector3.RIGHT, _time * 3.0), r2.origin)
		for sh in shields:
			var r3: Transform3D = rest[sh]
			var side := -1.0 if sh.position.x < 0.0 else 1.0
			sh.transform = Transform3D(r3.basis.rotated(Vector3.FORWARD, side * (0.06 + sin(_time * 1.5) * 0.03)), r3.origin)

func _idle_breath() -> void:
	var br: Transform3D = rest[body]
	var breath := 1.0 + sin(_time * 2.0) * 0.015
	body.transform = Transform3D(br.basis.scaled(Vector3(1.0, breath, 1.0)), br.origin)
	for sh in shields:
		var r: Transform3D = rest[sh]
		var side := -1.0 if sh.position.x < 0.0 else 1.0
		sh.transform = Transform3D(r.basis.rotated(Vector3.FORWARD, side * sin(_time * 1.2) * 0.04), r.origin)

# ---- CannonFeedback：makeReady 曲线 0-0.35 后缩蓄力，0.35-0.5 爆发前冲，0.5-1 过冲回弹 ----
func _animate_tool() -> void:
	if _tool_t < 0.0:
		for tl in tools:  # 待机微动
			var r: Transform3D = rest[tl]
			tl.transform = Transform3D(r.basis.rotated(Vector3.RIGHT, sin(_time * 1.7) * 0.03), r.origin)
		return
	_tool_t += get_process_delta_time() / _tool_dur
	var t := _tool_t
	var k: float
	if t < 0.35:
		k = -ease(t / 0.35, 0.5) * 0.6
	elif t < 0.5:
		k = lerpf(-0.6, 1.0, ease((t - 0.35) / 0.15, 2.0))
	else:
		var u := (t - 0.5) / 0.5
		k = exp(-5.0 * u) * cos(u * 9.0)
	for tl in tools:
		var r: Transform3D = rest[tl]
		var nm := str(tl.name)
		var rot_axis := Vector3.RIGHT
		var push := Vector3(0, 0, -0.12 * k)
		if nm.begins_with("Arm"):
			rot_axis = Vector3.RIGHT
			push = Vector3.ZERO
		tl.transform = Transform3D(r.basis.rotated(rot_axis, -k * 0.55), r.origin + push)
	var br: Transform3D = body.transform
	body.transform = Transform3D(br.basis, br.origin + Vector3(0, 0, 0.05 * maxf(k, 0.0)))
	if _tool_t >= 1.0:
		_tool_t = -1.0

# ---- SimpleShaker + squash ----
func _animate_hit() -> void:
	if _hit_t < 0.0:
		return
	_hit_t += get_process_delta_time() / 0.28
	var decay := 1.0 - _hit_t
	var shake := Vector3(sin(_hit_t * 70.0), 0, cos(_hit_t * 55.0)) * 0.05 * decay
	var squash := 1.0 - 0.14 * decay * absf(cos(_hit_t * 12.0))
	model.transform = Transform3D(Basis().scaled(Vector3(1.0 + (1.0 - squash) * 0.6, squash, 1.0 + (1.0 - squash) * 0.6)), shake)
	if _hit_t >= 1.0:
		_hit_t = -1.0
		model.transform = Transform3D.IDENTITY

func _animate_spawn() -> void:
	if _spawn_t >= 1.0 or _hit_t >= 0.0:
		return
	var t := _spawn_t
	var s := 1.0 + sin(t * PI * 2.5) * exp(-4.0 * t) * 0.25
	model.scale = Vector3(1.0 / s, s, 1.0 / s) * clampf(t * 4.0, 0.0, 1.0)

# ---- DeathAnimationVehicle：deathAnimCurve（上弹→落地回弹）+ deathAnimCurveRot（侧翻）----
func _animate_death(delta: float) -> void:
	_death_t += delta / _death_dur
	var t := minf(_death_t, 1.0)
	var h := _model_height * 0.5
	# 上弹 0-0.35，落地 0.35-0.6，小回弹 0.6-1
	var y: float
	if t < 0.35:
		y = sin(t / 0.35 * PI * 0.5) * 0.5
	elif t < 0.6:
		y = lerpf(0.5, 0.0, ease((t - 0.35) / 0.25, 2.2))
	else:
		y = absf(sin((t - 0.6) / 0.4 * PI)) * 0.08 * (1.0 - t)
	var roll := ease(minf(t / 0.6, 1.0), 0.6) * deg_to_rad(95.0)
	var pivot := Vector3(0, h, 0)
	var basis := Basis().rotated(Vector3.FORWARD, roll).scaled(Vector3.ONE * (1.0 - maxf(t - 0.7, 0.0) * 0.6))
	# 绕身体中心旋转：T(pivot) * R * T(-pivot)，再叠加上弹位移
	model.transform = Transform3D(basis, pivot - basis * pivot + Vector3(0, y, 0))
	# 部件松脱四散
	for nd in legs + tools + wings + shields + rings:
		var r: Transform3D = rest[nd]
		var dir := (r.origin - (rest[body] as Transform3D).origin)
		dir.y = 0.0
		dir = dir.normalized() if dir.length() > 0.01 else Vector3.RIGHT
		var loose := maxf(t - 0.3, 0.0) / 0.7
		nd.transform = Transform3D(r.basis.rotated(Vector3(dir.z, 0, -dir.x), loose * 1.6), r.origin + dir * loose * 0.6)
