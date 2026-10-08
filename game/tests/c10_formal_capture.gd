extends SceneTree

## C10 视觉验收：正式模型替换白模后的游戏内呈现。
## 截两张：1) 河谷 + 召 Boss + 刷敌人；2) 沙漠群系锁门。

var failures: Array[String] = []
var main_scene: Node

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("FAIL: " + message)

func _wait(frames: int) -> void:
	for _i in range(frames):
		await process_frame

func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func _run() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		quit(1)
		return
	var packed := load("res://scenes/main.tscn") as PackedScene
	main_scene = packed.instantiate()
	root.add_child(main_scene)
	await _wait(20)
	var gm: Node = main_scene.get("gm")
	gm.execute("invulnerable", {"enabled": true})
	gm.execute("freeze_ai", {"enabled": true})
	gm.execute("spawn", {"kind": "heavy", "count": 2})
	gm.execute("spawn", {"kind": "ranged", "count": 2})
	gm.execute("boss_next", {})
	gm.execute("panel", {"open": false})
	await _wait(45)
	var boss: Node = main_scene.get("boss")
	check(boss != null and boss.find_child("BossFormalModel", true, false) != null, "Boss 应挂正式模型")
	var formal_enemies := 0
	for e in main_scene.get("gm_enemies"):
		if is_instance_valid(e) and e.find_child("EnemyFormalModel", true, false) != null:
			formal_enemies += 1
	check(formal_enemies >= 4, "GM 刷出的 4 个敌人应挂正式模型，实际 %d" % formal_enemies)
	await _shot("D:/工作/InverseGame/WaWa/CGAME/artifacts/qa/c10_formal_river.png")
	gm.execute("grant_key", {"key": "key_desert"})
	gm.execute("goto", {"biome": "desert"})
	gm.execute("panel", {"open": false})
	await _wait(45)
	var gates: Array = main_scene.get("biome_gates")
	check(not gates.is_empty() and gates[0].find_child("GateFormalModel", true, false) != null, "沙漠锁门应挂正式模型")
	await _shot("D:/工作/InverseGame/WaWa/CGAME/artifacts/qa/c10_formal_desert.png")
	print("C10 FORMAL CAPTURE PASS" if failures.is_empty() else "C10 FORMAL CAPTURE FAIL: " + ", ".join(failures))
	quit(0 if failures.is_empty() else 1)
