class_name AnimJuice
extends Node3D

## C22 动画弹性层（只表现）。插在 ProceduralRig 与 Facing 之间，对整只模型做“二级姿态”：
##   挤压/拉伸（Squash & Stretch）     sq：竖向压扁(+) / 拉高(-)；st：沿水平方向拉长（向量）
##   倾斜（跟随 / 预备的身体语言）     tilt：旋转向量，方向 = 顶部倒向 up×tilt
##   扭转 yaw、抬升 lift、平推 push
##   二级跟随 lag：低频弹簧追身体倾斜，挂件按 (lag - tilt) 甩动 —— Follow-through / Overlapping
## 全部是阻尼弹簧（Slow in/out + 回弹过冲），所以任何冲量都会自然地“压→弹→过冲→落定”。
## 坐标：rig 本地，-Z = 正面，+Y = 上；轴心在地面（像压在轮子/脚上摇晃）。
## 响应原则：玩家输入一律在第 0 帧 snap 出可见姿态（预备压缩 ≤ 60ms），再接动作 —— 不会“按了没反应”。

class Spring:
	var x := Vector3.ZERO
	var v := Vector3.ZERO
	var target := Vector3.ZERO
	var freq := 5.0
	var zeta := 0.4
	func _init(f: float, z: float) -> void:
		freq = f
		zeta = z
	func step(dt: float) -> void:
		var w := TAU * freq
		# 半隐式欧拉，子步保证稳定
		var n := maxi(1, int(ceil(dt / 0.008)))
		var h := dt / n
		for i in n:
			v += (-(w * w) * (x - target) - 2.0 * zeta * w * v) * h
			x += v * h
	func settled(eps := 0.004) -> bool:
		return (x - target).length() < eps and v.length() < eps * 10.0

var sq := Spring.new(3.2, 0.30)      # x 分量
var st := Spring.new(3.0, 0.36)      # 水平向量
var tilt := Spring.new(2.6, 0.40)    # 旋转向量（x / z）
var yaw := Spring.new(3.2, 0.32)     # x 分量
var lift := Spring.new(2.8, 0.55)    # x 分量（米）
var push := Spring.new(4.0, 0.55)    # 水平向量（米）
var lag := Spring.new(1.8, 0.24)     # 追 tilt + yaw（x,z = tilt, y = yaw）

var height := 1.0
## 全局夸张系数（俯视远镜头下需要放大）
static var exaggeration := 1.0
## 单体放大：小体型在俯视镜头下需要更大幅度才看得出
var boost := 1.0
func _ex() -> float:
	return exaggeration * boost
## 持续驱动目标（由 ProceduralRig 每帧按加速度 / 角速度写入）
var drive_tilt := Vector3.ZERO
var drive_stretch := Vector3.ZERO
var hold_sq := 0.0
var hold_tilt := Vector3.ZERO
var _queue: Array = []
var _t := 0.0
## 观测（测试 / 调试）：本帧姿态偏离静止的程度
var deviation := 0.0
var peak := {"sq": 0.0, "st": 0.0, "tilt": 0.0, "yaw": 0.0, "lift": 0.0}

func _ready() -> void:
	name = "AnimJuice"

# ------------------------------------------------------------ 基础冲量

func snap_squash(a: float) -> void:
	sq.x.x = clampf(a * _ex(), -0.45, 0.5)
	sq.v.x = 0.0

func kick_squash(vel: float) -> void:
	sq.v.x += vel * _ex()

## 顶部倒向 top_dir（本地水平方向），angle 弧度
func snap_lean(top_dir: Vector3, angle: float) -> void:
	tilt.x = _lean_vec(top_dir, angle * _ex())
	tilt.v = Vector3.ZERO

func kick_lean(top_dir: Vector3, ang_vel: float) -> void:
	tilt.v += _lean_vec(top_dir, ang_vel * _ex())

func snap_stretch(dir: Vector3, e: float) -> void:
	var d := Vector3(dir.x, 0, dir.z)
	st.x = d.normalized() * clampf(e * _ex(), -0.4, 0.65) if d.length() > 0.01 else Vector3.ZERO
	st.v = Vector3.ZERO

func snap_yaw(a: float) -> void:
	yaw.x.x = a * _ex()
	yaw.v.x = 0.0

func kick_yaw(vel: float) -> void:
	yaw.v.x += vel * _ex()

func kick_lift(vel: float) -> void:
	lift.v.x += vel * height * _ex()

func kick_push(dir: Vector3, vel: float) -> void:
	var d := Vector3(dir.x, 0, dir.z)
	if d.length() > 0.01:
		push.v += d.normalized() * vel * height * _ex()

func after(sec: float, fn: Callable) -> void:
	_queue.append([_t + sec, fn])

static func _lean_vec(top_dir: Vector3, angle: float) -> Vector3:
	var d := Vector3(top_dir.x, 0, top_dir.z)
	if d.length() < 0.01:
		return Vector3.ZERO
	# 绕 a 旋转时顶部倒向 a×up；要倒向 d，取 a = up×d
	return Vector3.UP.cross(d.normalized()) * angle

## 只取朝向（绕 Y）的逆矩阵：父节点缩放为 0（出生 / 换形动画）时也不会奇异
static func yaw_inverse(b: Basis) -> Basis:
	var z := Vector3(b.z.x, 0.0, b.z.z)
	if z.length() < 1e-5:
		var x := Vector3(b.x.x, 0.0, b.x.z)
		if x.length() < 1e-5:
			return Basis.IDENTITY
		return Basis(Vector3.UP, atan2(x.x, x.z) - PI * 0.5).inverse()
	return Basis(Vector3.UP, atan2(z.x, z.z)).inverse()

func world_to_local_dir(w: Vector3) -> Vector3:
	if not is_inside_tree():
		return w
	var l := yaw_inverse(global_basis) * Vector3(w.x, 0, w.z)
	return Vector3(l.x, 0, l.z)

# ------------------------------------------------------------ 组合动作（12 法则）

## 预备（Anticipation）：压低 + 后仰。time < 0.08 直接 snap（玩家输入），否则缓慢蓄力（敌人前摇）
func anticipate(amount: float, time: float, back := Vector3(0, 0, 1)) -> void:
	var b := Vector3(back.x, 0, back.z).normalized() if back.length() > 0.01 else Vector3(0, 0, 1)
	if time < 0.08:
		snap_squash(0.16 * amount)
		snap_lean(b, 0.16 * amount)
		snap_stretch(b, -0.08 * amount)
		push.x = b * height * 0.08 * amount * _ex()
		push.v = Vector3.ZERO
	else:
		hold_sq = 0.3 * amount
		hold_tilt = _lean_vec(b, 0.3 * amount)
		hold_push = b * height * 0.22 * amount * _ex()

var hold_push := Vector3.ZERO

## 出手（Action + Follow-through）：清掉蓄力，前扑 + 沿前方拉长 + 竖向拉高，弹簧回弹过冲收尾
func release(amount: float, fwd := Vector3(0, 0, -1), heavy := false) -> void:
	hold_sq = 0.0
	hold_tilt = Vector3.ZERO
	hold_push = Vector3.ZERO
	var k := amount * (1.35 if heavy else 1.0)
	snap_squash(-0.16 * k)
	snap_stretch(fwd, 0.34 * k)
	snap_lean(fwd, 0.2 * k)
	kick_push(fwd, 3.2 * k)
	if heavy:
		kick_lift(2.2 * k)
		# 重击落地：压扁 + 前倾回落
		after(0.16, func():
			snap_squash(0.3 * k)
			kick_lean(fwd, 2.5 * k))

## 受击：沿受力方向倒 + 压扁 + 往后推
func hit_from(push_dir: Vector3, amount := 1.0) -> void:
	snap_squash(0.2 * amount)
	if push_dir.length() > 0.01:
		snap_lean(push_dir, 0.3 * amount)
		snap_stretch(push_dir, -0.18 * amount)
		kick_push(push_dir, 2.2 * amount)
	else:
		kick_yaw(5.0 * amount * (1.0 if randf() < 0.5 else -1.0))

## 起跳 / 落地（弧线由宿主负责）
func takeoff(amount := 1.0) -> void:
	snap_squash(-0.3 * amount)

func land(amount := 1.0) -> void:
	snap_squash(0.34 * amount)
	kick_yaw(randf_range(-1.5, 1.5) * amount)

## 拒绝（无货 / 冷却中 / 槽位空）：原地左右甩“摇头” + 轻压
func deny() -> void:
	snap_yaw(0.22)
	yaw.v.x = 0.0
	snap_squash(0.08)

## 施法：小跳 + 落地压
func cast_pop(amount := 1.0) -> void:
	snap_squash(0.18 * amount)
	after(0.04, func():
		snap_squash(-0.22 * amount)
		kick_lift(2.0 * amount))
	after(0.2, func(): snap_squash(0.16 * amount))

# ------------------------------------------------------------ 主循环

func _process(delta: float) -> void:
	_t += delta
	var i := 0
	while i < _queue.size():
		if _t >= float(_queue[i][0]):
			var fn: Callable = _queue[i][1]
			_queue.remove_at(i)
			if fn.is_valid():
				fn.call()
		else:
			i += 1
	sq.target = Vector3(hold_sq, 0, 0)
	tilt.target = hold_tilt + drive_tilt
	st.target = drive_stretch
	push.target = hold_push
	for s in [sq, st, tilt, yaw, lift, push]:
		s.step(delta)
	lag.target = Vector3(tilt.x.x, yaw.x.x, tilt.x.z)
	lag.step(delta)
	# 落地不穿地；平推上限
	if lift.x.x < 0.0:
		lift.x.x = 0.0
		lift.v.x = absf(lift.v.x) * 0.25
	if push.x.length() > height * 0.6:
		push.x = push.x.normalized() * height * 0.6
	_apply()

func _apply() -> void:
	var q := clampf(sq.x.x, -0.45, 0.5)
	var vert := 1.0 - q
	var horiz := 1.0 / sqrt(maxf(vert, 0.2))
	var S := Basis.from_scale(Vector3(horiz, vert, horiz))
	var e := st.x.length()
	if e > 0.002 or e < -0.002:
		var u := st.x / maxf(e, 1e-4)
		e = clampf(e, -0.4, 0.65)
		var b := 1.0 + e
		var a := 1.0 / sqrt(maxf(b, 0.3))
		var cols := []
		for idx in 3:
			var ei := Vector3.ZERO
			ei[idx] = 1.0
			cols.append(ei * a + u * (b - a) * u[idx])
		S = Basis(cols[0], cols[1], cols[2]) * S
	var tv := tilt.x
	var ta := tv.length()
	var R := Basis(tv / ta, clampf(ta, 0.0, 0.9)) if ta > 1e-4 else Basis.IDENTITY
	R = Basis(Vector3.UP, clampf(yaw.x.x, -1.2, 1.2)) * R
	transform = Transform3D(R * S, Vector3(push.x.x, lift.x.x, push.x.z))
	deviation = absf(q) + absf(e) + ta + absf(yaw.x.x) + lift.x.x / maxf(height, 0.1) + push.x.length() / maxf(height, 0.1)
	peak["sq"] = maxf(peak["sq"], absf(q))
	peak["st"] = maxf(peak["st"], absf(e))
	peak["tilt"] = maxf(peak["tilt"], ta)
	peak["yaw"] = maxf(peak["yaw"], absf(yaw.x.x))
	peak["lift"] = maxf(peak["lift"], lift.x.x)

func reset_peaks() -> void:
	for k in peak.keys():
		peak[k] = 0.0

## 当前弹簧姿态幅度（不依赖本帧 _apply 是否已执行）
func pose_magnitude() -> float:
	return absf(sq.x.x) + st.x.length() + tilt.x.length() + absf(yaw.x.x)

## 二级跟随量：挂件额外旋转（相对身体滞后的部分）
func follow_through() -> Vector3:
	return Vector3(lag.x.x - tilt.x.x, lag.x.y - yaw.x.x, lag.x.z - tilt.x.z)
