extends SceneTree

## 部件生成资产单件检视：在空场景里实例化 rig，跑 idle/walk/attack，截正面斜俯视三张。
## 用法：godot --path game --script res://tests/parts_rig_view.gd -- module_demolition_pigeon [more slots...]

const OUT := "D:/工作/InverseGame/WaWa/CGAME/artifacts/qa/parts_rig"

func _init() -> void:
	call_deferred("_run")

func _wait(n: int) -> void:
	for _i in n:
		await process_frame

func _run() -> void:
	var slots := OS.get_cmdline_user_args()
	if slots.is_empty():
		slots = PackedStringArray(["module_demolition_pigeon"])
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#EFE3C8")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.78)
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.shadow_enabled = true
	world.add_child(sun)
	var cam := Camera3D.new()
	world.add_child(cam)
	for slot in slots:
		var holder := Node3D.new()
		world.add_child(holder)
		var rig := ProceduralRig.attach(holder, slot)
		if rig == null:
			print("MISS ", slot)
			holder.queue_free()
			continue
		var h: float = rig._model_height
		var aabb := AABB()
		var first := true
		for mi in rig.find_children("*", "MeshInstance3D", true, false):
			var box: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			aabb = box if first else aabb.merge(box)
			first = false
		var c := aabb.get_center()
		var r := aabb.size.length()
		cam.position = c + Vector3(r * 0.75, r * 0.65, r * 1.0)
		cam.look_at(c)
		await _wait(20)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s_idle.png" % [OUT, slot])
		rig.set_speed(4.0)
		await _wait(17)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s_move.png" % [OUT, slot])
		rig.set_speed(0.0)
		rig.play_attack(0.5)
		await _wait(8)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s_attack.png" % [OUT, slot])
		print("OK ", slot, " parts=", rig.legs.size(), "/", rig.wings.size(), "/", rig.tools.size(), "/", rig.treads.size(), "/", rig.rings.size(), "/", rig.tops.size())
		holder.queue_free()
		await _wait(2)
	print("PARTS VIEW DONE")
	quit(0)
