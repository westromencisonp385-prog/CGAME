extends SceneTree

## C19 3C 验收（docs/design/3c-v1.md §4）：在真实主场景里用模拟输入开车，测量手感指标。
## 每项打印实测值，便于调参时对比；任何一项不达标即 FAIL。

var main_scene: Node
var p: Node
var failures: Array[String] = []
const DT := 1.0 / 60.0

func _init() -> void:
	call_deferred("_run")

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FAIL ") + msg)
	if not ok:
		failures.append(msg)

func _phys(n: int) -> void:
	for _i in n:
		await physics_frame

func _release_all() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "primary", "dash"]:
		Input.action_release(a)

func _place(at: Vector3, heading: Vector3) -> void:
	_release_all()
	p.global_position = at
	p.velocity = Vector3.ZERO
	p.heading = heading.normalized()
	p._fwd_speed = 0.0
	p.knock_velocity = Vector3.ZERO
	await _phys(3)

func _speed() -> float:
	return Vector2(p.velocity.x, p.velocity.z).length()

func _run() -> void:
	main_scene = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main_scene)
	await _phys(30)
	var gm: Node = main_scene.get("gm")
	gm.execute("invulnerable", {"enabled": true})
	gm.execute("clear_enemies", {})
	gm.execute("panel", {"open": false})
	# 测试车道上不要有可碰撞的工程目标
	for t in get_nodes_in_group("engineering_targets"):
		var body: Variant = t.get("collision_body")
		if body is StaticBody3D:
			(body as StaticBody3D).collision_layer = 0
	p = main_scene.player
	var vmax: float = p.max_speed
	print("max_speed %.2f" % vmax)

	# 1. 起步：静止 → 90% 最大速度
	await _place(Vector3(-10, 0.5, 8), Vector3.RIGHT)
	Input.action_press("move_right")
	var frames := 0
	while _speed() < vmax * 0.9 and frames < 120:
		await _phys(1)
		frames += 1
	check(frames * DT <= 0.40, "起步到 90%% 速度 %.2fs (≤0.40)" % (frames * DT))
	# 2. 直线侧滑
	await _phys(20)
	var lat: Vector3 = Vector3(p.velocity.x, 0, p.velocity.z) - p.heading * p._fwd_speed
	check(lat.length() < 0.05 * absf(p._fwd_speed), "直线侧向速度 %.3f (<5%% 前向)" % lat.length())
	# 3. 满速 90° 转向
	await _place(Vector3(-12, 0.5, -12), Vector3.RIGHT)
	Input.action_press("move_right")
	await _phys(40)
	Input.action_release("move_right")
	Input.action_press("move_down")
	frames = 0
	var min_speed := 99.0
	while rad_to_deg(p.heading.angle_to(Vector3.BACK)) > 5.0 and frames < 120:
		await _phys(1)
		frames += 1
		min_speed = minf(min_speed, _speed())
	check(frames * DT <= 0.40, "满速 90° 转向 %.2fs (≤0.40)" % (frames * DT))
	check(min_speed >= 0.7 * vmax, "转向中最低速度 %.0f%% (≥70%%)" % (min_speed / vmax * 100.0))
	# 4. 180° 掉头
	await _phys(20)
	Input.action_release("move_down")
	Input.action_press("move_up")
	frames = 0
	while rad_to_deg(p.heading.angle_to(Vector3.FORWARD)) > 5.0 and frames < 120:
		await _phys(1)
		frames += 1
	check(frames * DT <= 0.65, "180° 掉头 %.2fs (≤0.65)" % (frames * DT))
	# 5. 刹停
	await _phys(30)
	_release_all()
	frames = 0
	while _speed() > 0.2 and frames < 120:
		await _phys(1)
		frames += 1
	check(frames * DT <= 0.35, "松手刹停 %.2fs (≤0.35)" % (frames * DT))
	# 6. 冲刺方向跟输入，不跟瞄准
	await _place(Vector3(6, 0.5, 8), Vector3.FORWARD)
	p.dash_cooldown = 0.0
	Input.action_press("move_left")
	await _phys(2)
	p.aim_direction = Vector3.RIGHT
	p.try_dash()
	await _phys(1)
	var dash_dir := Vector3(p.velocity.x, 0, p.velocity.z).normalized()
	check(rad_to_deg(dash_dir.angle_to(Vector3.LEFT)) < 10.0, "冲刺方向偏离输入 %.1f° (<10°，瞄准朝右)" % rad_to_deg(dash_dir.angle_to(Vector3.LEFT)))
	_release_all()
	await _phys(40)

	# 7. 相机与瞄准解耦
	var rig: CameraRig3C = main_scene.get("cam_rig")
	await _place(Vector3(0, 0.5, 2), Vector3.FORWARD)
	await _phys(300)
	var ctl0: Vector3 = main_scene.world.camera.global_position
	await _phys(30)
	var control_drift: float = main_scene.world.camera.global_position.distance_to(ctl0)
	var cam0: Vector3 = main_scene.world.camera.global_position
	for i in 30:
		p.aim_direction = Vector3.RIGHT.rotated(Vector3.UP, float(i) * 0.7)
		p.aim_mode = "pad" if i % 2 == 0 else "mouse"
		await _phys(1)
	p.aim_mode = "mouse"
	var drift: float = main_scene.world.camera.global_position.distance_to(cam0)
	check(drift <= control_drift + 0.002, "晃动瞄准时相机位移 %.4fm（对照 %.4fm）" % [drift, control_drift])
	# 8. 相机俯角
	check(absf(main_scene.world.camera.rotation_degrees.x + Tuning3C.get_f("camera", "pitch_deg")) < 0.5, "相机俯角 %.1f°" % -main_scene.world.camera.rotation_degrees.x)
	# 9. 行驶时相机超前、玩家在中央区
	await _place(Vector3(-4, 0.5, 2), Vector3.RIGHT)
	await _phys(60)
	Input.action_press("move_right")
	await _phys(48)
	var uv: Vector2 = rig.screen_uv(p.global_position)
	var ahead: float = rig.focus.x - p.global_position.x
	_release_all()
	check(uv.x > 0.3 and uv.x < 0.7 and uv.y > 0.3 and uv.y < 0.7, "行驶中玩家屏幕位置 (%.2f, %.2f) 在中央 40%%" % [uv.x, uv.y])
	check(ahead > 0.0, "相机在行进方向超前 %.2fm" % ahead)
	# 10. 场地角落：露出墙外 ≤ 4.5m
	await _place(Vector3(16.5, 0.5, 14.5), Vector3.RIGHT)
	await _phys(180)
	var half: Vector2 = rig.view_half_extents(rig.size)
	var over_x: float = rig.focus.x + half.x - 18.0
	var over_z: float = rig.focus.z + half.y - 16.0
	check(over_x <= 4.5 and over_z <= 4.5, "角落露出墙外 x=%.1fm z=%.1fm (≤4.5)" % [over_x, over_z])
	# 11. 进化分档拉远
	var base_size: float = rig.size
	rig.set_tier(2)
	await _phys(90)
	check(rig.size > base_size * 1.35, "进化 rank2 相机尺寸 %.1f → %.1f" % [base_size, rig.size])
	rig.set_tier(0)
	await _phys(90)
	# 12. Boss 在场拉远
	var before_boss: float = rig.size
	gm.execute("boss_next", {})
	gm.execute("freeze_ai", {"enabled": true})
	await _phys(150)
	check(rig.size > before_boss * 1.12, "Boss 在场相机尺寸 %.1f → %.1f" % [before_boss, rig.size])
	# 13. 朝向：车的 Jaw 在车头方向；敌人前部件指向玩家
	gm.execute("clear_enemies", {})
	await _place(Vector3(0, 0.5, 6), Vector3.RIGHT)
	Input.action_press("move_right")
	await _phys(30)
	_release_all()
	await _phys(20)
	var jaw := p.body_rig.model.find_child("Jaw", true, false) as Node3D if p.body_rig != null else null
	if jaw != null:
		var to_jaw: Vector3 = _mesh_center(jaw) - _mesh_center(p.body_rig.model.find_child("Body", true, false))
		to_jaw.y = 0.0
		check(rad_to_deg(to_jaw.normalized().angle_to(p.heading)) < 35.0, "鲸口在车头方向（偏差 %.0f°）" % rad_to_deg(to_jaw.normalized().angle_to(p.heading)))
	gm.execute("freeze_ai", {"enabled": false})
	gm.execute("spawn", {"kind": "mantis", "count": 1})
	await _phys(2)
	var foe: Node = null
	for e in main_scene.get("gm_enemies"):
		if is_instance_valid(e) and e.get("rig") != null:
			foe = e
	if foe != null:
		foe.global_position = p.global_position + Vector3(0, 0, -6)
		await _phys(80)
		var r: ProceduralRig = foe.rig
		var front: Node3D = null
		for n in ["Head", "Jaw", "Barrel", "Tool"]:
			front = r.model.find_child(n, true, false) as Node3D
			if front != null:
				break
		if front != null:
			var d: Vector3 = _mesh_center(front) - _mesh_center(r.model.find_child("Body", true, false))
			d.y = 0.0
			var to_p: Vector3 = p.global_position - foe.global_position
			to_p.y = 0.0
			if d.length() > 0.05:
				check(rad_to_deg(d.normalized().angle_to(to_p.normalized())) < 45.0, "敌人正面朝向玩家（偏差 %.0f°）" % rad_to_deg(d.normalized().angle_to(to_p.normalized())))
	print("C19 3C %s: %d failed" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)

func _mesh_center(n: Node) -> Vector3:
	var aabb := AABB()
	var first := true
	for mi in [n] + n.find_children("*", "MeshInstance3D", true, false):
		if not mi is MeshInstance3D:
			continue
		var b: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		aabb = b if first else aabb.merge(b)
		first = false
	return aabb.get_center()
