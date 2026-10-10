extends SceneTree

## C22 动画验收：按动画 12 法则量化检查 + “按键第 0 帧必有可见响应”。
##   响应：输入后 1 帧内姿态偏离 deviation > 阈值
##   预备 / 出手：先压低（sq>0）再拉长（st>0），顺序正确
##   跟随 / 过冲：挤压量出现正负两侧（压 → 弹过头）
##   夸张：峰值达到俯视可读的幅度
##   落定：动作结束 1.2s 内回到静止
##   受击方向：身体倒向远离攻击者
var failures: Array[String] = []
var main: Node

func _init() -> void:
	call_deferred("_run")

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FAIL ") + msg)
	if not ok:
		failures.append(msg)

func _frames(n: int) -> void:
	for _i in n:
		await process_frame

## 采样 sec 秒：返回 {sq_min, sq_max, st_max, tilt_max, yaw_min, yaw_max, dev_end}
func _sample(j: AnimJuice, sec: float) -> Dictionary:
	var r := {"sq_min": 0.0, "sq_max": 0.0, "st_max": 0.0, "tilt_max": 0.0, "yaw_min": 0.0, "yaw_max": 0.0, "lift_max": 0.0}
	var t := 0.0
	while t < sec:
		await process_frame
		t += maxf(root.get_process_delta_time(), 0.001)
		r["sq_min"] = minf(r["sq_min"], j.sq.x.x)
		r["sq_max"] = maxf(r["sq_max"], j.sq.x.x)
		r["st_max"] = maxf(r["st_max"], j.st.x.length())
		r["tilt_max"] = maxf(r["tilt_max"], j.tilt.x.length())
		r["yaw_min"] = minf(r["yaw_min"], j.yaw.x.x)
		r["yaw_max"] = maxf(r["yaw_max"], j.yaw.x.x)
		r["lift_max"] = maxf(r["lift_max"], j.lift.x.x)
	r["dev_end"] = j.deviation
	return r

func _settle(j: AnimJuice) -> void:
	var t := 0.0
	while t < 1.5 and j.deviation > 0.03:
		await process_frame
		t += maxf(root.get_process_delta_time(), 0.001)

func _run() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _frames(40)
	var gm: Node = main.get("gm")
	gm.execute("invulnerable", {"enabled": true})
	gm.execute("clear_enemies", {})
	var p: Node = main.player
	p.global_position = Vector3(0, 0.5, 6)
	p.velocity = Vector3.ZERO
	var rig: ProceduralRig = p._rig()
	check(rig != null and rig.juice != null, "玩家车挂了弹性层 AnimJuice")
	var j: AnimJuice = rig.juice
	await _settle(j)
	check(j.deviation < 0.06, "待机时接近静止 (dev=%.3f)" % j.deviation)

	# 1) 咬合：第 0 帧响应 + 预备→出手 + 过冲 + 落定
	p.primary_cooldown = 0.0
	p.aim_direction = Vector3(0, 0, -1)
	p.perform_primary()
	await process_frame
	var d1 := j.deviation
	check(d1 > 0.15, "左键咬合：1 帧内可见响应 (dev=%.3f > 0.15)" % d1)
	check(j.sq.x.x > 0.05, "咬合第 0 帧是预备姿态（先压低 sq=%.2f）" % j.sq.x.x)
	var antic_sq := j.sq.x.x
	var s := await _sample(j, 0.7)
	check(s["st_max"] >= 0.25, "咬合出手沿瞄准方向拉长 (st=%.2f >= 0.25)" % s["st_max"])
	check(s["tilt_max"] >= 0.15, "咬合前扑倾斜够大 (tilt=%.2f rad)" % s["tilt_max"])
	check(antic_sq > 0.08 and s["sq_min"] < -0.08, "先压后拉：预备压 %.2f → 出手拉 %.2f" % [antic_sq, s["sq_min"]])
	check(s["sq_max"] > 0.02, "拉长后回弹过冲再落定（follow-through 压 %.2f）" % s["sq_max"])
	await _sample(j, 0.8)
	check(j.deviation < 0.06, "咬合 1.5s 内落定 (dev=%.3f)" % j.deviation)

	# 2) 三段连击：第 1 / 2 段左右扭方向相反，第 3 段跳起
	var yaws := []
	var lifts := []
	for k in 3:
		p.primary_cooldown = 0.0
		p.perform_primary()
		await process_frame
		yaws.append(j.yaw.x.x)
		var sk := await _sample(j, 0.33)
		lifts.append(sk["lift_max"])
	check(float(yaws[0]) * float(yaws[1]) < 0.0, "连击 1/2 段扭向相反 (%.2f / %.2f)" % [yaws[0], yaws[1]])
	check(float(lifts[2]) > float(lifts[0]) + 0.05, "收尾段有跳起 (lift %.2f vs %.2f)" % [lifts[2], lifts[0]])
	await _settle(j)

	# 3) 冲刺：第 0 帧压缩，随后大幅拉长
	p.dash_cooldown = 0.0
	p._last_move_dir = Vector3(1, 0, 0)
	p.try_dash()
	await process_frame
	check(j.sq.x.x > 0.15, "Shift 冲刺：第 0 帧压缩蓄力 (sq=%.2f)" % j.sq.x.x)
	var sd := await _sample(j, 0.5)
	check(sd["st_max"] >= 0.4, "冲刺拉长夸张 (st=%.2f >= 0.4)" % sd["st_max"])
	await _settle(j)

	# 4) 冲刺冷却中再按：摇头（不是没反应）
	p.dash_cooldown = 1.0
	p._deny_anim_until = 0
	p.try_dash()
	await process_frame
	check(absf(j.yaw.x.x) > 0.15, "冷却中按 Shift：1 帧内摇头 (yaw=%.2f)" % j.yaw.x.x)
	var sn := await _sample(j, 0.5)
	check(sn["yaw_min"] < -0.04 and sn["yaw_max"] > 0.04, "摇头左右来回 (%.2f / %.2f)" % [sn["yaw_min"], sn["yaw_max"]])
	await _settle(j)

	# 5) 无货右键：摇头
	p.cargo = 0
	p.packed_enemy_ids.clear()
	p.throw_cooldown = 0.0
	p._deny_until = 0
	p.throw_cargo()
	await process_frame
	check(absf(j.yaw.x.x) > 0.15, "无货右键：1 帧内摇头 (yaw=%.2f)" % j.yaw.x.x)
	await _settle(j)

	# 6) 有货右键：预备后仰 → 甩出
	p.cargo = 2
	p.throw_cooldown = 0.0
	p.throw_cargo()
	await process_frame
	check(j.deviation > 0.12, "右键投掷：1 帧内响应 (dev=%.3f)" % j.deviation)
	var st := await _sample(j, 0.5)
	check(st["st_max"] >= 0.3, "投掷甩出拉长 (st=%.2f)" % st["st_max"])
	await _settle(j)

	# 7) 起步：按下方向键第 1 帧有蹬地姿态
	Input.action_press("move_right")
	await physics_frame
	await physics_frame
	check(j.pose_magnitude() > 0.15, "按下方向键：首个物理帧内起步姿态 (pose=%.3f)" % j.pose_magnitude())
	await _sample(j, 0.6)
	Input.action_release("move_right")
	await physics_frame
	await process_frame
	check(j.tilt.x.length() > 0.08, "松开方向键：刹车前栽 (tilt=%.2f)" % j.tilt.x.length())
	await _settle(j)

	# 8) 敌人：前摇蹲低（持续蓄力）→ 出手拉长
	gm.execute("freeze_ai", {"enabled": true})
	gm.execute("spawn", {"kind": "light", "count": 1})
	await _frames(3)
	var e: EnemyDummy = main.get("gm_enemies")[0]
	e.global_position = p.global_position + Vector3(0, 0, -5)
	await _frames(40)
	check(e.rig != null and e.rig.juice != null, "敌人挂了弹性层")
	var ej: AnimJuice = e.rig.juice
	e.rig.play_attack(0.7, false, 0.5, 1.0, p.global_position - e.global_position)
	var se := await _sample(ej, 0.3)
	check(se["sq_max"] > 0.1 and se["st_max"] < 0.2, "敌人前摇期间蹲低蓄力、尚未出手 (sq=%.2f st=%.2f)" % [se["sq_max"], se["st_max"]])
	var se2 := await _sample(ej, 0.3)
	check(se2["st_max"] >= 0.25, "前摇结束瞬间出手前扑 (st=%.2f)" % se2["st_max"])
	await _settle(ej)

	# 9) 敌人受击：1 帧内反应，且倒向远离玩家
	e.take_damage(4.0)
	await process_frame
	check(ej.deviation > 0.15, "敌人受击：1 帧内反应 (dev=%.3f)" % ej.deviation)
	var top_local := ej.tilt.x.cross(Vector3.UP)
	var top_world: Vector3 = ej.get_parent_node_3d().global_basis * top_local
	var away: Vector3 = e.global_position - p.global_position
	away.y = 0.0
	check(top_world.dot(away.normalized()) > 0.0, "受击时身体倒向远离攻击者 (dot=%.2f)" % top_world.dot(away.normalized()))

	# 10) 击退：顺受力方向拉长
	await _settle(ej)
	e.apply_knockback(Vector3(1, 0, 0), 10.0)
	await process_frame
	check(ej.st.x.length() > 0.08, "击退时沿受力方向拉长 (st=%.2f)" % ej.st.x.length())

	# 11) 惯性驱动：拖着走一段，身体后仰 / 拉长（无需任何事件）
	await _settle(ej)
	gm.execute("freeze_ai", {"enabled": false})
	ej.reset_peaks()
	for i in 30:
		e.global_position += Vector3(0.0, 0, 0.12 * minf(i, 10) / 10.0)
		await process_frame
	check(float(ej.peak["tilt"]) > 0.04, "加速时自动后仰（惯性驱动 tilt=%.2f）" % ej.peak["tilt"])

	main.queue_free()
	await process_frame
	print("C22 ANIM %s: %d failed" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)
