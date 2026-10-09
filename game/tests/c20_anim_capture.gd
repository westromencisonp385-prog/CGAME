extends SceneTree

## C20 动画验收截帧：每个 rig 单独取景（3/4 侧视），以固定 1/60s 步长手动推进动画（截图写盘很慢，
## 不能依赖真实帧间隔），按 行走 8 帧 / 攻击 6 帧 / 收尾重击 6 帧 / 受击 3 帧 / 死亡 4 帧 截图，
## 输出 artifacts/qa/c20_anim/<slot>/NN.png，由 tools/asset_pipeline/contact_sheet.py 拼成胶片条。
const OUT := "D:/工作/InverseGame/WaWa/CGAME/artifacts/qa/c20_anim"
const SLOTS := ["player_stage01_whale", "enemy_crab_b01", "enemy_minion_mantis", "enemy_elite_rhino", "boss_02", "boss_04_dredge_toad", "boss_01_kanoning", "enemy_minion_bat", "enemy_elite_eel", "module_demolition_pigeon"]
const DT := 1.0 / 60.0

var cam: Camera3D

func _init() -> void:
	call_deferred("_run")

func _shot(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func _tick(rig: ProceduralRig, holder: Node3D, n: int, move_speed := 0.0) -> void:
	for i in n:
		holder.position.z -= move_speed * DT
		rig._process(DT)

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#e9dcc0")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.77, 0.72)
	e.ambient_light_energy = 0.8
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	world.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("#d8c49a")
	ground.material_override = gm
	world.add_child(ground)
	cam = Camera3D.new()
	cam.fov = 35
	world.add_child(cam)
	cam.make_current()
	for slot in SLOTS:
		var dir := "%s/%s" % [OUT, slot]
		DirAccess.make_dir_recursive_absolute(dir)
		var holder := Node3D.new()
		world.add_child(holder)
		var rig := ProceduralRig.attach(holder, slot)
		if rig == null:
			print("MISSING ", slot)
			holder.queue_free()
			continue
		rig.set_process(false)
		var h: float = rig._model_height
		print("RIG %s legs=%d static=%d tools=%d wings=%d treads=%d h=%.2f leg_len=%.2f" % [slot, rig.legs.size(), rig.static_parts.size(), rig.tools.size(), rig.wings.size(), rig.treads.size(), h, rig.leg_len])
		var dist := maxf(h, 1.0) * 4.2
		var n := 0
		var speed := clampf(h * 2.5, 2.0, 6.0)
		rig.set_speed(speed)
		_tick(rig, holder, 60, speed)
		for f in 8:
			_tick(rig, holder, 4, speed)
			_frame(holder, h, dist)
			await _shot("%s/%02d_walk.png" % [dir, n]); n += 1
		rig.set_speed(0.0)
		_tick(rig, holder, 40)
		rig.play_attack(0.3, false)
		for f in 6:
			_tick(rig, holder, 3)
			_frame(holder, h, dist)
			await _shot("%s/%02d_attack.png" % [dir, n]); n += 1
		_tick(rig, holder, 20)
		rig.play_attack(0.36, true)
		for f in 6:
			_tick(rig, holder, 3)
			_frame(holder, h, dist)
			await _shot("%s/%02d_heavy.png" % [dir, n]); n += 1
		_tick(rig, holder, 20)
		rig.play_hit()
		for f in 3:
			_tick(rig, holder, 4)
			_frame(holder, h, dist)
			await _shot("%s/%02d_hit.png" % [dir, n]); n += 1
		_tick(rig, holder, 20)
		rig.play_death(0.9)
		for f in 4:
			_tick(rig, holder, 12)
			_frame(holder, h, dist)
			await _shot("%s/%02d_death.png" % [dir, n]); n += 1
		holder.queue_free()
		await process_frame
	print("C20 ANIM CAPTURE DONE")
	quit(0)

func _frame(holder: Node3D, h: float, dist: float) -> void:
	var target := holder.global_position + Vector3(0, h * 0.45, 0)
	cam.global_position = target + Vector3(dist * 0.72, dist * 0.42, -dist * 0.18)
	cam.look_at(target, Vector3.UP)
