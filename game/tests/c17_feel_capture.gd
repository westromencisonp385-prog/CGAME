extends SceneTree

## C17 游戏内截图：一波敌人 + 连续技能（数字/闪白/扇形/光束）→ Boss 招式预警与弹幕 + Boss 血条 + 状态签。

const OUT := "D:/工作/InverseGame/WaWa/CGAME/artifacts/qa/c17_feel"

func _init() -> void:
	call_deferred("_run")

func _wait(n: int) -> void:
	for _i in n:
		await process_frame

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [OUT, name])

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var m: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(m)
	await _wait(30)
	var gm: Node = m.get("gm")
	gm.execute("panel", {"open": false})
	gm.execute("clear_enemies", {})
	var p: M0VehicleController = m.player
	# 装 4 个技能
	var defs := ContentV2Catalog.create_v2_definitions()
	for id in ["mage_cryo", "mage_void", "crew_bomber", "quake_hammer"]:
		for d in defs:
			if d.module_id == id:
				m.selection_engine.installed_modules.append(d)
	m._sync_equipped_abilities()
	m.spawn_roster_wave(false)
	await _wait(40)
	p.aim_direction = Vector3(0, 0, -1)
	m._try_cast(0)
	await _wait(3)
	await _shot("cone_numbers")
	await _wait(20)
	m._try_cast(1)
	await _wait(2)
	await _shot("lance")
	m._try_cast(2)
	await _wait(14)
	await _shot("mortar_telegraph")
	await _wait(30)
	p.status.apply("slow", 3.0, 0.4)
	p.status.apply("shield", 5.0, 30.0)
	p.heat = 85.0
	m._try_cast(3)
	await _wait(4)
	await _shot("quake_status")
	m.clear_gm_and_formal_enemies()
	m.run_systems.bosses_defeated = 0
	gm.execute("invulnerable", {"enabled": true})
	m.summon_boss()
	await _wait(30)
	var b: BossEntity = m.boss
	b.take_damage(120.0)
	BossPatterns.run(b, "barrage")
	BossPatterns.run(b, "slam")
	BossPatterns.run(b, "charge")
	await _wait(24)
	await _shot("boss_patterns")
	await _wait(80)
	await _shot("boss_bar_trail")
	print("C17 FEEL CAPTURE DONE")
	quit(0)
