extends SceneTree

## C20 动画 + 交互手感验收（headless）
var failures: Array[String] = []
var main_scene: Node

func _init() -> void:
	call_deferred("_run")

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FAIL ") + msg)
	if not ok:
		failures.append(msg)

func _phys(n: int) -> void:
	for _i in n:
		await physics_frame

func _run() -> void:
	_test_rigs()
	await _test_interaction()
	print("C20 FEEL %s: %d failed" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)

func _tool_angle(rig: ProceduralRig) -> float:
	var tl: Node3D = rig.tools[0]
	return rad_to_deg(((rig.rest[tl] as Transform3D).basis.inverse() * tl.transform.basis).get_euler().length())

func _test_rigs() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	# 伪腿过滤：倒车蟹的整块底盘不再当腿摆
	var crab := ProceduralRig.attach(holder, "enemy_crab_b01")
	check(crab.static_parts.size() >= 1 and crab.legs.size() >= 4, "倒车蟹：过滤伪腿 %d 条，保留真腿 %d 条" % [crab.static_parts.size(), crab.legs.size()])
	# 轴向：+Z / -X 正面的资产，腿都应在“前后”平面里摆（父空间 right 轴与模型右轴一致）
	for slot in ["enemy_minion_mantis", "boss_01_kanoning", "player_stage01_whale"]:
		var r := ProceduralRig.attach(holder, slot)
		var tl_ok := not r.tools.is_empty()
		if tl_ok:
			r.set_process(false)
			r._process(0.016)
			r.play_attack(0.3)
			var peak := 0.0
			for i in 18:
				r._process(1.0 / 60.0)
				peak = maxf(peak, _tool_angle(r))
			check(peak > 15.0, "%s 攻击时工具部件最大转角 %.0f° (>15°)" % [slot, peak])
		var right_m: Vector3 = r.right_m
		var fwd_m: Vector3 = r.fwd_m
		check(absf(right_m.dot(fwd_m)) < 0.01 and absf(right_m.y) < 0.01, "%s 右轴与正面轴正交" % slot)
	# 步态：两组腿相位相反，停下后振幅归零
	var m := ProceduralRig.attach(holder, "enemy_elite_rhino")
	m.set_speed(3.0)
	var max_lift := 0.0
	for i in 90:
		m._process(1.0 / 60.0)
		for leg in m.legs:
			max_lift = maxf(max_lift, (leg.transform.origin - (m.rest[leg] as Transform3D).origin).length())
	check(max_lift > 0.02, "犀牛行走抬脚 %.3fm" % max_lift)
	m.set_speed(0.0)
	for i in 60:
		m._process(1.0 / 60.0)
	var settle := 0.0
	for leg in m.legs:
		settle = maxf(settle, rad_to_deg(((m.rest[leg] as Transform3D).basis.inverse() * leg.transform.basis).get_euler().length()))
	check(settle < 2.0, "停下 1 秒后腿回静止（残余 %.1f°）" % settle)
	holder.free()

func _test_interaction() -> void:
	main_scene = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main_scene)
	await _phys(30)
	var gm: Node = main_scene.get("gm")
	gm.execute("invulnerable", {"enabled": true})
	gm.execute("clear_enemies", {})
	gm.execute("freeze_ai", {"enabled": true})
	var p: Node = main_scene.player
	p.global_position = Vector3(0, 0.5, 4)
	p.aim_direction = Vector3(0, 0, -1)
	await _phys(5)
	# 三段连击
	var steps: Array[int] = []
	for i in 4:
		p.primary_cooldown = 0.0
		p.heat = 0.0
		var r: Dictionary = p.perform_primary()
		steps.append(int(r.get("combo_step", -1)))
		await _phys(12)
	check(steps == [0, 1, 2, 0], "咬合连击段位 %s == [0,1,2,0]" % [steps])
	p.primary_cooldown = 0.0
	await _phys(50)
	p.primary_cooldown = 0.0
	check(int(p.perform_primary().get("combo_step", -1)) == 0, "停顿 >0.6s 连击重置")
	# 咬合前扑：出手后速度朝瞄准方向
	p.velocity = Vector3.ZERO
	p._fwd_speed = 0.0
	await _phys(30)
	p.primary_cooldown = 0.0
	p.perform_primary()
	check(Vector3(p.velocity.x, 0, p.velocity.z).dot(Vector3(0, 0, -1)) > 1.0, "咬合带前扑速度 %.1f" % Vector3(p.velocity.x, 0, p.velocity.z).dot(Vector3(0, 0, -1)))
	await _phys(30)
	# 投掷：落地后才结算伤害
	gm.execute("spawn", {"kind": "rhino", "count": 1})
	await _phys(2)
	var foe: Node = null
	for e in main_scene.get("gm_enemies"):
		if is_instance_valid(e):
			foe = e
	p.global_position = Vector3(0, 0.5, 4)
	p.velocity = Vector3.ZERO
	foe.global_position = Vector3(0, foe.global_position.y, -1)
	await _phys(3)
	p.cargo = 2
	p.throw_cooldown = 0.0
	var hp0: float = foe.current_health
	var res: Dictionary = p.throw_cargo()
	check(bool(res.get("hit", false)), "投掷锁定目标")
	check(is_equal_approx(foe.current_health, hp0), "投掷出手瞬间不扣血（飞行中）")
	await _phys(40)
	check(foe.current_health < hp0, "投掷落地后扣血 %.0f → %.0f" % [hp0, foe.current_health])
	# 没货时投掷给反馈
	p.cargo = 0
	p.packed_enemy_ids.clear()
	p.throw_cooldown = 0.0
	var msgs: Array[String] = []
	p.feedback.connect(func(m: String): msgs.append(m))
	p._deny_until = 0
	p.throw_cargo()
	check(msgs.any(func(m): return m.contains("没有废料")), "空仓投掷有提示")
	# 震屏在正交镜头下可见
	var feel: GameFeel = GameFeel.instance
	feel._trauma = 0.0
	feel.shake(0.3)
	var off := 0.0
	for i in 6:
		await process_frame
		off = maxf(off, Vector2(main_scene.world.camera.h_offset, main_scene.world.camera.v_offset).length())
	check(off > 0.05, "0.3 震屏在正交镜头下偏移 %.2fm" % off)
