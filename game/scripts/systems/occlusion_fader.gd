class_name OcclusionFader
extends Node

## C26 遮挡处理（俯视游戏的标准做法，对照 Wanderburg：高物件不挡在玩家和镜头之间 + 被挡住时能看到轮廓）。
## 两层：
##   1. 淡出：场景里的景物如果挡住了玩家 / 敌人 / Boss（在它们和镜头之间，屏幕上盖住它们），平滑淡到 25% 不透明
##   2. 剪影：玩家 / 敌人被任何东西挡住的部分，画一层纯色剪影（RigStyle 的 x-ray pass，见 rig_style.gd）
## 判定在屏幕空间做（正交镜头下屏幕矩形 = 真实遮挡），每 0.08s 一次，景物包围盒只算一次。

const FADED := 0.75        ## GeometryInstance3D.transparency：0 不透明，1 全透明
const FADE_SPEED := 6.0
const INTERVAL := 0.08
## 被盖住多少才算挡住：主体的屏幕点在景物屏幕矩形里（再往里收 6px，避免擦边闪烁）
const INSET := 6.0

var main: Node
var world: Node3D
var _props: Array = []       ## [{node, meshes: Array[GeometryInstance3D], aabb: AABB, cur: float, want: float}]
var _clock := 0.0
var fades_active := 0

func setup(main_node: Node, world_root: Node3D) -> void:
	main = main_node
	world = world_root
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_collect")

## 收集可淡出的景物：道具 holder（Prop_* / FormalProp_*），高于 0.7m 才有遮挡可能
func _collect() -> void:
	_props.clear()
	if world == null or not is_instance_valid(world):
		return
	for n in world.find_children("*", "Node3D", true, false):
		var s := str(n.name)
		if not (s.begins_with("Prop_") or s.begins_with("FormalProp_")):
			continue
		var meshes: Array = []
		var box := AABB()
		var have := false
		for m in (n as Node3D).find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			if mi.mesh == null:
				continue
			meshes.append(mi)
			var b := mi.global_transform * mi.get_aabb()
			box = b if not have else box.merge(b)
			have = true
		if not have or box.end.y < 0.7:
			continue
		_props.append({"node": n, "meshes": meshes, "aabb": box, "cur": 0.0, "want": 0.0})

func _subjects() -> Array:
	var out: Array = []
	if main == null:
		return out
	var p = main.get("player")
	if p != null and is_instance_valid(p):
		out.append([(p as Node3D).global_position, 1.0])
	for list_name in ["enemies", "gm_enemies"]:
		var lst = main.get(list_name)
		if lst is Array:
			for e in lst:
				if is_instance_valid(e) and not e.get("dead") and (e as Node3D).is_visible_in_tree():
					out.append([(e as Node3D).global_position, 0.5])
	var b = main.get("boss")
	if b != null and is_instance_valid(b) and not b.get("dead"):
		out.append([(b as Node3D).global_position, 1.4])
	return out

func _screen_rect(cam: Camera3D, box: AABB) -> Rect2:
	var r := Rect2()
	for i in 8:
		var sp := cam.unproject_position(box.get_endpoint(i))
		r = Rect2(sp, Vector2.ZERO) if i == 0 else r.expand(sp)
	return r.grow(-INSET)

func _process(delta: float) -> void:
	var real_dt := delta / maxf(Engine.time_scale, 0.05)
	_clock -= real_dt
	if _clock <= 0.0:
		_clock = INTERVAL
		_evaluate()
	fades_active = 0
	for e in _props:
		if not is_instance_valid(e["node"]):
			continue
		var cur: float = e["cur"]
		var want: float = e["want"]
		if absf(cur - want) > 0.001:
			cur = move_toward(cur, want, real_dt * FADE_SPEED)
			e["cur"] = cur
			for mi in e["meshes"]:
				if is_instance_valid(mi):
					(mi as GeometryInstance3D).transparency = cur
		if cur > 0.05:
			fades_active += 1

func _evaluate() -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return
	var subs := _subjects()
	for e in _props:
		var box: AABB = e["aabb"]
		var hide := false
		var rect := _screen_rect(cam, box)
		for s in subs:
			var pos: Vector3 = s[0]
			# 只有在主体“前面”（离镜头更近 = z 更大）且比主体所在处高的景物才算挡
			if box.end.z <= pos.z + 0.2:
				continue
			var sp := cam.unproject_position(pos + Vector3(0, float(s[1]) * 0.5, 0))
			if rect.has_point(sp):
				hide = true
				break
		e["want"] = FADED if hide else 0.0

## 测试用：某个景物当前是否处于淡出
func is_faded(node: Node) -> bool:
	for e in _props:
		if e["node"] == node:
			return float(e["cur"]) > 0.3
	return false
