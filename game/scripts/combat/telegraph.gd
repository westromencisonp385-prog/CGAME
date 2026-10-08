class_name Telegraph
extends Node3D

## C17 攻击预警（读招窗口）：地面先出红色轮廓，内圈/内条从 0 涨满，涨满瞬间结算并闪一下。
## 敌人、精英、Boss、玩家迫击类技能都用它——“看得见才躲得开”是好手感的前提。
##   Telegraph.circle(parent, at, radius, delay, on_fire)
##   Telegraph.line(parent, from, dir, length, width, delay, on_fire)
## on_fire 在涨满时调用一次（参数：中心点 Vector3）。

const ENEMY_COLOR := Color("#D9412B")
const PLAYER_COLOR := Color("#E3A52B")

var shape := "circle"
var radius := 2.0
var length := 6.0
var width := 1.2
var delay := 0.8
var color := ENEMY_COLOR
var on_fire: Callable
var _t := 0.0
var _fired := false
var _fill: MeshInstance3D
var _edge: MeshInstance3D
var _fill_mat: StandardMaterial3D
var _edge_mat: StandardMaterial3D

static func circle(parent: Node, at: Vector3, r: float, wait: float, fire: Callable, tint := ENEMY_COLOR) -> Telegraph:
	var t := Telegraph.new()
	t.shape = "circle"
	t.radius = r
	t.delay = wait
	t.on_fire = fire
	t.color = tint
	t.position = Vector3(at.x, 0.05, at.z)
	parent.add_child(t)
	return t

static func line(parent: Node, from: Vector3, dir: Vector3, len: float, w: float, wait: float, fire: Callable, tint := ENEMY_COLOR) -> Telegraph:
	var t := Telegraph.new()
	t.shape = "line"
	t.length = len
	t.width = w
	t.delay = wait
	t.on_fire = fire
	t.color = tint
	var d := Vector3(dir.x, 0, dir.z).normalized()
	t.position = Vector3(from.x, 0.05, from.z)
	t.rotation.y = atan2(-d.x, -d.z)
	parent.add_child(t)
	return t

func _ready() -> void:
	name = "Telegraph"
	_edge_mat = _mat(Color(color, 0.95))
	_fill_mat = _mat(Color(color, 0.45))
	if shape == "circle":
		_edge = MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = radius - 0.28
		tm.outer_radius = radius
		tm.rings = 32
		tm.ring_segments = 4
		_edge.mesh = tm
		_edge.scale = Vector3(1, 0.05, 1)
		_edge.material_override = _edge_mat
		add_child(_edge)
		_fill = MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = radius
		cm.bottom_radius = radius
		cm.height = 0.02
		cm.radial_segments = 32
		_fill.mesh = cm
		_fill.material_override = _fill_mat
		_fill.scale = Vector3(0.05, 1, 0.05)
		add_child(_fill)
	else:
		_edge = MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(width, 0.02, length)
		_edge.mesh = bm
		_edge.position = Vector3(0, 0, -length * 0.5)
		_edge.material_override = _mat(Color(color, 0.3))
		add_child(_edge)
		_fill = MeshInstance3D.new()
		var fm := BoxMesh.new()
		fm.size = Vector3(width, 0.03, length)
		_fill.mesh = fm
		_fill.material_override = _fill_mat
		_fill.scale = Vector3(1, 1, 0.02)
		_fill.position = Vector3(0, 0.01, 0)
		add_child(_fill)

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _process(delta: float) -> void:
	if _fired:
		return
	_t += delta
	var k := clampf(_t / maxf(delay, 0.01), 0.0, 1.0)
	# 越接近结算越快地闪：最后 30% 时间边框快速脉动，提示「现在躲」
	if _edge_mat != null and k > 0.7:
		_edge_mat.albedo_color.a = 0.55 + 0.45 * absf(sin(_t * 28.0))
	if shape == "circle":
		var s := lerpf(0.05, 1.0, ease(k, 0.6))
		_fill.scale = Vector3(s, 1, s)
	else:
		_fill.scale = Vector3(1, 1, maxf(0.02, k))
		_fill.position = Vector3(0, 0.01, -length * 0.5 * k)
	if k >= 1.0:
		_fire()

func _fire() -> void:
	_fired = true
	var center := global_position
	if shape == "line":
		center = global_position + (-global_transform.basis.z) * length * 0.5
	if on_fire.is_valid():
		on_fire.call(center)
	_fill_mat.albedo_color = Color(1, 1, 1, 0.75)
	_fill.scale = Vector3(1, 1, 1) if shape == "circle" else Vector3(1, 1, 1)
	if shape == "line":
		_fill.position = Vector3(0, 0.01, -length * 0.5)
	var tw := create_tween()
	tw.tween_property(_fill_mat, "albedo_color:a", 0.0, 0.18)
	tw.parallel().tween_property(_edge_mat, "albedo_color:a", 0.0, 0.18)
	tw.tween_callback(queue_free)

## 测试 / 立即结算
func force_fire() -> void:
	if not _fired:
		_t = delay
		_fire()
