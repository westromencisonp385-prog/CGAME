extends SceneTree

## C16 游戏内截图：一波花名册（5 小怪 ×2 + 精英）→ 精英近景 → 吞河蟾 Boss。

const OUT := "D:/工作/InverseGame/WaWa/CGAME/artifacts/qa/c16_enemies"

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
	gm.execute("invulnerable", {"enabled": true})
	gm.execute("panel", {"open": false})
	gm.execute("clear_enemies", {})
	var wave: Array = m.spawn_roster_wave(true)
	print("wave=", wave.size())
	await _wait(20)
	await _shot("wave_banner")
	await _wait(90)
	await _shot("wave")
	m.clear_gm_and_formal_enemies()
	m.run_systems.bosses_defeated = 1
	m.summon_boss()
	await _wait(25)
	await _shot("boss_toad_warning")
	await _wait(100)
	await _shot("boss_toad")
	var missing := 0
	for slot in ["enemy_minion_flea", "enemy_minion_oildrum", "enemy_minion_bat", "enemy_minion_hedgehog", "enemy_minion_mantis", "enemy_elite_rhino", "enemy_elite_eel", "boss_04_dredge_toad"]:
		if not ProceduralRig.has_rig(slot):
			print("MISS ", slot)
			missing += 1
	print("C16 ENEMIES CAPTURE DONE missing=%d" % missing)
	quit(0)
