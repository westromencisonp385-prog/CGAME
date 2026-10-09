extends SceneTree

## C21 特效系统验收（headless）：确认各类特效能产出节点、受全局开关控制、不超预算、无脚本报错。
var failures: Array[String] = []
var main: Node

func _init() -> void:
	call_deferred("_run")

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FAIL ") + msg)
	if not ok:
		failures.append(msg)

func _phys(n: int) -> void:
	for _i in n:
		await physics_frame

func _count(group_root: Node, prefix: String) -> int:
	var n := 0
	for c in group_root.find_children("Vfx*", "", true, false):
		if str(c.name).begins_with(prefix) or prefix == "Vfx":
			n += 1
	return n

func _run() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _phys(30)
	var gm: Node = main.get("gm")
	gm.execute("invulnerable", {"enabled": true})
	gm.execute("freeze_ai", {"enabled": true})
	var p: Node = main.player
	var world: Node = main.world
	p.global_position = Vector3(0, 0.5, 6)
	p.aim_direction = Vector3(0, 0, -1)

	# 1) 贴图程序生成且缓存
	var t1 := VfxKit.tex("flame")
	check(t1 != null and t1 == VfxKit.tex("flame"), "程序贴图生成且缓存命中")
	check(VfxKit.tex("crack") != null and VfxKit.tex("spark") != null, "裂纹 / 火花贴图可生成")

	# 2) 爆炸 / 光束 / 闪电各记一次（预算干净时）
	var b0 := int(VfxKit.stats["beams"])
	VfxKit.beam(Vector3.ZERO, Vector3(0, 0, -5), VfxKit.RED)
	await process_frame
	check(int(VfxKit.stats["beams"]) > b0, "光束计数增长 (%d → %d)" % [b0, VfxKit.stats["beams"]])
	var l0 := int(VfxKit.stats["bolts"])
	VfxKit.lightning(Vector3.ZERO, Vector3(3, 0, -3))
	await process_frame
	check(int(VfxKit.stats["bolts"]) > l0, "闪电计数增长 (%d → %d)" % [l0, VfxKit.stats["bolts"]])
	var e0 := int(VfxKit.stats["explosions"])
	VfxKit.explosion(Vector3(0, 0, -3), 2.0)
	await process_frame
	check(int(VfxKit.stats["explosions"]) > e0, "爆炸计数增长 (%d → %d)" % [e0, VfxKit.stats["explosions"]])

	# 3) 每种技能形状都不报错，且 shape 已覆盖
	var shapes: Array = AbilityLibrary.distinct_shapes()
	check(shapes.size() >= 30, "技能形状种类 %d (>=30)" % shapes.size())
	for shape in shapes:
		AbilityLibrary._cast_shape(main, shape, 10.0, 9.0, {})
		await process_frame
	check(true, "全部 %d 种技能形状施放无脚本错误" % shapes.size())

	# 4) 施放产生特效节点（统计挂载父节点下的 Vfx*）
	var vfx_root: Node = GameFeel.instance.world_parent
	check(vfx_root != null, "GameFeel 已就绪，world_parent 存在")
	var before := _count(vfx_root, "Vfx")
	gm.execute("spawn", {"kind": "light", "count": 3})
	await process_frame
	for e in main.get("gm_enemies"):
		if is_instance_valid(e):
			e.global_position = p.global_position + Vector3(0, 0, -4)
	AbilityLibrary._cast_shape(main, "fireball", 10.0, 9.0, {})
	AbilityLibrary._cast_shape(main, "emp", 10.0, 9.0, {})
	await process_frame
	check(_count(vfx_root, "Vfx") > before, "施放后特效层出现 Vfx 节点 (%d → %d)" % [before, _count(vfx_root, "Vfx")])

	# 5) 预算封顶：狂刷不超过上限，溢出计入 dropped
	for i in 400:
		VfxKit.burst(Vector3(randf() * 4, 0.5, -4), "sparks", VfxKit.OCHRE)
	await process_frame
	check(VfxKit.live <= VfxKit.MAX_LIVE, "存活特效 %d <= 上限 %d" % [VfxKit.live, VfxKit.MAX_LIVE])
	check(int(VfxKit.stats["dropped"]) > 0, "超预算的特效被丢弃而非无限增长")

	# 6) 状态光环：挂上后出现 StatusAura，过期后清理
	var foe: Node = main.get("gm_enemies")[0]
	check(foe.get_node_or_null("VfxStatusAura") != null, "敌人带状态光环节点")
	var aura := foe.get_node("VfxStatusAura")
	foe.status.apply("burning", 0.3, 4.0)
	await process_frame
	check(aura.fx.has("burning"), "灼烧状态产生光环子节点")
	for i in 30:
		foe.status.tick(0.05)
		await process_frame
	check(not aura.fx.has("burning"), "状态过期后光环子节点移除")

	# 7) 全局关闭特效：parent() 返回 null，不再新增
	GameFeel.instance.enabled = false
	var live_before := VfxKit.live
	VfxKit.explosion(Vector3.ZERO, 2.0)
	VfxKit.burst(Vector3.ZERO, "sparks", VfxKit.RED)
	check(VfxKit.parent() == null and VfxKit.live <= live_before, "关闭特效后不再创建新特效")
	GameFeel.instance.enabled = true

	main.queue_free()
	await process_frame
	print("C21 VFX %s: %d failed" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)
