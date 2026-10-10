extends SceneTree

## C28 关卡验收：时间线节拍、刷怪位置、蜂群预警、Boss 时涓流下调、加时、敌巢上限、中立逃跑、阶段推进、通关、升级给选择、HUD
const OUT := "D:/工作/InverseGame/WaWa/CGAME/artifacts/qa/c28_level"
var failures: Array[String] = []
var main: Node
var d

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

func drain_all() -> int:
	var n := 0
	var guard := 0
	while not d._queue.is_empty() and guard < 200:
		var before: int = d.stats["spawned"]
		d._drain_queue()
		n += int(d.stats["spawned"]) - before
		guard += 1
	return n

func clear_hostiles() -> void:
	for e in d.stage_enemies:
		if is_instance_valid(e) and EnemyArchetypes.is_hostile(str(e.tier)) and not (e is BossEntity):
			e.queue_free()
	d.stage_enemies = d.stage_enemies.filter(func(e): return is_instance_valid(e) and not e.is_queued_for_deletion())
	await process_frame

func choose_until_closed() -> void:
	for i in 30:
		if main.selection_ui.visible:
			main.selection_ui._choose(0)
		await wait(0.4)
		if not main.selection_ui.visible and main.pending_selections.is_empty() and main._deferred_selections.is_empty():
			return

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await wait(1.2)
	main.ui.hint_time = 0.0
	main.start_campaign(0, 4242)
	d = main.director
	main.player.status.apply("invincible", 9999.0)
	await wait(0.6)
	# 1 开局
	check(d.running and d.stage_index == 0 and d.state == "playing", "关卡模式开局：阶段 1 运行中")
	check(d.stages.size() == 4, "一局 4 个阶段（%d）" % d.stages.size())
	check(d.nests.size() == 3, "3 个敌巢（%d）" % d.nests.size())
	check(d.stage_targets.size() >= 24, "4 片废料场（%d 堆）" % d.stage_targets.size())
	check(str(main.ui.mission_label.text).begins_with("阶段 1/4"), "目标行显示阶段（%s）" % main.ui.mission_label.text)
	check(main.ui.stage_bar.visible, "阶段进度条可见")
	await shot("01_start")
	# 2 刷怪位置：6 种模式都在场地内、镜头外；每帧不超过 3 个
	main.set_gm_ai_frozen(true)
	await clear_hostiles()
	var cam_size: float = d.cam_size()
	var focus: Vector3 = main.player.global_position
	var bad_inside := 0
	var bad_view := 0
	var total := 0
	for pat in ["ahead", "surround", "random", "double", "all", "groups"]:
		d._enqueue_wave("swarm_flea", 18, pat)
		var first_before: int = d.stats["spawned"]
		d._drain_queue()
		check(int(d.stats["spawned"]) - first_before <= 3, "[%s] 一帧最多生成 3 个" % pat)
		drain_all()
	for e in d.stage_enemies:
		if is_instance_valid(e) and str(e.tier) == "swarm":
			total += 1
			if not ArenaLayout.inside(e.global_position, 0.5):
				bad_inside += 1
			if ArenaLayout.in_view(e.global_position, focus, cam_size, 0.0):
				bad_view += 1
	check(total >= 70, "6 种模式共刷出 %d 只（上限 80）" % total)
	check(bad_inside == 0, "全部在场地内（越界 %d）" % bad_inside)
	check(bad_view <= total * 0.05, "几乎全在镜头外（镜头内 %d / %d）" % [bad_view, total])
	# 角落：玩家在角落时刷怪仍在场地内
	main.player.global_position = Vector3(ArenaLayout.HALF.x - 3.0, 0.5, ArenaLayout.HALF.y - 3.0)
	await clear_hostiles()
	d._enqueue_wave("swarm_mantis", 24, "ahead")
	drain_all()
	var corner_bad := 0
	for e in d.stage_enemies:
		if is_instance_valid(e) and str(e.tier) == "swarm" and not ArenaLayout.inside(e.global_position, 0.5):
			corner_bad += 1
	check(corner_bad == 0, "玩家在角落时刷怪不越界（%d）" % corner_bad)
	main.player.global_position = ArenaLayout.PLAYER_START
	await clear_hostiles()
	# 3 存活上限：超过 max_alive 时杂兵被丢弃
	d._enqueue_wave("swarm_flea", 120, "surround")
	drain_all()
	check(d.alive_hostiles() <= 80, "存活上限 80（现在 %d，丢弃 %d）" % [d.alive_hostiles(), d.stats["dropped"]])
	await clear_hostiles()
	# 4 节拍按时触发
	var s1: Dictionary = d.stage()
	d.t = 17.95
	d._tick_beats(s1)
	var q0: int = d._queue.size()
	d.t = 18.0
	d._tick_beats(s1)
	check(d._queue.size() - q0 >= 24, "18s 杂兵潮按时入队（+%d）" % (d._queue.size() - q0))
	d._queue.clear()
	# 5 蜂群：提前 4 秒预警，再爆发
	var warned := [false]
	var fired_before := [false]
	d.swarm_warning.connect(func(_s): warned[0] = true; fired_before[0] = int(d.stats["swarms"]) > 0, CONNECT_ONE_SHOT)
	d.t = 91.0
	d._tick_beats(s1)
	check(warned[0] and not fired_before[0], "蜂群在爆发前预警")
	d.t = 95.0
	d._tick_beats(s1)
	check(int(d.stats["swarms"]) == 1 and d._queue.size() >= 50, "95s 蜂群爆发（入队 %d）" % d._queue.size())
	drain_all()
	await wait(0.2)
	await shot("02_swarm")
	await clear_hostiles()
	d._queue.clear()
	# 6 Boss：屏幕外入场，涓流下调
	d.t = 149.0
	var before_strength: float = d.trickle_strength()
	d.spawn_boss()
	await wait(0.3)
	check(d.boss_alive(), "Boss 入场")
	if d.boss_alive():
		check(ArenaLayout.inside(d.boss.global_position, 0.0), "Boss 在场地内")
		check(d.boss.global_position.distance_to(main.player.global_position) >= 15.0, "Boss 离玩家 ≥15m（%.1f）" % d.boss.global_position.distance_to(main.player.global_position))
		var dip: float = float(d.g("boss_trickle_dip", 0.45))
		check(absf(d.trickle_strength() - before_strength * dip) < 0.01, "Boss 在场涓流 ×%.2f（%.2f → %.2f）" % [dip, before_strength, d.trickle_strength()])
		check(str(main.ui.mission_label.text).contains("击败 Boss"), "目标行改为击败 Boss")
	await wait(1.6)
	await shot("03_boss")
	# 7 加时
	d.t = float(s1["overtime_at"]) + 0.1
	await wait(0.3)
	check(d.overtime, "超过 overtime_at 进入加时")
	var ot0: int = d.stats["overtime_spawns"]
	d._ot_clock = 0.0
	d._tick_overtime(s1, 0.016)
	check(int(d.stats["overtime_spawns"]) > ot0, "加时刷清场者")
	d._enqueue_wave("enforcer", 20, "surround")
	drain_all()
	var enf: int = d.stage_enemies.filter(func(e): return is_instance_valid(e) and not e.dead and e.archetype_id == "enforcer").size()
	check(enf <= int(d.g("overtime_max_alive", 6)), "清场者同时最多 %d 只（%d）" % [int(d.g("overtime_max_alive", 6)), enf])
	d._queue.clear()
	# 8 敌巢：靠近才出兵，有上限
	var nest = d.nests[0]
	nest.nest_interval = 0.15
	main.set_gm_ai_frozen(false)
	main.player.global_position = nest.global_position + Vector3(0, 0.5, 30)
	await wait(1.0)
	check(nest.nest_children.is_empty(), "离巢 30m 不出兵")
	main.player.global_position = nest.global_position + Vector3(0, 0.5, 12)
	main.player.auto_combat = false
	await wait(3.0)
	var kids: int = nest.nest_children.filter(func(c): return is_instance_valid(c) and not c.dead).size()
	check(kids >= 2 and kids <= 5, "靠近敌巢出兵且不超过 5（%d）" % kids)
	await shot("04_nest")
	main.player.auto_combat = true
	main.player.global_position = ArenaLayout.PLAYER_START
	# 9 中立：宝箱车限时逃走
	var tr = d.spawn("treasure", main.player.global_position + Vector3(8, 0, 0))
	tr.lifetime = 0.4
	var esc0: int = d.stats["escaped"]
	await wait(1.0)
	check(int(d.stats["escaped"]) == esc0 + 1, "宝箱车限时逃走")
	# 10 升级给选择
	var vp = main.vehicle_progression
	vp.gain_growth(vp.growth_needed() - vp.growth_points + 0.01)
	await wait(1.2)
	check(main.selection_ui.visible or not main.pending_selections.is_empty(), "升级弹三选一")
	await choose_until_closed()
	# 11 阶段推进：打掉 Boss → 清场 → 阶段 2（沙漠、倍率上调）
	main.set_gm_ai_frozen(true)
	if d.boss_alive():
		d.boss.take_damage(999999.0)
	await wait(0.5)
	check(d.state == "clear", "Boss 倒下 → 清场")
	await choose_until_closed()
	await wait(float(d.g("stage_break", 4.0)) + 1.0)
	check(d.stage_index == 1 and d.state == "playing", "进入阶段 2（%d %s）" % [d.stage_index + 1, d.state])
	check(main.biome_system.current_id == "desert", "阶段 2 换成沙漠（%s）" % main.biome_system.current_id)
	var m = d.spawn("mantis", main.player.global_position + Vector3(20, 0, 0))
	check(absf(float(m.health) - 34.0 * float(d.mult("hp"))) < 0.1 and d.mult("hp") > 1.0, "阶段 2 小怪血量 ×%.1f（%.1f）" % [d.mult("hp"), float(m.health)])
	var sw = d.spawn("swarm_flea", main.player.global_position + Vector3(20, 0, 3))
	check(absf(float(sw.health) - 8.0 * float(d.mult("hp_swarm"))) < 0.1, "阶段 2 杂兵血量 ×%.2f（%.1f）" % [d.mult("hp_swarm"), float(sw.health)])
	await wait(0.4)
	await shot("05_stage2")
	# 12 通关：第 4 阶段 Boss 倒下
	d._begin_stage(3)
	await wait(0.3)
	d.spawn_boss()
	await wait(0.3)
	d.boss.take_damage(9999999.0)
	await wait(0.5)
	await choose_until_closed()
	await wait(float(d.g("stage_break", 4.0)) + 1.0)
	check(main.outcome == "won", "第 4 阶段 Boss 倒下 → 通关（%s）" % main.outcome)
	await shot("06_won")
	print("C28 LEVEL %s: %d failed" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)
