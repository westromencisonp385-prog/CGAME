extends SceneTree

## C14 UI v2 视觉验收：HUD / 三选一（含 hover 态与开场动画中间帧）/ 改装台（含按钮 hover）/ Boss 大字 / GM。

const OUT := "D:/工作/InverseGame/WaWa/CGAME/artifacts/qa/c14_ui"
var main_scene: Node

func _init() -> void:
	call_deferred("_run")

func _wait(n: int) -> void:
	for _i in n:
		await process_frame

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [OUT, name])

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	main_scene = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main_scene)
	var gm: Node = main_scene.get("gm")
	await _wait(4)
	await _shot("hud_intro_mid")
	await _wait(50)
	gm.execute("invulnerable", {"enabled": true})
	gm.execute("panel", {"open": false})
	gm.execute("spawn", {"kind": "light", "count": 2})
	await _wait(30)
	await _shot("hud")
	main_scene.open_selection_flow("new_module")
	await _wait(9)
	await _shot("select_opening")
	await _wait(50)
	await _shot("select")
	var sui: SelectionUI = main_scene.get("selection_ui")
	if not sui._cards.is_empty():
		sui._cards[1].grab_focus()
	await _wait(20)
	await _shot("select_hover")
	sui.visible = false
	main_scene.toggle_garage()
	await _wait(40)
	var hud: Node = main_scene.get("ui")
	if not hud.module_buttons.is_empty():
		hud.module_buttons[1].grab_focus()
	await _wait(20)
	await _shot("garage_hover")
	main_scene.toggle_garage()
	await _wait(10)
	gm.execute("boss_next", {})
	gm.execute("panel", {"open": false})
	await _wait(16)
	await _shot("boss_warning")
	await _wait(80)
	gm.execute("panel", {"open": true})
	await _wait(10)
	await _shot("gm_panel")
	print("C14 UI CAPTURE DONE")
	quit(0)
