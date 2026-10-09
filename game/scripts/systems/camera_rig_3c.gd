class_name CameraRig3C
extends RefCounted

## 3C 相机（docs/design/3c-v1.md §3）。对齐 Wanderburg CameraRig 的结构：
##   正交、固定俯角、不旋转；指数阻尼跟随 + 按速度前瞻（与瞄准解耦）；
##   进化分档缩放（回缩→冲过曲线）；Boss 在场额外缩放（SmoothDamp）；Boss 登场演出；冲刺尺寸冲击。
## 震屏不在这里：GameFeel 继续写 h/v_offset，两者不冲突。

var camera: Camera3D
var focus := Vector3.ZERO          # 相机注视的地面点（已含前瞻、已钳制）
var _follow := Vector3.ZERO        # 跟随点（指数阻尼追玩家）
var _lead := Vector3.ZERO          # 前瞻向量（指数阻尼追 速度×系数）
var size := 19.0
var _tier := 0
var _tier_from := 1.0
var _tier_to := 1.0
var _tier_t := 1.0
var _boss_mult := 1.0
var _boss_vel := 0.0
var _intro := {}                   # 演出状态；空 = 无
var aspect := 16.0 / 9.0
var _snapped := false

## 原作 zoomOutCurve 关键帧：先回缩、再冲过、最后落定
const ZOOM_OUT_KEYS := [[0.0, 0.0], [0.201, -0.339], [0.901, 1.028], [1.0, 1.0]]

func setup(cam: Camera3D) -> void:
	camera = cam
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	size = Tuning3C.get_f("camera", "base_size")
	camera.size = size
	camera.current = true

func t(key: String) -> float:
	return Tuning3C.get_f("camera", key)

## 进化分档（0..3）
func set_tier(rank: int) -> void:
	var scales: Array = Tuning3C.get_v("camera", "tier_scale")
	var r := clampi(rank, 0, scales.size() - 1)
	if r == _tier:
		return
	_tier_from = _current_tier_scale()
	_tier_to = float(scales[r])
	_tier = r
	_tier_t = 0.0

func tier() -> int:
	return _tier

func _current_tier_scale() -> float:
	return lerpf(_tier_from, _tier_to, _curve(_tier_t))

static func _curve(x: float) -> float:
	if x >= 1.0:
		return 1.0
	for i in range(ZOOM_OUT_KEYS.size() - 1):
		var a: Array = ZOOM_OUT_KEYS[i]
		var b: Array = ZOOM_OUT_KEYS[i + 1]
		if x <= float(b[0]):
			var u := (x - float(a[0])) / maxf(float(b[0]) - float(a[0]), 1e-4)
			return lerpf(float(a[1]), float(b[1]), u * u * (3.0 - 2.0 * u))
	return 1.0

## Boss 登场演出：相机飞向 Boss → 缩近停留 → 返回。real-time 驱动，期间玩法慢放。
func start_boss_intro(boss_pos: Vector3) -> bool:
	if not bool(Tuning3C.get_v("camera", "boss_intro")) or DisplayServer.get_name() == "headless" or camera == null:
		return false
	_intro = {"t": 0.0, "from": focus, "to": Vector3(boss_pos.x, 0.0, boss_pos.z + 2.0), "size0": size}
	if GameFeel.instance != null:
		GameFeel.instance.slowmo(0.08, t("boss_intro_move") + t("boss_intro_hold") + t("boss_intro_return") * 0.5)
	return true

func intro_active() -> bool:
	return not _intro.is_empty()

## 每帧调用。player_pos/player_vel 为玩家位置与平面速度；boss_on 是否 Boss 在场
func update(delta: float, player_pos: Vector3, player_vel: Vector3, boss_on: bool) -> void:
	if camera == null:
		return
	var real_dt := delta / maxf(Engine.time_scale, 0.001)
	if camera.get_viewport() != null:
		var vp := camera.get_viewport().get_visible_rect().size
		if vp.y > 1.0:
			aspect = vp.x / vp.y
	var target := Vector3(player_pos.x, 0.0, player_pos.z)
	var planar_v := Vector3(player_vel.x, 0.0, player_vel.z)
	var lead_target := planar_v * t("lead_mult")
	if lead_target.length() > t("lead_max"):
		lead_target = lead_target.normalized() * t("lead_max")
	if not _snapped:
		_follow = target
		_lead = Vector3.ZERO
		_snapped = true
	# 指数阻尼（帧率无关）
	_follow = _follow.lerp(target, 1.0 - exp(-t("follow_k") * delta))
	_lead = _lead.lerp(lead_target, 1.0 - exp(-t("lead_k") * delta))
	# 尺寸：分档 × Boss × 冲击
	_tier_t = minf(1.0, _tier_t + real_dt / maxf(t("tier_zoom_time"), 0.05))
	var boss_target := t("boss_scale") if boss_on else 1.0
	_boss_mult = _smooth_damp(_boss_mult, boss_target, real_dt, t("boss_smooth_time"))
	var punch := 0.0
	if GameFeel.instance != null:
		punch = float(GameFeel.instance.get("_fov_kick")) * t("zoom_punch_per_fov")
	var base := t("base_size") * _current_tier_scale() * _boss_mult
	size = base * (1.0 - punch)
	var want := _clamp_focus(_follow + _lead, size)
	if not _intro.is_empty():
		want = _update_intro(real_dt, want)
	focus = want
	_apply()

func _update_intro(real_dt: float, normal_focus: Vector3) -> Vector3:
	var mv := t("boss_intro_move")
	var hold := t("boss_intro_hold")
	var ret := t("boss_intro_return")
	_intro["t"] = float(_intro["t"]) + real_dt
	var tt := float(_intro["t"])
	var to: Vector3 = _intro["to"]
	var zoom := t("boss_intro_zoom")
	if tt < mv:
		var u := _ease_out_back(tt / mv)
		size *= lerpf(1.0, zoom, clampf(u, 0.0, 1.0))
		return (_intro["from"] as Vector3).lerp(to, u)
	if tt < mv + hold:
		# 到达抖动：尺寸小幅阻尼振荡
		var w := tt - mv
		var wob := 0.0
		if w < t("boss_intro_wobble"):
			var k := 1.0 - w / t("boss_intro_wobble")
			wob = sin(w / t("boss_intro_wobble") * TAU * 3.0) * k * t("boss_intro_wobble_strength") * 0.1
		size *= zoom * (1.0 - 0.04 + wob)
		return to
	if tt < mv + hold + ret:
		var u := (tt - mv - hold) / ret
		u = u * u * (3.0 - 2.0 * u)
		size *= lerpf(zoom, 1.0, u)
		return to.lerp(normal_focus, u)
	_intro = {}
	return normal_focus

static func _ease_out_back(x: float) -> float:
	var c1 := 1.4
	var c3 := c1 + 1.0
	var y := x - 1.0
	return 1.0 + c3 * y * y * y + c1 * y * y

func _smooth_damp(cur: float, target: float, dt: float, smooth_time: float) -> float:
	var omega := 2.0 / maxf(smooth_time, 0.01)
	var x := omega * dt
	var e := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change := cur - target
	var temp := (_boss_vel + omega * change) * dt
	_boss_vel = (_boss_vel - omega * temp) * e
	return target + (change + temp) * e

## 地面可视半宽/半深（正交 + 俯角）
func view_half_extents(s: float) -> Vector2:
	var pitch := deg_to_rad(t("pitch_deg"))
	return Vector2(s * aspect * 0.5, s * 0.5 / maxf(sin(pitch), 0.1))

func _clamp_focus(p: Vector3, s: float) -> Vector3:
	var arena: Array = Tuning3C.get_v("camera", "arena_half")
	var half := view_half_extents(s)
	var m := t("edge_margin")
	var mx := maxf(0.0, float(arena[0]) + m - half.x)
	var mz := maxf(0.0, float(arena[1]) + m - half.y)
	return Vector3(clampf(p.x, -mx, mx), 0.0, clampf(p.z, -mz, mz))

func _apply() -> void:
	var pitch := deg_to_rad(t("pitch_deg"))
	var back := Vector3(0.0, sin(pitch), cos(pitch))
	camera.size = size
	camera.position = focus + back * t("distance")
	camera.rotation = Vector3(-pitch, 0.0, 0.0)

## 玩家在屏幕上的归一化位置（0..1）；测试与调试用
func screen_uv(world: Vector3) -> Vector2:
	if camera == null or camera.get_viewport() == null:
		return Vector2(0.5, 0.5)
	var vp := camera.get_viewport().get_visible_rect().size
	return camera.unproject_position(world) / vp
