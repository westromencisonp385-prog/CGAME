extends SceneTree
## 行为测试：C3 载具成长（Tier 链 + 吞噬升阶 + 4 技能槽）与 C4 单局系统束（经济/任务/掉落/神器）。

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("FAIL: " + message)

func _run() -> void:
	_test_tier_chain()
	_test_absorb_growth()
	_test_ability_slots()
	_test_economy()
	_test_quests()
	_test_artifacts()
	_test_drop()
	if failures.is_empty():
		print("PASS progression_flow: all checks")
	else:
		print("FAIL progression_flow: %d checks" % failures.size())
	quit(0 if failures.is_empty() else 1)

func _test_tier_chain() -> void:
	var chain := VehicleProgression.default_tier_chain()
	check(chain.size() == 3, "Tier 链应有 3 级 (got %d)" % chain.size())
	check(chain[0].next_upgrade == chain[1] and chain[1].next_upgrade == chain[2], "next_upgrade 链应连通")
	check(chain[2].vehicle_size_rank == 2 and chain[2].max_hp > chain[0].max_hp, "高 Tier 属性应更强")

func _test_absorb_growth() -> void:
	var prog := VehicleProgression.new()
	var r := prog.absorb(0)
	check(bool(r["absorbed"]), "rank0 目标应可吞噬")
	var advanced := false
	for i in 10:
		r = prog.absorb(0)
		if bool(r.get("advanced", false)):
			advanced = true
	check(advanced, "连续吞噬应推进 size_rank")
	check(prog.stats.vehicle_size_rank >= 1, "升阶后 rank>=1 (got %d)" % prog.stats.vehicle_size_rank)
	check(prog.stats.collector_radius > 2.5, "升阶应扩大收集半径")
	var too_big := prog.absorb(5)
	check(not bool(too_big["absorbed"]), "超出 can_absorb 的目标应拒绝")

func _test_ability_slots() -> void:
	var prog := VehicleProgression.new()
	var mage := ModuleDefinitionV2.new()
	mage.module_id = "t1"
	mage.active_base_cooldown = 2.0
	mage.active_base_damage = 9.0
	check(prog.equip_ability(0, mage) and prog.equip_ability(3, mage), "0/3 号槽应可装备")
	check(not prog.equip_ability(4, mage), "越界槽应拒绝")
	var cast := prog.cast_slot(0)
	check(bool(cast["cast"]) and float(cast["damage"]) == 9.0, "首施放应成功并带伤害")
	var again := prog.cast_slot(0)
	check(not bool(again["cast"]) and str(again["reason"]) == "cooling_down", "冷却期内应拒绝")
	prog.tick(2.5)
	check(bool(prog.cast_slot(0)["cast"]), "冷却走完应可再施放")

func _test_economy() -> void:
	var run := RunSystems.new()
	check(run.earn_silver(50, "test") and run.silver == 50, "收入入账")
	check(run.spend_silver(30, "buy") and run.silver == 20, "支出扣账")
	check(not run.spend_silver(999, "too_much"), "余额不足应拒绝")
	check(run.ledger_legit(), "流水净值应等于余额 (50-30=20)")

func _test_quests() -> void:
	var run := RunSystems.new()
	var quests := [{"id": "q1", "metric": "harvested", "target": 3, "reward_silver": 20}]
	var got := run.report("harvested", 2, quests)
	check(got.is_empty() and run.quest_progress["q1"] == 2, "未达标不结算")
	got = run.report("harvested", 1, quests)
	check(got.has("q1"), "达标应结算 q1")
	check(run.silver == 20, "任务奖励应入账 (got %d)" % run.silver)
	got = run.report("harvested", 5, quests)
	check(got.is_empty(), "已达成任务不重复结算")

func _test_artifacts() -> void:
	var run := RunSystems.new()
	var a := ArtifactDefinition.new()
	a.id = "luck_charm"
	a.stat_modifiers = {"luck": 3.0}
	a.factor = 1.5
	check(run.equip_artifact(a), "神器应可装备")
	check(absf(run.artifact_bonus("luck") - 4.5) < 0.001, "聚合应含 factor (3.0*1.5=4.5)")
	check(run.effective_luck(1.0) == 5.5, "有效 luck 应为 base+bonus")
	check(run.has_artifact_tag("luck") == false, "未打 tag 不应命中")

func _test_drop() -> void:
	var run := RunSystems.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var silver_drops := 0
	for i in 100:
		if run.roll_drop(rng, 0.0) == "silver":
			silver_drops += 1
	check(silver_drops > 40 and silver_drops < 100, "掉落表应稳定在七成左右 (got %d/100)" % silver_drops)
	check(run.silver > 0 and run.ledger_legit(), "掉落收益应入账且流水合法")
