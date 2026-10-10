extends SceneTree

## C25 渲染诊断：原分辨率截图 + 2 倍放大裁切 + 渲染设置清单
const OUT := "D:/工作/InverseGame/WaWa/CGAME/artifacts/qa/c25_render"
var tag := "before"

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tag="):
			tag = a.substr(4)
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await create_timer(2.5, true, false, true).timeout
	main.ui.hint_time = 0.0
	main.get("gm").execute("spawn", {"kind": "mantis", "count": 3})
	main.get("gm").execute("freeze_ai", {"enabled": true})
	await create_timer(0.8, true, false, true).timeout
	var pl: Node3D = main.player
	var es: Array = main.get("gm_enemies")
	for i in es.size():
		(es[i] as Node3D).global_position = pl.global_position + Vector3(-3.5 + i * 3.5, 0.0, 3.2)
	main.get("gm").execute("spawn", {"kind": "rhino", "count": 1})
	await create_timer(0.3, true, false, true).timeout
	es = main.get("gm_enemies")
	if es.size() > 3:
		(es[3] as Node3D).global_position = pl.global_position + Vector3(4.5, 0.0, -2.0)
	await create_timer(0.6, true, false, true).timeout
	var vp := root
	print("RENDER window=", DisplayServer.window_get_size(), " vp=", vp.size, " msaa3d=", vp.msaa_3d, " ssaa=", vp.screen_space_aa, " taa=", vp.use_taa, " scale3d=", vp.scaling_3d_scale, " mode=", vp.scaling_3d_mode, " mip_bias=", vp.texture_mipmap_bias, " aniso=", ProjectSettings.get_setting("rendering/textures/default_filters/anisotropic_filtering_level"))
	var cam := vp.get_camera_3d()
	print("RENDER cam proj=", cam.projection, " size=", cam.size, " near=", cam.near, " far=", cam.far, " pos=", cam.global_position)
	var env: Environment = vp.find_world_3d().environment if vp.find_world_3d().environment != null else null
	for we in root.find_children("*", "WorldEnvironment", true, false):
		env = (we as WorldEnvironment).environment
	if env != null:
		print("RENDER env fog=", env.fog_enabled, " dens=", env.fog_density, " amb=", env.ambient_light_energy, " tonemap=", env.tonemap_mode, " exp=", env.tonemap_exposure, " glow=", env.glow_enabled, " ssao=", env.ssao_enabled, " adj=", env.adjustment_enabled)
	await RenderingServer.frame_post_draw
	var fails := 0
	var checks := [
		[vp.msaa_3d >= Viewport.MSAA_4X, "MSAA 4x"],
		[not vp.use_taa and vp.screen_space_aa == Viewport.SCREEN_SPACE_AA_DISABLED, "不用 TAA / FXAA（会糊）"],
		[int(ProjectSettings.get_setting("rendering/textures/default_filters/anisotropic_filtering_level")) >= 4, "16x 各向异性"],
		[env != null and not env.fog_enabled, "无全场景距离雾"],
		[env != null and env.ssao_enabled, "SSAO 接地阴影"],
		[env != null and env.ambient_light_energy <= 0.45, "环境光压低（阴影有对比）"],
		[str(ProjectSettings.get_setting("rendering/renderer/rendering_method")) == "forward_plus", "Forward+ 渲染器"],
	]
	var rim_hero := 0
	var rim_foe := 0
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var m := mi.get_surface_override_material(0)
		if m != null and m.next_pass is ShaderMaterial:
			var c: Color = (m.next_pass as ShaderMaterial).get_shader_parameter("rim_color")
			if c == RenderProfile.RIM["hero"]["color"]:
				rim_hero += 1
			elif c == RenderProfile.RIM["foe"]["color"]:
				rim_foe += 1
	checks.append([rim_hero > 0, "玩家边缘光（暖骨白）%d 个网格" % rim_hero])
	checks.append([rim_foe > 0, "敌人边缘光（番茄红）%d 个网格" % rim_foe])
	for c in checks:
		print(("OK   " if c[0] else "FAIL ") + str(c[1]))
		if not c[0]:
			fails += 1
	var img := vp.get_texture().get_image()
	img.save_png("%s/%s_full.png" % [OUT, tag])
	var c := img.get_region(Rect2i(440, 220, 400, 260))
	c.resize(1200, 780, Image.INTERPOLATE_NEAREST)
	c.save_png("%s/%s_crop.png" % [OUT, tag])
	print("C25 RENDER %s: %d failed" % ["PASS" if fails == 0 else "FAIL", fails])
	print("RENDER DONE")
	quit(0 if fails == 0 else 1)
