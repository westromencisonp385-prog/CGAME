extends SceneTree

## B1 截图：装 6 个不同槽位的模块，在真实关卡里开 8 秒，按时间截 4 张
const OUT := "D:/工作/InverseGame/WaWa/CGAME/artifacts/qa/c29_combat"
var main: Node

func _init() -> void:
	call_deferred("_run")

func wait(t: float) -> void:
	await create_timer(t, true, false, true).timeout

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [OUT, name])

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await wait(1.5)
	main.ui.hint_time = 0.0
	main.gm.execute("invulnerable", {"enabled": true})
	main.start_campaign(1, 777)
	await wait(0.3)
	main.selection_engine.installed_modules.clear()
	for id in ["front_cannon", "side_flamethrower", "mage_storm", "crew_bomber", "back_mine_layer", "top_archer"]:
		for pool in main.selection_engine.new_module_pools:
			for entry in pool.entries:
				if entry["item"].module_id == id:
					main.selection_engine.installed_modules.append(entry["item"])
	main._sync_equipped_abilities()
	main.director.t = 100.0
	await wait(4.0)
	Input.action_press("move_right")
	for i in 4:
		await wait(1.6)
		await shot("auto_%d" % i)
		if i == 1:
			Input.action_release("move_right")
			Input.action_press("move_up")
	Input.action_release("move_up")
	main.ui.show_result()
	await wait(0.6)
	await shot("result_damage")
	print("C29 CAPTURE done ", JSON.stringify(main.auto_weapons.shots_fired))
	main.queue_free()
	quit(0)
