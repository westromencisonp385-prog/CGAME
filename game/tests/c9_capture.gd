extends SceneTree

## C9 视觉验收：Boss 花名册第 2 顺位 + 神器/船长 GM 直发后的同屏呈现。

var failures: Array[String] = []
var main_scene: Node

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _wait(frames: int) -> void:
	for _i in range(frames):
		await process_frame

func _run() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		quit(1)
		return
	var packed := load("res://scenes/main.tscn") as PackedScene
	main_scene = packed.instantiate()
	root.add_child(main_scene)
	await _wait(20)
	var gm: Node = main_scene.get("gm")
	gm.execute("grant_artifact", {"id": "art_kraken_heart"})
	gm.execute("hire_captain", {"id": "cap_marrow"})
	gm.execute("panel", {"open": false})
	gm.execute("boss_next", {})
	await _wait(40)
	var boss: Node = main_scene.get("boss")
	check(boss != null, "Boss 已召唤")
	check(str(boss.boss_title) == "炮阵阶段蟹", "第 2 顺位 Boss 应为炮阵阶段蟹，实际 " + str(boss.boss_title))
	var run: Node = main_scene.get("run_systems")
	check(run.hired_captain != null and run.hired_captain.id == "cap_marrow", "骨髓船长已上船")
	check(run.artifact_bonus("damage") > 0.0, "海妖之心 damage 修饰已生效")
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png("D:/工作/InverseGame/WaWa/CGAME/artifacts/qa/c9_roster.png")
	print("C9 ROSTER CAPTURE PASS" if failures.is_empty() else "C9 ROSTER CAPTURE FAIL")
	quit(0 if failures.is_empty() else 1)
