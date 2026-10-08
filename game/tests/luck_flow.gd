extends SceneTree
## 行为测试：Luck 引擎 + 选择引擎 + 存档 v7（随仓库测试契约：SceneTree + failures）。

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("FAIL: " + message)

func _run() -> void:
	_test_probability_list()
	_test_luck()
	_test_artifact_fallback()
	_test_vehicle_upgrade()
	_test_save_v7()
	if failures.is_empty():
		print("PASS luck_flow: all checks")
	else:
		print("FAIL luck_flow: %d checks" % failures.size())
	quit(0 if failures.is_empty() else 1)

func _test_probability_list() -> void:
	var pl := ProbabilityList.new()
	pl.add("a", 3.0)
	pl.add("b", 1.0)
	check(absf(pl.total_weight() - 4.0) < 0.001, "total_weight 应为 4")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var counts := {"a": 0, "b": 0}
	for i in 400:
		counts[pl.roll_item(rng)] += 1
	check(counts["a"] > counts["b"] * 2, "权重抽取应偏向 a (a=%d b=%d)" % [counts["a"], counts["b"]])
	var c := pl.clone()
	c.add("c", 1.0)
	check(pl.entries.size() == 2 and c.entries.size() == 3, "clone 应与原池隔离")

func _test_luck() -> void:
	var p0 := LuckEngine.rarity_probabilities(0.0)
	var p10 := LuckEngine.rarity_probabilities(10.0)
	var pm5 := LuckEngine.rarity_probabilities(-5.0)
	check(p10.w > p0.w, "luck+ 应提升 epic 概率 (%.3f -> %.3f)" % [p0.w, p10.w])
	check(p10.x < p0.x, "luck+ 应降低 common 概率")
	check(pm5.w < p0.w, "luck- 应降低 epic 概率")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var epic := 0
	for i in 2000:
		if LuckEngine.roll(8.0, rng) == LuckEngine.Rarity.EPIC:
			epic += 1
	check(epic > 100, "高 luck 下 epic 出现率应放大 (got %d/2000)" % epic)
	for luck in [-3.0, 0.0, 2.5, 15.0]:
		var p := LuckEngine.rarity_probabilities(luck)
		check(absf(p.x + p.y + p.z + p.w - 1.0) < 0.001, "概率和应为 1 (luck=%.1f)" % luck)

func _mk_mod(id: String) -> ModuleDefinitionV2:
	var m := ModuleDefinitionV2.new()
	m.module_id = id
	return m

func _test_artifact_fallback() -> void:
	var se := SelectionEngine.new()
	se.rng.seed = 11
	var a1 := ArtifactDefinition.new(); a1.id = "a1"
	var a2 := ArtifactDefinition.new(); a2.id = "a2"
	var fb := ArtifactDefinition.new(); fb.id = "fb"
	se.artifact_pool = ProbabilityList.new()
	se.artifact_fallbacks = [a1, a2, fb]
	var picks := se.generate_artifacts(false)
	check(picks.size() == 3, "保底应填满 3 槽 (got %d)" % picks.size())
	if picks.size() == 3:
		check(picks[0].id == "a1" and picks[1].id == "a2" and picks[2].id == "fb", "fallback 应按序去重填充")

func _test_vehicle_upgrade() -> void:
	var se := SelectionEngine.new()
	se.rng.seed = 3
	var t1 := VehicleStats.new(); t1.stats_name = "T1"; t1.vehicle_size_rank = 0
	var t2 := VehicleStats.new(); t2.stats_name = "T2"; t2.vehicle_size_rank = 1; t2.max_hp = 200
	se.vehicle_tiers = [t1, t2]
	var opts := se.generate_vehicle_upgrades(t1)
	check(opts.size() == 1, "Tier 链应给出 1 个升级选项 (got %d)" % opts.size())
	if opts.size() == 1:
		check(opts[0]["stats"].stats_name == "T2", "只应给出更高 rank 的选项")
		check(opts[0]["bonus_lines"].size() == 5, "属性对比行应为 5 条")

func _test_save_v7() -> void:
	var s := SaveV7.new()
	s.silver = 150
	s.unlocked_ids = ["m1", "m2", "m1"]
	s.quest_progress = {"q1": 3}
	s.stamp_build_identity("dev", 2)
	var s2 := SaveV7.migrate(s.to_dict())
	check(s2.save_version == 7, "迁移后版本应为 7")
	check(s2.unlocked_ids == ["m1", "m2"], "normalize 应去重")
	check(s2.matches_build_identity("dev", 2), "build identity 应匹配")
	var legacy := {"save_version": 1, "gold": 99, "unlocked_ids": ["x", "x"]}
	var s3 := SaveV7.migrate(legacy)
	check(s3.silver == 99, "旧 gold 字段应迁移到 silver")
