extends SceneTree
## 行为测试：S3 桥接装配流 + C5 Boss 阶段流 + C6 音频事件表。

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("FAIL: " + message)

func _run() -> void:
	_test_bridge()
	_test_min_slice()
	_test_boss_phases()
	_test_audio_table()
	if failures.is_empty():
		print("PASS min_slice_flow: all checks")
	else:
		print("FAIL min_slice_flow: %d checks" % failures.size())
	quit(0 if failures.is_empty() else 1)

func _test_bridge() -> void:
	var modules := ContentV2Catalog.create_v2_definitions()
	check(modules.size() == 40, "v2 目录 40 模块")
	var legacy_by_id := {}
	for m in modules:
		var legacy := ContentBridge.to_legacy(m)
		check(ModuleCatalog.validate_definition(legacy), "桥接 %s 应通过旧目录校验" % m.module_id)
		check(legacy.mount_kind == "function", "v2 模块应为 function 槽位")
		legacy_by_id[legacy.id] = legacy
	var assembler := LoadoutAssembler.new()
	assembler.setup(Node3D.new(), legacy_by_id)
	check(assembler.definitions.size() == 40, "装配器应收录 40 个 v2 定义")
	var sample_id := "mage_pyro"
	check(assembler.set_preview(sample_id, 0), "应可预览 " + sample_id)
	check(assembler.confirm_preview(), "应可安装 " + sample_id)
	check(assembler.has_module(sample_id), "安装后 has_module 应命中")

func _test_min_slice() -> void:
	var catalog := ModuleCatalog.create_definitions()
	check(catalog.size() == 6, "旧目录 6 模块应不受影响")

func _test_boss_phases() -> void:
	var boss := BossEntity.new().configure_boss("boss_test", Vector3.ZERO)
	check(boss.health == 420.0, "Boss 血量应为 420")
	check(boss.phase == 1, "初始阶段应为 1")
	boss.current_health = boss.health * 0.5
	boss._process(0.016)
	check(boss.phase == 2, "血量 50% 应进阶段 2")
	boss.current_health = boss.health * 0.2
	boss._process(0.016)
	check(boss.phase == 3, "血量 20% 应进阶段 3")
	check(boss.speed == float((boss.get_meta("phase_speeds") as Array)[2]), "阶段 3 速度应同步")
	var result := boss.try_engineering_hit(Vector3(0, 0, 2), Vector3(0, 0, -1), 2.0, 5.0, 30.0, {})
	check(bool(result["hit"]), "Boss 应接受既有战斗协议命中")

func _test_audio_table() -> void:
	check(AudioEventTable.has_event("boss_spawn") and AudioEventTable.has_event("ability_cast"), "事件表应含 Boss/技能事件")
	check(AudioEventTable.keyword_event("卡诺宁鲸王现身 · 河谷深处") == "boss_spawn", "现身应路由到 boss_spawn")
	check(AudioEventTable.keyword_event("新模块入列") == "module_install", "模块应路由到 module_install")
	check(AudioEventTable.keyword_event("普通消息") == "", "无关键词应回退默认")
	var audio_script := load("res://scripts/wanderburg_audio.gd") as GDScript
	check(audio_script != null, "音频节点脚本应可加载")
	check(AudioEventTable.EVENTS.size() >= 19, "事件表应不少于 19 个事件")
