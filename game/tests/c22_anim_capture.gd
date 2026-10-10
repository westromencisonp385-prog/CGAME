extends SceneTree

## C22 动作胶片：真 GPU，逐帧截取玩家咬合 / 冲刺 / 投掷 / 敌人前摇受击，裁切到角色周围
const OUT := "D:/工作/InverseGame/WaWa/CGAME/artifacts/qa/c22_anim"
var main: Node

func _init() -> void:
	call_deferred("_run")

func _real(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout

func _crop(at: Vector3, path: String, half := 150) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var cam: Camera3D = root.get_viewport().get_camera_3d()
	var sp := cam.unproject_position(at)
	var r := Rect2i(int(sp.x) - half, int(sp.y) - half, half * 2, half * 2).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	img.get_region(r).save_png(path)

func _strip(name: String, focus: Callable, action: Callable, frames := 10, step := 0.035) -> void:
	await _real(0.6)
	action.call()
	for k in frames:
		await _crop(focus.call(), "%s/%s_%02d.png" % [OUT, name, k])
		await _real(step)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _real(1.5)
	var gm: Node = main.get("gm")
	gm.execute("invulnerable", {"enabled": true})
	gm.execute("clear_enemies", {})
	var p: Node = main.player
	p.global_position = Vector3(0, 0.5, 4)
	p.aim_direction = Vector3(1, 0, 0)
	var pf := func(): return p.global_position
	await _strip("bite", pf, func():
		p.primary_cooldown = 0.0
		p.aim_direction = Vector3(1, 0, 0)
		p.perform_primary())
	await _strip("dash", pf, func():
		p.dash_cooldown = 0.0
		p._last_move_dir = Vector3(1, 0, 0)
		p.try_dash(), 12)
	p.global_position = Vector3(0, 0.5, 4)
	await _strip("throw", pf, func():
		p.cargo = 2
		p.throw_cooldown = 0.0
		p.aim_direction = Vector3(1, 0, 0)
		p.throw_cargo())
	await _strip("deny", pf, func():
		p.cargo = 0
		p._deny_until = 0
		p.throw_cooldown = 0.0
		p.throw_cargo(), 8)
	gm.execute("freeze_ai", {"enabled": true})
	gm.execute("spawn", {"kind": "heavy", "count": 1})
	await _real(0.3)
	var e: Node = main.get("gm_enemies")[0]
	e.global_position = p.global_position + Vector3(4, 0, 0)
	var ef := func(): return e.global_position
	await _strip("enemy_windup", ef, func(): e.rig.play_attack(0.75, true, 0.55, 1.2, p.global_position - e.global_position), 12, 0.06)
	await _strip("enemy_hit", ef, func(): e.take_damage(6.0), 8)
	print("C22 CAPTURE DONE")
	quit(0)
