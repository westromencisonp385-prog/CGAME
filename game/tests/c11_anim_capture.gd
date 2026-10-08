extends SceneTree

## C11 动画验收：在空舞台上并排放置各类 rig，驱动移动/攻击/受击/死亡，按时间点截帧拼成胶片条。
## 输出 artifacts/qa/c11_anim/<label>_<frame>.png，由外部脚本拼接审查。

const OUT := "D:/工作/InverseGame/WaWa/CGAME/artifacts/qa/c11_anim"
var rigs: Array = []
var holders: Array = []

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
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#e9dcc0")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.72, 0.68)
	e.ambient_light_energy = 0.7
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	world.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 30)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("#d8c49a")
	ground.material_override = gm
	world.add_child(ground)
	var cam := Camera3D.new()
	cam.position = Vector3(-4.5, 4.2, 6.2)
	cam.rotation_degrees = Vector3(-30, 0, 0)
	cam.fov = 40
	world.add_child(cam)
	cam.make_current()
	var slots := ["enemy_light_v1", "enemy_light_v2", "enemy_ranged_v1", "boss_01_kanoning", "boss_03", "module_demolition_pigeon", "enemy_flyer_v1", "wind_turbine"]
	var xs := [-10.5, -7.5, -4.5, -0.5, 4.2, 7.6, 10.4, 13.0]
	for i in slots.size():
		var h := Node3D.new()
		h.position = Vector3(xs[i] * 0.85, 0, 0)
		world.add_child(h)
		var r := ProceduralRig.attach(h, slots[i])
		if r == null:
			push_error("missing rig " + slots[i])
			continue
		r.rotation_degrees.y = 25.0
		rigs.append(r)
		holders.append(h)
	await _wait(30)
	# 行走：holder 前后移动，rig 自动估计速度
	for f in 6:
		for h in holders.slice(0, 7):
			h.position.z = sin(f * 0.6) * 0.3
		for k in 4:
			for h in holders.slice(0, 7):
				h.position.z -= 0.035
			await process_frame
		await _shot("walk_%d" % f)
	# 攻击
	for r in rigs:
		r.play_attack(0.5)
	for f in 5:
		await _wait(6)
		await _shot("attack_%d" % f)
	# 受击
	for r in rigs:
		r.play_hit()
	for f in 3:
		await _wait(4)
		await _shot("hit_%d" % f)
	# 死亡
	for r in rigs.slice(0, 3):
		r.play_death(0.9)
	for f in 5:
		await _wait(10)
		await _shot("death_%d" % f)
	print("C11 ANIM CAPTURE DONE rigs=%d" % rigs.size())
	quit(0)
