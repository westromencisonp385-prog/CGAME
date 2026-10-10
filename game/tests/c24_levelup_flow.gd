extends SceneTree

## C24 升级表现验收（真窗口）：
##   击杀 → 能量球飞到车身才入账 → HUD 能量条增长
##   能量满 → 升级：慢动作、车身压缩→跳起→落地、冲击波推开敌人、头顶 LEVEL UP、HUD Lv 变化
##   形态进化：旧车先压、闪白后新形态弹出（最终只显示新形态）
##   选卡：选中卡飞向目标，落地才触发车身 power_up 与技能槽弹出；选卡期间战斗暂停
const OUT := "D:/工作/InverseGame/WaWa/CGAME/artifacts/qa/c24_levelup"
var failures: Array[String] = []
var main: Node

func _init() -> void:
	call_deferred("_run")

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FAIL ") + msg)
	if not ok:
		failures.append(msg)

func _real(s: float) -> void:
	await create_timer(s, true, false, true).timeout

func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [OUT, n])

func _count(name_part: String) -> int:
	var n := 0
	for c in root.find_children("*" + name_part + "*", "", true, false):
		if c is Node3D and (c as Node3D).is_visible_in_tree():
			n += 1
	return n

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _real(1.5)
	var gm: Node = main.get("gm")
	gm.execute("invulnerable", {"enabled": true})
	gm.execute("clear_enemies", {})
	main.ui.hint_time = 0.0
	var p: Node = main.player
	var vp = main.vehicle_progression
	p.global_position = Vector3(0, 0.5, 4)

	# 1) 击杀 → 能量球 → 入账
	gm.execute("freeze_ai", {"enabled": true})
	gm.execute("spawn", {"kind": "light", "count": 1})
	await _real(0.3)
	var e: Node = main.get("gm_enemies")[0]
	e.global_position = p.global_position + Vector3(5, 0, 0)
	var g0: float = vp.growth_points
	e.take_damage(9999.0)
	await process_frame
	check(_count("VfxGrowthOrb") >= 1, "击杀后冒出进化能量球 (%d)" % _count("VfxGrowthOrb"))
	check(absf(vp.growth_points - g0) < 0.001, "能量球飞到前还没入账")
	await _real(0.25)
	await _shot("01_orbs")
	await _real(0.6)
	check(vp.growth_points > g0, "能量球飞到车身后入账 (%.2f → %.2f)" % [g0, vp.growth_points])
	check(main.ui._growth_shown > 0.0, "HUD 能量条增长 (%.2f)" % main.ui._growth_shown)

	# 2) 升级演出
	gm.execute("spawn", {"kind": "light", "count": 3})
	await _real(0.3)
	var ring := []
	for i in 3:
		var en: Node = main.get("gm_enemies")[main.get("gm_enemies").size() - 1 - i]
		en.global_position = p.global_position + Vector3(cos(i * 2.1), 0, sin(i * 2.1)) * 3.0
		ring.append([en, en.global_position.distance_to(p.global_position)])
	var rank0: int = vp.stats.vehicle_size_rank
	var j: AnimJuice = p._juice()
	vp.gain_growth(vp.growth_needed() - vp.growth_points + 0.01)
	await process_frame
	check(vp.stats.vehicle_size_rank == rank0 + 1, "能量满 → 等级 +1 (%d → %d)" % [rank0, vp.stats.vehicle_size_rank])
	j = p._juice()
	check(Engine.time_scale < 0.9, "升级瞬间慢动作 (time_scale %.2f)" % Engine.time_scale)
	await _shot("02_anticipate")
	var lift_max := 0.0
	var squash_max := 0.0
	var t := 0.0
	var shot_air := false
	while t < 0.9:
		await process_frame
		t += root.get_process_delta_time() / maxf(Engine.time_scale, 0.05)
		j = p._juice()
		if j != null:
			lift_max = maxf(lift_max, j.lift.x.x)
			squash_max = maxf(squash_max, j.sq.x.x)
		if not shot_air and t > 0.3:
			shot_air = true
			await _shot("03_air")
		if t > 0.5 and t < 0.56:
			await _shot("04_land")
	check(squash_max > 0.25, "升级预备：车身压缩蓄力 (sq %.2f)" % squash_max)
	check(lift_max > 0.25, "升级动作：车身跳起 (lift %.2f m)" % lift_max)
	var pushed := 0
	for r in ring:
		if is_instance_valid(r[0]) and (r[0] as Node3D).global_position.distance_to(p.global_position) > float(r[1]) + 0.5:
			pushed += 1
	check(pushed >= 2, "落地冲击波推开周围敌人 (%d/3)" % pushed)
	check(str(main.ui.lv_label.text) == "Lv.%d" % (vp.stats.vehicle_size_rank + 1) or str(main.ui.lv_label.text) == "MAX", "HUD 等级标签更新 (%s)" % main.ui.lv_label.text)
	await _real(0.6)
	check(p.evolved_rig == null or (p.evolved_rig.get_parent() as Node3D).scale.x > 0.9, "形态进化完成后新形态满尺寸")
	if p.evolved_rig != null:
		check(not p.chassis_visual.visible, "形态进化后旧车身隐藏")
	await _shot("05_after")
	gm.execute("clear_enemies", {})
	# 关掉可能弹出的载具 2 选 1
	await _real(0.6)
	if main.selection_ui.visible:
		main.selection_ui._choose(0)
		await _real(1.2)

	# 3) 选卡：暂停 + 飞卡 + 落地才演出
	main.open_selection_flow("new_module")
	await _real(0.8)
	check(main.selection_ui.visible and paused, "选卡期间战斗暂停")
	await _shot("06_cards")
	var pillars0 := _count("VfxPillar")
	main.selection_ui._choose(1)
	await process_frame
	check(not paused, "选完立即恢复战斗")
	check(main.selection_ui.outro_running(), "选中卡飞行演出进行中")
	check(_count("VfxPillar") == pillars0, "飞卡落地前车身还没演出")
	await _real(0.14)
	await _shot("07_pick_stamp")
	await _real(0.3)
	await _shot("08_pick_fly")
	var waited := 0.0
	var landed_seen := false
	while waited < 2.0:
		await process_frame
		waited += root.get_process_delta_time()
		if _count("VfxPillar") > pillars0 or _count("VfxCallout") > 0:
			landed_seen = true
			break
	check(landed_seen, "飞卡落地 → 车身 power_up（光柱 / 头顶字）")
	await _shot("09_power_up")
	await _real(0.6)
	check(not main.selection_ui.outro_running(), "飞卡演出结束后自动清理")

	print("C24 LEVELUP %s: %d failed" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)
