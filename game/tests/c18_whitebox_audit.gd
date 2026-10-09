extends SceneTree

## C18 白模审计：载入真实主场景，刷怪、召唤、刷掉落、叫 Boss，然后列出所有仍在显示的程序几何网格。
## 判定口径：可见的 MeshInstance3D 若网格是 Box/Cylinder/Sphere/Prism/Capsule/Torus 原语，即视为白模。
## 豁免（不是“资产”，而是特效/界面/功能层）：预警圈、弹道、伤害区、特效粒子、水面、地表 PlaneMesh、HUD。
## 有真 GPU 时额外截 4 张验收图到 artifacts/qa/c18_world/。

const OUT := "D:/工作/InverseGame/WaWa/CGAME/artifacts/qa/c18_world"
const PRIMS := ["BoxMesh", "CylinderMesh", "SphereMesh", "PrismMesh", "CapsuleMesh", "TorusMesh"]
const EXEMPT_NAMES := ["FlowingWater", "Telegraph", "Projectile", "AreaHazard", "Effects", "NativeEffects", "GameFeel",
	"Shadow", "Ring", "Pulse", "Marker", "Aura", "Beam", "Spark", "Vfx", "VFX", "Hit", "Flash", "Bolt", "Arc", "Wave",
	"JawPreviewRing", "GhostVehicle", "Dust", "Trail", "Weather"]
var main_scene: Node

func _init() -> void:
	call_deferred("_run")

func _wait(n: int) -> void:
	for _i in n:
		await process_frame

func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [OUT, name])

func _exempt(n: Node) -> bool:
	var p: Node = n
	while p != null and p != main_scene:
		var nm := str(p.name)
		for e in EXEMPT_NAMES:
			if nm.contains(e):
				return true
		var sc: Script = p.get_script()
		if sc != null:
			var path := sc.resource_path
			if path.contains("/combat/telegraph") or path.contains("/combat/projectile") or path.contains("/combat/area_hazard") \
					or path.contains("native_effects") or path.contains("game_feel") or path.contains("biome_weather"):
				return true
		if p is CanvasItem or p is CanvasLayer:
			return true
		p = p.get_parent()
	return false

func _visible_in_tree(n: Node3D) -> bool:
	return n.is_visible_in_tree()

func _audit() -> Dictionary:
	var counts := {}
	for node in main_scene.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or not _visible_in_tree(mi):
			continue
		var cls := mi.mesh.get_class()
		if not cls in PRIMS:
			continue
		if _exempt(mi):
			continue
		# 输出相对主场景路径（去掉末级网格名），便于定位来源
		var path := str(main_scene.get_path_to(mi.get_parent()))
		var owner_name := "%s  [%s %s]" % [path, str(mi.name), cls]
		counts[owner_name] = int(counts.get(owner_name, 0)) + 1
	return counts

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	main_scene = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main_scene)
	await _wait(40)
	var gm: Node = main_scene.get("gm")
	gm.execute("invulnerable", {"enabled": true})
	gm.execute("freeze_ai", {"enabled": true})
	gm.execute("panel", {"open": false})
	await _wait(20)
	await _shot("01_start")
	main_scene.spawn_roster_wave(true)
	for i in 3:
		main_scene._try_summon(i)
	LootPickup.burst(main_scene, main_scene.player.global_position + Vector3(2, 0, 2), 6, 1)
	LootPickup.burst(main_scene, main_scene.player.global_position + Vector3(-2, 0, 2), 2, 1, "repair")
	await _wait(30)
	await _shot("02_wave_summons_loot")
	gm.execute("boss_next", {})
	await _wait(30)
	await _shot("03_boss")
	var counts := _audit()
	var total := 0
	for k in counts:
		total += int(counts[k])
		print("WHITEBOX %3d  %s" % [int(counts[k]), k])
	main_scene.world.green_zone.show()
	await _wait(30)
	await _shot("04_repaired_route")
	var after := _audit()
	var total_after := 0
	for k in after:
		total_after += int(after[k])
		print("WHITEBOX(repaired) %3d  %s" % [int(after[k]), k])
	print("C18 WHITEBOX AUDIT: start=%d repaired=%d %s" % [total, total_after, "PASS" if total + total_after == 0 else "FAIL"])
	quit(0 if total + total_after == 0 else 1)
