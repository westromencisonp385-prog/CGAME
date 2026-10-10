extends SceneTree

## C26 视角 / 遮挡诊断与验收（真窗口）
##   1. 资产排队：manifest 里每个资产在游戏镜头下摆一排，量世界包围盒——
##      躺倒（应直立的资产高度远小于水平尺寸）、浮空 / 下沉（底部离地 > 0.2m）
##   2. 遮挡审计：主场景里每个可见网格，按正交 45° 投影算它在地面上“盖住”的范围；
##      高物件盖住可玩区（玩家可到达的地面）→ 记为遮挡物
##   3. 原作口径：正交、俯角 45°、yaw 0（与 Wanderburg Main Camera 一致）
const OUT := "D:/工作/InverseGame/WaWa/CGAME/artifacts/qa/c26_view"
## 应该直立的资产前缀（树、灯、牌、旗、角色……）；扁平件（桥、地毯式）不判躺倒
const UPRIGHT := ["enemy_", "boss_0", "player_", "module_", "summon_", "prop_tree", "prop_lamp", "prop_sign", "prop_pennant", "wind_turbine", "mountain_air_pump", "repair_pump", "camp_board", "biome_gate", "prop_reeds", "prop_grass", "prop_stone_arch", "prop_fence", "prop_roadblock", "prop_barrier"]
var failures: Array[String] = []
var tag := "before"
var report := {}

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tag="):
			tag = a.substr(4)
	call_deferred("_run")

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FAIL ") + msg)
	if not ok:
		failures.append(msg)

func _aabb(root_node: Node3D) -> AABB:
	var have := false
	var box := AABB()
	for n in root_node.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree() or str(mi.name).begins_with("Vfx"):
			continue
		var b := mi.global_transform * mi.get_aabb()
		box = b if not have else box.merge(b)
		have = true
	return box if have else AABB(root_node.global_position, Vector3.ZERO)

func _lineup(main: Node) -> void:
	var manifest := ProceduralRig.load_manifest()
	var stage := Node3D.new()
	stage.name = "C26Lineup"
	root.add_child(stage)
	stage.position = Vector3(0, 0, 400)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 40.0
	cam.near = 1.0
	cam.far = 400.0
	stage.add_child(cam)
	var pitch := deg_to_rad(45.0)
	cam.position = Vector3(0, sin(pitch), cos(pitch)) * 80.0
	cam.rotation = Vector3(-pitch, 0, 0)
	var keys: Array = manifest.keys()
	keys.sort()
	var cols := 10
	var lying := []
	var floating := []
	var rows := {}
	for i in keys.size():
		var slot: String = keys[i]
		var holder := Node3D.new()
		holder.name = slot
		stage.add_child(holder)
		var x := (float(i % cols) - (cols - 1) * 0.5) * 6.4
		var z := (float(i / cols) - 2.5) * 6.6
		holder.position = Vector3(x, 0, z)
		var rig := ProceduralRig.attach(holder, slot)
		if rig == null:
			continue
		var lbl := Label3D.new()
		lbl.text = slot.replace("prop_", "").replace("enemy_", "e_").replace("module_", "m_")
		lbl.font_size = 40
		lbl.pixel_size = 0.01
		lbl.outline_size = 8
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.position = Vector3(0, -0.2, 2.2)
		holder.add_child(lbl)
		rows[slot] = holder
	await process_frame
	await process_frame
	for slot in rows:
		var h: Node3D = rows[slot]
		var b := _aabb(h)
		var local_min_y := b.position.y - h.global_position.y
		var horiz := maxf(b.size.x, b.size.z)
		var upright := false
		for p in UPRIGHT:
			if str(slot).begins_with(p):
				upright = true
		report[slot] = {"size": [snappedf(b.size.x, 0.01), snappedf(b.size.y, 0.01), snappedf(b.size.z, 0.01)], "min_y": snappedf(local_min_y, 0.01)}
		if upright and b.size.y < horiz * 0.42 and horiz > 0.6:
			lying.append("%s (高 %.2f / 宽 %.2f)" % [slot, b.size.y, horiz])
		if absf(local_min_y) > 0.2:
			floating.append("%s (底 %.2f)" % [slot, local_min_y])
	cam.current = true
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s_lineup.png" % [OUT, tag])
	print("LINEUP lying=", lying)
	print("LINEUP floating=", floating)
	check(lying.is_empty(), "资产没有躺倒（%d 件：%s）" % [lying.size(), ", ".join(lying)])
	check(floating.is_empty(), "资产贴地（无浮空 / 下沉 >0.2m：%s）" % ", ".join(floating))
	main.get_viewport().get_camera_3d()
	stage.queue_free()
	var gcam: Camera3D = main.get("cam_rig").camera if main.get("cam_rig") != null else null
	if gcam != null:
		gcam.current = true

## 正交 45° 下，一个高 h、离地 y0 的点在地面上“盖住”的位置是往远处（-Z）挪 h/tan(pitch)
func _occlusion(main: Node) -> void:
	var cam: Camera3D = main.get_viewport().get_camera_3d()
	var pitch := -cam.global_rotation.x
	var cot := 1.0 / tan(pitch)
	var arena: Array = Tuning3C.get_v("camera", "arena_half")
	var ax := float(arena[0]) - 1.0
	var az := float(arena[1]) - 1.0
	var playable := Rect2(-ax, -az, ax * 2.0, az * 2.0)
	var occluders := {}
	var nodes: Array = []
	for n in main.find_children("*", "GeometryInstance3D", true, false):
		nodes.append(n)
	for n in nodes:
		var gi := n as GeometryInstance3D
		if not gi.is_visible_in_tree() or str(gi.name).begins_with("Vfx") or str(gi.name).contains("Telegraph") or str(gi.name).contains("Terrain"):
			continue
		var p: Node = gi
		var skip := false
		while p != null:
			if p == main.player or p is EnemyDummy or str(p.name).begins_with("C26") or str(p.name).contains("Effects"):
				skip = true
				break
			p = p.get_parent()
		if skip:
			continue
		var boxes: Array = []
		if gi is MultiMeshInstance3D:
			var mm := (gi as MultiMeshInstance3D).multimesh
			if mm == null or mm.mesh == null:
				continue
			var mb := mm.mesh.get_aabb()
			for i in mm.instance_count:
				boxes.append(gi.global_transform * mm.get_instance_transform(i) * mb)
		elif gi is MeshInstance3D and (gi as MeshInstance3D).mesh != null:
			boxes.append(gi.global_transform * (gi as MeshInstance3D).get_aabb())
		for b in boxes:
			var bb: AABB = b
			var top := bb.position.y + bb.size.y
			if top < 1.1:
				continue
			# 地面上被盖住的带：从物体近边 z1 往远处延伸到 z_far - top*cot（同 x 范围）
			var z_near := bb.position.z + bb.size.z
			var shadow := Rect2(bb.position.x, bb.position.z - top * cot, bb.size.x, z_near - (bb.position.z - top * cot))
			var own := Rect2(bb.position.x, bb.position.z, bb.size.x, bb.size.z)
			var cover := shadow.intersection(playable)
			# 只算“盖住了别处”的部分：去掉物体自身脚下
			var extra := cover.get_area() - own.intersection(playable).get_area()
			if extra > 0.8:
				var key := _owner_name(gi)
				occluders[key] = float(occluders.get(key, 0.0)) + extra
	var top_list := []
	var total := 0.0
	for k in occluders:
		total += float(occluders[k])
		top_list.append([k, snappedf(float(occluders[k]), 0.1)])
	top_list.sort_custom(func(a, b): return a[1] > b[1])
	print("OCCLUSION total_m2=%.1f playable_m2=%.0f" % [total, playable.get_area()])
	for e in top_list.slice(0, 20):
		print("OCCLUDER ", e[0], " ", e[1], " m2")
	report["_occlusion"] = {"total_m2": total, "top": top_list.slice(0, 30)}
	check(total < playable.get_area() * 0.03, "高物件盖住可玩区 < 3%%（现在 %.1f m² / %.0f m²）" % [total, playable.get_area()])
	# 镜头口径
	check(cam.projection == Camera3D.PROJECTION_ORTHOGONAL, "正交投影（同原作）")
	check(absf(rad_to_deg(pitch) - 45.0) < 0.5 and absf(cam.global_rotation.y) < 0.01, "俯角 45°、yaw 0（同原作 Main Camera）")

func _owner_name(n: Node) -> String:
	var p: Node = n
	while p != null:
		var s := str(p.name)
		if s.begins_with("Prop_"):
			return s
		if p is MultiMeshInstance3D and p.has_meta("slot"):
			return "Scatter_" + str(p.get_meta("slot"))
		if p.has_meta("rig_slot"):
			return "Rig_" + str(p.get_meta("rig_slot")) + " @" + str(p.get_parent().name if p.get_parent() else "")
		p = p.get_parent()
	var path := str(n.name)
	p = n.get_parent()
	for i in 4:
		if p == null:
			break
		path = str(p.name) + "/" + path
		p = p.get_parent()
	return path

## 把车开到最高的景物正后方（远离镜头一侧），看它是否淡出；再关掉淡出看剪影
func _behind_test(main: Node) -> void:
	var fader: OcclusionFader = main.get("occlusion")
	check(fader != null and not fader._props.is_empty(), "遮挡淡出系统已收集景物 (%d)" % (fader._props.size() if fader else 0))
	if fader == null or fader._props.is_empty():
		return
	var best: Dictionary = {}
	var arena: Array = Tuning3C.get_v("camera", "arena_half")
	for e in fader._props:
		var b: AABB = e["aabb"]
		var c := b.get_center()
		if absf(c.x) > float(arena[0]) - 3.0 or absf(c.z) > float(arena[1]) - 3.0 or not (e["node"] as Node3D).is_visible_in_tree():
			continue
		if best.is_empty() or b.end.y > (best["aabb"] as AABB).end.y:
			best = e
	if best.is_empty():
		return
	var box: AABB = best["aabb"]
	var p: Node3D = main.player
	main.get("gm").execute("freeze_ai", {"enabled": true})
	p.global_position = Vector3(box.get_center().x, 0.5, box.position.z - 0.25)
	p.velocity = Vector3.ZERO
	await create_timer(1.2, true, false, true).timeout
	check(fader.is_faded(best["node"]), "车开到「%s」后面 → 它淡出（高 %.2fm）" % [best["node"].name, box.end.y])
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s_behind_fade.png" % [OUT, tag])
	# 剪影：关掉淡出，看被挡住部分的剪影
	fader.set_process(false)
	for mi in best["meshes"]:
		(mi as GeometryInstance3D).transparency = 0.0
	var has_xray := false
	for n in p.find_children("*", "MeshInstance3D", true, false):
		var m: Material = (n as MeshInstance3D).get_surface_override_material(0)
		var depth := 0
		while m != null and depth < 5:
			if m is ShaderMaterial and (m as ShaderMaterial).shader != null and (m as ShaderMaterial).shader.code.contains("hint_depth_texture"):
				has_xray = true
			m = m.next_pass
			depth += 1
	check(has_xray, "玩家材质带被挡剪影 pass")
	await create_timer(0.3, true, false, true).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s_behind_xray.png" % [OUT, tag])
	fader.set_process(true)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await create_timer(2.0, true, false, true).timeout
	main.ui.hint_time = 0.0
	await _occlusion(main)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s_game.png" % [OUT, tag])
	# 走到场地最下沿（离镜头最近），看近处遮挡
	main.player.global_position = Vector3(-6.0, 0.5, 14.0)
	await create_timer(1.6, true, false, true).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s_south_edge.png" % [OUT, tag])
	await _lineup(main)
	await _behind_test(main)
	FileAccess.open("%s/%s_report.json" % [OUT, tag], FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print("C26 VIEW %s: %d failed" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)
