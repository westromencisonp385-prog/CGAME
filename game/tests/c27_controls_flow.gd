extends SceneTree

## C27 操控验收：WASD + 少量技能键，不用鼠标，攻击全自动（对照 Wanderburg 原作 Vehicle 动作表）
const OUT := "D:/工作/InverseGame/WaWa/CGAME/artifacts/qa/c27_controls"
var failures: Array[String] = []
var main: Node
var p

func _init() -> void:
	call_deferred("_run")

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FAIL ") + msg)
	if not ok:
		failures.append(msg)

func wait(t: float) -> void:
	await create_timer(t, true, false, true).timeout

func shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [OUT, name])

func key(code: Key, pressed := true) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)

func tap(code: Key) -> void:
	key(code, true)
	await process_frame
	await process_frame
	key(code, false)
	await process_frame

func enemies() -> Array:
	var out := []
	for n in main.get_tree().get_nodes_in_group("enemies"):
		if n is EnemyDummy and not n.dead and not n.packed:
			out.append(n)
	return out

func park_all_enemies_far() -> void:
	var i := 0
	for e in enemies():
		(e as Node3D).global_position = Vector3(-16.0 + i * 1.5, (e as Node3D).global_position.y, -14.0)
		i += 1

func scraps_far() -> void:
	for t in main.get_tree().get_nodes_in_group("engineering_targets"):
		if t is EngineeringTarget and t.target_kind != "repair":
			t.global_position = Vector3(15.0, t.global_position.y, -14.0)

func _bindings() -> void:
	var mouse_bound := []
	for action in InputMap.get_actions():
		if str(action).begins_with("ui_"):
			continue
		for e in InputMap.action_get_events(action):
			if e is InputEventMouseButton:
				mouse_bound.append(action)
	check(mouse_bound.is_empty(), "战斗动作不绑鼠标（%s）" % ", ".join(mouse_bound))
	for a in ["primary", "throw_cargo", "interact"]:
		check(InputMap.action_get_events(a).is_empty(), "%s 不需要按键（自动）" % a)
	var want := {"skill_1": KEY_Q, "skill_2": KEY_E, "skill_3": KEY_R, "skill_4": KEY_SPACE, "dash": KEY_SHIFT, "move_up": KEY_W, "summon_1": KEY_Z}
	for a in want:
		var has := false
		for e in InputMap.action_get_events(a):
			if e is InputEventKey and (e as InputEventKey).physical_keycode == want[a]:
				has = true
		check(has, "%s = %s（原作键位）" % [a, OS.get_keycode_string(want[a])])

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await wait(1.5)
	p = main.player
	main.ui.hint_time = 0.0
	_bindings()
	main.gm.execute("freeze_ai", {"enabled": true})
	p.status.apply("invincible", 600.0)
	main.spawn_roster_wave(true)
	await wait(0.4)
	scraps_far()
	park_all_enemies_far()
	p.global_position = Vector3(0, p.global_position.y, 4.0)
	p.velocity = Vector3.ZERO
	p.heading = Vector3(0, 0, -1)
	p.aim_direction = Vector3(0, 0, -1)
	await wait(0.4)
	# 1 没目标：不乱咬、瞄准回到车头
	var heat0: float = p.heat
	await wait(0.8)
	check(p.auto_target == null, "附近没目标时不锁定")
	check(p.heat <= heat0 + 0.01 and p.primary_cooldown <= 0.0, "没目标不空咬（热量 %.1f→%.1f）" % [heat0, p.heat])
	# 2 敌人在侧面 6m：自动锁定、挖斗平滑转过去（不是瞬间）
	var foe: EnemyDummy = enemies()[0]
	foe.global_position = Vector3(6.0, foe.global_position.y, 4.0)
	await physics_frame
	await physics_frame
	await physics_frame
	var a1: float = rad_to_deg(p.aim_direction.angle_to(Vector3(1, 0, 0)))
	check(a1 > 45.0, "转向有过程（3 帧后还差 %.0f°）" % a1)
	await wait(0.5)
	check(p.auto_target == foe, "6m 外的敌人被自动锁定")
	var a2: float = rad_to_deg(p.aim_direction.angle_to(Vector3(1, 0, 0)))
	check(a2 < 6.0, "0.5 秒内挖斗对准目标（差 %.1f°）" % a2)
	await shot("lock_on")
	# 3 进咬合距离：自动咬，连击，不会一直过热
	foe.global_position = Vector3(2.4, foe.global_position.y, 4.0)
	foe.current_health = 99999.0
	var hp0: float = foe.current_health
	var peak := 0.0
	var t := 0.0
	while t < 5.0:
		await physics_frame
		t += 1.0 / 60.0
		peak = maxf(peak, p.heat)
	check(foe.current_health < hp0, "进咬合距离自动咬（掉血 %.0f）" % (hp0 - foe.current_health))
	check(peak < 95.0 and not p.status.has("overheat"), "连续自动咬 5 秒不过热（峰值热量 %.0f）" % peak)
	await shot("auto_bite")
	# 4 优先最近的敌人
	var foes := enemies()
	foes.erase(foe)
	if foes.size() >= 1:
		var near: EnemyDummy = foes[0]
		near.current_health = 99999.0
		var pp: Vector3 = p.global_position
		foe.global_position = Vector3(pp.x + 9.0, foe.global_position.y, pp.z)
		near.global_position = Vector3(pp.x - 3.5, near.global_position.y, pp.z)
		await wait(0.6)
		check(p.auto_target == near, "锁定最近的敌人（3.5m 的，而不是正在打的 9m 那只）")
		near.global_position = Vector3(-16, near.global_position.y, -14)
	# 5 自动投掷：装满货、敌人在 6m → 自动扔
	park_all_enemies_far()
	foe.global_position = Vector3(0.0, foe.global_position.y, -2.0)
	var cap: int = int(p._stats().get("cargo_capacity", p.max_cargo))
	p.cargo = cap
	p.throw_cooldown = 0.0
	await wait(1.4)
	check(p.cargo < cap, "满货 + 6m 有敌人 → 自动投掷（%d→%d）" % [cap, p.cargo])
	await shot("auto_throw")
	# 6 没敌人时自动咬废料堆
	park_all_enemies_far()
	await wait(0.3)
	var scrap: EngineeringTarget = null
	for tg in main.get_tree().get_nodes_in_group("engineering_targets"):
		if tg is EngineeringTarget and tg.target_kind != "repair" and not tg.dead:
			scrap = tg
			break
	if scrap != null:
		scrap.global_position = Vector3(p.global_position.x + 2.2, scrap.global_position.y, p.global_position.z)
		var shp: float = scrap.current_hp
		await wait(1.5)
		check(not is_instance_valid(scrap) or scrap.dead or scrap.current_hp < shp, "没敌人时自动咬附近废料堆")
	# 7 技能键：Q 走施法通道（空槽也要有“做不了”的反馈）
	var casts0: int = main.cast_requests
	await tap(KEY_Q)
	await tap(KEY_SPACE)
	check(main.cast_requests == casts0 + 2, "Q / 空格 触发技能施放（%d 次）" % (main.cast_requests - casts0))
	var s0: int = main.summon_requests
	await tap(KEY_Z)
	check(main.summon_requests == s0 + 1, "Z 触发召唤")
	# 8 自动修理：带够废料开到水泵旁
	var pump: EngineeringTarget = null
	for tg in main.targets:
		if is_instance_valid(tg) and tg.target_kind == "repair":
			pump = tg
	if pump != null and not main.repair_done:
		main.collected = maxi(main.collected, 3)
		p.global_position = pump.global_position + Vector3(0, 0, 2.0)
		p.velocity = Vector3.ZERO
		await wait(0.8)
		check(main.repair_done or pump.repaired_state, "开到水泵旁自动修理")
	# 9 选卡只用键盘：按 1 选第一张
	main.open_selection_flow("new_module")
	await wait(0.9)
	var sel: CanvasLayer = main.selection_ui
	check(sel.visible, "选卡界面打开")
	var focus := root.get_viewport().gui_get_focus_owner()
	check(focus != null and sel.is_ancestor_of(focus), "选卡打开后自动聚焦第一张卡（键盘可直接确认）")
	await tap(KEY_D)
	var focus2 := root.get_viewport().gui_get_focus_owner()
	check(focus2 != null and focus2 != focus, "D 键切到下一张卡")
	await shot("select_keyboard")
	await tap(KEY_SPACE)
	await wait(1.6)
	check(not sel.visible, "空格确认选卡")
	# 10 暂停菜单键盘导航
	await wait(0.4)
	await tap(KEY_ESCAPE)
	await wait(0.5)
	var pf := root.get_viewport().gui_get_focus_owner()
	check(main.manual_pause and pf != null and main.ui.pause_menu.is_ancestor_of(pf), "Esc 打开菜单并聚焦第一个按钮")
	await shot("pause_keyboard")
	await tap(KEY_SPACE)
	await wait(0.5)
	check(not main.manual_pause, "空格确认“继续游戏”")
	var pf2 := root.get_viewport().gui_get_focus_owner()
	check(pf2 == null or not main.ui.pause_menu.is_ancestor_of(pf2), "回到战斗后菜单不残留焦点（空格不会误触菜单）")
	print("C27 CONTROLS %s: %d failed" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)
