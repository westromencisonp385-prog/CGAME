extends SceneTree
## 行为测试：C2 选择 UI 逻辑 + v2 内容目录（随仓库测试契约：SceneTree + failures）。

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("FAIL: " + message)

func _run() -> void:
	_test_catalog()
	_test_pools()
	_test_selection_generate()
	if failures.is_empty():
		print("PASS content_v2_flow: all checks")
	else:
		print("FAIL content_v2_flow: %d checks" % failures.size())
	quit(0 if failures.is_empty() else 1)

func _test_catalog() -> void:
	var modules := ContentV2Catalog.create_v2_definitions()
	check(modules.size() == 40, "v2 目录应有 40 模块 (got %d)" % modules.size())
	var ids := {}
	for m in modules:
		check(ContentV2Catalog.validate_v2(m), "模块 %s 应通过校验" % (m.module_id if m != null else "null"))
		check(not ids.has(m.module_id), "模块 id 不应重复: %s" % m.module_id)
		ids[m.module_id] = true
	check(ids.has("mage_pyro") and ids.has("crew_engineer") and ids.has("turret_layer"), "三系代表模块齐备")

func _test_pools() -> void:
	var pools := ContentV2Catalog.build_module_pools(ContentV2Catalog.create_v2_definitions())
	check(pools.size() == 4, "应产出四档池")
	var total := 0
	for pool in pools:
		total += pool.entries.size()
	check(total == 40, "四档池应覆盖全部 40 模块 (got %d)" % total)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var epics := 0
	for i in 300:
		if LuckEngine.roll(6.0, rng) == LuckEngine.Rarity.EPIC:
			epics += 1
	check(epics > 0, "高 luck 下应能抽出 epic 档 (got %d/300)" % epics)

func _test_selection_generate() -> void:
	var se := SelectionEngine.new()
	se.rng.seed = 9
	se.new_module_pools = ContentV2Catalog.build_module_pools(ContentV2Catalog.create_v2_definitions())
	var picks := se.generate_new_modules()
	check(picks.size() == 3, "新模块 3 选 1 应生成 3 项 (got %d)" % picks.size())
	var seen := {}
	for p in picks:
		check(not seen.has(p.module_id), "3 选 1 不应重复: %s" % p.module_id)
		seen[p.module_id] = true
	se.installed_modules = picks.duplicate()
	se.upgrade_pools = se.new_module_pools
	var ups := se.generate_upgrades()
	check(ups.size() == 3, "模块升级应生成 3 项 (got %d)" % ups.size())
	if ups.size() > 0:
		check(ups[0].has("module") and ups[0].has("upgrade"), "升级选项应含 module+upgrade")
