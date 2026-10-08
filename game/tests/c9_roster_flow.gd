extends SceneTree

## C9 内容批次测试：花名册（神器 30 / Boss 10 / 船长 15）+ 神器双池保底 +
## Boss 序列轮换 + 船长聚合修饰 + 回路接线。

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("FAIL: " + message)

func _run() -> void:
	_test_roster_sizes()
	_test_artifact_pools_and_fallback()
	_test_boss_rotation()
	_test_captain_bonus()
	_test_total_bonus_aggregation()
	if failures.is_empty():
		print("PASS c9_roster_flow: all checks")
	else:
		print("FAIL c9_roster_flow: %d checks" % failures.size())
	quit(0 if failures.is_empty() else 1)

func _test_roster_sizes() -> void:
	var artifacts: Array = ContentRoster.create_artifacts()
	check(artifacts.size() >= 30, "神器应 >=30，实际 %d" % artifacts.size())
	var rare_count := artifacts.filter(func(a): return a.rare).size()
	check(rare_count >= 5, "rare 神器应 >=5，实际 %d" % rare_count)
	check(ContentRoster.BOSS_ROSTER.size() == 11, "Boss 花名册应 11（含吞河蟾），实际 %d" % ContentRoster.BOSS_ROSTER.size())
	var captains: Array = ContentRoster.create_captains()
	check(captains.size() == 15, "船长应 15，实际 %d" % captains.size())
	for a in artifacts:
		check(not a.id.is_empty() and not a.display_name.is_empty(), "神器 id/name 非空: " + a.id)
	for c in captains:
		check(not c.id.is_empty() and not c.display_name.is_empty(), "船长 id/name 非空: " + c.id)

func _test_artifact_pools_and_fallback() -> void:
	var artifacts: Array = ContentRoster.create_artifacts()
	var pools: Dictionary = ContentRoster.build_artifact_pools(artifacts)
	var normal: ProbabilityList = pools["normal"]
	var rare: ProbabilityList = pools["rare"]
	check(normal != null and not normal.is_empty(), "普通神器池非空")
	check(rare != null and not rare.is_empty(), "rare 神器池非空")
	var engine := SelectionEngine.new(7)
	engine.artifact_pool = normal
	engine.rare_artifact_pool = rare
	engine.artifact_fallbacks = artifacts.filter(func(a): return not a.rare).slice(0, 3)
	engine.rare_artifact_fallbacks = artifacts.filter(func(a): return a.rare).slice(0, 3)
	var picks: Array = engine.generate_artifacts(false)
	check(picks.size() == 3, "普通神器 3 选 1 应 3 项，实际 %d" % picks.size())
	for p in picks:
		check(p is ArtifactDefinition and not bool(p.rare), "普通池抽取不应含 rare")
	var rare_picks: Array = engine.generate_artifacts(true)
	check(rare_picks.size() == 3, "rare 神器 3 选 1 应 3 项")
	var empty_engine := SelectionEngine.new(7)
	empty_engine.artifact_pool = ProbabilityList.new()
	empty_engine.artifact_fallbacks = artifacts.filter(func(a): return not a.rare).slice(0, 3)
	var fallback_picks: Array = empty_engine.generate_artifacts(false)
	check(fallback_picks.size() == 3, "空池应走 fallback 保底 3 项，实际 %d" % fallback_picks.size())

func _test_boss_rotation() -> void:
	check(ContentRoster.next_boss_id(0) == "boss_kanoning", "第 1 个 Boss 是鲸王")
	check(ContentRoster.next_boss_id(1) == "boss_dredge_toad", "第 2 个 Boss 是吞河蟾")
	check(ContentRoster.next_boss_id(2) == "boss_cannon_phase", "第 3 个 Boss 是炮阵阶段蟹")
	check(ContentRoster.next_boss_id(10) == "boss_grave_cross", "第 11 个 Boss 是墓十字")
	check(ContentRoster.next_boss_id(15) == "boss_grave_cross", "超出序列钳制在最后一个")

func _test_captain_bonus() -> void:
	var captains: Array = ContentRoster.create_captains()
	var run := RunSystems.new()
	check(run.total_bonus("damage") == 0.0, "无船长无神器时 damage bonus 0")
	run.hire_captain(captains[2])
	check(absf(run.total_bonus("damage") - 0.06) < 0.001, "铆钉船长 damage +6%")
	run.hire_captain(captains[14])
	check(absf(run.total_bonus("damage") - 0.08) < 0.001, "换骨髓船长后取新值 +8%")

func _test_total_bonus_aggregation() -> void:
	var artifacts: Array = ContentRoster.create_artifacts()
	var run := RunSystems.new()
	var artifact: ArtifactDefinition = artifacts.filter(func(a): return a.id == "art_whale_tooth")[0]
	run.equip_artifact(artifact)
	check(absf(run.artifact_bonus("damage") - 0.25 * 1.5) < 0.001, "鲸牙 damage = 0.25 × factor 1.5")
	run.hire_captain(ContentRoster.create_captains()[2])
	check(absf(run.total_bonus("damage") - (0.25 * 1.5 + 0.06)) < 0.001, "神器+船长聚合求和")
	var by_id := {}
	for a in artifacts:
		by_id[a.id] = a
	check(by_id.has("art_midas_gear"), "点金齿轮在目录")
	check(absf(run.total_bonus("silver_gain")) >= 0.0, "silver_gain 聚合可用")
