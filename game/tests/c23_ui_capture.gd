extends SceneTree

## C23 UI 截图：开局（带操作提示）/ 提示淡出后 / 装了技能 / 暂停菜单 / 操作说明 / 改装台
const OUT := "D:/工作/InverseGame/WaWa/CGAME/artifacts/qa/c23_ui"
var main: Node

func _init() -> void:
	call_deferred("_run")

func _real(s: float) -> void:
	await create_timer(s, true, false, true).timeout

func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [OUT, n])

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _real(2.0)
	await _shot("1_start")
	main.ui.hint_time = 0.0
	for i in 3:
		main.open_selection_flow("new_module")
		await _real(0.9)
		if main.selection_ui.visible:
			main.selection_ui._choose(0)
		await _real(0.5)
	main.feedback("技能已装到 1 号槽 · 按 1 或点击技能槽")
	await _real(0.4)
	await _shot("2_combat")
	main.toggle_pause()
	await _real(0.6)
	await _shot("3_pause")
	main.ui.pause_help.visible = true
	await _real(0.2)
	await _shot("4_pause_help")
	main.toggle_pause()
	main.toggle_garage()
	await _real(1.0)
	await _shot("5_garage")
	print("C23 UI CAPTURE DONE")
	quit(0)
