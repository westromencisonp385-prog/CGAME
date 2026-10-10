class_name ProceduralRig
extends Node3D

## 程序化动画运行时（v2，2026-10-09）。对齐 Wanderburg 逆向结论：原作没有骨骼动画片段，全部程序驱动。
## - 腿：SpiderLegController，两组对角交替；连续相位（摆动相抬脚前送，支撑相贴地后推），
##   步频随速度 / 腿长变化，停下时振幅平滑归零；每次落脚发出 step_taken
## - 履带：DriveFeedback，发动机震动 + 速度相关抖动
## - 工具：CannonFeedback，按部件类型分别做“张口-咬合”“抬起-砸下”“后坐”三种曲线
## - 翅膀 / 转子 / 环：拍翅、旋转、浮动
## - 受击：SimpleShaker 抖动 + 挤压回弹；死亡：DeathAnimationVehicle 上弹侧翻 + 部件松脱
## v2 修复：所有旋转轴改为按资产正面轴（manifest.forward）换算到部件父空间；过滤自动拆分误判成腿的整块底盘。
## 只改表现，不改玩法：位置 / 碰撞 / 伤害仍由宿主决定。

signal step_taken(foot_position: Vector3)

const MANIFEST_PATH := "res://assets/models/rigged/rig_manifest.json"
## 模型正面轴 -> 绕 Y 旋转多少能对齐到 -Z
const FORWARD_YAW := {"-Z": 0.0, "+Z": PI, "+X": PI * 0.5, "-X": -PI * 0.5}
const FORWARD_VEC := {"-Z": Vector3(0, 0, -1), "+Z": Vector3(0, 0, 1), "+X": Vector3(1, 0, 0), "-X": Vector3(-1, 0, 0)}
static var _manifest: Dictionary = {}

var rig_type := "static"
var forward_axis := "-Z"
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
var static_parts: Array[Node3D] = []   # 被过滤掉的“伪腿”（整块底盘），保持静止
var rest: Dictionary = {}               # Node3D -> Transform3D（当前静止姿态，可被 set_part_scale 改）
var base_rest: Dictionary = {}          # Node3D -> Transform3D（资产原始姿态）
var _axes: Dictionary = {}              # Node3D -> {"right": Vector3, "fwd": Vector3, "up": Vector3}（父空间）
var _side: Dictionary = {}              # Node3D -> -1 / +1（在模型右侧为 +1）

# 模型空间参考
var fwd_m := Vector3(0, 0, -1)
var right_m := Vector3(1, 0, 0)
var _center_m := Vector3.ZERO
var _size_m := Vector3.ONE
var _model_height := 1.0

# 步态
var leg_groups: Array = []              # Array[Array[Node3D]]
var leg_len := 0.3
var stride_angle := 0.5
var step_lift := 0.1
var _phase := 0.0
var _amp := 0.0
var speed := 0.0                        # 平面速度 m/s（宿主每帧喂，或由位移自动估计）
var _last_pos := Vector3.ZERO
var _auto_speed := true
var _time := 0.0

# 动作
var _tool_t := -1.0
var _tool_dur := 0.42
var _tool_heavy := false
var _hit_t := -1.0
var _death_t := -1.0
var _death_dur := 0.9
var _spawn_t := 0.0
var _phase_boost := 1.0
var spin_enabled := true
var _spin_amt := 1.0
var _spin_angle := 0.0
var _drum_angle := 0.0
## C22 弹性层与驱动
var juice: AnimJuice
var _vel_w := Vector3.ZERO
var _acc_w := Vector3.ZERO
var _last_yaw := 0.0
var _bump_t := 0.0
var _tool_antic := 0.35
## 驱动强度（玩家车可调高）
var lean_gain := 1.0

static func load_manifest() -> Dictionary:
	if _manifest.is_empty() and FileAccess.file_exists(MANIFEST_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
		if parsed is Dictionary:
			_manifest = parsed
	return _manifest

static func has_rig(slot: String) -> bool:
	var m := load_manifest()
	return m.has(slot) and ResourceLoader.exists(str(m[slot].get("file", "")))

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
	rig.forward_axis = str(entry.get("forward", "-Z"))
	rig.model = packed.instantiate() as Node3D
	# 资产正面轴不统一：用独立的 Facing 节点对齐到游戏正面 -Z。受击/死亡动画改 model.transform，不会冲掉这层。
	var facing := Node3D.new()
	facing.name = "Facing"
	facing.rotation.y = FORWARD_YAW.get(rig.forward_axis, 0.0)
	rig.juice = AnimJuice.new()
	rig.add_child(rig.juice)
	rig.juice.add_child(facing)
	facing.add_child(rig.model)
	parent.add_child(rig)
	rig._index_parts()
	rig.juice.height = rig._model_height
	rig.juice.boost = clampf(1.5 / maxf(rig._model_height, 0.3), 1.0, 1.7)
	RigStyle.apply(rig.model, rig._model_height)
	return rig

# ---------------------------------------------------------------- 索引

## 节点到模型根的变换（不依赖是否在场景树里）
func _to_model(n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var p: Node = n
	while p != null and p != model and p is Node3D:
		t = (p as Node3D).transform * t
		p = p.get_parent()
	return t

func _mesh_aabb_m(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi in [n] + n.find_children("*", "MeshInstance3D", true, false):
		if not mi is MeshInstance3D:
			continue
		var b: AABB = _to_model(mi) * (mi as MeshInstance3D).get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out

func _index_parts() -> void:
	fwd_m = FORWARD_VEC.get(forward_axis, Vector3(0, 0, -1))
	right_m = fwd_m.cross(Vector3.UP).normalized()
	body = model.find_child("Body", true, false) as Node3D
	if body == null:
		body = model
	var whole := _mesh_aabb_m(model)
	_center_m = whole.get_center()
	_size_m = whole.size.max(Vector3.ONE * 0.05)
	_model_height = maxf(whole.size.y, 0.3)
	var width := absf(_size_m.dot(right_m.abs()))
	var length := absf(_size_m.dot(fwd_m.abs()))
	var leg_heights: Array[float] = []
	for n in model.find_children("*", "Node3D", true, false):
		var nd := n as Node3D
		var nm := str(nd.name)
		if nm.begins_with("Leg_"):
			var box := _mesh_aabb_m(nd)
			var w := absf(box.size.dot(right_m.abs()))
			var l := absf(box.size.dot(fwd_m.abs()))
			# 自动拆分会把连成一片的底盘也标成“腿”：太宽 / 太长 / 太扁的不当腿用
			if w > width * 0.45 or l > length * 0.6 or box.size.y < _model_height * 0.07:
				static_parts.append(nd)
			else:
				legs.append(nd)
				leg_heights.append(box.size.y)
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
	for nd in [body] + legs + treads + tools + wings + rotors + rings + shields + tops + static_parts:
		rest[nd] = nd.transform
		base_rest[nd] = nd.transform
		# 父空间里的右 / 前 / 上轴
		var parent_basis := Basis.IDENTITY
		if nd != model and nd.get_parent() != model and nd.get_parent() is Node3D:
			parent_basis = _to_model(nd.get_parent() as Node3D).basis
		var inv := parent_basis.orthonormalized().inverse()
		_axes[nd] = {"right": (inv * right_m).normalized(), "fwd": (inv * fwd_m).normalized(), "up": (inv * Vector3.UP).normalized()}
		var o := _to_model(nd).origin
		_side[nd] = 1.0 if (o - _center_m).dot(right_m) >= 0.0 else -1.0
	if not leg_heights.is_empty():
		var sum := 0.0
		for h in leg_heights:
			sum += h
		leg_len = clampf(sum / leg_heights.size(), 0.08, 2.0)
	step_lift = clampf(leg_len * 0.4, 0.03, 0.4)
	_build_leg_groups()
	_last_pos = global_position if is_inside_tree() else Vector3.ZERO
	_spawn_t = 0.0

## 前后排序后按“排序序号 + 左右”棋盘分两组：四足 = 对角步态，六足 = 三角步态
func _build_leg_groups() -> void:
	leg_groups = [[], []]
	var sorted: Array = legs.duplicate()
	sorted.sort_custom(func(a, b): return _to_model(a).origin.dot(fwd_m) > _to_model(b).origin.dot(fwd_m))
	var count_side := {-1.0: 0, 1.0: 0}
	for leg in sorted:
		var s: float = _side[leg]
		var g := (int(count_side[s]) + (1 if s > 0.0 else 0)) % 2
		count_side[s] = int(count_side[s]) + 1
		leg_groups[g].append(leg)
	if leg_groups[1].is_empty() and leg_groups[0].size() > 1:
		leg_groups[1].append(leg_groups[0].pop_back())

## 外部改部件缩放（如宽斗放大鲸口）：基于原始姿态，不会把动画中的姿态写进静止姿态
func set_part_scale(nd: Node3D, s: float) -> void:
	if nd == null or not base_rest.has(nd):
		return
	var b: Transform3D = base_rest[nd]
	rest[nd] = Transform3D(b.basis.scaled(Vector3.ONE * s), b.origin)

# ---------------------------------------------------------------- 外部驱动接口

func set_speed(v: float) -> void:
	speed = v
	_auto_speed = false

func set_phase_boost(v: float) -> void:
	_phase_boost = v

## 攻击：heavy = 连击收尾的大动作；antic = 预备占比（玩家 0.1 左右，第 0 帧就有姿态；敌人前摇对齐伤害结算）
func play_attack(duration := 0.42, heavy := false, antic := 0.35, amount := 1.0, dir_world := Vector3.ZERO) -> void:
	_tool_dur = duration
	_tool_heavy = heavy
	_tool_antic = clampf(antic, 0.05, 0.8)
	_tool_t = 0.0
	if juice != null:
		var lead := _tool_antic * duration
		var fwd := Vector3(0, 0, -1)
		if dir_world.length() > 0.01:
			fwd = juice.world_to_local_dir(dir_world).normalized()
		juice.anticipate(amount, lead, -fwd)
		juice.after(lead, func(): juice.release(amount, fwd, heavy))

## 受击：push_dir_world = 受力方向（世界）；为零时原地扭一下
func play_hit(push_dir_world := Vector3.ZERO, amount := 1.0) -> void:
	_hit_t = 0.0
	if juice != null:
		juice.hit_from(juice.world_to_local_dir(push_dir_world) if push_dir_world.length() > 0.01 else Vector3.ZERO, amount)

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
	if is_inside_tree() and delta > 0.0:
		var gp := global_position
		var planar := Vector3(gp.x - _last_pos.x, 0, gp.z - _last_pos.z)
		var teleported := planar.length() > 3.0
		if _auto_speed:
			speed = lerpf(speed, 0.0 if teleported else planar.length() / maxf(delta, 1e-4), minf(delta * 10.0, 1.0))
		var v := Vector3.ZERO if teleported else planar / maxf(delta, 1e-4)
		var a := (v - _vel_w) / maxf(delta, 1e-4)
		if a.length() > 80.0:
			a = a.normalized() * 80.0
		_acc_w = _acc_w.lerp(a, minf(delta * 14.0, 1.0))
		_vel_w = v
		_last_pos = gp
		var yw := global_basis.get_euler().y
		var dyaw := wrapf(yw - _last_yaw, -PI, PI)
		_last_yaw = yw
		_drive_juice(delta, dyaw, teleported)
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
	_animate_tops(delta)
	_animate_tool(delta)
	_animate_hit(delta)
	_animate_spawn()
	_apply_follow_through()

## 惯性驱动：加速时身体后仰、刹车前栽、转弯外倾（离心）；速度越快沿行进方向越拉长；
## 转身时身体滞后再追上（overlapping）；履带车行驶中随机颠簸（secondary action）
func _drive_juice(delta: float, dyaw: float, teleported: bool) -> void:
	if juice == null:
		return
	var inv := global_basis.orthonormalized().inverse()
	var a_l := inv * _acc_w
	a_l.y = 0.0
	var v_l := inv * _vel_w
	v_l.y = 0.0
	var amag := a_l.length()
	# 顶部倒向加速度的反方向；20 m/s² ≈ 0.2 rad
	juice.drive_tilt = AnimJuice._lean_vec(-a_l, clampf(amag * 0.01 * lean_gain, 0.0, 0.32)) if amag > 0.5 else Vector3.ZERO
	var spd := v_l.length()
	juice.drive_stretch = v_l / spd * clampf(spd / maxf(_model_height * 9.0, 4.0) * 0.14, 0.0, 0.12) if spd > 0.5 else Vector3.ZERO
	if not teleported and absf(dyaw) > 0.0005:
		juice.yaw.x.x -= clampf(dyaw, -0.3, 0.3) * 0.35
	if (rig_type == "tracked" or legs.is_empty()) and rig_type in ["tracked", "walker", "turret"] and spd > 1.5:
		_bump_t -= delta
		if _bump_t <= 0.0:
			_bump_t = randf_range(0.12, 0.28)
			juice.kick_squash(randf_range(0.3, 0.7) * clampf(spd / 8.0, 0.3, 1.0))
			juice.kick_lean(Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)), randf_range(0.15, 0.4))

## 二级跟随：挂件 / 烟囱 / 盾 / 翅膀相对身体滞后甩动并过冲落定
func _apply_follow_through() -> void:
	if juice == null:
		return
	var ft := juice.follow_through()
	if ft.length() < 0.0005:
		return
	var gain := 1.6
	for nd in tools + tops + shields + wings + rings:
		if not is_instance_valid(nd) or not _axes.has(nd):
			continue
		var ax: Dictionary = _axes[nd]
		var b := Basis(ax["right"], ft.x * gain) * Basis(ax["fwd"], ft.z * gain) * Basis(ax["up"], ft.y * gain * 0.7)
		nd.transform = Transform3D(b * nd.transform.basis, nd.transform.origin)

func _reset_pose() -> void:
	for nd in rest.keys():
		if is_instance_valid(nd):
			nd.transform = rest[nd]

## 绕部件自身枢轴、在父空间里按某轴旋转
func _rot(nd: Node3D, axis_key: String, angle: float, offset := Vector3.ZERO, base: Variant = null) -> void:
	var r: Transform3D = rest[nd] if base == null else base
	var axis: Vector3 = _axes[nd][axis_key]
	nd.transform = Transform3D(Basis(axis, angle) * r.basis, r.origin + offset)

# ---- SpiderLegController.Simulate（连续相位版）----
func _animate_legs(delta: float) -> void:
	if legs.is_empty():
		_idle_breath()
		return
	var target_amp := clampf(speed / maxf(leg_len * 5.0, 0.6), 0.0, 1.0)
	_amp = lerpf(_amp, target_amp, minf(delta * 8.0, 1.0))
	# 步频：一步走过约 1.6 倍腿长
	var freq := clampf(speed / maxf(leg_len * 3.2, 0.25), 0.0, 4.5) * _phase_boost
	if target_amp > 0.02 and freq < 1.2:
		freq = 1.2
	var prev := _phase
	_phase = fmod(_phase + freq * delta, 1.0)
	for g in 2:
		var ph := fmod(_phase + 0.5 * g, 1.0)
		var prev_ph := fmod(prev + 0.5 * g, 1.0)
		if prev_ph < 0.5 and ph >= 0.5 and _amp > 0.15:
			if juice != null:
				juice.kick_squash(0.9 * _amp)
			for leg in leg_groups[g]:
				var foot: Vector3 = leg.global_position if leg.is_inside_tree() else Vector3.ZERO
				step_taken.emit(foot)
				if _model_height >= 1.0 and leg.is_inside_tree():
					CombatVfx.puff(Vector3(foot.x, 0.0, foot.z), clampf(_model_height * 0.18, 0.2, 0.7))
			if _model_height >= 2.0 and GameFeel.instance != null and is_inside_tree():
				GameFeel.instance.shake(0.05)
		var theta: float
		var lift := 0.0
		if ph < 0.5:
			var u := ph / 0.5
			var s := u * u * (3.0 - 2.0 * u)
			theta = lerpf(-1.0, 1.0, s)
			lift = sin(PI * u)
		else:
			theta = lerpf(1.0, -1.0, (ph - 0.5) / 0.5)
		for leg in leg_groups[g]:
			var up: Vector3 = _axes[leg]["up"]
			_rot(leg, "right", theta * stride_angle * _amp, up * step_lift * lift * _amp)
	# 身体：每步一次起伏（双频）、左右轻摆、移动时略前倾
	var bob := (1.0 - cos(_phase * TAU * 2.0)) * 0.5 * _model_height * 0.03 * _amp
	var sway := sin(_phase * TAU) * 0.05 * _amp
	var br: Transform3D = rest[body]
	var ax: Dictionary = _axes[body]
	var basis := Basis(ax["fwd"], sway) * Basis(ax["right"], -0.06 * _amp) * br.basis
	var breath := 1.0 + sin(_time * 2.0) * 0.035 * (1.0 - _amp)
	body.transform = Transform3D(basis.scaled(Vector3(1.0, breath, 1.0)), br.origin + (ax["up"] as Vector3) * bob)
	if _amp < 0.3:
		_idle_shields()

# ---- DriveFeedback.AnimateTracks / AnimateEngine ----
func _animate_treads(delta: float) -> void:
	var moving := speed > 0.1
	for tr in treads:
		var up: Vector3 = _axes[tr]["up"]
		var buzz := sin(_time * (30.0 + speed * 12.0)) * _model_height * (0.006 if moving else 0.002)
		var r: Transform3D = rest[tr]
		tr.transform = Transform3D(r.basis, r.origin + up * buzz)
	# 滚筒：按速度滚动
	_drum_angle += speed * delta / maxf(_model_height * 0.25, 0.1)
	for ro in rotors:
		if str(ro.name).begins_with("Drum"):
			_rot(ro, "right", -_drum_angle)
	if rig_type == "tracked" or legs.is_empty():
		var br: Transform3D = rest[body]
		var ax: Dictionary = _axes[body]
		var engine := (sin(_time * 23.0) * 0.004 + sin(_time * 3.1) * 0.008) * _model_height
		var engine_roll := sin(_time * 17.0) * 0.006 * (1.0 if moving else 0.5)
		body.transform = Transform3D(Basis(ax["fwd"], engine_roll) * br.basis, br.origin + (ax["up"] as Vector3) * engine)

func _animate_flyer() -> void:
	var moving := speed > 0.2
	var flap_speed := 15.0 if moving else 10.0
	var flap := sin(_time * flap_speed)
	for w in wings:
		# 下拍快、上拍慢：给拍翅一点力量感
		var a := (flap if flap > 0.0 else flap * 0.7) * 0.75
		_rot(w, "fwd", a * float(_side[w]))
	var br: Transform3D = rest[body]
	var ax: Dictionary = _axes[body]
	var hover := _model_height * (0.4 + sin(_time * 2.4) * 0.06) - cos(_time * flap_speed) * _model_height * 0.025
	var bank := clampf(speed / 4.0, 0.0, 1.0) * 0.2
	body.transform = Transform3D(Basis(ax["right"], -bank) * br.basis, br.origin + (ax["up"] as Vector3) * hover)
	for tr in treads:
		var r2: Transform3D = rest[tr]
		tr.transform = Transform3D(r2.basis.scaled(Vector3.ONE * 0.85), r2.origin)

func _animate_orbit() -> void:
	var br: Transform3D = rest[body]
	var ax: Dictionary = _axes[body]
	body.transform = Transform3D(br.basis, br.origin + (ax["up"] as Vector3) * _model_height * (0.08 + sin(_time * 1.6) * 0.04))
	for i in rings.size():
		var ring := rings[i]
		var r: Transform3D = rest[ring]
		var side: float = _side[ring]
		var ang := _time * 1.8 * _phase_boost * side
		var up: Vector3 = _axes[ring]["up"]
		var orbit := (_axes[ring]["right"] as Vector3) * cos(ang) * 0.12 + up * sin(_time * 2.2 + i) * 0.15
		ring.transform = Transform3D(Basis(up, ang) * Basis(_axes[ring]["right"], sin(_time + i) * 0.3) * r.basis, r.origin + orbit)

func _animate_world_spin() -> void:
	_spin_amt = move_toward(_spin_amt, 1.0 if spin_enabled else 0.0, get_process_delta_time() * 0.8)
	_spin_angle += get_process_delta_time() * 2.4 * _spin_amt
	for ro in rotors:
		var r: Transform3D = rest[ro]
		var axis := Vector3.FORWARD if str(get_parent().name).contains("turbine") or rig_type == "world_spin" else Vector3.UP
		ro.transform = Transform3D(r.basis.rotated(axis, _spin_angle), r.origin)

func _animate_tops(_delta: float) -> void:
	for tp in tops:
		var r: Transform3D = rest[tp]
		var puff := 1.0 + maxf(0.0, sin(_time * 5.0)) * 0.12
		tp.transform = Transform3D(r.basis.scaled(Vector3(1.0, puff, 1.0)), r.origin)
	if rig_type == "turret":
		for ro in rotors:
			if not str(ro.name).begins_with("Drum"):
				_rot(ro, "fwd", _time * 3.0)
		for sh in shields:
			_rot(sh, "fwd", float(_side[sh]) * (0.06 + sin(_time * 1.5) * 0.03))

func _idle_breath() -> void:
	var br: Transform3D = rest[body]
	var breath := 1.0 + sin(_time * 2.0) * 0.035
	body.transform = Transform3D(br.basis.scaled(Vector3(1.0, breath, 1.0)), br.origin)
	_idle_shields()

func _idle_shields() -> void:
	for sh in shields:
		_rot(sh, "fwd", float(_side[sh]) * sin(_time * 1.2) * 0.04)

# ---- CannonFeedback：0-a 蓄力（反向）→ a-(a+0.15) 爆发 → 余下阻尼回弹 ----
static func attack_curve(t: float, a := 0.35) -> float:
	a = clampf(a, 0.05, 0.8)
	if t < a:
		var u := t / a
		return -(1.0 - (1.0 - u) * (1.0 - u))
	if t < a + 0.15:
		var u2 := (t - a) / 0.15
		return lerpf(-1.0, 1.0, u2 * u2)
	var u3 := (t - a - 0.15) / maxf(1.0 - a - 0.15, 0.05)
	return exp(-5.0 * u3) * cos(u3 * 9.0)

func _animate_tool(delta: float) -> void:
	if _tool_t < 0.0:
		for tl in tools:
			_rot(tl, "right", sin(_time * 1.7 + float(_side[tl])) * 0.03)
		return
	_tool_t += delta / maxf(_tool_dur, 0.05)
	var k := attack_curve(minf(_tool_t, 1.0), _tool_antic)
	var heavy := 1.6 if _tool_heavy else 1.25
	var h := _model_height
	for tl in tools:
		var nm := str(tl.name)
		var fwd: Vector3 = _axes[tl]["fwd"]
		if nm == "Jaw":
			# 张大（绕右轴负转）→ 猛合并过冲咬紧
			var a := (k * 0.6 if k < 0.0 else k * 0.5) * heavy
			_rot(tl, "right", a, fwd * h * 0.05 * maxf(k, 0.0) * heavy)
		elif nm.begins_with("Arm"):
			# 后摆蓄力 → 前砸
			var a2 := (k * 0.6 if k < 0.0 else k * 1.0) * heavy
			_rot(tl, "right", a2)
		elif nm == "Barrel":
			# 抬起蓄力 → 后坐
			_rot(tl, "right", -k * 0.22, -fwd * h * 0.1 * maxf(k, 0.0) * heavy)
		else:
			# Head / Tool / Boom / Crane：抬起 → 砸下前伸
			var a3 := (-k * 0.4 if k < 0.0 else -k * 0.6) * heavy
			_rot(tl, "right", a3, fwd * h * 0.08 * maxf(k, 0.0) * heavy)
	# 身体跟着出力：蓄力后坐抬头、出手前扑并沿前向拉长（挤压-拉伸）
	var br: Transform3D = body.transform
	var ax: Dictionary = _axes[body]
	var f: Vector3 = ax["fwd"]
	var stretch := 1.0 + 0.14 * k * heavy
	var squash := 1.0 - 0.07 * k * heavy
	var s_basis := Basis(Vector3(1, 0, 0) + f * f.x * (stretch - 1.0), Vector3(0, 1, 0) * squash, Vector3(0, 0, 1) + f * f.z * (stretch - 1.0))
	body.transform = Transform3D(Basis(ax["right"], -k * 0.08 * heavy) * s_basis * br.basis, br.origin + f * h * 0.09 * k * heavy)
	if _tool_t >= 1.0:
		_tool_t = -1.0

# ---- SimpleShaker + squash ----
func _animate_hit(delta: float) -> void:
	if _hit_t < 0.0:
		return
	_hit_t += delta / 0.3
	var decay := maxf(1.0 - _hit_t, 0.0)
	var shake := (right_m * sin(_hit_t * 70.0) + fwd_m * cos(_hit_t * 55.0)) * 0.04 * decay * _model_height
	var squash := 1.0 - 0.24 * decay * absf(cos(_hit_t * 12.0))
	var wide := 1.0 + (1.0 - squash) * 0.6
	# 后仰：快速向后倒 ~14° 再弹回（绕模型右轴）
	var recoil := sin(minf(_hit_t * 3.0, 1.0) * PI) * deg_to_rad(14.0) * decay
	var pivot := Vector3(0, 0, 0)
	var b := Basis(right_m, recoil) * Basis().scaled(Vector3(wide, squash, wide))
	model.transform = Transform3D(b, pivot - b * pivot + shake - fwd_m * _model_height * 0.06 * decay)
	if _hit_t >= 1.0:
		_hit_t = -1.0
		model.transform = Transform3D.IDENTITY

func _animate_spawn() -> void:
	if _spawn_t >= 1.0 or _hit_t >= 0.0:
		return
	var t := _spawn_t
	var s := 1.0 + sin(t * PI * 2.5) * exp(-4.0 * t) * 0.25
	model.scale = Vector3(1.0 / s, s, 1.0 / s) * clampf(t * 4.0, 0.0, 1.0)

# ---- DeathAnimationVehicle：上弹 → 落地回弹 + 侧翻；部件松脱 ----
func _animate_death(delta: float) -> void:
	_death_t += delta / _death_dur
	var t := minf(_death_t, 1.0)
	var h := _model_height * 0.5
	var y: float
	if t < 0.35:
		y = sin(t / 0.35 * PI * 0.5) * 0.5
	elif t < 0.6:
		y = lerpf(0.5, 0.0, ease((t - 0.35) / 0.25, 2.2))
	else:
		y = absf(sin((t - 0.6) / 0.4 * PI)) * 0.08 * (1.0 - t)
	var roll := ease(minf(t / 0.6, 1.0), 0.6) * deg_to_rad(95.0)
	var pivot := Vector3(0, h, 0)
	var basis := Basis(fwd_m, roll).scaled(Vector3.ONE * (1.0 - maxf(t - 0.7, 0.0) * 0.6))
	model.transform = Transform3D(basis, pivot - basis * pivot + Vector3(0, y, 0))
	var loose := maxf(t - 0.3, 0.0) / 0.7
	for nd in legs + tools + wings + shields + rings:
		var r: Transform3D = rest[nd]
		var dir := r.origin - (rest[body] as Transform3D).origin
		dir.y = 0.0
		dir = dir.normalized() if dir.length() > 0.01 else Vector3.RIGHT
		nd.transform = Transform3D(Basis(Vector3(dir.z, 0, -dir.x), loose * 1.6) * r.basis, r.origin + dir * loose * 0.6)
