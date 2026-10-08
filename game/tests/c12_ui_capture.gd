extends SceneTree

## C12 UI 视觉验收：主 HUD / 3 选 1 / 改装台 / Boss 警告大字。

const OUT := "D:/工作/InverseGame/WaWa/CGAME/artifacts/qa/c12_ui"
var main_scene: Node

func _init() -> void:
	call_deferred("_run")

func _wait(frames: int) -> void:
	for _i in range(frames):
		await process_frame

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [OUT, name])

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	main_scene = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main_scene)
	var gm: Node = main_scene.get("gm")
	await _wait(50)
	gm.execute("invulnerable", {"enabled": true})
	gm.execute("panel", {"open": false})
	gm.execute("spawn", {"kind": "light", "count": 3})
	await _wait(40)
	await _shot("hud")
	main_scene.open_selection_flow("new_module")
	await _wait(60)
	await _shot("select")
	main_scene.get("selection_ui").visible = false
	main_scene.toggle_garage()
	await _wait(40)
	await _shot("garage")
	main_scene.toggle_garage()
	print("before boss: outcome=", main_scene.get("outcome"), " boss=", main_scene.get("boss"))
	gm.execute("boss_next", {})
	gm.execute("panel", {"open": false})
	print("after boss: boss=", main_scene.get("boss"))
	var ui0: Node = main_scene.get("ui")
	await _wait(12)
	print("banner visible=", ui0.banner.visible)
	await _shot("boss_warning")
	print("C12 UI CAPTURE DONE")
	quit(0)
