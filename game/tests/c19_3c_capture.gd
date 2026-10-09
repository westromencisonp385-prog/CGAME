extends SceneTree

## C19 3C 截图：转弯中 / 侧向咬合甩头 / Boss 登场演出中。输出 artifacts/qa/c19_3c/
const OUT := "D:/工作/InverseGame/WaWa/CGAME/artifacts/qa/c19_3c"
var main_scene: Node

func _init() -> void:
	call_deferred("_run")

func _phys(n: int) -> void:
	for _i in n:
		await physics_frame

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [OUT, name])

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	main_scene = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main_scene)
	await _phys(40)
	var gm: Node = main_scene.get("gm")
	gm.execute("invulnerable", {"enabled": true})
	gm.execute("freeze_ai", {"enabled": true})
	gm.execute("panel", {"open": false})
	var p: Node = main_scene.player
	p.global_position = Vector3(-8, 0.5, 8)
	p.heading = Vector3.RIGHT
	await _phys(60)
	Input.action_press("move_right")
	await _phys(40)
	Input.action_release("move_right")
	Input.action_press("move_up")
	await _phys(9)
	await _shot("01_turning")
	await _phys(30)
	Input.action_release("move_up")
	await _phys(40)
	p.aim_mode = "pad"
	Input.action_press("aim_right")
	await _phys(2)
	p.primary_cooldown = 0.0
	p.perform_primary()
	await _phys(5)
	await _shot("02_bite_side")
	Input.action_release("aim_right")
	p.aim_mode = "mouse"
	await _phys(30)
	main_scene.summon_boss()
	await _phys(30)
	await _shot("03_boss_intro")
	await _phys(200)
	await _shot("04_boss_fight_zoom")
	print("C19 CAPTURE done")
	quit(0)
