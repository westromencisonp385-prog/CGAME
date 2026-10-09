extends SceneTree

## C21 特效截帧：在真实主场景里逐个施放技能形状 / Boss 招式 / 状态，按时间点截图。
## 输出 artifacts/qa/c21_vfx/<name>_<k>.png；用 tools/asset_pipeline/contact_sheet.py 的平铺模式拼图。
const OUT := "D:/工作/InverseGame/WaWa/CGAME/artifacts/qa/c21_vfx"
const SHAPES := ["fireball", "flame_cone", "frost_cone", "tide_wave", "chain", "void_lance", "snipe", "mortar", "cannon", "harpoon",
	"volley", "broadside", "barrage", "ram", "blink", "magnet_pull", "gravity_well", "quake", "frost_nova", "emp", "roar", "cyclone",
	"repair", "shield", "tesla", "firewall", "mines", "overclock"]
const BOSS := ["slam", "charge", "mortar_rain", "shockwave", "vacuum", "summon", "barrage"]
const SHOTS := [0.06, 0.18, 0.4]

var main: Node

func _init() -> void:
	call_deferred("_run")

func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func _wait(sec: float) -> void:
	var t := 0.0
	while t < sec:
		await process_frame
		t += root.get_process_delta_time() if root.get_process_delta_time() > 0 else 0.016

func _real_wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout

func _ring_enemies(n: int, r: float) -> void:
	var gm: Node = main.get("gm")
	gm.execute("clear_enemies", {})
	gm.execute("spawn", {"kind": "light", "count": n})
	await process_frame
	var i := 0
	for e in main.get("gm_enemies"):
		if is_instance_valid(e):
			var a := -PI * 0.5 + (float(i) - (n - 1) * 0.5) * 0.35
			e.global_position = main.player.global_position + Vector3(cos(a), 0, sin(a)) * r
			i += 1

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _real_wait(1.5)
	var gm: Node = main.get("gm")
	gm.execute("invulnerable", {"enabled": true})
	gm.execute("freeze_ai", {"enabled": true})
	var p: Node = main.player
	p.global_position = Vector3(0, 0.5, 6)
	p.aim_direction = Vector3(0, 0, -1)
	p.heading = Vector3(0, 0, -1)
	await _real_wait(0.8)
	for shape in SHAPES:
		await _ring_enemies(5, 6.0)
		await _real_wait(0.25)
		p.aim_direction = Vector3(0, 0, -1)
		AbilityLibrary._cast_shape(main, shape, 10.0, 9.0, {})
		main._cast_presentation("", shape, shape)
		var last := 0.0
		for k in SHOTS.size():
			await _real_wait(SHOTS[k] - last)
			last = SHOTS[k]
			await _shot("%s/skill_%s_%d.png" % [OUT, shape, k])
		await _real_wait(0.6)
		p.global_position = Vector3(0, 0.5, 6)
		p.status.clear()
	# 状态光环
	gm.execute("clear_enemies", {})
	gm.execute("spawn", {"kind": "light", "count": 3})
	await process_frame
	var es: Array = main.get("gm_enemies")
	var kinds := ["burning", "stun", "slow"]
	for i in es.size():
		es[i].global_position = p.global_position + Vector3(-3 + i * 3, 0, -4)
		es[i].status.apply(kinds[i % 3], 5.0, 0.5)
	p.status.apply("shield", 5.0, 40.0)
	await _real_wait(0.5)
	await _shot("%s/status_0.png" % OUT)
	# 冲刺 + 敌人死亡
	p.status.clear()
	p._last_move_dir = Vector3(1, 0, 0)
	p.dash_cooldown = 0.0
	p.try_dash()
	await _real_wait(0.12)
	await _shot("%s/dash_0.png" % OUT)
	for e in es:
		if is_instance_valid(e) and not e.dead:
			e.take_damage(9999.0)
	await _real_wait(0.1)
	await _shot("%s/death_0.png" % OUT)
	await _real_wait(0.9)
	# Boss 招式
	gm.execute("clear_enemies", {})
	main.summon_boss()
	await _real_wait(1.5)
	var boss: Node = null
	for n in get_nodes_in_group("enemies"):
		if n is BossEntity:
			boss = n
	if boss != null:
		boss._pattern_t = 999.0
		for atk in BOSS:
			p.global_position = Vector3(0, 0.5, 6)
			boss.global_position = Vector3(0, boss.global_position.y, -2)
			await _real_wait(0.3)
			BossPatterns.run(boss, atk)
			var marks := [0.5, 1.05, 1.5]
			var last2 := 0.0
			for k in marks.size():
				await _real_wait(marks[k] - last2)
				last2 = marks[k]
				await _shot("%s/boss_%s_%d.png" % [OUT, atk, k])
			await _real_wait(0.6)
	print("C21 VFX CAPTURE DONE live=%d stats=%s" % [VfxKit.live, VfxKit.stats])
	quit(0)
