extends SceneTree

## C16 敌人花名册 v3：小怪 ≥5 / 精英 ≥1 / Boss ≥1；原型配置、行为、精英奖励、Boss 槽位、存档字段。

var failures := 0

func check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		push_error("FAIL: " + msg)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var minions := EnemyArchetypes.ids_of_tier("minion")
	var elites := EnemyArchetypes.ids_of_tier("elite")
	check(minions.size() >= 5, "小怪至少 5 种，实际 %d" % minions.size())
	check(elites.size() >= 1, "精英至少 1 种，实际 %d" % elites.size())
	check(ContentRoster.BOSS_ROSTER.has("boss_dredge_toad"), "新 Boss 吞河蟾已登记")
	check(FormalModelLibrary.boss_slot("boss_dredge_toad") == "boss_04_dredge_toad", "吞河蟾使用专属模型槽位")
	var behaviors := {}
	for id in EnemyArchetypes.ARCHETYPES:
		var d: Dictionary = EnemyArchetypes.ARCHETYPES[id]
		behaviors[d["behavior"]] = true
		check(float(d["hp"]) > 0.0 and float(d["speed"]) > 0.0, id + " 数值合法")
		if d["tier"] == "elite":
			check(float(d["hp"]) >= 4.0 * 34.0, id + " 精英血量显著高于小怪")
	check(behaviors.size() >= 6, "至少 6 种不同行为，实际 %d" % behaviors.size())
	# 原型配置
	var e := EnemyDummy.new().configure_archetype("t_flea", "flea", Vector3(1, 0, 2))
	check(e.archetype_id == "flea" and e.tier == "minion" and e.behavior == "hopper", "configure_archetype 写入原型")
	check(is_equal_approx(e.health, 22.0), "跳蚤血量来自原型")
	root.add_child(e)
	check(e.get_snapshot().get("archetype", "") == "flea", "快照带原型 id")
	e.queue_free()
	# 行为：ranged 会后退，charger 蓄力停顿后冲锋
	var r := EnemyDummy.new().configure_archetype("t_oil", "oildrum")
	var back := r._behave(0.1, Vector3(0, 0, 2.0))
	check(back.z < 0.0, "远程怪近距离会后退")
	r.free()
	var c := EnemyDummy.new().configure_archetype("t_rhino", "rhino")
	c._beh_t = 2.6
	check(c._behave(0.1, Vector3(0, 0, 6.0)).length() == 0.0, "精英犀牛蓄力时停顿（读招窗口）")
	c._beh_t = 3.3
	c._behave(0.1, Vector3(0, 0, 6.0))
	check(c._dash_t > 0.0, "蓄力后触发冲锋")
	var dash := c._behave(0.1, Vector3(0, 0, 6.0))
	check(dash.length() > c.speed * 0.1 * 3.0, "冲锋速度远高于移动")
	c.free()
	check(EnemyArchetypes.reward_scale("elite") > EnemyArchetypes.reward_scale("minion"), "精英奖励倍率高于小怪")
	# 主场景：一波 + 精英 + 新 Boss 实际在场
	var main_scene: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main_scene)
	await process_frame
	await process_frame
	var spawned: Array = main_scene.spawn_roster_wave(true)
	check(spawned.size() == minions.size() * 2 + 1, "一波 = 每种小怪 2 只 + 1 精英，实际 %d" % spawned.size())
	var tiers := {}
	for en in spawned:
		tiers[en.tier] = true
	check(tiers.has("minion") and tiers.has("elite"), "波次包含小怪与精英")
	var elite: EnemyDummy = null
	for en in spawned:
		if en.tier == "elite":
			elite = en
	await process_frame
	check(elite != null and elite.get_node_or_null("EliteNameplate") != null or not ProceduralRig.has_rig(str(EnemyArchetypes.get_def(elite.archetype_id)["slot"])), "精英有头顶名牌")
	var silver_before: int = main_scene.run_systems.silver
	elite.take_damage(9999.0)
	await process_frame
	check(main_scene.run_systems.silver > silver_before, "击杀精英发放银币")
	main_scene.run_systems.bosses_defeated = 1
	main_scene.summon_boss()
	await process_frame
	check(main_scene.boss != null and main_scene.boss.enemy_id == "boss_dredge_toad", "第二只 Boss 是吞河蟾")
	if failures == 0:
		print("PASS enemy_roster_flow: all checks")
	quit(1 if failures > 0 else 0)
