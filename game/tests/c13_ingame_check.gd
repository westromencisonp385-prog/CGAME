extends SceneTree

## C13 入场验收：确认资产真的在游戏场景里（不是只在盘上）。
## 检查：场景景物 / 敌人 rig / Boss rig / 锁门 rig / 模块 rig / 玩家进化形态 / UI 主题与字体 / GM 面板。

const OUT := "D:/工作/InverseGame/WaWa/CGAME/artifacts/qa/c13_ingame"
var failures: Array[String] = []
var main_scene: Node

func _init() -> void:
	call_deferred("_run")

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "MISS ") + msg)
	if not ok:
		failures.append(msg)

func _wait(n: int) -> void:
	for _i in n:
		await process_frame

func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [OUT, name])

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	main_scene = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main_scene)
	await _wait(40)
	var gm: Node = main_scene.get("gm")
	gm.execute("invulnerable", {"enabled": true})
	gm.execute("freeze_ai", {"enabled": true})
	var world: Node = main_scene.get("world")
	for slot in ["wind_turbine", "mountain_air_pump", "camp_board"]:
		var n: Node = world.find_child("FormalProp_" + slot, true, false)
		check(n != null and n.get_child_count() > 0, "场景景物在场: " + slot)
	check(world.find_child("FormalProp_wind_turbine", true, false) != null and world.find_child("FormalProp_wind_turbine", true, false).find_child("ProceduralRig", true, false) != null, "涡轮为动画版")
	gm.execute("spawn", {"kind": "light", "count": 2})
	gm.execute("spawn", {"kind": "heavy", "count": 1})
	gm.execute("spawn", {"kind": "ranged", "count": 1})
	await _wait(10)
	var rigged := 0
	for e in main_scene.get("gm_enemies"):
		if is_instance_valid(e) and e.get("rig") != null:
			rigged += 1
	check(rigged >= 4, "GM 敌人挂动画 rig: %d/4" % rigged)
	var formal_enemies := 0
	for e in main_scene.get("enemies"):
		if is_instance_valid(e) and (e.get("rig") != null or e.find_child("EnemyFormalModel", true, false) != null or e.find_child("FormalB01", true, false) != null):
			formal_enemies += 1
	check(formal_enemies >= 1, "关卡原生敌人用正式模型: %d" % formal_enemies)
	gm.execute("boss_next", {})
	await _wait(5)
	var boss: Node = main_scene.get("boss")
	check(boss != null and boss.get("rig") != null, "Boss 挂动画 rig")
	var hud: Node = main_scene.get("ui")
	check(hud.get("skill_bar") != null and hud.skill_bar.get_child_count() == 4, "HUD 技能栏 4 槽")
	check(P5Theme.title_font() is FontFile, "标题字体已加载 (Anton+得意黑)")
	check(hud.root_ui.theme.default_font != null, "HUD 主题字体已设置")
	gm.execute("panel", {"open": false})
	await _wait(40)
	await _shot("river_full")
	# 进化
	var r: Dictionary = gm.execute("evolve", {})
	gm.execute("panel", {"open": false})
	await _wait(30)
	check(main_scene.player.evolved_rig != null, "玩家进化为叠河鲸形态 (rank=%s)" % str(r.get("rank")))
	await _shot("evolved")
	# 改装台模块
	main_scene.toggle_garage()
	main_scene.request_preview("magnet")
	await _wait(20)
	await _shot("garage")
	main_scene.toggle_garage()
	# 锁门
	gm.execute("grant_key", {"key": "key_desert"})
	print("goto: ", gm.execute("goto", {"biome": "desert"}))
	await _wait(20)
	var gates: Array = main_scene.get("biome_gates")
	check(not gates.is_empty() and gates[0].get("gate_rig") != null, "沙漠锁门为动画版")
	gm.execute("panel", {"open": false})
	await _wait(20)
	await _shot("desert_gate")
	# GM 面板
	gm.execute("panel", {"open": true})
	await _wait(10)
	await _shot("gm_panel")
	print("C13 INGAME %s: %d missing" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)
